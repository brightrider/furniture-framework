std::uint32_t GetCollisionLayer(RE::StaticFunctionTag*, RE::TESObjectREFR* ref) {
    if (ref == nullptr) {
		return 0;
	}

    RE::NiAVObject* _3d = ref->Get3D();
    if (_3d == nullptr) {
		return 0;
	}
    return (std::uint32_t)_3d->GetCollisionLayer();
}

SKSEPluginLoad(const SKSE::LoadInterface* skse) {
    SKSE::Init(skse);

    SKSE::GetPapyrusInterface()->Register([](RE::BSScript::IVirtualMachine* vm) {
        vm->RegisterFunction("GetCollisionLayer", "BRFFSKSELibrary", GetCollisionLayer);

        return true;
    });

    return true;
}
