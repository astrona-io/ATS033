#!/usr/bin/env python3
"""Check that "About the authors" on the intro page matches AUTHORS.md."""
from pathlib import Path
import re
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
PAGE = 'sections/intro/30-how-this-course-is-made.md'
SECTION = '## About the authors'
ENTRY = re.compile(r'^- (?P<name>[^()]+?) \(GitHub: (?P<handle>[A-Za-z0-9-]+)\)$')
PHOTO_SIZE = 320
# An HTML table: a Markdown table always has a header row, which renders bold with a border.
TABLE = re.compile(
    r'^<table>\n'
    r'  <tr>\n'
    r'    <td align="center" valign="top" width="120"><img src="images/author/(?P<photo>[A-Za-z0-9-]+)\.png"'
    r' alt="(?P<alt>[^"<>]+)" width="120"></td>\n'
    r'    <td><strong>(?P<name>[^<>]+)</strong><br>(?P<bio>[^<>]+)<br>'
    r'<a href="https://github\.com/(?P<handle>[A-Za-z0-9-]+)">GitHub</a>'
    r'(?: · <a href="https://www\.linkedin\.com/in/[A-Za-z0-9_-]+/?">LinkedIn</a>)?</td>\n'
    r'  </tr>\n'
    r'</table>$')
EXAMPLE = """<table>
  <tr>
    <td align="center" valign="top" width="120"><img src="images/author/handle.png" alt="Name" width="120"></td>
    <td><strong>Name</strong><br>Short bio.<br><a href="https://github.com/handle">GitHub</a> · <a href="https://www.linkedin.com/in/name">LinkedIn</a></td>
  </tr>
</table>"""


def from_authors(text):
    """Return {(name, handle): {roles}} from the Authors and Maintainers sections."""
    people, role = {}, None
    for line in text.splitlines():
        if line.startswith('## '):
            role = {'## Authors': 'author', '## Maintainers': 'maintainer'}.get(line.strip())
        elif role and line.startswith('- '):
            match = ENTRY.match(line.strip())
            if not match:
                raise ValueError(f'AUTHORS.md: write "{line.strip()}" as "- Name (GitHub: handle)"')
            people.setdefault((match['name'], match['handle']), set()).add(role)
    if not people:
        raise ValueError('AUTHORS.md lists no authors or maintainers')
    return people


def from_page(root, text):
    """Return {name: handle} from the author tables under "About the authors"."""
    if SECTION not in text:
        raise ValueError(f'{PAGE}: missing the "{SECTION}" section')
    section = text.split(SECTION, 1)[1].split('\n## ', 1)[0]
    blocks = [block.strip() for block in section.split('\n\n') if block.strip().startswith('<table')]
    people = {}
    for block in blocks:
        table = TABLE.match(block)
        if not table:
            raise ValueError(f'{PAGE}: write each author as this table:\n{EXAMPLE}')
        name, handle = table['name'], table['handle']
        if table['photo'] != handle or table['alt'] != name:
            raise ValueError(f'{PAGE}: {name}: the photo must be images/author/{handle}.png with alt="{name}"')
        photo_path = root / 'sections/intro/images/author' / f'{handle}.png'
        if not photo_path.is_file():
            raise ValueError(f'{PAGE}: {name}: missing photo sections/intro/images/author/{handle}.png')
        head = photo_path.read_bytes()[:24]
        if head[:8] != b'\x89PNG\r\n\x1a\n' or struct.unpack('>II', head[16:24]) != (PHOTO_SIZE, PHOTO_SIZE):
            raise ValueError(f'{photo_path.relative_to(root)}: the photo must be a {PHOTO_SIZE} x {PHOTO_SIZE} pixel PNG')
        people[name] = handle
    return people


def validate(root):
    # The page shows people, not roles; roles live in AUTHORS.md.
    expected = {name: handle for name, handle in from_authors((root / 'AUTHORS.md').read_text())}
    actual = from_page(root, (root / PAGE).read_text())
    if expected != actual:
        missing = {k: v for k, v in expected.items() if actual.get(k) != v}
        extra = {k: v for k, v in actual.items() if expected.get(k) != v}
        raise ValueError(f'{PAGE} does not match AUTHORS.md; expected {missing}, found {extra}')
    return len(expected)


if __name__ == '__main__':
    try:
        count = validate(ROOT)
        print(f'PASS: AUTHORS.md and {PAGE} list the same {count} {"person" if count == 1 else "people"}')
    except (ValueError, OSError) as error:
        sys.exit(f'FAIL: {error}')
