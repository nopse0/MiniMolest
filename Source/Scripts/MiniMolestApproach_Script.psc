Scriptname MiniMolestApproach_Script extends Quest


Int MAX_COOLDOWN_ENTRIES = 8
Actor[] CooldownActors
Int[] CooldownScans
Int CooldownIndex = 0
Int ScanCount = 0
Int LastGreetScan = -999999
; Int AliasSetScan = -1


Float ScanInterval = 10.0
Float DetectionRadius = 700.0
Int MaxCandidates = 8
Int MaxCooldowns = 16
Float NpcGreetCooldown = 300.0
Float GlobalGreetInterval = 60.0
Float GreetChance = 0.4
Float GreetTimeout = 90.0

Actor Property PlayerRef Auto
MiniMolestMain_Script Property MiniMolestMain Auto
MiniMolestConfig_Script Property MiniMolestConfig Auto
Bool Initialized = false
Bool ConfigChanged = false

Function ReadConfig()
	Debug.Trace("[MiniMolest Approach] ReadConfig")
    MaxCandidates = MiniMolestConfig.iApproach_maxCandidates
    if MaxCandidates >= 128
        MaxCandidates = 128
    endif

    MaxCooldowns = MiniMolestConfig.iApproach_maxCooldowns
    if MaxCooldowns >= 128
        MaxCooldowns = 128
    endif

	ScanInterval = MiniMolestConfig.fApproach_scanInterval
	DetectionRadius = MiniMolestConfig.fApproach_detectionRadius
	NpcGreetCooldown = MiniMolestConfig.fApproach_npcGreetCooldown
	GlobalGreetInterval = MiniMolestConfig.fApproach_globalGreetInterval
	GreetChance = MiniMolestConfig.fApproach_greetChance
	GreetTimeout = MiniMolestConfig.fApproach_greetTimeout

	; In case the cooldown array has been shrinked
	CooldownIndex = CooldownIndex % MaxCooldowns

	Debug.Trace("[MiniMolest Approach] ReadConfig: ScanInterval=" + ScanInterval + ", DetectionRadius=" + DetectionRadius\
	 + ", MaxCandidates=" + MaxCandidates + ", MaxCooldowns=" + MaxCooldowns + ", NpcGreetCooldown=" + NpcGreetCooldown\
	  + ", GlobalGreetInterval=" + GlobalGreetInterval + ", GreetChance=" + GreetChance + ", GreetTimeout=" + GreetTimeout)
EndFunction

;/
Event OnInit()
    ReadConfig()
	CooldownActors = new Actor[128]
	CooldownScans = new Int[128]
	Debug.Trace("[MiniMolest Approach] MiniMolestApproachManager_Script initialized.")
	RegisterForSingleUpdate(ScanInterval)
EndEvent
/;

Event OnInit()
    Debug.trace("[MiniMolest Approach] OnInit")
    if IsRunning()
        ; OnInit is called twice, so defer initialization
        RegisterForSingleUpdate(8)
    endif
EndEvent

Function NotifyConfigChanged()
	Debug.Trace("[MiniMolest Approach] Config changed")
	ConfigChanged = true
EndFunction

Event OnUpdate()
	if (!IsRunning() || (!Initialized && !ConfigChanged))
		RegisterForSingleUpdate(0.5)
		return
	endif

	if (!Initialized && ConfigChanged)
		Debug.Trace("[MiniMolest Approach] OnUpdate: First time initialization")
		Initialized = true
		ConfigChanged = false
		ReadConfig()
		; First time initialization
		CooldownActors = new Actor[128]
		CooldownScans = new Int[128]
		; Start periodic scan
		RegisterForSingleUpdate(ScanInterval)
		return
	endif

	; I think, this is a safe place to change the configuration
	if ConfigChanged
		ConfigChanged = false
		ReadConfig()
	endif

	; Periodic scan
	ScanCount += 1
	Debug.Trace("[MiniMolest Approach] OnUpdate, ScanCount = " + ScanCount)
	ScanNearbyActors()
	RegisterForSingleUpdate(ScanInterval)
EndEvent


Bool Function IsCandidate(Actor candidate)
	if candidate == None || candidate == PlayerRef
		return False
	endif

	if candidate.IsDead() || candidate.IsInCombat() || candidate.IsPlayerTeammate()
		return False
	endif

	if PlayerRef.GetDistance(candidate) > DetectionRadius
		return False
	endif

	if candidate.GetRace() == None || !candidate.GetRace().IsPlayable()
		return False
	endif

	if candidate.GetActorBase().GetRace().IsChildRace()
		return False
	endif

	return True
EndFunction

Bool Function CanGreet(Actor aTarget)
	if aTarget == None || !aTarget.IsAIEnabled()
		return False
	endif

	if (ScanCount - LastGreetScan) * ScanInterval < GlobalGreetInterval
		return False
	endif

	Int i = 0
	while i < MaxCoolDowns
		if CooldownActors[i] == aTarget
			bool result = (ScanCount - CooldownScans[i]) * ScanInterval >= NpcGreetCooldown
			Debug.Trace("[MiniMolest Approach] CanGreet: result = " + result)
			if result
				CooldownActors[i] = None
				CooldownScans[i] = 0
                Debug.Trace("[MiniMolest Approach] CanGreet: " + aTarget + " cooldown elapsed: " + aTarget)
			endif		
			return result
		endif
		i += 1
	endwhile

	Debug.Trace("[MiniMolest Approach] CanGreet: " + aTarget + " is eligible for greeting.")
	return True
EndFunction

Function ScanNearbyActors()
	; Test
	;SlaveTatsNG.find_molester_group(1, 0, 1000)

	if PlayerRef == None || !PlayerRef.IsAIEnabled() || PlayerRef.IsInCombat()
		return
	endif

	ObjectReference[] nearbyObjects = PO3_SKSEFunctions.FindAllReferencesOfFormType(PlayerRef, 43, DetectionRadius)
	Int referenceCount = nearbyObjects.Length

	Actor[] candidates = new Actor[128]
    Int candidateCount = 0
	Int index = 0

	while index < referenceCount && candidateCount < MaxCandidates
		Actor candidate = nearbyObjects[index] as Actor

		if IsCandidate(candidate)
			candidates[candidateCount] = candidate
			candidateCount += 1
			Debug.Trace("[MiniMolest Approach] Candidate " + candidateCount + ": " + candidate.GetDisplayName()\
             + ", distance=" + PlayerRef.GetDistance(candidate))
		endif

		index += 1
	endwhile

	if candidateCount == 0
		return
	endif

	Debug.Trace("[MiniMolest Approach] candidates = " + candidates)
	Actor target = candidates[Utility.RandomInt(0, candidateCount - 1)]
	Debug.Trace("[MiniMolest Approach] target = " + target)
	if CanGreet(target) && Utility.RandomFloat(0.0, 1.0) < GreetChance
		if MiniMolestMain.GreetActor(target)
			; put target on cooldown
			CooldownActors[CooldownIndex] = target
			CooldownScans[CooldownIndex] = ScanCount
			CooldownIndex = (CooldownIndex + 1) % MaxCooldowns
			LastGreetScan = ScanCount
		else
			Debug.Trace("[MiniMolest Approach] Scan complete. candidates=" + candidateCount + ", unable to greet.")
		endif
	else
		Debug.Trace("[MiniMolest Approach] Scan complete. candidates=" + candidateCount + ", no greet.")
	endif
EndFunction

