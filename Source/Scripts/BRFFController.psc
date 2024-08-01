Scriptname BRFFController extends Quest

Spell Property ActorSpell Auto
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
    JFormMap.setObj(ACTORS, ref, record)
EndFunction

Function Remove(Actor ref)
    JMap.setInt(JFormMap.getObj(ACTORS, ref), "toRemove", 1)
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
    ref.ForceAV("Health", JMap.getFlt(record, "health"))
    ref.SetRestrained(False)
    ref.SetDontMove(False)
    ref.EvaluatePackage()
    Debug.SendAnimationEvent(ref, "IdleForceDefaultState")
    ObjectReference furn = JMap.getForm(record, "furniture") as ObjectReference
    PO3_SKSEFunctions.SetCollisionLayer(furn, "", 1)
    furn.BlockActivation(False)
    JFormMap.removeKey(ACTORS, ref)
EndFunction

Function ConfigureActor(Actor ref, bool shouldAddPackage=True)
    If ref.IsDead()
        ref.Resurrect()
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
    furn.SetAngle(0, 0, Mod(furn.GetAngleZ(), 360))
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
    Debug.SendAnimationEvent(ref, JMap.getStr(MAPPING, PO3_SKSEFunctions.GetFormEditorID(furn.GetBaseObject())))
    Utility.Wait(1)
EndFunction

Bool Function TryPosition(Actor ref, ObjectReference furn)
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
