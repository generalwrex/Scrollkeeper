"""Scrollkeeper: watch WoW Forever builds for scroll changes.

Every Forever build is on wago.tools (product "wowf"). This script:
  1. asks wago.tools for the latest Forever build
  2. if it's new, downloads the item and spell name tables for it
  3. keeps only what Scrollkeeper cares about (see Interesting below)
  4. compares with the last build it saw and writes a report:
       tools/watch/reports/<build>.md
  5. saves the new snapshot in tools/watch/snapshots/<build>.json

Run:  python tools/watch/scroll_watch.py          (only if there's a new build)
      python tools/watch/scroll_watch.py --force  (redo the latest build)
Exit code 0, and the last line says "NEW BUILD" or "no new build".
Only uses the standard library.
"""
import csv, io, json, os, sys, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
SNAPSHOTS = os.path.join(HERE, "snapshots")
REPORTS = os.path.join(HERE, "reports")
STATE = os.path.join(HERE, "state.json")
API = "https://wago.tools"
AGENT = {"User-Agent": "scroll-watch (WoW addon data check)"}

COMPREHENSION = "3012"      # skill line: untranslated scrolls need it
MAGE = "128"                # AllowableClass bit for mages
LIGHT_FEATHER = "17056"
ITEM_FIELDS = ["Display_lang", "Description_lang", "AllowableClass", "RequiredSkill", "RequiredSkillRank",
               "RequiredLevel", "ItemLevel", "Stackable", "Bonding", "OverallQualityID"]
SPELL_WORDS = ("Comprehend", "Study", "Familiar", "Imbue", "Liminal", "Khadgar", "Scroll", "Research",
               "Evocation", "Cryoblast", "Confuse Beast", "Rebuke Elemental")


def get(url):
    request = urllib.request.Request(url, headers=AGENT)
    with urllib.request.urlopen(request, timeout=120) as response:
        return response.read().decode("utf-8")


def table(name, build):
    csv.field_size_limit(10 ** 9)
    return csv.DictReader(io.StringIO(get(f"{API}/db2/{name}/csv?build={build}")))


def interesting_item(row):
    name = row.get("Display_lang", "")
    if row.get("RequiredSkill") == COMPREHENSION:
        return True                                    # untranslated scrolls
    if row.get("AllowableClass") == MAGE and ("Scroll" in name or "scroll" in name):
        return True                                    # mage scrolls
    if name.startswith("Scroll of") or name.startswith("Scroll:"):
        return True                                    # any other scroll (standard, event...)
    return row.get("ID") == LIGHT_FEATHER or "Light Feather" in name or "Bundle of Scrolls" in name


def snapshot(build):
    items = {}
    for row in table("ItemSparse", build):
        if interesting_item(row):
            items[row["ID"]] = {field: row.get(field, "") for field in ITEM_FIELDS}
    spells = {}
    for row in table("SpellName", build):
        name = row.get("Name_lang", "")
        if any(word in name for word in SPELL_WORDS):
            spells[row["ID"]] = name
    return {"build": build, "items": items, "spells": spells}


def diff(old, new, label, describe):
    lines = []
    for key in sorted(set(new) - set(old), key=int):
        lines.append(f"- **new {label}** {key}: {describe(new[key])}")
    for key in sorted(set(old) - set(new), key=int):
        lines.append(f"- **removed {label}** {key}: {describe(old[key])}")
    for key in sorted(set(old) & set(new), key=int):
        if old[key] != new[key]:
            if isinstance(old[key], dict):
                changes = [f"{f}: `{old[key].get(f)}` -> `{new[key].get(f)}`"
                           for f in ITEM_FIELDS if old[key].get(f) != new[key].get(f)]
                lines.append(f"- **changed {label}** {key} {new[key].get('Display_lang')}: " + "; ".join(changes))
            else:
                lines.append(f"- **changed {label}** {key}: `{old[key]}` -> `{new[key]}`")
    return lines


def item_text(item):
    tier = f" (needs Comprehension {item['RequiredSkillRank']})" if item.get("RequiredSkill") == COMPREHENSION else ""
    return f"{item.get('Display_lang')}{tier}"


def main():
    force = "--force" in sys.argv
    os.makedirs(SNAPSHOTS, exist_ok=True)
    os.makedirs(REPORTS, exist_ok=True)
    state = json.load(open(STATE)) if os.path.exists(STATE) else {}
    latest = json.loads(get(f"{API}/api/builds/wowf/latest"))
    build = latest["version"]
    if build == state.get("build") and not force:
        print(f"Forever build {build}: no new build")
        return

    snap = snapshot(build)
    json.dump(snap, open(os.path.join(SNAPSHOTS, f"{build}.json"), "w", encoding="utf-8"), indent=1, ensure_ascii=False)

    previous = state.get("build")
    old = None
    if previous and previous != build and os.path.exists(os.path.join(SNAPSHOTS, f"{previous}.json")):
        old = json.load(open(os.path.join(SNAPSHOTS, f"{previous}.json"), encoding="utf-8"))

    lines = [f"# Forever {build}", "", f"Found on wago.tools {latest.get('created_at')}.", ""]
    if old:
        changes = diff(old["items"], snap["items"], "item", item_text) + diff(old["spells"], snap["spells"], "spell", str)
        lines += [f"Compared with {previous}.", ""] + (changes or ["No scroll changes."])
    else:
        lines += ["First snapshot (nothing to compare with yet).", "",
                  f"{len(snap['items'])} scroll items, {len(snap['spells'])} spells."]
    report = os.path.join(REPORTS, f"{build}.md")
    open(report, "w", encoding="utf-8").write("\n".join(lines) + "\n")

    state["build"] = build
    json.dump(state, open(STATE, "w"), indent=1)
    print("\n".join(lines))
    print(f"NEW BUILD {build}: report in {report}")


if __name__ == "__main__":
    main()
