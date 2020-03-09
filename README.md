# JSON:API/OpenAPI Test Server
## Usage
### As Tool
#### Against a URL
You can point the test tool at a URL serving up OpenAPI documentation. The URL can either require HTTP Basic Authentication or no authentication.

The unauthenticated version only requires the `API_TEST_IN_URL` environment variable.
```shell
docker run --rm --env 'API_TEST_IN_URL=https://website.com/api/documentation' mattpolzin2/api-test-server ./APITest
```

The authenticated version additionally requires the `API_TEST_USERNAME` and `API_TEST_PASSWORD` environment variables.
```shell
docker run --rm --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_USERNAME=username' --env 'API_TEST_PASSWORD=password' mattpolzin2/api-test-server ./APITest
```

#### Against a local file
You can point the test tool at a local file if you mount that file into the docker container and specify the mount destination with the `API_TEST_IN_FILE` environment variable.
```shell
docker run --rm --env 'API_TEST_IN_FILE=/api/openapi.json' -v '/full/path/to/openapi.json:/api/openapi.json' mattpolzin2/api-test-server ./APITest
```
Note that you cannot use relative paths with bind mounts but if, for example, your `openapi.json` file is in the current working directory then you could invoke as:
```shell
docker run --rm --env 'API_TEST_IN_FILE=/api/openapi.json' -v "$(pwd)/openapi.json:/api/openapi.json" mattpolzin2/api-test-server ./APITest
```

#### Dumping test files
The test tool works by generating Swift code to parse examples and test responses. These test files include JSON:API models that could be used as a basis for client implementations. You can dump the test files with the `--dump-files` argument to the `./APITest test` command. You must also mount the output directory so you can access the generated file from outside of the container.

```shell
docker run --rm --env 'API_TEST_IN_URL=https://website.com/api/documentation' -v "$(pwd)/out:/app/out" mattpolzin2/api-test-server ./APITest test --dump-files
```

You will find the dumped files at `./out/api_test_files.zip`.

### As Server
You can run an API Test server that accepts requests to run tests at HTTP endpoints. This requires the same input file or URL environment variables explained in the above section but you also must provide a Postgres database for the server to use as its persistence layer. You specify this database using a Postgres URL in the `API_TEST_DATABASE_URL` environment variable.

First you need to run the migrator against your Postgres database.
```shell
docker run --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_DATABASE_URL=postgres://user:password@host:port/databasename' -p '8080:80' mattpolzin2/api-test-server migrate --yes
```

Then you can start the server.
```shell
docker run --env 'API_TEST_IN_URL=https://website.com/api/documentation' --env 'API_TEST_DATABASE_URL=postgres://user:password@host:port/databasename' -p '8080:80' mattpolzin2/api-test-server
```

**NOTE** We must explicitly expose the port to the host device. In this example, `http://localhost:8080` will point to the server which is listening on port `80` in the container.

Visit the `/docs` API endpoint to see what endpoints the server provides.

## Building
Note that Vapor 4 (and therefore this server) requires Swift 5.2.
### Generating API Documentation
To generate API documentation, run the `GenAPIDocumenation` target and save the output to `Public/openapi.yml`. This file is not committed to the repository but it will be picked up by the ReDoc UI served at the `/docs` API endpoint.

Documentation is generated as part of the Docker image build so you do not need to perform it as a separate step if you are building the Docker image anyway.

### Building Docker Image
From the root folder of the repository, run
```shell
docker build -t api-test-server:latest .
```
Once done, you will have the `api-test-server:latest` Docker image.