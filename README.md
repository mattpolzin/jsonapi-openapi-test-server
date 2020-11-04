# JSON:API/OpenAPI Test Server
## Requirements
### Server
The test server requires a Postgres database and Redis instace.

## Usage

The test server and commandline tool will execute tests against an OpenAPI document. Out of box, you get errors for unprocessable OpenAPI documentation, warnings for certain unhandled types of APIs, and a test that every OpenAPI Example parses under the corresponding request/response body schema. 

By default the server will assume that all request and response bodies are JSON:API compliant. The server will warn you and fall back to a non-JSON:API (but still JSON) request/response parsing mode if it fails to generate a test based on a JSON:API compliant schema. You can also opt out of attempting to interpret any particular OpenAPI Media Item as JSON:API with the `x-not-json-api: true` specification extension. This gets added to the OpenAPI document inside the Media Item but outside the schema.

For example,
```json
...
{
    "content": {
        "application/json": {
            "x-not-json-api": true,
            "schema": {
                "type": "object"
            }
        }
    }
}
...
```

You can additionally create tests that make API calls and verify that the actual responses from your server are parseable under the corresponding response schema. You do this with the `x-tests` Specification Extension on the OpenAPI Media Type Object within a Response Object (e.g. `responses/'200'/content/'application/json'/x-tests`). `x-tests` has the following structure:
```json
{
    "test_name": {
        "test_host": "url",
        "skip_example": false,
        "ignore_missing_parameter_warnings": false,
        "parameters": {
            "path_param_name": "value",
            "header_param_name": "value"
        },
        "query_parameters": [
            {
                "name": "param_name",
                "value": "param_value"
            }
        ]
    }
}
```

Parameters:
- `test_host`: optional, if omitted then default server for API will be used.
- `skip_example`: optional, defaults to false.
- `ignore_missing_parameter_warnings`: optional, defaults to false.
- `parameters` values: Must be strings, even if the parameter type is Int or other.

### The Commandline Tool

The command line tool's usage can be printed with `--help` and it is as follows:
```
OVERVIEW: Build and run tests based on an OpenAPI Document.

USAGE: APITest [--dump-files <directory path>] [--fail-hard] [--ignore-warnings] [--validate-all] [--openapi-file <file path>] [--override-server <url>] [--parser <parser>]

OPTIONS:
  --dump-files <directory path>
                          Dump produced test files in a zipped file at the specified location. 
        Tip: A good location to dump files is "./out". For the Dockerized tool this will be `/app/out` and when running the tool natively on your machine this will be the `out` folder relative to the current working directory.

        Not using this argument will result in test files being deleted after execution of the tests.
  -f, --fail-hard         Produce a non-zero exit code if any tests fail. 
  --ignore-warnings       Do not print warnings in the output. 
  --validate-all          Perform validation and linting on the OpenAPI documentation in addition to generating tests from it. 
  --openapi-file <file path>
                          Specify a filename from the local filesystem from which to read OpenAPI documentation. 
        Alternatively, set the `API_TEST_IN_FILE` environment variable.

        Either the environment variable or this argument must be used to indicate the OpenAPI file from which the tests should be generated.
  --override-server <url> Override the server definition(s) in the OpenAPI document for the purposes of this test run. 
        This argument allows you to make API requests against a different server than the input OpenAPI documentation specifies for this test run.

        Not using this argument will result in the API server options from the OpenAPI documentation being used.
  -p, --parser <parser>   Choose between the "stable" parser and a "fast" parser that is less battle-tested. (default: stable)
        This argument is currently only applicable to JSON parsing. When decoding a YAML file, the argument is ignored as there is only currently one YAML parser to choose from.

        Not using this argument will result in using the default stable parser.
  -h, --help              Show help information.
```

#### Against a URL
You can point the test tool at a URL serving up OpenAPI documentation. The URL can either require HTTP Basic Authentication or no authentication.

The unauthenticated version only requires the `API_TEST_IN_URL` environment variable.
```shell
docker run --rm --entrypoint ./APITest --env 'API_TEST_IN_URL=https://website.com/api/documentation' mattpolzin2/api-test-server
```

The authenticated version additionally requires the `API_TEST_USERNAME` and `API_TEST_PASSWORD` environment variables.
```shell
docker run --rm --entrypoint ./APITest --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_USERNAME=username' --env 'API_TEST_PASSWORD=password' mattpolzin2/api-test-server ./APITest
```

#### Against a local file
You can point the test tool at a local file if you mount that file into the docker container and specify the mount destination with the `API_TEST_IN_FILE` environment variable or the `--openapi-file` option for the `test` command.
```shell
# command option
docker run --rm --entrypoint ./APITest -v '/full/path/to/openapi.json:/api/openapi.json' mattpolzin2/api-test-server --openapi-file /api/openapi.json

# ENV var
docker run --rm --entrypoint ./APITest --env 'API_TEST_IN_FILE=/api/openapi.json' -v '/full/path/to/openapi.json:/api/openapi.json' mattpolzin2/api-test-server
```

Note that you cannot use relative paths with bind mounts but if, for example, your `openapi.json` file is in the current working directory then you could invoke as:
```shell
docker run --rm --entrypoint ./APITest --env 'API_TEST_IN_FILE=/api/openapi.json' -v "$(pwd)/openapi.json:/api/openapi.json" mattpolzin2/api-test-server
```

#### API Host Override
You can specify an override test server URL if you want to make API test requests against a different URL than is specified by the OpenAPI documentation. You use the `test` command's `--override-server` option for this.
```shell
docker run --rm --entrypoint ./APITest -v '/full/path/to/openapi.json:/api/openapi.json' mattpolzin2/api-test-server --openapi-file /api/openapi.json --override-server https://test.server.com
```

#### Dumping test files
The test tool works by generating Swift code to parse examples and test responses. These test files include JSON:API models that could be used as a basis for client implementations. You can dump the test files with the `--dump-files` argument to the `./APITest test` command. You must also mount the output directory (or don't remove the container and then `docker cp` later) so you can access the generated file from outside of the container.

```shell
docker run --rm --env 'API_TEST_IN_URL=https://website.com/api/documentation' -v "$(pwd)/out:/app/out" mattpolzin2/api-test-server ./APITest --dump-files /app/out
```

You will find the dumped files at `/app/out/api_test_files.zip`. **TIP:** You can also find the raw text logs from a test run at `/app/out/api_test.log`.

### The Test Server
You can run an API Test server that accepts requests to run tests at HTTP endpoints. This requires the same input file or URL environment variables explained in the above section but you also must provide a Postgres database for the server to use as its persistence layer. You specify this database using a Postgres URL in the `API_TEST_DATABASE_URL` environment variable. A Redis instance is required to queue up the test runs. You specify the Redis URL in the `API_TEST_REDIS_URL` environment variable.

First you need to run the migrator against your Postgres database.
```shell
docker run --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_DATABASE_URL=postgres://user:password@host:port/databasename' --env 'API_TEST_REDIS_URL=redis://host:port' -p '8080:80' mattpolzin2/api-test-server migrate --yes
```

Then you can start the server.
```shell
docker run --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_DATABASE_URL=postgres://user:password@host:port/databasename' --env 'API_TEST_REDIS_URL=redis://host:port' -p '8080:80' mattpolzin2/api-test-server
```

#### Jobs Queue
Testing is run in a jobs queue. That queue can be run in the same process as the API server if you specify `API_TEST_IN_PROCESS_QUEUES=true` as an environment variable but the recommendation is to run the jobs service as its own process.

You start the Jobs Queue using the same docker image as the server but you specify the `queues` command.
```shell
docker run --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_DATABASE_URL=postgres://user:password@host:port/databasename' --env 'API_TEST_REDIS_URL=redis://host:port' mattpolzin2/api-test-server queues
```

**NOTE** You must explicitly expose the port to the host device. In this example, `http://localhost:8080` will point to the server which is listening on port `80` in the container.

Visit the `/docs` API endpoint to see what endpoints the server provides.

## Building
Note that Vapor 4 (and therefore this server) requires Swift 5.2.

### Running and Testing
As of this writing, you need to run `swift package generate-xcodeproj` and then open that project in Xcode. Using Xcode's built-in Swift Package Manager support is currently broken for libraries like swift-syntax that require dynamic libraries from the Swift toolchain. `swift build`, `swift test`, etc. from the command line will work fine, though.

### Generating API Documentation
To generate API documentation, run the `GenAPIDocumenation` target and save the output to `Public/openapi.yml`. This file is not committed to the repository but it will be picked up by the ReDoc UI served at the `/docs` API endpoint.

Documentation is generated as part of the Docker image build so you do not need to perform it as a separate step if you are building the Docker image anyway.

### Building Docker Image
From the root folder of the repository, run
```shell
docker build -t api-test-server:latest .
```
Once done, you will have the `api-test-server:latest` Docker image.
