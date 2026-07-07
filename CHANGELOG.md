# Changelog

All notable changes to SecureKube are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.0.0] - 2026-07-07

### Added
- CIS-aligned Kubernetes cluster provisioning via `kind` + Terraform
- Zero-trust networking: Calico CNI + default-deny NetworkPolicy across all namespaces
- OPA Gatekeeper with 8 constraints: no-root, no-privileged, readonly-rootfs, no-hostpath, no-host-namespaces, require-resources, allowed-repos, capabilities-and-ports
- Pod Security Admission (`restricted` profile) enforced on all workload namespaces
- Least-privilege RBAC — no wildcard verbs, no cluster-admin for workloads
- Falco runtime threat detection (modern eBPF driver) + Falco Sidekick UI
- Audit logging via hardened API server flags (CIS 3.2.x)
- GitOps layer: Argo CD managing all policy layers (NetworkPolicy, RBAC, PSA, Gatekeeper) with manual sync
- One-command deploy: `make deploy` (kind, fully local, zero cloud cost)
- Policy test suite: 8 negative tests (insecure patterns rejected) + 1 positive test (secure workload allowed)
- CIS Benchmark scoring via kube-bench (`make bench`)
- GitHub Actions CI: deploy → test → bench → teardown on every push
- Container image published to ghcr.io and Docker Hub on every release
- Versioned GitHub Releases with changelog and zip artifact

### Known limitations
- kind-only (EKS/GKE modules on roadmap)
- Gatekeeper webhook is fail-open due to Calico IPAM deadlock (documented in `docs/architecture.md`)
- `anonymous-auth` left enabled (kubeadm join compatibility — documented)
- CIS benchmark does not fully pass on kind (node-level controls require bare metal)

---

## Roadmap

- [ ] EKS Terraform module
- [ ] GKE Terraform module
- [ ] Image signing with Cosign + Gatekeeper
- [ ] Secrets management (External Secrets Operator)
- [ ] Per-workload egress NetworkPolicy
- [ ] GitOps for Helm releases (Gatekeeper, Falco, Argo CD as Argo CD Applications)
