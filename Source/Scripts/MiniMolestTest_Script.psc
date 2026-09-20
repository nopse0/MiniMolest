Scriptname MiniMolestTest_Script extends Quest

; Bind to the stats quest (QF_MiniMolestStats) in CK
MiniMolestStats_Script Property MiniMolestStats Auto

Function Test()
    Debug.Trace("[MiniMolest Test] Test() called")
    if MiniMolestStats != None
        MiniMolestStats.TestDump()
    endif
EndFunction
