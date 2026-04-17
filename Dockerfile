ARG UPSTREAM_TAG=v26.4.0

FROM node:22-alpine AS builder
RUN apk add --no-cache python3 openssl build-base git && corepack enable
WORKDIR /src

ARG UPSTREAM_TAG
RUN git clone --depth 1 --branch ${UPSTREAM_TAG} https://github.com/actualbudget/actual.git .

COPY patches/ /patches/
RUN for p in /patches/*.patch; do echo "Applying $p"; git apply "$p"; done

RUN yarn install --immutable
RUN yarn workspace @actual-app/web build

FROM actualbudget/actual-server:${UPSTREAM_TAG}
COPY --from=builder --chown=actual:actual /src/packages/desktop-client/build /app/node_modules/@actual-app/web/build
