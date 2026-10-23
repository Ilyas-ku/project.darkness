#!/usr/bin/env python3
"""Generates scenes/main/forest_test_01.tscn from the fixed ForestTest_01 layout (coordinates in gu).
Run from the project root: python3 tools/gen_forest_map.py"""

GU = 32.0

TREES = [(13, 3), (24, 3.5), (27.5, 7), (4, 11), (8.5, 12.5), (11.5, 16.5), (3, 17.5), (6, 21.5),
         (12.5, 21), (19.5, 16.5), (22.5, 12), (25.5, 15.5), (25.5, 10.5), (15.5, 19.5), (21, 21.5),
         (12.5, 9.5), (28, 13)]
BUSHES = [(1.5, 6.6, 0.9), (14.5, 6.5, 1.0), (6.5, 15, 1.2), (19.5, 12.5, 1.0), (24.5, 19, 1.1), (9.5, 19, 1.0), (27, 3.8, 0.9)]
STONES = [(10.5, 9.6), (15.5, 12), (4.5, 13.5)]
CABIN = (3, 2)
SHED = (19, 7.5)
EXIT = (29.85, 19.25)
# Areas of interest: (id, weight, is_house, bounds (x, y, w, h) gu, [(marker name, x, y)])
# Marker names sort in visiting order; "sweep" = stop and look around, "hide" = consider hiding spots.
AREAS = [
    ("house", 1.4, True, (3, 2, 8, 6), [
        ("a_approach", 9.2, 9.2), ("b_entry", 9.2, 6.9), ("c_living_sweep", 9.4, 5.4),
        ("d_inner_door", 7.9, 5.0), ("e_bedroom_sweep", 5.2, 5.0), ("f_bedroom_hide", 4.4, 3.9),
        ("g_back", 7.9, 5.0), ("h_leave", 9.2, 6.9), ("i_out", 9.2, 9.2)]),
    ("house_back", 0.8, False, (0, 2, 3, 6), [("a_sweep", 1.6, 3.6)]),
    ("shed", 1.0, False, (16, 5, 6, 6), [("a_sweep", 16.2, 7.5), ("b_sweep", 19.0, 10.2)]),
    ("clearing", 1.2, False, (12, 10, 6, 6), [("a_sweep", 15.0, 13.0)]),
    ("west_bushes", 1.0, False, (4, 13, 6, 5), [("a_sweep", 7.6, 16.6)]),
    ("south_forest", 0.9, False, (8, 17, 8, 6), [("a_sweep", 10.4, 18.4), ("b_sweep", 14.5, 21.5)]),
    ("exit_path", 1.0, False, (23, 16, 7, 6), [("a_sweep", 26.0, 19.2)]),
    ("north_forest", 0.9, False, (20, 1, 9, 7), [("a_sweep", 22.5, 5.2)]),
]
SURVIVOR_SPAWNS = [(8.2, 10.0), (6.0, 9.8), (12.0, 5.5)]
KILLER_SPAWNS = [(15, 0.8), (29.2, 1.2), (29.2, 10), (0.8, 13.5), (1, 23.2), (15, 23.2), (24, 23.2)]

SCENES = [
    ("session", "Script", "res://scripts/core/game_session.gd"),
    ("clock", "Script", "res://scripts/core/game_clock.gd"),
    ("bus", "Script", "res://scripts/core/sound_event_bus.gd"),
    ("bounds", "Script", "res://scripts/world/map_bounds.gd"),
    ("nav", "Script", "res://scripts/core/navigation_builder.gd"),
    ("aoi", "Script", "res://scripts/ai/area_of_interest.gd"),
    ("fog", "Script", "res://scripts/perception/fog_renderer.gd"),
    ("view", "Script", "res://scripts/perception/player_perception_view.gd"),
    ("debug", "Script", "res://scripts/ui/debug_overlay.gd"),
    ("hud", "Script", "res://scripts/ui/gameplay_hud.gd"),
    ("cabin", "PackedScene", "res://scenes/world/cabin.tscn"),
    ("shed", "PackedScene", "res://scenes/world/shed.tscn"),
    ("tree", "PackedScene", "res://scenes/world/tree.tscn"),
    ("bush", "PackedScene", "res://scenes/world/bush.tscn"),
    ("stone", "PackedScene", "res://scenes/items/stone.tscn"),
    ("exit", "PackedScene", "res://scenes/world/exit_gate.tscn"),
    ("survivor", "PackedScene", "res://scenes/characters/survivor.tscn"),
]


def v(x, y):
    return f"Vector2({x * GU:g}, {y * GU:g})"


def main():
    out = [f"[gd_scene load_steps={len(SCENES) + 1} format=3]", ""]
    for rid, typ, path in SCENES:
        out.append(f'[ext_resource type="{typ}" path="{path}" id="{rid}"]')
    out.append("")

    def node(name, typ=None, parent=None, inst=None, props=(), groups=None):
        head = f'[node name="{name}"'
        if typ:
            head += f' type="{typ}"'
        if parent is not None:
            head += f' parent="{parent}"'
        if inst:
            head += f' instance=ExtResource("{inst}")'
        if groups:
            head += " groups=[" + ", ".join(f'"{g}"' for g in groups) + "]"
        out.append(head + "]")
        out.extend(props)
        out.append("")

    node("ForestTest01", "Node2D", props=['script = ExtResource("session")'])
    node("GameClock", "Node", ".", props=['script = ExtResource("clock")'])
    node("SoundEventBus", "Node", ".", props=['script = ExtResource("bus")'])
    node("World", "Node2D", ".")
    node("Bounds", "StaticBody2D", "World", props=['script = ExtResource("bounds")'])
    node("NavRegion", "NavigationRegion2D", "World", props=['script = ExtResource("nav")'])
    node("Cabin", None, "World", "cabin", [f"position = {v(*CABIN)}"])
    node("Shed", None, "World", "shed", [f"position = {v(*SHED)}"])
    node("Trees", "Node2D", "World")
    for i, (x, y) in enumerate(TREES, 1):
        node(f"Tree{i:02d}", None, "World/Trees", "tree", [f"position = {v(x, y)}"])
    node("Bushes", "Node2D", "World")
    for i, (x, y, r) in enumerate(BUSHES, 1):
        node(f"Bush{i:02d}", None, "World/Bushes", "bush", [f"position = {v(x, y)}", f"radius_gu = {r}"])
    node("Items", "Node2D", "World")
    for i, (x, y) in enumerate(STONES, 1):
        node(f"Stone{i:02d}", None, "World/Items", "stone", [f"position = {v(x, y)}"])
    node("ExitGate", None, "World", "exit", [f"position = {v(*EXIT)}"])
    node("AreasOfInterest", "Node2D", "World")
    for aid, w, house, b, markers in AREAS:
        node(aid, "Node2D", "World/AreasOfInterest", props=['script = ExtResource("aoi")', f'area_id = &"{aid}"',
             f"weight = {w}", f"is_house = {'true' if house else 'false'}", f"bounds_gu = Rect2({b[0]}, {b[1]}, {b[2]}, {b[3]})"])
        for name, x, y in markers:
            node(name, "Marker2D", f"World/AreasOfInterest/{aid}", props=[f"position = {v(x, y)}"])
    node("SurvivorSpawns", "Node2D", "World")
    for i, (x, y) in enumerate(SURVIVOR_SPAWNS, 1):
        node(f"S{i}", "Marker2D", "World/SurvivorSpawns", props=[f"position = {v(x, y)}"], groups=["survivor_spawn"])
    node("KillerSpawns", "Node2D", "World")
    for i, (x, y) in enumerate(KILLER_SPAWNS, 1):
        node(f"K{i}", "Marker2D", "World/KillerSpawns", props=[f"position = {v(x, y)}"], groups=["killer_spawn"])
    node("Actors", "Node2D", "World")
    node("Survivor", None, "World/Actors", "survivor", [f"position = {v(*SURVIVOR_SPAWNS[0])}"])
    node("FogRenderer", "Node2D", ".", props=['script = ExtResource("fog")'])
    node("PerceptionView", "Node", ".", props=['script = ExtResource("view")'])
    node("DebugOverlay", "Node2D", ".", props=['script = ExtResource("debug")'])
    node("HUD", "CanvasLayer", ".", props=['script = ExtResource("hud")'])

    with open("scenes/main/forest_test_01.tscn", "w") as f:
        f.write("\n".join(out))


if __name__ == "__main__":
    main()
