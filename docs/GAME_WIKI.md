# TIDEBREAK World Tour - game wiki

> A Godot 4.7 "World Tour" career screen for a surf game that does not exist yet: pick one of seven
> stops on a map (PIPELINE to TIDEBREAK FINALS), press START EVENT, and choose your own result from a
> dialog titled EVENT TEST HARNESS (BRONZE / SILVER / GOLD / WIPEOUT). A full "season" (all seven
> stops) takes about 30 clicks and under a minute; there is no surf gameplay in this repository.

| | |
| --- | --- |
| Status | playable (as a UI demo); the surf heat it is built around is not implemented |
| Play | https://calebhomwe.github.io/TidebreakWorldTour/ or `godot --path .` (Godot 4.7) |
| Platforms | desktop mouse: verified by harness; keyboard: ESC verified (`_unhandled_input`, `world_tour_screen.gd:57-60`), arrow/Enter focus navigation not verified; touch: verified by harness `mobile` mode (the whole UI is a 390x219 strip, see Gaps); gamepad: not verified (footer promises "D-PAD / MOUSE SELECT  A / ENTER CONFIRM  B / ESC BACK", `world_tour_screen.gd:426`) |
| Engine | Godot 4.7, GL Compatibility renderer, 1600x900 `canvas_items` stretch (`project.godot:13-21`); web export is single-threaded (`export_presets.cfg:22`) |
| Save | one JSON file `user://tidebreak_world_tour.json` (`tour_save.gd:4`) holding `version, xp, tour_points, credits, completed, medals, best_scores, current_stop` (`world_tour_screen.gd:111-121`); written on every refresh, selection and result (`:518`, `:664`, `:709`, `:746`). On the web build `user://` lives in IndexedDB (IDBFS). Unparseable JSON or wrong types fall back to defaults / are coerced (`tour_save.gd:21-34`, `:56-81`); `version` is stored but never used for migration. With IndexedDB blocked the game runs on an in-memory FS and progress does not survive a reload (harness `storage-blocked`). |
| Harness | `node tools/harness/play.mjs --mode <default\|mobile\|storm\|resize\|blur\|storage-blocked\|long>` plays whole seasons from the exported web build and asserts no page errors, no NaN/out-of-range values, legal phase transitions, no stuck state, progression per episode and a working restart. `godot --headless --path . -s tools/test_world_tour.gd` checks the rules (75 checks). CI: `.github/workflows/godot-web.yml`, jobs `web` (logic tests) and `harness`. |

## How to play

| Action | Desktop | Touch | Gamepad |
| --- | --- | --- | --- |
| Select a stop | click its button on the TourMap (`tour_map.gd:136-144`) or its card in the carousel (`world_tour_screen.gd:307-321`); locked stops are disabled buttons (`:544`, `tour_map.gd:158`) | tap the same button (Godot emulates mouse from touch) | focus moves between buttons (`FOCUS_ALL`, `tour_map.gd:140`); initial focus is the selected map stop (`world_tour_screen.gd:54`, `:911-912`); not verified |
| Start the event | click START EVENT / REPLAY EVENT (`:380-381`) | tap | Enter / A on the focused button: not verified |
| Choose the result | click BRONZE 65% / SILVER 85% / GOLD 110% / WIPEOUT 40% (`:482-500`); CANCEL (`:502-503`) | tap | first enabled button is focused when the dialog opens (`:680-682`) |
| Close the dialog | ESC (`ui_cancel`, `:57-60`) or CANCEL | CANCEL | B: not verified |
| Wipe progress | RESET DEMO SAVE (`:263-264`, `:819-824`) | tap | - |

The header nav "HOME SURFER GEAR WORLD TOUR SPONSORS PROFILE" is a single `Label`, not buttons
(`:195`); clicking it does nothing.

Time from page load to the first meaningful action (UI drawn, START EVENT clickable) on the web
build: 15.8 s, 18.0 s and 21.2 s in three harness runs on this box (`report.bootMs`; SwiftShader,
no GPU, load average 20-31 on 4 CPUs). Not measured on a GPU browser.

## Core loop

Every ~10 seconds the player: clicks the next unlocked stop on the TourMap (teal ring = open, gold
ring = completed, grey = locked, `tour_map.gd:94-106`), reads its EVENT TARGET ("SCORE 22,000+") and
REWARDS ("+1,200 XP  +1,600 TOUR PTS", `world_tour_screen.gd:578-582`), presses START EVENT, and in
the EVENT TEST HARNESS dialog picks GOLD. A toast then reports "Score 24,200 - GOLD / +1,200 XP
+1,600 Tour Points / Unlocked: TRESTLES" (`:760-776`), SEASON PROGRESS moves by 14%, YOUR RANK drops
from 250TH towards 63RD, and the next stop's ring turns teal.

Per-season arc: PIPELINE (target 22,000) through TRESTLES, SNAPPER ROCKS, JEFFREYS BAY, TEAHUPO'O,
CLOUD 9 to TIDEBREAK FINALS (target 78,000) (`:63-108`). Because the dialog scales the chosen ratio
by the stop's target (`_simulate_result`, `:751-757`), every stop plays identically: GOLD is always
110% of target. The arc ends at SEASON PROGRESS 100% with the same toast as any other stop; nothing
else happens. The selection does not advance after a result (`_refresh_all` keeps `current_stop`,
`:511`), so the player must pick the next stop by hand each time.

## Structure (screens and states)

There is one scene (`world_tour_demo.tscn` -> `WorldTourScreen`, `world_tour_screen.gd:1-2`) and no
phase variable; the only mode flag is `result_overlay.visible` (`:674` opens, `:814` closes).

```
tour screen (idle) --START EVENT--> result dialog --BRONZE/SILVER/GOLD--> toast + refreshed screen
                                     |            --WIPEOUT------------> toast "Target missed", no change
                                     '--ESC / CANCEL (fade 0.14 s, `:807-816`)--> tour screen
tour screen --RESET DEMO SAVE--> delete save, default state, toast "World Tour progress reset." (`:819-824`)
```

Harness phases map onto this as: `menu` = 0/7 stops and no dialog, `playing` = dialog open or 1-6
stops done, `over` = 7/7 stops and no dialog. There is no pause (nothing to pause), no season end
screen, no title screen. Dead ends: none found; the dialog is modal (`MOUSE_FILTER_STOP`, `:437`) so
RESET and the map are unreachable while it is open, and ESC always closes it. The season has no end
state: completing TIDEBREAK FINALS returns `unlocked_stop == ""` (`:741-744`) and the screen just
sits at 100%.

## Progression

- Within a run: nothing ramps. A "run" is one dialog click. Targets rise per stop (22,000 to 78,000,
  `:66-104`) and rewards rise (1,200 to 4,000 XP, 1,600 to 5,500 points) but the demo result is a
  fixed ratio of the target, so difficulty is constant.
- Across runs: `xp`, `tour_points`, `credits`, `completed`, `medals`, `best_scores` and the selected
  stop persist in the JSON save. Sponsor tiers TIDEBREAK CORE (0) / RISING (6,000) / PRO (14,000) /
  ELITE (24,000 XP) (`:635-640`); YOUR RANK = `clamp(250 - floor(points / 110), 1, 250)` (`:879-881`).
  Medals only upgrade, never downgrade (`:718-730`), and a replay below the stored medal pays nothing
  (`:732-739`). Maximum from an all-gold season: 15,750 XP, 20,600 points, rank 63RD, tier
  TIDEBREAK PRO (`tools/test_world_tour.gd`, `_test_full_season`). ELITE and the top-3 leaderboard
  names (58,200 / 52,100 / 48,750 points, `:599-601`) are unreachable.
- Harness evidence: `completed` rose 0 -> 7 in every default episode (see Stability); the sponsor
  bar was observed resetting at 4/7 and 7/7 stops as the tier changed (CORE -> RISING -> PRO).

## Win / lose / fail

| Condition | Rule | Feedback | Back into play |
| --- | --- | --- | --- |
| Gold / silver / bronze | score >= 100% / 80% / 60% of target (`_medal_for_score`, `:859-867`) | toast with score, medal, XP, points, unlock; card status text becomes the medal; ring turns gold | select next stop, START EVENT |
| Wipeout | score < 60% | toast "Score 8,800 - NONE / Target missed. Replay the heat." (`:764-765`); best score still recorded (`:703-706`) | START EVENT again on the same stop |
| Season complete | all 7 in `completed` | SEASON PROGRESS 100%, nothing else | REPLAY EVENT on any stop, or RESET DEMO SAVE |

There is no losing state and no way to lose anything already earned.

## Scoring and economy

- Demo score = `roundi(target_score * ratio)` with ratios 0.65 / 0.85 / 1.10 / 0.40 (`:484`, `:489`,
  `:494`, `:499`, `:756`).
- Medal multiplier bronze 0.70, silver 0.88, gold 1.00 (`:712-716`); `xp_earned = roundi(xp_reward *
  m)`, `points_earned = roundi(points_reward * m)` (`:733-734`), paid on first completion or medal
  upgrade only (`:732`). Upgrades pay the full new multiplier on top of the old award (bronze then
  silver at PIPELINE = 840 + 1,056 XP, `tools/test_world_tour.gd`, `_test_upgrade_and_replay`).
- Credits: `credits += roundi(points_earned * 0.45)` (`:737`), start 2,500. Never displayed and never
  spent; the header's "12,650 / 3,250" are literals (`:208`).
- Sanitising clamps `xp`, `tour_points`, `credits` to >= 0 and coerces types (`tour_save.gd:57-79`);
  `_medal_for_score` guards target 0 with `maxf(1.0, ...)` (`:860`). Nothing can go NaN; a hand-edited
  `completed` with duplicates would print >100% progress (`:625-628`, not deduplicated) - not
  reachable from the UI.
- `complete_event()` does not check that the stop is unlocked (`:685-690`); the real game must gate it.

## Juice inventory

| Event | Visual FX | SFX | Music/ducking | Camera/shake | UI/text pop | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| select a stop | ✔ ring + card border recolour, white selection ring | ✘ | ✘ | ✘ | ✔ detail panel text swap | `tour_map.gd:105-106`, `world_tour_screen.gd:556-559` |
| START EVENT | ✔ overlay fades in 0.18 s | ✘ | ✘ | ✘ | ✘ | `:676-678` |
| result (medal) | ✔ progress bar fill, ring/route turn gold | ✘ | ✘ | ✘ | ✔ toast fade in/hold 2.4 s/out | `:799-804`, `tour_map.gd:87-100` |
| wipeout | ✘ | ✘ | ✘ | ✘ | ✔ toast "Target missed" | `:764-765` |
| unlock next stop | ✔ ring/route turn teal | ✘ | ✘ | ✘ | ✔ "Unlocked: X" line in toast | `tour_map.gd:89-90`, `:771-774` |
| tier / rank change | ✔ sponsor bar refills | ✘ | ✘ | ✘ | ~ label text changes only | `:647-652`, `:620-621` |
| season complete | ✘ | ✘ | ✘ | ✘ | ✘ (same toast as any stop) | `:741-744` |
| button hover / press / focus | ✔ StyleBox swap (teal hover, gold pressed/focus) | ✘ | ✘ | ✘ | ✘ | `:948-952`, `tour_map.gd:180-184` |
| reset | ✘ | ✘ | ✘ | ✘ | ✔ toast | `:824` |

No audio anywhere: `grep -rn "AudioStream\|\.play(\|AudioServer" scripts/ project.godot` returns
nothing. No particles, shake or hit-stop. The only animations are the three `create_tween()` calls
(`:676`, `:800`, `:811`).

## Stability (harness results)

How state is read: the project has no `JavaScriptBridge` hook and prints nothing, so the harness
screenshots the canvas each tick (CDP `Page.captureScreenshot`, decoded in Node) and samples three
regions of the 1600x900 design space mapped through the `canvas_items`/keep stretch: the SEASON
PROGRESS bar's teal fill -> `completed` 0..7, the WORLD TOUR title's brightness -> dialog open
(the overlay's 76% black dimmer), the SPONSOR PROGRESSION bar's gold fill -> `sponsorFrac`
(`tools/harness/play.mjs`, `REGIONS`). Policy: GOLD first in each season, then GOLD 60% / SILVER
15% / BRONZE 13% / WIPEOUT 7% / ESC 5%; outside the dialog, click the next uncompleted stop on the
TourMap then START EVENT. Restart = RESET DEMO SAVE + START EVENT.

All runs below: web export of commit `835c729` (the game is unchanged by this programme's commits)
served locally with COOP/COEP, Playwright 1.56.1 Chromium on SwiftShader (no GPU), 4 CPUs shared with
other agents' harness runs, `uptime` load average 20-47 throughout (quoted per row). The 2-4 fps
figures are SwiftShader + that load, not a defect of the game. An earlier attempt to run three modes
in parallel at load 47 ended with Chromium closing mid-run ("Target page, context or browser has been
closed") in all three; those runs were discarded and every row below is from a sequential re-run.

| Mode | Episodes | Errors | Stuck | End state | Restart ok | fps | Heap | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| default (1 ep, `--secs 100`) | 1 | 0 | no | `over`, completed 0->7 in 77 s | - | 2-3 | not sampled | PASS - console: `TIDEBREAK World Tour [default] PASS / boot 18002 ms, fps 2/2/2/2/2/3/2, errors 0 / ep0: over 77s completed 0->7` (load 31.7) |
| default (2 ep, `--secs 60`, earlier sampler) | 2 | 0 | no | timeout while playing, 0->2 and 0->3 | ok (reload+start) | 2-3 | not sampled | PASS - `boot 21228 ms ... ep1: playing 76s completed 0->3 restart=reload+start` (load 20-25) |
| default, CI step text `--episodes 2 --secs 40` under `bash --noprofile --norc -eo pipefail` | 2 | 0 | no | timeout while playing, 0->3 then 3->4 (the save survived the reload) | ok (reload+start) | 2-3 | not sampled | PASS, exit 0 - `boot 14376 ms, fps 2/2/2/2/3/2/2/2, errors 0` (load 39-43) |
| mobile | - | 0 | - | - | - | 4 (deepcheck) | - | NOT VERIFIED by the play harness: the parallel attempt never saw the UI (boot 156 s at load 47, `unknown phase unreadable`) and the sequential re-run was still on its first step when the time box ended. Deepcheck's mobile pass (390x844, touch, 12 s storm) booted and ran with 0 page errors. |
| storm | 1 | 0 | no | 0->2 before the browser closed | - | 2-3 | 62 MB | NOT VERIFIED: 0 page errors and progression while it ran; cut short by Chromium closing under the parallel load (harness exception, not a game error). |
| resize | - | - | - | - | - | - | - | NOT RUN (time box). |
| blur / focus | 1 | 0 | no | 0->5 in 124 s, then browser closed on the restart reload | FAIL (browser gone) | 2-3 | 22 MB | NOT VERIFIED: 5 stops completed with blur/focus events every 5 s and 0 page errors; the restart failed because Chromium had closed under the parallel load. |
| storage-blocked | - | - | - | - | - | - | - | NOT RUN (time box). Expected behaviour from the code: `TourSave.save_state` fails with `push_error` (`tour_save.gd:38-41`) and play continues in memory; not observed. |
| long (`--secs 180`) | 1 | 0 | no | 0->6 in ~180 s before the browser closed | - | 2-4 | 30 -> 56 MB over 180 s | NOT VERIFIED: heap +26 MB (limit 60) and 0 page errors while it ran; ended by the same browser close. |

Fault proof (the harness can fail):
- `node tools/harness/play.mjs --mode default --episodes 1 --secs 45 --fault dead-mouse` (the served
  `index.js` has its canvas `"mousedown"` listener renamed): `FAIL: stuck while playing, no progression -
  no progression signal moved: completed`, `menu 0->0`, 0 page errors, boot 8284 ms, exit 1
  (`report-default-fault-dead-mouse.json`). The clean run of the same mode is the PASS row above.
- `--fault no-boot` (`engine.startGame` misspelled in `index.html`): NOT RUN (time box).

Headless logic tests: `godot --headless --path . -s tools/test_world_tour.gd` -> `test_world_tour:
75 checks, 0 failures`, exit 0. Fault proof: with `if ratio >= 0.60` changed to `0.50` in
`_medal_for_score` the same command printed `FAIL  59.99% of target is none`, `75 checks, 1
failures`, exit 1; restored, exit 0 again.

Deepcheck sweep (`deepcheck.mjs`, 20 s desktop storm + mobile, COEP): 0 page errors, 0 console
errors, 0 failed requests; the NaN/undefined text scan is blind here because the whole UI is one
canvas (`body.innerText` is empty).

## Scorecard

| Axis | Score (0-5) | Evidence |
| --- | --- | --- |
| Sense | 2 | Goal text is on screen ("Compete across the globe, earn tour points, climb the rankings, and qualify for the TIDEBREAK Finals", `:236`) but the rules contradict the feedback: the header hard-codes "KAI LANI • RANK 24" (`:202`) while YOUR RANK shows the computed 250TH / 236TH beside it (screenshots d0/d2); "◉ 12,650 ★ 3,250" never changes (`:208`) although credits do (`:737`); the FINALS copy says "claim the World Tour crown" (`:104`) but the best reachable rank is 63RD (`_calculate_rank(20600) == 63`); and the "run" is a dialog labelled EVENT TEST HARNESS (`:465`) in which the player picks the medal, so nothing teaches why WIPEOUT exists. |
| Structure | 2 | Screen -> START EVENT -> dialog -> toast -> screen and RESET DEMO SAVE are all reachable and the harness never found a stuck state; but the season has no end state (`:741-744`, 100% changes nothing), the header nav is a dead label that looks like six tabs (`:195`), and there is no pause or title screen. |
| Progression | 2 | Persists across runs (xp/points/medals/completed/current_stop in `user://tidebreak_world_tour.json`, tiers `:635-640`, rank `:879-881`; harness `completed` 0->7 each episode) but nothing ramps within a run: the result is a fixed ratio of the target (`:756`), so every stop is the same click. |
| Juice | 2 | Visual only: three tweens (`:676-678`, `:799-804`, `:811-812`), StyleBox hover/press/focus swaps (`:948-952`), ring/route recolour (`tour_map.gd:94-106`); zero audio (`grep AudioStream scripts/` = 0), no shake, no particles, season end has no feedback at all. |
| Stability | 3 | Default play is clean (harness PASS: 7/7 stops, `over`, restart, 0 page errors; deepcheck desktop+mobile 0 errors) and the fault run goes red; no stress mode produced a game error, stuck state or lost save in what ran (storm 0->2, blur 0->5, long 0->6 with +26 MB heap), but those three were cut short by Chromium closing under load, mobile was not completed by the play harness, and resize / storage-blocked did not run - so 4 is not supportable and nothing observed supports 2. |

**Verdict:** FIX - the FIX rule fired (Stability < 4 and every design axis == 2). Read it as a design
problem, not a bug list: the surf heat the screen is built around does not exist, so no code fix
raises Sense, Progression or Juice above 2; the rubric's RETHINK threshold (<= 1) is not met only
because persistence, a reachable loop and on-screen goal text are all real.

## Gaps and next steps

1. **The surf heat does not exist (L).** The "run" is the four-button EVENT TEST HARNESS dialog
   (`:465-500`); the README says so. Until `event_requested` (`:7`) is connected to a real heat,
   Sense, Progression and Juice cannot rise above 2 - a player's only decision is which button
   gives the most XP, and GOLD always does.
2. **No season finale (S/M).** Completing TIDEBREAK FINALS shows the same toast as PIPELINE and
   `unlocked_stop` is empty (`:741-744`). A crown screen, a season summary or at least a distinct
   toast would give the loop an end.
3. **Header placeholders contradict live state (S).** "RANK 24" (`:202`), "12,650 / 3,250" (`:208`),
   the "/ 24,000 XP" cap (`:633`, max earnable 15,750) and the fixed top-3 leaderboard (`:599-601`,
   unreachable at max 20,600 points) all disagree with the numbers the game computes. Bind them to
   `state` or remove them. Left as is: copy/design scope, not a reproduced defect.
4. **Phone layout (M).** 1600x900 `canvas_items`/keep at 390x844 renders the UI as a 390x219 strip
   (`project.godot:13-17`, `export_presets.cfg:28`; screenshot `mobile-ep0-end.png`); START EVENT is
   about 12 CSS px tall. Needs a portrait layout or `stretch/aspect=expand` with larger minimums.
5. **No audio (M).** Not one `AudioStreamPlayer`; a result sting, a medal fanfare and a hover tick
   are the cheapest wins.
6. **`complete_event()` ignores locks (S).** It completes any stop id regardless of order
   (`:685-690`); gate it with `_is_stop_unlocked` before the real game calls it.
7. **Dividers look like empty progress bars (S).** `_divider()` gives the HSeparator a filled 12-px
   StyleBox (`:958-962`), so the panels show two grey bars under SEASON PROGRESS and YOUR RANK that
   never fill.

## Changelog of this programme's commits
- `cb6a9f4` Add a browser play harness and headless logic tests for the World Tour screen
- `eaa6b7c` CI: run the headless logic tests and the play harness on the web build
- (this commit) Add the game wiki with harness results and an evidence-bound scorecard; README links it

