# Database Examples — Online Bookstore

Four databases, one domain. Each database stores the same bookstore data in the
way that plays to its strengths.

| Service | Database | Type | Port | Documentation |
|---------|----------|------|------|---------------|
| `relational` | PostgreSQL 18.2 | Relational (SQL) | 5432 | [Docs](https://www.postgresql.org/docs/18/index.html) |
| `document` | CouchDB 3.5.1 | Document | 5984 | [Docs](https://docs.couchdb.org/en/stable/) |
| `kvstore` | Memcached 1.6.40 | Key-Value Cache | 11211 | [Docs](https://github.com/memcached/memcached/wiki) |
| `fulltext` | Typesense 30.1 | Full-Text Search | 8108 | [Docs](https://typesense.org/docs/) |

## The Data

All databases are loaded with the same **online bookstore** domain data:

- **120 books** by **40 authors** across **13 genres** (fiction, sci-fi, fantasy,
  horror, mystery, literary fiction, romance, thriller, science, magical realism,
  and more) — including multi-author books (e.g., Good Omens)
- **25 customers** with varied purchase and review histories
- **355 reviews** with a realistic rating distribution (not all five-star — includes
  a healthy mix of 1-3 star reviews)
- **61 orders** containing **336 line items** with mixed statuses (delivered,
  shipped, pending, canceled)

The canonical data lives in `data/books.json` and `data/customers.json`. The
individual seed files were generated from these sources.

## Quick Start

```bash
# Prerequisites: docker or podman (with compose support) — that's it.
./setup.sh
```

This starts all four database containers, builds a lightweight seed container
(Alpine + curl + netcat), runs the seed scripts against the databases, and
exits. No host dependencies beyond a container runtime.

The setup script auto-detects whether you have `docker compose`,
`podman compose`, or `podman-compose` and uses whichever it finds.

Other modes:

```bash
./setup.sh --seed   # Re-run seed scripts (rebuilds and reruns the seed container)
./setup.sh --down   # Tear everything down (removes volumes)
```

## How Seeding Works

- **PostgreSQL** seeds itself automatically — `postgres/sql/init.sql` is mounted
  into `/docker-entrypoint-initdb.d` and runs on first container start.
- **CouchDB, Memcached, Typesense** are seeded by a one-shot `seed` container
  defined in `docker-compose.yaml`. It builds from `Dockerfile.seed` (Alpine
  with `bash`, `curl`, `netcat-openbsd`), runs all three seed scripts, then
  exits. The scripts use Docker Compose's internal DNS to reach the databases
  by service name (e.g., `document:5984` instead of `localhost:5984`).

## What Each Database Showcases

### PostgreSQL (Relational)

**File:** `postgres/sql/init.sql`

The data is **normalized** across 8 tables with foreign keys, constraints, and a
join table for the many-to-many relationship between books and authors. A view
(`book_details`) demonstrates JOINs that aggregate data from multiple tables.

```
authors ──┐
           ├── book_authors (M:N join table)
books ────┘
  │
  ├── genres (FK)
  ├── reviews ── customers
  └── order_items ── orders ── customers
```

**Try it:**

```bash
# Connect to the database
docker compose exec relational psql -U launchpad -d bookstore

# Inside psql:
SELECT * FROM book_details;
SELECT b.title, a.name FROM books b
  JOIN book_authors ba ON ba.book_id = b.id
  JOIN authors a ON a.id = ba.author_id;
```

**What it demonstrates:** Referential integrity, CHECK constraints, normalized
schema design, many-to-many relationships, aggregate views, indexes.

---

### CouchDB (Document)

**File:** `scripts/seed-couchdb.sh`

The same data is stored as **self-contained JSON documents**. A single book
document embeds its authors, reviews, and tags — no joins needed. Different
document types (books, customers) coexist in the same database, distinguished
only by a `type` field.

```json
{
  "type": "book",
  "title": "Good Omens",
  "authors": [
    {"name": "Neil Gaiman", "born_year": 1960},
    {"name": "Terry Pratchett", "born_year": 1948}
  ],
  "reviews": [
    {"customer": "Alice Johnson", "rating": 5, "body": "..."}
  ],
  "tags": ["apocalypse", "humor", "angels", "demons"]
}
```

**Try it:**

```bash
# Fetch a single document (everything in one request)
docker compose run --rm seed curl -s http://launchpad:dontdothis@document:5984/bookstore/book:dune

# Query a MapReduce view
docker compose run --rm seed curl -s 'http://launchpad:dontdothis@document:5984/bookstore/_design/bookstore/_view/books_by_genre?key="Science%20Fiction"'
```

**What it demonstrates:** Denormalized nested documents, flexible schema, embedded
arrays, mixed document types, MapReduce views.

---

### Memcached (Key-Value Cache)

**File:** `scripts/seed-memcached.sh`

Memcached has no schema, no queries, no indexes. It stores opaque blobs by key
with optional TTL (time-to-live). The seed script demonstrates four common
caching patterns:

| Pattern | Key Format | Example |
|---------|-----------|---------|
| Session tokens | `session:<token>` | Fast auth lookups with TTL |
| Cached queries | `query:<name>` | Pre-computed expensive results |
| Rate limiting | `ratelimit:<user>:<date>` | Atomic counters with daily expiry |
| Entity cache | `book:<id>` | Hot-path single-record lookups |

**Try it:**

```bash
# Get a cached session
docker compose run --rm seed sh -c "printf 'get session:2ab7b932d89d2388\r\n' | nc -q 1 kvstore 11211"

# Get cached top-rated books
docker compose run --rm seed sh -c "printf 'get query:top_rated_books\r\n' | nc -q 1 kvstore 11211"

# Atomically increment a rate limit counter
docker compose run --rm seed sh -c "printf 'incr ratelimit:alice@example.com:2025-02-25 1\r\n' | nc -q 1 kvstore 11211"

# Get a cached book entity
docker compose run --rm seed sh -c "printf 'get book:1\r\n' | nc -q 1 kvstore 11211"
```

**What it demonstrates:** Simple get/set semantics, TTL-based expiry, atomic
increment/decrement, serialized JSON values, caching patterns.

---

### Typesense (Full-Text Search)

**File:** `scripts/seed-typesense.sh`

Same book data, but structured for **search**. Each book has a `description`
field that enables thematic full-text queries. The collection schema defines
field types and marks fields as `facet: true` for filtered search.

**Try it:**

```bash
# Typo-tolerant search (note the misspelling "duen"):
docker compose run --rm seed curl -s -H 'X-TYPESENSE-API-KEY: dontdothis' \
  'http://fulltext:8108/collections/books/documents/search?q=duen&query_by=title'

# Search by theme across title + description:
docker compose run --rm seed curl -s -H 'X-TYPESENSE-API-KEY: dontdothis' \
  'http://fulltext:8108/collections/books/documents/search?q=prophecy+desert&query_by=title,description'

# Faceted search — Fantasy books sorted by price:
docker compose run --rm seed curl -s -H 'X-TYPESENSE-API-KEY: dontdothis' \
  'http://fulltext:8108/collections/books/documents/search?q=*&query_by=title&filter_by=genre:Fantasy&sort_by=price:asc&facet_by=tags'

# Find books by author name:
docker compose run --rm seed curl -s -H 'X-TYPESENSE-API-KEY: dontdothis' \
  'http://fulltext:8108/collections/books/documents/search?q=gaiman&query_by=title,authors,description'
```

**What it demonstrates:** Typed collection schemas, full-text search with typo
tolerance, relevance ranking, faceted filtering, multi-field search, sort by
numeric fields.

## Credentials

All services use the same credentials for simplicity (do not do this in production):

| Service | User | Password / API Key |
|---------|------|--------------------|
| PostgreSQL | `launchpad` | `dontdothis` |
| CouchDB | `launchpad` | `dontdothis` |
| Typesense | — | `dontdothis` (API key) |
| Memcached | — | (no auth) |

## Project Structure

```
.
├── setup.sh                    # One-command setup (only needs docker)
├── docker-compose.yaml         # All four databases + seed container
├── Dockerfile.seed             # Alpine image with curl + netcat for seeding
├── data/
│   ├── books.json              # Canonical source: 120 books, 40 authors, 13 genres
│   └── customers.json          # 25 customers, 355 reviews, 61 orders
├── postgres/
│   └── sql/
│       └── init.sql            # Relational schema + seed data (auto-loaded by Postgres)
├── scripts/
│   ├── seed-all.sh             # Entrypoint: runs the three scripts below in order
│   ├── seed-couchdb.sh         # Document DB seed script
│   ├── seed-memcached.sh       # KV cache seed script
│   └── seed-typesense.sh       # Search engine seed script
└── README.md
```

## Resetting

To start completely fresh:

```bash
./setup.sh --down
rm -rf postgres/data couchdb/data typesense/data
./setup.sh
```
