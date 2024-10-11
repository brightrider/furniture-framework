Scriptname BRFFController extends Quest

Import NetImmerse

Spell Property ActorSpell Auto
Armor Property ExecutionerRing Auto
Package Property DoNothing Auto
Faction Property FFFaction Auto

Int MAPPING
Int ACTORS

ObjectReference selectedFurniture

Event OnInit()
    Int mainEntry = JMap.object()
    ACTORS = JFormMap.object()
    JMap.setObj(mainEntry, "actors", ACTORS)
    JDB.setObj("BRFF", mainEntry)

    Init()

    RegisterForKey(0x10)

    RegisterForSingleUpdate(3)
EndEvent

Event OnKeyDown(Int keyCode)
    If ! Input.IsKeyPressed(0x38)
        Return
    EndIf

    ObjectReference selectedRef = Game.GetCurrentCrosshairRef()

    ; TODO: Check if selectedRef is in use by this mod.
    If selectedRef.GetBaseObject() as Furniture && ! selectedRef.IsFurnitureInUse()
        selectedFurniture = selectedRef
        Debug.Notification("Select: " + selectedFurniture.GetBaseObject().GetName())
        Return
    EndIf

    If JFormMap.hasKey(ACTORS, selectedRef)
        Remove(selectedRef as Actor)
        Debug.Notification("Remove: " + selectedRef.GetBaseObject().GetName())
        Return
    EndIf

    If selectedFurniture && (selectedRef as Actor)
        Add(selectedRef as Actor, selectedFurniture)
        selectedFurniture = None
        Debug.Notification("Add: " + selectedRef.GetBaseObject().GetName())
        Return
    EndIf
EndEvent

Event OnUpdate()
    Actor k = JFormMap.nextKey(ACTORS) as Actor
    While k
        ObjectReference furn = JMap.getForm(JFormMap.getObj(ACTORS, k), "furniture") as ObjectReference
        If furn.IsDeleted()
            furn = furn.PlaceAtMe(furn.GetBaseObject())
            JMap.setForm(JFormMap.getObj(ACTORS, k), "furniture", furn)
        EndIf
        If (Game.GetPlayer().GetDistance(furn) < 102400) || Game.GetPlayer().HasLOS(furn)
            ; TODO: Workaround, not good.
            If k.GetDistance(furn) > 1000000
                k.MoveTo(furn)
            EndIf
            If ! k.HasSpell(ActorSpell)
                k.AddSpell(ActorSpell, abVerbose=False)
            EndIf
        Else
            If k.HasSpell(ActorSpell)
                k.RemoveSpell(ActorSpell)
            EndIf
        EndIf

        k = JFormMap.nextKey(ACTORS, k) as Actor
    EndWhile

    RegisterForSingleUpdate(1)
EndEvent

Function Add(Actor ref, ObjectReference furn)
    Int record = JMap.object()
    JMap.setInt(record, "new", 1)
    JMap.setInt(record, "toRemove", 0)
    JMap.setForm(record, "furniture", furn)
    JMap.setForm(record, "crimeFaction", ref.GetCrimeFaction())
    JMap.setFlt(record, "health", ref.GetAV("Health"))
    JMap.setFlt(record, "aggression", ref.GetAV("Aggression"))
    JMap.setFlt(record, "confidence", ref.GetAV("Confidence"))
    JMap.setFlt(record, "assistance", ref.GetAV("Assistance"))
    JMap.setInt(record, "ignoreFriendlyHits", ref.IsIgnoringFriendlyHits() as Int)
    JMap.setInt(record, "collisionLayer", BRFFSKSELibrary.GetCollisionLayer(furn))
    JFormMap.setObj(ACTORS, ref, record)

    Int handle = ModEvent.Create("BRFF_Add")
    If handle
        ModEvent.PushForm(handle, ref)
        ModEvent.PushForm(handle, furn)
        ModEvent.Send(handle)
    EndIf
EndFunction

Function Remove(Actor ref)
    Int record = JFormMap.getObj(ACTORS, ref)

    Int handle = ModEvent.Create("BRFF_Remove")
    If handle
        ModEvent.PushForm(handle, ref)
        ModEvent.PushForm(handle, JMap.getForm(record, "furniture"))
        ModEvent.Send(handle)
    EndIf

    JMap.setInt(record, "toRemove", 1)
EndFunction

Function Kill(Actor ref)
    Int record = JFormMap.getObj(ACTORS, ref)
    ObjectReference dummyL = JMap.getForm(record, "dummyL") as ObjectReference
    ObjectReference dummyR = JMap.getForm(record, "dummyR") as ObjectReference
    Form dummy = Game.GetForm(0xD19BA)
    If ! dummyL
        Float lHandPosX = GetNodeWorldPositionX(ref, "NPC L Hand [LHnd]", firstPerson=False)
        Float lHandPosY = GetNodeWorldPositionY(ref, "NPC L Hand [LHnd]", firstPerson=False)
        Float lHandPosZ = GetNodeWorldPositionZ(ref, "NPC L Hand [LHnd]", firstPerson=False)
        dummyL = ref.PlaceAtMe(dummy, 1, abForcePersist=True)
        JMap.setForm(record, "dummyL", dummyL)
        dummyL.SetPosition(lHandPosX, lHandPosY, lHandPosZ)
    EndIf
    If ! dummyR
        Float rHandPosX = GetNodeWorldPositionX(ref, "NPC R Hand [RHnd]", firstPerson=False)
        Float rHandPosY = GetNodeWorldPositionY(ref, "NPC R Hand [RHnd]", firstPerson=False)
        Float rHandPosZ = GetNodeWorldPositionZ(ref, "NPC R Hand [RHnd]", firstPerson=False)
        dummyR = ref.PlaceAtMe(dummy, 1, abForcePersist=True)
        JMap.setForm(record, "dummyR", dummyR)
        dummyR.SetPosition(rHandPosX, rHandPosY, rHandPosZ)
    EndIf
    ref.Kill()
    SetConstraints(ref)
EndFunction

Function RemoveImpl(Actor ref)
    Int record = JFormMap.getObj(ACTORS, ref)
    ActorUtil.RemovePackageOverride(ref, DoNothing)
    ref.SetCrimeFaction(JMap.getForm(record, "crimeFaction") as Faction)
    ref.RemoveFromFaction(FFFaction)
    ref.SetAV("Aggression", JMap.getFlt(record, "aggression"))
    ref.SetAV("Confidence", JMap.getFlt(record, "confidence"))
    ref.SetAV("Assistance", JMap.getFlt(record, "assistance"))
    ref.IgnoreFriendlyHits(JMap.getInt(record, "ignoreFriendlyHits") as Bool)
    ref.SetRestrained(False)
    ref.SetDontMove(False)
    ObjectReference dummyL = JMap.getForm(record, "dummyL") as ObjectReference
    ObjectReference dummyR = JMap.getForm(record, "dummyR") as ObjectReference
    Game.RemoveHavokConstraints(ref, "NPC L Hand [LHnd]", dummyL, "AttachDummy")
    Game.RemoveHavokConstraints(ref, "NPC R Hand [RHnd]", dummyR, "AttachDummy")
    dummyL.Delete()
    dummyR.Delete()
    If ! ref.IsDead()
        ref.ForceAV("Health", JMap.getFlt(record, "health"))
        ref.EvaluatePackage()
        Debug.SendAnimationEvent(ref, "IdleForceDefaultState")
    EndIf
    ObjectReference furn = JMap.getForm(record, "furniture") as ObjectReference
    PO3_SKSEFunctions.SetCollisionLayer(furn, "", JMap.getInt(record, "collisionLayer"))
    furn.BlockActivation(False)
    JFormMap.removeKey(ACTORS, ref)
EndFunction

Function ConfigureActor(Actor ref, bool shouldAddPackage=True)
    If ref.IsDead()
        SetConstraints(ref)
        ref.IgnoreFriendlyHits(False)
        ref.SetRestrained(False)
        ref.SetDontMove(False)
        Return
    EndIf
    If shouldAddPackage
        ActorUtil.AddPackageOverride(ref, DoNothing, 100)
        ref.EvaluatePackage()
    EndIf
    ref.SetCrimeFaction(None)
    ref.AddToFaction(FFFaction)
    ref.ForceAV("Health", 1000000000)
    ref.SetAV("Aggression", 0)
    ref.SetAV("Confidence", 4)
    ref.SetAV("Assistance", 0)
    ref.IgnoreFriendlyHits()
    ref.StopCombatAlarm()
    ref.SetAlert(False)
    ref.SetRestrained()
    ref.SetDontMove()
    ; ref.SetUnconscious()
    ; ref.Reset()
EndFunction

Function ConfigureFurniture(ObjectReference furn)
    If furn.GetAngleX() != 0 || furn.GetAngleY() != 0
        furn.SetAngle(0, 0, Mod(furn.GetAngleZ(), 360))
    EndIf
    If BRFFSKSELibrary.GetCollisionLayer(furn) != 15
        PO3_SKSEFunctions.SetCollisionLayer(furn, "", 15)
    EndIf
    furn.BlockActivation()
EndFunction

Function Init()
    JValue.release(MAPPING)
    MAPPING = JMap.object()
    Int vals = JMap.allValues(JValue.readFromFile("Data/brff_mapping.json"))
    Int i = 0
    While i < JArray.count(vals)
        JMap.addPairs(MAPPING, JArray.getObj(vals, i), overrideDuplicates=True)

        i += 1
    EndWhile
    JValue.retain(MAPPING)
EndFunction

Function HandleActor(Actor ref)
    Int record = JFormMap.getObj(ACTORS, ref)

    If JMap.getInt(record, "toRemove") == 1
        RemoveImpl(ref)
    EndIf

    If JMap.getInt(record, "toRemove", 100) != 0
        ref.RemoveSpell(ActorSpell)
        Return
    EndIf

    ObjectReference furn = JMap.getForm(record, "furniture") as ObjectReference
    If JMap.getInt(record, "new")
        JMap.setInt(record, "new", 0)
        ConfigureFurniture(furn)
        ConfigureActor(ref)
        TryPosition(ref, furn)
    Else
        If ! TryPosition(ref, furn)
            ConfigureFurniture(furn)
            ConfigureActor(ref, False)
        EndIf
    EndIf
    If ! ref.IsDead()
        Debug.SendAnimationEvent(ref, JMap.getStr(MAPPING, PO3_SKSEFunctions.GetFormEditorID(furn.GetBaseObject())))
    EndIf
    Utility.Wait(1)
EndFunction

Function HandleActorHit(Actor ref, Actor attacker)
    If attacker.IsEquipped(ExecutionerRing)
        Kill(ref)
    EndIf
EndFunction

Function SetConstraints(Actor ref)
    Int record = JFormMap.getObj(ACTORS, ref)
    ObjectReference dummyL = JMap.getForm(record, "dummyL") as ObjectReference
    ObjectReference dummyR = JMap.getForm(record, "dummyR") as ObjectReference
    If dummyL && dummyR
        Game.AddHavokBallAndSocketConstraint(ref, "NPC L Hand [LHnd]", dummyL, "AttachDummy")
        Game.AddHavokBallAndSocketConstraint(ref, "NPC R Hand [RHnd]", dummyR, "AttachDummy")
        ref.ApplyHavokImpulse(1, 1, 1, 1)
    EndIf
EndFunction

Bool Function TryPosition(Actor ref, ObjectReference furn)
    If ref.IsDead()
        Return False
    EndIf

    Int c = 0
    While c < 3
        Int aX = Math.Floor(ref.X)
        Int aY = Math.Floor(ref.Y)
        Int aZ = Math.Floor(ref.Z)
        Int aR = Math.Floor(ref.GetAngleZ())
        Int fX = Math.Floor(furn.X)
        Int fY = Math.Floor(furn.Y)
        Int fZ = Math.Floor(furn.Z)
        Int fR = Math.Floor(furn.GetAngleZ())
        If aX == fX && aY == fY && aZ == fZ && aR == fR
            Return True
        EndIf

        ref.MoveTo(furn)

        c += 1
    EndWhile

    Return False
EndFunction

Int Function Mod(Float a, Float b)
    Return Math.Floor(a - Math.Floor(a / b) * b)
EndFunction
