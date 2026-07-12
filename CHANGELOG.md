# Changelog

All notable changes to SecureKube are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versioning follows [Semantic Versioning](https://semver.org/).

---

## [1.2.0] - 2026-07-12

### Added
- GitOps layer via Argo CD — 5 Applications managing all policy layers (NetworkPolicy, RBAC, PSA, Gatekeeper constraints) with manual sync mode
- Argo CD AppProject scoping source repo and destination cluster with least-privilege allow-lists
- `make argocd`, `make dashboard-argocd`, `make sync-all`, `make sync-policies`, `make sync-rbac`, `make sync-gatekeeper` targets
- `scripts/install-argocd.sh` — auto-detects GitHub remote URL, patches Application manifests, prints admin credentials
- CONTRIBUTING.md — contribution guide covering constraint authoring, test requirements, commit format, PR process
- SECURITY.md — vulnerability reporting path and documented known trade-offs
- GitHub issue templates — bug report and feature request
- GitHub PR template — checklist for constraint PRs
- Trivy vulnerability scanning in CI (filesystem scan) and release workflow (container image scan)
- Trivy SARIF results uploaded to GitHub Security tab
- Container image published to ghcr.io and Docker Hub on every release

### Fixed
- Added `argocd` to Gatekeeper `excludedNamespaces` on all 8 constraints — prevents webhook deadlock during Argo CD pod scheduling
- Lowercase repo owner in Trivy image ref — GHCR requires all-lowercase image names
- `security-events: write` permission added to release workflow for SARIF upload
- Restored missing `test:` target in Makefile
- `install-argocd.sh` pre-creates `argocd` namespace before Helm install to avoid Gatekeeper webhook race

### Docker images
```
docker pull ghcr.io/kadhiravaneg/secure-kube:v1.2.0
docker pull joker53/secure-kube:v1.2.0
```

---

## [1.1.0] - 2026-07-07

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
