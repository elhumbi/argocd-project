# ArgoCD Projekt Setup Guide

Ein umfassender Leitfaden zum Aufbau eines ArgoCD-Projekts mit GitOps-Best-Practices.

## Übersicht

ArgoCD ist ein deklaratives GitOps-Tool für Kubernetes, das deine Anwendungen automatisch bereitstellt und synchronisiert. Dieses Repository zeigt, wie du ein ArgoCD-Projekt strukturiert aufbaust.

## Voraussetzungen

- Kubernetes Cluster (v1.16+)
- ArgoCD installiert im Cluster
- Git Repository für deine Manifeste
- `kubectl` konfiguriert
- Optional: `kustomize` oder `helm`

## Repository-Struktur

```
my-argocd-project/
├── README.md
├── apps/
│   ├── my-app/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       │   ├── kustomization.yaml
│   │       │   └── patches/
│   │       ├── staging/
│   │       │   ├── kustomization.yaml
│   │       │   └── patches/
│   │       └── production/
│   │           ├── kustomization.yaml
│   │           └── patches/
├── argocd/
│   ├── applications/
│   │   ├── my-app-dev.yaml
│   │   ├── my-app-staging.yaml
│   │   └── my-app-prod.yaml
│   └── projects/
│       └── my-project.yaml
└── scripts/
    └── deploy-argocd-apps.sh
```

## Schritt-für-Schritt Setup

### 1. Basis-Manifeste erstellen

Erstelle deine Kubernetes-Manifeste in `apps/my-app/base/`:

**deployment.yaml**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  labels:
    app: my-app
spec:
  replicas: 3
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
      - name: my-app
        image: my-app:latest
        ports:
        - containerPort: 8080
```

**service.yaml**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app-service
spec:
  selector:
    app: my-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 8080
  type: ClusterIP
```

**kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: my-app
  version: v1.0.0
```

### 2. Umgebungsspezifische Overlays

**apps/my-app/overlays/development/kustomization.yaml**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base

patchesStrategicMerge:
  - patches/deployment-patch.yaml

namePrefix: dev-
namespace: my-app-dev

replicas:
  - name: my-app
    count: 1
```

### 3. ArgoCD Application definieren

**argocd/applications/my-app-dev.yaml**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-dev
  namespace: argocd
  labels:
    environment: development
spec:
  project: my-project
  source:
    repoURL: https://github.com/username/my-argocd-project
    targetRevision: HEAD
    path: apps/my-app/overlays/development
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-dev
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
```

### 4. ArgoCD Project definieren

**argocd/projects/my-project.yaml**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: my-project
  namespace: argocd
spec:
  description: "Mein ArgoCD Projekt"
  
  sourceRepos:
    - 'https://github.com/username/my-argocd-project'
  
  destinations:
    - namespace: 'my-app-*'
      server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  
  namespaceResourceWhitelist:
    - group: 'apps'
      kind: Deployment
    - group: ''
      kind: Service
    - group: ''
      kind: ConfigMap
    - group: ''
      kind: Secret
  
  roles:
    - name: developer
      description: "Entwickler Rolle"
      policies:
        - p, proj:my-project:developer, applications, get, my-project/*, allow
        - p, proj:my-project:developer, applications, sync, my-project/*, allow
      groups:
        - my-org:developers
```

## Deployment

### ArgoCD Applications bereitstellen

```bash
# Projekt erstellen
kubectl apply -f argocd/projects/my-project.yaml

# Applications bereitstellen
kubectl apply -f argocd/applications/
```

### Automatisches Deployment-Script

**scripts/deploy-argocd-apps.sh**
```bash
#!/bin/bash

echo "Deploying ArgoCD Project and Applications..."

# ArgoCD Project bereitstellen
kubectl apply -f argocd/projects/

# Applications bereitstellen
kubectl apply -f argocd/applications/

echo "Checking Application Status..."
kubectl get applications -n argocd

echo "Deployment complete!"
```

## Best Practices

### 🔧 Repository-Management
- **Separate Repositories**: Trenne Application-Code von Deployment-Manifesten
- **Branch-Strategie**: Verwende unterschiedliche Branches für verschiedene Umgebungen
- **Conventional Commits**: Nutze aussagekräftige Commit-Messages

### 🚀 Deployment-Strategien
- **Staged Rollouts**: Deploye zuerst in dev, dann staging, dann production
- **Automated Sync**: Aktiviere automatische Synchronisation nur nach ausreichenden Tests
- **Health Checks**: Definiere Custom Health Checks für komplexe Anwendungen

### 🔐 Security
- **Secrets Management**: Verwende External Secrets Operator oder Sealed Secrets
- **RBAC**: Implementiere granulare Berechtigungen über ArgoCD Projects
- **Image Scanning**: Integriere Container-Security-Scanning in deine Pipeline

### 📊 Monitoring
- **Notifications**: Konfiguriere Slack/Email-Benachrichtigungen für Failed Syncs
- **Metrics**: Nutze ArgoCD Metrics für Monitoring-Dashboards
- **Logging**: Centralisiere ArgoCD-Logs für besseres Troubleshooting

## Troubleshooting

### Häufige Probleme

**Application Out of Sync**
```bash
# Status prüfen
kubectl describe application my-app-dev -n argocd

# Manueller Sync
argocd app sync my-app-dev
```

**Resource Permission Errors**
```bash
# ArgoCD Project Permissions prüfen
kubectl get appproject my-project -n argocd -o yaml
```

**Sync Hooks Debugging**
```bash
# Logs der Sync Operation
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

## Erweiterte Konfiguration

### Custom Health Checks
```yaml
# In der Application spec
spec:
  source:
    plugin:
      name: my-plugin
  health:
    - group: apps
      kind: Deployment
      check: |
        hs = {}
        if obj.status.readyReplicas == obj.status.replicas then
          hs.status = "Healthy"
        else
          hs.status = "Progressing"
        end
        return hs
```

### Sync Hooks
```yaml
# Pre-sync Hook Beispiel
apiVersion: batch/v1
kind: Job
metadata:
  name: database-migration
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
spec:
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: migration
        image: my-migration-tool:latest
```

## Nützliche Commands

```bash
# ArgoCD CLI Login
argocd login <argocd-server>

# Applications auflisten
argocd app list

# Application Status
argocd app get my-app-dev

# Sync durchführen
argocd app sync my-app-dev

# Logs anzeigen
argocd app logs my-app-dev

# Application löschen
argocd app delete my-app-dev
```

## Weitere Ressourcen

- [ArgoCD Official Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [GitOps Best Practices](https://www.weave.works/technologies/gitops/)

## Contributing

1. Fork das Repository
2. Erstelle einen Feature Branch (`git checkout -b feature/amazing-feature`)
3. Committe deine Änderungen (`git commit -m 'Add amazing feature'`)
4. Push zum Branch (`git push origin feature/amazing-feature`)
5. Öffne einen Pull Request

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe [LICENSE](LICENSE) für Details.