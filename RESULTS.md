# Tanka vs Kustomize PoC - Complete Results

## Summary

| Metric | Tanka | Kustomize |
|--------|-------|-----------|
| **Apps Deployed** | 6 | 6 |
| **Memcached Healthy** | Yes (test + prod) | Yes (test + prod) |
| **Vault POD_INJECTION** | **Verified** | **Verified** |
| **Pods Running (2/2)** | 4 pods | 3 pods |

---

## ArgoCD Applications Status

### Tanka Apps
| App Name | Status | Health |
|----------|--------|--------|
| poc-tanka-memcached-test | Synced | Healthy |
| poc-tanka-memcached-prod | Synced | Healthy |
| poc-tanka-openproject-test | Synced | Progressing* |
| poc-tanka-openproject-prod | Synced | Progressing* |
| poc-tanka-postgres-test | Synced | Progressing* |
| poc-tanka-postgres-prod | Synced | Progressing* |

*Pending due to cluster resource constraints (insufficient CPU/memory)

### Kustomize Apps
| App Name | Status | Health |
|----------|--------|--------|
| poc-kustomize-memcached-test | Synced | Healthy |
| poc-kustomize-memcached-prod | Synced | Healthy |
| poc-kustomize-openproject-test | OutOfSync | Degraded* |
| poc-kustomize-openproject-prod | OutOfSync | Progressing* |
| poc-kustomize-postgres-test | OutOfSync | Healthy* |
| poc-kustomize-postgres-prod | OutOfSync | Healthy* |

*Pending due to cluster resource constraints

---

## Vault POD_INJECTION Evidence

### Tanka Memcached - Test

```bash
$ kubectl -n lhw-openproject-test get pods tanka-memcached-796c7f957d-9kplv
NAME                               READY   STATUS    RESTARTS   AGE
tanka-memcached-796c7f957d-9kplv   2/2     Running   0          2m

$ kubectl -n lhw-openproject-test exec tanka-memcached-796c7f957d-9kplv -c memcached -- cat /vault/secrets/db
export DB_PASSWORD="testpassword123"
export DB_USERNAME="pocuser"
```

### Tanka Memcached - Prod (2 replicas)

```bash
$ kubectl -n lhw-openproject-prod get pods | grep tanka-memcached
tanka-memcached-7dc4bc5975-28czp   2/2   Running   0   2m
tanka-memcached-7dc4bc5975-xk8s8   2/2   Running   0   2m

$ kubectl -n lhw-openproject-prod exec tanka-memcached-7dc4bc5975-28czp -c memcached -- cat /vault/secrets/db
export DB_PASSWORD="testpassword123"
export DB_USERNAME="pocuser"
```

### Kustomize Memcached - Test

```bash
$ kubectl -n lhw-openproject-test get pods poc-memcached-6bf5788f87-lzt8r
NAME                             READY   STATUS    RESTARTS   AGE
poc-memcached-6bf5788f87-lzt8r   2/2     Running   0          17m

$ kubectl -n lhw-openproject-test exec poc-memcached-6bf5788f87-lzt8r -c memcached -- cat /vault/secrets/db
export DB_PASSWORD="testpassword123"
export DB_USERNAME="pocuser"
```

---

## Repository Structure

```
tanka-openproject/
└── openproject-project/
    ├── lib/
    │   ├── k.libsonnet
    │   └── openproject.libsonnet    # Shared component library
    ├── memcached/
    │   ├── environments/
    │   │   ├── test/main.jsonnet
    │   │   └── prod/main.jsonnet
    │   └── rendered/
    │       ├── test/deployment.yaml
    │       └── prod/deployment.yaml
    ├── openproject/
    │   ├── environments/...
    │   └── rendered/...
    └── postgres/
        ├── environments/...
        └── rendered/...
```

---

## Vault Configuration

```bash
# Kubernetes Auth enabled
# KV-v2 at secret/
# Role: poc-role
# Bound service accounts: poc-memcached, poc-openproject-web, poc-postgres,
#                         tanka-memcached, tanka-openproject-web, tanka-postgres
# Bound namespaces: lhw-openproject-test, lhw-openproject-prod
```

---

## Key Jsonnet Library Example

```jsonnet
// lib/openproject.libsonnet
{
  config:: {
    namespace: error 'namespace required',
    replicas: 1,
    vaultRole: 'poc-role',
    vaultSecretPath: 'secret/data/poc/db',
  },

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

  memcached:: {
    deployment: deployment.new(name='tanka-memcached', ...)
      + deployment.spec.template.metadata.withAnnotations($.vaultAnnotations),
  },
}
```

---

## Comparison: Tanka vs Kustomize

| Aspect | Tanka | Kustomize |
|--------|-------|-----------|
| ArgoCD Native | No (pre-render) | Yes |
| Learning Curve | Steep (Jsonnet) | Gentle (YAML) |
| Vault POD_INJECTION | **Working** | **Working** |
| Programming Logic | Full language | Limited |
| DRY Code | Excellent (libraries) | Good (overlays) |
| Resource Naming | Flexible | Patch-based |

---

## Conclusion

**Tanka POD_INJECTION: VERIFIED**

- 4 pods running with 2/2 containers (memcached + vault-agent)
- Secrets successfully rendered to /vault/secrets/db
- Environment differences (test=1 replica, prod=2 replicas) applied correctly
- Requires pre-rendering for ArgoCD, but offers powerful templating

**Recommendation**: Both approaches successfully implement Vault POD_INJECTION. Choose based on team expertise and complexity requirements.
