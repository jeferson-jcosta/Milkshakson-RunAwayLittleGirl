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

-- `frame` shows / hides both; Nat (natBox) and the pole (badge) are placed and
-- sized on their own (saved in db.fishNat / db.fishPole = { x, y, w, h }, from
-- the screen center), movable and resizable while unlocked (db.fishingLocked).
local NAT_DEF = { x = 0, y = 11, w = W, h = H }
local POLE_DEF = { x = 0, y = -64, w = SIZE, h = SIZE }

local frame = CreateFrame("Frame", "RunAwayLittleGirlFishing", UIParent)
frame:SetAllPoints(UIParent)
frame:SetFrameStrata("MEDIUM")
frame:EnableMouse(false)
frame:Hide()

local natBox = CreateFrame("Frame", "RunAwayLittleGirlNatBox", frame)
natBox:SetSize(W, H)
natBox:SetPoint("CENTER", UIParent, "CENTER", NAT_DEF.x, NAT_DEF.y)
natBox:EnableMouse(false)
local model = CreateFrame("PlayerModel", "RunAwayLittleGirlNatPagle", natBox)
model:SetAllPoints()
model:EnableMouse(false)
frame.model, frame.nat = model, natBox

-- round pole icon with a thin gold ring (at Nat's feet by default)
local badge = CreateFrame("Frame", "RunAwayLittleGirlPoleBox", frame)
badge:SetSize(SIZE, SIZE)
badge:SetPoint("CENTER", UIParent, "CENTER", POLE_DEF.x, POLE_DEF.y)
badge:SetFrameLevel(model:GetFrameLevel() + 2)
badge:EnableMouse(false)
local ring = badge:CreateTexture(nil, "ARTWORK", nil, 1)
ring:SetAllPoints()
ring:SetColorTexture(0.85, 0.68, 0.25, 0.9)
local icon = badge:CreateTexture(nil, "ARTWORK", nil, 2)
icon:SetPoint("TOPLEFT", 2, -2)
icon:SetPoint("BOTTOMRIGHT", -2, 2)
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
    local db = RunAwayLittleGirlDB
    model:SetShown(not (db and db.fishingNat == false))
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

---------------------------------------------------------------------------
-- Unlock: drag to move, corner grip to resize; a gold outline and a label
-- show what is what. Locked (default): no mouse at all (never blocks clicks).
---------------------------------------------------------------------------
local function Save(box, key)
    local db = RunAwayLittleGirlDB
    if not db then return end
    local cx, cy = box:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (cx and ux) then return end
    db[key] = { x = math.floor(cx - ux + 0.5), y = math.floor(cy - uy + 0.5),
        w = math.floor(box:GetWidth() + 0.5), h = math.floor(box:GetHeight() + 0.5) }
end

local function Place(box, key, def)
    local db = RunAwayLittleGirlDB
    local v = (db and type(db[key]) == "table" and db[key]) or def
    box:ClearAllPoints()
    box:SetPoint("CENTER", UIParent, "CENTER", v.x or def.x, v.y or def.y)
    box:SetSize(v.w or def.w, v.h or def.h)
end

local function Editable(box, key, label, minW, minH, maxW, maxH, square)
    box:SetMovable(true)
    box:SetResizable(true)
    box:SetClampedToScreen(true)
    if box.SetResizeBounds then box:SetResizeBounds(minW, minH, maxW, maxH) end
    box:RegisterForDrag("LeftButton")
    box:SetScript("OnDragStart", function(self) self:StartMoving() end)
    box:SetScript("OnDragStop", function(self) self:StopMovingOrSizing(); Save(self, key) end)
    local edge = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
        local t = box:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(1, 0.82, 0, 0.8)
        t:SetPoint(p[1]); t:SetPoint(p[2])
        if i <= 2 then t:SetHeight(1) else t:SetWidth(1) end
        edge[#edge + 1] = t
    end
    local lbl = box:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    lbl:SetPoint("BOTTOM", box, "TOP", 0, 2)
    lbl:SetText(label)
    edge[#edge + 1] = lbl
    box.label = lbl
    local grip = CreateFrame("Button", nil, box)
    grip:SetSize(14, 14)
    grip:SetPoint("BOTTOMRIGHT")
    grip:SetFrameLevel(box:GetFrameLevel() + 10)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function() box:StartSizing("BOTTOMRIGHT") end)
    grip:SetScript("OnMouseUp", function() box:StopMovingOrSizing(); Save(box, key) end)
    edge[#edge + 1] = grip
    if square then
        box:SetScript("OnSizeChanged", function(self, w, h)
            if w and h and math.abs(w - h) > 0.5 then self:SetHeight(w) end
        end)
    end
    box.editParts = edge
end
Editable(natBox, "fishNat", "Nat Pagle", 50, 60, 400, 500)
Editable(badge, "fishPole", "", 20, 20, 160, 160, true)

local function Unlocked()
    local db = RunAwayLittleGirlDB
    return db and db.fishingLocked == false
end

local function ApplyLock()
    local open = Unlocked() and true or false
    for _, box in ipairs({ natBox, badge }) do
        box:EnableMouse(open)
        for _, part in ipairs(box.editParts or {}) do part:SetShown(open) end
    end
end

function ns.FishingPlace()
    badge.label:SetText(ns.L.CFG_FISHING_POLE_LABEL)
    Place(natBox, "fishNat", NAT_DEF)
    Place(badge, "fishPole", POLE_DEF)
    ApplyLock()
end

function ns.FishingResetPosition()
    local db = RunAwayLittleGirlDB
    if db then db.fishNat, db.fishPole = nil, nil end
    ns.FishingPlace()
end

-- Fishing right now = the player is channeling (the fishing cast is a channel).
function ns.IsFishing()
    if not UnitChannelInfo then return false end
    local ok, name = pcall(UnitChannelInfo, "player")
    return ok and name ~= nil
end

-- Options: db.fishingNat (Nat Pagle), db.fishingIcon (the pole icon), each on/off;
-- the frame shows while the pole is equipped (or during a test, or while unlocked
-- to be placed) and one of them is on.
local testing = false
function ns.UpdateFishing()
    local db = RunAwayLittleGirlDB
    local nat = not (db and db.fishingNat == false)
    local pole = not (db and db.fishingIcon == false)
    ApplyLock()
    -- while fishing (casting = a channel) both hide; they are the "you are NOT fishing" reminder
    local on = db and (nat or pole) and (testing or Unlocked() or (ns.FishingPoleEquipped() and not ns.IsFishing()))
    if on then
        icon:SetTexture((GetInventoryItemTexture and GetInventoryItemTexture("player", 16)) or FALLBACK)
    end
    badge:SetShown(pole)
    frame:SetShown(on and true or false)
    natBox:SetShown(nat)
    if on and nat then
        if try == 0 then Next() elseif loaded then model:Show(); Pose() end
    else
        model:Hide()
    end
end

-- Test everything: Nat and the pole for 8 s (even without a pole equipped) and the warning.
function ns.FishingTest()
    testing = true
    ns.UpdateFishing()
    if ns.FishingIdleWarn then ns.FishingIdleWarn("idle") end
    if C_Timer and C_Timer.After then
        C_Timer.After(8, function() testing = false; ns.UpdateFishing() end)
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
    local spoken = key == "speak" and Speak(ns.L.SAY_POLE)
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
        if slot == "player" then lastFish, lastWarn = Now(), 0; ns.UpdateFishing() end
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        combatWarn = 0          -- combat starts with the pole: warn right away
        IdleTick()
        return
    end
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= 16 then return end
    if event == "PLAYER_ENTERING_WORLD" then ns.FishingPlace() end
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

---------------------------------------------------------------------------
-- Fishing skill up: blue text rising from the middle of the screen
-- ("Fishing 76"). Option db.fishingSkillUp (on). The skill-up line comes as
-- CHAT_MSG_SKILL (or CHAT_MSG_SYSTEM) with the game's SKILL_RANK_UP format
-- ("Your skill in %s has increased to %d."); only the fishing skill counts.
---------------------------------------------------------------------------
local function PatternFrom(fmt)
    fmt = fmt:gsub("%%%d%$", "%%")                         -- positional %1$s -> %s
    fmt = fmt:gsub("%%s", "\001"):gsub("%%d", "\002")    -- placeholders first
    fmt = fmt:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1") -- escape magic chars
    return "^" .. fmt:gsub("\001", "(.-)"):gsub("\002", "(%%d+)") .. "$"
end
ns.FishingPatternFrom = PatternFrom

local function FishingName()
    if GetProfessions and GetProfessionInfo then
        local fish = select(4, GetProfessions())
        if fish then
            local name = GetProfessionInfo(fish)
            if name then return name end
        end
    end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, 7620)
        if ok and n then return n end
    end
    return ns.L.FISHING_NAME
end

local up = CreateFrame("Frame", "RunAwayLittleGirlSkillUp", UIParent)
up:SetSize(400, 40)
up:SetFrameStrata("HIGH")
up:EnableMouse(false)
up:Hide()
local upText = up:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
upText:SetPoint("CENTER")
if upText.SetFont and STANDARD_TEXT_FONT then upText:SetFont(STANDARD_TEXT_FONT, 26, "OUTLINE") end
upText:SetTextColor(0.25, 0.62, 1)
up.text = upText
local RISE, LIFE, FADE = 110, 2.6, 0.9      -- px, seconds, last seconds fading
up:SetScript("OnUpdate", function(self, el)
    self.t = (self.t or 0) + (el or 0)
    local k = math.min(self.t / LIFE, 1)
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "CENTER", 0, 40 + RISE * k)
    self:SetAlpha(self.t > LIFE - FADE and math.max(0, (LIFE - self.t) / FADE) or 1)
    if self.t >= LIFE then self:Hide() end
end)

function ns.FishingSkillUp(name, rank)
    local db = RunAwayLittleGirlDB
    if db and db.fishingSkillUp == false then return end
    upText:SetText(ns.L.FISHING_UP:format(name or FishingName(), tonumber(rank) or 0))
    up.t = 0
    up:SetAlpha(1)
    up:ClearAllPoints()
    up:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    up:Show()
end

local skillPat
local sk = CreateFrame("Frame")
sk:RegisterEvent("CHAT_MSG_SKILL")
sk:RegisterEvent("CHAT_MSG_SYSTEM")
sk:SetScript("OnEvent", function(_, _, text)
    if type(text) ~= "string" or (issecretvalue and issecretvalue(text)) then return end
    if not skillPat then
        if type(SKILL_RANK_UP) ~= "string" then return end
        skillPat = PatternFrom(SKILL_RANK_UP)
    end
    local name, rank = text:match(skillPat)
    if not name then return end
    local fish = FishingName()
    if fish and name:lower() == fish:lower() then ns.FishingSkillUp(name, rank) end
end)
