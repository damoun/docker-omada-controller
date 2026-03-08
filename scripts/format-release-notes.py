#!/usr/bin/env python3
"""Convert pdftotext output from TP-Link release notes to Markdown."""
import sys
import re

text = sys.stdin.read()

# Remove form feeds (page breaks)
text = re.sub(r'\x0c', '\n', text)

lines = text.splitlines()
output = []
i = 0

# Known section header patterns (case-insensitive)
SECTION_RE = re.compile(
    r'^(Version Info|Supported Device Models|New Features|Enhancements|'
    r'Bugs? Fixed|Notes?|Important Notes?|Compatibility|Known Issues?)$',
    re.IGNORECASE
)

def is_section_header(line):
    return bool(SECTION_RE.match(line.strip()))

first_line = True
prev_blank = True

while i < len(lines):
    line = lines[i].rstrip()

    if not line:
        if output and output[-1] != '':
            output.append('')
        prev_blank = True
        i += 1
        continue

    # First non-empty line = document title
    if first_line:
        output.append(f'# {line.strip()}')
        first_line = False
        prev_blank = False
        i += 1
        continue

    # Section header
    if is_section_header(line):
        output.append(f'## {line.strip()}')
        prev_blank = False
        i += 1
        continue

    # Numbered list item — join continuation lines
    m = re.match(r'^(\d+)\.\s+(\*?)(.+)', line)
    if m:
        num, star, content = m.group(1), m.group(2), m.group(3).strip()
        while i + 1 < len(lines):
            nxt = lines[i + 1].rstrip()
            if not nxt:
                break
            if re.match(r'^\d+\.', nxt):
                break
            if is_section_header(nxt):
                break
            content += ' ' + nxt.strip()
            i += 1
        if star:
            output.append(f'{num}. _{content}_')
        else:
            output.append(f'{num}. {content}')
        prev_blank = False
        i += 1
        continue

    # Regular paragraph line — join wrapped continuation
    content = line.strip()
    while i + 1 < len(lines):
        nxt = lines[i + 1].rstrip()
        if not nxt:
            break
        if re.match(r'^\d+\.', nxt):
            break
        if is_section_header(nxt):
            break
        content += ' ' + nxt.strip()
        i += 1
    output.append(content)
    prev_blank = False
    i += 1

result = re.sub(r'\n{3,}', '\n\n', '\n'.join(output))
print(result.strip())
