# Network Policy Templates

Per-workload egress NetworkPolicy templates for SecureKube.

The cluster ships with a `default-deny-all` policy that blocks ALL ingress
and egress across every namespace. These templates let you explicitly open
only what each workload actually needs — the correct zero-trust approach.

---

## How to use

1. Copy the relevant template(s) from `egress-templates/` into your namespace's policy folder
2. Replace the `app: YOUR_APP` label selector with your workload's actual label
3. Apply with `kubectl apply -f` or let Argo CD sync it

```bash
# Apply a single template directly
kubectl apply -f network-policies/egress-templates/allow-dns.yaml

# Or copy and customise before applying
cp network-policies/egress-templates/allow-external-https.yaml \
   kustomize/base/network-policies/my-app-egress.yaml
# edit the file, then:
kubectl apply -k kustomize/base/network-policies/
```

---

## Template index

| File | What it allows | Use when |
|---|---|---|
| `allow-dns.yaml` | UDP/TCP 53 to kube-dns | Every pod needs this — DNS is blocked by default-deny |
| `allow-same-namespace.yaml` | All traffic within the same namespace | Microservices in the same namespace talking to each other |
| `allow-to-namespace.yaml` | Egress to a specific namespace | Frontend → backend in a different namespace |
| `allow-external-https.yaml` | Egress to 0.0.0.0/0 on port 443 | Pods that call external APIs (broadest safe external allow) |
| `allow-external-cidr.yaml` | Egress to a specific IP range | Tightly scoped external access (e.g. your company's API gateway) |
| `allow-monitoring.yaml` | Egress to Prometheus/metrics namespace | Workloads that expose /metrics and need scraping |
| `allow-database-egress.yaml` | Egress to a database pod on a specific port | App → Postgres/MySQL/Redis |
| `allow-api-gateway.yaml` | Ingress from an API gateway namespace | Backend services that only accept traffic from a gateway |

---

## Layering policies

NetworkPolicies are additive — multiple policies on the same pod are OR'd together.
Build up a workload's allowed traffic by applying multiple focused templates:

```yaml
# A typical web API workload needs:
# 1. DNS resolution
# 2. Ingress from the API gateway
# 3. Egress to its database
# 4. Egress to an external payment API

kubectl apply -f egress-templates/allow-dns.yaml
kubectl apply -f egress-templates/allow-api-gateway.yaml
kubectl apply -f egress-templates/allow-database-egress.yaml
kubectl apply -f egress-templates/allow-external-https.yaml
```

---

## Testing your policies

```bash
# Confirm a pod CAN reach its intended target
kubectl exec -n default deploy/my-app -- curl -s https://api.example.com

# Confirm a pod CANNOT reach something it shouldn't
kubectl exec -n default deploy/my-app -- curl -s --max-time 3 http://internal-service.other-namespace

# Check which policies apply to a pod
kubectl get networkpolicies -n default
```
