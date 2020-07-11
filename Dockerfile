
FROM swift:5.2 as builder

RUN apt-get -qq update && apt-get install -y \
  libssl-dev zlib1g-dev \
  && rm -r /var/lib/apt/lists/*

RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so* /build/lib

WORKDIR /app

# Copy manifest
COPY ./Package.* ./

# Resolve dependencies
RUN swift package resolve

# Build Source
COPY . .

#########
# RELEASE
# RUN swift build --enable-test-discovery -c release -Xswiftc -g \
#  && mv `swift build -c release --show-bin-path` /build/bin
#
#########
# DEBUG
RUN swift build --enable-test-discovery -c release -Xswiftc -g -Xswiftc -DDEBUG \
  && mv `swift build -c release --show-bin-path` /build/bin
#
#########

#
# Generate API Documentation
#
RUN /build/bin/GenAPIDocumentation > ./Public/openapi.yml

# ------------------------------------------------------------------------------

#
## Production image
#

FROM swift:5.2
ARG env
# DEBIAN_FRONTEND=noninteractive for automatic UTC configuration in tzdata
RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  libatomic1 libicu60 libxml2 libcurl4 libz-dev libbsd0 tzdata zlib1g \
  && rm -r /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/bin/Run .
COPY --from=builder /build/bin/APITest .
COPY --from=builder /app/Public ./Public
COPY --from=builder /build/lib/* /usr/lib/

RUN mkdir -p ./out

##
## ENV vars
##

ENV ENVIRONMENT=$env

# A local file from which to read the OpenAPI documentation.
#   IMPORTANT: Only specify one of [API_TEST_IN_FILE, API_TEST_IN_URL]
# ENV API_TEST_IN_FILE

# A remote URL from which to read the OpenAPI documentation.
#   IMPORTANT: Only specify one of [API_TEST_IN_FILE, API_TEST_IN_URL]
# ENV API_TEST_IN_URL

# Basic Auth credentials for API_TEST_IN_URL. Do not specify if no auth needed.
# ENV API_TEST_USERNAME
# ENV API_TEST_PASSWORD

# Path on local filesystem to which to write generated API test files.
# Optional. If not specified, defaults to ~/api_test
# ENV API_TEST_OUT_PATH

# Path on local filesystem to which to write zipped generated API test files.
# Optional. If not specified, defaults to ~/api_test_archives
# ENV API_TEST_ARCHIVES_PATH

# Postgres Database URL. Required.
# ENV API_TEST_DATABASE_URL

# Redis URL. Required.
# ENV API_TEST_REDIS_URL

# Jobs Queue runs in process. Optional. If false (or undefined),
#   a jobs process must be run separately.
# ENV API_TEST_IN_PROCESS_QUEUES

##
## serve (default command)
##

# --env
# The environment to start up in. anything is valid, but 'production', 'development', and 'testing' have special meaning.

# --log
# The log-level. One of case "trace", "debug", "info", "notice", "warning", "error", "critical"

ENTRYPOINT ["./Run"]
CMD ["serve", "--env", "$ENVIRONMENT", "--hostname", "0.0.0.0", "--port", "80"]

##
## queues
##

# Use this command to run the queues service outside of the API server process.
# This is the recommended way to run the Jobs Queue.
# CMD ["queues"]
