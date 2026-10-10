# ShopLite — GitOps repo

Single source of truth for what runs in the cluster. Argo CD watches this repo.

- `bootstrap/` — Argo CD app-of-apps root
- `platform/` — cluster add-ons (gateway, cert-manager, monitoring, policies...)
- `charts/` — reusable Helm chart(s) for services
- `apps/<env>/` — per-environment values; image tags are bumped here by CI

Promotion: dev auto-syncs; staging/prod change only via reviewed PR.
