#!/usr/bin/env bash
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

TITLE="$1"
API_URL="https://en.wikiquote.org/w/api.php"

if [ -z "$TITLE" ]; then
    echo "Usage: $0 \"author or topic name\""
    exit 1
fi

# --- STEP 1: Query title → get page ID ---
PAGE_ID=$(
    curl -s "$API_URL?action=query&format=json&redirects=&titles=$(echo $TITLE | sed 's/ /%20/g')" |
        jq -r '.query.pages | to_entries[0].key'
)

if [ "$PAGE_ID" = "-1" ]; then
    echo "No page found for: $TITLE"
    exit 1
fi

# --- STEP 2: Get section list ---
SECTIONS=$(
    curl -s "$API_URL?action=parse&format=json&prop=sections&pageid=$PAGE_ID" |
        jq -r '.parse.sections[] | select(.number | startswith("1.")) | .index'
)

# fallback to section 1 if no 1.x sections
if [ -z "$SECTIONS" ]; then
    SECTIONS="1"
fi

# choose random section
SECTION=$(echo "$SECTIONS" | shuf -n 1)

# --- STEP 3: Get quotes for that section ---
QUOTES=$(
    curl -s "$API_URL?action=parse&format=json&noimages=&pageid=$PAGE_ID&section=$SECTION" |
        jq -r '.parse.text["*"]'
)

# Extract <li> elements and remove nested tags
QUOTE_LIST=$(python $SCRIPT_DIR/quote_parser.py <<<"$QUOTES")

if [ -z "$QUOTE_LIST" ]; then
    echo "No quotes found."
    exit 1
fi

# pick random quote
RANDOM_QUOTE=$(echo "$QUOTE_LIST" | shuf -n 1)

echo ""
echo "---------------------------"
echo " Random Quote from '$TITLE'"
echo "---------------------------"
echo "$RANDOM_QUOTE"
echo ""
