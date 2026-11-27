-- Theme: Alliance (blue) or Horde (red) colors for the addon's windows.
-- (Same file in every Milkshakson addon; each keeps its own settings.theme.)
-- settings.theme = "auto" (the character's faction), "alliance" or "horde".
-- Windows register what to paint with Theme:Skin(); Theme:Apply() repaints all.
local _, ns = ...
local T = {}
ns.Theme = T

T.THEMES = {
    alliance = {
        -- near-black background (a touch of blue): the strong blue is for the
        -- border, title, tabs and buttons, so they stand out
        bg = { 0.05, 0.06, 0.09, 0.94 }, border = { 0.35, 0.55, 1, 1 },
        title = { 0.6, 0.8, 1 }, accent = { 0.4, 0.65, 1 }, list = { 0.025, 0.03, 0.045, 0.9 },
        crest = "Interface\\Timer\\Alliance-Logo",
        -- flat blue buttons in place of the game's red art: bottom / top of the
        -- gradient, border; pressed and disabled are derived
        -- buttons: the list box's dark color, no border
        -- (fill = exactly the list box color; user: "o azul escuro, tal qual o fundo")
        button = { fill = { 0.025, 0.03, 0.045 }, hover = { 0.05, 0.065, 0.10 } },   -- no border (user)
    },
    horde = {
        bg = { 0.08, 0.05, 0.05, 0.94 }, border = { 0.9, 0.25, 0.15, 1 },
        title = { 1, 0.45, 0.3 }, accent = { 1, 0.35, 0.2 }, list = { 0.045, 0.03, 0.03, 0.9 },
        crest = "Interface\\Timer\\Horde-Logo",
    },
}

local settings
local skinned = {}   -- { obj, kind, alpha }

function T:Init(s)
    settings = s
    if settings.theme == nil then settings.theme = "auto" end
end

function T:Key()
    local c = settings and settings.theme or "auto"
    if c == "alliance" or c == "horde" then return c end
    local f = UnitFactionGroup and UnitFactionGroup("player")
    return f == "Horde" and "horde" or "alliance"   -- (neutral: Alliance colors)
end

function T:Get() return T.THEMES[T:Key()] end

-- A game button (UIPanelButtonTemplate) in the theme: its red art hidden and a
-- flat gradient + border drawn instead (Alliance), or the original art (Horde).
local function Fill(c)
    local th = T:Get()
    local bt = th.button
    local f, e = rawget(c, "themeFill"), rawget(c, "themeEdge")
    if not (f and e) then return end
    local hl = c.GetHighlightTexture and c:GetHighlightTexture()
    if not bt then
        f:Hide(); e:Hide()
        if hl then hl:SetAlpha(1) end
        return
    end
    f:Show(); e:Show()
    if hl then hl:SetAlpha(0) end   -- (our own hover instead of the game's glow)
    if c.IsEnabled and not c:IsEnabled() then
        f:SetColorTexture(bt.fill[1], bt.fill[2], bt.fill[3], 1)
        if bt.edge then e:SetColorTexture(0.3, 0.32, 0.38, 1) else e:Hide() end
        return
    end
    local over = rawget(c, "themeOver")
    local fc = over and bt.hover or bt.fill
    local k = rawget(c, "themeDown") and 0.6 or 1
    f:SetColorTexture(fc[1] * k, fc[2] * k, fc[3] * k, 1)
    local ec = over and bt.edgeHover or bt.edge
    if ec then e:SetColorTexture(ec[1], ec[2], ec[3], 1) else e:Hide() end
end

function T:SkinButton(c, th)
    th = th or T:Get()
    if not rawget(c, "themeFill") then
        c.themeEdge = c:CreateTexture(nil, "BACKGROUND", nil, 6)
        c.themeEdge:SetPoint("TOPLEFT", 1, -1)
        c.themeEdge:SetPoint("BOTTOMRIGHT", -1, 1)
        c.themeFill = c:CreateTexture(nil, "BACKGROUND", nil, 7)
        c.themeFill:SetPoint("TOPLEFT", 2, -2)
        c.themeFill:SetPoint("BOTTOMRIGHT", -2, 2)
        if c.HookScript then
            c:HookScript("OnMouseDown", function(self) self.themeDown = true; Fill(self) end)
            c:HookScript("OnMouseUp", function(self) self.themeDown = nil; Fill(self) end)
            c:HookScript("OnEnter", function(self) self.themeOver = true; Fill(self) end)
            c:HookScript("OnLeave", function(self) self.themeOver = nil; self.themeDown = nil; Fill(self) end)
            c:HookScript("OnEnable", Fill)
            c:HookScript("OnDisable", Fill)
            c:HookScript("OnShow", Fill)
        end
    end
    local a = th.button and 0 or 1
    for _, t in ipairs({ c.Left, c.Middle, c.Right }) do t:SetAlpha(a) end
    Fill(c)
end

local function Paint(x)
    local th, o, kind = T:Get(), x.obj, x.kind
    if kind == "window" or kind == "box" then
        if o.SetBackdropColor then
            local c = kind == "box" and th.list or th.bg
            o:SetBackdropColor(c[1], c[2], c[3], x.bgAlpha or c[4])
            local b = th.border
            local k = kind == "box" and 0.6 or 1
            o:SetBackdropBorderColor(b[1] * k, b[2] * k, b[3] * k, b[4])
        end
        if kind == "window" and x.alpha ~= 0 then
            -- the faction crest, very faint, behind the content
            if not rawget(o, "crest") then
                o.crest = o:CreateTexture(nil, "BACKGROUND", nil, 1)
                o.crest:SetSize(x.alpha or 150, x.alpha or 150)
                o.crest:SetPoint("CENTER", o, "CENTER", 0, 0)
            end
            local ok = o.crest:SetTexture(th.crest)
            o.crest:SetAlpha(0.07)
            o.crest:SetShown(ok ~= false)
        end
    elseif kind == "tree" then
        -- every red game button (UIPanelButtonTemplate: Left/Middle/Right) under it;
        -- tabs (they have LeftActive) keep their own art
        local seen = {}
        local function Walk(f, depth)
            if depth > 8 or seen[f] then return end
            seen[f] = true
            for _, c in ipairs({ f:GetChildren() }) do
                if type(c) == "table" then
                    local l, m, r = rawget(c, "Left"), rawget(c, "Middle"), rawget(c, "Right")
                    local isButton = c.GetObjectType and c:GetObjectType() == "Button"
                    if isButton and l and m and r and not rawget(c, "LeftActive") and l.SetAlpha then
                        T:SkinButton(c, th)
                    end
                    Walk(c, depth + 1)
                end
            end
        end
        Walk(o, 0)
    elseif kind == "title" then
        o:SetTextColor(th.title[1], th.title[2], th.title[3])
    elseif kind == "accent" then
        o:SetColorTexture(th.accent[1], th.accent[2], th.accent[3], x.alpha or 1)
    end
end

-- kind: "window" (backdrop + crest; alpha = crest size, 0 = no crest; bgAlpha
-- keeps the window's own transparency), "box" (list backdrop),
-- "tree" (game buttons inside a frame; register once its buttons exist),
-- "title" (font string), "accent" (texture; alpha = its alpha)
function T:Skin(obj, kind, alpha, bgAlpha)
    if not obj then return end
    local x = { obj = obj, kind = kind, alpha = alpha, bgAlpha = bgAlpha }
    skinned[#skinned + 1] = x
    pcall(Paint, x)
end

function T:Apply()
    for _, x in ipairs(skinned) do pcall(Paint, x) end
end

-- the faction is only known for sure once the character is in the world
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function() T:Apply() end)
