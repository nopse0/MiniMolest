Scriptname MiniMolestMain_Script extends Quest

Actor Property PlayerRef Auto
SexLabFramework Property SexLabFramework_Script Auto

float SceneHandle = -1.0
Actor[] SceneActors
Actor[] SceneSubmissiveActors

Function RegisterModEventHooks()
	Debug.Trace("[MiniMolest Main] Registering mod event hooks.")
	RegisterForModEvent("MiniUtilStartScene", "StartScene")
EndFunction

bool Function GetSceneParameters(float aHandle) native

Event StartScene(string eventName, string hookPostfix, float numArg, Form sender)
    Debug.Trace("[MiniMolest Main] StartScene event received. Handle: " + numArg)
    if SceneHandle == numArg
        Debug.Trace("[MiniMolest Main] Scene already running, ignoring StartScene event.")
        return
    endif
    SceneHandle = numArg
    if GetSceneParameters(SceneHandle)
        Debug.Trace("[MiniMolest Main] GetSceneParameters: SceneActors=" + SceneActors + \
        ", SceneSubmissiveActors=" + SceneSubmissiveActors)
        ; Utility.Wait(0.5) ; Wait a moment to ensure all actors are ready
        SexLabThread thread = SexLabFramework_Script.StartSceneA(SceneActors, "!Aggressive", SceneSubmissiveActors, asHook = hookPostfix)
        if (thread != None)
            MiniUtil_Script.SetSceneThreadID(SceneHandle, thread.GetThreadID())
        else
            MiniUtil_Script.SetSceneError(SceneHandle)
        endif
    else
         Debug.Trace("[MiniMolest Main] GetSceneParameters failed!")
    endif   
EndEvent
