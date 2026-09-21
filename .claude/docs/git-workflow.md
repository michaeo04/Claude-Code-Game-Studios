# Git and GitHub Workflow

Trunk-based development with GitHub as the source of truth. This is the standing
process for humans and agents; it applies to every session.

## Principles

- `main` is the trunk. Docs on it stay consistent with each other (registry,
  systems index, review logs) and, once code exists, the build and tests pass.
- **No direct pushes to `main`.** (The one exception is the baseline import of the
  first 13 commits on 2026-09-21.) All work goes through a short-lived branch and a
  pull request, then the branch is deleted.
- One logical change per branch and per PR. Keep design, code, tooling and assets in
  separate PRs so each can be reviewed, reverted and understood alone.
- A branch lives for one unit of work (about two days at most). Long-running branches
  are a smell: split the work.

## Branch naming

`<type>/<short-kebab-description>`, where `<type>` is a Conventional Commit type:
`feat`, `fix`, `docs`, `chore`, `test`, `refactor`, `hotfix`.

Examples: `docs/ball-movement-gdd`, `feat/tilt-core`, `fix/run-state-double-restart`,
`chore/git-workflow`. Add the story id when one exists:
`feat/EPIC-001-S02-tilt-core`.

## Commits

- Conventional Commits (coding standards): `feat:`, `fix:`, `docs:`, `chore:`,
  `test:`, `refactor:`, optionally with a scope: `docs(tilt-input): ...`.
- Subject in the imperative, at most 72 characters. The body says what changed and
  why, and references the story or design document (`Story: EPIC-001-S02` or
  `Design-Doc: design/gdd/<system>.md`), then the `Co-Authored-By` trailer for
  agent-assisted commits.
- One logical unit per commit. Commit at every natural checkpoint:
  - a GDD finished with `/design-system`;
  - a revision applied after `/design-review`;
  - a story finished with `/story-done`;
  - an ADR, a config change or a tooling change.
- Stage explicit paths. Never `git add -A` or `git add .`.
- Never commit: `production/session-state/`, `production/session-logs/`, secrets,
  `.godot/`, build output. Large binary assets need a Git LFS decision before the
  first one is added.
- **Known repo decision to revisit:** `export_presets.cfg` is currently gitignored.
  Platform Services AC-13 lints it, so when the first export preset is created,
  remove that line from `.gitignore` in the same PR. Godot keeps signing credentials
  in `.godot/export_credentials.cfg`, so the presets file itself holds no secrets.

## Pull requests

- Title is a Conventional Commit line. Use the PR template in
  `.github/PULL_REQUEST_TEMPLATE.md`.
- Open the PR as soon as the branch is pushed (a draft is fine). Link the design docs,
  stories or issues, and state what was verified and what was not.
- The project's review gates are the review skills: `/design-review` (always in a
  fresh session, never in the authoring session), `/code-review`, `/consistency-check`,
  `/smoke-check`. Record their verdicts in the PR body and in the review log.
- Read your own diff on GitHub before merging.
- Merge strategy: **squash and merge** by default (the PR title becomes the commit).
  Use **rebase and merge** when the commits are each meaningful and self-contained
  (multi-commit design PRs). No merge commits on `main`.
- Delete the branch after merging, then `git switch main && git pull --ff-only`.

## Releases and tags

- Annotated tags `vMAJOR.MINOR.PATCH` on `main` at milestone gates (`/gate-check`,
  `/release-checklist`, the release-manager agent).
- Emergency fixes use `/hotfix`: a `hotfix/<description>` branch and a PR to `main`.
- There is no long-lived `develop` branch.

## Branch protection for `main`

**Status (2026-09-21):** not enabled. GitHub returns HTTP 403 ("Upgrade to GitHub Pro
or make this repository public") for branch protection on a private repository on the
Free plan. What is enabled: automatic deletion of head branches after merge. Until
protection is available, the rules below are enforced by discipline, and the local
`.claude/hooks/validate-push.sh` warns on any push to `main` (uncomment its `exit 2`
line to make Claude Code block such pushes; that does not stop a push made outside
Claude Code). Options to get real enforcement: GitHub Pro, or a public repository.

Recommended settings once available:

- Require a pull request before merging (0 required approvals while solo).
- Require conversations to be resolved; require linear history.
- Block force pushes and branch deletion.
- Require status checks once CI exists (tests and lints from `/test-setup`).
- Delete head branches automatically after merge.

## Agent rules (standing authorization from the user, 2026-09-21)

Do without asking again:
- Create a feature branch, commit at the checkpoints above, push the branch, open or
  update the PR.

Ask first, every time:
- Merging a PR, or any push to `main`.
- Force push, amending or rebasing published commits, deleting remote branches.
- Creating tags or releases.
- Changing branch protection or any repository setting; adding or changing remotes.

Never: `--no-verify`, committing session state or secrets, pushing to the `template`
remote.

Session start: run `git status` and `git branch`. If on `main` with uncommitted work,
create the branch first. If the previous PR was merged, `git switch main && git pull
--ff-only` before starting.

## Remotes

- `origin`: the project repository on GitHub (private).
- `template`: the upstream Claude Code Game Studios framework. Read-only source for
  framework updates (see `UPGRADING.md`); never push to it.

## Useful commands

```bash
gh pr create --base main --title "docs: ..." --body-file <file>
gh pr view --web          # open the PR
gh pr checks              # CI status once workflows exist
gh pr merge --squash --delete-branch   # only with the user's approval
git switch main && git pull --ff-only
```
