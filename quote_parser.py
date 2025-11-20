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
