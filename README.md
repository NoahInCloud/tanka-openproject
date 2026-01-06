# Tanka OpenProject PoC

This repo mirrors the Kustomize PoC but uses Tanka/Jsonnet to express per-environment differences for OpenProject, Postgres, and Memcached. Jsonnet libraries (`lib/`) centralize defaults, while `environments/{test,prod}` supply overrides and `rendered/{test,prod}` hold pre-exported YAML for ArgoCD.

## Layout

```
openproject-project/
  jsonnetfile*.json   # jb dependencies (k8s-libsonnet)
  lib/                # shared Jsonnet libraries
  memcached|openproject|postgres/
    environments/{test,prod}/main.jsonnet
    rendered/{test,prod}/manifests.yaml
  vendor/             # populated by jb install
```

## ArgoCD app mapping (Tanka)

| App | Path | Revision | Namespace |
| --- | --- | --- | --- |
| lhw-openproject-memcached-test | `openproject-project/memcached/rendered/test` | `Test` | `lhw-openproject-test` |
| lhw-openproject-memcached-prod | `openproject-project/memcached/rendered/prod` | `Production` | `lhw-openproject-prod` |
| lhw-openproject-openproject-test | `openproject-project/openproject/rendered/test` | `Test` | `lhw-openproject-test` |
| lhw-openproject-openproject-prod | `openproject-project/openproject/rendered/prod` | `Production` | `lhw-openproject-prod` |
| lhw-openproject-postgres-test | `openproject-project/postgres/rendered/test` | `Test` | `lhw-openproject-test` |
| lhw-openproject-postgres-prod | `openproject-project/postgres/rendered/prod` | `Production` | `lhw-openproject-prod` |

## How to render

```bash
cd openproject-project

# Update deps (if needed)
jb install

# Render to the ArgoCD-consumed paths
tk export memcached/rendered/test memcached/environments/test
tk export memcached/rendered/prod memcached/environments/prod
tk export openproject/rendered/test openproject/environments/test
tk export openproject/rendered/prod openproject/environments/prod
tk export postgres/rendered/test postgres/environments/test
tk export postgres/rendered/prod postgres/environments/prod
```

## Vault Agent Injector

`lib/openproject.libsonnet` injects `vault.hashicorp.com/*` annotations so Vault Agent renders `/vault/secrets/db` at runtime. Override `config.vaultRole` or `config.vaultSecretPath` per environment inside `environments/*/main.jsonnet`.

## Branches

- `main`: source of truth for the PoC
- `Test`: matches test ArgoCD targetRevision
- `Production`: matches prod ArgoCD targetRevision
