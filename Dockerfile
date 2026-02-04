FROM elixir:1.14-alpine AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm

# Set build ENV
ENV MIX_ENV=prod

# Install hex and rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Create app directory
WORKDIR /app

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

# Copy application code
COPY config ./config
COPY lib ./lib
COPY priv ./priv

# Compile and build release
RUN mix compile
RUN mix phx.digest

# Build release
RUN mix release

# ===========================
# Runtime Stage
# ===========================
FROM alpine:3.18

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    ncurses-libs \
    libstdc++ \
    libgcc

# Create app user
RUN addgroup -g 1000 app && \
    adduser -D -u 1000 -G app app

WORKDIR /app

# Copy release from builder
COPY --from=builder --chown=app:app /app/_build/prod/rel/call_flow_engine ./

# Switch to app user
USER app

# Expose Phoenix port
EXPOSE 4000

# Set environment
ENV HOME=/app
ENV MIX_ENV=prod
ENV PORT=4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start the application
CMD ["bin/call_flow_engine", "start"]
