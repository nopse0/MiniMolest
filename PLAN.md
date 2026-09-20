# MiniMolest — Sexual Stats & Fame System (Implementation Plan)

Track, over a configurable floating time window: how often the player had sex, and how
often he won/lost the struggle minigame. Expose these as readable stats and derive a
"sexual fame" value used to calculate chances for dialogs/events. Future: split sex into
consensual vs non-consensual (rape).

> Sources live in `Source/Scripts/*.psc` — edit those, not the `.pex` binaries.

## Current architecture (one concern per persistent Quest script)

| Script | Role |
|---|---|
| `MiniMolestMain_Script.psc` | Central state machine: ForceGreet → Dialogue → Struggle → Sex |
| `MiniMolestApproach_Script.psc` | Scans nearby NPCs, rolls `GreetChance` (line 195) |
| `MiniMolestStruggle_Script.psc` | QTE minigame; win via `CheckSuccess()` (line 237) |
| `MiniMolestConfig_Script.psc` | Loads `MiniMolest.json`, fans out `NotifyConfigChanged()` (lines 51–53) |
| `MiniMolestStats_Script.psc` | Bucket-ring stats: record + windowed/weighted queries, fame (later) |
| `MiniMolestTest_Script.psc` | Test quest script; stage-999 fragment calls `Test()` — reusable test hook |

All three trackable events already funnel through **two spots in `MiniMolestMain_Script`**:
- Sex scene start: `OnUpdate()` struggle-timeout branch, `StartScene(...)` at line 91.
- Struggle win: single funnel → `OnBreakFree()` (line 146).
- Struggle loss: same timeout branch, `ResolveMinigame(false)` at line 86.

## Locked decisions

1. **External-readable storage = GlobalVariables, NOT faction ranks.**
   Papyrus cannot set a faction rank to an arbitrary value — the whole Actor faction API is
   `AddToFaction` / `RemoveFromFaction` / `GetRank` / `IsInFaction` (no set/increment). So a
   running counter can't be a faction rank. GlobalVariables are persistent, settable via
   `SetValue()`, and referenceable in CK dialogue conditions (`kMM_FameTier.GetValue() >= 3`).
   Optional later: map fame to discrete *tier factions* only if another mod needs to read them.

2. **Sex is counted on scene COMPLETION**, not start. Hook = `OnSexLabAnimationEnd`
   (`MiniMolestMain_Script.psc:128`), guarded by a `Bool SexSceneActive` flag so exactly one
   completed act is counted (the hook fires more than once per scene). The hook name is
   MiniMolest-specific (`MiniMolestSLHook`), so other mods' scenes can't trigger it. An aborted
   scene never clears the flag via this path → not counted.

3. **Storage = bucket histogram, NOT per-event timestamps.** Respects the 128-entry Papyrus
   array cap (we store counts-per-slice, not events) and fits a days/weeks/months scope with
   recency weighting.

## Build / compile

Compile with Pyro (bundled in the papyrus-lang VS Code extension) against `skyrimse.ppj`:
```
& "C:\Users\nirme\.vscode\extensions\joelday.papyrus-lang-vscode-3.2.0\pyro\pyro.exe" skyrimse.ppj
```
(run from the mod root; writes `.pex` into `Scripts/`). The ppj imports CK + SKSE + dependency sources —
check both when looking up APIs (SKSE overwrites/adds some CK scripts).

Papyrus syntax gotchas (hit during build):
- Logical operators are C-style `&&` / `||` / `!` — the words `and`/`or` do NOT parse.

JsonUtil key naming:
- Key matching is **case-insensitive only** — JSON keys are the Papyrus property name in plain
  lowercase, with NO camelCase→snake_case conversion (underscores matter). E.g. `fStats_sexWindowHours`
  matches `fstats_sexwindowhours`, NOT `fstats_sexwindow_hours`. A mismatched key silently falls back
  to the `missing` value passed to `Get*Value` — no error is logged, so a wrong key looks like "config
  ignored". (Fixed in step 4: two window keys from step 3 + two fame weight keys; also pre-existing
  `ifapproach_maxcandidates/maxcooldowns` → `iapproach_...`.)

Plugin behavior gotchas:
- `JsonUtil` (PapyrusUtil SE) keeps an **in-memory copy** of each JSON file per game session;
  `Get*Value` reads from memory, not disk. A plain `Load()` is a no-op if the file is already
  loaded — you must `JsonUtil.Unload(FileName, false)` first to evict the cached copy, then
  `Load()`. `LoadConfiguration()` does exactly this (safe: MiniMolest never writes the JSON at
  runtime), so "edit JSON → restart config quest" picks up new values without a game restart.
- MO2 here runs **USVFS**: there is no materialized `Data\SKSE` on disk and no merged profile
  tree — file access resolves live to the mod folders (plus `overwrite/`, which has top priority).
  Runtime edits in `mods\<mod>\...` are therefore visible to fresh reads; VFS staleness is not a
  factor. (`overwrite\SKSE\Plugins\StorageUtilData\` exists but does not shadow MiniMolest.json.)

## Data model: rolling bucket ring

- Time source: `Utility.GetCurrentGameTime() * 24.0` — the API returns game **days** as a float;
  there is no `GetGameHours()` in vanilla or SKSE sources (verified against CK + SKSE `.psc`).
  Advances only while playing/sleeping. Configurable to real time later (`Game.GetRealHoursPassed()`).
- Papyrus constraint: array creation needs an **integer literal** size (`new Int[n]` with a variable
  fails: "mismatched input 'n' expecting INTEGER"). Rings are therefore always allocated at 128 slots;
  only the first `BucketCount` slots are addressed via `slot = abs % BucketCount`.
- **Granularity vs span** tradeoff, both configurable; product = total covered time.
  - default: daily buckets (`bucketHours=24`) × 90 ≈ 3 months
  - longer span → weekly buckets (`bucketHours=168`), same code, coarser resolution
- **Recency weighting** (for fame only): exponential decay `weight = 0.5 ^ (ageHours / halfLife)`,
  default half-life 72h. Plain windowed *counts* stay unweighted.

### Structures (per stat series; all persist with the quest)
```
Int   BucketCount            ; = maxBuckets, clamped <= 128
Float BucketHours            ; granularity

; one pair per series: sexConsensual, sexNonConsensual, struggleWin, struggleLoss
Int[] <Series>Buckets        ; count in that bucket
Int[] <Series>Stamps         ; absolute-bucket index the slot currently represents
```
4 series × 2 arrays = 8 arrays, each ≤128 Ints. The `Stamps` array makes it save/load-safe and
wrap-around-safe: a slot is trusted only if its stamp equals the queried absolute bucket, so
stale/wrapped slots self-heal with no special load code.

The consensual series stays zero until that feature lands — **no migration needed later.**

### Core logic (sketch)
```
Int   BucketOf(Float hours)              ; floor(hours / BucketHours)

Record<Series>()                         ; RecordSex(Bool), RecordStruggleWin(), RecordStruggleLoss()
    abs  = BucketOf(Game.GetGameHours())
    slot = abs % BucketCount
    if Stamps[slot] != abs { Buckets[slot]=0; Stamps[slot]=abs }   ; stale/wrapped -> reset
    Buckets[slot] += 1

Int   GetSexCountInWindow(Float hours)   ; UNWEIGHTED "how often in last N days"
    sum Buckets over abs buckets [floor((now-hours)/bh) .. floor(now/bh)] where stamp matches
    (consensual + non-consensual combined)

Float GetWeightedSexScore()              ; recency-decayed magnitude -> drives fame
    sum Buckets[slot] * 0.5^(ageHours/halfLife) across the retained ring
```
Two read-outs from one histogram:
- `Get…CountInWindow(hours)` → unweighted count (dialog thresholds like "sex 5+ times this week").
- `GetWeighted…Score()` → decayed magnitude for the fame value feeding chance rolls.

Note: with daily buckets, "last 24h" includes the whole current (partial) day — acceptable approximation.

## Recording call sites (all in `MiniMolestMain_Script.psc`)
- **Win** — `OnBreakFree()` (line 146) → `Stats.RecordStruggleWin()`.
- **Loss + sex-start** — `OnUpdate()` timeout branch (lines 86–95) → `RecordStruggleLoss()`;
  set `SexSceneActive = true` after a successful `StartScene`.
- **Sex completed** — `OnSexLabAnimationEnd`: `if SexSceneActive { Stats.RecordSex(false); SexSceneActive=false }`.

## Config additions (`SKSE/Plugins\StorageUtilData/MiniMolest.json`)
```jsonc
"int": {
  "istats_maxbuckets": 90       ; retained buckets, clamped <=128; span = buckethours*maxbuckets
},
"float": {
  "fstats_buckethours": 24.0,   ; granularity (24=daily) — float key, not the originally planned int one
  "fstats_sexwindowhours": 168.0,        ; default "how often" window (7 days)
  "fstats_strugglewindowhours": 168.0,
  "fstats_decayhalflifehours": 72.0      ; recency weighting for fame
}
```
Fame keys (added in step 4): `fstats_fameweightsex` (default 1.0), `fstats_fameweightloss`
(default 0.5), `fstats_famenormalizer` (default 10.0 — weighted sex acts per fame point),
`fstats_famelossnormalizer` (default 10.0 — weighted losses per fame point),
`fstats_famesaturation` (default 1.0 — k in the x/(x+k) normalized-fame mapping).

## Fame system (tunable)
`GetFameScore() = wSex * GetWeightedSexScore()/normSex + wLoss * GetStruggleLossWeighted()/normLoss`,
where both terms are recency-decayed counts over their respective windows (sex window / struggle
window). `GetFameTier()` buckets that into integers for CK dialogue conditions and for modulating
the approach roll at `MiniMolestApproach_Script.psc:195`. Exact weights/thresholds are a design call —
the bucketed, weighted data is what makes it tunable.

Implementation notes (step 4):
- Both terms are unbounded frequency×recency scores; each has its own normalizer so the user can
  calibrate "events per fame point" independently (`fstats_famenormalizer`, `fstats_famelossnormalizer`).
  (Originally the loss term was a bounded win/loss *rate*; replaced 2026-09-20 because it saturated at
  wLoss and gave maximum loss-fame from a single loss.)
- The plain win rate is still available as `GetStruggleWinRate()` / `MM_Stat_StruggleWinRate` for
  "how helpless he is" dialogue conditions, independent of fame.
- Losses partially overlap with the sex term (a lost struggle usually leads to a non-consensual act);
  acceptable — aborted scenes never count and the two represent different gossip.
- `GetFameTier() = floor(GetFameScore())` — one tier per whole fame point; scale via the weight/normalizer
  keys instead of adding threshold keys.
- Normalized fame for smooth dialogue conditions: `GetFameNormalized() = 100 * score/(score + k)` maps
  the unbounded score onto [0,100) (the faction-rank scale), where `k = fstats_famesaturation` is the fame
  value at which normalized fame hits exactly 50. Monotonic; approaches but never reaches 100. Validated > 0
  in `ReadConfig()`. Mirrored to a fifth GlobalVariable `MM_FameNorm` (float) so CK can do smooth checks
  (`kMM_FameNorm.GetValue() >= 40`) while `MM_FameTier` stays the int floor for discrete tiers.
- GlobalVariable mirrors (`MM_Stat_SexWindow`, `MM_Stat_StruggleWinRate`, `MM_FameScore`,
  `MM_FameTier`, `MM_FameNorm`) are refreshed on every record, at first init, and on config change; unbound
  properties are skipped, so the script is safe before/without the CK bindings.

## Files to change / create
- **NEW** `Source/Scripts/MiniMolestStats_Script.psc` (`extends Quest`) — buckets, record/query,
  fame, `ReadConfig()` + `NotifyConfigChanged()` (mirror the sibling pattern).
- `MiniMolestMain_Script.psc` — add `MiniMolestStats_Script Property MiniMolestStats Auto`;
  add the three record calls; add `Bool SexSceneActive`.
- `MiniMolestConfig_Script.psc` — add stat properties, load them in `LoadConfiguration()`, and add
  `MiniMolestStats.NotifyConfigChanged()` to the fan-out (lines 51–53).
- `SKSE/Plugins\StorageUtilData/MiniMolest.json` — stats section above.

## CK / ESP work
- New **Quest** `QF_MiniMolestStats_…`, attach script, set to start at game load (like the other
  manager quests). No player alias needed — uses `Game.GetPlayer()`.
- Bind that quest into `MiniMolestMain_Script`'s `MiniMolestStats` property.
- **GlobalVariable** forms for mirrored values: `MM_Stat_SexWindow` (int), `MM_Stat_StruggleWinRate`
  (float), `MM_FameScore` (float), `MM_FameTier` (int), `MM_FameNorm` (float — normalized [0,100)). Refreshed on each record, at first init, and
  on config change — for CK dialogue conditions (`kMM_FameTier.GetValue() >= 3`) and console checks
  (`getglobal MM_FameScore`). Int vs float form type doesn't matter to the script (`SetValueInt` /
  `SetValue` both work either way); bind each form to the same-named property on the stats quest.

## Build order
1. ~~Stats quest + bucket ring + the three `Record*()` calls + `SexSceneActive` guard; verify via `Debug.Trace`.~~ **DONE, verified in-game** (allocation + record traces confirmed). Notes:
   - Win recording is gated on `MiniMolestState == "Struggle"` in `OnBreakFree()`, so stage-999 /
     `TestMinigame()` runs do NOT pollute stats.
   - All record calls are guarded by `if MiniMolestStats != None`.
   - CK work done: Quest `QF_MiniMolestStats_…` created (script attached, Start Game Enabled) and bound
     to the `MiniMolestStats` property on the main quest form.
2. ~~Windowed-count + weighted-score queries; test hook to dump current windows/scores.~~ **DONE, verified in-game** (decay math hand-checked against TestDump output). Notes:
   - Queries in `MiniMolestStats_Script.psc`: `GetSexCount()`, `GetSexWeightedScore()`,
      `GetStruggleWinCount()`, `GetStruggleLossCount()`, `GetStruggleWinRate()`; window params are now
      config-driven via `ReadConfig()` (step 3), with the script fields as fallback defaults.
   - Test hook: dedicated test quest `QF_MiniMolestTestQuest_0904F95B` — set stage 999 → fragment calls
     `MiniMolestTest_Script.Test()` → `Stats.TestDump()`. Re-stageable at will.
    - **CK work done:** bound the `Stats` property on `MiniMolestTest_Script` to the stats quest (stage 999 → TestDump verified in-game).
 3. ~~Config wiring (granularity, span, half-life, weights).~~ **DONE, verified in-game** (JSON values confirmed via TestDump; runtime reload confirmed working). Notes:
     - JSON keys: `istats_maxbuckets`, `fstats_buckethours` (float — not the originally planned int key, since non-integer granularities are legitimate),
       `fstats_sexwindowhours`, `fstats_strugglewindowhours`, `fstats_decayhalflifehours`. Fame weight keys land with step 4.
    - Stats now has `ReadConfig()` + `NotifyConfigChanged()` (sibling pattern); the config fan-out calls it None-guarded.
      Geometry change (bucketHours/maxBuckets) → rings rebuilt via `AllocateBuckets()`; window params just update in place.
      Init order self-heals either way: stats reads config at first init, and a later config load re-applies + reallocates if needed.
    - **CK work done:** bound `MiniMolestStats` on the CONFIG quest → stats quest, and `MiniMolestConfig` on the STATS quest → config quest.
    - Runtime reload: "edit JSON → restart config quest" now picks up new values without a game restart — required the
      `Unload(configName, false)` before `Load()` (see Plugin behavior gotchas). Verified in-game.
 4. ~~GlobalVariables mirror + fame score/tier.~~ **DONE, verified in-game** (2026-09-20). Notes:
     - JSON keys added: `fstats_fameweightsex` (1.0), `fstats_fameweightloss` (0.5), `fstats_famenormalizer` (10.0),
       `fstats_famelossnormalizer` (10.0). Normalizers are validated (> 0) in `ReadConfig()`; weights are applied as-is
       (negative = intentional tuning allowed).
     - Formula revision (2026-09-20): loss term changed from bounded win/loss *rate* to the decay-weighted loss count
       (`GetStruggleLossWeighted()`) divided by its own normalizer — both fame terms are now unbounded frequency×recency.
       See "Fame system" notes for rationale.
    - Key-naming audit: renamed JSON keys to plain-lowercase Papyrus names — `fstats_sexwindow_hours` →
      `fstats_sexwindowhours`, `fstats_strugglewindow_hours` → `fstats_strugglewindowhours` (step 3; these had
      been silently falling back to script defaults, which happened to equal the JSON values), plus the two new
      fame weight keys and pre-existing `ifapproach_maxcandidates/maxcooldowns`. See "JsonUtil key naming" gotcha.
    - Stats: `GetFameScore()`, `GetFameTier()` (= floor of score), `RefreshMirrors()` into the four
      GlobalVariable properties, called from each `Record*()`, first init, and `NotifyConfigChanged()`.
    - `TestDump()` now prints a fame line (score, tier, active weights) for in-game verification.
     - **CK work done:** four GlobalVariable forms created and bound to the same-named properties on the
       stats quest — int globals as **'short'** type (fine: values are small counts/tiers, nowhere near the
       ±32767 limit), floats as float. Verified in-game: all three record types fire with correct bucket
       rollover; TestDump fame line matches hand-computed value exactly (`1.0 × 2.5874/10 + 0.5 × 3/4 = 0.6337`,
        tier=0); JSON key renames confirmed live (changing `fstats_sexwindowhours` now affects the dump).
     - Normalized fame added (2026-09-20): `GetFameNormalized()` → [0,100) via `x/(x+k)` with configurable
       `k = fstats_famesaturation` (default 1.0), mirrored to new GlobalVariable `MM_FameNorm`. Compiled clean;
       needs in-game verification (`TestDump` now prints `norm=` and `satK=`). CK: create + bind the `MM_FameNorm`
       float form like the other mirrors.
  5. ~~Fame-driven chance/dialogue integration.~~ **DONE** (2026-09-20). Approach + force-greet outcome now scale with normalized sexual fame; all logic lives in `MiniMolestMain_Script` (scanner untouched — no new CK binding needed). Notes:
     - Design decision: the scanner keeps its fixed `GreetChance` trial frequency; Main does the fame gate by returning false from `GreetActor()` when it declines. A rejection happens BEFORE any state is touched, so the scanner sets NO per-NPC cooldown and does NOT update `LastGreetScan` — low-fame rejections never "burn" an NPC's cooldown (only successful engagements do). This avoids colliding with the scanner's cooldowns.
     - Two new chance curves, both driven by `GetFameNormalized()` [0,100]:
       - **Approach accept** = clamp(`fMain_approachBaseChance` + `fMain_fameApproachBonus` × norm/100) — rolled in `GreetActor()` before engaging.
       - **Force-greet outcome** (struggle vs let-go) = clamp(`fMain_outcomeBaseChance` + `fMain_fameOutcomeBonus` × norm/100) — rolled in `RollForceGreetOutcome()`, sets `MiniMolestForceGreetOutcome`.
     - JSON keys added: `fmain_approachbasechance` (0.25), `fmain_fameapproachbonus` (0.75), `fmain_outcomebasechance` (0.25), `fmain_fameoutcomebonus` (0.75).
     - Config: four new Auto properties + JsonUtil loads + trace in `LoadConfiguration()`; Main reads them in `ReadConfig()`. Helpers `ClampChance`, `GetApproachAcceptChance`, `RollForceGreetOutcome` added to Main.
     - Compiled clean (Pyro, 2 scripts recompiled). Needs in-game verification: watch for "Declined approach (fame gate)" and "Force-greet outcome roll" traces as fame changes.
