Scriptname MiniMolestConfig_Script extends Quest

;float Property fDamageMultiplier = 1.0 Auto
;bool Property bEnableFeature = true Auto

Int Property iStruggleBar_bgR = 40 Auto
Int Property iStruggleBar_bgG = 40 Auto
Int Property iStruggleBar_bgB = 40  Auto
Int Property iStruggleBar_borderR = 0 Auto
Int Property iStruggleBar_borderG = 0 Auto
Int Property iStruggleBar_borderB = 0 Auto

Int Property iStruggleBar_penaltyAmount = 2 Auto
Int Property iStruggleBar_targetMashes = 20 Auto
Float Property fStruggleBar_timeLimit = 5.0 Auto
Float Property fStruggleBar_updateInterval = 0.5 Auto
; Default DXScanCodes: 30 is 'A', 32 is 'D'
Int Property iStruggleBar_mashKeyA = 30 Auto
Int Property iStruggleBar_mashKeyB = 32 Auto
Int Property iStruggleBar_maxKeyRepeat = 4 Auto

Float Property fApproach_scanInterval = 10.0 Auto
Float Property fApproach_detectionRadius = 700.0 Auto
Int Property iApproach_maxCandidates = 8 Auto
Int Property iApproach_maxCooldowns = 16 Auto
Float Property fApproach_npcGreetCooldown = 300.0 Auto
Float Property fApproach_globalGreetInterval = 60.0 Auto
Float Property fApproach_greetChance = 0.4 Auto
Float Property fApproach_greetTimeout = 90.0 Auto
; Fame-driven approach tuning (step 5): probability that Main accepts an approach the
; scanner proposes. Base chance at zero fame plus a bonus scaled by normalized sexual
; fame [0,100), clamped to [0,1]. A rejection returns false from GreetActor and does
; NOT consume any scanner cooldown.
Float Property fMain_approachBaseChance = 0.25 Auto
Float Property fMain_fameApproachBonus = 0.75 Auto

; Fame-driven force-greet outcome tuning (step 5): probability that a denial triggers
; a struggle (outcome=1) instead of the NPC letting it go (outcome=0). Base chance at
; zero fame plus a bonus scaled by normalized sexual fame [0,100), clamped to [0,1].
Float Property fMain_outcomeBaseChance = 0.25 Auto
Float Property fMain_fameOutcomeBonus = 0.75 Auto

Int Property iStats_maxBuckets = 90 Auto
Float Property fStats_bucketHours = 24.0 Auto
Float Property fStats_sexWindowHours = 168.0 Auto
Float Property fStats_struggleWindowHours = 168.0 Auto
Float Property fStats_decayHalfLifeHours = 72.0 Auto
Float Property fStats_fameWeightSex = 1.0 Auto
Float Property fStats_fameWeightLoss = 0.5 Auto
Float Property fStats_fameNormalizer = 10.0 Auto
Float Property fStats_fameLossNormalizer = 10.0 Auto
Float Property fStats_fameSaturation = 1.0 Auto

MiniMolestApproach_Script Property MiniMolestApproach Auto
MiniMolestMain_Script Property MiniMolestMain Auto
MiniMolestStruggle_Script Property MiniMolestStruggle Auto
MiniMolestStats_Script Property MiniMolestStats Auto

; Restart config quest, if you change the config at run time 
Event OnInit()
    Debug.trace("[MiniMolest Config] OnInit")
    if IsRunning()
        ; OnInit is called twice, so defer initialization
        RegisterForSingleUpdate(8)
    endif
EndEvent

Function OnUpdate()
    Debug.Trace("[MiniMolest Config] OnUpdate: First time initialization")
    if !IsRunning()
        RegisterForSingleUpdate(0.5)
        return
    endif
    LoadConfiguration()
    MiniMolestMain.NotifyConfigChanged()
    MiniMolestApproach.NotifyConfigChanged()
    MiniMolestStruggle.NotifyConfigChanged()
    if MiniMolestStats != None
        MiniMolestStats.NotifyConfigChanged()
    endif
EndFunction

Function NotifyPlayerLoadGame()
    Debug.trace("[MiniMolest Config] NotifyPlayerLoadGame")
    RegisterForSingleUpdate(0.5)
EndFunction

Function LoadConfiguration()
    Debug.Trace("[MiniMolest Config] LoadConfiguration")

    string configName = "MiniMolest.json"

    ; JsonUtil keeps an in-memory copy of each file per game session and Get*Value reads from it,
    ; not from disk. A plain Load() is a no-op if the file is already loaded, so Unload first to
    ; evict the cached copy (no runtime writes exist for this file, saveChanges=false is safe),
    ; then Load to force a fresh read — picks up runtime JSON edits on quest restart.
    Debug.Trace("[MiniMolest Config] LoadConfiguration: reloading " + configName)
    JsonUtil.Unload(configName, false)
    if !JsonUtil.Load(configName)
        Debug.Trace("[MiniMolest Config] LoadConfiguration: JsonUtil.Load failed for " + configName)
        return
    endif

    if JsonUtil.IntListCount(configName, "istrugglebar_bg")
        iStruggleBar_bgR = JsonUtil.IntListGet(configName, "istrugglebar_bg", 0)
        iStruggleBar_bgG = JsonUtil.IntListGet(configName, "istrugglebar_bg", 1)
        iStruggleBar_bgB = JsonUtil.IntListGet(configName, "istrugglebar_bg", 2)
    endif
    
    if JsonUtil.IntListCount(configName, "istrugglebar_border")
        iStruggleBar_borderR = JsonUtil.IntListGet(configName, "istrugglebar_border", 0)
        iStruggleBar_borderG = JsonUtil.IntListGet(configName, "istrugglebar_border", 1)
        iStruggleBar_borderB = JsonUtil.IntListGet(configName, "istrugglebar_border", 2)
    endif

    iStruggleBar_penaltyAmount = JsonUtil.GetIntValue(configName, "iStruggleBar_penaltyAmount", iStruggleBar_penaltyAmount)
    iStruggleBar_targetMashes = JsonUtil.GetIntValue(configName, "iStruggleBar_targetMashes", iStruggleBar_targetMashes)
    fStruggleBar_timeLimit = JsonUtil.GetFloatValue(configName, "fStruggleBar_timeLimit", fStruggleBar_timeLimit)
    fStruggleBar_updateInterval = JsonUtil.GetFloatValue(configName, "fStruggleBar_updateInterval", fStruggleBar_updateInterval)
    iStruggleBar_mashKeyA = JsonUtil.GetIntValue(configName, "iStruggleBar_mashKeyA", iStruggleBar_mashKeyA)
    iStruggleBar_mashKeyB = JsonUtil.GetIntValue(configName, "iStruggleBar_mashKeyB", iStruggleBar_mashKeyB)
    iStruggleBar_maxKeyRepeat = JsonUtil.GetIntValue(configName, "iStruggleBar_maxKeyRepeat", iStruggleBar_maxKeyRepeat)

    fApproach_scanInterval = JsonUtil.GetFloatValue(configName, "fApproach_scanInterval", fApproach_scanInterval)
    fApproach_detectionRadius = JsonUtil.GetFloatValue(configName, "fApproach_detectionRadius", fApproach_detectionRadius)
    iApproach_maxCandidates = JsonUtil.GetIntValue(configName, "iApproach_maxCandidates", iApproach_maxCandidates)
    iApproach_maxCooldowns = JsonUtil.GetIntValue(configName, "iApproach_maxCooldowns", iApproach_maxCooldowns)
    fApproach_npcGreetCooldown = JsonUtil.GetFloatValue(configName, "fApproach_npcGreetCooldown", fApproach_npcGreetCooldown)
    Debug.Trace("[MiniMolest Config] fApproach_npcGreetCooldown = " + fApproach_npcGreetCooldown)
    fApproach_globalGreetInterval = JsonUtil.GetFloatValue(configName, "fApproach_globalGreetInterval", fApproach_globalGreetInterval)
    fApproach_greetChance = JsonUtil.GetFloatValue(configName, "fApproach_greetChance", fApproach_greetChance)
    fApproach_greetTimeout = JsonUtil.GetFloatValue(configName, "fApproach_greetTimeout", fApproach_greetTimeout)

    fMain_approachBaseChance = JsonUtil.GetFloatValue(configName, "fMain_approachBaseChance", fMain_approachBaseChance)
    fMain_fameApproachBonus = JsonUtil.GetFloatValue(configName, "fMain_fameApproachBonus", fMain_fameApproachBonus)
    fMain_outcomeBaseChance = JsonUtil.GetFloatValue(configName, "fMain_outcomeBaseChance", fMain_outcomeBaseChance)
    fMain_fameOutcomeBonus = JsonUtil.GetFloatValue(configName, "fMain_fameOutcomeBonus", fMain_fameOutcomeBonus)

    iStats_maxBuckets = JsonUtil.GetIntValue(configName, "iStats_maxBuckets", iStats_maxBuckets)
    fStats_bucketHours = JsonUtil.GetFloatValue(configName, "fStats_bucketHours", fStats_bucketHours)
    fStats_sexWindowHours = JsonUtil.GetFloatValue(configName, "fStats_sexWindowHours", fStats_sexWindowHours)
    fStats_struggleWindowHours = JsonUtil.GetFloatValue(configName, "fStats_struggleWindowHours", fStats_struggleWindowHours)
    Float tmp = JsonUtil.GetFloatValue(configName, "fStats_decayHalfLifeHours", fStats_decayHalfLifeHours)
    fStats_decayHalfLifeHours = tmp 
    Debug.Trace("[MiniMolest Config] LoadConfiguration: fStats_decayHalfLifeHours = " + fStats_decayHalfLifeHours + ", tmp = " + tmp)

    fStats_fameWeightSex = JsonUtil.GetFloatValue(configName, "fStats_fameWeightSex", fStats_fameWeightSex)
    fStats_fameWeightLoss = JsonUtil.GetFloatValue(configName, "fStats_fameWeightLoss", fStats_fameWeightLoss)
    fStats_fameNormalizer = JsonUtil.GetFloatValue(configName, "fStats_fameNormalizer", fStats_fameNormalizer)
    fStats_fameLossNormalizer = JsonUtil.GetFloatValue(configName, "fStats_fameLossNormalizer", fStats_fameLossNormalizer)
    fStats_fameSaturation = JsonUtil.GetFloatValue(configName, "fStats_fameSaturation", fStats_fameSaturation)

    Debug.trace("[MiniMolest Config] LoadConfiguration: config loaded. "\
     + "istrugglebar_bg=" + iStruggleBar_bgR + "," + iStruggleBar_bgG + "," + iStruggleBar_bgB\
     + ", istrugglebar_border=" + iStruggleBar_borderR + "," + iStruggleBar_borderG + "," + iStruggleBar_borderB\
     + ", istrugglebar_penaltyAmount=" + iStruggleBar_penaltyAmount\
     + ", istrugglebar_targetMashes=" + iStruggleBar_targetMashes\
     + ", fStruggleBar_timeLimit=" + fStruggleBar_timeLimit\
     + ", fStruggleBar_updateInterval=" + fStruggleBar_updateInterval\
     + ", iStruggleBar_mashKeyA=" + iStruggleBar_mashKeyA\
     + ", iStruggleBar_maxKeyRepeat=" + iStruggleBar_maxKeyRepeat\
     + ", fApproach_scanInterval=" + fApproach_scanInterval\
     + ", fApproach_detectionRadius=" + fApproach_detectionRadius\
     + ", iApproach_maxCandidates=" + iApproach_maxCandidates\
     + ", iApproach_maxCooldowns=" + iApproach_maxCooldowns\
     + ", fApproach_npcGreetCooldown=" + fApproach_npcGreetCooldown\
     + ", fApproach_globalGreetInterval=" + fApproach_globalGreetInterval\
      + ", fApproach_greetChance=" + fApproach_greetChance\
      + ", fApproach_greetTimeout=" + fApproach_greetTimeout\
      + ", fMain_approachBaseChance=" + fMain_approachBaseChance\
      + ", fMain_fameApproachBonus=" + fMain_fameApproachBonus\
      + ", fMain_outcomeBaseChance=" + fMain_outcomeBaseChance\
      + ", fMain_fameOutcomeBonus=" + fMain_fameOutcomeBonus\
      + ", iStats_maxBuckets=" + iStats_maxBuckets\
     + ", fStats_bucketHours=" + fStats_bucketHours\
     + ", fStats_sexWindowHours=" + fStats_sexWindowHours\
     + ", fStats_struggleWindowHours=" + fStats_struggleWindowHours\
      + ", fStats_decayHalfLifeHours=" + fStats_decayHalfLifeHours\
      + ", fStats_fameWeightSex=" + fStats_fameWeightSex\
      + ", fStats_fameWeightLoss=" + fStats_fameWeightLoss\
       + ", fStats_fameNormalizer=" + fStats_fameNormalizer\
        + ", fStats_fameLossNormalizer=" + fStats_fameLossNormalizer\
        + ", fStats_fameSaturation=" + fStats_fameSaturation\
        )
EndFunction
