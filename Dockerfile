FROM hexpm/elixir:1.12.3-erlang-24.1.6-alpine-3.13.6 as builder

RUN apk add --no-cache npm

ARG MIX_ENV=prod

WORKDIR /src

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix do deps.get --only ${MIX_ENV} 
RUN mkdir config

COPY config/config.exs config/$MIX_ENV.exs config/
RUN mix deps.compile

COPY priv ./priv

COPY assets ./assets
RUN mix npmi
RUN mix assets.deploy

COPY lib ./lib
RUN mix compile

COPY config/runtime.exs ./config

RUN mix do release

# ===========================================

FROM alpine:3.13.6
RUN apk add --no-cache openssl ncurses-libs bash file curl libstdc++

WORKDIR /app
COPY --from=builder /src/_build/prod/rel/goplay_plugin/ .

EXPOSE 4000

ENTRYPOINT ["/app/bin/goplay_plugin"]
CMD ["start"]


