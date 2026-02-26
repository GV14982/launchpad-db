#!/usr/bin/env bash
# =============================================================================
# Typesense Seed Script (Full-Text Search Engine)
#
# Showcases: schema-defined collections, full-text search with typo tolerance,
# faceted filtering, sorting by numeric fields, and search ranking.
#
# Typesense is purpose-built for search. Unlike a relational DB where you'd
# write complex LIKE/ILIKE queries or maintain GIN indexes, Typesense handles
# tokenization, stemming, typo correction, and relevance ranking automatically.
#
# Data: 120 books. Generated from data/books.json + data/customers.json.
# =============================================================================
set -euo pipefail

TS_HOST="${TS_HOST:-localhost}"
TS="http://${TS_HOST}:8108"
API_KEY="dontdothis"

echo "==> Waiting for Typesense to be ready..."
until curl -sf -H "X-TYPESENSE-API-KEY: ${API_KEY}" "${TS}/health" >/dev/null 2>&1; do
  sleep 1
done
echo "==> Typesense is up."

# ---------------------------------------------------------------------------
# Create the 'books' collection with a typed schema.
# Typesense requires you to define field types up front (unlike CouchDB).
# This enables it to build optimized search indexes per field.
# ---------------------------------------------------------------------------
echo "==> Creating 'books' collection..."

# Delete if exists (for idempotency).
curl -sf -X DELETE -H "X-TYPESENSE-API-KEY: ${API_KEY}" \
  "${TS}/collections/books" >/dev/null 2>&1 || true

curl -sf -X POST -H "X-TYPESENSE-API-KEY: ${API_KEY}" \
  -H "Content-Type: application/json" \
  "${TS}/collections" \
  -d '{
    "name": "books",
    "fields": [
      {"name": "title",          "type": "string"},
      {"name": "authors",        "type": "string[]"},
      {"name": "genre",          "type": "string",   "facet": true},
      {"name": "isbn",           "type": "string"},
      {"name": "price",          "type": "float"},
      {"name": "published_year", "type": "int32",    "facet": true},
      {"name": "in_stock",       "type": "bool",     "facet": true},
      {"name": "rating",         "type": "float"},
      {"name": "review_count",   "type": "int32"},
      {"name": "tags",           "type": "string[]", "facet": true},
      {"name": "description",    "type": "string"}
    ],
    "default_sorting_field": "rating"
  }' >/dev/null

echo "    Collection 'books' created."

# ---------------------------------------------------------------------------
# Index book documents. Each document includes a description field that makes
# full-text search shine — you can find books by vague thematic queries.
# ---------------------------------------------------------------------------
echo "==> Indexing book documents..."

index_book() {
  local json="$1"
  local title
  title=$(echo "${json}" | sed -n 's/.*"title"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
  title="${title:-?}"
  curl -sf -X POST -H "X-TYPESENSE-API-KEY: ${API_KEY}" \
    -H "Content-Type: application/json" \
    "${TS}/collections/books/documents" \
    -d "${json}" >/dev/null
  echo "    + ${title}"
}

index_book '{"id": "1", "title": "Dune", "authors": ["Frank Herbert"], "genre": "Science Fiction", "isbn": "978-0441013593", "price": 9.99, "published_year": 1965, "in_stock": true, "rating": 3.8, "review_count": 6, "tags": ["desert", "politics", "ecology", "epic", "spice"], "description": "Set on the desert planet Arrakis, Dune tells the story of Paul Atreides as he navigates political intrigue, ecological challenges, and a prophecy that could change the universe."}'

index_book '{"id": "2", "title": "The Fellowship of the Ring", "authors": ["J.R.R. Tolkien"], "genre": "Fantasy", "isbn": "978-0547928210", "price": 12.99, "published_year": 1954, "in_stock": true, "rating": 4.0, "review_count": 6, "tags": ["quest", "elves", "hobbits", "epic", "ring"], "description": "A hobbit named Frodo inherits a powerful ring and must journey across Middle-earth to destroy it in the fires of Mount Doom before the Dark Lord Sauron can reclaim it."}'

index_book '{"id": "3", "title": "Murder on the Orient Express", "authors": ["Agatha Christie"], "genre": "Mystery", "isbn": "978-0062693662", "price": 10.99, "published_year": 1934, "in_stock": true, "rating": 3.8, "review_count": 5, "tags": ["detective", "train", "whodunit", "poirot"], "description": "Detective Hercule Poirot investigates a murder aboard the luxurious Orient Express, where every passenger has a motive and an alibi."}'

index_book '{"id": "4", "title": "Foundation", "authors": ["Isaac Asimov"], "genre": "Science Fiction", "isbn": "978-0553293357", "price": 8.99, "published_year": 1951, "in_stock": true, "rating": 3.6, "review_count": 5, "tags": ["psychohistory", "empire", "mathematics", "civilization"], "description": "Mathematician Hari Seldon predicts the fall of the Galactic Empire and establishes the Foundation to preserve knowledge and shorten the coming dark age."}'

index_book '{"id": "5", "title": "The Left Hand of Darkness", "authors": ["Ursula K. Le Guin"], "genre": "Science Fiction", "isbn": "978-0441478125", "price": 11.99, "published_year": 1969, "in_stock": true, "rating": 4.3, "review_count": 3, "tags": ["gender", "anthropology", "winter", "alien", "identity"], "description": "An envoy from Earth visits the planet Gethen, whose inhabitants can change gender, challenging assumptions about identity, politics, and trust."}'

index_book '{"id": "6", "title": "Good Omens", "authors": ["Neil Gaiman", "Terry Pratchett"], "genre": "Fantasy", "isbn": "978-0060853983", "price": 13.99, "published_year": 1990, "in_stock": true, "rating": 4.0, "review_count": 6, "tags": ["apocalypse", "humor", "angels", "demons", "comedy"], "description": "An angel and a demon who have grown fond of Earth team up to prevent the apocalypse in this comedic tale of good, evil, and everything in between."}'

index_book '{"id": "7", "title": "American Gods", "authors": ["Neil Gaiman"], "genre": "Fantasy", "isbn": "978-0063081918", "price": 14.99, "published_year": 2001, "in_stock": true, "rating": 3.2, "review_count": 4, "tags": ["mythology", "america", "gods", "road-trip"], "description": "Shadow Moon discovers that the gods of old mythology live among us in America, and a war is brewing between them and the new gods of technology and media."}'

index_book '{"id": "8", "title": "The Color of Magic", "authors": ["Terry Pratchett"], "genre": "Fantasy", "isbn": "978-0062225672", "price": 7.99, "published_year": 1983, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["discworld", "humor", "parody", "wizard", "turtle"], "description": "The first adventure on Terry Pratchett'\''s Discworld, a flat world balanced on the backs of four elephants standing on a giant turtle, following the hapless wizard Rincewind."}'

index_book '{"id": "9", "title": "1984", "authors": ["George Orwell"], "genre": "Fiction", "isbn": "978-0451524935", "price": 9.99, "published_year": 1949, "in_stock": true, "rating": 4.2, "review_count": 5, "tags": ["dystopia", "surveillance", "totalitarian", "political", "thought-police"], "description": "In a totalitarian society where Big Brother watches everything, Winston Smith begins to question the Party and risks everything for truth and freedom."}'

index_book '{"id": "10", "title": "Animal Farm", "authors": ["George Orwell"], "genre": "Fiction", "isbn": "978-0451526342", "price": 7.99, "published_year": 1945, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["allegory", "revolution", "communism", "satire", "animals"], "description": "A group of farm animals overthrow their human farmer, only to find that their new leaders become indistinguishable from the tyrants they replaced."}'

index_book '{"id": "11", "title": "Pride and Prejudice", "authors": ["Jane Austen"], "genre": "Romance", "isbn": "978-0141439518", "price": 6.99, "published_year": 1813, "in_stock": true, "rating": 3.8, "review_count": 5, "tags": ["regency", "marriage", "class", "manners", "wit"], "description": "Elizabeth Bennet navigates issues of manners, morality, and marriage in Georgian England as she clashes with and ultimately falls for the proud Mr. Darcy."}'

index_book '{"id": "12", "title": "Sense and Sensibility", "authors": ["Jane Austen"], "genre": "Romance", "isbn": "978-0141439662", "price": 6.99, "published_year": 1811, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["sisters", "romance", "regency", "restraint", "emotion"], "description": "Two sisters, one rational and one emotional, navigate love, heartbreak, and societal expectations in late-18th-century England."}'

index_book '{"id": "13", "title": "Emma", "authors": ["Jane Austen"], "genre": "Romance", "isbn": "978-0141439587", "price": 7.49, "published_year": 1815, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["matchmaking", "comedy", "class", "village", "romance"], "description": "Emma Woodhouse, a well-meaning but meddlesome young woman, attempts to play matchmaker for her friends with comic and sometimes disastrous results."}'

index_book '{"id": "14", "title": "Do Androids Dream of Electric Sheep?", "authors": ["Philip K. Dick"], "genre": "Science Fiction", "isbn": "978-0345404473", "price": 10.99, "published_year": 1968, "in_stock": true, "rating": 3.8, "review_count": 4, "tags": ["android", "empathy", "dystopia", "identity", "bounty-hunter"], "description": "In a post-apocalyptic world, bounty hunter Rick Deckard must retire six escaped androids while questioning what it means to be truly human."}'

index_book '{"id": "15", "title": "A Scanner Darkly", "authors": ["Philip K. Dick"], "genre": "Science Fiction", "isbn": "978-0547572178", "price": 11.49, "published_year": 1977, "in_stock": true, "rating": 3.0, "review_count": 2, "tags": ["drugs", "surveillance", "identity", "paranoia", "undercover"], "description": "An undercover agent becomes so dependent on the drug he is investigating that he can no longer distinguish his true identity from his assumed one."}'

index_book '{"id": "16", "title": "The Man in the High Castle", "authors": ["Philip K. Dick"], "genre": "Science Fiction", "isbn": "978-0547572482", "price": 10.99, "published_year": 1962, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["alternate-history", "wwii", "axis", "resistance", "reality"], "description": "In an alternate history where the Axis powers won World War II, Americans live under German and Japanese rule while a mysterious novel imagines Allied victory."}'

index_book '{"id": "17", "title": "The Shining", "authors": ["Stephen King"], "genre": "Horror", "isbn": "978-0307743657", "price": 9.99, "published_year": 1977, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["hotel", "isolation", "madness", "ghosts", "winter"], "description": "Jack Torrance takes a winter caretaker job at the Overlook Hotel with his family, where supernatural forces and his own demons slowly drive him toward violence."}'

index_book '{"id": "18", "title": "It", "authors": ["Stephen King"], "genre": "Horror", "isbn": "978-1501142970", "price": 12.99, "published_year": 1986, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["clown", "childhood", "fear", "friendship", "evil"], "description": "Seven children in Derry, Maine confront a shape-shifting evil that emerges every 27 years, then return as adults to finish what they started."}'

index_book '{"id": "19", "title": "The Stand", "authors": ["Stephen King"], "genre": "Horror", "isbn": "978-0307743688", "price": 11.99, "published_year": 1978, "in_stock": true, "rating": 2.7, "review_count": 3, "tags": ["plague", "apocalypse", "good-vs-evil", "survival", "epic"], "description": "After a superflu wipes out most of humanity, survivors are drawn to two opposing leaders in a final battle between good and evil."}'

index_book '{"id": "20", "title": "Misery", "authors": ["Stephen King"], "genre": "Horror", "isbn": "978-1501143106", "price": 9.49, "published_year": 1987, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["captivity", "obsession", "writer", "fan", "psychological"], "description": "After a car accident, novelist Paul Sheldon is rescued by his self-proclaimed number one fan, Annie Wilkes, who holds him captive and forces him to write."}'

index_book '{"id": "21", "title": "2001: A Space Odyssey", "authors": ["Arthur C. Clarke"], "genre": "Science Fiction", "isbn": "978-0451457998", "price": 8.99, "published_year": 1968, "in_stock": true, "rating": 4.3, "review_count": 3, "tags": ["space", "AI", "evolution", "monolith", "jupiter"], "description": "A mysterious monolith guides humanity from ape to spacefarer, culminating in astronaut Dave Bowman'\''s transcendent encounter beyond Jupiter."}'

index_book '{"id": "22", "title": "Rendezvous with Rama", "authors": ["Arthur C. Clarke"], "genre": "Science Fiction", "isbn": "978-0358380221", "price": 10.49, "published_year": 1973, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["alien", "exploration", "hard-sci-fi", "mystery", "spacecraft"], "description": "A massive cylindrical spacecraft enters the solar system, and a team of explorers boards it to discover an eerily empty alien world of engineered wonders."}'

index_book '{"id": "23", "title": "Childhood'\''s End", "authors": ["Arthur C. Clarke"], "genre": "Science Fiction", "isbn": "978-0345444059", "price": 9.49, "published_year": 1953, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["aliens", "utopia", "evolution", "overlords", "transcendence"], "description": "Benevolent alien Overlords bring peace to Earth, but their true purpose involves a transformation of humanity that will render the species unrecognizable."}'

index_book '{"id": "24", "title": "The Handmaid'\''s Tale", "authors": ["Margaret Atwood"], "genre": "Fiction", "isbn": "978-0385490818", "price": 10.99, "published_year": 1985, "in_stock": true, "rating": 4.2, "review_count": 5, "tags": ["dystopia", "feminism", "theocracy", "resistance", "oppression"], "description": "In the theocratic Republic of Gilead, women are stripped of all rights. Offred, a Handmaid, navigates survival and memory in a regime built on subjugation."}'

index_book '{"id": "25", "title": "Oryx and Crake", "authors": ["Margaret Atwood"], "genre": "Science Fiction", "isbn": "978-0385721677", "price": 11.99, "published_year": 2003, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["biotech", "apocalypse", "genetic-engineering", "corporate", "dystopia"], "description": "Snowman may be the last true human alive, surrounded by genetically engineered creatures, remembering the brilliant and dangerous friend who brought the world to ruin."}'

index_book '{"id": "26", "title": "Slaughterhouse-Five", "authors": ["Kurt Vonnegut"], "genre": "Fiction", "isbn": "978-0385333481", "price": 9.99, "published_year": 1969, "in_stock": true, "rating": 3.8, "review_count": 4, "tags": ["war", "time-travel", "absurdism", "dresden", "aliens"], "description": "Billy Pilgrim becomes unstuck in time, experiencing moments from his life out of order, including the firebombing of Dresden and his abduction by aliens."}'

index_book '{"id": "27", "title": "Cat'\''s Cradle", "authors": ["Kurt Vonnegut"], "genre": "Fiction", "isbn": "978-0812993543", "price": 8.99, "published_year": 1963, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["satire", "science", "religion", "apocalypse", "ice-nine"], "description": "A writer researching the atomic bomb discovers ice-nine, a substance that could freeze all water on Earth, in this darkly comic exploration of science and faith."}'

index_book '{"id": "28", "title": "Fahrenheit 451", "authors": ["Ray Bradbury"], "genre": "Fiction", "isbn": "978-1451673319", "price": 8.99, "published_year": 1953, "in_stock": true, "rating": 4.0, "review_count": 4, "tags": ["censorship", "books", "firemen", "dystopia", "knowledge"], "description": "In a future where books are banned and firemen burn them, Guy Montag begins to question his role after meeting a young woman who shows him a world of ideas."}'

index_book '{"id": "29", "title": "The Martian Chronicles", "authors": ["Ray Bradbury"], "genre": "Science Fiction", "isbn": "978-1451678192", "price": 9.49, "published_year": 1950, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["mars", "colonization", "nostalgia", "alien", "humanity"], "description": "A series of interconnected stories chronicling humanity'\''s colonization of Mars, the displacement of Martians, and the loneliness of the human condition."}'

index_book '{"id": "30", "title": "Something Wicked This Way Comes", "authors": ["Ray Bradbury"], "genre": "Horror", "isbn": "978-1501167713", "price": 10.49, "published_year": 1962, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["carnival", "evil", "youth", "temptation", "autumn"], "description": "Two thirteen-year-old boys confront the sinister Mr. Dark and his nightmarish carnival that arrives in their small town offering terrible wishes fulfilled."}'

index_book '{"id": "31", "title": "Crime and Punishment", "authors": ["Fyodor Dostoevsky"], "genre": "Fiction", "isbn": "978-0486415871", "price": 7.99, "published_year": 1866, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["guilt", "murder", "redemption", "philosophy", "poverty"], "description": "Raskolnikov, a destitute former student, murders a pawnbroker and is consumed by guilt, paranoia, and a philosophical struggle over whether he is above moral law."}'

index_book '{"id": "32", "title": "The Brothers Karamazov", "authors": ["Fyodor Dostoevsky"], "genre": "Fiction", "isbn": "978-0374528379", "price": 12.99, "published_year": 1880, "in_stock": true, "rating": 3.7, "review_count": 3, "tags": ["family", "faith", "murder", "philosophy", "russia"], "description": "Three brothers grapple with their father'\''s murder while confronting questions of faith, free will, morality, and the nature of God in tsarist Russia."}'

index_book '{"id": "33", "title": "Notes from Underground", "authors": ["Fyodor Dostoevsky"], "genre": "Fiction", "isbn": "978-0679734529", "price": 6.99, "published_year": 1864, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["existentialism", "isolation", "philosophy", "spite", "confession"], "description": "A bitter, isolated narrator delivers a rambling monologue about consciousness, free will, and the perverse pleasure of refusing to be rational."}'

index_book '{"id": "34", "title": "One Hundred Years of Solitude", "authors": ["Gabriel Garcia Marquez"], "genre": "Fiction", "isbn": "978-0060883287", "price": 11.99, "published_year": 1967, "in_stock": true, "rating": 3.8, "review_count": 5, "tags": ["magical-realism", "family", "latin-america", "time", "solitude"], "description": "Seven generations of the Buendia family live, love, and repeat history in the mythical town of Macondo in this landmark of magical realism."}'

index_book '{"id": "35", "title": "Love in the Time of Cholera", "authors": ["Gabriel Garcia Marquez"], "genre": "Romance", "isbn": "978-0307389732", "price": 10.99, "published_year": 1985, "in_stock": true, "rating": 3.0, "review_count": 3, "tags": ["love", "aging", "obsession", "patience", "river"], "description": "Florentino Ariza waits over fifty years to pursue his love for Fermina Daza, finally reuniting with her after her husband'\''s death in this meditation on love and time."}'

index_book '{"id": "36", "title": "Beloved", "authors": ["Toni Morrison"], "genre": "Fiction", "isbn": "978-1400033416", "price": 11.99, "published_year": 1987, "in_stock": true, "rating": 4.3, "review_count": 3, "tags": ["slavery", "memory", "ghost", "trauma", "motherhood"], "description": "Sethe, an escaped slave, is haunted by the ghost of her dead daughter in this wrenching exploration of the lasting trauma of slavery and the power of memory."}'

index_book '{"id": "37", "title": "Song of Solomon", "authors": ["Toni Morrison"], "genre": "Fiction", "isbn": "978-1400033423", "price": 10.99, "published_year": 1977, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["identity", "family", "flight", "heritage", "names"], "description": "Milkman Dead embarks on a journey to discover his family'\''s history, uncovering secrets that connect him to an ancestral legacy of flight and freedom."}'

index_book '{"id": "38", "title": "Norwegian Wood", "authors": ["Haruki Murakami"], "genre": "Fiction", "isbn": "978-0375704024", "price": 10.99, "published_year": 1987, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["loss", "love", "nostalgia", "youth", "tokyo"], "description": "Toru Watanabe reflects on his college years in 1960s Tokyo, torn between two very different women as he navigates loss, desire, and the passage to adulthood."}'

index_book '{"id": "39", "title": "Kafka on the Shore", "authors": ["Haruki Murakami"], "genre": "Fiction", "isbn": "978-1400079278", "price": 11.49, "published_year": 2002, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["surreal", "cats", "parallel", "metaphysics", "journey"], "description": "A fifteen-year-old runaway and an elderly man who can talk to cats find their stories converging in this dreamlike tale of fate, identity, and memory."}'

index_book '{"id": "40", "title": "1Q84", "authors": ["Haruki Murakami"], "genre": "Fiction", "isbn": "978-0307476463", "price": 14.99, "published_year": 2009, "in_stock": true, "rating": 2.5, "review_count": 2, "tags": ["parallel-worlds", "cult", "love", "mystery", "tokyo"], "description": "In an alternate 1984 Tokyo, a fitness instructor and an aspiring writer are drawn together across parallel realities shaped by a mysterious cult and two moons."}'

index_book '{"id": "41", "title": "Kindred", "authors": ["Octavia Butler"], "genre": "Science Fiction", "isbn": "978-0807083697", "price": 10.99, "published_year": 1979, "in_stock": true, "rating": 4.7, "review_count": 3, "tags": ["time-travel", "slavery", "survival", "race", "history"], "description": "A modern Black woman is repeatedly pulled back in time to antebellum Maryland, where she must ensure the survival of a white slaveholder who is her ancestor."}'

index_book '{"id": "42", "title": "Parable of the Sower", "authors": ["Octavia Butler"], "genre": "Science Fiction", "isbn": "978-1538732182", "price": 11.49, "published_year": 1993, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["dystopia", "religion", "survival", "climate", "community"], "description": "In a near-future California ravaged by climate change and inequality, young Lauren Olamina develops a new belief system and leads a community northward."}'

index_book '{"id": "43", "title": "The Hitchhiker'\''s Guide to the Galaxy", "authors": ["Douglas Adams"], "genre": "Science Fiction", "isbn": "978-0345391803", "price": 8.99, "published_year": 1979, "in_stock": true, "rating": 3.6, "review_count": 5, "tags": ["humor", "space", "earth", "absurdism", "towel", "42"], "description": "Arthur Dent escapes Earth'\''s demolition with his alien friend Ford Prefect and hitchhikes across the galaxy discovering the answer to life, the universe, and everything."}'

index_book '{"id": "44", "title": "The Restaurant at the End of the Universe", "authors": ["Douglas Adams"], "genre": "Science Fiction", "isbn": "978-0345391810", "price": 8.99, "published_year": 1980, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["humor", "space", "time-travel", "restaurant", "absurdism"], "description": "Arthur Dent and friends visit Milliways, the restaurant at the end of the universe, where diners watch the cosmos end while enjoying a nice meal."}'

index_book '{"id": "45", "title": "Frankenstein", "authors": ["Mary Shelley"], "genre": "Horror", "isbn": "978-0486282114", "price": 6.99, "published_year": 1818, "in_stock": true, "rating": 3.8, "review_count": 4, "tags": ["monster", "creation", "science", "hubris", "gothic"], "description": "Victor Frankenstein creates a living being from dead tissue and is horrified by the result, setting off a tragic chain of rejection, vengeance, and remorse."}'

index_book '{"id": "46", "title": "At the Mountains of Madness", "authors": ["H.P. Lovecraft"], "genre": "Horror", "isbn": "978-0812974416", "price": 8.99, "published_year": 1936, "in_stock": true, "rating": 3.0, "review_count": 3, "tags": ["antarctic", "lovecraft", "elder-things", "cosmic-horror", "expedition"], "description": "An Antarctic expedition discovers the ruins of a vast alien city and evidence of beings that predate humanity, with horrors that defy comprehension lurking deeper still."}'

index_book '{"id": "47", "title": "The Call of Cthulhu", "authors": ["H.P. Lovecraft"], "genre": "Horror", "isbn": "978-1689177832", "price": 5.99, "published_year": 1928, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["cthulhu", "cosmic-horror", "cult", "ocean", "madness"], "description": "A series of documents and accounts reveal the existence of Cthulhu, a monstrous entity sleeping beneath the Pacific, worshipped by cults across the world."}'

index_book '{"id": "48", "title": "Brave New World", "authors": ["Aldous Huxley"], "genre": "Fiction", "isbn": "978-0060850524", "price": 9.99, "published_year": 1932, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["dystopia", "consumerism", "conditioning", "pleasure", "control"], "description": "In a world of engineered happiness, genetic castes, and mandatory pleasure, Bernard Marx begins to question the cost of a society that has abolished suffering."}'

index_book '{"id": "49", "title": "Blood Meridian", "authors": ["Cormac McCarthy"], "genre": "Fiction", "isbn": "978-0679728757", "price": 11.99, "published_year": 1985, "in_stock": true, "rating": 3.2, "review_count": 4, "tags": ["western", "violence", "philosophy", "desert", "war"], "description": "A teenage runaway joins a gang of scalp hunters in the 1850s borderlands, led by the terrifying Judge Holden, in this unflinching meditation on violence and human nature."}'

index_book '{"id": "50", "title": "The Road", "authors": ["Cormac McCarthy"], "genre": "Fiction", "isbn": "978-0307387899", "price": 10.99, "published_year": 2006, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["post-apocalyptic", "father-son", "survival", "hope", "ash"], "description": "A father and son push a shopping cart through a scorched, ashen America, scavenging for food and avoiding marauders in a world that has lost nearly everything."}'

index_book '{"id": "51", "title": "No Country for Old Men", "authors": ["Cormac McCarthy"], "genre": "Thriller", "isbn": "978-0375706677", "price": 10.49, "published_year": 2005, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["crime", "fate", "violence", "texas", "cat-and-mouse"], "description": "When Llewelyn Moss finds two million dollars at a drug deal gone wrong, he sets off a chain of violence as the unstoppable Anton Chigurh hunts him down."}'

index_book '{"id": "52", "title": "Ficciones", "authors": ["Jorge Luis Borges"], "genre": "Fiction", "isbn": "978-0802130303", "price": 9.99, "published_year": 1944, "in_stock": true, "rating": 3.7, "review_count": 3, "tags": ["labyrinths", "philosophy", "metafiction", "infinity", "puzzles"], "description": "A collection of short stories exploring infinite libraries, forking paths, imaginary encyclopedias, and the blurred boundaries between fiction and reality."}'

index_book '{"id": "53", "title": "Things Fall Apart", "authors": ["Chinua Achebe"], "genre": "Fiction", "isbn": "978-0385474542", "price": 8.99, "published_year": 1958, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["colonialism", "igbo", "tradition", "change", "africa"], "description": "Okonkwo, a respected leader in an Igbo village, watches his world unravel as British missionaries and colonial government arrive in 1890s Nigeria."}'

index_book '{"id": "54", "title": "Mrs Dalloway", "authors": ["Virginia Woolf"], "genre": "Fiction", "isbn": "978-0156628709", "price": 8.49, "published_year": 1925, "in_stock": true, "rating": 2.7, "review_count": 3, "tags": ["stream-of-consciousness", "london", "party", "memory", "time"], "description": "Over the course of a single day in post-war London, Clarissa Dalloway prepares for a party while the narrative weaves through her memories and the lives of those around her."}'

index_book '{"id": "55", "title": "To the Lighthouse", "authors": ["Virginia Woolf"], "genre": "Fiction", "isbn": "978-0156907392", "price": 9.49, "published_year": 1927, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["memory", "time", "family", "art", "perception"], "description": "The Ramsay family and their guests visit a summer home on the Isle of Skye, and over ten years, loss and time transform their plans to visit a nearby lighthouse."}'

index_book '{"id": "56", "title": "The Old Man and the Sea", "authors": ["Ernest Hemingway"], "genre": "Fiction", "isbn": "978-0684801223", "price": 7.99, "published_year": 1952, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["sea", "fishing", "endurance", "cuba", "aging"], "description": "An aging Cuban fisherman hooks a giant marlin far out in the Gulf Stream and struggles for days to bring it home, only to lose his prize to sharks."}'

index_book '{"id": "57", "title": "A Farewell to Arms", "authors": ["Ernest Hemingway"], "genre": "Fiction", "isbn": "978-0684801469", "price": 9.99, "published_year": 1929, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["war", "love", "italy", "wwi", "loss"], "description": "An American ambulance driver on the Italian front during World War I falls in love with a British nurse, and together they try to escape the madness of war."}'

index_book '{"id": "58", "title": "For Whom the Bell Tolls", "authors": ["Ernest Hemingway"], "genre": "Fiction", "isbn": "978-0684803357", "price": 10.99, "published_year": 1940, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["spanish-civil-war", "guerrilla", "love", "duty", "sacrifice"], "description": "Robert Jordan, an American fighting with Spanish guerrillas, has three days to blow up a bridge while falling in love with a young woman named Maria."}'

index_book '{"id": "59", "title": "The Trial", "authors": ["Franz Kafka"], "genre": "Fiction", "isbn": "978-0805209990", "price": 8.99, "published_year": 1925, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["bureaucracy", "absurdism", "guilt", "law", "existential"], "description": "Josef K. is arrested one morning for an unspecified crime and spends the rest of his life navigating a bewildering, opaque legal system that offers no answers."}'

index_book '{"id": "60", "title": "The Metamorphosis", "authors": ["Franz Kafka"], "genre": "Fiction", "isbn": "978-0553213690", "price": 5.99, "published_year": 1915, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["transformation", "alienation", "family", "insect", "existential"], "description": "Gregor Samsa wakes up one morning transformed into a giant insect and must cope with his family'\''s horror, his own isolation, and the loss of his humanity."}'

index_book '{"id": "61", "title": "Neuromancer", "authors": ["William Gibson"], "genre": "Science Fiction", "isbn": "978-0441569595", "price": 10.99, "published_year": 1984, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["cyberpunk", "hacking", "AI", "cyberspace", "noir"], "description": "A washed-up computer hacker is hired for one last job: to break into a powerful artificial intelligence, in this genre-defining cyberpunk novel."}'

index_book '{"id": "62", "title": "Count Zero", "authors": ["William Gibson"], "genre": "Science Fiction", "isbn": "978-0441117734", "price": 10.49, "published_year": 1986, "in_stock": true, "rating": 3.0, "review_count": 1, "tags": ["cyberpunk", "voodoo", "AI", "art", "corporate"], "description": "Three storylines converge in a world of corporate espionage, sentient AI, and voodoo-practicing cyberspace cowboys in Gibson'\''s Sprawl trilogy sequel."}'

index_book '{"id": "63", "title": "The Fifth Season", "authors": ["N.K. Jemisin"], "genre": "Fantasy", "isbn": "978-0316229296", "price": 11.99, "published_year": 2015, "in_stock": true, "rating": 4.0, "review_count": 4, "tags": ["apocalypse", "oppression", "seismic", "identity", "survival"], "description": "On a continent racked by catastrophic seismic events, a woman with the power to control earthquakes searches for her kidnapped daughter while civilization crumbles."}'

index_book '{"id": "64", "title": "The Obelisk Gate", "authors": ["N.K. Jemisin"], "genre": "Fantasy", "isbn": "978-0316229265", "price": 11.99, "published_year": 2016, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["apocalypse", "community", "power", "survival", "obelisks"], "description": "As the world endures a devastating Season, Essun shelters in an underground community while her daughter Nassun discovers the true nature of orogeny."}'

index_book '{"id": "65", "title": "The Stone Sky", "authors": ["N.K. Jemisin"], "genre": "Fantasy", "isbn": "978-0316229241", "price": 11.99, "published_year": 2017, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["apocalypse", "moon", "resolution", "power", "motherhood"], "description": "Mother and daughter converge on opposite sides of a conflict that will determine whether the world is saved or destroyed in this conclusion to the Broken Earth trilogy."}'

index_book '{"id": "66", "title": "The Three-Body Problem", "authors": ["Liu Cixin"], "genre": "Science Fiction", "isbn": "978-0765382030", "price": 11.99, "published_year": 2008, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["physics", "alien", "china", "first-contact", "civilization"], "description": "During China'\''s Cultural Revolution, a secret military project sends signals into space, making first contact with an alien civilization on the brink of destruction."}'

index_book '{"id": "67", "title": "The Dark Forest", "authors": ["Liu Cixin"], "genre": "Science Fiction", "isbn": "978-0765386694", "price": 12.49, "published_year": 2008, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["dark-forest", "deterrence", "alien", "strategy", "civilization"], "description": "Earth prepares for an alien invasion four centuries away while grappling with the Dark Forest theory: the universe is full of hunters, and silence means survival."}'

index_book '{"id": "68", "title": "Death'\''s End", "authors": ["Liu Cixin"], "genre": "Science Fiction", "isbn": "978-0765386632", "price": 12.99, "published_year": 2010, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["cosmology", "dimensions", "sacrifice", "time", "civilization"], "description": "Spanning billions of years, the conclusion to the Remembrance of Earth'\''s Past trilogy explores the ultimate fate of civilization in a hostile universe."}'

index_book '{"id": "69", "title": "Rebecca", "authors": ["Daphne du Maurier"], "genre": "Mystery", "isbn": "978-0380730407", "price": 9.99, "published_year": 1938, "in_stock": true, "rating": 4.0, "review_count": 4, "tags": ["gothic", "mansion", "jealousy", "suspense", "identity"], "description": "A young bride moves into the grand estate Manderley, haunted by the shadow of her husband'\''s glamorous first wife, Rebecca, whose presence pervades everything."}'

index_book '{"id": "70", "title": "My Cousin Rachel", "authors": ["Daphne du Maurier"], "genre": "Mystery", "isbn": "978-0380731541", "price": 9.49, "published_year": 1951, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["suspicion", "inheritance", "love", "poison", "ambiguity"], "description": "Philip Ashley suspects his beautiful cousin Rachel of poisoning his guardian, but as he falls under her spell, he can no longer distinguish love from manipulation."}'

index_book '{"id": "71", "title": "The Name of the Wind", "authors": ["Patrick Rothfuss"], "genre": "Fantasy", "isbn": "978-0756404741", "price": 12.99, "published_year": 2007, "in_stock": true, "rating": 3.8, "review_count": 5, "tags": ["magic", "university", "music", "legend", "coming-of-age"], "description": "Kvothe, a legendary figure now living in obscurity, tells the true story of his life — from orphaned trouper'\''s child to the most notorious wizard of his age."}'

index_book '{"id": "72", "title": "The Wise Man'\''s Fear", "authors": ["Patrick Rothfuss"], "genre": "Fantasy", "isbn": "978-0756407919", "price": 13.99, "published_year": 2011, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["magic", "travel", "martial-arts", "fae", "adventure"], "description": "Kvothe continues his story: searching for the mysterious Amyr, studying with a legendary swordsman, and surviving encounters with the fae."}'

index_book '{"id": "73", "title": "The Way of Kings", "authors": ["Brandon Sanderson"], "genre": "Fantasy", "isbn": "978-0765365279", "price": 14.99, "published_year": 2010, "in_stock": true, "rating": 3.5, "review_count": 4, "tags": ["epic", "knights", "storms", "war", "honor"], "description": "On a world of stone and storms, Kaladin struggles as a slave soldier, Shallan seeks forbidden knowledge, and Dalinar pursues visions of ancient knights."}'

index_book '{"id": "74", "title": "Words of Radiance", "authors": ["Brandon Sanderson"], "genre": "Fantasy", "isbn": "978-0765365286", "price": 14.99, "published_year": 2014, "in_stock": true, "rating": 4.0, "review_count": 2, "tags": ["epic", "knights", "shardblades", "war", "oaths"], "description": "Shallan races to prevent a catastrophe while Kaladin discovers the extent of his powers and Dalinar faces assassination and political betrayal."}'

index_book '{"id": "75", "title": "Mistborn: The Final Empire", "authors": ["Brandon Sanderson"], "genre": "Fantasy", "isbn": "978-0765350381", "price": 11.99, "published_year": 2006, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["heist", "allomancy", "rebellion", "ash", "prophecy"], "description": "In a world of ash and darkness ruled by an immortal emperor, a crew of thieves with metal-based magic powers plan the ultimate heist: overthrowing the empire."}'

index_book '{"id": "76", "title": "Assassin'\''s Apprentice", "authors": ["Robin Hobb"], "genre": "Fantasy", "isbn": "978-0553573398", "price": 10.99, "published_year": 1995, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["assassin", "court", "telepathy", "coming-of-age", "wolves"], "description": "Young Fitz, the illegitimate son of a prince, is trained as a royal assassin while developing a forbidden telepathic bond with animals."}'

index_book '{"id": "77", "title": "Royal Assassin", "authors": ["Robin Hobb"], "genre": "Fantasy", "isbn": "978-0553573411", "price": 10.99, "published_year": 1996, "in_stock": true, "rating": 3.0, "review_count": 2, "tags": ["intrigue", "loyalty", "sacrifice", "court", "magic"], "description": "Fitz returns to court to find treachery everywhere as he serves his ailing king while the pretender Prince Regal plots to seize the throne."}'

index_book '{"id": "78", "title": "The Blade Itself", "authors": ["Joe Abercrombie"], "genre": "Fantasy", "isbn": "978-0316387316", "price": 11.49, "published_year": 2006, "in_stock": true, "rating": 3.7, "review_count": 3, "tags": ["grimdark", "war", "barbarian", "inquisitor", "humor"], "description": "A crippled torturer, a vain barbarian, and a disgraced nobleman are drawn into a web of war and intrigue in this darkly funny grimdark fantasy."}'

index_book '{"id": "79", "title": "Before They Are Hanged", "authors": ["Joe Abercrombie"], "genre": "Fantasy", "isbn": "978-0316387330", "price": 11.49, "published_year": 2007, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["grimdark", "quest", "siege", "war", "cynicism"], "description": "Glokta defends a besieged city, Jezal leads a doomed expedition to the edge of the world, and Logen faces his violent past."}'

index_book '{"id": "80", "title": "Last Argument of Kings", "authors": ["Joe Abercrombie"], "genre": "Fantasy", "isbn": "978-0316387378", "price": 11.49, "published_year": 2008, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["grimdark", "war", "revolution", "betrayal", "consequences"], "description": "War engulfs the Union as all plots converge, alliances shatter, and every character pays the price for the choices they have made."}'

index_book '{"id": "81", "title": "The Secret History", "authors": ["Donna Tartt"], "genre": "Thriller", "isbn": "978-1400031702", "price": 12.99, "published_year": 1992, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["academia", "murder", "classics", "obsession", "guilt"], "description": "A group of elite classics students at a Vermont college commit a murder inspired by Dionysian ritual, and their secret slowly destroys them from within."}'

index_book '{"id": "82", "title": "The Goldfinch", "authors": ["Donna Tartt"], "genre": "Fiction", "isbn": "978-0316055444", "price": 13.99, "published_year": 2013, "in_stock": true, "rating": 3.0, "review_count": 3, "tags": ["art", "loss", "addiction", "theft", "identity"], "description": "After his mother dies in a bombing at the Metropolitan Museum, thirteen-year-old Theo Decker clings to a small painting that becomes both his salvation and his burden."}'

index_book '{"id": "83", "title": "Cosmos", "authors": ["Carl Sagan"], "genre": "Science", "isbn": "978-0345539434", "price": 12.49, "published_year": 1980, "in_stock": true, "rating": 4.7, "review_count": 3, "tags": ["astronomy", "science", "wonder", "exploration", "universe"], "description": "A sweeping journey through the universe, from the Big Bang to the search for extraterrestrial intelligence, celebrating humanity'\''s quest to understand the cosmos."}'

index_book '{"id": "84", "title": "Contact", "authors": ["Carl Sagan"], "genre": "Science Fiction", "isbn": "978-1501197987", "price": 10.99, "published_year": 1985, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["seti", "first-contact", "science", "faith", "signal"], "description": "When radio astronomer Ellie Arroway detects a signal from Vega containing blueprints for a machine, humanity must decide whether to trust an alien invitation."}'

index_book '{"id": "85", "title": "The Two Towers", "authors": ["J.R.R. Tolkien"], "genre": "Fantasy", "isbn": "978-0547928203", "price": 12.99, "published_year": 1954, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["quest", "war", "fellowship", "ents", "mordor"], "description": "The Fellowship is broken. Frodo and Sam continue toward Mordor guided by the treacherous Gollum, while Aragorn, Legolas, and Gimli pursue the orcs who captured their friends."}'

index_book '{"id": "86", "title": "The Return of the King", "authors": ["J.R.R. Tolkien"], "genre": "Fantasy", "isbn": "978-0547928197", "price": 12.99, "published_year": 1955, "in_stock": true, "rating": 4.3, "review_count": 3, "tags": ["war", "king", "destiny", "sacrifice", "victory"], "description": "The final battle for Middle-earth looms as Aragorn claims his birthright and Frodo reaches Mount Doom to destroy the One Ring once and for all."}'

index_book '{"id": "87", "title": "Dune Messiah", "authors": ["Frank Herbert"], "genre": "Science Fiction", "isbn": "978-0441172696", "price": 9.99, "published_year": 1969, "in_stock": true, "rating": 3.0, "review_count": 2, "tags": ["politics", "religion", "conspiracy", "prescience", "empire"], "description": "Paul Atreides rules the Known Universe but is trapped by his own prescience, beset by conspiracies from every faction, unable to prevent the terrible future he foresees."}'

index_book '{"id": "88", "title": "Children of Dune", "authors": ["Frank Herbert"], "genre": "Science Fiction", "isbn": "978-0441104024", "price": 9.99, "published_year": 1976, "in_stock": true, "rating": 3.0, "review_count": 2, "tags": ["empire", "transformation", "ecology", "twins", "destiny"], "description": "Paul'\''s twin children inherit his prescient abilities and must navigate assassination attempts and political intrigue as the ecology of Arrakis begins to transform."}'

index_book '{"id": "89", "title": "And Then There Were None", "authors": ["Agatha Christie"], "genre": "Mystery", "isbn": "978-0062073488", "price": 9.99, "published_year": 1939, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["island", "murder", "suspense", "isolation", "nursery-rhyme"], "description": "Ten strangers are lured to a remote island where they begin dying one by one according to a children'\''s nursery rhyme, with no way to escape or identify the killer."}'

index_book '{"id": "90", "title": "The Murder of Roger Ackroyd", "authors": ["Agatha Christie"], "genre": "Mystery", "isbn": "978-0062073563", "price": 9.49, "published_year": 1926, "in_stock": true, "rating": 3.7, "review_count": 3, "tags": ["poirot", "village", "twist", "narrator", "deception"], "description": "In a quiet English village, Hercule Poirot investigates the murder of a wealthy man, only to deliver one of the most shocking twists in detective fiction history."}'

index_book '{"id": "91", "title": "Foundation and Empire", "authors": ["Isaac Asimov"], "genre": "Science Fiction", "isbn": "978-0553293371", "price": 8.99, "published_year": 1952, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["empire", "mutant", "psychohistory", "war", "surprise"], "description": "The Foundation faces two threats: the dying Galactic Empire'\''s last general, and the Mule, a mutant whose powers Seldon'\''s plan never predicted."}'

index_book '{"id": "92", "title": "Second Foundation", "authors": ["Isaac Asimov"], "genre": "Science Fiction", "isbn": "978-0553293364", "price": 8.99, "published_year": 1953, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["psychohistory", "mind-control", "secrecy", "search", "plan"], "description": "The Mule searches for the mythical Second Foundation, a hidden group of psychic scholars who may be the only force capable of restoring Seldon'\''s Plan."}'

index_book '{"id": "93", "title": "I, Robot", "authors": ["Isaac Asimov"], "genre": "Science Fiction", "isbn": "978-0553294385", "price": 8.49, "published_year": 1950, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["robots", "AI", "laws", "ethics", "logic"], "description": "Nine stories explore the evolving relationship between humans and robots, bound by the Three Laws of Robotics yet constantly finding unexpected loopholes."}'

index_book '{"id": "94", "title": "A Wizard of Earthsea", "authors": ["Ursula K. Le Guin"], "genre": "Fantasy", "isbn": "978-0547722023", "price": 8.99, "published_year": 1968, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["magic", "coming-of-age", "shadow", "islands", "naming"], "description": "Young Ged, a gifted sorcerer, unleashes a shadow creature through reckless magic and must chase it across the seas of Earthsea to restore the balance he shattered."}'

index_book '{"id": "95", "title": "The Dispossessed", "authors": ["Ursula K. Le Guin"], "genre": "Science Fiction", "isbn": "978-0061054884", "price": 11.49, "published_year": 1974, "in_stock": true, "rating": 4.0, "review_count": 2, "tags": ["anarchism", "utopia", "physics", "revolution", "dual-world"], "description": "Physicist Shevek leaves his anarchist moon colony for the capitalist planet it orbits, searching for intellectual freedom while confronting the flaws of both societies."}'

index_book '{"id": "96", "title": "Coraline", "authors": ["Neil Gaiman"], "genre": "Horror", "isbn": "978-0380807345", "price": 7.99, "published_year": 2002, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["other-mother", "buttons", "bravery", "children", "dark"], "description": "Coraline discovers a door in her new home that leads to a mirror world where everything is better — except the Other Mother wants to keep her there forever."}'

index_book '{"id": "97", "title": "Neverwhere", "authors": ["Neil Gaiman"], "genre": "Fantasy", "isbn": "978-0060557812", "price": 10.99, "published_year": 1996, "in_stock": true, "rating": 4.0, "review_count": 2, "tags": ["london-below", "urban-fantasy", "quest", "underworld", "doors"], "description": "Richard Mayhew helps an injured girl on a London street and falls through the cracks into London Below, a dangerous magical world hidden beneath the city."}'

index_book '{"id": "98", "title": "The Ocean at the End of the Lane", "authors": ["Neil Gaiman"], "genre": "Fantasy", "isbn": "978-0062255655", "price": 9.99, "published_year": 2013, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["childhood", "memory", "magic", "fear", "sacrifice"], "description": "A man returns to his childhood home and remembers the extraordinary, terrifying events that began when a mysterious girl led him to the ocean at the end of her lane."}'

index_book '{"id": "99", "title": "Mort", "authors": ["Terry Pratchett"], "genre": "Fantasy", "isbn": "978-0062225719", "price": 8.49, "published_year": 1987, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["death", "discworld", "apprentice", "humor", "duty"], "description": "Death takes on an apprentice named Mort, who makes a catastrophic mistake by saving a princess who was supposed to die, threatening the fabric of reality."}'

index_book '{"id": "100", "title": "Guards! Guards!", "authors": ["Terry Pratchett"], "genre": "Fantasy", "isbn": "978-0062225757", "price": 8.99, "published_year": 1989, "in_stock": true, "rating": 4.0, "review_count": 4, "tags": ["discworld", "dragon", "city-watch", "humor", "vimes"], "description": "Captain Vimes and the ragtag Night Watch of Ankh-Morpork must stop a secret society from using a dragon to overthrow the Patrician in this beloved Discworld entry."}'

index_book '{"id": "101", "title": "Small Gods", "authors": ["Terry Pratchett"], "genre": "Fantasy", "isbn": "978-0062237378", "price": 8.49, "published_year": 1992, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["discworld", "religion", "philosophy", "humor", "tortoise"], "description": "The Great God Om finds himself incarnated as a small tortoise, with only one true believer left, in this sharp satire of organized religion and blind faith."}'

index_book '{"id": "102", "title": "Going Postal", "authors": ["Terry Pratchett"], "genre": "Fantasy", "isbn": "978-0060502935", "price": 9.49, "published_year": 2004, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["discworld", "con-artist", "post-office", "humor", "redemption"], "description": "Convicted con artist Moist von Lipwig is given a choice: be hanged, or take over the derelict Ankh-Morpork Post Office and make it work again."}'

index_book '{"id": "103", "title": "The Hobbit", "authors": ["J.R.R. Tolkien"], "genre": "Fantasy", "isbn": "978-0547928227", "price": 10.99, "published_year": 1937, "in_stock": true, "rating": 4.2, "review_count": 4, "tags": ["dragon", "treasure", "adventure", "dwarves", "hobbit"], "description": "Bilbo Baggins, a comfort-loving hobbit, is swept into an epic quest to reclaim a dwarven kingdom from the fearsome dragon Smaug."}'

index_book '{"id": "104", "title": "Pet Sematary", "authors": ["Stephen King"], "genre": "Horror", "isbn": "978-1501156700", "price": 10.49, "published_year": 1983, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["burial-ground", "death", "grief", "resurrection", "dread"], "description": "The Creed family discovers a burial ground behind their new home that can bring the dead back to life — but what returns is never quite the same."}'

index_book '{"id": "105", "title": "Salem'\''s Lot", "authors": ["Stephen King"], "genre": "Horror", "isbn": "978-0307743671", "price": 9.99, "published_year": 1975, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["vampires", "small-town", "evil", "night", "writer"], "description": "Writer Ben Mears returns to his childhood town of Jerusalem'\''s Lot and discovers that an ancient evil has taken up residence, turning townsfolk into vampires."}'

index_book '{"id": "106", "title": "The Caves of Steel", "authors": ["Isaac Asimov"], "genre": "Science Fiction", "isbn": "978-0553293401", "price": 8.49, "published_year": 1954, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["robots", "detective", "future-city", "partnership", "prejudice"], "description": "In a future where humans live in vast enclosed cities, detective Elijah Baley must partner with a humanoid robot to solve a politically explosive murder."}'

index_book '{"id": "107", "title": "The Naked Sun", "authors": ["Isaac Asimov"], "genre": "Science Fiction", "isbn": "978-0553293395", "price": 8.49, "published_year": 1957, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["robots", "solaria", "agoraphobia", "isolation", "murder"], "description": "Detective Baley and robot Daneel travel to Solaria, a planet of extreme isolation where inhabitants never meet in person, to solve an impossible murder."}'

index_book '{"id": "108", "title": "Persuasion", "authors": ["Jane Austen"], "genre": "Romance", "isbn": "978-0141439686", "price": 6.99, "published_year": 1817, "in_stock": true, "rating": 3.7, "review_count": 3, "tags": ["regency", "second-chance", "navy", "constancy", "maturity"], "description": "Anne Elliot, who was persuaded years ago to reject Captain Wentworth, encounters him again and must navigate pride, regret, and the possibility of a second chance."}'

index_book '{"id": "109", "title": "Mansfield Park", "authors": ["Jane Austen"], "genre": "Romance", "isbn": "978-0141439808", "price": 7.49, "published_year": 1814, "in_stock": true, "rating": 3.0, "review_count": 2, "tags": ["morality", "adoption", "theater", "class", "quiet-strength"], "description": "Fanny Price, raised by wealthy relatives at Mansfield Park, quietly observes the moral failings of those around her while remaining steadfast in her own principles."}'

index_book '{"id": "110", "title": "Ubik", "authors": ["Philip K. Dick"], "genre": "Science Fiction", "isbn": "978-0547572291", "price": 9.99, "published_year": 1969, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["reality", "entropy", "afterlife", "paranoia", "consumerism"], "description": "After a bomb explosion on the Moon, Joe Chip finds reality deteriorating around him as objects regress to earlier forms and only the mysterious product Ubik can stop the decay."}'

index_book '{"id": "111", "title": "VALIS", "authors": ["Philip K. Dick"], "genre": "Science Fiction", "isbn": "978-0547572414", "price": 10.49, "published_year": 1981, "in_stock": true, "rating": 2.0, "review_count": 2, "tags": ["theology", "madness", "gnosticism", "reality", "autobiography"], "description": "Horselover Fat believes he has been contacted by a divine intelligence called VALIS, blurring the line between visionary experience and mental illness."}'

index_book '{"id": "112", "title": "The Illustrated Man", "authors": ["Ray Bradbury"], "genre": "Science Fiction", "isbn": "978-1451678185", "price": 9.49, "published_year": 1951, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["tattoos", "stories", "future", "space", "humanity"], "description": "A man covered in living tattoos tells eighteen tales of the future, each one animated on his skin — stories of rockets, rain, nurseries, and the human heart."}'

index_book '{"id": "113", "title": "The Idiot", "authors": ["Fyodor Dostoevsky"], "genre": "Fiction", "isbn": "978-0375702242", "price": 9.99, "published_year": 1869, "in_stock": true, "rating": 3.5, "review_count": 2, "tags": ["innocence", "society", "russia", "compassion", "tragedy"], "description": "Prince Myshkin, a genuinely good and compassionate man, returns to St. Petersburg society, where his innocence is exploited and destroyed by the passions around him."}'

index_book '{"id": "114", "title": "Sula", "authors": ["Toni Morrison"], "genre": "Fiction", "isbn": "978-1400033430", "price": 9.99, "published_year": 1973, "in_stock": true, "rating": 4.5, "review_count": 2, "tags": ["friendship", "community", "rebellion", "grief", "identity"], "description": "Two Black women in a small Ohio town forge a deep friendship that is tested by betrayal, convention, and the different paths they choose through life."}'

index_book '{"id": "115", "title": "Wind/Pinball", "authors": ["Haruki Murakami"], "genre": "Fiction", "isbn": "978-0804170147", "price": 10.49, "published_year": 1979, "in_stock": true, "rating": 2.5, "review_count": 2, "tags": ["youth", "loss", "bars", "japan", "nostalgia"], "description": "Murakami'\''s first two novellas follow a young narrator drifting through bars and conversations in late-1970s Japan, searching for connection in a disconnected world."}'

index_book '{"id": "116", "title": "Dawn", "authors": ["Octavia Butler"], "genre": "Science Fiction", "isbn": "978-0446603775", "price": 10.49, "published_year": 1987, "in_stock": true, "rating": 4.0, "review_count": 2, "tags": ["alien", "survival", "genetics", "identity", "choice"], "description": "Lilith Iyapo awakens after nuclear war to find herself among the Oankali, aliens who offer to save humanity but at the cost of genetic merging with their species."}'

index_book '{"id": "117", "title": "So Long, and Thanks for All the Fish", "authors": ["Douglas Adams"], "genre": "Science Fiction", "isbn": "978-0345391834", "price": 8.99, "published_year": 1984, "in_stock": true, "rating": 2.5, "review_count": 2, "tags": ["humor", "earth", "dolphins", "love", "return"], "description": "Arthur Dent returns to a mysteriously restored Earth, falls in love, and discovers why the dolphins left and what their final message really meant."}'

index_book '{"id": "118", "title": "Mona Lisa Overdrive", "authors": ["William Gibson"], "genre": "Science Fiction", "isbn": "978-0553281743", "price": 10.49, "published_year": 1988, "in_stock": true, "rating": 3.0, "review_count": 1, "tags": ["cyberpunk", "AI", "art", "cyberspace", "convergence"], "description": "The Sprawl trilogy concludes as a kidnapped girl, a razor-girl bodyguard, and others converge in a story about artificial intelligences evolving beyond human understanding."}'

index_book '{"id": "119", "title": "The Shadow of the Wind", "authors": ["Jorge Luis Borges"], "genre": "Mystery", "isbn": "978-0143034902", "price": 11.99, "published_year": 2001, "in_stock": true, "rating": 4.0, "review_count": 3, "tags": ["books", "barcelona", "mystery", "library", "obsession"], "description": "In post-war Barcelona, young Daniel discovers a forgotten novel and becomes obsessed with finding its author, uncovering a dark history intertwined with his own."}'

index_book '{"id": "120", "title": "Daggerspell", "authors": ["Robin Hobb"], "genre": "Fantasy", "isbn": "978-0553565218", "price": 8.99, "published_year": 1986, "in_stock": true, "rating": 3.7, "review_count": 3, "tags": ["reincarnation", "celtic", "magic", "destiny", "love"], "description": "A tale spanning multiple lifetimes as a sorcerer works across centuries to resolve a tragic love triangle that binds three souls through cycles of reincarnation."}'

echo "==> Typesense seeding complete."
echo ""
echo "Try these searches:"
echo "  # Typo-tolerant search (note the typo 'duen'):"
echo "  docker compose exec seed curl -s -H 'X-TYPESENSE-API-KEY: ${API_KEY}' '${TS}/collections/books/documents/search?q=duen&query_by=title'"
echo ""
echo "  # Full-text search across title + description:"
echo "  docker compose exec seed curl -s -H 'X-TYPESENSE-API-KEY: ${API_KEY}' '${TS}/collections/books/documents/search?q=prophecy+desert&query_by=title,description'"
echo ""
echo "  # Faceted search — filter by genre, sort by price:"
echo "  docker compose exec seed curl -s -H 'X-TYPESENSE-API-KEY: ${API_KEY}' '${TS}/collections/books/documents/search?q=*&query_by=title&filter_by=genre:Fantasy&sort_by=price:asc&facet_by=tags'"
echo ""
echo "  # Multi-field search with author:"
echo "  docker compose exec seed curl -s -H 'X-TYPESENSE-API-KEY: ${API_KEY}' '${TS}/collections/books/documents/search?q=gaiman&query_by=title,authors,description'"
