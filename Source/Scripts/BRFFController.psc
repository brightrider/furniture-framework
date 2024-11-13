Scriptname BRFFController extends Quest

Import Math
Import NetImmerse

Spell Property ActorSpell Auto
Armor Property BeaterRing Auto
Armor Property ExecutionerRing Auto
Faction Property FFFaction Auto
Package Property DoNothing Auto

Int ACTORS

ObjectReference selectedFurniture

; ----------------------------------------------------------------------------------------------------------------------
; Events
; ----------------------------------------------------------------------------------------------------------------------
Event OnInit()
    Int mainEntry = JMap.object()
    ACTORS = JFormMap.object()
    JMap.setObj(mainEntry, "actors", ACTORS)
    JDB.setObj("BRFF", mainEntry)

    DBInit()

    RegisterForKey(0x3B)
EndEvent

Event OnKeyDown(Int keyCode)
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

    Refresh()
    Debug.Notification("Refresh")
EndEvent

Event ActorHit(Actor ref, Actor attacker)
    If attacker.IsEquipped(BeaterRing) && CAllowed(ref)
        attacker.PushActorAway(ref, 2)
    EndIf

    If attacker.IsEquipped(ExecutionerRing)
        Kill(ref)
    EndIf
EndEvent
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; API
; ----------------------------------------------------------------------------------------------------------------------
Function Add(Actor ref, ObjectReference furn)
    Int record = JMap.object()
    JMap.setForm(record, "furniture", furn)
    JMap.setFlt(record, "health", ref.GetAV("Health"))
    JMap.setInt(record, "ignoreFriendlyHits", ref.IsIgnoringFriendlyHits() as Int)
    JMap.setObj(record, "equipment", EAddAllEquippedItemsToArrayStr(ref))
    JMap.setInt(record, "packageOverrides", ActorUtil.CountPackageOverride(ref))
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
    ObjectReference furn = DBAGetFurniture(ref)

    ref.RemoveSpell(ActorSpell)
    ref.RemoveFromFaction(FFFaction)
    ref.IgnoreFriendlyHits(JMap.getInt(record, "ignoreFriendlyHits") as Bool)
    CPositionDummies(ref, checkConfig=False)
    RDisable(ref)
    CDisable(ref, checkRagdollModeRuntime=False)
    If ref.IsDead()
        CConstraintHandcuffsArms(ref, checkDuplicate=False)
        CConstraintHandcuffsLegs(ref, checkDuplicate=False)
    EndIf
    CRemoveDummies(ref)
    ActorUtil.RemovePackageOverride(ref, DoNothing)
    If ! ref.IsDead()
        ref.ForceAV("Health", JMap.getFlt(record, "health"))
        ERestore(ref)
        Debug.SendAnimationEvent(ref, "IdleForceDefaultState")
        ref.EvaluatePackage()
        If DBGetRagdollMode(ref)
            furn.PushActorAway(ref, 0)
        EndIf
    EndIf

    SafeSetCollisionLayer(furn, JMap.getInt(record, "collisionLayer"))
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
    If ref.IsDead()
        Return
    EndIf

    RDisable(ref)

    ref.Kill()

    If ! DBGetRagdollMode(ref)
        CEnable(ref)
    EndIf
EndFunction

Function Refresh()
    Actor key_ = JFormMap.nextKey(ACTORS) as Actor
    While key_
        Actor player = Game.GetPlayer()
        ObjectReference furn = DBAGetFurniture(key_)
        If furn.Is3DLoaded() && ((player.GetDistance(furn) < 102400) || player.HasLOS(furn))
            FConfigure(key_, furn)
            AConfigure(key_)
            CConfigure(key_)
            If key_.IsDead()
                key_.ApplyHavokImpulse(0.1, 0.1, 0.1, 0.1)
            EndIf
        EndIf
        key_ = JFormMap.nextKey(ACTORS, key_) as Actor
    EndWhile
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Actor
; ----------------------------------------------------------------------------------------------------------------------
Function AConfigure(Actor ref)
    AAddPackageOverride(ref, DoNothing, priority=100)
    If ! ref.IsDead()
        ref.ForceAV("Health", 1000000000)
    EndIf
    ref.AddToFaction(FFFaction)
    ref.IgnoreFriendlyHits()
    AMoveToFurn(ref)
    ASAE(ref)
    REnable(ref)
    EEquip(ref)
    ref.AddSpell(ActorSpell)
EndFunction

Function AMoveToFurn(Actor ref)
    ObjectReference furn = DBAGetFurniture(ref)

    If ref.IsDead() && ref.GetDistance(furn) < 192
        Return
    EndIf

    SafeMoveTo(ref, furn)
EndFunction

Function ASAE(Actor ref)
    If DBGetRagdollMode(ref) || ref.IsDead()
        Return
    EndIf

    Debug.SendAnimationEvent(ref, DBGetEvent(ref))
EndFunction

Function AAddPackageOverride(Actor ref, Package targetPackage, Int priority=30)
    If ActorUtil.CountPackageOverride(ref) > DBAGetPackageOverrides(ref)
        Return
    EndIf

    ActorUtil.AddPackageOverride(ref, targetPackage, priority)
EndFunction

Function AReset(Actor ref, ObjectReference target=None, Bool saveEquipment=True)
    If ref.IsDead()
        Return
    EndIf

    Int equipment
    If saveEquipment
        equipment = EAddAllEquippedItemsToArrayStr(ref)
    EndIf

    ref.Reset(target)

    If saveEquipment
        EEquipFromJArray(ref, equipment, unequipAll=True, unequipAllRemoveGore=True)
    EndIf
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Furniture
; ----------------------------------------------------------------------------------------------------------------------
Function FConfigure(Actor ref, ObjectReference furn)
    SafeSetAngleNormalized(furn, 0, 0, furn.GetAngleZ())
    If ! DBGetCollisionEnabled(ref)
        SafeSetCollisionLayer(furn, 15)
    EndIf
    furn.BlockActivation()
EndFunction

String Function FGetEditorId(ObjectReference furn)
    Return PO3_SKSEFunctions.GetFormEditorID(furn.GetBaseObject())
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

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
    Return JMap.getObj(DBGetMapping(), FGetEditorId(DBAGetFurniture(ref)))
EndFunction

String Function DBGetEvent(Actor ref)
    Return JMap.getStr(DBGetMappingRecord(ref), "animEvent")
EndFunction

Bool Function DBGetRagdollMode(Actor ref)
    Return JMap.getInt(DBGetMappingRecord(ref), "ragdollMode") as Bool
EndFunction

String Function DBGetConstraints(Actor ref)
    Return JMap.getStr(DBGetMappingRecord(ref), "constraints")
EndFunction

Int Function DBGetBondArms(Actor ref)
    Return JMap.getInt(DBGetMappingRecord(ref), "bondArms")
EndFunction

Int Function DBGetBondLegs(Actor ref)
    Return JMap.getInt(DBGetMappingRecord(ref), "bondLegs")
EndFunction

Int Function DBGetEquipmentAnimMode(Actor ref)
    Return JMap.getObj(DBGetMappingRecord(ref), "equipmentAnimMode")
EndFunction

Int Function DBGetEquipmentRagdollMode(Actor ref)
    Return JMap.getObj(DBGetMappingRecord(ref), "equipmentRagdollMode")
EndFunction

Bool Function DBGetCollisionEnabled(Actor ref)
    Return JMap.getInt(DBGetMappingRecord(ref), "collisionEnabled") as Bool
EndFunction

Float[] Function DBGetDummyPosition(Actor ref, String name)
    Return JArray.asFloatArray(JMap.getObj(DBGetMappingRecord(ref), name))
EndFunction

Int Function DBGetActorRecord(Actor ref)
    Return JFormMap.getObj(ACTORS, ref)
EndFunction

ObjectReference Function DBAGetFurniture(Actor ref)
    Return JMap.getForm(DBGetActorRecord(ref), "furniture") as ObjectReference
EndFunction

Int Function DBAGetEquipment(Actor ref)
    Return JMap.getObj(DBGetActorRecord(ref), "equipment")
EndFunction

Int Function DBAGetPackageOverrides(Actor ref)
    Return JMap.getInt(DBGetActorRecord(ref), "packageOverrides")
EndFunction

ObjectReference Function DBAGetRef(Actor ref, String name)
    Return JMap.getForm(DBGetActorRecord(ref), name) as ObjectReference
EndFunction

Function DBASetRef(Actor ref, String name, ObjectReference value)
    JMap.setForm(DBGetActorRecord(ref), name, value)
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Transforms
; ----------------------------------------------------------------------------------------------------------------------
Function SafeSetPosition(ObjectReference ref, Float x, Float y, Float z)
    If ref.X != x || ref.Y != y || ref.Z != z
        ref.SetPosition(x, y, z)
    EndIf
EndFunction

Function SafeMoveTo(ObjectReference ref, ObjectReference target, Float x=0.0, Float y=0.0, Float z=0.0)
    If ref.X != target.X + x || ref.Y != target.Y + y || ref.Z != target.Z + z
        ref.MoveTo(target, x, y, z)
    EndIf
EndFunction

Function SafeSetAngle(ObjectReference ref, Float x, Float y, Float z)
    If ref.GetAngleX() != x || ref.GetAngleY() != y || ref.GetAngleZ() != z
        ref.SetAngle(x, y, z)
    EndIf
EndFunction

Function SafeSetAngleNormalized(ObjectReference ref, Float x, Float y, Float z)
    SafeSetAngle(ref, Mod(x, 360), Mod(y, 360), Mod(z, 360))
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Collision
; ----------------------------------------------------------------------------------------------------------------------
Function SafeSetCollisionLayer(ObjectReference ref, Int layer)
    If BRFFSKSELibrary.GetCollisionLayer(ref) != layer
        PO3_SKSEFunctions.SetCollisionLayer(ref, "", layer)
    EndIf
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
; Equipment
; ----------------------------------------------------------------------------------------------------------------------
Function EEquip(Actor ref)
    If RActive(ref) || ref.IsDead()
        EEquipRagdollMode(ref)
    Else
        EEquipAnimMode(ref)
    EndIf
EndFunction

Function EEquipAnimMode(Actor ref)
    EEquipFromJArray(ref, DBGetEquipmentAnimMode(ref), unequipAll=True)
EndFunction

Function EEquipRagdollMode(Actor ref)
    EEquipFromJArray(ref, DBGetEquipmentRagdollMode(ref), unequipAll=True)
EndFunction

Function EEquipFromJArray(Actor ref, Int equipment, Bool unequipAll=False, Bool unequipAllRemoveGore=False)
    If unequipAll
        EUnequipAll(ref, removeGore=unequipAllRemoveGore)
    EndIf

    Int i = 0
    While i < JArray.count(equipment)
        ESafeEquipItem(ref, JArray.getStr(equipment, i))
        i += 1
    EndWhile
EndFunction

Function ESafeEquipItem(Actor ref, String name)
    Form item = PO3_SKSEFunctions.GetFormFromEditorID(name)
    If ! ref.IsEquipped(item)
        ref.EquipItem(item)
    EndIf
EndFunction

Function ESafeUnequipItem(Actor ref, String name)
    Form item = PO3_SKSEFunctions.GetFormFromEditorID(name)
    If ref.IsEquipped(item)
        ref.UnequipItem(item)
    EndIf
EndFunction

Function EUnequipAll(Actor ref, Bool removeGore=False)
    Form[] items = PO3_SKSEFunctions.AddAllEquippedItemsToArray(ref)
    Int i = 0
    While i < items.Length
        String editorId = PO3_SKSEFunctions.GetFormEditorID(items[i])
        If removeGore || StringUtil.Substring(editorId, 0, 3) != "MC_"
            ref.UnequipItem(items[i])
        EndIf
        i += 1
    EndWhile
EndFunction

Function ERestore(Actor ref)
    EEquipFromJArray(ref, DBAGetEquipment(ref), unequipAll=True, unequipAllRemoveGore=True)
EndFunction

Int Function EAddAllEquippedItemsToArrayStr(Actor ref)
    Int result = JArray.object()

    Form[] equipment = PO3_SKSEFunctions.AddAllEquippedItemsToArray(ref)
    Int i = 0
    While i < equipment.Length
        JArray.addStr(result, PO3_SKSEFunctions.GetFormEditorID(equipment[i]))
        i += 1
    EndWhile

    Return result
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Ragdoll
; ----------------------------------------------------------------------------------------------------------------------
Function REnable(Actor ref, Bool checkConfig=True)
    If checkConfig && ! DBGetRagdollMode(ref)
        Return
    EndIf

    If ref.IsDead()
        Return
    EndIf

    DBAGetFurniture(ref).PushActorAway(ref, 0)
    ref.SetAV("Paralysis", 1)
EndFunction

Function RDisable(Actor ref, Bool checkConfig=True)
    If checkConfig && ! DBGetRagdollMode(ref)
        Return
    EndIf

    ref.SetAV("Paralysis", 0)
EndFunction

Bool Function RActive(Actor ref)
    Return ref.GetAV("Paralysis") == 1
EndFunction
; ----------------------------------------------------------------------------------------------------------------------

; ----------------------------------------------------------------------------------------------------------------------
; Constraints
; ----------------------------------------------------------------------------------------------------------------------
Function CConfigure(Actor ref)
    CCreateDummies(ref)
    CPositionDummies(ref)
    CEnable(ref)
EndFunction

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

; Calling this function while constraints are still atttached to the dummies is unsafe and can cause a crash.
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

Function CPositionDummies(Actor ref, Bool checkConfig=True)
    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        String nodeName = JArray.getStr(nodes, i)
        ObjectReference dummy = DBAGetRef(ref, nodeName)
        If dummy
            Float[] pos = DBGetDummyPosition(ref, nodeName)
            If checkConfig && pos
                ObjectReference furn = DBAGetFurniture(ref)
                Float posX = pos[0] * cos(-furn.GetAngleZ()) + pos[1] * sin(furn.GetAngleZ())
                Float posY = pos[0] * sin(-furn.GetAngleZ()) + pos[1] * cos(-furn.GetAngleZ())
                Float posZ = pos[2]
                SafeMoveTo(dummy, DBAGetFurniture(ref), posX, posY, posZ)
            Else
                Float posX = GetNodeWorldPositionX(ref, nodeName, firstPerson=False)
                Float posY = GetNodeWorldPositionY(ref, nodeName, firstPerson=False)
                Float posZ = GetNodeWorldPositionZ(ref, nodeName, firstPerson=False)
                SafeSetPosition(dummy, posX, posY, posZ)
            EndIf
        EndIf
        i += 1
    EndWhile
EndFunction

Function CEnable(Actor ref)
    If ! CAllowed(ref)
        Return
    EndIf

    Int nodes = CGetStrings(ref)
    Int i = 0
    While i < JArray.count(nodes)
        ObjectReference dummy = DBAGetRef(ref, JArray.getStr(nodes, i))
        If dummy
            Game.AddHavokBallAndSocketConstraint(ref, JArray.getStr(nodes, i), dummy, "AttachDummy")
        EndIf
        i += 1
    EndWhile

    CConstraintHandcuffsArms(ref)
    CConstraintHandcuffsLegs(ref)
EndFunction

Function CConstraintHandcuffsArms(Actor ref, Bool checkConfig=True, Bool checkDuplicate=True)
    If ! CAllowed(ref)
        Return
    EndIf

    If checkConfig && DBGetBondArms(ref) == 0
        Return
    EndIf

    If checkDuplicate && StringUtil.Find(DBGetConstraints(ref), "H") != -1
        Return
    EndIf

    Game.AddHavokBallAndSocketConstraint(ref, "NPC L Hand [LHnd]", ref, "NPC Spine [Spn0]", -3, 7, 8)
    Game.AddHavokBallAndSocketConstraint(ref, "NPC R Hand [RHnd]", ref, "NPC Spine [Spn0]", 3, 7, 8)
EndFunction

Function CConstraintHandcuffsLegs(Actor ref, Bool checkConfig=True, Bool checkDuplicate=True)
    If ! CAllowed(ref)
        Return
    EndIf

    If checkConfig && DBGetBondLegs(ref) == 0
        Return
    EndIf

    If checkDuplicate && StringUtil.Find(DBGetConstraints(ref), "L") != -1
        Return
    EndIf

    Game.AddHavokBallAndSocketConstraint(ref, "NPC L Foot [Lft ]", ref, "NPC R Foot [Rft ]")
    Game.AddHavokBallAndSocketConstraint(ref, "NPC R Foot [Rft ]", ref, "NPC L Foot [Lft ]")
EndFunction

Function CDisable(Actor ref, Bool checkRagdollModeRuntime=True)
    If ! CAllowed(ref, checkRagdollModeRuntime)
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

    CUnconstraintHandcuffsArms(ref, checkRagdollModeRuntime=checkRagdollModeRuntime)
    CUnconstraintHandcuffsLegs(ref, checkRagdollModeRuntime=checkRagdollModeRuntime)
EndFunction

Function CUnconstraintHandcuffsArms(Actor ref, Bool checkConfig=True, Bool checkRagdollModeRuntime=True)
    If ! CAllowed(ref, checkRagdollModeRuntime)
        Return
    EndIf

    If checkConfig && DBGetBondArms(ref) == 0
        Return
    EndIf

    If StringUtil.Find(DBGetConstraints(ref), "H") != -1
        Return
    EndIf

    Game.RemoveHavokConstraints(ref, "NPC L Hand [LHnd]", ref, "NPC Spine [Spn0]")
    Game.RemoveHavokConstraints(ref, "NPC R Hand [RHnd]", ref, "NPC Spine [Spn0]")
EndFunction

Function CUnconstraintHandcuffsLegs(Actor ref, Bool checkConfig=True, Bool checkRagdollModeRuntime=True)
    If ! CAllowed(ref, checkRagdollModeRuntime)
        Return
    EndIf

    If checkConfig && DBGetBondLegs(ref) == 0
        Return
    EndIf

    If StringUtil.Find(DBGetConstraints(ref), "L") != -1
        Return
    EndIf

    Game.RemoveHavokConstraints(ref, "NPC L Foot [Lft ]", ref, "NPC R Foot [Rft ]")
    Game.RemoveHavokConstraints(ref, "NPC R Foot [Rft ]", ref, "NPC L Foot [Lft ]")
EndFunction

Bool Function CAllowed(Actor ref, Bool checkRagdollModeRuntime=True)
    If checkRagdollModeRuntime
        Return RActive(ref) || ref.IsDead()
    Else
        Return DBGetRagdollMode(ref) || ref.IsDead()
    EndIf
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
