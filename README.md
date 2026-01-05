# chinmina-token-buildkite-plugin

A Buildkite plugin for retrieving GitHub tokens from Chinmina for the current
repository or [organizational profiles][organization-profiles]. Tokens can be
automatically exported as environment variables or retrieved programmatically
via the `chinmina_token` helper script.

> [!NOTE]
> Refer to the [Chinmina documentation][chinmina-integration] for detailed
> information about configuring and using this plugin effectively.
>
> The documentation recommends configuring the token plugin at the agent level,
> so the `chinmina_token` function is available to all scripts, and the default
> configuration for the current plugin environment is configured.
>
> When the plugin is installed at the agent level, the `environment` parameter
> is all that needs to be supplied.

## Requirements

- `jq` - Used for parsing plugin configuration and extracting version
  information

## Getting Started

The simplest way to use this plugin is to declare the tokens you need as
environment variables:

```yml
steps:
  - label: "Deploy to production"
    command: |
      # GITHUB_TOKEN is automatically available
      gh release download --repo myorg/myrepo --pattern "*.zip"
    plugins:
      - chinmina/chinmina-token#v1.3.0:
          chinmina-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
          environment:
            - GITHUB_TOKEN=pipeline:default
```

> [!TIP]
> All tokens retrieved from Chinmina Bridge are automatically redacted from
> build logs.

### Agent configuration

If you install the plugin on the agent by default (in the bootstrap of the
Elastic Stack, for example), you can default the configuration for all
pipelines.

Add the following to the agent `environment` hook:

```shell
BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL="${BUILDKITE_PLUGIN_CHINMINA_TOKEN_CHINMINA_URL:-https://chinmina-bridge.example.com}" \
  BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE="${BUILDKITE_PLUGIN_CHINMINA_TOKEN_AUDIENCE:-chinmina:your-organization}" \
    source /buildkite/plugins/chinmina-token-buildkite-plugin/hooks/environment
```

Then in your pipeline you can set the environment without specifying the URL and
audience again.

```yml
steps:
  - label: "Deploy to production"
    command: |
      # GITHUB_TOKEN is automatically available
      gh release download --repo myorg/myrepo --pattern "*.zip"
    plugins:
      - chinmina/chinmina-token#v1.3.0:
          environment:
            - GITHUB_TOKEN=pipeline:default
```


### Multiple Tokens

For workflows requiring multiple tokens (e.g., accessing different organizations
or profiles):

```yml
steps:
  - label: "Build with private dependencies"
    command: |
      # Multiple tokens available for different purposes
      npm config set //npm.pkg.github.com/:_authToken "$GITHUB_NPM_TOKEN"
      npm install

      # Deploy using different token
      gh release create --repo myorg/releases "$VERSION"
    plugins:
      - chinmina/chinmina-token#v1.3.0:
          chinmina-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
          environment:
            - GITHUB_TOKEN=pipeline:default
            - GITHUB_NPM_TOKEN=org:npm-packages
```

## Advanced Usage

For dynamic token selection or complex scripting scenarios, use the
`chinmina_token` helper script directly:

```yml
steps:
  - plugins:
      - chinmina/chinmina-token#v1.3.0:
          chinmina-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
```

Then in your scripts:

```bash
# Dynamically select profile based on environment
if [[ "$ENVIRONMENT" == "production" ]]; then
  export GITHUB_TOKEN=$(chinmina_token "org:prod-profile")
else
  export GITHUB_TOKEN=$(chinmina_token "org:staging-profile")
fi

# Or get a token for the repository
export GITHUB_TOKEN=$(chinmina_token "pipeline:default")

# Use with gh CLI
gh release download --repo "${repo}" \
  --pattern "release-file-${arch}.zip" \
  --dir "${directory}" \
  "${tag}"
```

### When to Use Each Approach

| Use Case | Recommended Approach |
|----------|---------------------|
| Static token needs known upfront | `environment` array (declarative) |
| Multiple tokens for different services | `environment` array |
| Dynamic profile selection | `chinmina_token` script |
| Conditional token logic | `chinmina_token` script |
| Token needed only in specific conditions | `chinmina_token` script |

## Configuration

### `chinmina-url` (Required, string)

The URL of the [`chinmina-bridge`][chinmina-bridge] helper agent that vends a
token for a pipeline. This is a separate HTTP service that must be accessible to
your Buildkite agents.

### `audience` (string)

**Default:** `chinmina:default`

The value of the `aud` claim of the OIDC JWT that will be sent to
[`chinmina-bridge`][chinmina-bridge]. This must correlate with the value
configured in the `chinmina-bridge` settings.

**Recommendation:** `chinmina:your-github-organization`

This value should be specific to the purpose of the token and scoped to the
GitHub organization that tokens will be vended for. Since `chinmina-bridge`'s
GitHub app is configured for a particular GitHub organization/user, multiple
agents are needed for multiple organizations.

### `environment` (array of strings)

Automatically export environment variables containing tokens from specified
profiles. Each entry uses the format `VAR_NAME=profile`.

#### Profile formats

- `pipeline:default` - Token for the current repository
- `org:profile-name` - Token for an organizational profile

#### Example

```yml
environment:
  - GITHUB_TOKEN=pipeline:default
  - GITHUB_NPM_TOKEN=org:npm-packages
  - GITHUB_HOMEBREW_TOKEN=org:homebrew-tap
```

**Equivalent manual approach:**

```bash
export GITHUB_TOKEN=$(chinmina_token "pipeline:default")
export GITHUB_NPM_TOKEN=$(chinmina_token "org:npm-packages")
export GITHUB_HOMEBREW_TOKEN=$(chinmina_token "org:homebrew-tap")
```

#### Features
- Tokens are automatically redacted from build logs
- Fails fast if any token retrieval fails
- Validates environment variable names and profile values

## Developing

Run tests and plugin linting locally using `docker compose`:

```shell
# Buildkite plugin linter
docker compose run --rm lint

# Bash tests
docker compose run --rm tests

# Specific test file
docker compose run --rm tests tests/chinmina_token.bats
```

## Contributing

Contributions are welcome! Raise a PR, and include tests with your changes.

1. Fork the repo
2. Make the changes
3. Run the tests and linter
4. Commit and push your changes
5. Send a pull request

[chinmina-bridge]: https://chinmina.github.io/introduction/
[chinmina-integration]: https://chinmina.github.io/guides/buildkite-integration/
[organization-profiles]: https://chinmina.github.io/reference/organization-profile/
