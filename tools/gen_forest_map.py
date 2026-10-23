#!/usr/bin/env python3
"""Generates scenes/main/forest_test_01.tscn from the fixed ForestTest_01 layout (coordinates in gu).
Run from the project root: python3 tools/gen_forest_map.py"""

GU = 32.0

TREES = [(13, 3), (24, 3.5), (27.5, 7), (4, 11), (8.5, 12.5), (11.5, 16.5), (3, 17.5), (6, 21.5),
         (12.5, 21), (19.5, 16.5), (22.5, 12), (25.5, 15.5), (25.5, 10.5), (15.5, 19.5), (21, 21.5),
         (12.5, 9.5), (28, 13)]
BUSHES = [(14.5, 6.5, 1.0), (6.5, 15, 1.2), (19.5, 12.5, 1.0), (24.5, 19, 1.1), (9.5, 19, 1.0), (27, 3.8, 0.9)]
STONES = [(9.5, 9.6), (15.5, 12), (4.5, 13.5)]
CABIN = (2, 2)
SHED = (19, 7.5)
EXIT = (29.3, 19.25)
PATROL = [(14, 4.5), (25, 8), (24, 17), (15, 16), (6, 13)]
SURVIVOR_SPAWNS = [(7.2, 10.0), (5.0, 9.6), (11.0, 5.0)]
KILLER_SPAWNS = [(15, 0.8), (29.2, 1.2), (29.2, 10), (0.8, 13.5), (1, 23.2), (15, 23.2), (24, 23.2)]

SCENES = [
    ("session", "Script", "res://scripts/core/game_session.gd"),
    ("clock", "Script", "res://scripts/core/game_clock.gd"),
    ("bus", "Script", "res://scripts/core/sound_event_bus.gd"),
    ("bounds", "Script", "res://scripts/world/map_bounds.gd"),
    ("nav", "Script", "res://scripts/core/navigation_builder.gd"),
    ("fog", "Script", "res://scripts/perception/fog_renderer.gd"),
    ("view", "Script", "res://scripts/perception/player_perception_view.gd"),
    ("debug", "Script", "res://scripts/ui/debug_overlay.gd"),
    ("hud", "Script", "res://scripts/ui/gameplay_hud.gd"),
    ("cabin", "PackedScene", "res://scenes/world/cabin.tscn"),
    ("shed", "PackedScene", "res://scenes/world/shed.tscn"),
    ("tree", "PackedScene", "res://scenes/world/tree.tscn"),
    ("bush", "PackedScene", "res://scenes/world/bush.tscn"),
    ("stone", "PackedScene", "res://scenes/items/stone.tscn"),
    ("exit", "PackedScene", "res://scenes/world/exit.tscn"),
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
    node("Exit", None, "World", "exit", [f"position = {v(*EXIT)}"])
    node("PatrolPoints", "Node2D", "World")
    for i, (x, y) in enumerate(PATROL, 1):
        node(f"P{i}", "Marker2D", "World/PatrolPoints", props=[f"position = {v(x, y)}"], groups=["patrol_point"])
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
