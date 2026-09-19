Scriptname MiniMolestPlayer_Script extends ReferenceAlias  

Event OnInit()
	Debug.Trace("[MiniMolest Player] Player alias script initialized.")
    (GetOwningQuest() as MiniMolestMain_Script).RegisterModEventHooks()
EndEvent

Event OnPlayerLoadGame()
    Debug.Trace("[MiniMolest Player] OnPlayerLoadGame.")
    (GetOwningQuest() as MiniMolestMain_Script).RegisterModEventHooks()
EndEvent

