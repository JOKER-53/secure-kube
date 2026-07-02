#!/usr/bin/env bash
# Proves the cluster is actually enforcing what it claims to enforce.
# Every test below is EXPECTED to be rejected. If any of them succeed,
# the security posture is broken and this script exits non-zero.
set -uo pipefail

FAILURES=0

check_rejected() {
  local description="$1"
  local manifest="$2"

  echo -n "→ ${description}... "
  if echo "${manifest}" | kubectl apply -f - >/tmp/verify_out 2>&1; then
    echo "FAIL (was allowed, should have been rejected)"
    kubectl delete -f - <<<"${manifest}" >/dev/null 2>&1
    FAILURES=$((FAILURES + 1))
  else
    echo "OK (rejected as expected)"
  fi
}

echo "== SecureKube policy verification =="

check_rejected "privileged pod should be blocked" "
apiVersion: v1
kind: Pod
metadata:
  name: test-privileged
  namespace: default
spec:
  containers:
    - name: test
      image: nginx
      securityContext:
        privileged: true
"

check_rejected "root pod should be blocked" "
apiVersion: v1
kind: Pod
metadata:
  name: test-root
  namespace: default
spec:
  containers:
    - name: test
      image: nginx
      securityContext:
        runAsNonRoot: false
"

check_rejected "writable rootfs pod should be blocked" "
apiVersion: v1
kind: Pod
metadata:
  name: test-writable-rootfs
  namespace: default
spec:
  containers:
    - name: test
      image: nginx
      securityContext:
        runAsNonRoot: true
        readOnlyRootFilesystem: false
"

echo ""
if [ "${FAILURES}" -eq 0 ]; then
  echo "✅ All policy checks passed — cluster is secure by default."
  exit 0
else
  echo "❌ ${FAILURES} check(s) failed — review Gatekeeper constraints and PSA labels."
  exit 1
fi
