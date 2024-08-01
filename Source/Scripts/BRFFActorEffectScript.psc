Scriptname BRFFActorEffectScript extends ActiveMagicEffect

BRFFController Property Controller Auto

Int End = 0

Event OnEffectStart(Actor akTarget, Actor akCaster)
    While End == 0
        Controller.HandleActor(akTarget)
    EndWhile
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
    End = 1
EndEvent
