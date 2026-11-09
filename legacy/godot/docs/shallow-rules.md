# Progressive fishing journey rules

## Current flow and input

`setup(seed)` resets a run and auto-casts with initial velocity `(235,-330) × 0.95`. One press stops horizontal motion and sets downward velocity to at least 900 pt/s. Release/flick never hook, cancel or fail. A second distinct press near ring alignment launches the physically contacted fish or debris to the basket. No third counter input is used. Basket flight is 0.9 seconds, followed by a 0.18-second automatic recast. Held/repeated presses cannot trigger another state or queue a future dive.

Empty diving, early ring input, late input and ring timeout end the run. `game_over` freezes simulation, fish and score. After releasing the previous touch, one fresh press starts a new seeded run; it cannot also dive. `ready` and `restarted` reset renderer effects. User tuning survives restart; score, flags, population and journey reset.

## Journey and screen layout

Public `row_positions` is the authoritative screen-native row layout; the old `ROW_Y` constant is legacy only. `journey_thresholds=[0,3,7,12,18,25]` uses actual fish catches to unlock 2→7 rows. Initial fish population is nine slow small fish across two rows. Existing fish never change species or teleport when a new row unlocks.

Target layouts:
- 2 rows: 340,397; floor425.
- 3 rows: 334,390,446; floor474.
- 4 rows: 324,378,432,486; floor514.
- 5 rows: 318,361,404,447,490; floor518.
- 6 rows: 315,353,391,429,467,505; floor539.
- 7 rows: 313,345,377,409,441,473,505; floor539.

Existing row centers move toward targets at 12 pt/s; floor moves at 24 pt/s. Layout and debris depth are locked during `diving` and `bite_window`. School movement remains physically represented, using actual previous/current positions for collision. New rows enter from offscreen edges. `depth_meters` and `boat_distance` provide narrative travel without putting deeper fish below the phone UI.

The upper two rows start with target populations 5/4, transition to 4/4, then 3/3 at five rows. Each deeper row has two fish. Excess fish leave through normal capture/offscreen movement rather than disappearing. Entry gaps are 75 points initially, 115 for mature upper rows, and 170 for deep rows. Fish can overlap occasionally; the engine never moves blockers away to guarantee a catch.

## Twenty actual species

`fish_species_id`, each school fish's `species_id`, and event `species_id` are authoritative. `fish_kind` 0–7 remains only a legacy visual archetype, not species identity or authoritative difficulty. `fish_tier` and each fish’s `tier` come from the shared geometry module. In particular, the old trophy-bass kind is not a duplicate species ID. `ACTIVE_SPECIES` matches Catalog.ACTIVE_IDS exactly.

Row entrant pools rotate deterministically:
- Row0: bluegill, pumpkinseed, green sunfish, redear sunfish, longear sunfish.
- Row1: initially the same small-fish pool, then rock bass, black crappie, white crappie, yellow perch, white bass.
- Row2: brook trout, rainbow trout, smallmouth bass.
- Row3: largemouth bass, spotted bass, walleye.
- Row4: channel catfish, northern pike.
- Row5: striped bass, blue catfish.
- Row6: northern pike, blue catfish, striped bass.

Only new entrants use the pool. Small fish speed is 17–27 pt/s, medium 28–42, heavy 44–64, trophy archetypes 65–88. Largemouth/smallmouth/spotted/striped bass give a 0.2-second `turn_warning` before regular 1.8-second reversals, beginning only after entering the screen. Walleye, northern pike, blue catfish and rainbow trout use slow sinusoidal vertical movement. Amplitude reduces with row spacing, reaching at most5 points at seven rows. A dive locks motion parameters until contact/floor, preventing last-second untelegraphed evasions.

## Collision, rings and events

`fish_school` dictionaries contain id, kind, species_id, tier, row, pos, previous_pos, velocity, radius, weight, multiplier, motion_clock, turn_left and turn_warning. One relative-motion swept ellipse test checks all fish and debris and chooses earliest contact. Surface splash does not spawn fish or award points. A contacted fish preserves its species/weight and is removed from the school; replacement enters from an edge.

Public ring fields: duration, elapsed, progress, target_radius, window and timing_grade. Tier durations are [.95,.82,.68,.55] seconds. Successful symmetric half-windows are [.18,.15,.12,.10] seconds scaled from `hook_window_ms`, whose default180 means the actual small-fish ±180ms. Renderer highlighting must use `abs(elapsed-duration)<=window`. `ring_aligned` fires once at visual alignment when reached. Fish contact and successful hook each add one combo.

Main events: cast, slam, splash, fish_contact/item_contact, bite, ring_aligned, ring_judgement, hookset, breach, basket/junk_basket, recast, fail, ready and restarted. Common fields include type/time/state/pos/combo/fever/category/species_id. `best_run_combo` and `final_reason` support results UI.

## Sparse bottom salvage

`bottom_items` contains snail and weed dictionaries with negative id, category/kind, pos, previous_pos, velocity and radius. Initial x is157/285, drift +4/−5pt/s; center is floor−9. Radii are(12,9)/(10,13). Objects settle visibly when the floor deepens, but depth is locked during dives/rings. Caught/offscreen debris reenters at an edge.

`catch_category` is fish/snail/weed. Salvage uses the same second-tap ring. `junk_basket` gives zero points and never increments fish catches or species statistics; only real fish emit `basket`. Current configurable salvage_combo_policy preserves existing combo without adding any. Missing both fish and debris still ends the run.

## Determinism and validation

Version4 snapshots include journey, species pools, RNG, all objects, ring state and pending events. These are in-memory Variant dictionaries with Vector2 values, not JSON serialization. `predict_slam_contact()` clones identical rules and returns id/category/species_id/kind/pos/seconds or empty. It is QA-only, read-only, and never steers live collision. Fish-only demos must filter category=fish.

Headless suites:
- tests/arcade/test_shallow_rules.gd:139 checks, including swept first-contact, salvage accounting and updated mature-layout reachability.
- tests/arcade/test_arcade_integration.gd:38 checks using actual viewport input dispatch, pause/debug, intro, timing units and retry.
- tests/arcade/test_journey_rules.gd: progressive unlocks, all20 spawn pools, layout locks and consecutive normal generated gameplay. `-- --fast-scan` chooses the earliest feasible input instead of prioritizing new species.

Final-art validation: the species-seeking run caught250 actual fish continuously, all20 species, with zero casts lacking a real contact opportunity (402 assertions). The earliest-feasible-input run independently caught250 fish without an unavoidable empty cast (408 assertions); that strategy naturally collected18 species. A separate26-check geometry suite verifies all20 ellipse hit/miss boundaries and deepest-row first-contact opportunities at each2–7-row stage. No test injects fish near the hook or bypasses collision. These are deterministic feasibility scans, not a claim that every human input succeeds or all possible seeds are guaranteed fair.

Final geometry is now canonical in scripts/arcade/fish_geometry.gd, generated from assets/fish20/manifest.json v2. Rules use radius_for(species_id): actual body ellipse uniformly scaled to recommended visible width, plus four points of forgiving padding. Rendering uses the same anchor and scale. Speed, weight, score multiplier and ring difficulty use tier_for(species_id), not legacy kind. All20 IDs and collider hit/miss boundaries are checked; the deepest row is reachable at all2–7 stages under this geometry. Physical iPhone latency/haptics still require device validation.

## 0.6.1 difficulty follow-up

Later water rows no longer imply a permanently filled fish lane. Population caps and rotating natural edge entry progressively reduce visible density while preserving the initial nine slow small fish. Only canonical tier-3 fish contacted in rows4+ accelerate their shrinking ring with banked catches (0.55→0.40seconds); their default ±100ms window is unchanged. See difficulty-curve.md for the final curve, rejected candidates and actual sampled opportunities.
