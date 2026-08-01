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

## Non-Affiliation Note

The opencode project requires any project using "opencode" as part of its name
to state in its README that it is not built by or affiliated with the OpenCode
team. This project's README carries that note; keep it present whenever the
README is restructured.

## Conventions

- `install.sh -p` accepts plugins AND skills (e.g. `impeccable`, `emil`).
  Skill names are skipped in `scripts/configure-opencode.sh` (they are not
  `opencode.json` plugins) and installed by the Dockerfile into
  `~/.config/opencode/skills/`.
- `impeccable` requires Node.js (auto-enabled by `install.sh`); `emil` does
  not (pure markdown).
- Run `make test-lint` and the bats unit tests before finishing; e2e tests
  need Docker.
