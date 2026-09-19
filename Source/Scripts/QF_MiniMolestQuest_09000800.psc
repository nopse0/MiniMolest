;BEGIN FRAGMENT CODE - Do not edit anything between this and the end comment
;NEXT FRAGMENT INDEX 1
Scriptname QF_MiniMolestQuest_09000800 Extends Quest Hidden

;BEGIN ALIAS PROPERTY HarassingNPC
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_HarassingNPC Auto
;END ALIAS PROPERTY

;BEGIN ALIAS PROPERTY PlayerAlias
;ALIAS PROPERTY TYPE ReferenceAlias
ReferenceAlias Property Alias_PlayerAlias Auto
;END ALIAS PROPERTY

MiniMolestMain_Script Property kmyQuest Auto

;BEGIN FRAGMENT Fragment_0
Function Fragment_0()
;BEGIN CODE
kmyQuest.TestMiniGame()
;END CODE
EndFunction
;END FRAGMENT

;END FRAGMENT CODE - Do not edit anything between this and the begin comment
