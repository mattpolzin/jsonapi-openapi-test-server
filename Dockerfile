
FROM swift:6.0 AS builder

# Install OS updates and, if needed, sqlite3
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update \
    && apt-get -q dist-upgrade -y \
    && apt-get install -y libssl-dev zlib1g-dev libz-dev \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so* /build/lib

WORKDIR /build

# Copy manifest
COPY ./Package.* ./

# Resolve dependencies
RUN swift package resolve

# Build Source
COPY . .

#########
# RELEASE
# RUN swift build --enable-test-discovery -c release
#
#########
# DEBUG
RUN swift build --enable-test-discovery -c release -Xswiftc -DDEBUG
#
#########

# Copy to staging area
WORKDIR /staging

# Copy Public folder to staging area
RUN cp -r /build/Public ./Public

# Copy main executables to staging area 
# and generate API documentation
# and write-protect Public folder
RUN bin_path="$(swift build --package-path /build -c release --show-bin-path)" \
  && cp "${bin_path}/Run" ./ \
  && cp "${bin_path}/APITest" ./ \
  && ${bin_path}/GenAPIDocumentation > ./Public/openapi.yml \
  && chmod -R a-w ./Public

# ------------------------------------------------------------------------------

#
## Production image
#

FROM swift:6.0

# DEBIAN_FRONTEND=noninteractive for automatic UTC configuration in tzdata
# Make sure all system packages are up to date.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true \
    && apt-get -q update && apt-get -q dist-upgrade -y \
    && apt-get install -y libz-dev libz3-4 tzdata zlib1g \
    && rm -r /var/lib/apt/lists/*

WORKDIR /app

# Copy built executable and any staged resources from builder
COPY --from=builder /staging /app

# Create the default output directory
RUN mkdir -p ./out

##
## ENV vars
##

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
CMD ["serve", "--env", "production", "--hostname", "0.0.0.0", "--port", "80"]

##
## queues
##

# Use this command to run the queues service outside of the API server process.
# This is the recommended way to run the Jobs Queue.
# CMD ["queues"]
