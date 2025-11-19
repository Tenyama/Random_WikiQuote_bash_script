#!/usr/bin/env bash

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
echo "'$QUOTES'"

# Extract <li> elements and remove nested tags
QUOTE_LIST=$(python -c "
import sys
import re
from html.parser import HTMLParser

class QuoteParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_quote = False
        self.quote_depth = 0
        self.quotes = []
        self.current_quote = []
    
    def handle_starttag(self, tag, attrs):
        if tag == 'li':
            if self.quote_depth == 0:
                self.in_quote = True
            self.quote_depth += 1
    
    def handle_endtag(self, tag):
        if tag == 'li':
            self.quote_depth -= 1
            if self.quote_depth == 0 and self.in_quote:
                self.in_quote = False
                quote_text = ''.join(self.current_quote).strip()
                if quote_text:
                    # Clean up the text
                    quote_text = re.sub(r'\[citation[^\]]*\]', '', quote_text)  # Remove [citation needed]
                    quote_text = re.sub(r'\[sic\]', '', quote_text)  # Remove [sic]
                    quote_text = re.sub(r'\s+', ' ', quote_text)  # Normalize whitespace
                    quote_text = quote_text.strip()
                    if quote_text:
                        self.quotes.append(quote_text)
                self.current_quote = []
    
    def handle_data(self, data):
        if self.in_quote and self.quote_depth == 1:
            self.current_quote.append(data)

parser = QuoteParser()
html_content = sys.stdin.read()
parser.feed(html_content)

for quote in parser.quotes:
    print(quote)
" <<<"$QUOTES")

echo "'$QUOTE_LIST'"

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
