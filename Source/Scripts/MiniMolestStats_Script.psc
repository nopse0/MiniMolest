Scriptname MiniMolestStats_Script extends Quest

; --- Bucket geometry (config-driven via ReadConfig, these are fallback defaults) ---
Int   BucketCount = 90        ; retained buckets, clamped <= 128
Float BucketHours = 24.0      ; granularity in game-hours

MiniMolestConfig_Script Property MiniMolestConfig Auto

; One pair per series: sexConsensual, sexNonConsensual, struggleWin, struggleLoss
; Stamps[slot] = absolute bucket index the slot currently represents (save/wrap-safe)
Int[] SexConsensualBuckets
Int[] SexConsensualStamps
Int[] SexNonConsensualBuckets
Int[] SexNonConsensualStamps
Int[] StruggleWinBuckets
Int[] StruggleWinStamps
Int[] StruggleLossBuckets
Int[] StruggleLossStamps

Bool Initialized = false

Event OnInit()
    Debug.Trace("[MiniMolest Stats] OnInit")
    if IsRunning()
        ; OnInit is called twice, so defer initialization
        RegisterForSingleUpdate(8)
    endif
EndEvent

Function OnUpdate()
    if !IsRunning()
        RegisterForSingleUpdate(0.5)
        return
    endif
    if Initialized
        return
    endif
    Debug.Trace("[MiniMolest Stats] First time initialization")
    ReadConfig()
    AllocateBuckets()
    Initialized = true
    RefreshMirrors()
EndFunction

Function AllocateBuckets()
    ; Papyrus array creation needs a literal size, so rings are always 128 slots;
    ; only the first BucketCount slots are ever addressed (slot = abs % BucketCount)
    Int n = BucketCount
    if n < 1
        n = 1
    endif
    if n > 128
        n = 128
    endif
    BucketCount = n

    SexConsensualBuckets   = new Int[128]
    SexConsensualStamps    = new Int[128]
    SexNonConsensualBuckets= new Int[128]
    SexNonConsensualStamps = new Int[128]
    StruggleWinBuckets     = new Int[128]
    StruggleWinStamps      = new Int[128]
    StruggleLossBuckets    = new Int[128]
    StruggleLossStamps     = new Int[128]

    Debug.Trace("[MiniMolest Stats] Allocated " + n + " buckets of " + BucketHours + "h")
EndFunction

; --- Config wiring (step 3) ---
Function ReadConfig()
    if MiniMolestConfig == None
        return
    endif
    Float oldBucketHours = BucketHours
    Int oldBucketCount = BucketCount
    Float newBucketHours = MiniMolestConfig.fStats_bucketHours
    Int newBucketCount = MiniMolestConfig.iStats_maxBuckets
    if newBucketHours > 0.0 && newBucketCount >= 1
        BucketHours = newBucketHours
        BucketCount = newBucketCount
    endif
    SexWindowHours = MiniMolestConfig.fStats_sexWindowHours
    StruggleWindowHours = MiniMolestConfig.fStats_struggleWindowHours
    DecayHalfLifeHours = MiniMolestConfig.fStats_decayHalfLifeHours
    FameWeightSex = MiniMolestConfig.fStats_fameWeightSex
    FameWeightLoss = MiniMolestConfig.fStats_fameWeightLoss
    if MiniMolestConfig.fStats_fameNormalizer > 0.0
        FameNormalizer = MiniMolestConfig.fStats_fameNormalizer
    endif
    if MiniMolestConfig.fStats_fameLossNormalizer > 0.0
        FameLossNormalizer = MiniMolestConfig.fStats_fameLossNormalizer
    endif
    if MiniMolestConfig.fStats_fameSaturation > 0.0
        FameSaturation = MiniMolestConfig.fStats_fameSaturation
    endif
    if Initialized && (BucketHours != oldBucketHours || BucketCount != oldBucketCount)
        ; Stamps from a different granularity are unsafe, rebuild the rings
        AllocateBuckets()
    endif
EndFunction

Function NotifyConfigChanged()
    Debug.Trace("[MiniMolest Stats] Config changed")
    ReadConfig()
    RefreshMirrors()
EndFunction

; Utility.GetCurrentGameTime() returns game DAYS, so convert to hours
Float Function NowHours()
    return Utility.GetCurrentGameTime() * 24.0
EndFunction

Int Function BucketOf(Float aHours)
    return Math.Floor(aHours / BucketHours) as Int
EndFunction

; --- Recording (called from MiniMolestMain_Script) ---

Function RecordSex(Bool aIsConsensual)
    if !Initialized
        Debug.Trace("[MiniMolest Stats] RecordSex ignored, not initialized yet")
        return
    endif
    Int abs = BucketOf(NowHours())
    Int slot = abs % BucketCount
    if aIsConsensual
        if SexConsensualStamps[slot] != abs
            SexConsensualBuckets[slot] = 0
            SexConsensualStamps[slot] = abs
        endif
        SexConsensualBuckets[slot] = SexConsensualBuckets[slot] + 1
        Debug.Trace("[MiniMolest Stats] Recorded consensual sex (bucket=" + abs + ", slot=" + slot + ")")
    else
        if SexNonConsensualStamps[slot] != abs
            SexNonConsensualBuckets[slot] = 0
            SexNonConsensualStamps[slot] = abs
        endif
        SexNonConsensualBuckets[slot] = SexNonConsensualBuckets[slot] + 1
        Debug.Trace("[MiniMolest Stats] Recorded non-consensual sex (bucket=" + abs + ", slot=" + slot + ")")
    endif
    RefreshMirrors()
EndFunction

Function RecordStruggleWin()
    if !Initialized
        Debug.Trace("[MiniMolest Stats] RecordStruggleWin ignored, not initialized yet")
        return
    endif
    Int abs = BucketOf(NowHours())
    Int slot = abs % BucketCount
    if StruggleWinStamps[slot] != abs
        StruggleWinBuckets[slot] = 0
        StruggleWinStamps[slot] = abs
    endif
    StruggleWinBuckets[slot] = StruggleWinBuckets[slot] + 1
    Debug.Trace("[MiniMolest Stats] Recorded struggle win (bucket=" + abs + ", slot=" + slot + ")")
    RefreshMirrors()
EndFunction

Function RecordStruggleLoss()
    if !Initialized
        Debug.Trace("[MiniMolest Stats] RecordStruggleLoss ignored, not initialized yet")
        return
    endif
    Int abs = BucketOf(NowHours())
    Int slot = abs % BucketCount
    if StruggleLossStamps[slot] != abs
        StruggleLossBuckets[slot] = 0
        StruggleLossStamps[slot] = abs
    endif
    StruggleLossBuckets[slot] = StruggleLossBuckets[slot] + 1
    Debug.Trace("[MiniMolest Stats] Recorded struggle loss (bucket=" + abs + ", slot=" + slot + ")")
    RefreshMirrors()
EndFunction

; --- Window parameters (config-driven via ReadConfig, these are fallback defaults) ---
Float SexWindowHours = 168.0        ; lookback for sex count/score
Float StruggleWindowHours = 168.0   ; lookback for struggle counts/rate
Float DecayHalfLifeHours = 72.0     ; half-life for the decay-weighted score

; --- Fame parameters (config-driven via ReadConfig, these are fallback defaults) ---
Float FameWeightSex = 1.0     ; weight of the decayed sex score in the fame formula
    Float FameWeightLoss = 0.5    ; weight of the decayed struggle-loss score in the fame formula
    Float FameNormalizer = 10.0   ; divides the weighted sex score (≈ acts per fame point)
    Float FameLossNormalizer = 10.0 ; divides the weighted loss score (≈ losses per fame point)
    Float FameSaturation = 1.0      ; k in x/(x+k): fame value at which normalized fame hits 50/100

; --- GlobalVariable mirrors (step 4) — for CK dialogue conditions, refreshed on each record ---
GlobalVariable Property MM_Stat_SexWindow Auto
GlobalVariable Property MM_Stat_StruggleWinRate Auto
GlobalVariable Property MM_FameScore Auto
GlobalVariable Property MM_FameTier Auto
GlobalVariable Property MM_FameNorm Auto

; --- Windowed queries (step 2) ---
; A window covers whole buckets: [BucketOf(now - aHours), BucketOf(now)]

Int Function CountWindow(Int[] aCounts, Int[] aStamps, Float aHours)
    if !Initialized
        return 0
    endif
    Int curAbs = BucketOf(NowHours())
    Int startAbs = BucketOf(NowHours() - aHours)
    Int total = 0
    Int i = 0
    while i < BucketCount
        if aStamps[i] >= startAbs && aStamps[i] <= curAbs
            total += aCounts[i]
        endif
        i += 1
    endwhile
    return total
EndFunction

Float Function WeightedWindow(Int[] aCounts, Int[] aStamps, Float aHours, Float aHalfLifeHours)
    if !Initialized || aHalfLifeHours <= 0.0
        return 0.0
    endif
    Int curAbs = BucketOf(NowHours())
    Int startAbs = BucketOf(NowHours() - aHours)
    Float total = 0.0
    Int i = 0
    while i < BucketCount
        if aStamps[i] >= startAbs && aStamps[i] <= curAbs
            Float ageHours = (curAbs - aStamps[i]) as Float * BucketHours
            total += (aCounts[i] as Float) * Math.Pow(0.5, ageHours / aHalfLifeHours)
        endif
        i += 1
    endwhile
    return total
EndFunction

Int Function GetSexCount()
    return CountWindow(SexConsensualBuckets, SexConsensualStamps, SexWindowHours) + CountWindow(SexNonConsensualBuckets, SexNonConsensualStamps, SexWindowHours)
EndFunction

Float Function GetSexWeightedScore()
    return WeightedWindow(SexConsensualBuckets, SexConsensualStamps, SexWindowHours, DecayHalfLifeHours) + WeightedWindow(SexNonConsensualBuckets, SexNonConsensualStamps, SexWindowHours, DecayHalfLifeHours)
EndFunction

Float Function GetStruggleLossWeighted()
    return WeightedWindow(StruggleLossBuckets, StruggleLossStamps, StruggleWindowHours, DecayHalfLifeHours)
EndFunction

Int Function GetStruggleWinCount()
    return CountWindow(StruggleWinBuckets, StruggleWinStamps, StruggleWindowHours)
EndFunction

Int Function GetStruggleLossCount()
    return CountWindow(StruggleLossBuckets, StruggleLossStamps, StruggleWindowHours)
EndFunction

Float Function GetStruggleWinRate()
    Int wins = GetStruggleWinCount()
    Int losses = GetStruggleLossCount()
    Int total = wins + losses
    if total == 0
        return 0.0
    endif
    return (wins as Float) / (total as Float)
EndFunction

; --- Fame (step 4) ---
Float Function GetFameScore()
    if !Initialized
        return 0.0
    endif
    Float sexPart = 0.0
    if FameNormalizer > 0.0
        sexPart = GetSexWeightedScore() / FameNormalizer
    endif
    Float lossPart = 0.0
    if FameLossNormalizer > 0.0
        lossPart = GetStruggleLossWeighted() / FameLossNormalizer
    endif
    return FameWeightSex * sexPart + FameWeightLoss * lossPart
EndFunction

Int Function GetFameTier()
    return Math.Floor(GetFameScore()) as Int
EndFunction

; Maps the unbounded fame score onto [0,100) via x/(x+k), where k = FameSaturation.
; 50/100 is reached at fame == k; approaches but never reaches 100 as fame grows.
Float Function GetFameNormalized()
    if !Initialized || FameSaturation <= 0.0
        return 0.0
    endif
    Float fame = GetFameScore()
    if fame <= 0.0
        return 0.0
    endif
    return 100.0 * fame / (fame + FameSaturation)
EndFunction

; Mirrors the current read-outs into GlobalVariables for CK dialogue conditions.
; Unbound properties are skipped, so this is safe before the CK bindings exist.
Function RefreshMirrors()
    if MM_Stat_SexWindow != None
        MM_Stat_SexWindow.SetValueInt(GetSexCount())
    endif
    if MM_Stat_StruggleWinRate != None
        MM_Stat_StruggleWinRate.SetValue(GetStruggleWinRate())
    endif
    if MM_FameScore != None
        MM_FameScore.SetValue(GetFameScore())
    endif
    if MM_FameTier != None
        MM_FameTier.SetValueInt(GetFameTier())
    endif
    if MM_FameNorm != None
        MM_FameNorm.SetValue(GetFameNormalized())
    endif
EndFunction

; --- Test hook (called from MiniMolestTest_Script.Test(), test quest stage 999) ---
Function TestDump()
    if !Initialized
        Debug.Trace("[MiniMolest Stats] TestDump: not initialized yet")
        return
    endif
    Int curAbs = BucketOf(NowHours())
    Debug.Trace("[MiniMolest Stats] Dump: now=" + NowHours() + "h, current bucket=" + curAbs + ", ring=" + BucketCount + "x" + BucketHours + "h")
    Debug.Trace("[MiniMolest Stats] Dump: sex window=" + SexWindowHours + "h halfLife=" + DecayHalfLifeHours + "h count=" + GetSexCount() + " weightedScore=" + GetSexWeightedScore())
    Debug.Trace("[MiniMolest Stats] Dump: struggle window=" + StruggleWindowHours + "h wins=" + GetStruggleWinCount() + " losses=" + GetStruggleLossCount() + " winRate=" + GetStruggleWinRate())
    Debug.Trace("[MiniMolest Stats] Dump: fame score=" + GetFameScore() + " tier=" + GetFameTier() + " norm=" + GetFameNormalized() + " (wSex=" + FameWeightSex + ", wLoss=" + FameWeightLoss + ", normSex=" + FameNormalizer + ", normLoss=" + FameLossNormalizer + ", satK=" + FameSaturation + ")")
EndFunction
