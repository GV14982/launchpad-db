#!/usr/bin/env bash
# =============================================================================
# Memcached Seed Script (Key-Value Store)
#
# Showcases: simple key-value caching patterns. Memcached has no schema, no
# queries, no indexes — just SET, GET, and DELETE with optional TTL (expiry).
#
# Typical use cases demonstrated here:
#   1. Session tokens      — fast auth lookups, short TTL
#   2. Cached query results — avoid repeated expensive DB queries
#   3. Rate limit counters  — track per-user request counts
#   4. Hot entity cache     — frequently accessed book details
#
# Memcached uses a simple text protocol over TCP. We send commands directly
# via bash using /dev/tcp or printf piped to netcat.
#
# Data: derived from 120 books, 25 customers, 355 reviews.
#       Generated from data/books.json + data/customers.json.
# =============================================================================
set -euo pipefail

MC_HOST="${MC_HOST:-localhost}"
MC_PORT="11211"

echo "==> Waiting for Memcached to be ready..."
until printf "version\r\n" | nc -q 1 "${MC_HOST}" "${MC_PORT}" 2>/dev/null | grep -q "VERSION"; do
  sleep 1
done
echo "==> Memcached is up."

# ---------------------------------------------------------------------------
# Helper: store a key-value pair.
#   mc_set <key> <value> [<ttl_seconds>]
#
# The Memcached text protocol SET format:
#   set <key> <flags> <exptime> <bytes>\r\n<data>\r\n
# ---------------------------------------------------------------------------
mc_set() {
  local key="$1"
  local value="$2"
  local ttl="${3:-0}"  # 0 = no expiry
  local bytes=${#value}

  printf "set %s 0 %s %s\r\n%s\r\n" "${key}" "${ttl}" "${bytes}" "${value}" \
    | nc -q 1 "${MC_HOST}" "${MC_PORT}" > /dev/null 2>&1
  echo "    + ${key} (ttl=${ttl}s, ${bytes} bytes)"
}

# ---------------------------------------------------------------------------
# 1. SESSION TOKENS
#    Fast auth lookups. In production these would have short TTLs (e.g., 3600s).
#    The key is the session token; the value is the user context as JSON.
# ---------------------------------------------------------------------------
echo "==> Storing session tokens..."

mc_set "session:2ab7b932d89d2388" \
  '{"customer_id": 1, "name": "Alice Johnson", "email": "alice@example.com", "role": "customer"}' \
  3600

mc_set "session:236807ce0bcd8559" \
  '{"customer_id": 2, "name": "Bob Smith", "email": "bob@example.com", "role": "customer"}' \
  3600

mc_set "session:ba7fba344c0e1037" \
  '{"customer_id": 3, "name": "Carol Williams", "email": "carol@example.com", "role": "customer"}' \
  3600

mc_set "session:68c7c07532ed6d93" \
  '{"customer_id": 4, "name": "Dan Chen", "email": "dan@example.com", "role": "customer"}' \
  3600

mc_set "session:deeb252bfe687a53" \
  '{"customer_id": 5, "name": "Elena Rodriguez", "email": "elena@example.com", "role": "customer"}' \
  3600

mc_set "session:a470c0ba5e3339f3" \
  '{"customer_id": 6, "name": "Frank Okafor", "email": "frank@example.com", "role": "customer"}' \
  3600

mc_set "session:c01f3284e0d1b257" \
  '{"customer_id": 7, "name": "Grace Kim", "email": "grace@example.com", "role": "customer"}' \
  3600

mc_set "session:41f3f24f9a93664b" \
  '{"customer_id": 8, "name": "Hassan Ali", "email": "hassan@example.com", "role": "customer"}' \
  3600

mc_set "session:bd2d03ec45467d03" \
  '{"customer_id": 9, "name": "Iris Novak", "email": "iris@example.com", "role": "customer"}' \
  3600

mc_set "session:2292326d256efbbf" \
  '{"customer_id": 10, "name": "Jamal Washington", "email": "jamal@example.com", "role": "customer"}' \
  3600

# ---------------------------------------------------------------------------
# 2. CACHED QUERY RESULTS
#    Pre-computed results of expensive database queries. Instead of running a
#    JOIN + aggregation every request, cache the result and invalidate on write.
# ---------------------------------------------------------------------------
echo "==> Caching computed query results..."

mc_set "query:top_rated_books" \
  '[{"title": "Kindred", "avg_rating": 4.67, "reviews": 3}, {"title": "Cosmos", "avg_rating": 4.67, "reviews": 3}, {"title": "The Left Hand of Darkness", "avg_rating": 4.33, "reviews": 3}, {"title": "2001: A Space Odyssey", "avg_rating": 4.33, "reviews": 3}, {"title": "Beloved", "avg_rating": 4.33, "reviews": 3}]' \
  300

mc_set "query:genre_counts" \
  '{"Science Fiction": 35, "Fiction": 31, "Fantasy": 28, "Horror": 11, "Mystery": 6, "Romance": 6, "Thriller": 2, "Science": 1}' \
  300

mc_set "query:books_in_stock_count" \
  '120' \
  60

mc_set "query:recent_reviews" \
  '[{"book_id": 119, "rating": 4, "body": "Gothic, romantic, and mysterious. A page-turner."}, {"book_id": 119, "rating": 3, "body": "Enjoyable but the plot twists are fairly predictable."}, {"book_id": 120, "rating": 4, "body": "Hobb'\''s reincarnation concept is unlike anything else in fant"}, {"book_id": 120, "rating": 4, "body": "Celtic-inspired fantasy with real emotional depth."}, {"book_id": 120, "rating": 3, "body": "The multi-timeline structure is more confusing than illumina"}]' \
  120

# ---------------------------------------------------------------------------
# 3. RATE LIMIT COUNTERS
#    Track API request counts per user. Memcached's INCR/DECR commands are
#    atomic, making this a common pattern for rate limiting.
# ---------------------------------------------------------------------------
echo "==> Setting rate limit counters..."

mc_set "ratelimit:alice@example.com:2025-02-25" "82" 86400
mc_set "ratelimit:bob@example.com:2025-02-25" "15" 86400
mc_set "ratelimit:carol@example.com:2025-02-25" "4" 86400
mc_set "ratelimit:dan@example.com:2025-02-25" "95" 86400
mc_set "ratelimit:elena@example.com:2025-02-25" "36" 86400
mc_set "ratelimit:frank@example.com:2025-02-25" "32" 86400
mc_set "ratelimit:grace@example.com:2025-02-25" "29" 86400
mc_set "ratelimit:hassan@example.com:2025-02-25" "18" 86400

# ---------------------------------------------------------------------------
# 4. HOT ENTITY CACHE
#    Frequently accessed individual records cached by ID. The key convention
#    (e.g., "book:1") mirrors what an ORM or data access layer would use.
# ---------------------------------------------------------------------------
echo "==> Caching hot entity lookups..."

mc_set "book:1" \
  '{"id": 1, "title": "Dune", "authors": ["Frank Herbert"], "price": 9.99, "genre": "Science Fiction", "avg_rating": 3.8, "review_count": 6, "in_stock": true}' \
  600

mc_set "book:2" \
  '{"id": 2, "title": "The Fellowship of the Ring", "authors": ["J.R.R. Tolkien"], "price": 12.99, "genre": "Fantasy", "avg_rating": 4.0, "review_count": 6, "in_stock": true}' \
  600

mc_set "book:6" \
  '{"id": 6, "title": "Good Omens", "authors": ["Neil Gaiman", "Terry Pratchett"], "price": 13.99, "genre": "Fantasy", "avg_rating": 4.0, "review_count": 6, "in_stock": true}' \
  600

mc_set "book:3" \
  '{"id": 3, "title": "Murder on the Orient Express", "authors": ["Agatha Christie"], "price": 10.99, "genre": "Mystery", "avg_rating": 3.8, "review_count": 5, "in_stock": true}' \
  600

mc_set "book:4" \
  '{"id": 4, "title": "Foundation", "authors": ["Isaac Asimov"], "price": 8.99, "genre": "Science Fiction", "avg_rating": 3.6, "review_count": 5, "in_stock": true}' \
  600

mc_set "book:9" \
  '{"id": 9, "title": "1984", "authors": ["George Orwell"], "price": 9.99, "genre": "Fiction", "avg_rating": 4.2, "review_count": 5, "in_stock": true}' \
  600

mc_set "book:11" \
  '{"id": 11, "title": "Pride and Prejudice", "authors": ["Jane Austen"], "price": 6.99, "genre": "Romance", "avg_rating": 3.8, "review_count": 5, "in_stock": true}' \
  600

mc_set "book:24" \
  '{"id": 24, "title": "The Handmaid'\''s Tale", "authors": ["Margaret Atwood"], "price": 10.99, "genre": "Fiction", "avg_rating": 4.2, "review_count": 5, "in_stock": true}' \
  600

mc_set "book:34" \
  '{"id": 34, "title": "One Hundred Years of Solitude", "authors": ["Gabriel Garcia Marquez"], "price": 11.99, "genre": "Fiction", "avg_rating": 3.8, "review_count": 5, "in_stock": true}' \
  600

mc_set "book:43" \
  '{"id": 43, "title": "The Hitchhiker'\''s Guide to the Galaxy", "authors": ["Douglas Adams"], "price": 8.99, "genre": "Science Fiction", "avg_rating": 3.6, "review_count": 5, "in_stock": true}' \
  600

mc_set "customer:1" \
  '{"id": 1, "name": "Alice Johnson", "email": "alice@example.com"}' \
  600

mc_set "customer:2" \
  '{"id": 2, "name": "Bob Smith", "email": "bob@example.com"}' \
  600

mc_set "customer:3" \
  '{"id": 3, "name": "Carol Williams", "email": "carol@example.com"}' \
  600

mc_set "customer:4" \
  '{"id": 4, "name": "Dan Chen", "email": "dan@example.com"}' \
  600

mc_set "customer:5" \
  '{"id": 5, "name": "Elena Rodriguez", "email": "elena@example.com"}' \
  600

echo "==> Memcached seeding complete."
echo ""
echo "Try these commands:"
echo "  docker compose exec seed sh -c \"printf 'get session:2ab7b932d89d2388\\r\\n' | nc -q 1 kvstore 11211\""
echo "  docker compose exec seed sh -c \"printf 'get query:top_rated_books\\r\\n' | nc -q 1 kvstore 11211\""
echo "  docker compose exec seed sh -c \"printf 'get book:1\\r\\n' | nc -q 1 kvstore 11211\""
echo "  docker compose exec seed sh -c \"printf 'incr ratelimit:alice@example.com:2025-02-25 1\\r\\n' | nc -q 1 kvstore 11211\""
