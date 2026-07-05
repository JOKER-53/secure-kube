include config.env
export

.PHONY: deploy deploy-light destroy cluster policies gatekeeper falco verify test bench \
        status logs clean-logs dashboard clean help

CLUSTER_NAME  ?= securekube
TF_VAR_cluster_name         = $(strip $(CLUSTER_NAME))
TF_VAR_enable_network_policy_cni = $(strip $(ENABLE_CALICO))

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

deploy: cluster policies gatekeeper falco test ## Full one-command deploy (kind, local)
	@echo ""
	@echo "✅ SecureKube is up. CIS-hardened, zero-trust, policy-enforced."
	@echo "   Run 'make bench' for the CIS score, 'make status' for component health, 'make dashboard' to view alerts."

deploy-light: ## Deploy with Falco disabled and 1 worker — for slower machines
	@$(MAKE) cluster
	@$(MAKE) policies
	@$(MAKE) gatekeeper
	@$(MAKE) test
	@echo "✅ SecureKube (light mode) is up — Falco skipped. Run 'make falco' later if you want runtime monitoring."

cluster: ## Step 1: Provision the kind cluster via Terraform
	cd terraform/kind && terraform init -input=false && terraform apply -auto-approve
	@echo "→ Cluster '$(CLUSTER_NAME)' provisioned ($(CONTROL_PLANE_COUNT) control-plane, $(WORKER_COUNT) worker)"

policies: ## Step 2-3: Apply NetworkPolicy, RBAC, Pod Security Standards
	kubectl apply -k kustomize/base
	@echo "→ Default-deny NetworkPolicy, least-privilege RBAC, and PSS labels applied"

gatekeeper: ## Step 4: Install OPA Gatekeeper + all constraint templates + constraints
	helm repo add gatekeeper https://open-policy-agent.github.io/gatekeeper/charts --force-update
	helm repo update
	helm upgrade --install gatekeeper gatekeeper/gatekeeper \
		--namespace gatekeeper-system --create-namespace \
		--wait --timeout 180s \
		-f helm/gatekeeper-values.yaml
	kubectl wait --for=condition=Available --timeout=120s -n gatekeeper-system deployment/gatekeeper-controller-manager
	kubectl apply -f gatekeeper/constraint-templates/
	@echo "→ Waiting for CRDs to register..."
	sleep 8
	kubectl apply -f gatekeeper/constraints/
	@echo "→ Gatekeeper installed — 6 constraints enforced: no-root, no-privileged, readonly-rootfs, no-hostpath, no-host-namespaces, require-resources, allowed-repos, capabilities-and-ports"

falco: ## Step 5: Install Falco for runtime threat detection + audit logging
ifeq ($(strip $(ENABLE_FALCO)),true)
	helm repo add falcosecurity https://falcosecurity.github.io/charts --force-update
	helm repo update
	helm upgrade --install falco falcosecurity/falco \
		--namespace falco --create-namespace \
		-f helm/falco-values.yaml
	@echo "→ Falco runtime monitoring active. Run 'make dashboard' to view alerts."
else
	@echo "→ ENABLE_FALCO=false in config.env, skipping Falco install"
endif

test: ## Run negative + positive policy tests (replaces old 'verify')
	./scripts/test-policies.sh

verify: test ## Alias for 'test' (back-compat)

bench: ## Step 6: Run kube-bench and report the CIS score
	kubectl apply -f https://raw.githubusercontent.com/aquasecurity/kube-bench/main/job.yaml
	@echo "→ Waiting for kube-bench job to complete..."
	kubectl wait --for=condition=complete --timeout=60s job/kube-bench
	kubectl logs job/kube-bench
	@echo ""
	@echo "ℹ️  kind runs a subset of a real control plane (no managed etcd/kubelet file perms"
	@echo "   the way a bare-metal install has). Expect PASS on API-server/RBAC/PSP-family"
	@echo "   controls and expected FAIL/WARN on node-file-permission controls — see docs/architecture.md."

status: ## Show health of every SecureKube component
	@echo "== Cluster =="
	@kubectl cluster-info --context kind-$(CLUSTER_NAME) 2>/dev/null || echo "  not running"
	@echo ""
	@echo "== Gatekeeper =="
	@kubectl get pods -n gatekeeper-system 2>/dev/null || echo "  not installed"
	@echo ""
	@echo "== Falco =="
	@kubectl get pods -n falco 2>/dev/null || echo "  not installed"
	@echo ""
	@echo "== Constraints (active policies) =="
	@kubectl get constraints 2>/dev/null || echo "  none"
	@echo ""
	@echo "== Recent constraint violations =="
	@kubectl get events --field-selector reason=ConstraintViolation -A 2>/dev/null | tail -10 || echo "  none"

logs: ## Tail Falco alert logs
	kubectl logs -n falco -l app.kubernetes.io/name=falco -f --tail=50

clean-logs: ## Clear old kube-bench / test job leftovers
	kubectl delete job kube-bench --ignore-not-found
	kubectl delete pod -n default -l app=secure-app --ignore-not-found
	@echo "→ Stale jobs and test pods removed"

dashboard: ## Port-forward the Falco Sidekick UI to localhost:2802
	@echo "Opening Falco Sidekick UI at http://localhost:2802 (Ctrl+C to stop)"
	kubectl port-forward -n falco svc/falco-falcosidekick-ui 2802:2802

destroy: ## Tear down the cluster and all resources
	cd terraform/kind && terraform destroy -auto-approve
	@echo "→ Cluster destroyed"

clean: destroy ## Alias for destroy
