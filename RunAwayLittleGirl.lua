-- Run Away Little Girl: a "rearview mirror" showing mobs that are still chasing you.
-- Activates when you are in combat, low on health and have been running
-- for a few seconds. Uses only nameplate units; every value that the
-- Midnight/Forever client may hide ("secret values") is checked first.

local ADDON, ns = ...
local L = ns.L
local PREFIX = "|cff33ff99[Run Away Little Girl]|r "
local MAX_SLOTS = 1 -- one mob is shown; the others are a "+N" badge
local TICK = 0.2

local db
local defaults = {
    secs = 2,         -- ...after running this many seconds
    sound = true,
    escapeLaugh = true, -- your character's laugh when you get away
    requireRunning = true, -- off: show at low health even when standing still
    locked = false,   -- when false the mirror can be dragged whenever it is visible
    pos = nil,        -- {left, top} relative to UIParent; nil = next to the player frame
    point = nil,
    locale = nil,
    slotW = 96,       -- size of each mob slot (changed with the resize grip)
    slotH = 120,
    fishingIcon = true, -- fishing pole icon in the middle of the screen while one is equipped
}
local MIN_SW, MIN_SH, MAX_SW, MAX_SH = 60, 80, 320, 420

---------------------------------------------------------------------------
-- Secret-safe helpers
---------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end

-- Calls fn(...) and returns its first result only if it is a usable (non-secret) value.
local function Safe(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok or v == nil or issecret(v) then return nil end
    return v
end

-- Movement: speed is hidden in combat on Forever, so also track the
-- PLAYER_STARTED_MOVING / PLAYER_STOPPED_MOVING events.
local movingEvt = false
local PlayWolf -- defined further down
local LowHealthShowing, LowHealthAvailable -- defined further down
local function IsMoving()
    local speed = Safe(GetUnitSpeed, "player")
    if speed ~= nil then return speed > 0 end
    if IsPlayerMoving then
        local m = Safe(IsPlayerMoving)
        if m ~= nil then return m and true or false end
    end
    return movingEvt
end

-- Is this nameplate unit a hostile mob chasing/attacking the player?
-- Returns: chasing (bool), targetingMe (bool|nil)
local function IsChaser(unit)
    if not Safe(UnitExists, unit) then return false end
    if Safe(UnitIsDead, unit) then return false end
    if Safe(UnitCanAttack, "player", unit) == false then return false end

    local targetingMe = Safe(UnitIsUnit, unit .. "target", "player")
    if targetingMe then return true, true end

    local threat = Safe(UnitThreatSituation, "player", unit)
    if threat and threat >= 2 then return true, false end
    if threat ~= nil then return false end -- threat known, not on us

    -- Both hidden: fall back to "hostile and in combat".
    local inCombat = Safe(UnitAffectingCombat, unit)
    if inCombat and targetingMe == nil then return true, nil end
    return false
end

local function FindChasers()
    local list = {}
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        local unit = plate.namePlateUnitToken or (plate.UnitFrame and plate.UnitFrame.unit)
        if unit then
            local chasing, onMe = IsChaser(unit)
            if chasing then list[#list + 1] = { unit = unit, onMe = onMe } end
        end
    end
    -- Mobs confirmed on you first.
    table.sort(list, function(a, b)
        if (a.onMe == true) ~= (b.onMe == true) then return a.onMe == true end
        return a.unit < b.unit
    end)
    return list
end

local function Play(kit)
    if db.sound and kit then PlaySound(kit, "Master") end
end

---------------------------------------------------------------------------
-- Mirror frame
---------------------------------------------------------------------------
local SLOT_W, SLOT_H = defaults.slotW, defaults.slotH
local shownSlots = 1
local mirror = CreateFrame("Frame", "RunAwayLittleGirlMirror", UIParent, "BackdropTemplate")
mirror:SetSize(SLOT_W * MAX_SLOTS + 24, SLOT_H + 40)
mirror:SetFrameStrata("HIGH")

-- Default spot: right under the player's unit frame (follows it if moved in Edit Mode).
local function DefaultPosition()
    mirror:ClearAllPoints()
    if PlayerFrame then
        mirror:SetPoint("TOPLEFT", PlayerFrame, "BOTTOMLEFT", 10, -4)
    else
        mirror:SetPoint("TOP", UIParent, "TOP", 0, -40)
    end
end

local function ApplyPosition()
    if db and db.pos then
        mirror:ClearAllPoints()
        mirror:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", db.pos[1], db.pos[2])
    else
        DefaultPosition()
    end
end
DefaultPosition()
mirror:SetClampedToScreen(true)
mirror:SetMovable(true)
mirror:EnableMouse(false)
mirror:RegisterForDrag("LeftButton")
mirror:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 20,
    insets = { left = 5, right = 5, top = 5, bottom = 5 },
})
mirror:SetBackdropColor(0.08, 0.12, 0.16, 0.85)
mirror:Hide()

mirror:SetScript("OnDragStart", function(self) if not db.locked then self:StartMoving() end end)
mirror:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    db.pos = { self:GetLeft(), self:GetTop() }
    ApplyPosition()
end)

-- Subtle "glass" sheen
local sheen = mirror:CreateTexture(nil, "BORDER")
sheen:SetPoint("TOPLEFT", 6, -6)
sheen:SetPoint("BOTTOMRIGHT", -6, 6)
sheen:SetColorTexture(1, 1, 1, 1)
sheen:SetGradient("VERTICAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, 0.07))

local title = mirror:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -12)

local slots = {}
for i = 1, MAX_SLOTS do
    local s = CreateFrame("Frame", nil, mirror)

    s.model = CreateFrame("PlayerModel", nil, s)
    s.model:SetPoint("TOPLEFT")
    s.model:SetPoint("TOPRIGHT")

    s.name = s:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    s.name:SetPoint("TOPLEFT", s.model, "BOTTOMLEFT", 0, -2)
    s.name:SetPoint("TOPRIGHT", s.model, "BOTTOMRIGHT", 0, -2)
    s.name:SetWordWrap(false)

    s.hp = CreateFrame("StatusBar", nil, s)
    s.hp:SetPoint("TOPLEFT", s.name, "BOTTOMLEFT", 0, -2)
    s.hp:SetPoint("TOPRIGHT", s.name, "BOTTOMRIGHT", 0, -2)
    s.hp:SetHeight(8)
    s.hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    s.hp:SetStatusBarColor(0.85, 0.15, 0.15)
    local bg = s.hp:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)

    s.tag = s:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
    s.tag:SetPoint("TOP", s.model, "TOP", 0, -2)

    -- "+N" badge: how many more mobs are chasing you besides this one
    s.badge = CreateFrame("Frame", nil, s)
    s.badge:SetSize(24, 24)
    s.badge:SetPoint("TOPRIGHT", s.model, "TOPRIGHT", 2, 2)
    s.badge:SetFrameLevel(s.model:GetFrameLevel() + 5)
    local dot = s.badge:CreateTexture(nil, "ARTWORK")
    dot:SetAllPoints()
    dot:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    dot:SetVertexColor(0.8, 0.05, 0.05, 0.95)
    s.badge.text = s.badge:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    s.badge.text:SetPoint("CENTER", 0, 0)
    s.badge:Hide()

    s:Hide()
    slots[i] = s
end

local function FillSlot(s, unit, onMe)
    if s.unit ~= unit or s.dirty then
        s.unit, s.dirty = unit, false
        pcall(s.model.SetUnit, s.model, unit)
        pcall(s.model.SetCamDistanceScale, s.model, 1.3)
    end
    -- Secret values may be passed straight to UI widgets: no math on them here.
    s.name:SetText(UnitName(unit) or "?")
    pcall(s.hp.SetMinMaxValues, s.hp, 0, UnitHealthMax(unit) or 1)
    pcall(s.hp.SetValue, s.hp, UnitHealth(unit) or 0)
    s.tag:SetText(onMe and L.TARGETING or "")
    s:Show()
end

local sizing = false

-- Applies the slot size to every slot and sizes the mirror for n slots.
local function LayoutSlots(n)
    shownSlots = math.max(n, 1)
    for i, s in ipairs(slots) do
        s:ClearAllPoints()
        s:SetSize(SLOT_W - 6, SLOT_H)
        s:SetPoint("TOPLEFT", 12 + (i - 1) * SLOT_W, -30)
        s.model:SetHeight(SLOT_H - 34)
    end
    if not sizing then
        mirror:SetWidth(SLOT_W * shownSlots + 24)
        mirror:SetHeight(n > 0 and (SLOT_H + 40) or 40)
    end
end

-- Resize grip: dragging changes the slot size (models scale with it).
mirror:SetResizable(true)
if mirror.SetResizeBounds then
    mirror:SetResizeBounds(MIN_SW + 24, MIN_SH + 40, MAX_SW * MAX_SLOTS + 24, MAX_SH + 40)
elseif mirror.SetMinResize then
    mirror:SetMinResize(MIN_SW + 24, MIN_SH + 40)
    mirror:SetMaxResize(MAX_SW * MAX_SLOTS + 24, MAX_SH + 40)
end
local grip = CreateFrame("Button", nil, mirror)
grip:SetSize(16, 16)
grip:SetPoint("BOTTOMRIGHT", -4, 4)
grip:SetFrameLevel(mirror:GetFrameLevel() + 10)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:Hide()

local function SlotSizeFromMirror()
    local w = (mirror:GetWidth() - 24) / shownSlots
    local h = mirror:GetHeight() - 40
    SLOT_W = math.floor(math.min(MAX_SW, math.max(MIN_SW, w)) + 0.5)
    SLOT_H = math.floor(math.min(MAX_SH, math.max(MIN_SH, h)) + 0.5)
end

mirror:SetScript("OnSizeChanged", function()
    if sizing then
        SlotSizeFromMirror()
        LayoutSlots(shownSlots)
    end
end)
grip:SetScript("OnMouseDown", function(_, button)
    if button ~= "LeftButton" or db.locked then return end
    sizing = true
    mirror:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function()
    if not sizing then return end
    mirror:StopMovingOrSizing()
    SlotSizeFromMirror()
    sizing = false
    db.slotW, db.slotH = SLOT_W, SLOT_H
    LayoutSlots(shownSlots)
    if db.pos then db.pos = { mirror:GetLeft(), mirror:GetTop() } end
    ApplyPosition()
end)

---------------------------------------------------------------------------
-- State machine
---------------------------------------------------------------------------
local runningSince
local active, testMode, moveMode = false, false, false
local lastChasers = {}
ns.IsTesting = function() return testMode end

-- Close button, visible only in test / positioning mode.
local closeBtn = CreateFrame("Button", nil, mirror, "UIPanelCloseButton")
closeBtn:SetSize(22, 22)
closeBtn:SetPoint("TOPRIGHT", -2, -2)
closeBtn:SetFrameLevel(mirror:GetFrameLevel() + 20)
closeBtn:Hide()
closeBtn:SetScript("OnClick", function()
    if testMode then SlashCmdList.RUNAWAYLITTLEGIRL("test") end
    if moveMode then SlashCmdList.RUNAWAYLITTLEGIRL("move") end
end)
closeBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(moveMode and L.CLOSE_MOVE or L.CLOSE_TEST)
    GameTooltip:Show()
end)
closeBtn:SetScript("OnLeave", GameTooltip_Hide)
local escapedUntil

local function UpdateRunning()
    -- Only movement inside combat counts (walking up to a mob before the pull doesn't).
    if Safe(UnitAffectingCombat, "player") and IsMoving() then
        runningSince = runningSince or GetTime()
    else
        runningSince = nil
    end
end

local function IsFleeing()
    return runningSince ~= nil and GetTime() - runningSince >= db.secs
end

local warnedNoWarning = false

-- Trigger: the game's own low-health warning (red screen edges). The game decides
-- when you are low on health; the addon only listens to it.
local function ShouldActivate()
    if not Safe(UnitAffectingCombat, "player") then return false end
    if db.requireRunning and not IsFleeing() then return false end
    if not LowHealthAvailable() then
        if not warnedNoWarning then
            warnedNoWarning = true
            print(PREFIX .. L.NO_WARNING)
        end
        return false
    end
    return LowHealthShowing()
end

local function ApplyAlpha()
    mirror:EnableMouse(not db.locked)
    pcall(mirror.SetAlpha, mirror, 1)
    for _, sl in ipairs(slots) do pcall(sl.model.SetAlpha, sl.model, 1) end
end

local function Render(chasers, header)
    title:SetText(header)
    local n = math.min(#chasers, MAX_SLOTS)
    for i = 1, MAX_SLOTS do
        local c = chasers[i]
        if c and i <= n then
            FillSlot(slots[i], c.unit, c.onMe)
        else
            slots[i]:Hide()
            slots[i].unit = nil
        end
    end
    -- the list is sorted with the mob on you first; the rest become a badge
    local more = #chasers - n
    local last = slots[n]
    for _, sl in ipairs(slots) do sl.badge:Hide() end
    if last and more > 0 then
        last.badge.text:SetText("+" .. more)
        last.badge:Show()
    end
    LayoutSlots(n)
    mirror:Show()
    ApplyAlpha()
end

---------------------------------------------------------------------------
-- Diagnostic log (saved in RunAwayLittleGirlDB.log, last 40 entries, 1 per second in combat)
---------------------------------------------------------------------------
local function Raw(fn, ...)
    if not fn then return "noapi" end
    local ok, v = pcall(fn, ...)
    if not ok then return "err" end
    if v == nil then return "nil" end
    if issecret(v) then return "SECRET" end
    if type(v) == "number" then return ("%.1f"):format(v) end
    return tostring(v)
end

local lastLog = 0
local function LogState(decision)
    if not db.debugLog then return end
    local now = GetTime()
    if now - lastLog < 1 then return end
    lastLog = now
    local plates = C_NamePlate.GetNamePlates() or {}
    local p1 = plates[1] and (plates[1].namePlateUnitToken or (plates[1].UnitFrame and plates[1].UnitFrame.unit))
    local entry = ("t=%.0f warning=%s moveEvt=%s isMoving=%s | combat=%s run=%.1f | plates=%d chasers=%d | p1=%s targetMe=%s threat=%s | %s"):format(
        now, tostring(LowHealthShowing()), tostring(movingEvt), Raw(IsPlayerMoving),
        Raw(UnitAffectingCombat, "player"), runningSince and (now - runningSince) or 0,
        #plates, #FindChasers(), tostring(p1),
        p1 and Raw(UnitIsUnit, p1 .. "target", "player") or "-",
        p1 and Raw(UnitThreatSituation, "player", p1) or "-",
        decision)
    db.log = db.log or {}
    table.insert(db.log, entry)
    while #db.log > 40 do table.remove(db.log, 1) end
end

---------------------------------------------------------------------------
-- "Run away, little girl! Run away!" (Big Bad Wolf, Karazhan opera)
---------------------------------------------------------------------------
-- Tried in order: Deadly Boss Mods' copy (classic clients may lack the file),
-- the game's own file, then a standard alert.
local WOLF_SOURCES = {
    "Interface\\AddOns\\DBM-Core\\sounds\\ClassicSupport\\HoodWolfTransformPlayer01.ogg",
    552035, -- sound/creature/hoodwolf/hoodwolftransformplayer01.ogg
}

function PlayWolf()
    if not db.sound then return end
    for _, src in ipairs(WOLF_SOURCES) do
        local ok, willPlay = pcall(PlaySoundFile, src, "Master")
        if ok and willPlay then return end
    end
    if SOUNDKIT and SOUNDKIT.RAID_WARNING then PlaySound(SOUNDKIT.RAID_WARNING, "Master") end
end
ns.PlayWolf = function() local s = db.sound; db.sound = true; PlayWolf(); db.sound = s end

---------------------------------------------------------------------------
-- Blizzard's own low-health warning (red screen edges) is driven by the game's
-- secure code, which can read your health. When it fires during a chase with
-- hidden health, the mirror is already visible, so the wolf line fits.
---------------------------------------------------------------------------
local lowHealthHooked = false

local function OnLowHealthWarning() end -- activation happens in Tick (every 0.2 s)

function LowHealthShowing()
    local f = _G.LowHealthFrame
    if not f then return false end
    local shown = Safe(f.IsVisible, f)
    return shown == true
end

function LowHealthAvailable()
    return _G.LowHealthFrame ~= nil
end

local function HookLowHealth()
    if lowHealthHooked then return end
    local f = _G.LowHealthFrame
    if f and f.HookScript then
        pcall(f.HookScript, f, "OnShow", OnLowHealthWarning)
        lowHealthHooked = true
    end
    for _, name in ipairs({ "LowHealthFrame_StartFlashing", "LowHealthFrame_Flash", "UIParent_UpdateLowHealthFrame" }) do
        if type(_G[name]) == "function" then
            hooksecurefunc(name, function() if LowHealthShowing() then OnLowHealthWarning() end end)
            lowHealthHooked = true
        end
    end
end

---------------------------------------------------------------------------
-- Your character's laugh (classic race/gender voice files, by FileDataID)
---------------------------------------------------------------------------
local LAUGH = {
    Human    = { [2] = 540739, [3] = 540540 },
    Dwarf    = { [2] = 539883, [3] = 539798 },
    NightElf = { [2] = 540945, [3] = 540877 },
    Gnome    = { [2] = 540267, [3] = 540268 },
    Orc      = { [2] = 541230, [3] = 541153 },
    Scourge  = { [2] = 542595, [3] = 542518 },
    Tauren   = { [2] = 542898, [3] = 542806 },
    Troll    = { [2] = 543094, [3] = 543091 },
    BloodElf = { [2] = 539287, [3] = 539267 },
    Draenei  = { [2] = 539604, [3] = 539719 },
    Goblin   = { [2] = 541902, [3] = 541840 },
    Worgen   = { [2] = 542246, [3] = 542077 },
    Pandaren = { [2] = 641324, [3] = 644720 },
}

local function PlayLaugh()
    local _, race = UnitRace("player")
    local sex = UnitSex("player")
    local id = race and LAUGH[race] and LAUGH[race][sex]
    if id then
        PlaySoundFile(id, "Master")
    elseif SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE then
        PlaySound(SOUNDKIT.IG_QUEST_LIST_COMPLETE, "Master") -- unknown race: old sound
    end
end
ns.PlayLaugh = PlayLaugh

local function Tick()
    if not db then return end
    closeBtn:SetShown(testMode or (moveMode and not active))

    if testMode then
        local unit = Safe(UnitExists, "target") and "target" or "player"
        Render({ { unit = unit, onMe = true } }, L.TEST)
        return
    end

    local now = GetTime()
    UpdateRunning()
    if not active then
        local should = ShouldActivate()
        if should then
            local chasers = FindChasers()
            if #chasers > 0 then
                active = true
                -- The line plays only when we know the mirror is really visible,
                -- i.e. when your health can be read. With hidden health the game
                -- decides visibility on its own, so the addon stays silent.
                PlayWolf()
            end
        end
        if Safe(UnitAffectingCombat, "player") then
            LogState(should and (active and "SHOW" or "no-chasers") or "conditions-not-met")
        end
    elseif Safe(UnitAffectingCombat, "player") then
        LogState("active")
    end

    if active then
        local chasers = FindChasers()
        local inCombat = Safe(UnitAffectingCombat, "player")
        if #chasers == 0 or not inCombat then
            active = false
            runningSince = nil
            -- A real escape = mobs gave up while you're alive, not a kill or a death.
            local killed = false
            for _, u in ipairs(lastChasers) do
                if Safe(UnitExists, u) and Safe(UnitIsDead, u) then killed = true end
            end
            wipe(lastChasers)
            if killed or Safe(UnitIsDeadOrGhost, "player") then
                mirror:Hide()
                return
            end
            escapedUntil = now + 2.5
            if db.escapeLaugh then PlayLaugh() else Play(SOUNDKIT and SOUNDKIT.IG_QUEST_LIST_COMPLETE) end
            Render({}, "|cff33ff33" .. L.ESCAPED .. "|r")
        else
            wipe(lastChasers)
            for i, c in ipairs(chasers) do lastChasers[i] = c.unit end
            Render(chasers, "|cffff4040" .. L.CHASING:format(#chasers) .. "|r")
        end
        return
    end

    if escapedUntil and now < escapedUntil then return end
    escapedUntil = nil
    if moveMode then -- positioning/resizing preview
        Render({ { unit = "player" } }, L.MOVE_TITLE)
        return
    end
    mirror:Hide()
end

C_Timer.NewTicker(TICK, Tick)

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("NAME_PLATE_UNIT_ADDED")
events:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_STARTED_MOVING")
events:RegisterEvent("PLAYER_STOPPED_MOVING")
events:RegisterEvent("PLAYER_ENTERING_WORLD")

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        RunAwayLittleGirlDB = RunAwayLittleGirlDB or {}
        db = RunAwayLittleGirlDB
        for k, v in pairs(defaults) do
            if db[k] == nil then db[k] = v end
        end
        db.always, db.hp = nil, nil -- options removed (1.4 / 2.4)
        db.escapeEmote, db.emoteLog = nil, nil -- /lol replaced by the laugh sound in 1.7
        db.debugLog, db.log = nil, nil -- diagnostics off (use /mrv log to turn on)
        if not db.migrated12 then -- v1.0/1.1 saved locked=true and an old position format
            db.locked, db.point, db.migrated12 = false, nil, true
        end
        ns:ApplyLocale(db.locale)
        if ns.BuildOptions and not ns.optionsCategory then ns:BuildOptions(db) end
        mirror:EnableMouse(not db.locked)
        grip:SetShown(not db.locked)
        SLOT_W, SLOT_H = db.slotW, db.slotH
        LayoutSlots(1)
        ApplyPosition()
    elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
        -- Nameplate tokens get reused for other mobs: reload the model.
        for _, s in ipairs(slots) do
            if s.unit == arg1 then s.dirty = true end
        end
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat starts: the run timer starts from now, never from before the pull.
        runningSince = movingEvt and GetTime() or nil
    elseif event == "PLAYER_STARTED_MOVING" then
        movingEvt = true
    elseif event == "PLAYER_STOPPED_MOVING" then
        movingEvt = false
    elseif event == "PLAYER_ENTERING_WORLD" then
        HookLowHealth()
    elseif event == "PLAYER_REGEN_ENABLED" then
    end
end)

---------------------------------------------------------------------------
-- Commands
---------------------------------------------------------------------------
local function OnOff(v) return v and L.ON or L.OFF end

local function SetLocked(locked)
    db.locked = locked
    mirror:EnableMouse(not locked)
    grip:SetShown(not locked)
end
ns.SetLocked = SetLocked

SLASH_RUNAWAYLITTLEGIRL1 = "/rv"
SLASH_RUNAWAYLITTLEGIRL2 = "/runawaylittlegirl"
SLASH_RUNAWAYLITTLEGIRL3 = "/retrovisor"
SLASH_RUNAWAYLITTLEGIRL4 = "/mrv"
SLASH_RUNAWAYLITTLEGIRL5 = "/runaway"
SLASH_RUNAWAYLITTLEGIRL6 = "/mrunaway"
SlashCmdList.RUNAWAYLITTLEGIRL = function(msg)
    msg = strtrim((msg or ""):lower())
    local cmd, arg = msg:match("^(%S*)%s*(.-)$")

    if cmd == "test" then
        testMode = not testMode
        print(PREFIX .. (testMode and L.TEST_ON or L.TEST_OFF))
        if not testMode then mirror:Hide() end
        if ns.optionsPanel and ns.optionsPanel:IsVisible() then ns.optionsPanel:Refresh() end
    elseif cmd == "move" then
        moveMode = not moveMode
        if moveMode then SetLocked(false) end
        print(PREFIX .. (moveMode and L.MOVE_ON or L.MOVE_OFF))
        if not moveMode then mirror:Hide() end
    elseif cmd == "log" then
        db.debugLog = not db.debugLog
        if db.debugLog then db.log = {} end
        print(PREFIX .. "diagnostic log: " .. (db.debugLog and "ON (saved on /reload)" or "OFF"))
    elseif cmd == "debug" then
        print(PREFIX .. ("low-health warning: frame=%s hooked=%s showing=%s"):format(
            tostring(_G.LowHealthFrame ~= nil), tostring(lowHealthHooked), tostring(LowHealthShowing())))
        print(PREFIX .. ("combat=%s moving=%s running=%.1fs | secs=%.1f onlyRunning=%s locked=%s"):format(
            tostring(Safe(UnitAffectingCombat, "player")), tostring(IsMoving()),
            runningSince and (GetTime() - runningSince) or 0, db.secs, tostring(db.requireRunning), tostring(db.locked)))
        local n = 0
        for _ in ipairs(FindChasers()) do n = n + 1 end
        print(PREFIX .. ("nameplates=%d chasers=%d active=%s test=%s move=%s"):format(
            #(C_NamePlate.GetNamePlates() or {}), n, tostring(active), tostring(testMode), tostring(moveMode)))
    elseif cmd == "lock" then
        SetLocked(not db.locked)
        print(PREFIX .. (db.locked and L.LOCKED or L.UNLOCKED))
    elseif cmd == "reset" then
        db.pos = nil
        db.slotW, db.slotH = defaults.slotW, defaults.slotH
        SLOT_W, SLOT_H = db.slotW, db.slotH
        LayoutSlots(shownSlots)
        ApplyPosition()
        print(PREFIX .. L.RESET)
    elseif cmd == "secs" and tonumber(arg) then
        db.secs = math.max(0, tonumber(arg))
        print(PREFIX .. L.SET_SECS:format(db.secs))
    elseif cmd == "sound" then
        db.sound = not db.sound
        print(PREFIX .. L.SET_SOUND:format(OnOff(db.sound)))
    elseif cmd == "status" then
        print(PREFIX .. L.STATUS:format(db.secs, OnOff(db.sound)))
    elseif cmd == "config" or cmd == "options" or cmd == "opcoes" then
        ns:OpenOptions()
    elseif cmd == "lang" then
        local available = table.concat(ns:AvailableLocales(), ", ")
        local function Name(c) return ns.Locales[c]._name end
        if arg == "" then
            print(PREFIX .. L.HELP4:format(available))
        elseif arg == "auto" then
            db.locale = nil
            local c = ns:ApplyLocale(nil)
            print(PREFIX .. L.LANG_AUTO:format(Name(c), c))
        else
            local code
            for c in pairs(ns.Locales) do
                if c:lower() == arg then code = c end
            end
            if code then
                db.locale = code
                ns:ApplyLocale(code)
                print(PREFIX .. L.LANG_SET:format(Name(code), code))
            else
                print(PREFIX .. L.LANG_UNKNOWN:format(arg, available))
            end
        end
    else
        print(PREFIX .. L.STATUS:format(db.secs, OnOff(db.sound)))
        print(PREFIX .. L.HELP1)
        print(PREFIX .. L.HELP5)
        print(PREFIX .. L.HELP_CONFIG)
        print(PREFIX .. L.HELP2)
        print(PREFIX .. L.HELP3)
        print(PREFIX .. L.HELP4:format(table.concat(ns:AvailableLocales(), ", ")))
    end
end

function RunAwayLittleGirl_OnAddonCompartmentClick(_, button)
    if button == "RightButton" then ns:OpenOptions() else SlashCmdList.RUNAWAYLITTLEGIRL("test") end
end
