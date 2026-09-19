Scriptname MiniMolestMain_Script extends Quest

Actor Property PlayerRef Auto
SexLabFramework Property SexLabFramework_Script Auto

ReferenceAlias Property HarassingNPC Auto

GlobalVariable Property MiniMolestForceGreetType Auto 
GlobalVariable Property MiniMolestForceGreetOutcome Auto 

ObjectReference Property MiniMolestAnimMarker Auto
Package         Property MiniMolestDoNothingPackage Auto

MiniMolestStruggle_Script Property MiniMolestStruggle Auto
MiniMolestConfig_Script Property MiniMolestConfig Auto

Int LastConfigGeneration = 0
Float ForceGreetTimeout = 0.0
Float StruggleTimeout = 0.0

String MiniMolestState = ""

Bool Initialized = false
Bool ConfigChanged = false
Bool IsBusy = false

Function ReadConfig()
	Debug.Trace("[MiniMolest Main] ReadConfig")
	ForceGreetTimeout = MiniMolestConfig.fApproach_greetTimeout
	StruggleTimeout = MiniMolestConfig.fStruggleBar_timeLimit
	Debug.Trace("[MiniMolest Main] ReadConfig: ForceGreetTimeout=" + ForceGreetTimeout + ", StruggleTimeout=" + StruggleTimeout)
EndFunction

Event OnInit()
	Debug.trace("[MiniMolest Main] OnInit")
	if IsRunning()
		; OnInit is called twice, so defer initialization
		RegisterForSingleUpdate(8)
	endif
EndEvent

Function NotifyConfigChanged()
	Debug.Trace("[MiniMolest Main] Config changed")
	if !Initialized
		ConfigChanged = true
		return
	endif
	if !IsBusy
		Debug.Trace("[MiniMolest Main] Config changed, re-reading config...")
		ReadConfig()
	endif
EndFunction

Function EndBusy()
	MiniMolestState = ""
	MiniMolestForceGreetType.SetValue(0)
	MiniMolestForceGreetOutcome.SetValue(0)
	HarassingNPC.Clear()
	if ConfigChanged
		ConfigChanged = false
		ReadConfig()
	endif
	IsBusy = false
EndFunction

Event OnUpdate()
	if (!IsRunning() || (!Initialized && !ConfigChanged))
		RegisterForSingleUpdate(0.5)
		return
	endif

	if (!Initialized && ConfigChanged)
		Debug.Trace("[MiniMolest Main] OnUpdate: First time initialization")
		Initialized = true
		ConfigChanged = false
		ReadConfig()
		return
	endif

	if IsBusy
		if MiniMolestState == "ForceGreet"
			Debug.Trace("[MiniMolest Main] ForceGreet timeout")
			EndBusy()
		elseif MiniMolestState == "Struggle"   ; Struggle Timeout
			Debug.Trace("[MiniMolest Main] Struggle timeout")
			MiniMolestStruggle.ResolveMinigame(false)
			Debug.Trace("[MiniMolest Main] Timeout, stopping BackHug, actor = " + HarassingNPC.GetActorReference())
			StopBackHug(HarassingNPC.GetActorReference())

			Actor[] positions = SexLabUtil.MakeActorArray(PlayerRef, HarassingNPC.GetActorReference())
			SexLabThread thread = SexLabFramework_Script.StartScene(positions, "!Aggressive", PlayerRef, asHook = "MiniMolestSLHook")
			if thread == None
				EndBusy()
			endif			
		endif
	endif
EndEvent

Bool Function GreetActor(Actor aTarget)
	if (!Initialized || IsBusy)
		return false
	endif

	IsBusy = true      ; maybe a race condition here, so read config afterwards
	if ConfigChanged    
		ConfigChanged = false
		ReadConfig()
	endif

	MiniMolestState = "ForceGreet"
	MiniMolestForceGreetType.SetValue(1)
	MiniMolestForceGreetOutcome.SetValue(1)

	Debug.Trace("[MiniMolest Main] Force-greeting " + aTarget.GetDisplayName())
	HarassingNPC.ForceRefTo(aTarget as ObjectReference)
	Actor HarrassingActor = HarassingNPC.GetActorReference()
	HarrassingActor.EvaluatePackage()

	RegisterForSingleUpdate(ForceGreetTimeout)
	return true
EndFunction

Function RegisterModEventHooks()
	Debug.Trace("[MiniMolest Main] Registering mod event hooks.")
	RegisterForModEvent("HookAnimationEnd_MiniMolestSLHook", "OnSexLabAnimationEnd")
EndFunction

Event OnSexLabAnimationEnd(int tid, bool HasPlayer)
	Debug.Trace("[MiniMolest Main] HookAnimationEnd_MiniMolestSLHook: tid=" + tid + ", hasPlayer=" + HasPlayer)
	EndBusy()
EndEvent

Function OnDialogueEnd(Actor speaker)
	UnregisterForUpdate()  ; remove ForceGreetTimeout
	MiniMolestForceGreetType.SetValue(0)
	MiniMolestForceGreetOutcome.SetValue(0)

	Debug.Trace("[MiniMolest Main] Dialogue ended with " + speaker.GetDisplayName() + ". Starting struggle minigame...")
	MiniMolestState = "Struggle"
	StartBackHug(speaker)
	MiniMolestStruggle.StartBreakFree(false)
	
	RegisterForSingleUpdate(StruggleTimeout)
EndFunction

Function OnBreakFree()
	StopBackHug(HarassingNPC.GetActorReference())
	MiniMolestState = ""
	MiniMolestForceGreetType.SetValue(0)
	MiniMolestForceGreetOutcome.SetValue(0)
	HarassingNPC.Clear()
	UnregisterForUpdate()
	if ConfigChanged
		ConfigChanged = false
		ReadConfig()
	endif
	IsBusy = false
	Debug.Trace("[MiniMolest Main] OnBreakFree called, state cleared, alias cleared.")
EndFunction

;###################################################################################

; Package          Property DoNothingPkg   Auto  ; a "do nothing" AI package, like SLAppDoNothing

Function StartBackHug(Actor akactor)   ; akactor = the MALE npc
    ActorUtil.AddPackageOverride(akactor, MiniMolestDoNothingPackage, 100, 1)
    akactor.EvaluatePackage()
    akactor.SetRestrained(True)
    akactor.SetDontMove(True)
    Game.SetPlayerAIDriven(true)
    if Game.GetCameraState() == 0
        Game.ForceThirdPerson()
    endIf

    Utility.Wait(0.5)
    ; BackHug offsets: angle=0, Xaxis=0, Yaxis=-50 (npc ends up behind player)
    int angle = 0 
	int Xaxis = 0
	int Yaxis = -50
    Float AngleZ = PlayerRef.GetAngleZ()
    Float rMoveX = (Math.sin(AngleZ) * Yaxis) + (Math.cos(AngleZ) * Xaxis)
    Float rMoveY = (Math.cos(AngleZ) * Yaxis) - (Math.sin(AngleZ) * Xaxis)

    MiniMolestAnimMarker.MoveTo(PlayerRef, rMoveX, rMoveY)
    Utility.Wait(0.5)
    akactor.MoveTo(MiniMolestAnimMarker)
    akactor.setangle(0, 0, AngleZ + angle)
    Utility.Wait(0.5)

    ; fire BOTH halves at once — male clip on npc, female clip on player
    Debug.SendAnimationEvent(akactor, "BaboBackHugStartM")
    Debug.SendAnimationEvent(PlayerRef, "BaboBackHugStartF")
EndFunction

Function StopBackHug(Actor akactor)
    PlayerRef.SetVehicle(None)
    akactor.SetVehicle(None)
    Game.EnablePlayerControls()
    Game.SetPlayerAIDriven(false)
    PlayerRef.SetRestrained(False)
    PlayerRef.SetDontMove(False)
    akactor.SetRestrained(False)
    akactor.SetDontMove(False)
    ActorUtil.RemovePackageOverride(akactor, MiniMolestDoNothingPackage)
    ; this is what pulls both skeletons OUT of the paired pose:
    Debug.SendAnimationEvent(akactor, "IdleForceDefaultState")
    Debug.SendAnimationEvent(PlayerRef, "IdleForceDefaultState")
EndFunction


Function TestMinigame()
    Debug.Trace("[MiniMolest Main] Minigame-Test...")
    MiniMolestStruggle.StartBreakFree(true)
EndFunction

Event OnStageSet(int aStageID, int aItemID)
    if aStageID == 999
        Debug.Trace("[MiniMolest Main] Manuelle Test-Stage 999 gesetzt. Starte Minigame...")
        MiniMolestStruggle.StartBreakFree(true)
    endif
EndEvent
