# ShopLite: GitOps repo

The single source of truth for what runs in the cluster. Argo CD watches `main` and makes the cluster match it. To change anything in the cluster, open a PR here. Nobody runs `kubectl apply`.

## How it fits together

```
shoplite-infra (Terraform) ── installs ──> Argo CD + root Application
                                                │ watches argocd/ on main
                                                v
argocd/projects.yaml            AppProjects "platform" and "shoplite" (guardrails)
argocd/namespaces.yaml          shoplite-dev | -staging | -prod  (Pod Security: restricted)
argocd/platform-cnpg.yaml       CloudNativePG operator
argocd/appset-environments.yaml one <env>-data + <env>-nats app per envs/<env>/ directory
argocd/appset-services.yaml     one <env>-<service> app per envs/<env>/services/<service>.yaml
```

| Path | What |
|---|---|
| `charts/shoplite-service/` | One chart for all services. Covers security context, probes, graceful shutdown, zone spread, PDB, HPA, and migrations as a PreSync hook |
| `charts/shoplite-data/` | Per-env data: a Postgres cluster **per service** (CloudNativePG), Redis, Mailpit |
| `values/<service>.yaml` | What is specific to a service (image repo, port, env, migration command) |
| `envs/<env>/services/<service>.yaml` | What differs per environment, above all the **image tag** |
| `envs/<env>/data.yaml` | Data sizing per environment |
| `envs/nats-values.yaml` | NATS (JetStream) values shared by all environments |

Values are layered: chart defaults, then `values/<service>.yaml`, then `envs/<env>/services/<service>.yaml`.

## Common changes

| I want to... | Change |
|---|---|
| Deploy a new version to dev | CI does it: a PR bumping `envs/dev/services/<svc>.yaml` `image.tag` |
| Promote to staging / prod | PR copying the tag into `envs/staging/...` / `envs/prod/...` |
| Roll back | `git revert` the bump commit |
| Scale a service in prod | `replicaCount` in `envs/prod/services/<svc>.yaml` |
| Add an environment | New `envs/<name>/` with `data.yaml` and `services/*.yaml`, plus a namespace in `argocd/namespaces.yaml` |

## Rules (enforced by CI: `scripts/validate.sh`)

- Image tags must be immutable `sha-<commit>`, never `latest` or `main`.
- Every env/service combination must render, and everything must pass schema validation (including Argo CD and CloudNativePG CRDs).
