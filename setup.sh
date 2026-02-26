#!/usr/bin/env bash
# =============================================================================
# setup.sh — Start all databases and populate them with seed data.
#
# Usage:
#   ./setup.sh          # Start containers and seed all databases
#   ./setup.sh --seed   # Only re-run the seed container
#   ./setup.sh --down   # Tear everything down
#
# Prerequisites: docker or podman (with compose support)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors for output.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---------------------------------------------------------------------------
# Detect container runtime: docker or podman
# ---------------------------------------------------------------------------
detect_runtime() {
  if command -v docker &> /dev/null && docker compose version &> /dev/null 2>&1; then
    RUNTIME="docker"
    COMPOSE="docker compose"
  elif command -v podman &> /dev/null && podman compose version &> /dev/null 2>&1; then
    RUNTIME="podman"
    COMPOSE="podman compose"
  elif command -v podman-compose &> /dev/null; then
    RUNTIME="podman"
    COMPOSE="podman-compose"
  else
    error "No supported container runtime found."
    echo "  Install one of the following:"
    echo "    - docker with the compose plugin"
    echo "    - podman with 'podman compose' or 'podman-compose'"
    exit 1
  fi

  info "Using runtime: ${RUNTIME} (${COMPOSE})"
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
compose() {
  ${COMPOSE} -f "${SCRIPT_DIR}/docker-compose.yaml" "$@"
}

start_all() {
  info "Starting all containers (databases + seed)..."
  compose up --build -d
  echo ""
  info "Waiting for seed container to finish..."
  # Follow the seed container logs until it exits.
  compose logs -f seed 2>/dev/null || true
  echo ""
  echo "========================================"
  echo "  All services are running:"
  echo "  PostgreSQL   -> localhost:5432"
  echo "  CouchDB      -> http://localhost:5984"
  echo "  Memcached    -> localhost:11211"
  echo "  Typesense    -> http://localhost:8108"
  echo "========================================"
}

reseed() {
  info "Re-running seed container..."
  compose up --build --force-recreate seed
}

tear_down() {
  info "Tearing down containers and volumes..."
  compose down -v
  info "Done."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
detect_runtime

case "${1:-}" in
  --seed)
    reseed
    ;;
  --down)
    tear_down
    ;;
  *)
    start_all
    ;;
esac
