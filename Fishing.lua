-- Fishing pole reminder: Nat Pagle (animated, the game's own NPC model) and a
-- round fishing pole icon in the middle of the screen while a fishing pole is
-- equipped (main hand). Visual only: it takes no clicks, so it never blocks the
-- bobber. Option db.fishingIcon (on by default).
--
-- The model is loaded by NPC id (12919 = Nat Pagle, Dustwallow Marsh; later
-- Nat Pagles as fallbacks); models load asynchronously, each try gets 2 s.
-- If none loads, only the pole icon shows. What happened is kept in
-- RunAwayLittleGirlDB.natPagle (SavedVariables) for diagnostics.
local _, ns = ...

local W, H = 120, 150          -- Nat's model
local SIZE = 44                -- pole icon
local FALLBACK = "Interface\\Icons\\INV_Fishingpole_02"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POLE = 20                -- Enum.ItemWeaponSubclass.Fishingpole
local TRIES = { 12919, 63721, 102639 }
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
    db.natPagle = { try = try, npc = TRIES[try], what = what, t = time and time() or 0 }
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
    local id = TRIES[try]
    if not id then
        Note("none loaded")
        model:Hide()
        return
    end
    if model.ClearModel then pcall(model.ClearModel, model) end
    local ok = pcall(model.SetCreature, model, id)
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

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, event, slot)
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= 16 then return end
    ns.UpdateFishing()
end)
