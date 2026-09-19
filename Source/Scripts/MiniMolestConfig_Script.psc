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

MiniMolestApproach_Script Property MiniMolestApproach Auto
MiniMolestMain_Script Property MiniMolestMain Auto
MiniMolestStruggle_Script Property MiniMolestStruggle Auto

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
EndFunction

Function NotifyPlayerLoadGame()
    Debug.trace("[MiniMolest Config] NotifyPlayerLoadGame")
    RegisterForSingleUpdate(0.5)
EndFunction

Function LoadConfiguration()
    Debug.Trace("[MiniMolest Config] LoadConfiguration")

    string configName = "MiniMolest.json"

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

    ;int iEnableFeature = bEnableFeature as int
    ;iEnableFeature = JsonUtil.GetIntValue(configName, "iEnableFeature", iEnableFeature)
    ;bEnableFeature = (iEnableFeature != 0)
    
    Debug.trace("[MiniMolest Config] LoadConfiguration: config loaded.")
EndFunction
