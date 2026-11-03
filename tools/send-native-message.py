"""Prints what a browser sends the native-messaging helper, for testing it without a browser."""
import json
import struct
import sys

links = [{
    "url": url,
    "cookies": "session=abc123; theme=dark",
    "useragent": "Mozilla/5.0 Test",
    "referrer": "https://example.com/page",
    "postdata": "",
} for url in sys.argv[1:]]
message = json.dumps({"url_links": links, "version": "4.0.0"}).encode()
sys.stdout.buffer.write(struct.pack('<I', len(message)) + message)
