# Tanka/Jsonnet vs Kustomize PoC - Results Documentation

## Overview

This document provides evidence and results from the proof-of-concept comparing **Tanka/Jsonnet** vs **Kustomize** for managing Kubernetes environment differences on top of Helm, with **HashiCorp Vault POD_INJECTION** integration.

**Date:** January 6, 2026
**Cluster:** AWS EKS eu-central-1
**Namespaces:** lhw-openproject-test, lhw-openproject-prod

---

## Repository Structure

```
tanka-openproject/
└── openproject-project/
    ├── lib/
    │   ├── k.libsonnet          # k8s-libsonnet import
    │   └── openproject.libsonnet # Shared component library
    ├── memcached/
    │   ├── environments/
    │   │   ├── test/
    │   │   │   ├── main.jsonnet
    │   │   │   └── spec.json
    │   │   └── prod/
    │   │       ├── main.jsonnet
    │   │       └── spec.json
    │   └── rendered/
    │       ├── test/
    │       │   └── apps-v1.Deployment-poc-memcached.yaml
    │       └── prod/
    │           └── apps-v1.Deployment-poc-memcached.yaml
    ├── openproject/
    │   └── ... (same structure)
    └── postgres/
        └── ... (same structure)
```

---

## Jsonnet Library Architecture

### Shared Library (lib/openproject.libsonnet)

```jsonnet
local k = import 'k.libsonnet';

{
  // Configuration defaults
  config:: {
    namespace: error 'namespace is required',
    replicas: 1,
    storage: '1Gi',
    vaultRole: 'poc-role',
    vaultSecretPath: 'secret/data/poc/db',
    environment: 'test',
  },

  // Vault Agent Injector annotations for POD_INJECTION
  vaultAnnotations:: {
    'vault.hashicorp.com/agent-inject': 'true',
    'vault.hashicorp.com/role': $.config.vaultRole,
    'vault.hashicorp.com/agent-inject-secret-db': $.config.vaultSecretPath,
    'vault.hashicorp.com/agent-inject-template-db': |||
      {{- with secret "%s" -}}
      export DB_PASSWORD="{{ .Data.data.password }}"
      export DB_USERNAME="{{ .Data.data.username }}"
      {{- end }}
    ||| % $.config.vaultSecretPath,
  },

  // Common labels
  commonLabels:: {
    'app.kubernetes.io/managed-by': 'tanka',
    'app.kubernetes.io/part-of': 'openproject-poc',
    environment: $.config.environment,
  },

  // Memcached component
  memcached:: {
    deployment: deployment.new(...)
      + deployment.spec.template.metadata.withAnnotations($.vaultAnnotations),
    service: service.new(...),
  },
}
```

### Environment-Specific Configuration

```jsonnet
// environments/test/main.jsonnet
local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-test',
    replicas: 1,
    environment: 'test',
  },

  deployment: $.memcached.deployment,
  service: $.memcached.service,
}
```

```jsonnet
// environments/prod/main.jsonnet
local lib = import '../../../lib/openproject.libsonnet';

lib {
  config+:: {
    namespace: 'lhw-openproject-prod',
    replicas: 2,
    storage: '10Gi',
    environment: 'production',
  },

  deployment: $.memcached.deployment,
  service: $.memcached.service,
}
```

---

## ArgoCD Integration

### Pre-rendering Requirement

Tanka requires pre-rendering for ArgoCD (native Tanka support not available):

```bash
# Render manifests for each environment
tk export openproject-project/memcached/rendered/test \
   openproject-project/memcached/environments/test

tk export openproject-project/memcached/rendered/prod \
   openproject-project/memcached/environments/prod
```

### Application Configuration

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: poc-tanka-memcached-test
  namespace: argocd
spec:
  project: default
  destination:
    namespace: lhw-openproject-test
    server: https://kubernetes.default.svc
  source:
    repoURL: https://github.com/NoahInCloud/tanka-openproject.git
    targetRevision: Test
    path: openproject-project/memcached/rendered/test  # Pre-rendered YAML
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

## Vault POD_INJECTION Configuration

### Vault Annotations in Jsonnet

```jsonnet
vaultAnnotations:: {
  'vault.hashicorp.com/agent-inject': 'true',
  'vault.hashicorp.com/role': $.config.vaultRole,
  'vault.hashicorp.com/agent-inject-secret-db': $.config.vaultSecretPath,
  'vault.hashicorp.com/agent-inject-template-db': |||
    {{- with secret "%s" -}}
    export DB_PASSWORD="{{ .Data.data.password }}"
    export DB_USERNAME="{{ .Data.data.username }}"
    {{- end }}
  ||| % $.config.vaultSecretPath,
},
```

### Rendered Output

```yaml
# rendered/test/apps-v1.Deployment-poc-memcached.yaml
spec:
  template:
    metadata:
      annotations:
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/role: "poc-role"
        vault.hashicorp.com/agent-inject-secret-db: "secret/data/poc/db"
        vault.hashicorp.com/agent-inject-template-db: |
          {{- with secret "secret/data/poc/db" -}}
          export DB_PASSWORD="{{ .Data.data.password }}"
          export DB_USERNAME="{{ .Data.data.username }}"
          {{- end }}
```

---

## Comparison Summary

| Aspect | Tanka/Jsonnet | Notes |
|--------|---------------|-------|
| **ArgoCD Native Support** | No | Requires pre-rendering to YAML |
| **Learning Curve** | High | Jsonnet is a full programming language |
| **Vault POD_INJECTION** | Validated | Annotations programmatically generated |
| **Environment Overlays** | Via Jsonnet inheritance | `config+::` pattern |
| **Helm Integration** | Via jsonnet-libs | Can import Helm chart definitions |
| **Git Branching** | Works well | Different branches for different environments |

---

## Key Findings

### Tanka Advantages
1. **Full programming language** - conditionals, loops, functions
2. **Type-safe configuration** - Jsonnet validates at render time
3. **DRY principle** - shared libraries reduce duplication
4. **Vault annotations as code** - can template secret paths programmatically
5. **Reusable components** - one library serves all environments

### Tanka Limitations
1. **ArgoCD pre-rendering** - must `tk export` before commit
2. **Steeper learning curve** - Jsonnet syntax not familiar to all
3. **Tooling required** - need jb (jsonnet-bundler), tk installed
4. **Rendered YAML in Git** - manifests stored twice (source + rendered)

---

## Tested Use Cases

| Use Case | Tested | Evidence |
|----------|--------|----------|
| Create/extend Helm-like structures | Yes | Jsonnet library with k8s-libsonnet |
| Integrate HashiCorp Vault (POD_INJECTION) | **Validated** | Annotations in rendered YAML |
| Environment-specific configuration | Yes | config+:: overrides |
| ArgoCD GitOps deployment | Yes | Via pre-rendered manifests |
| Branch-based deployments | Yes | Test/Production branches |

---

## Commands for Verification

```bash
# Render manifests locally
tk show openproject-project/memcached/environments/test

# Export to rendered/ directory
tk export openproject-project/memcached/rendered/test \
   openproject-project/memcached/environments/test

# Validate Jsonnet syntax
jsonnet openproject-project/memcached/environments/test/main.jsonnet

# Check ArgoCD app status
kubectl -n argocd get applications | grep poc-tanka
```

---

## Tanka vs Kustomize Decision Matrix

| Criteria | Tanka | Kustomize | Winner |
|----------|-------|-----------|--------|
| ArgoCD integration | Pre-render needed | Native | Kustomize |
| Configuration complexity | High | Low-Medium | Kustomize |
| Programmatic logic | Full language | Limited | Tanka |
| Learning curve | Steep | Gentle | Kustomize |
| Vault integration | Both work | Both work | Tie |
| Maintenance | Libraries to maintain | Patches to maintain | Tie |
| Helm chart wrapping | Native Jsonnet | Pre-render required | Tie |

---

## Conclusion

**Tanka/Jsonnet is validated** for the following capabilities:
- Programmatic environment configuration
- Vault Agent Injector annotations (POD_INJECTION mode)
- ArgoCD deployment (via pre-rendered manifests)
- Reusable component libraries

**Recommendation**: For teams familiar with programming concepts and needing complex logic, Tanka provides powerful templating. For simpler use cases, Kustomize offers a lower barrier to entry with native ArgoCD support.
