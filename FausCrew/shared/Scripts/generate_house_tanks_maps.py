#!/usr/bin/env python3
"""Writes HouseTanksMapCatalog+Maps.swift from Fixtures/houseTanksMaps.json.

The map catalog is contract data owned by the backend; clients never edit it by
hand. Run after copying a new fixture:

    python3 FausCrew/shared/Scripts/generate_house_tanks_maps.py

HouseTanksMapCatalogTests fails when the generated file and the fixture differ.
"""

import json
import pathlib

SHARED = pathlib.Path(__file__).resolve().parent.parent
FIXTURE = SHARED / "Fixtures" / "houseTanksMaps.json"
OUTPUT = SHARED / "Sources" / "FausCrewCore" / "Games" / "HouseTanks" / "HouseTanksMapCatalog+Maps.swift"


def number(value):
    """Shortest literal that reads back as the same Double."""
    text = repr(float(value))
    return text[:-2] if text.endswith(".0") else text


def point(value):
    return f"point({number(value['x'])}, {number(value['y'])})"


def main():
    catalog = json.loads(FIXTURE.read_text())
    lines = [
        "// Generated from Fixtures/houseTanksMaps.json by Scripts/generate_house_tanks_maps.py.",
        "// Do not edit: the backend owns the catalog; copy its fixture and run the script again.",
        "",
        "extension HouseTanksMapCatalog {",
        f"    public static let catalogVersion = {catalog['catalogVersion']}",
        f"    public static let contractRevision = \"{catalog['contractRevision']}\"",
        "",
        "    /// Every map in authored order; online play draws among those that seat the roster.",
        "    public static let maps: [HouseTanksMapDefinition] = [" + ", ".join(m["id"] for m in catalog["maps"]) + "]",
    ]
    for definition in catalog["maps"]:
        lines += [
            "",
            f"    public static let {definition['id']} = HouseTanksMapDefinition(",
            f"        id: .{definition['id']},",
            f"        version: {definition['version']},",
            "        spawnPoints: [" + ", ".join(point(p) for p in definition["spawnPoints"]) + "],",
            "        obstacles: [",
        ]
        for obstacle in definition["obstacles"]:
            rotation = "" if obstacle["rotation"] == 0 else f", rotation: {number(obstacle['rotation'])}"
            lines.append(
                f"            obstacle({number(obstacle['x'])}, {number(obstacle['y'])}, {number(obstacle['width'])}, "
                f"{number(obstacle['height'])}, .{obstacle['style']}, .{obstacle['tone']}{rotation}),"
            )
        lines += [
            "        ],",
            "        floorLines: ["
            + ", ".join(
                f"line({number(l['start']['x'])}, {number(l['start']['y'])}, {number(l['end']['x'])}, {number(l['end']['y'])})"
                for l in definition["floorLines"]
            )
            + "],",
            "        floorMarkers: [" + ", ".join(point(p) for p in definition["floorMarkers"]) + "],",
            f"        scale: {number(definition['scale'])},",
            f"        minPlayers: {definition['minPlayers']},",
            f"        maxPlayers: {definition['maxPlayers']}",
            "    )",
        ]
    lines += ["}", ""]
    OUTPUT.write_text("\n".join(lines))
    print(f"wrote {OUTPUT.relative_to(SHARED)}")


if __name__ == "__main__":
    main()
