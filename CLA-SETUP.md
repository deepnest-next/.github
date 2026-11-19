# CLA setup (maintainers)

How the CLA v2.0 check works across all deepnest-next repositories.

```
PR ─▶ <repo>/.github/workflows/cla.yml (pull_request_target, issue_comment)
        └─ deepnest-next/.github/.github/workflows/cla-reusable.yml@main
             ├─ GitHub App token (deepnest-cla-bot), scoped to cla-signatures + the repo
             ├─ CLA Assistant Lite → deepnest-next/cla-signatures:main signatures/cla-v2.json
             └─ all signed → label `cla-signed`  /  not signed → label removed, check red
PR ─▶ <repo>/.github/workflows/ci.yml (pull_request incl. labeled/unlabeled)
        cla-gate (needs label) ─▶ build/test jobs ─▶ ci-required (the one required check)
Public repos: ruleset "deepnest-policy" requires "cla / cla" + "ci-required".
```

| Piece | Where |
|---|---|
| CLA text | [CLA.md](CLA.md), [CLA-de.md](CLA-de.md) (German prevails) |
| Reusable check | [.github/workflows/cla-reusable.yml](.github/workflows/cla-reusable.yml) |
| Per-repo workflows | [workflow-templates/cla.yml](workflow-templates/cla.yml), [workflow-templates/ci.yml](workflow-templates/ci.yml); also in `deepnest-next/repo-template` |
| Ruleset | [rulesets/main.json](rulesets/main.json) |
| Apply to a repo | [scripts/apply-repo-policy.sh](scripts/apply-repo-policy.sh) |
| Signatures | `deepnest-next/cla-signatures` (private) |

## One-time: GitHub App `deepnest-cla-bot`

1. Go to https://github.com/organizations/deepnest-next/settings/apps/new.
   - Name: `deepnest-cla-bot`. Homepage: `https://github.com/deepnest-next`.
   - Webhook: **uncheck "Active"**.
   - Repository permissions:
     - **Contents: Read and write** (signature file)
     - **Pull requests: Read and write**
     - **Issues: Read and write** (labels)
     - Metadata: Read-only
   - "Where can this app be installed": **Only on this account**.
2. Create it. Note the **Client ID**, then generate a **private key** (`.pem`). Keep the key outside any repo.
3. Install the App on the org: **All repositories**, so new repos are covered automatically.
4. Store the credentials for public repos (org level):
   ```sh
   gh variable set CLA_APP_CLIENT_ID --org deepnest-next --visibility all --body "<client id>"
   gh secret set CLA_APP_PRIVATE_KEY --org deepnest-next --visibility all < deepnest-cla-bot.pem
   ```
   On the GitHub Free plan, org secrets and variables only reach **public** repos. The script
   sets them per repo for private repos.

## Per repo

```sh
# 1. copy the workflows (new repos from deepnest-next/repo-template already have them)
cp workflow-templates/cla.yml workflow-templates/ci.yml <repo>/.github/workflows/
sed -i 's/\$default-branch/main/' <repo>/.github/workflows/ci.yml
# 2. label + ruleset (public) or repo-level credentials (private)
scripts/apply-repo-policy.sh <repo> [deepnest-cla-bot.pem]
```

Add the repo's real jobs to `ci.yml`, each with `needs: cla-gate`, and list them in `ci-required.needs`.

## Notes

- **Private repos on GitHub Free** have no rulesets. The checks turn red, but merging is not
  blocked, so maintainers must not merge red PRs. A hard block needs the Team plan.
- **Dependabot** PRs get no Actions secrets. They skip the CLA check (skipped counts as passed),
  and `cla-gate` lets `dependabot[bot]` through.
- **Allowlist** (no signature needed): `Dexus`, `dependabot[bot]`, `renovate[bot]`,
  `github-actions[bot]` and `deepnest-cla-bot[bot]`. It is set in `cla-reusable.yml`.
- **Written signatures** (§ 31a UrhG, for major contributors): record them in
  `cla-signatures/written/README.md`. Keep the originals outside git.
- **Manual override:** a maintainer can add the `cla-signed` label by hand, for example after a
  written signature. The required `cla / cla` check still has to pass on public repos.
- **Known limit:** when an unsigned co-author pushes, a `synchronize` CI run can start before the
  CLA run removes the label. The required `cla` check still blocks merging on public repos.
