Scriptname BRFFController extends Quest

Import NetImmerse

Spell Property ActorSpell Auto
Armor Property ExecutionerRing Auto
Faction Property FFFaction Auto

Int ACTORS

ObjectReference selectedFurniture

Event OnInit()
    Int mainEntry = JMap.object()
    ACTORS = JFormMap.object()
    JMap.setObj(mainEntry, "actors", ACTORS)
    JDB.setObj("BRFF", mainEntry)

    DBInit()

    RegisterForKey(0x10)
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

    Debug.Notification("Refresh")
    Refresh()
EndEvent

Event ActorHit(Actor ref, Actor attacker)
    If attacker.IsEquipped(ExecutionerRing)
        Kill(ref)
    EndIf
EndEvent

Function Add(Actor ref, ObjectReference furn)
    Int record = JMap.object()
    JMap.setForm(record, "furniture", furn)
    JMap.setFlt(record, "health", ref.GetAV("Health"))
    JMap.setInt(record, "ignoreFriendlyHits", ref.IsIgnoringFriendlyHits() as Int)
    JMap.setInt(record, "collisionLayer", BRFFSKSELibrary.GetCollisionLayer(furn))
    JFormMap.setObj(ACTORS, ref, record)

    Refresh()

    Int handle = ModEvent.Create("BRFF_Add")
    If handle
        ModEvent.PushForm(handle, ref)
        ModEvent.PushForm(handle, furn)
        ModEvent.Send(handle)
    EndIf
EndFunction

Function Remove(Actor ref)
    Int record = DBGetActorRecord(ref)
    ObjectReference furn = DBGetFurniture(ref)

    ref.RemoveSpell(ActorSpell)
    ref.RemoveFromFaction(FFFaction)
    ref.IgnoreFriendlyHits(JMap.getInt(record, "ignoreFriendlyHits") as Bool)
    CUnconstraint(ref)
    CRemoveDummies(ref)
    If ! ref.IsDead()
        ref.ForceAV("Health", JMap.getFlt(record, "health"))
        Debug.SendAnimationEvent(ref, "IdleForceDefaultState")
        ref.EvaluatePackage()
    EndIf

    PO3_SKSEFunctions.SetCollisionLayer(furn, "", JMap.getInt(record, "collisionLayer"))
    furn.BlockActivation(False)

    JFormMap.removeKey(ACTORS, ref)

    Int handle = ModEvent.Create("BRFF_Remove")
    If handle
        ModEvent.PushForm(handle, ref)
        ModEvent.PushForm(handle, furn)
        ModEvent.Send(handle)
    EndIf
EndFunction

Function Kill(Actor ref)
    ref.Kill()
    CConstraint(ref)
EndFunction

Function Refresh()
    Actor key_ = JFormMap.nextKey(ACTORS) as Actor
    While key_
        Actor player = Game.GetPlayer()
        ObjectReference furn = DBGetFurniture(key_)
        If (player.GetDistance(furn) < 102400) || player.HasLOS(furn)
            FConfigure(furn)
            AConfigure(key_)
            EEquipItemsFromConfig(key_)
            CCreateDummies(key_)
            CPositionDummies(key_)
            CConstraint(key_)
        EndIf
        key_ = JFormMap.nextKey(ACTORS, key_) as Actor
    EndWhile
EndFunction

; ----------------------------------------------------------------------------------------------------------------------
; Database
; ----------------------------------------------------------------------------------------------------------------------
Function DBInit()
    Int mapping = JMap.object()
    Int vals = JMap.allValues(JValue.readFromFile("Data/brff_mapping.json"))
    Int i = 0
    While i < JArray.count(vals)
        JMap.addPairs(mapping, JArray.getObj(vals, i), overrideDuplicates=True)
        i += 1
    EndWhile
    JMap.setObj(JDB.solveObj(".BRFF"), "mapping", mapping)
EndFunction

Int Function DBGetMapping()
    Return JDB.solveObj(".BRFF.mapping")
EndFunction

Int Function DBGetMappingRecord(Actor ref)
    Return JMap.getObj(DBGetMapping(), FGetEditorId(DBGetFurniture(ref)))
EndFunction

Int Function DBGetActorRecord(Actor ref)
    Return JFormMap.getObj(ACTORS, ref)
EndFunction

ObjectReference Function DBGetFurniture(Actor ref)
    Return JMap.getForm(DBGetActorRecord(ref), "furniture") as ObjectReference
EndFunction

String Function DBGetEvent(Actor ref)
    Return JMap.getStr(DBGetMappingRecord(ref), "animEvent")
EndFunction

String Function DBGetConstraints(Actor ref)
    Return JMap.getStr(DBGetMappingRecord(ref), "constraints")
EndFunction

Int Function DBGetBondArmsOnDeath(Actor ref)
    Return JMap.getInt(DBGetMappingRecord(ref), "bondArmsOnDeath")
EndFunction

Int Function DBGetBondLegsOnDeath(Actor ref)
    Return JMap.getInt(DBGetMappingRecord(ref), "bondLegsOnDeath")
EndFunction

Int Function DBGetEquipment(Actor ref)
    Return JMap.getObj(DBGetMappingRecord(ref), "equipment")
EndFunction

ObjectReference Function DBAGetRef(Actor ref, String name)
    Return JMap.getForm(DBGetActorRecord(ref), name) as ObjectReference
EndFunction

Function DBASetRef(Actor ref, String name, ObjectReference value)
    JMap.setForm(DBGetActorRecord(ref), name, value)
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Math
; ----------------------------------------------------------------------------------------------------------------------
Int Function Mod(Float a, Float b)
    Return Math.Floor(a - Math.Floor(a / b) * b)
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Actor
; ----------------------------------------------------------------------------------------------------------------------
Function AConfigure(Actor ref)
    If ! ref.IsDead()
        ref.ForceAV("Health", 1000000000)
    EndIf
    ref.AddToFaction(FFFaction)
    ref.IgnoreFriendlyHits()
    ref.MoveTo(DBGetFurniture(ref))
    ASAE(ref)
    ref.AddSpell(ActorSpell)
EndFunction

Function ASAE(Actor ref)
    If ! ref.IsDead()
        Debug.SendAnimationEvent(ref, DBGetEvent(ref))
    EndIf
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Furniture
; ----------------------------------------------------------------------------------------------------------------------
String Function FGetEditorId(ObjectReference furn)
    Return PO3_SKSEFunctions.GetFormEditorID(furn.GetBaseObject())
EndFunction

Function FConfigure(ObjectReference furn)
    If furn.GetAngleX() != 0 || furn.GetAngleY() != 0
        furn.SetAngle(0, 0, Mod(furn.GetAngleZ(), 360))
    EndIf
    If BRFFSKSELibrary.GetCollisionLayer(furn) != 15
        PO3_SKSEFunctions.SetCollisionLayer(furn, "", 15)
    EndIf
    furn.BlockActivation()
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Equipment
; ----------------------------------------------------------------------------------------------------------------------
Function EEquipItemsFromConfig(Actor ref)
    Int equipment = DBGetEquipment(ref)
    Int i = 0
    While i < JArray.count(equipment)
        ref.EquipItem(PO3_SKSEFunctions.GetFormFromEditorID(JArray.getStr(equipment, i)))
        i += 1
    EndWhile
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Constraints
; ----------------------------------------------------------------------------------------------------------------------
Function CCreateDummies(Actor ref)
    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        ObjectReference dummy = DBAGetRef(ref, JArray.getStr(nodes, i))
        If ! dummy
            dummy = ref.PlaceAtMe(Game.GetForm(0xD19BA), abForcePersist=True)
            DBASetRef(ref, JArray.getStr(nodes, i), dummy)
        EndIf
        i += 1
    EndWhile
EndFunction

Function CRemoveDummies(Actor ref)
    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        ObjectReference dummy = DBAGetRef(ref, JArray.getStr(nodes, i))
        If dummy
            dummy.Delete()
        EndIf
        i += 1
    EndWhile
EndFunction

Function CPositionDummies(Actor ref)
    If ref.IsDead()
        Return
    EndIf

    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        String nodeName = JArray.getStr(nodes, i)
        ObjectReference dummy = DBAGetRef(ref, nodeName)
        If dummy
            Float posX = GetNodeWorldPositionX(ref, nodeName, firstPerson=False)
            Float posY = GetNodeWorldPositionY(ref, nodeName, firstPerson=False)
            Float posZ = GetNodeWorldPositionZ(ref, nodeName, firstPerson=False)
            dummy.SetPosition(posX, posY, posZ)
        EndIf
        i += 1
    EndWhile
EndFunction

Function CConstraint(Actor ref)
    If ! ref.IsDead()
        Return
    EndIf

    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        ObjectReference dummy = DBAGetRef(ref, JArray.getStr(nodes, i))
        If dummy
            Game.AddHavokBallAndSocketConstraint(ref, JArray.getStr(nodes, i), dummy, "AttachDummy")
            ref.ApplyHavokImpulse(0.1, 0.1, 0.1, 0.1)
        EndIf
        i += 1
    EndWhile

    CConstraintHandcuffsArms(ref)
    CConstraintHandcuffsLegs(ref)
EndFunction

Function CConstraintHandcuffsArms(Actor ref)
    If DBGetBondArmsOnDeath(ref) == 0
        Return
    EndIf

    If ! ref.IsDead()
        Return
    EndIf

    Game.AddHavokBallAndSocketConstraint(ref, "NPC L Hand [LHnd]", ref, "NPC Spine [Spn0]", -3, 7, 8)
    Game.AddHavokBallAndSocketConstraint(ref, "NPC R Hand [RHnd]", ref, "NPC Spine [Spn0]", 3, 7, 8)
EndFunction

Function CConstraintHandcuffsLegs(Actor ref)
    If DBGetBondLegsOnDeath(ref) == 0
        Return
    EndIf

    If ! ref.IsDead()
        Return
    EndIf

    Game.AddHavokBallAndSocketConstraint(ref, "NPC L Foot [Lft ]", ref, "NPC R Foot [Rft ]")
    Game.AddHavokBallAndSocketConstraint(ref, "NPC R Foot [Rft ]", ref, "NPC L Foot [Lft ]")
EndFunction

Function CUnconstraint(Actor ref)
    If ! ref.IsDead()
        Return
    EndIf

    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        ObjectReference dummy = DBAGetRef(ref, JArray.getStr(nodes, i))
        If dummy
            Game.RemoveHavokConstraints(ref, JArray.getStr(nodes, i), dummy, "AttachDummy")
        EndIf
        i += 1
    EndWhile
EndFunction

Int Function CGetStrings(Actor ref)
    Int result = JArray.object()

    String mask = DBGetConstraints(ref)
    If StringUtil.Find(mask, "N") != -1
        JArray.addStr(result, "NPC Head [Head]")
    EndIf
    If StringUtil.Find(mask, "H") != -1
        JArray.addStr(result, "NPC L Hand [LHnd]")
        JArray.addStr(result, "NPC R Hand [RHnd]")
    EndIf
    If StringUtil.Find(mask, "L") != -1
        JArray.addStr(result, "NPC L Foot [Lft ]")
        JArray.addStr(result, "NPC R Foot [Rft ]")
    EndIf
    If StringUtil.Find(mask, "A") != -1
        JArray.addStr(result, "NPC L UpperArm [LUar]")
        JArray.addStr(result, "NPC R UpperArm [RUar]")
    EndIf
    If StringUtil.Find(mask, "S") != -1
        JArray.addStr(result, "NPC Spine2 [Spn2]")
    EndIf

    Return result
EndFunction
; ------------------------------------------------------------------------------
