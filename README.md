# Сосновый лагерь — Prototype 0.2 «Search & Escape»

2D top-down тактический хоррор, Godot **4.7.2**, GDScript, без внешних пакетов.
Один выживший (игрок) против ИИ-маньяка на карте ForestTest_01 (30 × 24 gu, 1 gu = 32 px).
Версия 0.2 обновляет прототип 0.1 по ТЗ v2.0: маньяк обыскивает дом и шкаф, боёвка
«ранение → повал → добивание», выход открывается удержанием E 5 секунд, камни многоразовые,
шаги вне обзора проверяемы, в доме есть окно и мебель, графика и звук сделаны заново.

## Запуск
- **Версия Godot:** 4.7.2-stable (official). Главная сцена: `res://scenes/main/forest_test_01.tscn`.
- **Редактор:** Project Manager → Import → `project.godot` → F5.
- **Консоль:**
  ```
  godot --path .                                  # игра
  godot --path . -- --seed=42                     # фиксированный seed
  godot --path . -- --preset=TEST_HOUSE_PATROL    # debug-пресет (список ниже)
  godot --path . -- --skip-prep --debug           # без подготовки, с F3-оверлеем
  ```
- **Импорт и тесты (headless):**
  ```
  godot --headless --path . --import
  godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd          # 48 тестов, код выхода 0 = всё прошло
  godot --headless --path . --fixed-fps 60 -s res://tests/run_tests.gd -- --only=house
  godot --headless --path . --fixed-fps 60 -s res://tools/soak_test.gd          # 10 мин симуляции ботом
  ```
- **Ассеты:** `python3 tools/gen_assets.py` (Pillow + numpy) перегенерирует `assets/`; карта — `python3 tools/gen_forest_map.py`.

### Управление
| Действие | Ввод |
|---|---|
| Ходьба / взгляд | WASD / мышь |
| Спринт / осторожно | Shift / Ctrl (удерживать) |
| Подобрать, дверь, шкаф, радио | E |
| Выход (5 с), окно (1.2 с), сдвинуть стул/ящик (1.5 с) | **удерживать E** (отпускание сбрасывает) |
| Бросок предмета | ЛКМ; слот — 1 / 2 / колесо мыши |
| Выглянуть из шкафа | ПКМ (удерживать) |
| Пауза | Esc |
| Перезапуск | R на экране итогов (и в debug) |
| Debug-оверлей / debug-пресеты | F3 / **F2** |

### Debug-пресеты (F2 или `--preset=`), seed 42
| Пресет | Что воспроизводит |
|---|---|
| `TEST_HOUSE_PATROL` | игрок в шкафу, маньяк патрулирует; в консоль и F3 пишутся вход в дом, осмотр комнат, проверки шкафа |
| `TEST_COMBAT` | маньяк и жертва на поляне; F3: attacks_started / hit / whiffed, причины промахов, переходы здоровья |
| `TEST_EXIT_INTERRUPT` | игрок у ворот, маньяк идёт к нему — прерывание удержания |
| `TEST_STONE_LOOP` | камень рядом, бросок и подбор |
| `TEST_FOOTSTEPS` | «DEBUG: Hearing Test»: маньяк ходит за северной стеной спальни, останавливается, уходит; в консоль пишутся появление и исчезновение индикатора с причинами; в F3 — расстояние, moving, LOS, слышимость, причина отказа |
| `TEST_WINDOW_NAV` | погоня в спальне, уход через окно |

## Таблица исправлений
| ID | Статус | Чем подтверждено (автоматически) |
|---|---|---|
| BUG-01 маньяк не заходит в дом | **работает** | T02/T03; 5 seed × 200 с: вход в дом во всех прогонах (первый вход на 4–30 с), обе комнаты осмотрены; занятый шкаф открыт во всех 5 прогонах, пустой — 2–3 раза за прогон (`docs/test_logs/house_patrol_5_seeds.log`) |
| BUG-02 долгое убийство | **работает** | T07: неподвижная жертва — ранение 0.78 с, повал 2.13 с, смерть 4.67 с, 0 промахов; убегающая по открытому полю — 11.2 с (`docs/test_logs/combat.log`); T08 — удар не проходит сквозь стену и в шкаф |
| BUG-03 выход по пересечению края | **работает** | T09 пробег — нет победы; T10 удержание 5 с — победа; T11 отпускание / удар на 4-й секунде — прогресс 0 |
| BUG-04 камни одноразовые | **работает** | T12: один камень 10 бросков подряд, без дублей и потерь; удар о край карты — камень остаётся в карте и подбирается |
| BUG-05 шаги не проверить | **работает** | T13/T14; лог `TEST_FOOTSTEPS` (`docs/test_logs/hearing_test.log`): индикатор появляется при движении за стеной в радиусе 3 gu, гаснет через ≤ 0.75 с после остановки или ухода, не появляется при видимом источнике |
| LEVEL-01 окно | **работает** | T15: перелезание без телепорта и застревания; маньяк выходит наружу окном или через дверь; в soak маньяк реально пользуется окном |
| LEVEL-02 предметы | **работает** (кроме укрытия под кроватью) | T16: ящик сдвигается, навигация перестраивается, звук; двери меняют LOS и проходимость; бутылка бьётся громче камня; радио отвлекает, маньяк его выключает |
| ART-01 примитивная графика | **работает** (уровень прототипа) | 4 скриншота до/после в одном масштабе — `docs/screenshots/compare_*.png`; таблица 12.2 закрыта по всем строкам, см. ниже |

## Отчёт T01–T20
Автоматические проверки — `tests/` (48/48 PASS на Godot 4.7.2, лог `docs/test_logs/tests.log`).
**Ручной плейтест с клавиатурой и мышью мной не проводился**: в моём окружении нет экрана и ввода. Ввод в тестах подаётся программно (`SurvivorController.scripted_input`), «живые» сессии заменены ботом (`tools/soak_test.gd`).

| Тест | Статус | Проверка |
|---|---|---|
| T01 | PASS | `test_main_scene::test_prepare_timer_and_spawn` — маньяка нет 30 с, при появлении `has_last_seen=false` |
| T02 | PASS | `test_house_and_combat::test_t02_t04…` |
| T03 | PASS | `…::test_t03…` — пустой шкаф проверяется, вероятность при занятом и пустом шкафу одинакова |
| T04 | PASS | `…::test_t02_t04…` — дверь открыта действием маньяка, макс. шаг за кадр ≤ скорость (нет телепорта) |
| T05 | PASS | `test_killer_perception::test_seen_then_behind_wall…`, `test_acceptance::test_tree_and_stone_decoy` |
| T06 | PASS | там же — last seen не двигается по скрытому движению |
| T07 | PASS | `test_house_and_combat::test_t07…` |
| T08 | PASS | `…::test_t08…` |
| T09 | PASS | `test_main_scene::test_t09…` |
| T10 | PASS | `test_exit_and_items::test_t10…` |
| T11 | PASS | `…::test_t11_release…`, `…::test_t11_hit…` |
| T12 | PASS | `…::test_t12…` |
| T13 | PASS | `test_level_interactions::test_t13_t14…`, `test_acceptance::test_footsteps_behind_wall…` |
| T14 | PASS | `test_level_interactions::test_t13_t14…` (остановка, далеко, видим) |
| T15 | PASS | `…::test_t15…` |
| T16 | PASS | `…::test_t16_push_crate…`, `…::test_t16_doors…` |
| T17 | PASS | `test_routes::test_t17…`, `test_acceptance::test_explored_area…`, `…::test_door_change_unseen…` |
| T18 | визуально | 4 скриншота запущенной игры (Xvfb + программный OpenGL) — `docs/screenshots/after_*.png` |
| T19 | PASS | `test_level_interactions::test_t19…` |
| T20 | PASS | `test_routes::test_t20…` — 3 разные траектории дом → выход и маршруты по дому, сараю, лесу без застреваний |

Soak 10 минут (бот): 13–17 матчей, все состояния FSM, двери/окно/шкаф, ошибок скриптов нет.

## Скриншоты (запущенная игра)
| | |
|---|---|
| `docs/screenshots/after_1_forest_clearing.png` | лес и поляна, деревья, грунт, тропа, оба персонажа |
| `docs/screenshots/after_2_house_interior.png` | дом: двери, окно, шкаф, кровать, стол, стулья, радио, ковёр |
| `docs/screenshots/after_3_view_and_memory.png` | текущий обзор и затемнённая память карты |
| `docs/screenshots/after_4_exit_progress_chase.png` | открытие выхода с прогрессом, маньяк рядом |
| `docs/screenshots/compare_*.png` | до/после в одинаковом масштабе |

Art pass (12.2): почва — трава/мох, тропы, поляна, дощатый пол двух тонов; лес — 2 хвойные кроны + 1 лиственная, стволы с корнями, кусты, детали (папоротник, камни, пни, ветки), кромка леса за границей; кроны прозрачнеют над игроком; дом — бревенчатые стены с тенями, пол, мебель с силуэтами, ковёр, лампа; персонажи — разные силуэты, поворот по взгляду, кадры покоя и ходьбы, замах, ранение, повал; предметы читаемы, подсветка доступного действия; свет — холодный ночной тон, тёплые пятна лампы и фонаря у ворот, мягкий край LOS; HUD — панели здоровья, выносливости, слотов, подсказки, прогресса выхода, индикатор шагов, экран итогов; аудио — шаги, дверь, камень, бутылка, окно, атака, шкаф, ворота, радио, ночной фон. Список ассетов и лицензия — `ASSETS.md`.

## Архитектура (кратко)
`PhysicalWorld → VisionSensor/HearingSensor → Observation.* → AIMemory → KillerBrain → KillerMotor`.
`KillerBrain` не ссылается на выжившего и не читает `occupied` шкафа: занятость видна только в момент фактического открытия (`locker.killer_open`). Из мира ИИ знает статику: `AreaOfInterest` (дом, сарай, поляна, кусты, пути к выходу), места шкафов. Состояния ИИ: PATROL, TRAVEL_TO_POI, SWEEP_INTERIOR, CHECK_HIDING_SPOT, INVESTIGATE_SOUND, CHASE, GO_TO_LAST_SEEN, LOCAL_SEARCH, ATTACK, FINISH, RETURN_TO_PATROL; открытие двери и перелезание окна — действия мотора (в F3 видны как OPEN_DOOR / VAULT_WINDOW).
Все числа — в `scripts/config/game_params.gd` (Приложение А ТЗ).

| Система ТЗ | Файл |
|---|---|
| GameSession | `scripts/core/game_session.gd` |
| CharacterController | `scripts/characters/survivor_controller.gd`, `killer_motor.gd` |
| HealthCombat | `scripts/characters/health_component.gd`, `killer_motor.gd::try_hit/perform_finish`, `killer_brain.gd` |
| VisionSystem / ExplorationMemory | `scripts/perception/vision_sensor.gd`, `fog_renderer.gd`, `player_perception_view.gd`, `scripts/memory/exploration_memory.gd` |
| SoundEventBus | `scripts/core/sound_event_bus.gd`, `scripts/perception/hearing_sensor.gd` |
| AIMemory / KillerAI | `scripts/memory/ai_memory.gd`, `scripts/ai/killer_brain.gd`, `area_of_interest.gd` |
| InteractionSystem / Inventory / WorldItem | `scripts/interactions/*`, `scripts/world/{door,window,locker,furniture,radio}.gd` |
| ExitInteraction | `scripts/world/exit_gate.gd` |
| DebugOverlay / пресеты | `scripts/ui/debug_overlay.gd`, `scripts/core/debug_presets.gd` |
| Графика / звук | `scripts/world/art.gd`, `scripts/core/audio_director.gd`, `tools/gen_assets.py` |

## Ограничения (честно)
- **Ручной плейтест не проведён мной**; нужен ваш прогон (сценарий ниже).
- **FPS на реальной видеокарте не измерялся.** Измерено на 4 vCPU Xeon 2.8 GHz без GPU: логика ≈ 0.74 мс/кадр (headless); программный рендер llvmpipe — ~10 FPS при 1920×1080 и ~21 FPS при 1152×648. Это не показатель для desktop с GPU.
- Укрытия под кроватью нет (кровать — препятствие/укрытие от прохода).
- Звуки синтезированы процедурно — функциональные, но простые.
- Слух по умолчанию не ослабляется стенами (`footsteps_wall_attenuation = 1.0`, настраивается).
- Бег по открытому полю без укрытий: маньяк догоняет после окончания выносливости (≈ 7–11 с) — уходить нужно через препятствия и окно.
- В тестовой сцене выход открыт с начала (`exit_unlocked_in_test_scene`), флаг `exit_requires_sunrise` оставлен для будущего режима.
- Ветка: `claude/youthful-carson-o6jall` вместо `feature/prototype-0.2-search-escape` — окружение разрешает пушить только в неё.
- При выходе из тестового раннера Godot печатает предупреждения об утечках ObjectDB (тестовые узлы на момент завершения движка); на игру не влияет.

## Ручная проверка (≈ 5 минут)
1. F2 → `TEST_HOUSE_PATROL`: сидите в шкафу; в консоли — `entered house`, `swept …`, `opened hiding spot … someone inside`.
2. F2 → `TEST_FOOTSTEPS`: стойте в спальне; внизу экрана появляется и гаснет пульс шагов; F3 показывает причины.
3. Обычная игра: подберите камень, покажитесь маньяку, уйдите за ствол, бросьте камень в сторону → маньяк уходит проверять (INVESTIGATE_SOUND в F3).
4. Спрячьтесь в шкаф или уйдите через окно (удерживать E).
5. У ворот на правом краю удерживайте E 5 секунд → ESCAPED. Отпустите на середине — прогресс сбросится.

## Следующие задачи
Ручной плейтест и баланс (вероятности проверки шкафа, интервал посещения дома, скорости); полный матч 12 минут с рассветом и полицией; укрытие под кроватью; анимации на 4 направления; живые звуки и микширование; несколько жертв.
