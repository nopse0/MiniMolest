Scriptname MiniMolestStruggle_Script extends Quest

; -- Internal Variables --
Int[] KeySequence
Int KeyPressNum = 0
Int CurrentMashes = 0
Int LastKeyPressed = 0 ; 0 = none, 1 = KeyA, 2 = KeyB
Bool IsMinigameActive = false
;Float TimeElapsed = 0.0
Float StartTime = 0.0
Int MeterID = -1       ; Stores the ID of the SkyUI meter widget
bool Freeze = false

; Hintergrund (Dunkelgrau: 40, 40, 40) und Rahmen (Schwarz: 0, 0, 0) bleiben immer gleich
Int bgR = 40
Int bgG = 40
Int bgB = 40
Int borderR = 0
Int borderG = 0
Int borderB = 0

Int PenaltyAmount = 2
Int TargetMashes = 20
Float TimeLimit = 5.0
Float UpdateInterval = 0.5

; Default DXScanCodes: 30 is 'A', 32 is 'D'
Int MashKeyA = 30
Int MashKeyB = 32
Int MaxKeyRepeat = 4

iwant_widgets Property iWantWidgets_Script Auto
MiniMolestConfig_Script Property MiniMolestConfig Auto
MiniMolestMain_Script Property MiniMolestMain Auto
Bool ConfigChanged = true

Function ReadConfig()
    Debug.Trace("[MiniMolest Struggle] ReadConfig")

    bgR = MiniMolestConfig.iStruggleBar_bgR
    bgG = MiniMolestConfig.iStruggleBar_bgG
    bgB = MiniMolestConfig.iStruggleBar_bgB
    borderR = MiniMolestConfig.iStruggleBar_borderR
    borderG = MiniMolestConfig.iStruggleBar_borderG
    borderB = MiniMolestConfig.iStruggleBar_borderB

    PenaltyAmount = MiniMolestConfig.iStruggleBar_penaltyAmount
    TargetMashes = MiniMolestConfig.iStruggleBar_targetMashes
    TimeLimit = MiniMolestConfig.fStruggleBar_timeLimit
    UpdateInterval = MiniMolestConfig.fStruggleBar_updateInterval
    MashKeyA = MiniMolestConfig.iStruggleBar_mashKeyA
    MashKeyB = MiniMolestConfig.iStruggleBar_mashKeyB
    MaxKeyRepeat = MiniMolestConfig.iStruggleBar_maxKeyRepeat
EndFunction

Function NotifyConfigChanged()
	Debug.Trace("[MiniMolest Struggle] Config changed")
    ConfigChanged = true
EndFunction

Function GenerateKeySequence()
    KeySequence = new int[128] ; Maximalgröße ausnutzen
    
    int i = 0
    int nextKey
    int choice = Utility.RandomInt(0, 1) ; Erste Taste bestimmen
    if (choice)
        nextKey = MashKeyB ; KeyB
    else
        nextKey = MashKeyA ; KeyA
    endif

    while i < KeySequence.Length
        ; Bestimme, wie oft DIESE Taste hintereinander gedrückt werden muss (z.B. 1 bis 4 Mal)
        ; Höhere Zahlen machen längere Serien wahrscheinlicher
        int sequenceLength = Utility.RandomInt(1, MaxKeyRepeat) 
        
        int count = 0
        while count < sequenceLength && i < KeySequence.Length
            KeySequence[i] = nextKey
            i += 1
            count += 1
        endWhile
        
        ; Nach der Serie wird die Taste zwingend gewechselt (0 wird 1, 1 wird 0)
        if nextKey == MashKeyA
            nextKey = MashKeyB
        else
            nextKey = MashKeyA
        endif
    endWhile
EndFunction


; -- Start the Minigame --
Function StartBreakFree(bool abFreeze)
    if ConfigChanged
        ConfigChanged = false
        ReadConfig()
    endif
    
    GenerateKeySequence()
    KeyPressNum = 0

    Freeze = abFreeze
    IsMinigameActive = true
    CurrentMashes = 0
    LastKeyPressed = 0 
    ;TimeElapsed = 0.0
 
    StartTime = Utility.GetCurrentRealTime()

    ; 1. Freeze the player
    if Freeze
        Game.SetPlayerAIDriven(true)
    endif
    Debug.Notification("ALTERNATE A AND D TO BREAK FREE!")
    
    ; 2. Initialize SkyUI Progress Bar
    InitializeProgressBar()
    
    ; 3. Register inputs
    RegisterForKey(MashKeyA)
    RegisterForKey(MashKeyB)
    
    ; 4. Start failure timer
    ; RegisterForSingleUpdate(UpdateInterval) 
EndFunction

; -- Funktion für die Farbanpassung --

Function UpdateMeterColor(Float Ratio)
    If MeterID == -1 || !iWantWidgets_Script
        Return
    EndIf

    If Ratio < 0.5
        ; 0% - 50% der Zeit: Gesundes Grün (34, 255, 34)
        iWantWidgets_Script.setMeterRGB(MeterID, 34, 255, 34, bgR, bgG, bgB, borderR, borderG, borderB)
    ElseIf Ratio >= 0.5 && Ratio < 0.8
        ; 50% - 80% der Zeit: Warnendes Orange (255, 153, 0)
        iWantWidgets_Script.setMeterRGB(MeterID, 255, 153, 0, bgR, bgG, bgB, borderR, borderG, borderB)
        Game.ShakeController(0.1, 0.1, 0.2)
    Else
        ; Ab 80% der Zeit: Kritisches Rot (255, 17, 17)
        iWantWidgets_Script.setMeterRGB(MeterID, 255, 17, 17, bgR, bgG, bgB, borderR, borderG, borderB)
    EndIf
EndFunction

; -- Handle Alternating Button Mashing --
Event OnKeyDown(Int KeyCode)
    If !IsMinigameActive
        Return
    EndIf

    Float CurrentTime = Utility.GetCurrentRealTime()
    Float TimeElapsed = CurrentTime - StartTime

    ; If TimeElapsed >= TimeLimit
    ;    ResolveMinigame(false) ; Timeout / Fehlschlag direkt im Key-Handler!
    ;    Return
    ; EndIf

    Float TimeRatio = TimeElapsed / TimeLimit
    UpdateMeterColor(TimeRatio)

    If KeyCode == KeySequence[KeyPressNum]
        CurrentMashes += 1
        ;LastKeyPressed = 1
        UpdateProgressBar(CurrentMashes, TargetMashes)
        CheckSuccess()
    Else
        ; PENALTY
        ApplyPenalty()
    EndIf
    KeyPressNum = (KeyPressNum + 1) % 128

EndEvent

; -- Handle Penalties --
Function ApplyPenalty()
    CurrentMashes -= PenaltyAmount
    If CurrentMashes < 0
        CurrentMashes = 0
    EndIf
    
    ; Visual feedback for making a mistake
    Debug.Notification("Fumbled! - Don't panic!")
    Game.ShakeCamera(Game.GetPlayer(), 0.3, 0.2) ; Quick camera jar
    
    UpdateProgressBar(CurrentMashes, TargetMashes)
EndFunction


Function InitializeProgressBar()
    If iWantWidgets_Script == None
        iWantWidgets_Script = Game.GetFormFromFile(0x000800, "iWant Widgets.esl") as iwant_widgets
    EndIf

    If iWantWidgets_Script
        MeterID = iWantWidgets_Script.loadMeter()

        If MeterID != -1
            iWantWidgets_Script.setVisible(MeterID, 1)
            
            ; Behalte die Größe bei, die dir gefällt (z.B. 150, 500)
            iWantWidgets_Script.setSize(MeterID, 75, 800) 
            
            ; 640 hält es exakt mittig, 580 schiebt es perfekt ins untere Drittel
            iWantWidgets_Script.setPos(MeterID, 640, 580)
            
            iWantWidgets_Script.setMeterPercent(MeterID, 0) 
            iWantWidgets_Script.setMeterRGB(MeterID, 34, 255, 34, 40, 40, 40, 0, 0, 0)
            iWantWidgets_Script.sendToFront(MeterID)
        EndIf
    EndIf
EndFunction

; Wird aufgerufen, wenn sich der Mashing-Fortschritt ändert
Function UpdateProgressBar(Float aCurrentMashes, Float aTargetMashes)
    if MeterID != -1 && iWantWidgets_Script
        Int Percent = ((aCurrentMashes / aTargetMashes) * 100) as Int
        iWantWidgets_Script.setMeterPercent(MeterID, Percent)
    endif
EndFunction

Function RemoveProgressBar()
    if MeterID != -1 && iWantWidgets_Script
        iWantWidgets_Script.setVisible(MeterID, 0)
        iWantWidgets_Script.destroy(MeterID)
        MeterID = -1
    endif
EndFunction


; -- Helper to check win condition --
Function CheckSuccess()
    If CurrentMashes >= TargetMashes
        ResolveMinigame(true)
        MiniMolestMain.OnBreakFree()
    EndIf
EndFunction

; -- Handle Time Limits / Failure --
;Event OnTimer(Int TimerId)
;    If TimerId == 1 && IsMinigameActive
;        ResolveMinigame(false)
;    EndIf
;EndEvent

Function TriggerTimeout()
    If IsMinigameActive ; <- Das hier ist deine Absicherung!
        ResolveMinigame(false)
    EndIf
EndFunction

; -- Clean up --
Function ResolveMinigame(Bool WasSuccessful)
    IsMinigameActive = false
    UnregisterForKey(MashKeyA)
    UnregisterForKey(MashKeyB)
    
    RemoveProgressBar()
    if Freeze
        Game.SetPlayerAIDriven(false)
    endif

    ; If WasSuccessful
    ;    Debug.Notification("You broke free!")
    ; Else
    ;    Debug.Notification("You fainted from exhaustion!")
    ;    Game.GetPlayer().DamageActorValue("Stamina", 100.0) ; Drain resources on fail
    ; EndIf
EndFunction
