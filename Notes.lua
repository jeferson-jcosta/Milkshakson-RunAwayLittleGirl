-- Release notes shown once after an update (MilkshaksonUI:WhatsNew) and by the
-- "What's new" button in Options. Newest first; en = English, pt = Portuguese.
-- At each release: add the new version on top (from CHANGELOG.md).
local ADDON, ns = ...

ns.NOTES = {
    { v = "2.6.0",
      en = {
        "**No lure?** While you fish with no lure on the pole, a pulsing lure icon with **No lure!** shows where the pole icon sits.",
        "**Alliance / Horde colors** for the mirror window — Options > Appearance.",
      },
      pt = {
        "**Sem isca?** Enquanto você pesca sem isca na vara, um ícone de isca pulsando com **Sem isca!** aparece onde fica o ícone da vara.",
        "**Cores da Aliança / Horda** na janela do espelho — Opções > Aparência.",
      } },
    { v = "2.5.0",
      en = {
        "**Fishing**: Nat Pagle and the fishing pole in the middle of the screen while a pole is equipped and you are not fishing (hidden while you fish).",
        "**Fishing pole warning**: in combat, or a minute without fishing, a warning sound (horn, alarm, raid warning or spoken).",
        "Nat and the pole can be moved and resized (untick “Lock”).",
        "**Skill up**: the new level rises in blue from the middle of the screen. Professions / fishing only / all skills / off.",
        "**What's new** popup after an update (this window), also from Options.",
      },
      pt = {
        "**Pesca**: Nat Pagle e a vara no meio da tela com a vara equipada e sem pescar (somem enquanto você pesca).",
        "**Aviso da vara**: em combate, ou um minuto sem pescar, toca um aviso (corneta, alarme, aviso de raide ou falado).",
        "Nat e a vara podem ser movidos e redimensionados (desmarque “Travar”).",
        "**Habilidade subiu**: o novo nível sobe em azul do meio da tela. Profissões / só pesca / todas / desligado.",
        "Janela de **novidades** depois de atualizar (esta), também pelas Opções.",
      } },
    { v = "2.4.2",
      en = {
        "Options: “Buy me a coffee” at the top of the page.",
      },
      pt = {
        "Opções: “Me pague um café” no topo da página.",
      } },
}

local function Version()
    local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return get and get(ADDON, "Version") or "?"
end

function ns:ShowWhatsNew(force)
    local UI = MilkshaksonUI
    if not (UI and UI.WhatsNew) then return end
    UI:WhatsNew({ title = "Run Away Little Girl", version = Version(), notes = ns.NOTES,
        db = RunAwayLittleGirlDB, lang = ns.localeCode, force = force })
end

-- Options > About: the addon's description (About.lua, same text as the README / CurseForge page)
function ns:ShowAbout()
    local UI = MilkshaksonUI
    if not (UI and UI.About and ns.ABOUT) then return end
    UI:About({ title = "Run Away Little Girl", version = Version(), about = ns.ABOUT, lang = ns.localeCode })
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function()
    f:UnregisterAllEvents()
    ns:ShowWhatsNew(false)
end)
