# chinmina-token-buildkite-plugin

Adds a `chinimina_token` script to the `PATH`, allowing agent scripts to retrieve
a GitHub token from Chinmina for the current repository or for an
[organizational profile][organization-profiles].

> [!NOTE]
> Refer to the [Chinmina documentation][chinmina-integration] for detailed
> information about configuring and using this plugin effectively.
>
> While this plugin can be used as a regular Buildkite plugin, it may be more
> useful if the agent configuration is adjusted to include it on all steps.
> This is fairly straightforward to implement in a custom `bootstrap` agent hook,
> and an example of this is documented.

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - plugins:
      - chinmina/chinmina-token#v1.0.0:
          chinmina-url: "https://chinmina-bridge-url"
          audience: "chinmina:your-github-organization"
```

To get a GitHub token, then fetch a private GitHub release
asset, usage would be the following:

```bash
# use the helper function to get a token
export GITHUB_TOKEN=$(chinmina_token "org:profile-name")

# The GH CLI will use GITHUB_TOKEN as its authorization for any API requests:

# ... show this to the console
gh auth status

# ... download a release from a private repo
gh releases download --repo "${repo}" \
  --pattern "release-file=${arch}.zip" \
  --dir "${directory}" \
  "${tag}"
```

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

[chinmina-bridge]: https://chinmina.github.io/introduction/
[chinmina-integration]: https://chinmina.github.io/guides/buildkite-integration/
[organization-profiles]: https://chinmina.github.io/reference/organization-profile/
