<!-- ./command.sh curl https://github.com/cultureamp/deploy-buildkite-plugin/releases/download/v0.1/deploy-buildkite-plugin_darwin_arm64 -->

# Chinmina Private Releases Buildkite Plugin

Buildkite plugin to retrieve private releases from github repos by shimming curl & wget requests.

## Example

Add the following to your `pipeline.yml`:

```yml
steps:
  - command: ls
    plugins:
      - chinmina/chinmina-private-releases#v1.0.0: 
```

## Developing

Run tests and plugin linting locally using `docker compose`:

```shell
# Buildkite plugin linter
docker-compose run --rm lint

# Bash tests
docker-compose run --rm tests
```

## Configuration

None