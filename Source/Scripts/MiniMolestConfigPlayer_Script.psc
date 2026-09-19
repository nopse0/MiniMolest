Scriptname MiniMolestConfigPlayer_Script extends ReferenceAlias  

Event OnInit()
	Debug.Trace("[MiniMolest Config] Player alias script initialized.")
EndEvent

Event OnPlayerLoadGame()
    Debug.Trace("[MiniMolest Config] OnPlayerLoadGame.")
    (GetOwningQuest() as MiniMolestConfig_Script).NotifyPlayerLoadGame()
EndEvent