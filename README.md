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
| Deploy a new version to dev | Nothing. The app repo's CI opens a `deploy(dev)` PR bumping `image.tag`; it auto-merges when CI is green |
| Promote dev to staging, or staging to prod | Actions, then **Promote**, then **Run workflow** (choose `from`). It opens a PR with a before/after tag table; merging it is the approval |
| Roll back | `git revert` the bump commit |
| Scale a service in prod | `replicaCount` in `envs/prod/services/<svc>.yaml` |
| Add an environment | New `envs/<name>/` with `data.yaml` and `services/*.yaml`, plus a namespace in `argocd/namespaces.yaml` |

## Delivery flow

```
app repo: merge to main ─> build, scan, sign sha-abc1234 ─> PR here: envs/dev tag = sha-abc1234 ─> auto-merge on green ─> Argo CD: dev
Promote workflow: dev ─> staging ─> prod   (a PR each, human merge = approval; prod never skips staging)
```

Both bots use the `GITOPS_TOKEN` secret, a fine-grained token limited to this repo (contents + pull requests). PRs opened with the default `GITHUB_TOKEN` would not trigger CI, so their required check could never pass.

## Rules (enforced by CI: `scripts/validate.sh`)

- Image tags must be immutable `sha-<commit>`, never `latest` or `main`.
- Every env/service combination must render, and everything must pass schema validation (including Argo CD and CloudNativePG CRDs).
