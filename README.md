# SecureKube

A CIS-benchmarked, zero-trust Kubernetes cluster provisioned via IaC — no manual security configuration required.

## Problem statement

Default Kubernetes installations ship with zero network isolation, no pod security standards, and permissive RBAC. Teams adopt K8s fast and configure security slowly — or never. SecureKube eliminates that gap entirely at provisioning time: `make deploy` and the cluster is already hardened.

## Objectives

- CIS Kubernetes Benchmark **Level 1** controls enforced out of the box
- Zero-trust networking via **default-deny NetworkPolicy** across all namespaces
- **Least-privilege RBAC** — no wildcard permissions, no cluster-admin for workloads
- **Pod security standards** — no root containers, no privileged pods, read-only root filesystem
- **Audit logging** and runtime policy enforcement via OPA Gatekeeper + Falco
- **One-command deployment** — `make deploy` on local (kind) or cloud (EKS/GKE)

## Architecture

```
1. Provision cluster        Terraform: kind / EKS / GKE
        │
        ▼
2. Network isolation        Default-deny NetworkPolicy (+ Calico CNI)
        │
        ▼
3. RBAC hardening           Least privilege, no wildcards
        │
        ▼
4. Policy enforcement       OPA Gatekeeper + Pod Security Standards
        │
        ▼
5. Runtime monitoring       Falco + audit logging
        │
        ▼
6. CIS validation           kube-bench score reported
        │
        ▼
   Cluster ready — secure by default
```

## Tech stack

| Layer | Tool |
|---|---|
| Cluster provisioning | Terraform |
| Package management | Helm (Gatekeeper, Falco) |
| Namespace policy | Kustomize |
| Local demo target | kind |
| CI validation | GitHub Actions |
| CIS scoring | kube-bench |

## Project phases

| Phase | Focus | Deliverables | Timeline |
|---|---|---|---|
| 1 | Research | CIS/NSA standards review | Week 1 |
| 2 | Core IaC | Terraform for kind/EKS/GKE | Week 2-3 |
| 3 | Policy layer | NetworkPolicy, RBAC, PSA | Week 3-4 |
| 4 | Enforcement | Gatekeeper + Falco | Week 4-5 |
| 5 | CI/CD validation | GitHub Actions + kube-bench | Week 5-6 |
| 6 | Docs & demo | README, diagrams | Week 6 |

## Quick start (kind / local)

Prerequisites: `terraform`, `kubectl`, `helm`, `kind`, `docker`.

```bash
git clone <this-repo>
cd securekube
make deploy
```

This runs, in order: `cluster` → `policies` → `gatekeeper` → `falco` → `test`.

On a slower machine, use `make deploy-light` — 1 worker node, Falco skipped.

Edit `config.env` to change cluster name, node counts, or toggle Calico/Falco before deploying.

### Useful commands

```bash
make status      # health of every component + active constraints + recent violations
make test        # negative tests (insecure pods rejected) + positive test (secure pod allowed)
make bench       # CIS Benchmark score via kube-bench
make dashboard   # port-forward Falco Sidekick UI to localhost:2802
make logs        # tail live Falco alerts
make clean-logs  # remove stale kube-bench/test job leftovers
make destroy     # tear down everything
```

### Try the example workloads yourself

```bash
kubectl apply -f examples/secure-app.yaml       # should succeed
kubectl apply -f examples/insecure-apps.yaml    # every pod in this file should be rejected
```

## Repository layout

```
securekube/
├── Makefile                         one-command deploy entrypoint
├── terraform/kind/                  cluster provisioning (kind target)
│   ├── main.tf                      audit logging, hardened API server flags, Calico CNI
│   ├── variables.tf
│   ├── outputs.tf
│   └── audit-policy.yaml            CIS 3.2.x audit policy
├── kustomize/base/
│   ├── network-policies/            default-deny + DNS-allow NetworkPolicy
│   ├── rbac/                        least-privilege Role/RoleBinding, no-wildcard rules
│   └── pod-security/                PSA "restricted" labels per namespace
├── gatekeeper/
│   ├── constraint-templates/        Rego: no-root, no-privileged, readonly-rootfs,
│   │                                 no-hostpath, no-host-namespaces, require-resources,
│   │                                 allowed-repos, capabilities-and-ports
│   └── constraints/                 activation of each template cluster-wide
├── helm/
│   ├── gatekeeper-values.yaml       fail-closed webhook, 3 replicas, live-state audit
│   └── falco-values.yaml            eBPF driver, JSON output, sidekick UI
├── examples/
│   ├── secure-app.yaml              passes every policy layer — proves the "happy path" works
│   └── insecure-apps.yaml           8 pods, each violating exactly one constraint
├── config.env                       cluster name, node counts, feature toggles
├── .github/workflows/ci.yaml        spins up kind, deploys, validates, tears down
├── scripts/test-policies.sh         negative + positive policy tests
└── docs/architecture.md
```

## Known limitations (be upfront about these)

- **`make bench` will not show a clean pass.** `kind` runs Kubernetes components as containers on your machine, not as a real multi-node control plane — controls around etcd file permissions, kubelet config file ownership, and certain node-level TLS settings can't be satisfied the way they would be on bare metal or a managed node group. Treat SecureKube as "CIS-aligned at the API/RBAC/pod-security layer," not "100% CIS-certified." The `bench` target prints this caveat after every run.
- **The allowed-repos list ships permissive** (`docker.io/library/`, `ghcr.io/`, `gcr.io/`, `registry.k8s.io/`) so the bundled examples work out of the box. Tighten `gatekeeper/constraints/allowed-repos-constraint.yaml` to your actual registry before treating this as a supply-chain control.
- **PSA and Gatekeeper overlap by design**, not by accident — see `docs/architecture.md` for why both layers exist and how to reason about coverage gaps between them.
- **No GitOps layer yet.** Deploys are `helm upgrade --install` + `kubectl apply`, not reconciled by Argo CD/Flux. Fine for a demo/portfolio cluster; add a GitOps controller before treating this as a production pattern.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `make cluster` hangs or fails | Docker doesn't have enough resources | Raise Docker Desktop's CPU/memory limits (4 CPU / 6GB+ recommended) |
| `make gatekeeper` — constraints fail to apply | CRDs not registered yet | Re-run `make gatekeeper`; the 8s sleep is usually enough but slow machines may need more — increase the `sleep` in the Makefile |
| `make test` — secure-app gets rejected | An unrelated constraint is stricter than expected | `make status` to see which constraint fired, then `kubectl describe pod secure-app` for the specific violation message |
| Port 2802 already in use (`make dashboard`) | Another process is bound to it | `kubectl port-forward -n falco svc/falco-falcosidekick-ui <free-port>:2802` manually |
| `make destroy` leaves resources behind | Terraform state drift after manual `kubectl` changes | `kind delete cluster --name <CLUSTER_NAME from config.env>` as a manual fallback |
| Everything is slow | Full mode installs Calico + Gatekeeper (3 replicas) + Falco | Use `make deploy-light` |

## References

- CIS Kubernetes Benchmark v1.8 — https://www.cisecurity.org/benchmark/kubernetes
- NSA/CISA Kubernetes Hardening Guide (2022) — https://media.defense.gov
- NIST SP 800-190, Application Container Security Guide
- Kubernetes Pod Security Standards — https://kubernetes.io/docs/concepts/security/pod-security-standards

## Roadmap

- [ ] EKS Terraform module (IAM Roles for Service Accounts, VPC CNI + NetworkPolicy)
- [ ] GKE Terraform module (Workload Identity, GKE Sandbox / gVisor)
- [ ] Image signing/verification via Cosign + Gatekeeper
- [ ] Secrets management via External Secrets Operator
