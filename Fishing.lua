-- Fishing pole reminder: Nat Pagle (animated, the game's own NPC model) and a
-- round fishing pole icon in the middle of the screen while a fishing pole is
-- equipped (main hand). Visual only: it takes no clicks, so it never blocks the
-- bobber. Option db.fishingIcon (on by default).
--
-- The model is loaded by its creature display (13099, Nat Pagle's model on
-- Wowhead, classic and MoP); by NPC id only as fallback (SetCreature showed
-- nothing in game: the client needs the NPC cached). Models load
-- asynchronously, each try gets 2 s.
-- If none loads, only the pole icon shows. What happened is kept in
-- RunAwayLittleGirlDB.natPagle (SavedVariables) for diagnostics.
local _, ns = ...

local W, H = 120, 150          -- Nat's model
local SIZE = 44                -- pole icon
local FALLBACK = "Interface\\Icons\\INV_Fishingpole_02"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POLE = 20                -- Enum.ItemWeaponSubclass.Fishingpole
local TRIES = { { "display", 13099 }, { "creature", 12919 }, { "creature", 63721 } }
-- AnimationData: FishingLoop (falls back to Stand on models without it), Stand,
-- EmoteTalk, EmoteWave, EmoteCheer: he fishes, and now and then talks or waves.
local FISH, STAND, IDLE = 134, 0, { 60, 67, 68 }

local frame = CreateFrame("Frame", "RunAwayLittleGirlFishing", UIParent)
frame:SetSize(W, H + SIZE / 2)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("MEDIUM")
frame:EnableMouse(false)
frame:Hide()

local model = CreateFrame("PlayerModel", "RunAwayLittleGirlNatPagle", frame)
model:SetSize(W, H)
model:SetPoint("TOP")
model:EnableMouse(false)
frame.model = model

-- round pole icon with a thin gold ring, at Nat's feet
local badge = CreateFrame("Frame", nil, frame)
badge:SetSize(SIZE, SIZE)
badge:SetPoint("BOTTOM")
badge:SetFrameLevel(model:GetFrameLevel() + 2)
local ring = badge:CreateTexture(nil, "ARTWORK", nil, 1)
ring:SetAllPoints()
ring:SetColorTexture(0.85, 0.68, 0.25, 0.9)
local icon = badge:CreateTexture(nil, "ARTWORK", nil, 2)
icon:SetPoint("CENTER")
icon:SetSize(SIZE - 4, SIZE - 4)
frame.icon, frame.ring, frame.pole = icon, ring, badge

local function Round(tex)
    if not (badge.CreateMaskTexture and tex.AddMaskTexture) then return end
    local ok, m = pcall(badge.CreateMaskTexture, badge)
    if not ok or not m then return end
    pcall(m.SetTexture, m, MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(tex)
    pcall(tex.AddMaskTexture, tex, m)
end
Round(ring)
Round(icon)

---------------------------------------------------------------------------
-- Nat Pagle
---------------------------------------------------------------------------
local try, loaded = 0, false
local function Note(what)
    local db = RunAwayLittleGirlDB
    if not db then return end
    local t = TRIES[try]
    db.natPagle = { try = try, how = t and t[1], id = t and t[2], what = what, t = time and time() or 0 }
end
local function Anim(a) if model.SetAnimation then pcall(model.SetAnimation, model, a) end end
local function Pose()
    if model.SetFacing then pcall(model.SetFacing, model, 0.35) end   -- a bit turned, facing the player
    if model.SetPortraitZoom then pcall(model.SetPortraitZoom, model, 0) end
    Anim(FISH)
end

local Next
Next = function()
    try = try + 1
    local t = TRIES[try]
    if not t then
        Note("none loaded")
        model:Hide()
        return
    end
    if model.ClearModel then pcall(model.ClearModel, model) end
    local ok = pcall(t[1] == "display" and model.SetDisplayInfo or model.SetCreature, model, t[2])
    Note(ok and "set" or "error")
    if C_Timer and C_Timer.After then
        local mine = try
        C_Timer.After(2, function() if try == mine and not loaded then Next() end end)
    end
end

model:SetScript("OnModelLoaded", function()
    loaded = true
    model:Show()
    Note("loaded")
    Pose()
end)

-- every 8-15 s he talks, waves or cheers for a moment, then goes back to fishing
local wait, busy = 10, 0
model:SetScript("OnUpdate", function(_, el)
    if not loaded then return end
    el = el or 0
    if busy > 0 then
        busy = busy - el
        if busy <= 0 then Anim(FISH) end
        return
    end
    wait = wait - el
    if wait <= 0 then
        Anim(IDLE[math.random(#IDLE)])
        busy, wait = 2.5, 8 + math.random(7)
    end
end)

---------------------------------------------------------------------------
-- Pole equipped?
---------------------------------------------------------------------------
-- Is the item in the main hand a fishing pole? (weapon class 2, subclass Fishing Pole)
function ns.FishingPoleEquipped()
    local id = GetInventoryItemID and GetInventoryItemID("player", 16)
    if not id then return false end
    local classID, subclassID
    if C_Item and C_Item.GetItemInfoInstant then
        classID, subclassID = select(6, C_Item.GetItemInfoInstant(id))
    elseif GetItemInfoInstant then
        classID, subclassID = select(6, GetItemInfoInstant(id))
    end
    local pole = (Enum and Enum.ItemWeaponSubclass and Enum.ItemWeaponSubclass.Fishingpole) or POLE
    return classID == 2 and subclassID == pole
end

function ns.UpdateFishing()
    local db = RunAwayLittleGirlDB
    local on = db and db.fishingIcon ~= false and ns.FishingPoleEquipped()
    if on then
        icon:SetTexture((GetInventoryItemTexture and GetInventoryItemTexture("player", 16)) or FALLBACK)
    end
    frame:SetShown(on and true or false)
    if on then
        if try == 0 then Next() elseif loaded then Pose() end
    end
end

---------------------------------------------------------------------------
-- Warnings with the pole equipped (option db.fishingIdle, on):
--  * in combat (the main case: fighting with a fishing pole): at once when
--    combat starts, then every COMBAT_REPEAT seconds while it lasts;
--  * out of combat: no fishing for IDLE seconds, then again every IDLE seconds,
--    until you cast again or take the pole off.
-- Fishing = the player channeling (the cast is a channel).
---------------------------------------------------------------------------
local IDLE, COMBAT_REPEAT = 60, 8
local lastFish, lastWarn, poleOn = 0, 0, false
local combatWarn = 0
local function Now() return GetTime and GetTime() or 0 end

-- Warning sounds (db.fishingSound): the game's "quest failed" horn (default:
-- sounds like something is wrong), an alarm clock, the raid warning, or a
-- spoken sentence with the game's text to speech (C_VoiceChat.SpeakText, the
-- voice / speed / volume set in Options > Accessibility > Text to Speech; the
-- voices are the computer's, not Nat Pagle's: the game has no recorded lines
-- of his to say this).
ns.FISHING_SOUNDS = {
    { "failed", "IG_QUEST_FAILED", 847 },
    { "alarm", "ALARM_CLOCK_WARNING_3", 12889 },
    { "raid", "RAID_WARNING", 8959 },
}
function ns.FishingSound(key)
    for _, s in ipairs(ns.FISHING_SOUNDS) do
        if s[1] == key then return (SOUNDKIT and SOUNDKIT[s[2]]) or s[3] end
    end
    return (SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED) or 847
end

local function Speak(text)
    local V, S = C_VoiceChat, C_TTSSettings
    if not (V and V.SpeakText and S and S.GetVoiceOptionID) then return false end
    local std = Enum and Enum.TtsVoiceType and Enum.TtsVoiceType.Standard or 0
    local ok, voice = pcall(S.GetVoiceOptionID, std)
    if not ok or not voice then
        local vs = V.GetTtsVoices and select(2, pcall(V.GetTtsVoices))
        voice = type(vs) == "table" and vs[1] and vs[1].voiceID
    end
    if not voice then return false end
    local rate = (S.GetSpeechRate and select(2, pcall(S.GetSpeechRate))) or 0
    local vol = (S.GetSpeechVolume and select(2, pcall(S.GetSpeechVolume))) or 100
    return (pcall(V.SpeakText, voice, text, tonumber(rate) or 0, tonumber(vol) or 100, false))
end
ns.FishingSpeak = Speak

function ns.FishingIdleWarn(kind)
    local db = RunAwayLittleGirlDB
    local key = db and db.fishingSound or "failed"
    local spoken = key == "speak" and Speak(kind == "idle" and ns.L.SAY_IDLE or ns.L.SAY_COMBAT)
    if not spoken then
        local s = ns.FishingSound(key == "speak" and "failed" or key)
        if PlaySound then pcall(PlaySound, s, "Master") end
    end
    if loaded and frame:IsShown() then
        Anim(64)                 -- EmoteTalkExclamation: Nat calls you
        busy = 2.5
    end
end

local function IdleTick()
    local db = RunAwayLittleGirlDB
    if not (poleOn and db and db.fishingIdle ~= false) then return end
    local now = Now()
    if InCombatLockdown and InCombatLockdown() then
        lastFish = now
        if now - combatWarn >= COMBAT_REPEAT then
            combatWarn = now
            ns.FishingIdleWarn("combat")
        end
        return
    end
    if UnitChannelInfo and UnitChannelInfo("player") then lastFish = now; return end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost("player") then lastFish = now; return end
    if now - lastFish >= IDLE and now - lastWarn >= IDLE then
        lastWarn = now
        ns.FishingIdleWarn("idle")
    end
end
ns.FishingIdleTick = IdleTick

local function PoleChanged()
    local on = ns.FishingPoleEquipped() and true or false
    if on and not poleOn then lastFish, lastWarn = Now(), 0 end   -- the minute starts when you equip it
    poleOn = on
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
ev:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event, slot)
    if event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if slot == "player" then lastFish, lastWarn = Now(), 0 end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        combatWarn = 0          -- combat starts with the pole: warn right away
        IdleTick()
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= 16 then return end
    PoleChanged()
    ns.UpdateFishing()
end)
local acc = 0
ev:SetScript("OnUpdate", function(_, el)
    acc = acc + (el or 0)
    if acc < 1 then return end
    acc = 0
    IdleTick()
end)
