# AGENTS.md

This file provides guidance to AI agents when working with code in this repository.

## Project Overview

This is a Buildkite plugin that provides GitHub token retrieval via Chinmina (a GitHub App token vending service). The plugin adds a `chinmina_token` helper script to the PATH that agents can use to retrieve tokens for GitHub operations.

## Testing and Development

Run tests and linting using Docker Compose:

```bash
# Run Buildkite plugin linter
docker compose run --rm lint

# Run all Bash tests
docker compose run --rm tests

# Run a specific test file
docker compose run --rm tests tests/chinmina_token.bats

# Run a specific test case
docker compose run --rm tests tests/chinmina_token.bats -f "fetches the chinmina token"
```

## Architecture

### Plugin Lifecycle

The plugin follows Buildkite's standard plugin hook structure:

1. **Environment Hook** (`hooks/environment`):
   - Validates required configuration parameters (`chinmina-url` and `audience`)
   - Exports configuration as environment variables with the `CHINMINA_TOKEN_LIBRARY_FUNCTION_` prefix
   - Adds `bin/` directory to PATH to make `chinmina_token` command available

2. **Helper Script** (`bin/chinmina_token`):
   - Retrieves GitHub tokens from the Chinmina Bridge service
   - Accepts an optional profile argument (defaults to "default")
   - Caches OIDC tokens for 5 minutes using encrypted storage in `${TMPDIR}/chinmina-oidc-${BUILDKITE_JOB_ID}.cache`
   - Encryption uses OpenSSL with AES-256-CBC and BUILDKITE_AGENT_ACCESS_TOKEN as the passphrase
   - Makes HTTP POST requests to Chinmina Bridge with OIDC JWT authorization
   - Requires TMPDIR environment variable to be set

### Token Retrieval Flow

1. Script validates TMPDIR environment variable is set
2. Checks for cached OIDC token (valid for 5 minutes) and attempts decryption
3. If cache miss or decryption fails, requests new OIDC token from Buildkite Agent using configured audience
4. Encrypts and caches the new OIDC token using OpenSSL (AES-256-CBC with BUILDKITE_AGENT_ACCESS_TOKEN as passphrase)
5. Determines API path based on profile:
   - Profiles starting with `pipeline:` (or deprecated `repo:`) → `/token`
   - All other profiles → `/organization/token/{profile_name}`
6. POSTs to Chinmina Bridge with OIDC token as Bearer authorization
7. Validates response contains non-empty token field
8. Outputs token to stdout

### Configuration Propagation

Plugin configuration flows from `plugin.yml` → Buildkite environment variables → `hooks/environment` → helper script environment variables:

- `chinmina-url` → `BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL` → `CHINMINA_TOKEN_LIBRARY_FUNCTION_CHINMINA_URL`
- `audience` → `BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE` → `CHINMINA_TOKEN_LIBRARY_FUNCTION_AUDIENCE`

### Caching Implementation

A separate caching library (`lib/cache.bash`) handles encrypted token storage:

- **Encryption**: Uses OpenSSL with AES-256-CBC, PBKDF2 with 100,000 iterations
- **Key Material**: BUILDKITE_AGENT_ACCESS_TOKEN serves as the encryption passphrase
- **Cache Location**: `${TMPDIR}/chinmina-oidc-${job_id}.cache` with 600 permissions
- **Graceful Degradation**: If OpenSSL is unavailable, caching is silently skipped
- **TTL**: Cache files are valid for 5 minutes from last modification

### Test Structure

Uses BATS (Bash Automated Testing System) with Buildkite's plugin-tester framework:

- `tests/environment.bats`: Tests the environment hook configuration validation and PATH setup
- `tests/chinmina_token.bats`: Tests the token retrieval script using stubbed `curl` and `buildkite-agent` commands
- `tests/cache.bats`: Tests the encryption/decryption caching functionality with mocked OpenSSL
- `tests/test_helpers.bash`: Shared test utilities for stubbing and mocking

Tests use the stub system from `buildkite/plugin-tester` to mock external dependencies without actual network calls.
