Scriptname BRFFActorEffectScript extends ActiveMagicEffect

BRFFController Property Controller Auto

Event OnEffectStart(Actor akTarget, Actor akCaster)
EndEvent

Event OnEffectFinish(Actor akTarget, Actor akCaster)
EndEvent

Event OnHit(ObjectReference akAggressor, Form akSource, Projectile akProjectile, bool abPowerAttack, bool abSneakAttack, bool abBashAttack, bool abHitBlocked)
    Controller.ActorHit(GetTargetActor(), akAggressor as Actor)
EndEvent
