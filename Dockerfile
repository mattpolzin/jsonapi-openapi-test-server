
FROM swift:5.1 as builder

# For local build, add `--build-arg env=docker`
# In your application, you can use `Environment.custom(name: "docker")` to check if you're in this env
ARG env

RUN apt-get -qq update && apt-get install -y \
  libssl-dev zlib1g-dev \
  && rm -r /var/lib/apt/lists/*
WORKDIR /app
COPY . .
RUN mkdir -p /build/lib && cp -R /usr/lib/swift/linux/*.so* /build/lib

##
# RELEASE
# RUN swift build -c release \
#  && mv `swift build -c release --show-bin-path` /build/bin
#
##
# DEBUG
RUN swift build -c release -Xswiftc -g -Xswiftc -DDEBUG \
  && mv `swift build -c release --show-bin-path` /build/bin
##

# ------------------------------------------------------------------------------

## Production image

FROM swift:5.1
ARG env
# DEBIAN_FRONTEND=noninteractive for automatic UTC configuration in tzdata
RUN apt-get -qq update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
  libatomic1 libicu60 libxml2 libcurl4 libz-dev libbsd0 tzdata zlib1g \
  && rm -r /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /build/bin/Run .
COPY --from=builder /build/bin/APITest .
COPY --from=builder /build/lib/* /usr/lib/

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

# Postgres Database URL. Required.
# ENV API_TEST_DATABASE_URL

##
## Serve (default command)
##

# --env
# The environment to start up in. anything is valid, but 'production', 'development', and 'testing' have special meaning.

# --log
# The log-level. One of case "trace", "debug", "info", "notice", "warning", "error", "critical"

CMD ./Run serve --env $ENVIRONMENT --hostname 0.0.0.0 --port 80
