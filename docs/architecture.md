# Architecture notes

## Why default-deny + Calico on kind

kindnet (kind's default CNI) does not enforce `NetworkPolicy` — it provides pod networking only. Without swapping in a policy-aware CNI, the `default-deny-all` NetworkPolicy in `kustomize/base/network-policies/` would be silently ignored and the cluster would *look* zero-trust without *being* zero-trust. `terraform/kind/main.tf` disables the default CNI and installs Calico for this reason.

## Why two enforcement layers (PSA + Gatekeeper)

- **Pod Security Admission (PSA)**, applied via namespace labels, is built into Kubernetes core, has zero extra moving parts, and enforces the standard "restricted" profile.
- **OPA Gatekeeper** adds enforcement Kubernetes' native PSA can't express as precisely (e.g. exact rego conditions, custom messages, audit trail of violations over time, extensibility for future org-specific rules).

Together: PSA is the floor that can never regress even if Gatekeeper is ever uninstalled; Gatekeeper is the layer that gives auditable, extensible policy-as-code.

## Why RBAC ships a `workload-runtime` Role instead of relying only on defaults

Kubernetes ships no default namespaced role suitable for application workloads — teams either bind `cluster-admin` (too broad) or write nothing (pods run with only their ServiceAccount's implicit, minimal permissions, which usually breaks introspection features). `workload-runtime` is the least-privilege middle ground: read-only access to configmaps and pod listing, explicitly *no* secrets access. Secrets access is intentionally left to a separate, per-secret scoped role so it's an explicit decision, not a default.

## Fail-closed webhook

`helm/gatekeeper-values.yaml` sets `validatingWebhookFailurePolicy: Fail`. If the Gatekeeper webhook is ever unreachable, the API server rejects the request rather than admitting it unchecked. This trades a small availability risk (a webhook outage blocks new pod creation) for a much larger security guarantee (policy can never be silently bypassed).

## Why the Gatekeeper layer has 8 constraints, not 3

The first pass only blocked root/privileged/writable-rootfs — a real attacker doesn't need any of those if `hostPath` mounting `/` is left open, or if a pod can set `hostNetwork: true` and see every other pod's traffic on the node. The current set closes the highest-value gaps beyond what PSA's "restricted" profile alone covers:

| Constraint | What it stops |
|---|---|
| `no-root` / `no-privileged` / `readonly-rootfs` | container escape via root or writable host-equivalent access |
| `no-hostpath` | reading/writing the node filesystem directly |
| `no-host-namespaces` | seeing/signaling every process on the node, or sniffing node network traffic |
| `require-resources` | noisy-neighbor DoS from unbounded pods |
| `allowed-repos` | pulling arbitrary/untrusted images |
| `capabilities-and-ports` | capability creep and binding privileged ports like a root process |

This still isn't exhaustive — seccomp/AppArmor profile enforcement, image signature verification (Cosign), and NetworkPolicy egress allow-lists per-workload are reasonable next additions, not yet implemented.

## Audit logging scope

`terraform/kind/audit-policy.yaml` logs full request/response bodies only for `secrets`, `configmaps`, and RBAC objects — the resources where a full body matters for a security investigation — and only request metadata for everything else, to keep log volume manageable while still satisfying CIS 3.2.x.
