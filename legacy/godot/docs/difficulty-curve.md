# Late-game difficulty curve

Final rules: `scripts/arcade/arcade_rules.gd`.
SHA-256: `6c979005993bac832670a8a5730201e3d922cc22b281227595ab7fec3c4086d3`.
Original v0.6 backup: `Legacy/v0.6-before-difficulty/arcade_rules.gd.txt`.

## Design

Difficulty now comes from genuinely less populated late water and faster rings only for the highest-value deep fish. It does not come from faster small fish, smaller collision bodies, hidden aiming assistance, sudden fish removal, or longer automatic-recast waits.

The opening is unchanged: nine slow small fish in two rows, the same two visible salvage objects, the same automatic cast and two-click controls. All initial simulation state and all first-cast input outcomes match the original for the tested seeds. Banked fish count drives progress; combo, salvage and elapsed time do not advance difficulty.

### Population targets

Counts include fish approaching from offscreen; they are not a promise that every slot is currently visible. Row limits and the global cap are admission limits. A cap decrease does not remove current fish. Surplus fish retire only when caught or when they reach the usual offscreen exit.

| Banked fish | Water rows | Upper two row limits | Deeper row limits | Effective total limit |
|---|---:|---|---|---:|
| 0–2 | 2 | 5 / 4 | — | 9 |
| 3–6 | 3 | 4 / 4 | 2 | 10 |
| 7–11 | 4 | 4 / 3 | 2 / 2 | 11 |
| 12–17 | 5 | 3 / 3 | 2 / 2 / 1 | 11 |
| 18–24 | 6 | 3 / 2 | 2 / 1 / 1 / 1 | 9 |
| 25–31 | 7 | 2 / 1 | At most 1 per deep row | 8 |
| 32–44 | 7 | 2 / 1 | At most 1 per deep row | 7 |
| 45 onward | 7 | 2 / 1 | At most 1 per deep row | 6 |

At mature progress, the shallow rows reserve two small-fish slots and one medium-fish slot. The three remaining slots rotate among five deeper rows. Empty rows are intentional. After a normal capture or edge exit, refill first respects the shallow limits, then chooses an available deep row with the fewest previous entrants. Its existing species pool continues rotating, so the reduced population does not remove any of the twenty species from the game.

All new fish start at x = −38 or 398, or farther behind an existing entrant. Neither the aimed hook position nor a predicted catch is consulted. Existing row movement, motion warnings, dive-time trajectory locks, and swept first-contact collision are unchanged.

Entry separation remains 75 points in the opening. After the opening it interpolates from 115 to 155 points in the top rows and from 170 to 210 points in deep rows over catches 12–45. Separation matters only when multiple fish occupy the same row. The global population cap, not deep-row separation, creates the mature reduction.

### Ring timings

Only canonical tier 3 fish from row index 4 or deeper accelerate. In the real pools these are northern pike, striped bass and blue catfish, the ×8 class. Weight within a tier does not secretly change timing.

`difficulty_progress() = clamp((catches - 12) / 33, 0, 1)`.
Elite duration is `0.55 - 0.15 × difficulty_progress()` seconds, with a hard 0.40-second floor.

| Banked fish | Elite ring duration | Default accepted offset |
|---:|---:|---:|
| ≤12 | 550 ms | ±100 ms |
| 18 | 523 ms | ±100 ms |
| 25 | 491 ms | ±100 ms |
| 32 | 459 ms | ±100 ms |
| ≥45 | 400 ms | ±100 ms |

Small, medium and ordinary heavy fish remain 950/820/680 ms with ±180/150/120 ms windows. Salvage remains 950 ms and its existing forgiving window. F1 `hook_window_ms` tuning retains its previous scaling. No shrinking of the elite success window was necessary.

## Measurement method

`tests/arcade/test_difficulty_curve.gd` compares against the original backup, loading it as an isolated GDScript. It scans the actual cast trajectory at 60 Hz. Each candidate click is passed through the real cloned simulation, moving fish and debris, and the same earliest swept-ellipse contact. This is not a static horizontal-overlap estimate, and it does not count a fish hidden behind another fish as reachable.

The existing `target_x` RNG field is event metadata; it does not drive cast velocity. Both versions still use `(235, −330) × 0.95`. Tests therefore scan the actual input-time trajectory rather than inventing trajectories from random `target_x` values.

For the stage comparison, 32 seeds (`20261109 + i × 7919`) are sampled at four lake phases each. Each lake is advanced without catching for 32 seconds plus a small seed offset; subsequent phases are 2.73 seconds apart. This intentionally separates population/layout effects from the player's choice of catches. Every stage has 128 casts and 9,088 candidate input frames.

“Empty click fraction” means the fraction of those sampled first-click times that hit neither a fish nor salvage. It is not a predicted human failure rate. Visible fish counts use body centers inside x = 0…360. Offscreen-to-onscreen predicted contacts are counted separately, not used as evidence of an observable fish opportunity. Same-fish timing windows require consecutive sampled inputs that all first-contact the same currently visible fish; their conservative span is `(frame_count − 1) / 60`.

### Stage comparison

| Fish count | Old mean visible | Final mean visible | Old empty clicks | Final empty clicks | Minimum longest same-visible-fish window |
|---:|---:|---:|---:|---:|---:|
| 0, warmed two-row lake | 6.20 | 6.20 | 38.2% | 38.2% | 116.7 ms |
| 3 | 7.35 | 7.35 | 32.3% | 32.3% | 116.7 ms |
| 7 | 9.03 | 8.53 | 24.7% | 26.7% | 150.0 ms |
| 12 | 9.23 | 8.69 | 22.1% | 24.8% | 150.0 ms |
| 18 | 11.02 | 7.28 | 16.5% | 29.5% | 150.0 ms |
| 25 | 12.77 | 6.70 | 13.8% | 33.8% | 150.0 ms |
| 32 | 12.77 | 5.82 | 13.8% | 40.1% | 150.0 ms |
| 45 | 12.77 | 4.85 | 13.8% | 44.2% | 133.3 ms |
| 60 | 12.77 | 4.85 | 13.8% | 44.2% | 133.3 ms |

The first row is a warmed lake, not the player's actual first cast. A separate 32-seed first-cast comparison found 16.6% empty candidate clicks, unchanged in both versions, no hidden-target frames, and exact matching outcomes for all 2,272 candidate inputs.

Final mature water therefore has about 62% fewer visible fish than the old mature water, with empty-input opportunities increasing from 13.8% to 44.2%. Difficulty stops increasing at 45 catches instead of becoming arbitrarily sparse.

All final stage samples retain a currently visible fish opportunity. At 45/60 catches, 259 of the 9,088 candidate frames first-contact the deepest row, so the lowest row remains genuinely reachable rather than merely decorative. All stages also retain shallow small-fish first-contact opportunities.

## Continuous-play checks and limits

The original earliest-contact run of 32 seeds reached 75 actual fish per seed. That strategy initially allowed any physical contact, so an additional stricter version selects only fish/debris already visible when the first click occurs. It is run separately as `--journey-only` and is the preferred regression for future work. All 32 visible-target journeys reached 75 fish, collectively encountered all twenty species, and passed 195 checks with zero failures.

The independent audit (`tests/arcade/test_difficulty_independent.gd`) runs deep-seeking, late-click and deterministic-random choices against three different seeds, to 100 fish each. It selects currently visible first-contact targets and favors continuous windows of at least 100 ms. The final six-fish floor completed all nine runs: 900 fish plus 13 salvage casts, no cast without a visible fish opportunity, and no disagreement between prediction and actual contact.

Measured empty-click fractions during these actual continuous journeys rose from about 30.2% at catches 0–11 to 43.3% at catches 45–59 and 60+. These are strategy-dependent histories and are not interchangeable with the warmed-stage table.

Two of the 913 continuous casts had a longest same-visible-target interval under 100 ms: 66.7 ms at seed 103013/deep/catch 93, and 83.3 ms at seed 118021/late/catch 99. The other 911 casts had at least 100 ms. This interval measures the viable first-click timing range, not how long the fish was visible beforehand. These difficult but observable opportunities remain a stress-test limitation; the result is not a guarantee of uniformly generous timing.

These deterministic samples are regression evidence, not a proof for every possible seed, every strategy or human reaction time. Real-device touch latency and human playtesting remain separate validation.

### Rejected variants

1. Reducing per-row counts while keeping one fish in every deep row left about 7.66 visible mature fish and 27.8% empty clicks. It did not provide a strong enough continuing late-game increase, so it was replaced by the global cap and rotating deep rows.
2. A five-fish cap after 60 catches was tested and rejected. Independent seed 118021 with the late-click strategy reached catch 69 with no currently visible first-contact opportunity; only a later-entering offscreen fish could be hit. Other casts had very narrow 33–67 ms windows. The final six-fish floor eliminates that specific no-visible-opportunity reproduction and does not use an invisible fallback or delay the next cast.

## Reproduction and evidence

Use `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script tests/arcade/test_difficulty_curve.gd` from the project directory. Flags after `--`:

- `--quick`: four seeds and two phases per stage, plus continuous journeys.
- `--late-only`: full 32-seed scan at catches 45/60, plus continuous journeys.
- `--opening-only`: exact original-versus-final first-cast comparison.
- `--journey-only`: 32 visible-target continuous journeys to 75 fish.

Evidence files under `runtime/`:
- `difficulty-final.stdout.log`: full 32-seed stage data for the cap-5 candidate. Stages through 45 match the final rules; its failing 60-catch data are explicitly superseded.
- `difficulty-cap6-final.stdout.log`: final 45/60 scan and original continuous regression, 203 checks, zero failures.
- `difficulty-opening-final.stdout.log`: 225 checks, zero failures, actual first-cast comparison.
- `difficulty-visible-journey-final.stdout.log`: stricter visible-target continuous regression, 195 checks, zero failures.
- `difficulty-independent-cap6-final.stdout.log`: final nine-strategy/seed audit, including the two narrow intervals.
- `test_shallow_rules-cap6.stdout.log`, `test_geometry_access-cap6.stdout.log`, `test_arcade_integration-cap6.stdout.log`, `test_journey_rules-cap6.stdout.log`: final rules/geometry/input/250-fish journey regressions, respectively 139/26/38/429 checks with zero failures. The 250-fish species-seeking journey caught all twenty species and accessed the deepest row at every 2–7-row stage.

No long-term save schema, fish art, collider geometry, score rules, salvage accounting, cast trajectory or recast delay changed. Snapshot schema remains version 4 because no state fields were added. The current running GUI was not manipulated during the rules implementation or headless tests.

## Integrated rendered acceptance

The frozen main/rules source was recorded in the actual Godot renderer for 60 consecutive catches, then intentional empty failure and immediate retry. Full evidence: captures/difficulty/sixty-catches.mp4 (157.82seconds), run.json and milestone screenshots. The 34.8second difficulty-highlights.mp4 is an edited early/mid/late excerpt from that same real scripted run, not an old/new split or human playtest. Opening field, mature spacing and warm fast-trophy ring/copy were visually inspected. Music status at exit confirms both supplied tracks played with one actual changeover. Fixed60FPS movie mode is not an iPhone/iPad performance claim.

The separately exported exports/macos/OneLastCast-v0.6.1.app passed actual PCK/source hash audit and strict local signature verification; the prior v0.6 app was verified unchanged. Current source main hash bbd5857a9173e567b2cea1a2b56ab14134f48372144378df1d5682957950105a and rules hash 6c979005993bac832670a8a5730201e3d922cc22b281227595ab7fec3c4086d3 match the package.
