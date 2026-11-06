#!/usr/bin/env python3
"""Turns sketchybar-app-font's icon_map.sh into the Spaces widget's app-icons.json.

Run it with the icon_map.sh from the sketchybar-app-font release whose font is
in resources/sketchybar, after updating the font:
    tools/app-icons.py path/to/icon_map.sh resources/widgets/spaces/app-icons.json
"""
import json
import re
import sys

source, target = sys.argv[1], sys.argv[2]
text = open(source, encoding="utf-8").read()
exact, prefixes = {}, []
for patterns, icon in re.findall(r'^\s*(".*?)\)\s*\n\s*icon_result="(:[^"]+:)"', text, re.M):
    for name, star in re.findall(r'"((?:[^"\\]|\\.)*)"(\*?)', patterns):
        name = name.replace('\\"', '"')
        if star:
            prefixes.append([name, icon])
        else:
            exact.setdefault(name, icon)
# Apps the generated map has never heard of: locally built ones.
exact.update({"Macarchy Settings": ":gear:", "MacarchySettings": ":gear:", "Macarchy": ":gear:"})
with open(target, "w", encoding="utf-8") as out:
    json.dump({"default": ":default:", "exact": exact, "prefixes": prefixes}, out,
              ensure_ascii=False, indent=0, sort_keys=False)
    out.write("\n")
print(f"{len(exact)} names, {len(prefixes)} prefixes")
