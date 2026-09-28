# syntax=docker/dockerfile:1

# ============================================================================
# Stage 1: Build dependencies with uv
# ============================================================================
FROM python:3.12-slim AS builder

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never

# Install uv (the fast Python package manager this project uses)
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

WORKDIR /app

# System deps needed to build psycopg2 and similar C-extension packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency manifests only — this layer caches on the lockfile
COPY backend/pyproject.toml backend/uv.lock ./

# Install dependencies into a .venv we can copy forward.
# --no-install-project: only install third-party deps here, not the project.
# --no-dev: skip dev/test dependencies for a smaller runtime image.
RUN uv sync --frozen --no-install-project --no-dev

# ============================================================================
# Stage 2: Runtime
# ============================================================================
FROM python:3.12-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH" \
    DJANGO_SETTINGS_MODULE=crm.settings

WORKDIR /app

# Runtime libs: libpq5 for psycopg2, curl for the /health/ healthcheck
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

# Bring in the virtualenv from the builder stage
COPY --from=builder /app/.venv /app/.venv

# Copy the backend source
COPY backend/ .

# Make entrypoint executable (the compose mounts it in, but this is a safety net)
RUN chmod +x /entrypoint.sh 2>/dev/null || true

# Sanity check: Django must be importable at build time
RUN python -c "import django; print('Django', django.get_version())" \
    && gunicorn --version

EXPOSE 8000

CMD ["/bin/bash", "/entrypoint.sh"]