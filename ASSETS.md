# ASSETS — графика и звук Prototype 0.2

Все ассеты **оригинальные**: созданы программно скриптом `tools/gen_assets.py`
(Python 3 + Pillow + numpy, фиксированные seed — результат воспроизводим).
Внешних картинок, звуков, шрифтов и сетевых ресурсов нет; генератор изображений
не использовался.

- **Автор:** сгенерировано в рамках проекта «Сосновый лагерь» (ИИ-разработчик по заданию владельца репозитория).
- **Лицензия:** принадлежат владельцу репозитория `Ilyas-ku/project.darkness`, используются без ограничений внутри проекта.
- **Перегенерация:** `python3 tools/gen_assets.py` (перезаписывает `assets/`).
- **Шрифт интерфейса:** встроенный шрифт Godot по умолчанию (входит в движок, MIT).

Плотность исходной графики — 64 px на игровую единицу; в мире рисуется с масштабом 0.5
(на экране 1:1 при зуме камеры 2×).

| Файл | Что | Где используется |
|---|---|---|
| `textures/ground_grass.png` | тайл лесной почвы: мох, трава, хвоя (бесшовный 256²) | `map_bounds.gd` |
| `textures/ground_path.png` | грунтовая тропа с камешками, мягкие края | тропы `Line2D` |
| `textures/clearing.png` | светлое пятно поляны | центральная поляна |
| `textures/floor_wood.png` | доски пола, два тона комнат | `cabin.gd` |
| `textures/wall_logs.png` | бревенчатые стены | `cabin.gd` |
| `sprites/canopy_pine_a/b.png`, `canopy_birch.png` | 3 вида крон (2 хвойные, 1 лиственная) | `tree.gd`, лесная кромка |
| `sprites/trunk_0..2.png` | стволы с корнями | `tree.gd` |
| `sprites/bush_a/b.png` | кусты | `bush.gd` |
| `sprites/detail_*.png` | папоротник, камни, пень, ветка, пучок травы | детали земли |
| `sprites/shed_roof.png` | крыша сарая (профнастил, ржавчина) | `obstacle_box.gd` |
| `sprites/survivor_sheet.png`, `killer_sheet.png` | 7 кадров: покой, 4 шага, особый (ранен / замах), повален | `character_visual.gd` |
| `sprites/stone.png`, `bottle.png` | предметы | `throwable.gd` |
| `sprites/locker.png`, `bed.png`, `table.png`, `chair.png`, `crate.png`, `rug.png`, `lamp.png`, `radio.png` | мебель и предметы дома | `locker.gd`, `furniture.gd`, `cabin.gd`, `radio.gd` |
| `sprites/door.png`, `window.png`, `gate.png` | дверь, окно, ворота выхода | `door.gd`, `window.gd`, `exit_gate.gd` |
| `sprites/blood_0..2.png`, `glass_shards.png` | следы крови, осколки | `blood_decal.gd`, `glass_shards.gd` |
| `ui/icon_heart.png`, `icon_stamina.png`, `icon_steps.png`, `icon_gate.png` | иконки HUD | `gameplay_hud.gd` |
| `audio/step_grass_0..2.wav`, `step_wood.wav` | шаги | `audio_director.gd` |
| `audio/door_creak.wav`, `window_vault.wav`, `locker.wav`, `gate_open.wav`, `furniture.wav` | взаимодействия | `audio_director.gd` |
| `audio/stone_impact.wav`, `glass_break.wav` | удар камня, бутылка | `audio_director.gd` |
| `audio/attack_swing.wav`, `attack_hit.wav` | атака | `audio_director.gd` |
| `audio/radio_loop.wav`, `night_ambience.wav` | радио, ночной фон | `audio_director.gd` |

Свет — `PointLight2D` с радиальной текстурой, создаваемой в коде (`Art.light_texture()`),
и `CanvasModulate` с ночным тоном (`GameParams.night_tint`).
