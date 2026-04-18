ARG UPSTREAM_GIT_TAG=v26.4.0
ARG UPSTREAM_IMAGE_TAG=26.4.0

FROM --platform=$BUILDPLATFORM node:22-alpine AS builder
RUN apk add --no-cache python3 openssl build-base git && corepack enable
WORKDIR /src

ARG UPSTREAM_GIT_TAG
RUN git clone --depth 1 --branch ${UPSTREAM_GIT_TAG} https://github.com/actualbudget/actual.git .

COPY patches/ /patches/
RUN for p in /patches/*.patch; do echo "Applying $p"; git apply "$p"; done

RUN yarn install --immutable

# Upstream's build:browser script expects translations at packages/desktop-client/locale.
# It tries to git-clone them itself, but that makes the build depend on network state.
# Clone explicitly so the step is deterministic.
RUN git clone --depth 1 https://github.com/actualbudget/translations.git packages/desktop-client/locale \
    && packages/desktop-client/bin/remove-untranslated-languages

# yarn build:browser = plugins-service build + loot-core build:browser + web build:browser.
# Critical: the web bundle alone is broken without loot-core's browser build (SQLite
# WASM + CRDT runtime) and plugins-service.
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN yarn workspace plugins-service build \
    && yarn workspace @actual-app/core build:browser \
    && yarn workspace @actual-app/web build:browser

FROM actualbudget/actual-server:${UPSTREAM_IMAGE_TAG}
COPY --from=builder --chown=actual:actual /src/packages/desktop-client/build /app/node_modules/@actual-app/web/build
