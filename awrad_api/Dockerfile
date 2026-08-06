# Multi-stage build for the Phoenix release. The builder and runtime bases must
# stay on the same Debian release so the compiled ERTS matches the runtime libc.
ARG ELIXIR_IMAGE=elixir:1.19-otp-28
ARG RUNNER_IMAGE=debian:trixie-slim

FROM ${ELIXIR_IMAGE} AS builder

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

ENV MIX_ENV="prod"

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
# hex.pm tarball fetches time out often enough to fail otherwise-good builds.
ENV HEX_HTTP_CONCURRENCY=1 HEX_HTTP_TIMEOUT=120
RUN set -e; for attempt in 1 2 3 4 5; do \
      mix deps.get --only $MIX_ENV && break; \
      [ "$attempt" = 5 ] && exit 1; \
      sleep $((attempt * 5)); \
    done
RUN mkdir config

COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.deploy
RUN mix compile

COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${RUNNER_IMAGE} AS runner

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends \
     ca-certificates libstdc++6 locales openssl \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG="en_US.UTF-8" \
    LANGUAGE="en_US:en" \
    LC_ALL="en_US.UTF-8" \
    MIX_ENV="prod" \
    PHX_SERVER="true" \
    PORT="4000"

WORKDIR /app

RUN groupadd --system --gid 1000 awrad \
  && useradd --system --uid 1000 --gid awrad --create-home --home-dir /home/awrad awrad \
  && chown awrad:awrad /app

COPY --from=builder --chown=awrad:awrad /app/_build/prod/rel/awrad_api ./

USER awrad

EXPOSE 4000

CMD ["/app/bin/server"]
