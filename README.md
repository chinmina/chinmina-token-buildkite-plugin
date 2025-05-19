<!-- ./command.sh curl https://github.com/cultureamp/deploy-buildkite-plugin/releases/download/v0.1/deploy-buildkite-plugin_darwin_arm64 -->

# chinmina-token-buildkite-plugin

Buildkite plugin to fetch a chinmina token for the requested organization profile by using the cached OIDC token.

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: chinmina_token
    plugins:
      - chinmina/chinmina-tokem#v1.0.0:
          chinmina-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
```

To use the token and fetch private github releases, usage would be the following:

```bash
token="$(chinmina_token "org:profile-name")"
GITHUB_TOKEN="${token}" \
  gh releases download --repo "${repo}" \
    --pattern "release-file=${arch}.zip" \
    --dir "${TMP}/something" \
    "${tag}"
```

## Configuration

### `chinmina-url` (Required, string)

The URL of the  helper agent that vends a
token for a pipeline. This is a separate HTTP service that must accessible to
your Buildkite agents.

### `audience` (string)

**Default:** `chinmina:default`

The value of the `aud` claim of the OIDC JWT that will be sent to
. This must correlate with the value
configured in the `chinmina-bridge` settings.

A recommendation: `chinmina:your-github-organization`. This is specific
to the purpose of the token, and also scoped to the GitHub organization that
tokens will be vended for. `chinmina-bridge`'s GitHub app is configured for a
particular GitHub organization/user, so if you have multiple organizations,
multiple agents will need to be running.

## Developing

Run tests and plugin linting locally using `docker compose`:

```shell
# Buildkite plugin linter
docker-compose run --rm lint

# Bash tests
docker-compose run --rm tests
```

## Contributing

Contributions are welcome! Raise a PR, and include tests with your changes.

1. Fork the repo
2. Make the changes
3. Run the tests and linter
4. Commit and push your changes
5. Send a pull request
