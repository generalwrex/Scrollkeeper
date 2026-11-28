#!/usr/bin/env python3
# Scrollkeeper by generalwrex. Created 2026-11-24.
# Read the LICENSE file before using any of this code.
"""Make the in-game news from CHANGELOG.md.

Writes Data/News.lua: one chat message, shown once per account the first
time someone opens the panel after updating, standing out in chat (bright
lines above and below, bright colors). It's written in Natop's voice,
with the top changelog entries as bullets.

    python tools/make-news.py            # from the top of the changelog
    python tools/make-news.py 1.3.0      # say it's version 1.3.0

Which entries: the newest "## 1.2.3" section, or every "## Unreleased..."
section above the first released one. If a section has lines starting with
"> ", those are the news, word for word (one line each); otherwise the top
"New..." and "Fixed..." bullets are shortened into it. The release workflow runs this before
packaging, with the tag's version, so every release gets its own news.
"""

import hashlib
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAX_BULLETS = 7
MAX_LENGTH = 170

GREETINGS = [
    "Hey, Natop here! Scrollkeeper {v} is out. Here's what's new:",
    "Hi from Natop! Scrollkeeper {v} just landed:",
    "Natop here with Scrollkeeper {v}. What's new:",
    "Hey! Scrollkeeper {v} is here. The good stuff:",
]
SIGNOFFS = [
    "Thanks for using Scrollkeeper! Bugs or ideas: /sk options > About. - Natop (Archmage Naage)",
    "Have fun, and tell me what breaks: /sk options > About. - Natop (Archmage Naage)",
    "Thanks for playing with it! Ideas welcome (/sk options > About). - Natop (Archmage Naage)",
]


def sections(text):
    """[(heading, [top-level bullet text, ...], [news lines])] in changelog order."""
    out = []
    for block in re.split(r"(?m)^## ", text)[1:]:
        heading, _, body = block.partition("\n")
        bullets, news = [], []
        for line in body.splitlines():
            if line.startswith("- "):
                bullets.append(line[2:].strip())
            elif line.startswith("> "):
                news.append(plain(line[2:].strip()))
        out.append((heading.strip(), bullets, news))
    return out


def plain(text):
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"`(.+?)`", r"\1", text)
    text = re.sub(r"\[(.+?)\]\(.+?\)", r"\1", text)
    return text.replace("\\", "").replace('"', "'")


def short(text):
    """The first sentence (two if the first is tiny), at most MAX_LENGTH."""
    text = plain(text)
    text = re.sub(r"\s*\([^()]*\)", "", text)          # no (asides)
    text = text.split("; ")[0].rstrip(".") + "." if "; " in text.split(". ")[0] else text
    parts = re.split(r"(?<=[.!?])\s+", text)
    result = parts[0]
    if len(result) < 40 and len(parts) > 1:
        result += " " + parts[1]
    if len(result) > MAX_LENGTH:
        result = result[: MAX_LENGTH - 3].rsplit(" ", 1)[0] + "..."
    return result


def main():
    changelog = open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8").read()
    all_sections = sections(changelog)
    picked = []
    for heading, bullets, news in all_sections:
        if heading.lower().startswith("unreleased"):
            picked.append((heading, bullets, news))
        else:
            if not picked:
                picked.append((heading, bullets, news))
            break
    if not picked:
        sys.exit("make-news: nothing in CHANGELOG.md")

    version = sys.argv[1].lstrip("v") if len(sys.argv) > 1 else None
    if not version:
        top = picked[0][0]
        version = top if re.match(r"^\d", top) else "update"

    # The biggest sections first; one line from each (its first bullet),
    # then the other "New..." lines.
    picked.sort(key=lambda section: -len(section[1]))
    lines = [line for _, _, news in picked for line in news][:MAX_BULLETS]
    if not lines:
        bullets, seen = [], set()
        for _, items, _ in picked:
            if items:
                bullets.append(items[0])
        for _, items, _ in picked:
            bullets.extend(item for item in items[1:] if item.startswith("New") or item.startswith("Fixed"))
        for bullet in bullets:
            line = short(bullet)
            if line and line not in seen:
                seen.add(line)
                lines.append(line)
            if len(lines) >= MAX_BULLETS:
                break

    pick = int(hashlib.md5(version.encode()).hexdigest(), 16)
    if version == "update":
        greeting = "Hey, Natop here! Scrollkeeper got an update. Here's what's new:"
    else:
        greeting = GREETINGS[pick % len(GREETINGS)].format(v=version)
    signoff = SIGNOFFS[pick % len(SIGNOFFS)]

    def lua(s):
        return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'

    out = [
        "-- Scrollkeeper: Data/News.lua",
        "-- MADE BY tools/make-news.py FROM CHANGELOG.md: don't edit by hand, run it again.",
        "-- The update's news, in chat once per account (see Data/Messages.lua).",
        "",
        "local _, SK = ...",
        "",
        "SK.MESSAGES = SK.MESSAGES or {}",
        "table.insert(SK.MESSAGES, 1, {",
        "    id = " + lua("news-" + version) + ",",
        "    alert = true,",
        "    lines = {",
        "        " + lua("|TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t |cffffe14d" + greeting + "|r") + ",",
    ]
    for line in lines:
        out.append("        " + lua("|cff40c8ff>|r |cffffffff" + line + "|r") + ",")
    out.append("        " + lua("|cff9fe0ff" + signoff + "|r") + ",")
    out += ["    },", "})", ""]
    path = os.path.join(ROOT, "Data", "News.lua")
    # Keep the file's header (author, creation date, license note) on top.
    if os.path.exists(path):
        old = open(path, encoding="utf-8").read().split("\n")
        header = []
        for line in old:
            if line.startswith("-- Scrollkeeper by ") or line.startswith("-- Read the LICENSE"):
                header.append(line)
            else:
                break
        out = header + out
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out))
    print(f"make-news: wrote Data/News.lua for {version} ({len(lines)} bullets)")


if __name__ == "__main__":
    main()
