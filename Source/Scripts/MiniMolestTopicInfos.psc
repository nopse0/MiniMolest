Scriptname MiniMolestTopicInfos extends TopicInfo

Function Fragment_0(ObjectReference akSpeakerRef)
	Actor speaker = akSpeakerRef as Actor
	if speaker != None
		(GetOwningQuest() as MiniMolestMain_Script).OnDialogueEnd(speaker)
	endif
EndFunction
