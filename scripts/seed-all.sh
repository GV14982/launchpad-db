#!/usr/bin/env bash
# =============================================================================
# Entrypoint for the seed container. Runs all seed scripts in order.
# Hostnames are set via environment variables to point at compose service names.
# =============================================================================
set -euo pipefail

echo "========================================"
echo "  Seeding all databases..."
echo "========================================"
echo ""

echo "--- CouchDB (document) ---"
bash /scripts/seed-couchdb.sh
echo ""

echo "--- Memcached (key-value) ---"
bash /scripts/seed-memcached.sh
echo ""

echo "--- Typesense (full-text search) ---"
bash /scripts/seed-typesense.sh
echo ""

echo "========================================"
echo "  All databases seeded successfully."
echo "  PostgreSQL was seeded automatically"
echo "  via docker-entrypoint-initdb.d."
echo "========================================"
