# GitOps Enterprise Setup - ArgoCD mit SSO/OAuth2

Ein produktionsreifer GitOps-Setup mit ArgoCD, SSO-Integration und allen notwendigen Enterprise-Features.

## 🏗️ Enterprise GitOps Architektur

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              GitOps Enterprise Stack                            │
├─────────────────┬─────────────────┬─────────────────┬─────────────────────────────┤
│   Identity      │   GitOps Core   │   Monitoring    │      Security               │
│                 │                 │                 │                             │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────────┐ │
│ │    Keycloak │ │ │   ArgoCD    │ │ │ Prometheus  │ │ │    Falco Security       │ │
│ │     or      │ │ │             │ │ │   Grafana   │ │ │   Network Policies      │ │
│ │  Azure AD   │ │ │ App of Apps │ │ │  AlertMgr   │ │ │   Pod Security          │ │
│ │     or      │ │ │ApplicationSet│ │ │   Loki      │ │ │   External Secrets      │ │
│ │   GitHub    │ │ │Image Updater│ │ │             │ │ │                         │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │ └─────────────────────────┘ │
├─────────────────┼─────────────────┼─────────────────┼─────────────────────────────┤
│   Git Repos     │   CI/CD         │   Ingress       │   Backup & DR               │
│                 │                 │                 │                             │
│ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────┐ │ ┌─────────────────────────┐ │
│ │ App Configs │ │ │GitHub Actions│ │ │NGINX Ingress│ │ │    Velero Backup        │ │
│ │Infrastructure│ │ │  or GitLab  │ │ │Cert-Manager │ │ │   Disaster Recovery     │ │
│ │   Policies  │ │ │  or Jenkins │ │ │   External  │ │ │   Multi-Cluster Sync    │ │
│ │             │ │ │             │ │ │    DNS      │ │ │                         │ │
│ └─────────────┘ │ └─────────────┘ │ └─────────────┘ │ └─────────────────────────┘ │
└─────────────────┴─────────────────┴─────────────────┴─────────────────────────────┘
```

## 📁 Complete Enterprise Repository Structure

```
gitops-enterprise/
├── README.md
├── .github/
│   ├── workflows/
│   │   ├── validate-manifests.yml
│   │   ├── security-scan.yml
│   │   ├── sync-environments.yml
│   │   └── disaster-recovery.yml
│   └── CODEOWNERS
├── docs/
│   ├── architecture/
│   ├── runbooks/
│   ├── security/
│   └── troubleshooting/
├── bootstrap/
│   ├── cluster-preparation/
│   │   ├── namespaces.yaml
│   │   ├── crds.yaml
│   │   └── operators.yaml
│   ├── argocd-installation/
│   │   ├── argocd-namespace.yaml
│   │   ├── argocd-install.yaml
│   │   ├── oauth2-proxy.yaml
│   │   └── ingress.yaml
│   ├── root-applications/
│   │   ├── infrastructure-root.yaml
│   │   ├── security-root.yaml
│   │   ├── monitoring-root.yaml
│   │   └── applications-root.yaml
│   └── scripts/
│       ├── bootstrap-cluster.sh
│       ├── setup-sso.sh
│       └── validate-setup.sh
├── infrastructure/
│   ├── identity/
│   │   ├── keycloak/
│   │   │   ├── base/
│   │   │   └── overlays/
│   │   ├── oauth2-proxy/
│   │   └── external-dns/
│   ├── networking/
│   │   ├── ingress-nginx/
│   │   ├── cert-manager/
│   │   ├── external-dns/
│   │   └── network-policies/
│   ├── monitoring/
│   │   ├── prometheus-stack/
│   │   ├── loki-stack/
│   │   ├── jaeger/
│   │   └── dashboards/
│   ├── security/
│   │   ├── falco/
│   │   ├── external-secrets/
│   │   ├── pod-security-policies/
│   │   ├── gatekeeper/
│   │   └── trivy-operator/
│   ├── backup/
│   │   ├── velero/
│   │   └── etcd-backup/
│   └── storage/
│       ├── longhorn/
│       └── nfs-provisioner/
├── platform/
│   ├── argocd/
│   │   ├── projects/
│   │   ├── repositories/
│   │   ├── applications/
│   │   ├── applicationsets/
│   │   ├── notifications/
│   │   └── rbac/
│   ├── jenkins/
│   ├── sonarqube/
│   ├── nexus/
│   └── harbor/
├── applications/
│   ├── frontend/
│   │   ├── base/
│   │   ├── overlays/
│   │   │   ├── development/
│   │   │   ├── staging/
│   │   │   └── production/
│   │   └── tests/
│   ├── backend/
│   ├── database/
│   └── microservices/
├── environments/
│   ├── development/
│   ├── staging/
│   └── production/
├── policies/
│   ├── opa-gatekeeper/
│   ├── network-policies/
│   └── pod-security-standards/
├── secrets/
│   ├── external-secrets/
│   ├── sealed-secrets/
│   └── vault-integration/
└── scripts/
    ├── setup/
    ├── maintenance/
    ├── disaster-recovery/
    └── migration/
```

## 🔐 SSO/OAuth2 Integration Setup

### 1. Keycloak Identity Provider

```yaml
# infrastructure/identity/keycloak/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: identity
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:23.0.1
        args: ["start", "--optimized"]
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-admin
              key: password
        - name: KC_HOSTNAME
          value: "keycloak.example.com"
        - name: KC_HOSTNAME_STRICT_HTTPS
          value: "true"
        - name: KC_HTTP_ENABLED
          value: "true"
        - name: KC_PROXY
          value: "edge"
        - name: KC_DB
          value: "postgres"
        - name: KC_DB_URL
          value: "jdbc:postgresql://postgres:5432/keycloak"
        - name: KC_DB_USERNAME
          value: "keycloak"
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgres-credentials
              key: password
        ports:
        - containerPort: 8080
          name: http
        readinessProbe:
          httpGet:
            path: /realms/master
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
        livenessProbe:
          httpGet:
            path: /realms/master
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 30
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: identity
spec:
  selector:
    app: keycloak
  ports:
  - port: 8080
    targetPort: 8080
    name: http
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: identity
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/proxy-buffer-size: "128k"
    nginx.ingress.kubernetes.io/proxy-buffers-number: "4"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - keycloak.example.com
    secretName: keycloak-tls
  rules:
  - host: keycloak.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
```

### 2. Keycloak Realm Configuration

```yaml
# infrastructure/identity/keycloak/base/realm-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: keycloak-realm-config
  namespace: identity
data:
  gitops-realm.json: |
    {
      "realm": "gitops",
      "enabled": true,
      "displayName": "GitOps Platform",
      "loginWithEmailAllowed": true,
      "duplicateEmailsAllowed": false,
      "resetPasswordAllowed": true,
      "editUsernameAllowed": false,
      "bruteForceProtected": true,
      "permanentLockout": false,
      "maxFailureWaitSeconds": 900,
      "minimumQuickLoginWaitSeconds": 60,
      "waitIncrementSeconds": 60,
      "quickLoginCheckMilliSeconds": 1000,
      "maxDeltaTimeSeconds": 43200,
      "failureFactor": 30,
      "defaultRoles": ["default-roles-gitops"],
      "requiredCredentials": ["password"],
      "passwordPolicy": "length(8) and digits(1) and lowerCase(1) and upperCase(1) and specialChars(1)",
      "groups": [
        {
          "name": "admins",
          "path": "/admins"
        },
        {
          "name": "developers",
          "path": "/developers"
        },
        {
          "name": "sre",
          "path": "/sre"
        },
        {
          "name": "viewers",
          "path": "/viewers"
        }
      ],
      "clients": [
        {
          "clientId": "argocd",
          "name": "ArgoCD",
          "enabled": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "argocd-client-secret-here",
          "redirectUris": [
            "https://argocd.example.com/auth/callback",
            "https://argocd.example.com/applications"
          ],
          "webOrigins": ["https://argocd.example.com"],
          "protocol": "openid-connect",
          "fullScopeAllowed": true,
          "protocolMappers": [
            {
              "name": "groups",
              "protocol": "openid-connect",
              "protocolMapper": "oidc-group-membership-mapper",
              "config": {
                "claim.name": "groups",
                "jsonType.label": "String",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "userinfo.token.claim": "true"
              }
            }
          ]
        },
        {
          "clientId": "grafana",
          "name": "Grafana",
          "enabled": true,
          "clientAuthenticatorType": "client-secret",
          "secret": "grafana-client-secret-here",
          "redirectUris": [
            "https://grafana.example.com/login/generic_oauth"
          ],
          "webOrigins": ["https://grafana.example.com"],
          "protocol": "openid-connect"
        }
      ],
      "identityProviders": [
        {
          "alias": "github",
          "displayName": "GitHub",
          "providerId": "github",
          "enabled": true,
          "config": {
            "clientId": "your-github-oauth-app-id",
            "clientSecret": "your-github-oauth-app-secret",
            "syncMode": "IMPORT"
          },
          "mappers": [
            {
              "name": "github-group-mapper",
              "identityProviderMapper": "github-group-mapper",
              "config": {
                "syncMode": "INHERIT",
                "group": "/developers"
              }
            }
          ]
        }
      ]
    }
```

### 3. ArgoCD OIDC Configuration

```yaml
# platform/argocd/base/argocd-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-cm
  namespace: argocd
data:
  # OIDC Configuration
  oidc.config: |
    name: Keycloak
    issuer: https://keycloak.example.com/realms/gitops
    clientId: argocd
    clientSecret: $oidc.keycloak.clientSecret
    requestedScopes: ["openid", "profile", "email", "groups"]
    requestedIDTokenClaims: {"groups": {"essential": true}}
    logoutURL: https://keycloak.example.com/realms/gitops/protocol/openid-connect/logout?redirect_uri=https://argocd.example.com
  
  # URL Configuration
  url: https://argocd.example.com
  
  # Application in any namespace
  application.instanceLabelKey: argocd.argoproj.io/instance
  
  # Server Configuration
  server.insecure: false
  server.grpc.web: true
  
  # Repository Configuration
  repositories: |
    - type: git
      url: https://github.com/your-org/gitops-enterprise
      name: gitops-main
    - type: git
      url: https://github.com/your-org/applications
      name: applications
    - type: helm
      url: https://charts.bitnami.com/bitnami
      name: bitnami
    - type: helm
      url: https://prometheus-community.github.io/helm-charts
      name: prometheus-community
  
  # Resource Customizations
  resource.customizations: |
    networking.k8s.io/Ingress:
      health.lua: |
        hs = {}
        hs.status = "Healthy"
        return hs
    
    argoproj.io/Application:
      health.lua: |
        hs = {}
        if obj.status ~= nil then
          if obj.status.health ~= nil then
            hs.status = obj.status.health.status
            if obj.status.health.message ~= nil then
              hs.message = obj.status.health.message
            end
          end
        end
        return hs
  
  # Exec Configuration
  exec.enabled: true
  
  # Accounts Configuration
  accounts.admin: apiKey, login
  accounts.developer: login
  accounts.sre: apiKey, login
  accounts.viewer: login

---
apiVersion: v1
kind: Secret
metadata:
  name: argocd-secret
  namespace: argocd
type: Opaque
stringData:
  # OIDC Client Secret
  oidc.keycloak.clientSecret: "argocd-client-secret-here"
  
  # Server Secret Key
  server.secretkey: "your-server-secret-key-here"
  
  # Admin Password (bcrypt hash)
  admin.password: "$2a$10$rRyBsGSHK6.uc8fntPwVIuLVHgsAhAX7TcdrqW/RADU9TpY4.BN."
  admin.passwordMtime: "2024-01-01T00:00:00Z"
```

### 4. ArgoCD RBAC Configuration

```yaml
# platform/argocd/rbac/argocd-rbac-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: argocd-rbac-cm
  namespace: argocd
data:
  policy.default: role:readonly
  policy.csv: |
    # Global Admin Policy (from Keycloak admins group)
    p, role:admin, applications, *, */*, allow
    p, role:admin, clusters, *, *, allow
    p, role:admin, repositories, *, *, allow
    p, role:admin, accounts, *, *, allow
    p, role:admin, projects, *, *, allow
    p, role:admin, logs, get, *, allow
    p, role:admin, exec, create, */*, allow
    
    # SRE Policy (from Keycloak sre group)
    p, role:sre, applications, *, */*, allow
    p, role:sre, clusters, get, *, allow
    p, role:sre, repositories, get, *, allow
    p, role:sre, projects, get, *, allow
    p, role:sre, logs, get, *, allow
    p, role:sre, exec, create, */production-*, deny
    p, role:sre, exec, create, */*, allow
    
    # Developer Policy (from Keycloak developers group)
    p, role:developer, applications, get, */*, allow
    p, role:developer, applications, sync, */development-*, allow
    p, role:developer, applications, sync, */staging-*, allow
    p, role:developer, applications, action/*, */development-*, allow
    p, role:developer, applications, action/*, */staging-*, allow
    p, role:developer, logs, get, */development-*, allow
    p, role:developer, logs, get, */staging-*, allow
    p, role:developer, exec, create, */development-*, allow
    p, role:developer, repositories, get, *, allow
    p, role:developer, projects, get, *, allow
    
    # Viewer Policy (from Keycloak viewers group)
    p, role:viewer, applications, get, */*, allow
    p, role:viewer, repositories, get, *, allow
    p, role:viewer, projects, get, *, allow
    p, role:viewer, logs, get, */*, allow
    
    # Project-specific policies
    p, role:project-alpha-admin, applications, *, project-alpha/*, allow
    p, role:project-alpha-dev, applications, get, project-alpha/*, allow
    p, role:project-alpha-dev, applications, sync, project-alpha/*-dev, allow
    p, role:project-alpha-dev, applications, sync, project-alpha/*-staging, allow
    
    # Group mappings (mapped from OIDC groups claim)
    g, /admins, role:admin
    g, /sre, role:sre  
    g, /developers, role:developer
    g, /viewers, role:viewer
    
    # User-specific mappings (for service accounts or specific users)
    g, argocd-image-updater, role:image-updater
    g, ci-cd-service, role:ci-cd
    
    # Project-specific group mappings
    g, /project-alpha-admins, role:project-alpha-admin
    g, /project-alpha-devs, role:project-alpha-dev
  
  scopes: '[groups, email, profile]'
```

### 5. OAuth2 Proxy for Additional Security

```yaml
# infrastructure/identity/oauth2-proxy/base/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: identity
spec:
  replicas: 2
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
    spec:
      containers:
      - name: oauth2-proxy
        image: quay.io/oauth2-proxy/oauth2-proxy:v7.5.1
        args:
        - --config=/etc/oauth2-proxy/oauth2-proxy.cfg
        ports:
        - containerPort: 4180
          name: http
        volumeMounts:
        - name: config
          mountPath: /etc/oauth2-proxy
        env:
        - name: OAUTH2_PROXY_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: client-secret
        - name: OAUTH2_PROXY_COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-secret
              key: cookie-secret
        livenessProbe:
          httpGet:
            path: /ping
            port: 4180
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 4180
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: config
        configMap:
          name: oauth2-proxy-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: oauth2-proxy-config
  namespace: identity
data:
  oauth2-proxy.cfg: |
    # OAuth Provider
    provider = "oidc"
    oidc_issuer_url = "https://keycloak.example.com/realms/gitops"
    client_id = "oauth2-proxy"
    
    # Upstream Configuration
    upstreams = [
      "http://argocd-server.argocd.svc.cluster.local:80/",
      "http://grafana.monitoring.svc.cluster.local:3000/"
    ]
    
    # Server Configuration
    http_address = "0.0.0.0:4180"
    reverse_proxy = true
    
    # Session Configuration
    cookie_secure = true
    cookie_httponly = true
    cookie_samesite = "lax"
    cookie_domains = [".example.com"]
    cookie_name = "_oauth2_proxy"
    
    # Security Configuration
    skip_provider_button = false
    pass_basic_auth = false
    pass_access_token = true
    pass_user_headers = true
    set_authorization_header = true
    set_xauthrequest = true
    
    # Logging
    silence_ping_logging = true
    
    # Email domains (or set to * for all)
    email_domains = ["*"]
    
    # Scopes
    scope = "openid email profile groups"
    
    # Custom headers
    set_authorization_header = true
    pass_authorization_header = true
```

## 🚀 Bootstrap Scripts

### 1. Complete Cluster Bootstrap

```bash
#!/bin/bash
# bootstrap/scripts/bootstrap-cluster.sh

set -euo pipefail

# Configuration
CLUSTER_NAME=${CLUSTER_NAME:-"gitops-cluster"}
DOMAIN=${DOMAIN:-"example.com"}
KEYCLOAK_ADMIN_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD:-$(openssl rand -base64 32)}
ARGOCD_ADMIN_PASSWORD=${ARGOCD_ADMIN_PASSWORD:-$(openssl rand -base64 32)}

echo "🚀 Starting GitOps Enterprise Cluster Bootstrap"
echo "Cluster: $CLUSTER_NAME"
echo "Domain: $DOMAIN"

# Function to wait for deployment
wait_for_deployment() {
    local namespace=$1
    local deployment=$2
    echo "⏳ Waiting for $deployment in $namespace to be ready..."
    kubectl wait --for=condition=available --timeout=600s deployment/$deployment -n $namespace
}

# Function to wait for pods
wait_for_pods() {
    local namespace=$1
    local label=$2
    echo "⏳ Waiting for pods with label $label in $namespace..."
    kubectl wait --for=condition=ready --timeout=600s pods -l $label -n $namespace
}

# Step 1: Create namespaces
echo "📁 Creating namespaces..."
kubectl apply -f bootstrap/cluster-preparation/namespaces.yaml

# Step 2: Install CRDs and Operators
echo "🔧 Installing CRDs and Operators..."
kubectl apply -f bootstrap/cluster-preparation/crds.yaml
kubectl apply -f bootstrap/cluster-preparation/operators.yaml

# Step 3: Install Cert-Manager
echo "🔐 Installing Cert-Manager..."
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.13.2 \
  --set installCRDs=true

wait_for_deployment cert-manager cert-manager
wait_for_deployment cert-manager cert-manager-webhook
wait_for_deployment cert-manager cert-manager-cainjector

# Step 4: Install Ingress NGINX
echo "🌐 Installing Ingress NGINX..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=LoadBalancer

wait_for_deployment ingress-nginx ingress-nginx-controller

# Step 5: Setup Let's Encrypt ClusterIssuer
echo "📜 Setting up Let's Encrypt ClusterIssuer..."
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF

# Step 6: Install External Secrets Operator
echo "🔑 Installing External Secrets Operator..."
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm upgrade --install external-secrets external-secrets/external-secrets \
  --namespace external-secrets \
  --create-namespace

wait_for_deployment external-secrets external-secrets

# Step 7: Setup PostgreSQL for Keycloak
echo "🗄️ Installing PostgreSQL for Keycloak..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm upgrade --install postgres bitnami/postgresql \
  --namespace identity \
  --create-namespace \
  --set auth.postgresPassword="$KEYCLOAK_ADMIN_PASSWORD" \
  --set auth.database="keycloak" \
  --set auth.username="keycloak" \
  --set auth.password="$KEYCLOAK_ADMIN_PASSWORD"

wait_for_deployment identity postgres-postgresql

# Step 8: Create Keycloak secrets
echo "🔐 Creating Keycloak secrets..."
kubectl create secret generic keycloak-admin \
  --namespace=identity \
  --from-literal=password="$KEYCLOAK_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic postgres-credentials \
  --namespace=identity \
  --from-literal=password="$KEYCLOAK_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

# Step 9: Install Keycloak
echo "👤 Installing Keycloak..."
kubectl apply -f infrastructure/identity/keycloak/base/

wait_for_deployment identity keycloak

# Step 10: Install ArgoCD
echo "🔄 Installing ArgoCD..."
kubectl create secret generic argocd-secret \
  --namespace=argocd \
  --from-literal=oidc.keycloak.clientSecret="argocd-client-secret-here" \
  --from-literal=server.secretkey="$(openssl rand -base64 32)" \
  --from-literal=admin.password="$(htpasswd -bnBC 10 "" $ARGOCD_ADMIN_PASSWORD | tr -d ':\n')" \
  --from-literal=admin.passwordMtime="$(date +%Y-%m-%dT%H:%M:%SZ)" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f bootstrap/argocd-installation/

wait_for_deployment argocd argocd-server
wait_for_deployment argocd argocd-application-controller
wait_for_deployment argocd argocd-repo-server

# Step 11: Install ArgoCD CLI
echo "🛠️ Installing ArgoCD CLI..."
if ! command -v argocd &> /dev/null; then
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

# Step 12: Deploy Root Applications (App of Apps)
echo "🌱 Deploying Root Applications..."
kubectl apply -f bootstrap/root-applications/

# Step 13: Wait for core infrastructure
echo "⏳ Waiting for core infrastructure to be ready..."
sleep 30

# Check ArgoCD applications
echo "📊 Checking ArgoCD application status..."
argocd login argocd.$DOMAIN --username admin --password "$ARGOCD_ADMIN_PASSWORD" --insecure

# Step 14: Setup monitoring
echo "📊 Setting up monitoring stack..."
# This will be handled by ArgoCD applications

# Step 15: Configure DNS (if using external-dns)
echo "🌍 Configuring DNS..."
# This will be handled by ArgoCD applications

echo "✅ Bootstrap complete!"
echo ""
echo "🎯 Access Information:"
echo "ArgoCD: https://argocd.$DOMAIN"
echo "ArgoCD Admin Password: $ARGOCD_ADMIN_PASSWORD"
echo "Keycloak: https://keycloak.$DOMAIN"
echo "Keycloak Admin Passwor