Scriptname BRFFSpawnFurnEffectScript extends ActiveMagicEffect

Event OnEffectStart(Actor akTarget, Actor akCaster)
    Int file = JValue.readFromFile("Data/brff_mapping.json")

    UIListMenu mainMenu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
    String k = JMap.nextKey(file)
    While k
        mainMenu.AddEntryItem(k)
        k = JMap.nextKey(file, k)
    EndWhile
    mainMenu.OpenMenu()
    String result = mainMenu.GetResultString()
    If ! result
        Return
    EndIf

    mainMenu = UIExtensions.GetMenu("UIListMenu") as UIListMenu
    Int furns = JMap.getObj(file, result)
    k = JMap.nextKey(furns)
    While k
        mainMenu.AddEntryItem(k)
        k = JMap.nextKey(furns, k)
    EndWhile
    mainMenu.OpenMenu()
    result = mainMenu.GetResultString()
    If ! result
        Return
    EndIf

    ObjectReference furn = Game.GetPlayer().PlaceAtMe(PO3_SKSEFunctions.GetFormFromEditorID(result))
    UIExtensions.InitMenu("UITextEntryMenu")
    UIExtensions.OpenMenu("UITextEntryMenu")
    String name = UIExtensions.GetMenuResultString("UITextEntryMenu")
    If name
        furn.SetDisplayName(name, force=True)
    EndIf
EndEvent
