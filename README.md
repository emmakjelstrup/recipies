# Cookbook

A cookbook you can cook *from*. Import recipes from a pasted text, a URL or a photo of a handwritten card, and an LLM turns them into structured, validated recipes. Search by meaning ("something light and quick with chicken"), cook with a step-by-step view and a chat assistant that knows the recipe you have open, plan your week, and get one merged shopping list.

> **Status:** work in progress. Follow the [issues](../../issues) and [milestones](../../milestones) for progress.

<!-- Add when available: live demo link, screenshots or a short GIF, CI badge -->

## Features (planned)

- Recipe management with tags, filters and structured ingredients
- AI import from text, URL and photo, with a review step before saving
- Semantic and hybrid search (pgvector)
- Cook mode with timers and a streaming, recipe-aware chat assistant
- Meal planner and merged shopping list with unit normalization
- MCP server so AI assistants can use your cookbook

## Tech stack

| Area | Technologies |
|---|---|
| Backend | Java 21, Spring Boot 3, Spring Security (OIDC), Maven, Flyway |
| Frontend | React, TypeScript, Vite, TanStack Query, Zod, Tailwind, shadcn/ui |
| Data | PostgreSQL with pgvector |
| AI | LLM API with structured output, embeddings, streaming over SSE, MCP |
| Tooling | Docker Compose, GitHub Actions, Testcontainers, Vitest, Playwright |

## Repository structure

```
backend/    Spring Boot application (Maven project)
frontend/   React application (Vite)
docs/       Architecture decision records, diagrams, OpenAPI spec, evals
infra/      Docker Compose and deployment configuration
```

## Getting started

Setup instructions will grow as the project takes shape (see the foundation milestone).

### Backend

Prerequisites: JDK 21. Maven is not needed; use the Maven Wrapper (`./mvnw`), which downloads the pinned Maven version on first run.

```bash
cd backend
./mvnw test                                            # unit tests
./mvnw spring-boot:run -Dspring-boot.run.profiles=local  # run on http://localhost:8080
```

Check that it is up: `curl http://localhost:8080/actuator/health` returns `{"status":"UP",...}`.
Configuration comes from environment variables; see [`.env.example`](.env.example).

## Documentation

- [Architecture decision records](docs/adr)

## License

[MIT](LICENSE)
