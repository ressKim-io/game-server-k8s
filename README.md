<div align="center">

# 🎮 게임 서버 Kubernetes 아키텍처

[![Challenge](https://img.shields.io/badge/Challenge-Week3--Day2-blue)](docs/challenge-requirements.md)
[![Blog](https://img.shields.io/badge/Blog-작성중-orange)](https://blog.example.com)
[![K8s](https://img.shields.io/badge/Kubernetes-v1.31-326CE5?logo=kubernetes)](https://kubernetes.io/)
[![k3d](https://img.shields.io/badge/k3d-v5.8-blue)](https://k3d.io/)

**부트캠프 Week 3 Day 2 - 워크로드 아키텍처 구현 챌린지**

멀티플레이어 게임 서버를 Kubernetes 워크로드로 설계하고 배포한 프로젝트입니다.

[챌린지 요구사항](docs/challenge-requirements.md) • [관련 블로그 (작성 예정)](#)

</div>

---

## 📋 목차

- [프로젝트 개요](#-프로젝트-개요)
- [아키텍처](#️-아키텍처)
- [구성 요소](#-구성-요소)
- [설치 방법](#-설치-방법)
- [테스트](#-테스트)
- [모니터링](#-모니터링)
- [트러블슈팅](#️-트러블슈팅)
- [기술 스택](#-기술-스택)

---

## 🎯 프로젝트 개요

### 배경
DevOps 부트캠프 Week 3 Day 2 챌린지 과제로, 게임 서버 아키텍처를 Kubernetes 환경에서 구현했습니다.

### 목표
- ConfigMap을 활용한 환경 변수 분리
- HPA를 통한 자동 스케일링
- Ingress로 단일 진입점 구성
- nodeSelector를 활용한 워크로드별 노드 배치

### 주요 성과
✅ 5개 마이크로서비스 배포  
✅ HPA 기반 자동 스케일링 구현  
✅ Ingress 경로 기반 라우팅  
✅ 노드별 워크로드 격리  

---

## 🏗️ 아키텍처
```
외부 사용자
  ↓
Ingress (game.local:8888)
  ├─ /lobby   → Lobby Service → Lobby Pods (2-5개, HPA)
  ├─ /room    → GameRoom Service → GameRoom Pods (3-10개, HPA)
  ├─ /chat    → Chat Service → Chat Pods (2-8개, HPA)
  └─ /ranking → Ranking Service → Ranking Pod (1개)

노드 배치:
- Agent-0 (고성능): GameRoom Pods
- Agent-1 (일반): Lobby, Chat, Ranking Pods
```

**상세 구조도**: [챌린지 요구사항](docs/challenge-requirements.md) 참조

---

## 📦 구성 요소

| 서비스 | 역할 | 복제본 | 스케일링 | 노드 배치 |
|--------|------|--------|----------|-----------|
| **Lobby** | 게임 방 목록, 매치메이킹 | 2-5개 | HPA (CPU 50%, 메모리 70%) | 일반 노드 |
| **GameRoom** | 실시간 게임 진행 | 3-10개 | HPA (CPU 60%) | 고성능 노드 (전용) |
| **Chat** | 채팅 서버 (WebSocket) | 2-8개 | HPA (메모리 75%) | 일반 노드 |
| **Ranking** | 랭킹 계산 및 조회 | 1개 | 없음 | 일반 노드 |

### 핵심 기능
- **ConfigMap**: 환경 변수 분리 (공통/서비스별)
- **HPA**: CPU/메모리 기반 자동 스케일링
- **Ingress**: 경로 기반 라우팅 (/lobby, /room, /chat, /ranking)
- **nodeSelector**: 워크로드별 노드 배치 (고성능/일반)
- **Resource Limits**: 안정성 확보 (requests/limits)
- **Health Checks**: Liveness/Readiness Probe

---

## 🚀 설치 방법

### 사전 요구사항
- Docker
- kubectl
- k3d

### 1. 클러스터 생성
```bash
# k3d 클러스터 생성
k3d cluster create k3s-local \
  --agents 2 \
  --servers 1 \
  --port "30000-30100:30000-30100@server:0" \
  --port "8080:80@loadbalancer" \
  --k3s-arg "--disable=traefik@server:0" \
  --wait

# 노드 라벨링
kubectl label nodes k3d-k3s-local-agent-0 workload=gameroom cpu-type=high node-type=high-performance
kubectl label nodes k3d-k3s-local-agent-1 workload=backend memory-type=high node-type=standard
```

### 2. 한 번에 배포
```bash
# 배포 스크립트 실행
./deploy-all.sh
```

### 3. 수동 배포 (단계별)
```bash
# Namespace
kubectl apply -f k8s-manifests/00-namespace.yaml

# ConfigMap
kubectl apply -f k8s-manifests/01-configmap.yaml

# Deployments & Services
kubectl apply -f k8s-manifests/03-lobby-deployment.yaml
kubectl apply -f k8s-manifests/04-service.yaml
kubectl apply -f k8s-manifests/05-gameroom-deployment.yaml
kubectl apply -f k8s-manifests/06-chat-deployment.yaml
kubectl apply -f k8s-manifests/07-ranking-deployment.yaml

# Metrics Server (HPA 필요)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl patch deployment metrics-server -n kube-system --type=json -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/args/-",
    "value": "--kubelet-insecure-tls"
  }
]'

# HPA
kubectl apply -f k8s-manifests/08-hpa.yaml

# Ingress
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.11.1/deploy/static/provider/cloud/deploy.yaml
kubectl apply -f k8s-manifests/09-ingress.yaml
```

### 4. 확인
```bash
# 전체 리소스 확인
kubectl get all,hpa,ingress -n game-prod

# Pod 상태 및 노드 배치
kubectl get pods -n game-prod -o wide

# HPA 상태
kubectl get hpa -n game-prod
```

---

## 🧪 테스트

### 로컬 접속 설정
```bash
# /etc/hosts 수정
echo "127.0.0.1 game.local" | sudo tee -a /etc/hosts

# Ingress 포트 포워딩 (필요시)
kubectl port-forward -n ingress-nginx svc/ingress-nginx-controller 8888:80
```

### 서비스 접속 테스트
```bash
# 각 서비스 테스트
curl http://game.local:8888/lobby
curl http://game.local:8888/room
curl http://game.local:8888/chat
curl http://game.local:8888/ranking

# 또는 브라우저에서
# http://game.local:8888/lobby
```

### HPA 부하 테스트
```bash
# 부하 생성
kubectl run load-generator \
  --image=busybox \
  -n game-prod \
  --restart=Never \
  -- /bin/sh -c "while true; do wget -q -O- http://game-lobby; done"

# HPA 상태 실시간 확인
kubectl get hpa -n game-prod -w

# Pod 증가 확인
kubectl get pods -n game-prod -l app=game-lobby -w

# 테스트 종료
kubectl delete pod load-generator -n game-prod
```

---

## 📊 모니터링

### 리소스 사용량
```bash
# 노드 리소스
kubectl top nodes

# Pod 리소스
kubectl top pods -n game-prod

# HPA 상태
kubectl get hpa -n game-prod
```

### k9s로 실시간 모니터링
```bash
# k9s 실행
k9s

# 주요 명령어
:ns          # Namespace
:po          # Pods
:deploy      # Deployments
:svc         # Services
:hpa         # HPA
:ing         # Ingress
```

---

## 🛠️ 트러블슈팅

### Pod가 Pending
```bash
# 원인 확인
kubectl describe pod <pod-name> -n game-prod

# 노드 라벨 확인
kubectl get nodes --show-labels

# 라벨 추가 (필요시)
kubectl label nodes <node-name> workload=gameroom
```

### HPA가 작동 안 함
```bash
# Metrics Server 확인
kubectl get deployment metrics-server -n kube-system

# Metrics 확인
kubectl top pods -n game-prod

# Metrics Server 재시작
kubectl rollout restart deployment metrics-server -n kube-system
```

### Ingress 접속 안 됨
```bash
# Ingress Controller 확인
kubectl get pods -n ingress-nginx

# Ingress 상태
kubectl describe ingress game-server-ingress -n game-prod

# /etc/hosts 확인
cat /etc/hosts | grep game.local
```

---

## 📚 기술 스택

### Orchestration
- **Kubernetes**: v1.31 (k3d)
- **Container Runtime**: containerd

### Core Components
- **Auto Scaling**: HPA (Horizontal Pod Autoscaler)
- **Ingress Controller**: nginx-ingress v1.11
- **Config Management**: ConfigMap
- **Monitoring**: Metrics Server

### Tools
- **Cluster Management**: k3d v5.8
- **CLI**: kubectl
- **Monitoring UI**: k9s

---

## 📁 파일 구조
```
game-server-k8s/
├── README.md                      # 본 문서
├── docs/
│   └── challenge-requirements.md  # 챌린지 원문
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
└── scripts/
    ├── deploy-all.sh              # 전체 배포
    └── cleanup.sh                 # 환경 정리
```

---

## 📝 관련 문서

- [챌린지 요구사항](docs/challenge-requirements.md) - 부트캠프 과제 원문
- [관련 블로그](#) - 구현 과정 및 트러블슈팅 (작성 예정)

---

## 🙏 참고

- [Kubernetes 공식 문서](https://kubernetes.io/docs/)
- [k3d 공식 문서](https://k3d.io/)
- [nginx-ingress 공식 문서](https://kubernetes.github.io/ingress-nginx/)
- [HPA 가이드](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)

---

<div align="center">

[챌린지 요구사항](docs/challenge-requirements.md) • [블로그 (작성 예정)](#)

</div>
