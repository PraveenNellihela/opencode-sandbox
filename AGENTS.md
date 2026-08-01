# AGENTS.md

Guidance for AI agents working in this repository.

## Third-Party Integration Gate (MANDATORY)

This project bundles third-party skills, plugins, and MCP servers into a
distributed Docker image. Bundling is **redistribution**, so licensing must be
verified BEFORE any integration work starts.

For every new third-party skill, plugin, or MCP server:

1. **Check the license first.** Look at the upstream repo's `LICENSE` file,
   package metadata (`package.json` / README), or the skill's frontmatter. Do
   not skip this step.

2. **Classify the license:**
   - **Allowed (requires attribution):** MIT, Apache-2.0, BSD, ISC, CC0,
     Unlicense.
   - **Not allowed:** GPL/AGPL/LGPL (copyleft), non-commercial terms (CC-BY-NC
     etc.), "no redistribution" clauses, proprietary, or **no license stated
     at all**. Unknown or missing license = do not integrate.

3. **Check attribution requirements.** Apache-2.0 work may include a `NOTICE`
   file that must travel with the redistribution; MIT requires retaining the
   copyright notice.

4. **If allowed:** the integration MUST include all of:
   - The upstream `LICENSE` (and `NOTICE` file, if any) copied into the image
     next to the integrated files (see Dockerfile skill steps).
   - A README entry under "Third-party licenses" crediting the project, its
     license, and its author.
   - CI verification that the license file exists in the built image.

5. **If not allowed:** do not integrate. No workarounds, no "it's just markdown"
   exceptions — the skill content itself is still someone's copyrighted work.

If the license is ambiguous, ask the user before proceeding.

## Documentation Discipline

Every change to this repo must keep docs and instructions in sync. When a
feature, flag, or default changes, update ALL of the following that are
affected, in the same change:

- `README.md` (flag tables, feature lists, "What --recommended Includes",
  plugin/skill bullets, "Third-party licenses" table).
- `install.sh` help text and interactive-mode prompts.
- CI matrix and test expectations (see "Extending the project").
- This file, if the change alters how the project is built or extended.

If a change makes a doc statement stale, fix it; do not ship drift.

## Non-Affiliation Note

The opencode project requires any project using "opencode" as part of its name
to state in its README that it is not built by or affiliated with the OpenCode
team. This project's README carries that note; keep it present whenever the
README is restructured.

## Architecture Overview

- **Build flow:** `install.sh` parses flags -> `docker build --build-arg ...`
  -> the Dockerfile passes build args through as `ENV` ->
  `scripts/configure-opencode.sh` generates `~/.config/opencode/opencode.json`
  from the `preconfig/opencode.json` template and seeds agents -> optional
  skill clone steps -> opencode install (see Conventions).
- **Build args:** `INSTALL_NODE`, `INSTALL_PYTHON`, `INSTALL_GO`,
  `INSTALL_CLI_TOOLS`, `OPCODE_PLUGINS`, `OPCODE_MCP`, `OPCODE_AGENTS`.
- **Runtime:** image `local:opencode`, runs as non-root `dev` user,
  `ENTRYPOINT ["opencode"]`. The `opencode` wrapper (repo root) mounts the
  current directory at `/home/dev/workspace` and the volumes:
  - `opencode-config` -> `~/.config/opencode` (settings, plugins, agents, skills)
  - `opencode-data` -> `~/.local/share/opencode` (auth tokens, sessions)
- **Seeding gotcha:** volumes are only seeded when empty. Repo changes to
  config/agents/skills do NOT appear in existing installs until
  `docker volume rm opencode-config opencode-data` and a rebuild.
- `install.sh -p` accepts plugins AND skills. Skill names are skipped in
  `scripts/configure-opencode.sh` (they are not `opencode.json` plugins) and
  installed by the Dockerfile into `~/.config/opencode/skills/`.

## Extending the Project

### Adding a new skill (e.g. the next impeccable/emil)

1. Run the Third-Party Integration Gate first; if the license is not
   permissive, stop.
2. Add a skip-case in `scripts/configure-opencode.sh` (like `impeccable`,
   `emil`) so the name is not injected as an opencode.json plugin.
3. Add a Dockerfile step: shallow clone with a retry loop (3 attempts),
   copy the skill into `/home/dev/.config/opencode/skills/`, AND copy the
   upstream `LICENSE` (+ `NOTICE.md` for Apache-2.0) next to it.
   - For large repos use `--filter=blob:none --sparse` plus
     `sparse-checkout set <dir> LICENSE NOTICE.md --skip-checks`.
4. README: add a bullet to the plugins list and a row in the
   "Third-party licenses" table.
5. CI: add a matrix entry and a "Verify ... seeded" step that asserts the
   skill AND its license files exist.
6. Tests: add a `test_configure.bats` case (skill name not injected as a
   plugin, doesn't break others) and a `test_e2e.bats` case if the skill
   goes into `--recommended`.
7. `install.sh`: add the name to help text, interactive prompt, and
   `--recommended` if it belongs there; auto-enable toolchains if the skill
   needs them (impeccable -> Node; emil -> none).

### Adding a new plugin (opencode.json)

- Map the flag name to its `opencode.json` plugin spec in
  `scripts/configure-opencode.sh`; add to `install.sh` help + interactive
  prompt + `--recommended` if desired; add a bullet in README; add a
  `test_configure.bats` case.

### Adding a new agent

- Add `preconfig/agents/<name>.md` with required frontmatter keys:
  `description`, `mode`, `temperature`, `permission`.
- Update agent-count assertions: `test/test_configure.bats`
  ("seeds all 6 agent files") and `test/test_e2e.bats` (agent file count).

### Adding a new MCP server

- Map the flag name to the `mcp` entry in `scripts/configure-opencode.sh`;
  update install.sh lists, README, and tests.

### Keeping duplicated lists in sync

`--recommended` is expressed in FOUR places that must change together:
`install.sh`, the CI matrix `recommended` entry (`.github/workflows/ci.yaml`),
`test/test_e2e.bats` recommended build args, and README. Default plugin/MCP
sets also appear in `test/fixtures/golden_{minimal,recommended}.json`.

## Testing

- `make test-lint` — shellcheck, hadolint, `bash -n`, JSON validation,
  frontmatter validation. CI always runs it; local machines may lack the
  tools (then those checks are skipped).
- `make test-unit` — bats tests (`test_configure.bats`,
  `test_install_flags.bats`, `test_wrapper.bats`), no Docker needed.
- `make test-e2e` — needs Docker; builds real images (slow,
  network-dependent).
- **Trap:** `test_install_flags.bats` and `test_wrapper.bats` HANG locally
  when the Docker daemon is running, because `install.sh`/`opencode` proceed
  into real image builds. Stub it out:
  `mkdir -p /tmp/fakedocker && printf '#!/bin/bash\nexit 1\n' > /tmp/fakedocker/docker && chmod +x /tmp/fakedocker/docker && PATH="/tmp/fakedocker:$PATH" bats ...`
  (the wrapper test needs a stub that fails `image inspect` but succeeds
  otherwise).

## Conventions

- opencode is installed at latest version (no pinning); the Dockerfile retry
  loop (5 attempts) handles transient "connection reset" download failures.
- `impeccable` requires Node.js (auto-enabled by `install.sh`); `emil` does
  not (pure markdown).
- Pre-commit hooks: shellcheck + shfmt (`.pre-commit-config.yaml`); run
  `pre-commit install` after cloning.
- Branching: `development` is the working branch; PRs target `main`.
- Run `make test-lint` and the bats unit tests before finishing; e2e tests
  need Docker.
