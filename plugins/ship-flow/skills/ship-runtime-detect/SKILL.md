---
name: ship-runtime-detect
description: Resolves the runtime tool (13 ecosystems — bun/pnpm/yarn/npm/cargo/go/python/ruby/elixir/jvm/make/shell/dart) from project context via Step R1 config probe, Step R2 README frontmatter override, Step R3 command lookup, and Step R4 LLM fallback. Produces `detected_stacks[]` and `{commands.test/build/typecheck/lint/dev/prettier}` consumed by ship-shape, ship-plan, ship-execute, and ship-verify. Auto-discovered by directory presence — no manifest edit.
---

# Ship-Runtime-Detect — Runtime Tool Resolution

Canonical source for stack detection across the ship-flow pipeline. Callers (ship-shape, ship-plan, ship-execute, ship-verify) reference this skill at their former "Runtime Detection Preamble" location with a call-site-specific purpose line. Consolidated by entity #075 preamble-extraction (slot 046f, harness-diet cut principle #2 — script-mediate / single-source).

## Contract

**Produces** (shell variables callers consume after running Step R1-R3):

| Variable | Shape | Description |
|----------|-------|-------------|
| `detected_stacks[]` | bash array | Stack identifiers — `bun`, `pnpm`, `yarn`, `npm`, `cargo`, `go`, `python`, `ruby`, `elixir`, `jvm`, `make`, `shell`, `dart` |
| `{commands.test}` | string | Test runner command |
| `{commands.build}` | string | Build command |
| `{commands.typecheck}` | string | Static type check |
| `{commands.lint}` | string | Linter |
| `{commands.dev}` | string (optional) | Dev server (not all callers need this) |
| `{commands.prettier}` | string (optional) | Formatter |
| `monorepo_detected` | bool | True when pnpm-workspace/turbo/lerna/nx config present |

**Polyglot mode**: if `detected_stacks` has multiple entries, callers list ALL detected stacks' commands and select per-file based on which files the entity touches.

**Override precedence**: workflow README frontmatter `commands:` block > Step R3 table defaults.

**Tier 2 fallback**: when Step R1 returns empty, Step R4 scans file extensions + CI configs + imports and produces an inferred stack profile for captain confirmation.

## Runtime Detection Preamble

Resolve the runtime tool by reading the project context, then populate the variables declared in the Contract above for consumption by the caller stage.

### Step R1: Detect Stacks

Scan for config files in the project root (check ALL — project may be polyglot):

```bash
detected_stacks=()

# JS/TS ecosystem
ls bun.lock bun.lockb 2>/dev/null && detected_stacks+=("bun")
ls pnpm-lock.yaml 2>/dev/null && detected_stacks+=("pnpm")
ls yarn.lock 2>/dev/null && detected_stacks+=("yarn")
ls package-lock.json 2>/dev/null && detected_stacks+=("npm")

# Systems languages
ls Cargo.toml 2>/dev/null && detected_stacks+=("cargo")
ls go.mod 2>/dev/null && detected_stacks+=("go")

# Python ecosystem
ls pyproject.toml requirements.txt Pipfile 2>/dev/null | head -1 | grep -q . && detected_stacks+=("python")

# Ruby
ls Gemfile 2>/dev/null && detected_stacks+=("ruby")

# Elixir
ls mix.exs 2>/dev/null && detected_stacks+=("elixir")

# Java/Kotlin
ls build.gradle build.gradle.kts pom.xml 2>/dev/null | head -1 | grep -q . && detected_stacks+=("jvm")

# Make-based
ls Makefile GNUmakefile makefile 2>/dev/null | head -1 | grep -q . && detected_stacks+=("make")

# Shell scripts (use shellcheck)
ls *.sh 2>/dev/null | head -1 | grep -q . && detected_stacks+=("shell")

# Dart/Flutter
ls pubspec.yaml 2>/dev/null && detected_stacks+=("dart")

echo "detected_stacks: ${detected_stacks[@]}"
[ ${#detected_stacks[@]} -eq 0 ] && echo "runner=unknown"
```

**Monorepo hint** (check after stack detection):
```bash
ls pnpm-workspace.yaml turbo.json lerna.json nx.json 2>/dev/null | head -1 | grep -q . && \
  echo "monorepo detected — scope commands to relevant workspace"
```

### Step R2: Check README Frontmatter Override

Read the workflow README at `docs/{workflow}/README.md`. If the frontmatter contains a `commands:` block, those values override auto-detection:

```yaml
commands:
  test: "npm test"           # overrides auto-detected test command
  build: "npm run build"     # overrides auto-detected build command
  typecheck: "npx tsc --noEmit"
  lint: "npm run lint"
  dev: "npm run dev"
```

### Step R3: Resolve Commands Per Stack

If `detected_stacks` contains exactly one entry → single-runner mode (backward-compatible):

| Variable | bun | pnpm | yarn | npm | cargo | go | python | ruby | elixir | jvm | make | shell | dart |
|----------|-----|------|------|-----|-------|----|--------|------|--------|-----|------|-------|------|
| `{commands.test}` | `bun test` | `pnpm test` | `yarn test` | `npm test` | `cargo test` | `go test ./...` | `pytest` | `bundle exec rspec` | `mix test` | `./gradlew test` or `mvn test` | `make test` | `shellcheck *.sh` | `dart test` |
| `{commands.build}` | `bun build` | `pnpm run build` | `yarn run build` | `npm run build` | `cargo build` | `go build ./...` | `python -m build` | `gem build` | `mix compile` | `./gradlew build` or `mvn package` | `make build` | N/A | `dart compile` |
| `{commands.typecheck}` | `bunx tsc --noEmit` | `pnpm exec tsc --noEmit` | `yarn dlx tsc --noEmit` | `npx tsc --noEmit` | `cargo check` | `go vet ./...` | `mypy .` | N/A | `mix dialyzer` | N/A | N/A | N/A | `dart analyze` |
| `{commands.lint}` | `bun lint` | `pnpm run lint` | `yarn run lint` | `npm run lint` | `cargo clippy` | `go vet ./...` | `ruff check .` | `rubocop` | `mix credo` | `./gradlew lint` | `make lint` | `shellcheck *.sh` | `dart analyze` |
| `{commands.dev}` | `bun dev` | `pnpm run dev` | `yarn run dev` | `npm run dev` | N/A | N/A | N/A | N/A | `mix phx.server` | N/A | `make dev` | N/A | `dart run` |
| `{commands.prettier}` | `bunx prettier` | `pnpm exec prettier` | `yarn dlx prettier` | `npx prettier` | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

If `detected_stacks` contains **multiple entries** (polyglot project):
- List ALL detected stacks and their commands in the response
- Do NOT pick one — list all:
  ```
  Detected stacks: python, make, bun
  - python: test=pytest, lint=ruff check ., typecheck=mypy .
  - make: test=make test, lint=make lint, build=make build
  - bun: test=bun test, lint=bun lint, build=bun build
  ```
- Agent selects the relevant stack(s) based on which files the entity touches
- If entity touches Python files → use python commands; if it touches Makefile → use make commands; etc.

If `detected_stacks` is empty → go to **Step R4: Tier 2 Fallback** (see below).

README frontmatter `commands:` takes precedence over the table above for any variable it defines.

### Step R4: Tier 2 LLM Fallback (when Tier 1 = unknown)

When `detected_stacks` is empty after Step R1:

1. **Scan file extensions** to infer language:
   ```bash
   find . -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' \
     \( -name "*.py" -o -name "*.rb" -o -name "*.ex" -o -name "*.java" \
        -o -name "*.kt" -o -name "*.sh" -o -name "*.bash" \) \
     | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10
   ```
2. **Check CI configs** as hints (not authoritative):
   ```bash
   ls .github/workflows/*.yml .circleci/config.yml .travis.yml 2>/dev/null | head -3
   ```
   If found, read the first workflow file and extract `run:` commands involving test/build/lint keywords.
3. **Check import patterns** in the largest non-test file:
   ```bash
   head -20 $(find . -maxdepth 2 -name "*.py" -o -name "*.rb" -o -name "*.ex" 2>/dev/null | head -1)
   ```
4. **Produce stack profile** and ask captain to confirm before proceeding:
   ```
   Tier 2 detection result:
   - Dominant extensions: {list from step 1}
   - CI hints: {commands found, or "none"}
   - Inferred stack: {your best guess with confidence}
   - Proposed commands: test={X}, lint={Y}, build={Z}

   Please confirm or provide correct commands via docs/{workflow}/README.md frontmatter under `commands:`.
   ```
