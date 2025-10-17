<div align="center">

# 🎮 게임 서버 Kubernetes 배포

[![Challenge](https://img.shields.io/badge/Challenge-%231-blue)](docs/challenge-requirements.md)
[![Blog](https://img.shields.io/badge/Blog-Read-orange)](https://resskim-io.github.io/my-blog/categories/#challenge)
[![K8s](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![k3d](https://img.shields.io/badge/k3d-v5.8-blue)](https://k3d.io/)

**DevOps 부트캠프챌린지 #1 - 게임 서버 K8s 배포**

Kubernetes를 이용한 마이크로서비스 게임 서버 배포 프로젝트입니다.

📖 **<a href="https://resskim-io.github.io/my-blog/categories/#challenge" target="_blank">구현 과정 블로그 보기</a>** 📖

</div>

---

## 📚 블로그 시리즈

구현 과정과 상세 설명은 블로그에서 확인하세요!

1. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part1/" target="_blank">Part 1: k3s → k3d 전환</a>
2. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part2/" target="_blank">Part 2: Namespace & ConfigMap</a>
3. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part3/" target="_blank">Part 3: Deployment로 첫 Pod 띄우기</a>
4. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part4/" target="_blank">Part 4: Service로 네트워크 연결</a>
5. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part5/" target="_blank">Part 5: 나머지 서비스 배포</a>
6. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part6/" target="_blank">Part 6: HPA로 Auto Scaling</a>
7. <a href="https://resskim-io.github.io/my-blog/challenge/kubernetes/challenge1-game-server-part7/" target="_blank">Part 7: Ingress로 단일 진입점</a>

---

## 🎯 프로젝트 개요

### 아키텍처
```
외부 사용자
  ↓
Ingress (:8080)
  ├─ /lobby   → Lobby Service (2-10개 Pod, HPA)
  ├─ /room    → GameRoom Service (3개 Pod, compute 노드)
  ├─ /chat    → Chat Service (2개 Pod, backend 노드)
  └─ /ranking → Ranking Service (1개 Pod)
```

### 주요 기술
- ✅ **ConfigMap**: 환경 변수 분리 (공통/서비스별)
- ✅ **HPA**: CPU/메모리 기반 자동 스케일링
- ✅ **Ingress**: 경로 기반 라우팅
- ✅ **nodeSelector**: 워크로드별 노드 배치

---

## 🚀 빠른 시작

### 1. 클러스터 생성
```bash
# k3d 클러스터 생성 (워커 노드 2개)
k3d cluster create k3s-local \
  --agents 2 \
  --port "8080:80@loadbalancer"

# 노드 라벨링
kubectl label nodes k3d-k3s-local-agent-0 workload=compute
kubectl label nodes k3d-k3s-local-agent-1 workload=backend
```

### 2. 전체 배포
```bash
# Namespace & ConfigMap
kubectl apply -f k8s-manifests/00-namespace.yaml
kubectl apply -f k8s-manifests/01-configmap.yaml

# 서비스 배포
kubectl apply -f k8s-manifests/03-lobby-deployment.yaml
kubectl apply -f k8s-manifests/04-service.yaml
kubectl apply -f k8s-manifests/05-gameroom-deployment.yaml
kubectl apply -f k8s-manifests/06-chat-deployment.yaml
kubectl apply -f k8s-manifests/07-ranking-deployment.yaml

# Metrics Server (HPA용)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type='json' \
  -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

# HPA
kubectl apply -f k8s-manifests/08-hpa.yaml

# Ingress Controller
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
kubectl apply -f k8s-manifests/09-ingress.yaml
```

### 3. 확인
```bash
# 전체 리소스
kubectl get all,hpa,ingress -n game-prod

# 접속 테스트
curl http://localhost:8080/lobby
curl http://localhost:8080/room
curl http://localhost:8080/chat
curl http://localhost:8080/ranking
```

**상세한 과정과 트러블슈팅은 <a href="https://resskim-io.github.io/my-blog/categories/#challenge" target="_blank">블로그</a>에서 확인하세요!**

---

## 📦 구성 요소

| 서비스 | 복제본 | 스케일링 | 노드 배치 |
|--------|--------|----------|-----------|
| **Lobby** | 3개 | HPA (2-10) | 일반 |
| **GameRoom** | 3개 | - | compute |
| **Chat** | 2개 | - | backend |
| **Ranking** | 1개 | - | backend |

자세한 설정은 [k8s-manifests/](k8s-manifests/) 폴더 참고

---

## 🛠️ 주요 명령어
```bash
# Pod 상태 확인
kubectl get pods -n game-prod -o wide

# HPA 상태
kubectl get hpa -n game-prod

# 로그 확인
kubectl logs -f deployment/game-lobby -n game-prod

# 전체 삭제
kubectl delete namespace game-prod
k3d cluster delete k3s-local
```

---

## 📁 파일 구조
```
game-server-k8s/
├── README.md
├── docs/
│   └── challenge-requirements.md
├── k8s-manifests/
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 03-lobby-deployment.yaml
│   ├── 04-service.yaml
│   ├── 05-gameroom-deployment.yaml
│   ├── 06-chat-deployment.yaml
│   ├── 07-ranking-deployment.yaml
│   ├── 08-hpa.yaml
│   └── 09-ingress.yaml
└── cleanup.sh
```

---

## 🔗 관련 링크

- 📖 **<a href="https://resskim-io.github.io/my-blog/categories/#challenge" target="_blank">블로그 시리즈 전체보기</a>**
- 📋 [챌린지 요구사항](docs/challenge-requirements.md)
- 📚 <a href="https://kubernetes.io/docs/" target="_blank">Kubernetes 공식 문서</a>
- 🚀 <a href="https://k3d.io/" target="_blank">k3d 공식 문서</a>

---

<div align="center">

**Made with ❤️ by <a href="https://github.com/ressKim-io" target="_blank">ressKim</a>**

📖 <a href="https://resskim-io.github.io/my-blog/categories/#challenge" target="_blank">상세 구현 과정 보기</a>

</div>
