# GALAXY-5-MOONLANDER: Cross-Cluster Communication MVP

## Mission Understanding

**Moonlander's Core Purpose**: Enable secure kubeconfig distribution between Kubernetes clusters to support Crossplane v2 multi-cluster resource management.

**Architectural Context**: In our CozyStack → Harvey → vcluster hierarchy, moonlander solves the fundamental problem of how Crossplane running in Harvey can manage resources in neighboring clusters (vclusters, Talos root, or external clusters).

## Landing Controller Analysis

### Current Implementation Review

The `LandingReconciler` implements a elegant cross-cluster secret synchronization pattern:

```
┌─────────────────────┐    ┌─────────────────────┐    ┌─────────────────────┐
│ Parent Cluster      │    │ Moonlander          │    │ Child Cluster       │
│ (Talos Root)        │    │ (Landing Resource)  │    │ (Harvey/vcluster)   │
│                     │    │                     │    │                     │
│ kubeconfig mounted  │───▶│ 1. Read parent cfg  │───▶│ remote-kubeconfig   │
│ at runtime          │    │ 2. Get child secret │    │ secret created      │
│                     │    │ 3. Bridge the gap   │    │                     │
└─────────────────────┘    └─────────────────────┘    └─────────────────────┘
```

### MVP Workflow Analysis

**Phase 1: Basic Cross-Cluster Communication**
1. **Landing Resource Created**: Deployed on cluster where moonlander runs
2. **Child Kubeconfig Discovery**: Finds kubeconfig secret for target cluster
3. **Parent Kubeconfig Access**: Reads mounted kubeconfig from filesystem
4. **Secret Bridge Creation**: Injects parent cluster access into child cluster

**Phase 2: Crossplane Integration**
- Crossplane providers in Harvey can use `remote-kubeconfig` secret
- Enables management of resources in parent Talos cluster
- Foundation for multi-cluster GitOps workflows

## Architecture Mapping

### Current Cluster Hierarchy
```
┌─────────────────────────────────────────────────────────────────────┐
│ Talos Root Cluster (ARM64 AWS)                                     │
│ ┌─────────────────────────────────────────────────────────────────┐ │
│ │ CozyStack Platform                                              │ │
│ │ ┌─────────────────────────────────────────────────────────────┐ │ │
│ │ │ Harvey Tenant Cluster (KubeVirt VM)                        │ │ │
│ │ │ - Crossplane v2 deployment target                         │ │ │
│ │ │ - Moonlander Landing controller                            │ │ │
│ │ │ ┌─────────────────────────────────────────────────────────┐ │ │ │
│ │ │ │ vclusters: moo, mop, vcluster                          │ │ │ │
│ │ │ │ - Crossplane managed resources                         │ │ │ │
│ │ │ │ - Application deployment targets                       │ │ │ │
│ │ │ └─────────────────────────────────────────────────────────┘ │ │ │
│ │ └─────────────────────────────────────────────────────────────┘ │ │
│ └─────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### Moonlander Communication Patterns

**Pattern A: Harvey ↔ Talos Root**
```yaml
apiVersion: moons.kingdon.ci/v1alpha1
kind: Landing
metadata:
  name: talos-root-access
  namespace: harvey-system
spec:
  kubeconfigSecretName: "kubernetes-harvey-admin-kubeconfig"
  writeKubeconfigSecretName: "talos-root-kubeconfig"
  targetNamespace: "crossplane-system"
```

**Pattern B: Harvey → vcluster**
```yaml
apiVersion: moons.kingdon.ci/v1alpha1
kind: Landing
metadata:
  name: vcluster-moo-access
  namespace: harvey-system  
spec:
  kubeconfigSecretName: "vcluster-moo-admin"
  writeKubeconfigSecretName: "vcluster-moo-kubeconfig"
  targetNamespace: "crossplane-system"
```

## MVP Requirements Analysis

### Current Gaps in Landing Controller

1. **Service Account Creation**: Code assumes kubeconfig secrets exist but doesn't create them for vclusters
2. **Bootstrap Dependency**: No mechanism to handle "Planet B doesn't exist yet" scenario
3. **Deployment Manifests**: Missing CRD definitions and RBAC configuration
4. **Error Handling**: Limited retry logic for transient failures

### Required MVP Components

#### 1. CRD Definition (Missing)
```yaml
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: landings.moons.kingdon.ci
spec:
  group: moons.kingdon.ci
  versions:
  - name: v1alpha1
    served: true
    storage: true
    schema:
      openAPIV3Schema:
        type: object
        properties:
          spec:
            type: object
            properties:
              kubeconfigSecretName:
                type: string
              kubeconfigSecretNamespace:
                type: string
              writeKubeconfigSecretName:
                type: string
              targetNamespace:
                type: string
          status:
            type: object
  scope: Namespaced
  names:
    plural: landings
    singular: landing
    kind: Landing
```

#### 2. Service Account Generator Extension
```go
// Additional method needed in LandingReconciler
func (r *LandingReconciler) ensureVClusterKubeconfig(ctx context.Context, vclusterName string) error {
    // 1. Create service account in vcluster
    // 2. Create cluster role binding for admin access
    // 3. Generate token and build kubeconfig
    // 4. Store as secret for Landing controller consumption
}
```

#### 3. RBAC Configuration (Missing)
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: moonlander-landing-controller
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch", "create", "update", "patch"]
- apiGroups: ["moons.kingdon.ci"]
  resources: ["landings"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
```

## Deployment Strategy for December 3rd Demo

### Phase 0: Infrastructure Foundation (Pre-MVP)
**Dependency**: CozyStack deployed with Harvey tenant cluster operational
**Deliverable**: Basic Kubernetes cluster capable of running Crossplane v2

### Phase 1: Moonlander MVP Deployment
```bash
# Deploy moonlander CRDs and controller to Harvey
kubectl apply -f moonlander-crd.yaml
kubectl apply -f moonlander-deployment.yaml

# Create Landing resources for cross-cluster access
kubectl apply -f landing-talos-root.yaml
kubectl apply -f landing-vclusters.yaml
```

### Phase 2: Crossplane Integration Validation
```bash
# Verify Crossplane can access remote clusters via moonlander secrets
kubectl get secrets -n crossplane-system | grep kubeconfig
kubectl get providers crossplane-contrib/provider-kubernetes
```

### Phase 3: Multi-Cluster Workflow Demo
**Scenario**: Deploy application to vcluster using Crossplane running in Harvey
**Success Metric**: Resource created in remote vcluster via Crossplane composition

## Fallback Scenarios

### If KubeVirt ARM64 Fails
**Fallback A**: Deploy Harvey as namespace-based tenant instead of VM
**Fallback B**: Run Crossplane directly on Talos root cluster
**Impact**: Moonlander still valuable for vcluster communication

### If vcluster on Talos Fails  
**Fallback C**: Demonstrate cross-cluster patterns with multiple namespaces
**Fallback D**: Show Landing controller pattern with external cluster mocks
**Impact**: Core moonlander concept still demonstrable

## Conference Demo Script Foundation

### Opening (2 minutes)
"Today we're solving the hardest problem in Kubernetes: secure cross-cluster communication for GitOps workflows."

### Architecture Overview (3 minutes)
- Show cluster hierarchy diagram
- Explain why kubeconfig distribution is critical
- Introduce moonlander as the solution

### Live Demo (15 minutes)
1. **Deploy Landing Resource** (2 min): Create cross-cluster bridge
2. **Crossplane Integration** (8 min): Show resource management across clusters
3. **Validation** (5 min): Verify resources deployed successfully

### Wrap-up (5 minutes)
- Discuss scaling to production workloads
- Roadmap for expanded moonlander features
- Community engagement and contribution opportunities

## Technical Debt and Production Readiness

### Immediate Improvements Needed
- [ ] Complete CRD and RBAC manifests
- [ ] Service account automation for vclusters
- [ ] Error handling and retry logic
- [ ] Deployment automation (Helm chart)

### Post-MVP Enhancements
- [ ] Webhook validation for Landing resources
- [ ] Status reporting and observability
- [ ] Multi-tenancy and security hardening
- [ ] Integration with ArgoCD/Flux for GitOps

---

**MVP Success Criteria**: 
- Landing controller successfully bridges kubeconfig between two clusters
- Crossplane v2 can manage resources across cluster boundaries
- Demo-ready deployment on ARM64 CozyStack infrastructure
- Conference presentation material validated with live deployment

**Galaxy Positioning**: Moonlander sits between infrastructure (Stakpak/Claude Desktop work) and latest builds, providing the essential cross-cluster communication foundation for advanced GitOps workflows.