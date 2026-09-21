# Git and GitHub Workflow

Two long-lived branches, `dev` and `main`, with GitHub as the source of truth. This is
the standing process for humans and agents; it applies to every session. The repository
is public.

## Model

- **`dev`** is where the work happens (design, code, tests). Commit and push directly to
  it. It should stay coherent (docs consistent with each other; once code exists, it
  should run and its tests should be runnable), but a short-lived broken state is
  acceptable.
- **`main`** is the stable, known-good line and the public face of the repository. It
  only receives merges from `dev`, when a milestone is finished or the tests are OK.
  Releases are tagged on `main`.
- Optional **short-lived branches** (`type/short-description`, cut from `dev`, merged
  back into `dev`, then deleted) for risky or experimental work. No PR is needed for
  these; a local merge is fine.
- Throwaway prototypes stay in `prototypes/`, isolated from `src/`.

## Daily flow

1. `git switch dev && git pull --ff-only`
2. Work. Commit at every checkpoint (below).
3. `git push origin dev` after each completed unit of work, so nothing stays local.
4. When a milestone is done or the tests pass: open a PR from `dev` to `main`
   (`gh pr create --base main --head dev`), review the diff, and merge with a **merge
   commit** (keep the history; do not squash; never delete `dev`). Tag the release on
   `main` if it is a milestone.
5. Sync back: `git switch dev && git pull origin main --ff-only` (or
   `git merge --ff-only origin/main`).

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
  credentials, keystores, personal data, `.godot/`, build output. The repository is
  public, so anything committed is visible. Large binary assets need a Git LFS decision
  before the first one is added.
- The commit author email is public. To use GitHub's private address instead, set
  `git config user.email <id>+<username>@users.noreply.github.com` (past commits keep
  the address they were made with).
- **Known repo decision to revisit:** `export_presets.cfg` is currently gitignored.
  Platform Services AC-13 lints it, so when the first export preset is created, remove
  that line from `.gitignore` in the same commit. Godot keeps signing credentials in
  `.godot/export_credentials.cfg`, so the presets file itself holds no secrets.

## Reviews

The review gates are the review skills: `/design-review` (always in a fresh session,
never in the authoring session), `/code-review`, `/consistency-check`, `/smoke-check`.
Record their verdicts in the review logs. For the `dev` to `main` PR, read the diff on
GitHub and state in the PR body what was verified and what was not (see the PR
template).

## Releases and tags

- Annotated tags `vMAJOR.MINOR.PATCH` on `main` after a `dev` to `main` merge, at
  milestone gates (`/gate-check`, `/release-checklist`, the release-manager agent).
- Emergency fixes use `/hotfix`: a `hotfix/<description>` branch cut from `main`, a PR
  to `main`, then merge `main` back into `dev`.

## Branch protection (applied 2026-09-21)

- `main`: a pull request is required to merge (0 required approvals, since the project
  is solo); force pushes and branch deletion are blocked; the owner (admin) can still
  bypass in an emergency. Linear history is not required, so merge commits are allowed.
- `dev`: force pushes and branch deletion are blocked; direct pushes are allowed.
- "Delete head branch on merge" is off, because a PR from `dev` must never delete `dev`.
  Delete short-lived branches by hand (`git branch -d`, `git push origin --delete`).
- Required status checks are added once CI exists (tests and lints from `/test-setup`).

## Agent rules (standing authorization from the user, 2026-09-21)

Do without asking again:
- Work on `dev` (or a short-lived branch cut from it), commit at the checkpoints above,
  and `git push origin dev` after each completed unit.

Ask first, every time:
- Merging into `main` (the `dev` to `main` PR or any push to `main`).
- Force push or rewriting published history (`dev` is published).
- Creating tags or releases.
- Changing branch protection or any repository setting; adding or changing remotes;
  changing repository visibility; deleting remote branches.

Never: `--no-verify`, committing session state or secrets, pushing to the `template`
remote.

Session start: run `git status` and `git branch`. Work on `dev`: `git switch dev && git
pull --ff-only` (uncommitted changes carry over when the switch is clean). If `main`
moved (a `dev` to `main` merge), sync `dev` as in step 5 above.

## Remotes

- `origin`: the project repository on GitHub (public), `michaeo04/Claude-Code-Game-Studios`.
- `template`: the upstream Claude Code Game Studios framework. Read-only source for
  framework updates (see `UPGRADING.md`); never push to it.

## Useful commands

```bash
git switch dev && git pull --ff-only          # start of a session
git push origin dev                           # after each completed unit
gh pr create --base main --head dev           # milestone: dev -> main (ask first)
gh pr view --web                              # open the PR
git switch dev && git pull origin main --ff-only   # sync dev after the merge
```
