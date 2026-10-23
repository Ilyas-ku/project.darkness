# Сосновый лагерь — первый играбельный прототип

2D top-down, Godot 4.4.1, GDScript, без внешних пакетов и ассетов (примитивная геометрия).
Один выживший (игрок) против одного ИИ-маньяка на карте ForestTest_01 (30 × 24 gu, 1 gu = 32 px).

## 1. Версия Godot
**Godot 4.4.1-stable (official, 49a5bc7b6)**, рендерер GL Compatibility. Именно на этой версии проект проверен.

## 2. Главная сцена
`res://scenes/main/forest_test_01.tscn` (задана как `run/main_scene`).

## 3. Запуск
- Редактор: открыть папку проекта в Godot 4.4.1 → F5.
- Из консоли:
  ```
  godot --path .                         # игра
  godot --path . -- --seed=42            # фиксированный seed (спавны, случайности ИИ)
  godot --path . -- --skip-prep --debug  # без 30 с подготовки, debug включён (только для отладки)
  ```
- Тесты (headless; при чистой копии сначала импорт):
  ```
  godot --headless --path . --import
  godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd
  godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- --only=acceptance
  ```
  Код выхода 0 — все тесты прошли.

### Управление
| Действие | Ввод |
|---|---|
| Ходьба / взгляд | WASD / курсор мыши |
| Спринт / осторожный шаг | Shift / Ctrl (удерживать) |
| Взаимодействие | E (объект в пределах 1.2 gu, ближайший к курсору) |
| Бросок камня | ЛКМ; слот инвентаря — 1 / 2 |
| Выглянуть из шкафа | ПКМ (удерживать) |
| Debug overlay | F3 |
| Пауза / рестарт | Esc / R (R — только в debug или на экране итогов) |

## 4. Реализованные системы
| Система | Скрипты |
|---|---|
| Конфигурация (все MVP-числа) | `scripts/config/game_params.gd`, `config/game_params.tres` |
| Выживший: движение, выносливость, взаимодействия, шкаф | `scripts/characters/survivor_controller.gd`, `stamina.gd`, `health_component.gd` |
| Маньяк: тело, навигация, двери, шкафы, удар | `scripts/characters/killer_motor.gd` |
| ИИ: FSM PREPARE/PATROL/CHASE/LAST_SEEN/INVESTIGATE/SEARCH/ATTACK | `scripts/ai/killer_brain.gd`, `killer_states.gd` |
| Зрение: сектор 110°, 5 gu, LOS-raycast по силуэту, накопление в кусте | `scripts/perception/vision_sensor.gd` |
| Слух и санитизация наблюдений | `scripts/perception/hearing_sensor.gd`, `observation.gd`, `scripts/core/sound_event_bus.gd` |
| Память ИИ (last seen, анти-эксплойт звуков 4 с) | `scripts/memory/ai_memory.gd` |
| Fog of war: UNEXPLORED / EXPLORED / VISIBLE | `scripts/memory/exploration_memory.gd`, `scripts/perception/fog_renderer.gd`, `player_perception_view.gd` |
| Камень, инвентарь (2 слота), контракт взаимодействий | `scripts/interactions/{throwable,inventory,interactable}.gd` |
| Мир: дерево, куст, дом, дверь, шкаф, сарай, выход, границы | `scripts/world/*.gd`, `scenes/world/*.tscn` |
| Навигация (bake в рантайме из статических коллайдеров) | `scripts/core/navigation_builder.gd` |
| Поток матча, пауза, рестарт, seed | `scripts/core/game_session.gd` |
| HUD, экран итогов, debug overlay | `scripts/ui/gameplay_hud.gd`, `debug_overlay.gd` |

Поток данных ИИ: `WorldState → VisionSensor/HearingSensor → Observation.* → AIMemory → KillerBrain → KillerMotor`.
`KillerBrain` не ссылается на выжившего и не имеет списка его координат; из мира он знает только статику (точки патруля, места шкафов).
Шаги передаются ИИ и HUD только как `is_nearby_presence=true` без позиции, направления, роли и id.

### Структура
```
project.godot
config/game_params.tres
scenes/main/forest_test_01.tscn          # генерируется tools/gen_forest_map.py
scenes/characters/{survivor,killer}.tscn
scenes/world/{tree,bush,cabin,door,locker,shed,exit}.tscn
scenes/items/stone.tscn
scripts/{config,characters,perception,memory,ai,interactions,core,ui,world}/
tests/{unit,integration,smoke}/, tests/run_tests.gd, tests/test_case.gd
tools/gen_forest_map.py, tools/screenshot_tour.gd, tools/soak_test.gd
```

## 5. Критерии приёмки
Статус по результатам автотестов в этом репозитории (29/29 PASS) и визуальной проверки скриншотами (Xvfb + программный OpenGL).

| ID | Статус | Чем проверено |
|---|---|---|
| AC-01 | PASS | smoke `test_main_scene` (загрузка сцены); импорт и открытие редактора без ошибок |
| AC-02 | PASS | unit `test_movement_stamina` |
| AC-03 | PASS | integration `test_seen_then_behind_wall_goes_last_seen` |
| AC-04 | PASS | integration (CHASE + обновление last seen) |
| AC-05 | PASS | integration + `test_tree_and_stone_decoy` (ствол дерева) |
| AC-06 | PASS | integration `test_long_search_returns_to_patrol` |
| AC-07 | PASS | `test_stone_into_shed_impacts_at_contact`, `test_tree_and_stone_decoy` |
| AC-08 | PASS | `test_stone_out_of_view_not_revealed` |
| AC-09 | PASS | `test_footsteps_behind_wall_presence_only` (гаснет ≤ 0.5 с) |
| AC-10 | PASS | integration `test_sound_does_not_break_visible_chase` |
| AC-11 | PASS | `test_locker_hides_and_peek_exposes` |
| AC-12 | PASS | `test_locker_hides_and_peek_exposes` |
| AC-13 | PASS | `test_explored_area_hides_dynamic_objects` + unit `test_exploration_memory` |
| AC-14 | PASS | `test_door_change_unseen_is_not_shown` |
| AC-15 | PASS | smoke `test_prepare_timer_and_spawn` |
| AC-16 | PASS | smoke `test_exit_escaped_and_restart` |
| AC-17 | PASS | smoke `test_caught` |
| AC-18 | PASS | `test_debug_toggle`; содержимое оверлея проверено скриншотом |

Ввод в тестах подаётся программно (`SurvivorController.scripted_input`). **Живая игра с клавиатурой и мышью на реальном desktop мной не проводилась** — это нужно проверить вручную (сценарий ниже).

Дополнительно: `tools/soak_test.gd` — 10 минут симуляции ботом (9 матчей, все состояния FSM), ошибок скриптов нет.

## 6. Ограничения
- Производительность: игровая логика ≈ 0.7 мс/кадр (headless). FPS на реальном GPU не измерялся; на программном рендере llvmpipe 1080p — ~26 FPS, это не показатель для desktop.
- Звук — только логические события, аудиодорожек нет.
- Бот-соак и тесты используют программный ввод, а не реальные устройства.
- Баллистика камня упрощена: полёт по прямой, удар о препятствие или приземление → impact; повторно камень не подбирается.
- Слух игнорирует стены (радиус слышимости — круг).
- Карта задаётся фиксированно; `forest_test_01.tscn` генерируется скриптом `tools/gen_forest_map.py` (можно править и в редакторе, но при перегенерации правки затрутся).

## 7. Отличия от ТЗ (и почему)
- **Маньяк сам открывает закрытые двери** на своём пути (0.3 с, событие `door`). ТЗ этого не оговаривает; без этого он застревает перед закрытым домом. Навигация строится без дверей.
- **Удар о землю тоже даёт impact**: камень, не встретивший препятствия, создаёт событие в точке приземления, иначе бросок в открытое место был бы беззвучным.
- **Шкаф, открытый маньяком**: выживший выталкивается к дверце шкафа и становится видимым; дальше работает обычная MVP-атака.
- **Выглядывание замечено маньяком в погоне** → маньяк идёт открывать именно этот шкаф. В поиске (SEARCH) шкаф рядом с last seen проверяется всегда, если last seen у самой дверцы шкафа, иначе — с вероятностью `locker_check_chance` (0.6).
- **Неопознанные шаги** в PATROL запускают короткий локальный SEARCH вокруг *собственной* позиции маньяка (радиус 2.5 gu), не чаще раза в 4 с; в SEARCH — лишь продлевают поиск.
- **Звук во время LAST_SEEN/SEARCH** переводит в INVESTIGATE (свежий звук выше патруля и поиска) — это и есть механика «обмануть камнем».
- **Центр области звука смещён** случайно (до 0.75 радиуса), чтобы центр круга 2 gu не совпадал с точным источником; источник всегда внутри круга.
- **Спавн маньяка** выбирается из точек края карты: ≥ 10 gu от выжившего и вне его поля зрения.
- Input Map создаётся в рантайме (`scripts/core/input_setup.gd`), а не хранится в `project.godot`.

## 8. Debug overlay и сценарий «побег за деревом + камень»
F3 включает: сектор и LOS-лучи маньяка, состояние FSM и причины переходов, last seen, область расследуемого звука, область поиска, путь NavigationAgent, счётчики наблюдений; маньяк в debug рисуется всегда. По умолчанию всё скрыто.

Ручная проверка (≈ 2–3 минуты):
1. `godot --path . -- --seed=1`. 30 с подготовки: подберите камень у дома (E), осмотрите поляну — открытые места остаются затемнённой памятью.
2. После появления маньяка нажмите F3 и найдите его (патруль по 5 точкам).
3. Покажитесь ему на открытом месте → FSM `CHASE`.
4. Убегите (Shift) за ствол дерева, чтобы ствол перекрыл линию между вами → `LAST_SEEN`, жёлтая точка last seen остаётся там, где он вас видел.
5. Бросьте камень (ЛКМ) в сторону, противоположную вашему укрытию → `INVESTIGATE`, голубой круг вокруг места удара.
6. Уходите осторожным шагом (Ctrl) к выходу у правого края карты (жёлтая зона `EXIT`) → экран `ESCAPED`, «Повторить»/«Выйти».

Скриншоты для визуальной проверки: `xvfb-run godot --path . --rendering-driver opengl3 --fixed-fps 60 -s res://tools/screenshot_tour.gd -- --out=/tmp/shots`.
