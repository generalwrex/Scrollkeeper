"""Merge Scrollkeeper exports (/sk export) from many players.

Usage:
    python tools/community/merge.py exports/            # a folder of .txt files
    python tools/community/merge.py all-exports.txt     # or one file with many exports

Each export starts with the line "Scrollkeeper export 1". A file can hold
several. If the same player (same export id) appears more than once, only
their latest export counts, so pasting twice never doubles the numbers.

Prints a summary: what each tier turns into (with %), skill-up rates by
color, and how many scroll and book drop spots and books are known.
"""
import sys
from collections import defaultdict
from pathlib import Path

HEADER = "Scrollkeeper export 1"


def read_exports(paths):
    """Yield each export as a list of lines."""
    for path in paths:
        current = None
        for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
            line = raw.strip()
            if line == HEADER:
                if current:
                    yield current
                current = []
            elif current is not None and line:
                current.append(line)
        if current:
            yield current


def parse(lines):
    data = {"id": None, "version": None, "T": {}, "U": {}, "P": {}, "K": {}, "I": set(), "N": {}, "W": []}
    for line in lines:
        parts = line.split("|")
        kind = parts[0]
        try:
            if kind == "meta":
                data["version"], data["id"] = parts[1], parts[8]
            elif kind in ("T", "U", "P", "K"):
                entries = {}
                for item in parts[2].split(","):
                    key, value = item.rsplit(":", 1)
                    entries[key] = value
                data[kind][parts[1]] = entries
            elif kind == "I":
                data["I"].update(int(x) for x in parts[1].split(",") if x)
            elif kind == "N":
                data["N"][int(parts[1])] = parts[2]
            elif kind in ("W", "L"):
                data["W"].append(tuple(parts[1:5]))
        except (IndexError, ValueError):
            print(f"  skipped a bad line: {line[:60]}", file=sys.stderr)
    return data


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    target = Path(sys.argv[1])
    paths = sorted(target.glob("*.txt")) if target.is_dir() else [target]

    players = {}
    for lines in read_exports(paths):
        data = parse(lines)
        players[data["id"] or f"unknown-{len(players)}"] = data   # later exports replace earlier

    odds = defaultdict(lambda: defaultdict(int))
    skillups = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    drops, book_drops = defaultdict(int), defaultdict(int)
    books, names, libraries = set(), {}, set()
    for data in players.values():
        names.update(data["N"])
        books |= data["I"]
        for tier, items in data["T"].items():
            for item, count in items.items():
                odds[int(tier)][int(item)] += int(count)
        for tier, colors in data["U"].items():
            for color, value in colors.items():
                ups, tries = (int(x) for x in value.split("/"))
                skillups[int(tier)][color][0] += ups
                skillups[int(tier)][color][1] += tries
        for kind, target_counts in (("P", drops), ("K", book_drops)):
            for map_id, cells in data[kind].items():
                for cell, count in cells.items():
                    target_counts[(map_id, cell)] += int(count)
        libraries.update(data["W"])

    print(f"# Scrollkeeper community data: {len(players)} players\n")
    for tier in sorted(odds):
        total = sum(odds[tier].values())
        print(f"## Tier {tier}: {total} deciphered")
        for item, count in sorted(odds[tier].items(), key=lambda kv: -kv[1]):
            print(f"  {count / total:6.1%}  {count:5d}  {names.get(item, f'item {item}')}")
        print()
    if skillups:
        print("## Skill-up rates by color")
        for tier in sorted(skillups):
            for color, (ups, tries) in sorted(skillups[tier].items()):
                print(f"  tier {tier:3d} {color:6s}  {ups}/{tries}  ({ups / tries:.0%})")
        print()
    print(f"Scroll drop spots: {len(drops)} ({sum(drops.values())} scrolls)")
    print(f"Book drop spots:   {len(book_drops)} ({sum(book_drops.values())} books)")
    print(f"Books learned:     {len(books)}: {', '.join(names.get(b, str(b)) for b in sorted(books))}")
    print(f"Library spots:     {len(libraries)}")


if __name__ == "__main__":
    main()
