-- Fishing pole reminder: a round fishing pole icon in the middle of the screen
-- while a fishing pole is equipped (main hand). Visual only: it takes no clicks,
-- so it never blocks the bobber. Option db.fishingIcon (on by default).
local _, ns = ...

local SIZE = 56
local FALLBACK = "Interface\\Icons\\INV_Fishingpole_02"
local MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"
local POLE = 20   -- Enum.ItemWeaponSubclass.Fishingpole

local frame = CreateFrame("Frame", "RunAwayLittleGirlFishing", UIParent)
frame:SetSize(SIZE, SIZE)
frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
frame:SetFrameStrata("MEDIUM")
frame:EnableMouse(false)
frame:Hide()

-- thin gold ring, then the icon on top, both round (circle MaskTexture)
local ring = frame:CreateTexture(nil, "ARTWORK", nil, 1)
ring:SetPoint("CENTER")
ring:SetSize(SIZE, SIZE)
ring:SetColorTexture(0.85, 0.68, 0.25, 0.9)
local icon = frame:CreateTexture(nil, "ARTWORK", nil, 2)
icon:SetPoint("CENTER")
icon:SetSize(SIZE - 4, SIZE - 4)
frame.icon, frame.ring = icon, ring

local function Round(tex)
    if not (frame.CreateMaskTexture and tex.AddMaskTexture) then return end
    local ok, m = pcall(frame.CreateMaskTexture, frame)
    if not ok or not m then return end
    pcall(m.SetTexture, m, MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    m:SetAllPoints(tex)
    pcall(tex.AddMaskTexture, tex, m)
end
Round(ring)
Round(icon)

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
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
ev:SetScript("OnEvent", function(_, event, slot)
    if event == "PLAYER_EQUIPMENT_CHANGED" and slot ~= 16 then return end
    ns.UpdateFishing()
end)
