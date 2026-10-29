#!/usr/bin/env bash
#
# Creates labels, milestones and issues for the Cookbook project.
#
# Usage (from inside your cloned repo):
#   chmod +x create-issues.sh
#   DRY_RUN=1 ./create-issues.sh     # preview only, creates nothing
#   ./create-issues.sh               # create everything
#
# Requirements: GitHub CLI (gh), authenticated with `gh auth login`.
# Run it once on a repo that has no issues yet, so issue numbers match the plan.
# Delete this script afterwards (or keep it out of your commits).

set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
DELAY="${DELAY:-2}"   # seconds between API calls, avoids GitHub rate limits

if [[ "$DRY_RUN" != "1" ]]; then
  command -v gh >/dev/null 2>&1 || { echo "GitHub CLI (gh) is not installed: https://cli.github.com"; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "Not logged in. Run: gh auth login"; exit 1; }
  gh repo view >/dev/null 2>&1 || { echo "Run this from inside a cloned GitHub repo."; exit 1; }
fi

FOOTER=$'\n\n---\n**Definition of done:** tests written, CI green, docs and OpenAPI updated, deployed to the live environment (once it exists).'

# ---------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------
create_label() {
  local name="$1" color="$2" desc="$3"
  if [[ "$DRY_RUN" == "1" ]]; then echo "label: $name"; return; fi
  gh label create "$name" --color "$color" --description "$desc" --force >/dev/null
  echo "Label ready: $name"
}

create_milestone() {
  local title="$1" desc="$2"
  if [[ "$DRY_RUN" == "1" ]]; then echo "milestone: $title"; return; fi
  local existing
  existing="$(gh api "repos/{owner}/{repo}/milestones?state=all" --paginate --jq '.[].title')"
  if grep -Fxq "$title" <<< "$existing"; then
    echo "Milestone exists: $title"
  else
    gh api "repos/{owner}/{repo}/milestones" -f title="$title" -f description="$desc" >/dev/null
    echo "Created milestone: $title"
    sleep "$DELAY"
  fi
}

COUNT=0
issue() {
  local title="$1" labels="$2" milestone="$3"
  local body
  body="$(cat)"
  body+="$FOOTER"
  COUNT=$((COUNT + 1))
  if [[ "$DRY_RUN" == "1" ]]; then
    printf '[%02d] %s  (%s | %s)\n' "$COUNT" "$title" "$milestone" "$labels"
    return
  fi
  local args=(issue create --title "$title" --body "$body" --milestone "$milestone")
  local l
  IFS=',' read -ra LABEL_LIST <<< "$labels"
  for l in "${LABEL_LIST[@]}"; do args+=(--label "$l"); done
  gh "${args[@]}"
  sleep "$DELAY"
}

# ---------------------------------------------------------------
# Labels
# ---------------------------------------------------------------
create_label backend   1d76db "Spring Boot / Java"
create_label frontend  0e8a16 "React / TypeScript"
create_label database  fbca04 "PostgreSQL, Flyway, pgvector"
create_label ai        7057ff "LLM, embeddings, RAG, MCP"
create_label infra     5319e7 "CI/CD, Docker, deployment"
create_label testing   c2e0c6 "Unit, integration, e2e, evals"
create_label docs      0075ca "Documentation"
create_label stretch   d4c5f9 "Optional extra"

# ---------------------------------------------------------------
# Milestones
# ---------------------------------------------------------------
M0="M0: Foundations"
M1="M1: Auth and recipe CRUD"
M2="M2: AI smart import"
M3="M3: Semantic search"
M4="M4: Cook mode and assistant"
M5="M5: Meal planner and shopping list"
M6="M6: MCP server"
M7="M7: Quality and polish"

create_milestone "$M0" "Empty but fully wired skeleton, built, tested and deployed on every push."
create_milestone "$M1" "A logged-in user can create, view, edit, delete and filter their own recipes."
create_milestone "$M2" "Turn text, URLs and photos into validated structured recipes."
create_milestone "$M3" "Find recipes by meaning and combine with normal filters."
create_milestone "$M4" "Cooking-friendly view with a chat assistant that knows the recipe."
create_milestone "$M5" "Plan a week and get one merged shopping list."
create_milestone "$M6" "Expose the cookbook to AI assistants through MCP."
create_milestone "$M7" "Observability, security, e2e tests and portfolio polish."

# ---------------------------------------------------------------
# M0: Foundations
# ---------------------------------------------------------------
issue "Set up repository and project hygiene" "infra,docs" "$M0" <<'EOF'
Make the repo look professional from the first commit.

**Tasks**
- [ ] Create the repo with plain directories (not Maven modules): `/backend`, `/frontend`, `/docs`, `/infra`. There is no parent `pom.xml` at the repo root.
- [ ] Add `.gitignore`, `.editorconfig` (repo root)
- [ ] Add `LICENSE` (MIT) and a `README.md` with the project pitch
- [ ] Add `.github/pull_request_template.md`
- [ ] Add `docs/adr/0000-record-architecture-decisions.md` (ADR template)
- [ ] Add a root `Makefile` stub (filled in as the project grows)
- [ ] Branch protection on `main`: require pull requests. Add the required CI checks after the CI issue is done (checks can only be selected once they have run).

**Acceptance criteria**
- A fresh clone has the structure above.
- Direct pushes to `main` are blocked.
EOF

issue "Spring Boot backend skeleton (Maven)" "backend" "$M0" <<'EOF'
**Tasks**
- [ ] Generate the project at start.spring.io: **Maven**, Java 21, Spring Boot 3.x, dependencies Spring Web, Validation, Actuator. Place it in `/backend` as a standalone Maven project.
- [ ] Commit the Maven Wrapper (`mvnw`, `mvnw.cmd`, `.mvn/`) and always use `./mvnw`
- [ ] Package-by-feature structure (for example `...cookbook.recipe`, `...cookbook.common`)
- [ ] Enable Actuator health endpoint; set `spring.threads.virtual.enabled=true`
- [ ] Global exception handling with `@RestControllerAdvice` returning `ProblemDetail` (RFC 7807)
- [ ] `application.yml` plus `application-local.yml`; environment-specific values come from environment variables (no secrets in files)
- [ ] Smoke test (context loads) and a MockMvc test for the error format

**Acceptance criteria**
- `GET /actuator/health` returns UP.
- An unknown route returns a structured JSON error.
- `./mvnw test` passes.
EOF

issue "PostgreSQL, Flyway and Docker Compose" "database,infra" "$M0" <<'EOF'
**Tasks**
- [ ] `docker-compose.yml` in `/infra` with Postgres using the `pgvector/pgvector` image, a named volume, credentials from environment variables, and a `pg_isready` healthcheck
- [ ] Add `flyway-core` and `flyway-database-postgresql` to `backend/pom.xml` (versions managed by the Spring Boot parent)
- [ ] Migrations in `src/main/resources/db/migration`; `V1__baseline.sql` creates a simple `users` table
- [ ] Datasource configured through environment variables (same config for local, CI and production)
- [ ] Decide the data access library (JDBI vs Spring Data JDBC) and record it in an ADR
- [ ] Root `Makefile` targets: `db-up`, `db-down`, `dev` (starts DB, then runs `./mvnw spring-boot:run -Dspring-boot.run.profiles=local` in `/backend`)

**Rule:** never edit a migration that has been applied; always add a new `V` file.

**Acceptance criteria**
- `make dev` starts the database and the app, and Flyway's history table shows V1 applied.
EOF

issue "OpenAPI-first workflow with generated TypeScript client" "backend,frontend" "$M0" <<'EOF'
**Depends on:** the React frontend skeleton issue (do that first, so there is somewhere to generate the client into).

**Tasks**
- [ ] Decide code-first (springdoc-openapi) vs spec-first, and record it in an ADR. Recommended: code-first with springdoc.
- [ ] Add one small real endpoint to test with, for example `GET /api/version`
- [ ] Export the spec to a committed file, `docs/openapi.json`. Simplest approach: a `@SpringBootTest` with MockMvc that fetches `/v3/api-docs` and writes the pretty-printed JSON, run as part of `./mvnw verify`. (Alternative: `springdoc-openapi-maven-plugin` with Spring Boot's `start`/`stop` goals; it needs a database available.)
- [ ] Configure Orval (or openapi-typescript) in `/frontend` to read `docs/openapi.json` and generate typed functions and TanStack Query hooks into `src/api/generated`
- [ ] Add a CI step that regenerates the spec and client and runs `git diff --exit-code`

**Acceptance criteria**
- Adding a field to a response DTO changes the generated TypeScript types.
- The frontend calls `/api/version` through the generated hook.
- CI fails if the committed spec or client is stale.
EOF

issue "React frontend skeleton" "frontend" "$M0" <<'EOF'
**Tasks**
- [ ] Vite + React + TypeScript with strict mode in `/frontend`
- [ ] Tailwind and shadcn/ui
- [ ] TanStack Router and TanStack Query configured
- [ ] ESLint, Prettier and Vitest set up (Prettier reads `.editorconfig`)
- [ ] App shell: layout, navigation, dark mode
- [ ] One sample component test

**Acceptance criteria**
- The app shell renders; lint, type-check and the sample test pass.
EOF

issue "CI pipeline with GitHub Actions" "infra,testing" "$M0" <<'EOF'
**Tasks**
- [ ] Backend job: `actions/setup-java` (distribution `temurin`, Java 21, `cache: maven`); run `./mvnw -B verify` with `working-directory: backend` (unit tests plus Testcontainers integration tests)
- [ ] Frontend job: install, lint, type-check, test, build
- [ ] Contract check: regenerate the OpenAPI spec and client, then `git diff --exit-code`
- [ ] Run on pull requests and on pushes to `main`; use path filters so docs-only changes skip heavy jobs
- [ ] Add status badges to the README
- [ ] Afterwards, add the CI jobs as required checks in the `main` branch protection

**Acceptance criteria**
- A PR shows both jobs, and a deliberately failing test blocks merging.
EOF

issue "First deployment" "infra" "$M0" <<'EOF'
**Tasks**
- [ ] Multi-stage Dockerfiles for backend and frontend
- [ ] Choose a host (Fly.io, Railway, Render or a small VPS such as Hetzner) and record the reasoning in an ADR. Check current pricing first, since free tiers change often.
- [ ] Managed or containerised Postgres with pgvector support
- [ ] Secrets configured through the host's secret store, not in the repo
- [ ] CD job deploys `main` after CI passes
- [ ] Put the live URL in the README

**Acceptance criteria**
- Pushing to `main` updates the live site.
EOF

# ---------------------------------------------------------------
# M1: Auth and recipe CRUD
# ---------------------------------------------------------------
issue "Authentication with OIDC (backend)" "backend" "$M1" <<'EOF'
**Tasks**
- [ ] Spring Security resource server validating JWTs from Keycloak, Auth0 or Clerk
- [ ] Map the token subject to a `users` row on first login
- [ ] Secure all endpoints except health and API docs
- [ ] ADR: which identity provider and why

**Acceptance criteria**
- Requests without a valid token get 401.
- The authenticated user is available in controllers.
EOF

issue "Login flow (frontend)" "frontend" "$M1" <<'EOF'
**Tasks**
- [ ] OIDC login and logout (authorization code with PKCE)
- [ ] Attach the token to the generated API client; handle expiry and refresh
- [ ] Protected routes and a user menu

**Acceptance criteria**
- Unauthenticated users are redirected to login; logout clears the session.
EOF

issue "Recipe domain model and migrations" "database,backend" "$M1" <<'EOF'
**Tasks**
- [ ] Tables: `users`, `recipes`, `recipe_ingredients`, `recipe_steps`, `tags`, `recipe_tags`
- [ ] Ingredients stored structured: quantity, unit, name, optional note
- [ ] Steps stored ordered, with an optional timer duration
- [ ] Constraints and indexes; schema changes only through Flyway migrations
- [ ] ADR: how units and quantities are modeled (the meal planner relies on this)
- [ ] ER diagram in `/docs`

**Acceptance criteria**
- Migrations apply cleanly on an empty database; the ER diagram matches the schema.
EOF

issue "Recipe CRUD API" "backend" "$M1" <<'EOF'
**Tasks**
- [ ] Endpoints: create, get, list (paginated), update, delete
- [ ] Ownership enforced: users only see and change their own recipes
- [ ] Bean Validation on request DTOs; DTOs as Java records
- [ ] OpenAPI annotations and examples; regenerate `docs/openapi.json` and the TypeScript client

**Acceptance criteria**
- All endpoints documented in OpenAPI.
- Ownership violations return a consistent 404 or 403.
EOF

issue "Integration tests for the recipe API" "backend,testing" "$M1" <<'EOF'
**Tasks**
- [ ] Testcontainers with a real Postgres (pgvector image)
- [ ] Name integration tests `*IT` so the Maven Failsafe plugin runs them in `./mvnw verify`, while fast unit tests stay in `./mvnw test`
- [ ] Cover happy paths, validation errors, ownership rules and pagination

**Acceptance criteria**
- Tests run in CI in a few minutes and are not flaky.
EOF

issue "Recipe list and detail UI" "frontend" "$M1" <<'EOF'
**Tasks**
- [ ] Recipe list with cards, loading, empty and error states
- [ ] Detail page with ingredients and steps
- [ ] TanStack Query for fetching and cache invalidation

**Acceptance criteria**
- A recipe created through the API appears in the UI without a manual refresh strategy.
EOF

issue "Recipe create and edit form" "frontend" "$M1" <<'EOF'
**Tasks**
- [ ] Form with dynamic ingredient and step rows (add, remove, reorder)
- [ ] Zod schema wired to React Hook Form through the Zod resolver
- [ ] Inline validation errors; optimistic updates where sensible

**Acceptance criteria**
- Invalid data cannot be submitted; edits persist.
EOF

issue "Tags and filtering" "backend,frontend" "$M1" <<'EOF'
**Tasks**
- [ ] Add and remove tags on a recipe
- [ ] Filter the list by tag, cook time and text
- [ ] Reflect filters in the URL (TanStack Router search params)

**Acceptance criteria**
- Filtered views can be shared by URL.
EOF

# ---------------------------------------------------------------
# M2: AI smart import
# ---------------------------------------------------------------
issue "LLM client abstraction" "backend,ai" "$M2" <<'EOF'
**Tasks**
- [ ] Introduce Spring AI or LangChain4j behind your own `RecipeExtractor` interface
- [ ] Provider, model and API key configured through environment variables
- [ ] Timeouts, retries with backoff, and a clear error type for provider failures
- [ ] ADR: Spring AI vs LangChain4j

**Acceptance criteria**
- The provider can be swapped by configuration; provider failures do not crash requests.
EOF

issue "Recipe extraction schema and prompt" "backend,ai" "$M2" <<'EOF'
**Tasks**
- [ ] JSON schema matching the recipe model (quantity, unit, name, note, steps, times)
- [ ] Use structured output or tool calling to constrain the model
- [ ] Validate the result server-side; on failure retry once, feeding the validation error back
- [ ] Keep prompts in versioned files, not inline strings

**Acceptance criteria**
- Malformed model output is either repaired or rejected with a useful error.
EOF

issue "Import from pasted text" "backend,frontend,ai" "$M2" <<'EOF'
**Tasks**
- [ ] `POST /imports` accepts raw text and returns a draft recipe (not yet saved)
- [ ] Frontend import page with a textarea and progress state

**Acceptance criteria**
- A typical recipe text yields a draft the user can open in the editor.
EOF

issue "Import from URL" "backend,ai" "$M2" <<'EOF'
**Tasks**
- [ ] Fetch the page and extract the main content; prefer `schema.org/Recipe` JSON-LD when present, fall back to the LLM
- [ ] Protect against SSRF: block private IP ranges, limit redirects, response size and timeouts
- [ ] Keep the source URL on the recipe for attribution

**Acceptance criteria**
- Works on several popular recipe sites; internal addresses are rejected.
EOF

issue "Import from photo" "backend,frontend,ai" "$M2" <<'EOF'
**Tasks**
- [ ] Image upload with size and type limits, sent to a vision-capable model
- [ ] Handle handwritten recipe cards and photographed cookbook pages
- [ ] Store originals with a clear retention policy

**Acceptance criteria**
- A photographed recipe card becomes a structured draft.
EOF

issue "Draft review screen" "frontend" "$M2" <<'EOF'
**Tasks**
- [ ] Show the draft side by side with the source (text, page or image)
- [ ] Highlight low-confidence or missing fields (for example an ingredient without a unit)
- [ ] Save into the normal recipe model only after the user confirms

**Acceptance criteria**
- Nothing imported is stored without user review.
EOF

issue "Import evaluation harness" "ai,testing" "$M2" <<'EOF'
**Tasks**
- [ ] Collect 20 to 30 test inputs (text, saved URL fixtures, photos) with hand-written expected output
- [ ] Script that measures ingredient accuracy, step count match and schema validity rate
- [ ] Write a report to `/docs/evals/` and put the headline score in the README
- [ ] Run manually or on a schedule, not on every PR (saves cost)

**Acceptance criteria**
- One command prints scores, so prompt or model changes can be compared with numbers.
EOF

# ---------------------------------------------------------------
# M3: Semantic search
# ---------------------------------------------------------------
issue "Enable pgvector and add embeddings column" "database" "$M3" <<'EOF'
**Tasks**
- [ ] Flyway migration: `CREATE EXTENSION IF NOT EXISTS vector`, add a vector column and an HNSW index
- [ ] ADR: embedding model and dimension

**Acceptance criteria**
- A vector similarity query runs in an integration test.
EOF

issue "Embedding pipeline" "backend,ai" "$M3" <<'EOF'
**Tasks**
- [ ] Build an embedding text per recipe (title, description, ingredients, tags)
- [ ] Generate on create and update, asynchronously (virtual threads or a simple job queue)
- [ ] Backfill job for existing recipes; re-embed when the model changes

**Acceptance criteria**
- Every recipe has a current embedding; failures are retried and logged.
EOF

issue "Hybrid search endpoint" "backend" "$M3" <<'EOF'
**Tasks**
- [ ] Combine vector similarity with SQL filters (tags, time, dietary flags)
- [ ] Optionally merge with Postgres full-text rank using reciprocal rank fusion
- [ ] Return a relevance score for debugging

**Acceptance criteria**
- A query like "quick chicken dinner" returns sensible results with filters applied.
EOF

issue "Search UI" "frontend" "$M3" <<'EOF'
**Tasks**
- [ ] Search bar with debounce, filter chips and result cards
- [ ] Empty state and a "no good match" state

**Acceptance criteria**
- Natural language queries and filter combinations work from the UI.
EOF

# ---------------------------------------------------------------
# M4: Cook mode and assistant
# ---------------------------------------------------------------
issue "Cook mode UI" "frontend" "$M4" <<'EOF'
**Tasks**
- [ ] Full-screen, large-text step view with next and previous
- [ ] Screen wake lock; step timers that can run in parallel
- [ ] Ingredient checklist

**Acceptance criteria**
- Usable on a phone in a kitchen; timers survive moving between steps.
EOF

issue "Deterministic serving scaler" "backend,frontend" "$M4" <<'EOF'
**Tasks**
- [ ] Scale ingredient quantities by servings in code, not with the LLM
- [ ] Sensible rounding rules (for example 0.33 becomes 1/3)

**Acceptance criteria**
- Unit tests cover fractions, rounding and unit edge cases.
EOF

issue "Streaming chat endpoint" "backend,ai" "$M4" <<'EOF'
**Tasks**
- [ ] `POST /recipes/{id}/chat` streaming tokens over SSE
- [ ] System prompt grounded in the recipe, instructed to say when it is unsure
- [ ] Limit conversation length; handle client disconnects and cancel the upstream call

**Acceptance criteria**
- The first token arrives quickly, and cancelling stops provider usage.
EOF

issue "Chat UI with streaming" "frontend" "$M4" <<'EOF'
**Tasks**
- [ ] Consume the SSE stream and render tokens progressively, with Markdown support
- [ ] Quick suggestions (substitutions, scaling, technique questions)
- [ ] Error and retry states

**Acceptance criteria**
- Works smoothly on slow connections and handles stream errors.
EOF

issue "Tool use for the assistant" "backend,ai,stretch" "$M4" <<'EOF'
**Tasks**
- [ ] Give the model tools: scale recipe, convert units, look up another recipe in the cookbook
- [ ] Log tool calls for debugging

**Acceptance criteria**
- "Double this and convert to grams" uses the tools instead of guessing.
EOF

# ---------------------------------------------------------------
# M5: Meal planner and shopping list
# ---------------------------------------------------------------
issue "Unit and ingredient normalization" "backend,database" "$M5" <<'EOF'
**Tasks**
- [ ] Unit table with type (mass, volume, count) and conversion factors
- [ ] Canonical ingredient names (for example "plain flour" and "all-purpose flour")
- [ ] Optional: LLM-assisted mapping with human confirmation

**Acceptance criteria**
- Conversions are covered by unit tests, including incompatible-unit cases.
EOF

issue "Meal plan model and API" "backend,database" "$M5" <<'EOF'
**Tasks**
- [ ] Meal plan with dated slots (day and meal type) pointing at recipes and servings
- [ ] CRUD endpoints with ownership rules

**Acceptance criteria**
- A week plan can be created, edited and fetched.
EOF

issue "Shopping list aggregation" "backend" "$M5" <<'EOF'
**Tasks**
- [ ] Merge ingredients across planned recipes, combining compatible units
- [ ] Keep incompatible entries separate rather than guessing
- [ ] Support ticking items off, manual items and excluding pantry staples

**Acceptance criteria**
- "200 g flour + 1 cup flour" becomes a single correct quantity.
EOF

issue "Planner and shopping list UI" "frontend" "$M5" <<'EOF'
**Tasks**
- [ ] Weekly calendar with drag and drop of recipes
- [ ] Shopping list grouped by category, usable on mobile

**Acceptance criteria**
- A user can plan a week and check items off in the store.
EOF

# ---------------------------------------------------------------
# M6: MCP server
# ---------------------------------------------------------------
issue "MCP server with core tools" "backend,ai" "$M6" <<'EOF'
**Tasks**
- [ ] Implement an MCP server (Spring AI MCP or the Java SDK)
- [ ] Tools: `search_recipes`, `get_recipe`, `create_meal_plan`, `get_shopping_list`
- [ ] Authenticate with a per-user token

**Acceptance criteria**
- An MCP-capable client can search your recipes and build a plan.
EOF

issue "MCP documentation and demo" "docs" "$M6" <<'EOF'
**Tasks**
- [ ] Setup guide with a screenshot or short GIF of an assistant using the tools

**Acceptance criteria**
- A reader can connect a client in under 5 minutes.
EOF

# ---------------------------------------------------------------
# M7: Quality and polish
# ---------------------------------------------------------------
issue "Structured logging and OpenTelemetry" "backend,infra" "$M7" <<'EOF'
**Tasks**
- [ ] JSON logs with request and trace IDs
- [ ] OpenTelemetry traces for HTTP, database and LLM calls
- [ ] Optional: Grafana stack in Docker Compose

**Acceptance criteria**
- One import request can be followed end to end in a trace.
EOF

issue "LLM cost and latency tracking" "backend,ai" "$M7" <<'EOF'
**Tasks**
- [ ] Record model, tokens in and out, latency and estimated cost per call
- [ ] Simple admin view or dashboard
- [ ] Per-user daily limits to protect the budget

**Acceptance criteria**
- The average cost of an import can be stated with a number.
EOF

issue "Rate limiting and abuse protection" "backend" "$M7" <<'EOF'
**Tasks**
- [ ] Limit expensive endpoints (import, chat); in-memory first, Redis optional
- [ ] Input size limits
- [ ] Prompt-injection mitigations: treat fetched page content as data, not instructions

**Acceptance criteria**
- Limits are tested and return 429 with a retry hint.
EOF

issue "End-to-end tests with Playwright" "testing,frontend" "$M7" <<'EOF'
**Tasks**
- [ ] Cover critical flows: login, create recipe, import from text (mocked LLM), search
- [ ] Run in CI with traces and screenshots kept on failure

**Acceptance criteria**
- The e2e job is green and stable.
EOF

issue "Security and dependency hygiene" "infra" "$M7" <<'EOF'
**Tasks**
- [ ] Dependabot or Renovate (Maven and npm), secret scanning, CodeQL
- [ ] Review CORS, security headers and file upload handling

**Acceptance criteria**
- No open high-severity alerts.
EOF

issue "Documentation and portfolio polish" "docs" "$M7" <<'EOF'
**Tasks**
- [ ] README: pitch, live demo link, screenshots or GIFs, architecture diagram, feature list, eval results
- [ ] Architecture and import pipeline diagrams (Mermaid works on GitHub)
- [ ] ADR index, local setup guide, link to API docs
- [ ] A short "what I would do next" section

**Acceptance criteria**
- A recruiter can understand the project in two minutes.
EOF

issue "Kubernetes deployment (stretch)" "infra,stretch" "$M7" <<'EOF'
**Tasks**
- [ ] Manifests or a Helm chart; deploy to k3s on a small VPS
- [ ] Ingress, secrets, readiness and liveness probes

**Acceptance criteria**
- The app runs on the cluster and the README documents how.
EOF

echo
if [[ "$DRY_RUN" == "1" ]]; then
  echo "Dry run finished: $COUNT issues would be created."
else
  echo "Done: $COUNT issues created."
fi
