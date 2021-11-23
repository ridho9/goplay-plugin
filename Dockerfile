FROM hexpm/elixir:1.12.3-erlang-24.1.6-alpine-3.13.6 as builder

ARG MIX_ENV=prod

WORKDIR /src

RUN mix local.hex --force && \
    mix local.rebar --force

COPY mix.exs mix.lock ./

RUN mix do deps.get --only ${MIX_ENV}, deps.compile

COPY assets ./assets
COPY config ./config
COPY lib ./lib
COPY priv ./priv

RUN mix do release
# RUN mix do deps.get --only ${MIX_ENV}, release

# ===========================================

FROM alpine:3.13.6
RUN apk add --no-cache openssl ncurses-libs bash file curl libstdc++

WORKDIR /app
COPY --from=builder /src/_build/prod/rel/goplay_plugin/ .

EXPOSE 80

ENTRYPOINT ["/app/bin/goplay_plugin"]
CMD ["start"]


