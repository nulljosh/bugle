#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
check_dir=$(mktemp -d)
trap 'rm -rf "$check_dir"' EXIT
python3 - "$check_dir/main.swift" <<'PY'
import sys
from pathlib import Path
root = Path('ios/Sources/Shared')
source = (root / 'Services/JournalFeedService.swift').read_text()
parser = source[source.index('final class FeedParser:'):]
Path(sys.argv[1]).write_text(
    (root / 'Models/JournalEntry.swift').read_text() + '\n' + parser + '\n' +
    (root / 'Services/AtomFeedParserTests.swift').read_text() + '\nfeedParserDemo()\n')
PY
swift -D DEBUG "$check_dir/main.swift"
