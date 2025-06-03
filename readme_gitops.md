# GitOps mit ArgoCD - Der komplette Leitfaden

Ein umfassender Guide für GitOps-Implementierung mit ArgoCD, von den Grundlagen bis zur Produktionsreife.

## 🎯 Was ist GitOps?

GitOps ist eine operative Methodik, die Git als einzige Quelle der Wahrheit (Single Source of Truth) für deklarative Infrastruktur und Anwendungen verwendet. Die Kernprinzipien sind:

- **Deklarativ**: Das gesamte System wird deklarativ beschrieben
- **Versioniert und unveränderlich**: Alle Änderungen werden in Git versioniert
- **Automatisch gepullt**: Software-Agenten ziehen automatisch gewünschte Zustände aus Git
- **Kontinuierlich abgeglichen**: Software-Agenten überwachen und korrigieren Abweichungen

## 🏗️ GitOps-Architektur mit ArgoCD

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Developer     │    │   Git Repository │    │   Kubernetes    │
│                 │────│                  │────│    Cluster      │
│ git push        │    │  Manifests       │    │                 │
└─────────────────┘    │  Configurations  │    │   ArgoCD        │
                       └──────────────────┘    │   Applications  │
                                ▲               └─────────────────┘
                                │
                                │ Pull & Sync
                                │
                       ┌──────────────────┐
                       │     ArgoCD       │
                       │   Controller     │
                       └──────────────────┘
```

## 📁 Empfohlene Repository-Struktur

### Option 1: Mono-Repository Ansatz
```
gitops-mono-repo/
├── README.md
├── .gitignore
├── docs/
│   ├── architecture.md
│   ├── deployment-guide.md
│   └── troubleshooting.md
├── infrastructure/
│   ├── argocd/
│   │   ├── install/
│   │   │   ├── namespace.yaml
│   │   │   ├── argocd-install.yaml
│   │   │   └── ingress.yaml
│   │   ├── projects/
│   │   │   ├── infrastructure.yaml
│   │   │   ├── applications.yaml
│   │   │   └── staging.yaml
│   │   └── repositories/
│   │       └── repo-credentials.yaml
│   ├── monitoring/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   └── alertmanager/
│   └── ingress/
│       ├── nginx-controller/
│       └── cert-manager/
├── applications/
│   ├── frontend/
│   │   ├── base/
│   │   │   ├── deployment.yaml
│   │   │   ├── service.yaml
│   │   │   ├── configmap.yaml
│   │   │   └── kustomization.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       ├── staging/
│   │       └── production/
│   ├── backend/
│   │   ├── base/
│   │   └── overlays/
│   └── database/
│       ├── base/
│       └── overlays/
├── bootstrap/
│   ├── root-app.yaml
│   ├── infrastructure-apps.yaml
│   └── application-apps.yaml
└── scripts/
    ├── bootstrap.sh
    ├── deploy-environment.sh
    └── sync-all.sh
```

### Option 2: Multi-Repository Ansatz
```
# Repository 1: Infrastructure
gitops-infrastructure/
├── argocd/
├── monitoring/
├── networking/
└── security/

# Repository 2: Applications  
gitops-applications/
├── frontend/
├── backend/
├── database/
└── microservices/

# Repository 3: Configuration
gitops-config/
├── environments/
├── secrets/
└── policies/
```

## 🚀 Schritt-für-Schritt GitOps Implementation

### Phase 1: ArgoCD Installation und Bootstrap

**1. ArgoCD Namespace und Installation**

```yaml
# infrastructure/argocd/install/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: argocd
  labels:
    name: argocd
    app.kubernetes.io/component: argocd
```

```yaml
# infrastructure/argocd/install/argocd-install.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
  namespace: argocd
spec:
  project: infrastructure
  source:
    repoURL: https://argoproj.github.io/argo-helm
    chart: argo-cd
    targetRevision: 5.51.6
    helm:
      values: |
        global:
          image:
            tag: v2.8.4
        server:
          ingress:
            enabled: true
            hosts:
              - argocd.example.com
            tls:
              - secretName: argocd-tls
                hosts:
                  - argocd.example.com
        configs:
          params:
            server.insecure: true
          repositories: |
            - url: https://github.com/your-org/gitops-repo
              type: git
              name: gitops-main
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**2. Bootstrap Script**

```bash
#!/bin/bash
# scripts/bootstrap.sh

set -e

echo "🚀 Bootstrapping GitOps with ArgoCD..."

# Apply ArgoCD installation
echo "📦 Installing ArgoCD..."
kubectl apply -f infrastructure/argocd/install/

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Apply root application (App of Apps pattern)
echo "🌱 Deploying Root Application..."
kubectl apply -f bootstrap/root-app.yaml

echo "✅ Bootstrap complete!"
echo "🌐 Access ArgoCD at: https://argocd.example.com"
echo "🔑 Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
```

### Phase 2: App of Apps Pattern

**Root Application (Parent)**

```yaml
# bootstrap/root-app.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  labels:
    app.kubernetes.io/name: root
spec:
  project: default
  source:
    repoURL: https://github.com/your-org/gitops-repo
    targetRevision: HEAD
    path: bootstrap
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
  info:
    - name: 'GitOps Root Application'
      value: 'Manages all child applications'
```

**Infrastructure Applications**

```yaml
# bootstrap/infrastructure-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: infrastructure
  namespace: argocd
spec:
  generators:
  - list:
      elements:
      - name: monitoring
        path: infrastructure/monitoring
        namespace: monitoring
      - name: ingress-nginx
        path: infrastructure/ingress/nginx-controller
        namespace: ingress-nginx
      - name: cert-manager
        path: infrastructure/ingress/cert-manager
        namespace: cert-manager
  template:
    metadata:
      name: '{{name}}'
      labels:
        app.kubernetes.io/name: '{{name}}'
        app.kubernetes.io/part-of: infrastructure
    spec:
      project: infrastructure
      source:
        repoURL: https://github.com/your-org/gitops-repo
        targetRevision: HEAD
        path: '{{path}}'
      destination:
        server: https://kubernetes.default.svc
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
          - ServerSideApply=true
      info:
        - name: 'Infrastructure Component'
          value: '{{name}}'
```

### Phase 3: Umgebungs-spezifische Deployments

**Environment ApplicationSet**

```yaml
# bootstrap/application-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: applications
  namespace: argocd
spec:
  generators:
  - matrix:
      generators:
      - list:
          elements:
          - app: frontend
          - app: backend
          - app: database
      - list:
          elements:
          - env: development
            server: https://dev-cluster.example.com
            namespace: apps-dev
            branch: develop
          - env: staging
            server: https://staging-cluster.example.com
            namespace: apps-staging
            branch: main
          - env: production
            server: https://prod-cluster.example.com
            namespace: apps-prod
            branch: release
  template:
    metadata:
      name: '{{app}}-{{env}}'
      labels:
        app.kubernetes.io/name: '{{app}}'
        app.kubernetes.io/env: '{{env}}'
    spec:
      project: applications
      source:
        repoURL: https://github.com/your-org/gitops-repo
        targetRevision: '{{branch}}'
        path: 'applications/{{app}}/overlays/{{env}}'
      destination:
        server: '{{server}}'
        namespace: '{{namespace}}'
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
        retry:
          limit: 3
          backoff:
            duration: 5s
            factor: 2
            maxDuration: 3m
      info:
        - name: 'Application'
          value: '{{app}} in {{env}}'
```

## 🔧 Erweiterte GitOps-Patterns

### 1. Progressive Delivery mit Rollouts

```yaml
# applications/frontend/base/rollout.yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: frontend
spec:
  replicas: 10
  strategy:
    canary:
      steps:
      - setWeight: 10
      - pause: {duration: 1m}
      - setWeight: 20
      - pause: {duration: 1m}
      - setWeight: 50
      - pause: {duration: 2m}
      - setWeight: 100
      analysis:
        templates:
        - templateName: success-rate
        args:
        - name: service-name
          value: frontend-service
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: frontend:latest
        ports:
        - containerPort: 8080
```

### 2. Multi-Tenant Setup mit Projects

```yaml
# infrastructure/argocd/projects/team-alpha.yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: team-alpha
  namespace: argocd
spec:
  description: "Team Alpha Applications"
  
  sourceRepos:
    - 'https://github.com/your-org/gitops-repo'
    - 'https://github.com/team-alpha/*'
  
  destinations:
    - namespace: 'team-alpha-*'
      server: https://kubernetes.default.svc
    - namespace: 'shared-services'
      server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: 'networking.k8s.io'
      kind: NetworkPolicy
  
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
  
  roles:
    - name: admin
      description: "Team Alpha Admin"
      policies:
        - p, proj:team-alpha:admin, applications, *, team-alpha/*, allow
        - p, proj:team-alpha:admin, exec, create, team-alpha/*, allow
      groups:
        - team-alpha:admins
    
    - name: developer
      description: "Team Alpha Developer"
      policies:
        - p, proj:team-alpha:developer, applications, get, team-alpha/*, allow
        - p, proj:team-alpha:developer, applications, sync, team-alpha/*, allow
      groups:
        - team-alpha:developers
  
  syncWindows:
    - kind: allow
      schedule: '0 9-17 * * MON-FRI'
      duration: 8h
      applications:
        - '*-staging'
    - kind: deny
      schedule: '0 18-8 * * *'
      duration: 14h
      applications:
        - '*-production'
```

### 3. Secret Management mit External Secrets

```yaml
# applications/backend/base/external-secret.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: backend-secrets
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: vault-backend
    kind: SecretStore
  target:
    name: backend-secrets
    creationPolicy: Owner
    template:
      type: Opaque
      data:
        DB_PASSWORD: "{{ .db_password }}"
        API_KEY: "{{ .api_key }}"
  data:
  - secretKey: db_password
    remoteRef:
      key: backend/database
      property: password
  - secretKey: api_key
    remoteRef:
      key: backend/api
      property: key
```

## 🔐 Security Best Practices

### 1. Repository Access Control

```yaml
# infrastructure/argocd/repositories/repo-credentials.yaml
apiVersion: v1
kind: Secret
metadata:
  name: private-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: https://github.com/your-org/private-gitops-repo
  password: ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
  username: git
```

### 2. RBAC Configuration

```yaml
# infrastructure/argocd/rbac/policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Global Policies
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    
    # Developer Policies
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */dev-*, allow
    p, role:developer, applications, sync, */staging-*, allow
    
    # SRE Policies  
    p, role:sre, applications, *, */*, allow
    p, role:sre, clusters, get, *, allow
    
    # Group Mappings (OIDC/SAML)
    g, your-org:admins, role:admin
    g, your-org:developers, role:developer
    g, your-org:sre, role:sre
```

### 3. Network Policies

```yaml
# infrastructure/networking/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-network-policy
  namespace: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/part-of: argocd
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-nginx
    ports:
    - protocol: TCP
      port: 8080
  egress:
  - to:
    - namespaceSelector: {}
    ports:
    - protocol: TCP
      port: 443
  - to: []
    ports:
    - protocol: TCP
      port: 53
    - protocol: UDP
      port: 53
```

## 📊 Monitoring und Observability

### 1. ArgoCD Metrics

```yaml
# infrastructure/monitoring/argocd-servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
  namespaceSelector:
    matchNames:
    - argocd
```

### 2. Grafana Dashboard

```yaml
# infrastructure/monitoring/grafana-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  argocd.json: |
    {
      "dashboard": {
        "title": "ArgoCD Overview",
        "panels": [
          {
            "title": "Application Health",
            "type": "stat",
            "targets": [
              {
                "expr": "sum(argocd_app_info{health_status!=\"Healthy\"}) by (health_status)"
              }
            ]
          },
          {
            "title": "Sync Status",
            "type": "stat", 
            "targets": [
              {
                "expr": "sum(argocd_app_info{sync_status!=\"Synced\"}) by (sync_status)"
              }
            ]
          }
        ]
      }
    }
```

### 3. Alerting Rules

```yaml
# infrastructure/monitoring/argocd-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: monitoring
spec:
  groups:
  - name: argocd
    rules:
    - alert: ArgoCDAppNotSynced
      expr: argocd_app_info{sync_status!="Synced"} == 1
      for: 15m
      labels:
        severity: warning
      annotations:
        summary: "ArgoCD Application {{ $labels.name }} is not synced"
        description: "Application {{ $labels.name }} in project {{ $labels.project }} has been out of sync for more than 15 minutes."
    
    - alert: ArgoCDAppUnhealthy
      expr: argocd_app_info{health_status!="Healthy"} == 1
      for: 10m
      labels:
        severity: critical
      annotations:
        summary: "ArgoCD Application {{ $labels.name }} is unhealthy"
        description: "Application {{ $labels.name }} in project {{ $labels.project }} is in {{ $labels.health_status }} state."
```

## 🔄 CI/CD Integration

### 1. GitHub Actions Workflow

```yaml
# .github/workflows/gitops-update.yml
name: Update GitOps Repository

on:
  push:
    branches: [main]
    paths: ['src/**']

jobs:
  update-gitops:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout Application Code
      uses: actions/checkout@v3
      
    - name: Build and Push Image
      run: |
        docker build -t myapp:${{ github.sha }} .
        docker push myapp:${{ github.sha }}
    
    - name: Update GitOps Repository
      run: |
        git clone https://github.com/your-org/gitops-repo.git
        cd gitops-repo
        
        # Update image tag in kustomization
        cd applications/myapp/overlays/staging
        kustomize edit set image myapp=myapp:${{ github.sha }}
        
        # Commit and push changes
        git config --global user.name "GitOps Bot"
        git config --global user.email "gitops-bot@example.com"
        git add .
        git commit -m "Update myapp to ${{ github.sha }}"
        git push
```

### 2. Image Updater Integration

```yaml
# applications/frontend/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  annotations:
    # ArgoCD Image Updater annotations
    argocd-image-updater.argoproj.io/image-list: frontend=myregistry/frontend
    argocd-image-updater.argoproj.io/frontend.update-strategy: latest
    argocd-image-updater.argoproj.io/frontend.allow-tags: regexp:^v[0-9]+\.[0-9]+\.[0-9]+$
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  replicas: 3
  selector:
    matchLabels:
      app: frontend
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: myregistry/frontend:v1.2.3  # Will be updated automatically
        ports:
        - containerPort: 8080
```

## 🚨 Disaster Recovery

### 1. Backup Strategy

```bash
#!/bin/bash
# scripts/backup-argocd.sh

DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="backups/argocd_${DATE}"

mkdir -p "${BACKUP_DIR}"

echo "🔄 Backing up ArgoCD configuration..."

# Backup Applications
kubectl get applications -n argocd -o yaml > "${BACKUP_DIR}/applications.yaml"

# Backup Projects
kubectl get appprojects -n argocd -o yaml > "${BACKUP_DIR}/projects.yaml"

# Backup Repositories
kubectl get secrets -n argocd -l argocd.argoproj.io/secret-type=repository -o yaml > "${BACKUP_DIR}/repositories.yaml"

# Backup ConfigMaps
kubectl get configmaps -n argocd -o yaml > "${BACKUP_DIR}/configmaps.yaml"

echo "✅ Backup completed: ${BACKUP_DIR}"
```

### 2. Restore Procedure

```bash
#!/bin/bash
# scripts/restore-argocd.sh

BACKUP_DIR=$1

if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup-directory>"
    exit 1
fi

echo "🔄 Restoring ArgoCD from ${BACKUP_DIR}..."

# Restore in order
kubectl apply -f "${BACKUP_DIR}/repositories.yaml"
kubectl apply -f "${BACKUP_DIR}/configmaps.yaml"
kubectl apply -f "${BACKUP_DIR}/projects.yaml"
kubectl apply -f "${BACKUP_DIR}/applications.yaml"

echo "✅ Restore completed from ${BACKUP_DIR}"
```

## 🛠️ Troubleshooting Guide

### Häufige Probleme und Lösungen

**1. Application Stuck in "Progressing" State**
```bash
# Check application status
kubectl describe application <app-name> -n argocd

# Check sync operation status
argocd app get <app-name> --show-operation

# Force refresh
argocd app get <app-name> --refresh

# Hard refresh (clear cache)
argocd app get <app-name> --hard-refresh
```

**2. Sync Hook Failures**
```bash
# List all resources including hooks
argocd app resources <app-name>

# Check hook logs
kubectl logs -f job/<hook-job-name> -n <namespace>

# Delete failed hook manually
kubectl delete job <hook-job-name> -n <namespace>
```

**3. Resource Permission Issues**
```bash
# Check ArgoCD controller logs
kubectl logs -f deployment/argocd-application-controller -n argocd

# Check RBAC permissions
kubectl auth can-i <verb> <resource> --as=system:serviceaccount:argocd:argocd-application-controller
```

**4. Out of Sync Resources**
```bash
# Show diff between desired and live state
argocd app diff <app-name>

# Sync specific resource
argocd app sync <app-name> --resource <group>:<kind>:<name>

# Prune unwanted resources
argocd app sync <app-name> --prune
```

### Debug Commands

```bash
# Get comprehensive application info
argocd app get <app-name> -o yaml

# Live tail application sync logs
argocd app logs <app-name> -f

# Check application events
kubectl get events --sort-by=.metadata.creationTimestamp -n argocd

# Validate YAML manifests
argocd app manifests <app-name> --dry-run

# Check repository connectivity
argocd repo get <repo-url>
```

## 📈 Performance Optimization

### 1. Resource Limits für ArgoCD

```yaml
# infrastructure/argocd/install/resource-limits.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cmd-params-cm
  namespace: argocd
data:
  # Application controller settings
  application.instanceLabelKey: argocd.argoproj.io/instance
  server.repo.server.timeout.seconds: "60"
  controller.status.processors: "20"
  controller.operation.processors: "10"
  controller.app.resync: "180"
  
  # Repository server settings
  reposerver.parallelism.limit: "20"
```

### 2. Horizontal Pod Autoscaling

```yaml
# infrastructure/argocd/scaling/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: argocd-server-hpa
  namespace: argocd
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: argocd-server
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
```

## ✅ Best Practices Checkliste

### Repository Management
- [ ] Separate Repositories für Apps und Infrastructure
- [ ] Klare Branch-Strategie (main/develop/release)
- [ ] Conventional Commits verwenden
- [ ] Pull Request Reviews obligatorisch
- [ ] Automated Tests für Manifeste

### Security
- [ ] RBAC ordnungsgemäß konfiguriert
- [ ] Secrets extern verwaltet (External Secrets)
- [ ] Network Policies implementiert
- [ ] Image Scanning aktiviert
- [ ] Regular Security Audits

### Monitoring & Observability
- [ ] Metrics erfasst und dashboards erstellt
- [ ] Alerting für kritische Events
- [ ] Logging zentralisiert
- [ ] SLOs/SLIs definiert
- [ ] Runbooks dokumentiert

### Operational Excellence
- [ ] Backup/Restore Prozeduren getestet
- [ ] Disaster Recovery Plan
- [ ] Incident Response Playbooks
- [ ] Regular Chaos Engineering
- [ ] Documentation aktuell

## 📚 Weiterführende Ressourcen

### Offizielle Dokumentation
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Kustomize Documentation](https://kustomize.io/)
- [Helm Documentation](https://helm.sh/docs/)

### Community Resources
- [ArgoCD Examples Repository](https://github.com/argoproj/argocd-example-apps)
- [Awesome GitOps](https://github.com/weaveworks/awesome-gitops)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery)

### Tools & Extensions
- [ArgoCD Image Updater](https://argocd-image-updater.readthedocs.io/)
- [ArgoCD Notifications](https://argocd-notifications.readthedocs.io/)
- [ArgoCD Vault Plugin](https://argocd-vault-plugin.readthedocs.io/)
- [Argo Rollouts](https://argoproj.github.io/argo-rollouts/)

---

## 🤝 Contributing

Wir freuen uns über Beiträge! Bitte lese unsere [Contributing Guidelines](CONTRIBUTING.md) und erstelle Pull Requests für Verbesserungen.

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe [LICENSE](LICENSE) für Details.

---

**Happy GitOps! 🚀**