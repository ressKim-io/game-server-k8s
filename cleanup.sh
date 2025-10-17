#!/bin/bash
set -e

echo "🧹 게임 서버 K8s 리소스 삭제..."
echo ""

# 역순으로 삭제
kubectl delete -f k8s-manifests/09-ingress.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/08-hpa.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/07-ranking-deployment.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/06-chat-deployment.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/05-gameroom-deployment.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/04-service.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/03-lobby-deployment.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/01-configmap.yaml 2>/dev/null || true
kubectl delete -f k8s-manifests/00-namespace.yaml 2>/dev/null || true

echo ""
echo "✅ 삭제 완료!"
kubectl get all -n game-prod 2>/dev/null || echo "(game-prod namespace 없음)"
