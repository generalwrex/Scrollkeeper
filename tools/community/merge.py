"""Merge Scrollkeeper exports (/sk export) from many players.

Usage:
    python tools/community/merge.py exports/            # a folder of .txt files
    python tools/community/merge.py all-exports.txt     # or one file with many exports
    python tools/community/merge.py tools/community/exports --lua Data/Community.lua
                                                        # also write the data the addon ships with

Save each "Share your data" issue as a .txt file in tools/community/exports
(issue-12.txt etc.), then run the --lua line and release.

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
        for raw in path.read_text(encoding="utf-8-sig", errors="replace").splitlines():
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
    data = {"id": None, "version": None, "T": {}, "U": {}, "P": {}, "K": {}, "D": {}, "I": set(), "N": {}, "W": [], "B": {}}
    for line in lines:
        parts = line.split("|")
        kind = parts[0]
        try:
            if kind == "meta":
                data["version"], data["id"] = parts[1], parts[8]
            elif kind in ("T", "U", "P", "K", "D"):
                entries = {}
                for item in parts[2].split(","):
                    key, value = item.rsplit(":", 1)
                    entries[key] = value
                data[kind][parts[1]] = entries
            elif kind == "B":
                for item in parts[1].split(","):
                    tier, value = item.split(":")
                    data["B"][tier] = value
            elif kind == "I":
                data["I"].update(int(x) for x in parts[1].split(",") if x)
            elif kind == "N":
                data["N"][int(parts[1])] = parts[2]
            elif kind in ("W", "L"):
                data["W"].append(tuple(parts[1:5]))
        except (IndexError, ValueError):
            print(f"  skipped a bad line: {line[:60]}", file=sys.stderr)
    return data


def lua_string(text):
    return '"' + str(text).replace("\\", "\\\\").replace('"', '\\"') + '"'


PACK_KEY = b"Scrollkeeper"


def pack_lines(players):
    """Every player's data as compact lines (the same shapes as the network
    messages), one "@exportid" line before each player's lines."""
    lines = []
    for export_id, data in sorted(players.items()):
        lines.append("@" + export_id)
        for tier, items in sorted(data["T"].items(), key=lambda kv: int(kv[0])):
            lines.append(f"T|{int(tier)}|" + ",".join(f"{int(i)}:{int(c)}" for i, c in sorted(items.items())))
        for tier, colors in sorted(data["U"].items(), key=lambda kv: int(kv[0])):
            lines.append(f"U|{int(tier)}|" + ",".join(f"{color}:{value}" for color, value in sorted(colors.items())))
        for kind in ("P", "K"):
            for map_id, cells in sorted(data[kind].items()):
                lines.append(f"{kind}|{int(map_id)}|" + ",".join(f"{c}:{int(n)}" for c, n in sorted(cells.items())))
        for map_id, tiers in sorted(data["D"].items()):
            lines.append(f"D|{int(map_id)}|" + ",".join(f"{int(t)}:{int(n)}" for t, n in sorted(tiers.items(), key=lambda kv: int(kv[0]))))
        if data["B"]:
            lines.append("B|" + ",".join(f"{int(t)}:{v}" for t, v in sorted(data["B"].items(), key=lambda kv: int(kv[0]))))
        if data["I"]:
            lines.append("I|" + ",".join(str(b) for b in sorted(data["I"])))
        for item, name in sorted(data["N"].items()):
            lines.append(f"N|{int(item)}|" + str(name).replace("\n", " "))
    return "\n".join(lines)


def pack(players):
    """The packed string: the lines, each byte shifted by a repeating key,
    then base64. Data/Unpack.lua turns it back into the table."""
    import base64
    raw = pack_lines(players).encode("utf-8")
    shifted = bytes((b + PACK_KEY[i % len(PACK_KEY)]) % 256 for i, b in enumerate(raw))
    return base64.b64encode(shifted).decode("ascii")


def write_lua(players, path):
    """Data/Community.lua: every player's data, packed. Data/Unpack.lua reads
    it into SK.COMMUNITY_DATA (keyed by export id, so the addon can skip a
    player's own export in their own game)."""
    packed = pack(players)
    out = [
        "-- Scrollkeeper: Data/Community.lua",
        "-- GENERATED by tools/community/merge.py from shared /sk export data.",
        "-- Don't edit by hand: add exports to tools/community/exports and re-run.",
        "-- Packed to keep it small; Data/Unpack.lua reads it.",
        f"-- Players: {len(players)}",
        "",
        "local _, SK = ...",
        "",
        "SK.COMMUNITY_PACKED = table.concat({",
    ]
    for i in range(0, len(packed), 100):
        out.append(f'    "{packed[i:i + 100]}",')
    out.append("})")
    target = Path(path)
    if target.exists():
        backup = Path(__file__).with_name("Community.lua.bak")
        backup.write_bytes(target.read_bytes())
    target.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Wrote {path} ({len(players)} players, packed)")


def write_lua_table(players, path):
    """The old readable format (not used; kept for reference)."""
    out = [
        "-- Scrollkeeper: Data/Community.lua",
        "-- GENERATED by tools/community/merge.py from shared /sk export data.",
        "-- Don't edit by hand: add exports to tools/community/exports and re-run.",
        "",
        "local _, SK = ...",
        "",
        "SK.COMMUNITY_DATA = {",
    ]
    for export_id, data in sorted(players.items()):
        out.append(f"    [{lua_string(export_id)}] = {{")
        out.append("        results = {")
        for tier, items in sorted(data["T"].items(), key=lambda kv: int(kv[0])):
            pairs = ", ".join(f"[{int(i)}] = {int(c)}" for i, c in sorted(items.items()))
            out.append(f"            [{int(tier)}] = {{ {pairs} }},")
        out.append("        },")
        out.append("        skillups = {")
        for tier, colors in sorted(data["U"].items(), key=lambda kv: int(kv[0])):
            for color, value in sorted(colors.items()):
                ups, tries = value.split("/")
                out.append(f"            [{lua_string(f'{int(tier)} {color}')}] = {{ ups = {int(ups)}, tries = {int(tries)} }},")
        out.append("        },")
        for kind, field in (("P", "drops"), ("K", "books")):
            out.append(f"        {field} = {{")
            for map_id, cells in sorted(data[kind].items()):
                pairs = ", ".join(f"[{lua_string(c)}] = {int(n)}" for c, n in sorted(cells.items()))
                out.append(f"            [{int(map_id)}] = {{ {pairs} }},")
            out.append("        },")
        out.append("        dropTiers = {")
        for map_id, tiers in sorted(data["D"].items()):
            pairs = ", ".join(f"[{int(t)}] = {int(n)}" for t, n in sorted(tiers.items(), key=lambda kv: int(kv[0])))
            out.append(f"            [{int(map_id)}] = {{ {pairs} }},")
        out.append("        },")
        out.append("        backfires = {")
        for tier, value in sorted(data["B"].items(), key=lambda kv: int(kv[0])):
            b, t = value.split("/")
            out.append(f"            [{int(tier)}] = {{ b = {int(b)}, t = {int(t)} }},")
        out.append("        },")
        books = ", ".join(str(b) for b in sorted(data["I"]))
        out.append(f"        bookIDs = {{ {books} }},")
        out.append("        names = {")
        for item, name in sorted(data["N"].items()):
            out.append(f"            [{int(item)}] = {lua_string(name)},")
        out.append("        },")
        out.append("    },")
    out.append("}")
    # Keep the previous one as tools/community/Community.lua.bak (not next to
    # it in Data/, which ships with the addon), so a bad rebuild can be undone.
    target = Path(path)
    if target.exists():
        backup = Path(__file__).with_name("Community.lua.bak")
        backup.write_bytes(target.read_bytes())
    target.write_text("\n".join(out) + "\n", encoding="utf-8")
    print(f"Wrote {path} ({len(players)} players)")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    lua_out = None
    if "--lua" in sys.argv:
        lua_out = sys.argv[sys.argv.index("--lua") + 1]
    target = Path(sys.argv[1])
    paths = sorted(target.glob("*.txt")) if target.is_dir() else [target]

    def size(data):
        return sum(int(c) for items in data["T"].values() for c in items.values())

    players = {}
    for lines in read_exports(paths):
        data = parse(lines)
        key = data["id"] or f"unknown-{len(players)}"
        known = players.get(key)
        heard = data["version"] == "heard"
        if known is not None:
            known_heard = known["version"] == "heard"
            if heard and not known_heard:
                continue                       # a player's own export beats a heard copy
            if heard and known_heard and size(data) <= size(known):
                continue                       # keep the more complete heard copy
        players[key] = data                    # otherwise later exports replace earlier

    # Never wipe the community data because nothing could be read.
    if paths and not players and lua_out:
        print(f"Found {len(paths)} export files but couldn't read any of them, so {lua_out} was left alone.")
        sys.exit(1)

    odds = defaultdict(lambda: defaultdict(int))
    skillups = defaultdict(lambda: defaultdict(lambda: [0, 0]))
    drops, book_drops = defaultdict(int), defaultdict(int)
    books, names, libraries = set(), {}, set()
    backfires = defaultdict(lambda: [0, 0])
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
        for tier, value in data["B"].items():
            b, t = (int(x) for x in value.split("/"))
            backfires[int(tier)][0] += b
            backfires[int(tier)][1] += t

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
    if backfires:
        print("## Sheep backfires")
        for tier in sorted(backfires):
            b, t = backfires[tier]
            print(f"  tier {tier:3d}  {b}/{t}  ({b / t:.1%})")
        print()
    print(f"Scroll drop spots: {len(drops)} ({sum(drops.values())} scrolls)")
    print(f"Book drop spots:   {len(book_drops)} ({sum(book_drops.values())} books)")
    print(f"Books learned:     {len(books)}: {', '.join(names.get(b, str(b)) for b in sorted(books))}")
    print(f"Library spots:     {len(libraries)}")
    if lua_out:
        write_lua(players, lua_out)


if __name__ == "__main__":
    main()
