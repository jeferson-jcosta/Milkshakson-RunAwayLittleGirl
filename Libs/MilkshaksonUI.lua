-- MilkshaksonUI: tiny shared options toolkit for the Milkshakson- addons.
-- Every Milkshakson addon ships this same file; the newest version wins.
-- Creates one "Milkshakson" category under Options > AddOns, with one
-- sub-page per addon. Falls back to a standalone window if the Settings
-- API is unavailable.

local VERSION = 7
local lib = _G.MilkshaksonUI
if lib and (lib.version or 0) >= VERSION then return end
lib = lib or {}
lib.version = VERSION
_G.MilkshaksonUI = lib

local PT = GetLocale() == "ptBR"

-- Donation info shown on every Milkshakson options page. Empty = hidden.
lib.SUPPORT = {
    paypal = "https://www.paypal.com/donate/?business=Q72ZP8CCJ6PFA&currency_code=BRL",
    pix = "2d8f2ae7-76df-497d-9afa-cb7d12dd73f9",
}

---------------------------------------------------------------------------
-- Categories
---------------------------------------------------------------------------
function lib:GetParent()
    if self.parent then return self.parent end
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return nil end
    local f = CreateFrame("Frame")
    local t = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText("Milkshakson")
    local d = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    d:SetText(PT and "Escolha um addon na lista à esquerda." or "Pick an addon in the list on the left.")
    f.y = -70
    f.refreshers = {}
    function f:Refresh() end
    self:Support(f)
    local cat = Settings.RegisterCanvasLayoutCategory(f, "Milkshakson")
    Settings.RegisterAddOnCategory(cat)
    self.parent = cat
    return cat
end

local function Standalone(panel, name)
    local w = CreateFrame("Frame", nil, UIParent, "BasicFrameTemplateWithInset")
    w:SetSize(460, 520)
    w:SetPoint("CENTER")
    w:SetMovable(true)
    w:EnableMouse(true)
    w:RegisterForDrag("LeftButton")
    w:SetScript("OnDragStart", w.StartMoving)
    w:SetScript("OnDragStop", w.StopMovingOrSizing)
    w:SetFrameStrata("DIALOG")
    w:Hide()
    if type(w.TitleText) == "table" then w.TitleText:SetText("Milkshakson - " .. name) end
    panel:SetParent(w)
    panel:SetPoint("TOPLEFT", 4, -24)
    panel:SetPoint("BOTTOMRIGHT", -4, 4)
    return { standalone = w }
end

function lib:Register(panel, name)
    local frame = panel.outer or panel
    if panel.Refresh then panel:Refresh() end -- checkboxes reflect saved values right away
    local parent = self:GetParent()
    if parent and Settings.RegisterCanvasLayoutSubcategory then
        local ok, sub = pcall(Settings.RegisterCanvasLayoutSubcategory, parent, frame, name)
        if ok and sub then return sub end
    end
    return Standalone(frame, name)
end

function lib:Open(cat)
    if not cat then return end
    if cat.standalone then
        cat.standalone:SetShown(not cat.standalone:IsShown())
        return
    end
    if InCombatLockdown() then
        print("|cff33ff99[Milkshakson]|r " .. (PT and "as opções abrem fora de combate." or "options open out of combat."))
        return
    end
    local id = cat.GetID and cat:GetID() or cat.ID
    if not pcall(Settings.OpenToCategory, id) then pcall(Settings.OpenToCategory, cat) end
end

---------------------------------------------------------------------------
-- Widgets (simple top-down layout; p.y is the cursor)
---------------------------------------------------------------------------
local function Tooltip(frame, title, text)
    if not text then return end
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        GameTooltip:AddLine(text, nil, nil, nil, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", GameTooltip_Hide)
end

function lib:NewPanel(title, desc)
    -- Outer frame is what gets registered; content scrolls inside it (mouse wheel).
    local outer = CreateFrame("Frame")
    outer:Hide() -- so OnShow fires every time the options page is opened
    local scroll = CreateFrame("ScrollFrame", nil, outer)
    scroll:SetPoint("TOPLEFT")
    scroll:SetPoint("BOTTOMRIGHT")
    scroll:EnableMouseWheel(true)
    local p = CreateFrame("Frame", nil, scroll)
    p:SetSize(600, 800)
    scroll:SetScrollChild(p)
    scroll:SetScript("OnSizeChanged", function(_, w) p:SetWidth(w) end)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local max = math.max(0, p:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(math.min(max, math.max(0, self:GetVerticalScroll() - delta * 40)))
    end)
    p.outer = outer
    p.refreshers = {}
    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16)
    t:SetText(title)
    local d = p:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
    d:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    d:SetJustifyH("LEFT")
    d:SetText(desc or "")
    p.y = -64
    outer:SetScript("OnShow", function() p:SetHeight(-p.y + 24); p:Refresh() end)
    -- The Settings panel also calls these on canvas pages.
    outer.OnRefresh = function() p:Refresh() end
    outer.OnCommit = function() end
    outer.OnDefault = function() end
    function p:Refresh()
        self.refreshing = true
        for _, fn in ipairs(self.refreshers) do
            local ok, err = pcall(fn)
            if not ok then geterrorhandler()(err) end
        end
        self.refreshing = false
    end
    return p
end

function lib:Section(p, text)
    p.y = p.y - 8
    local fs = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fs:SetPoint("TOPLEFT", 16, p.y)
    fs:SetText(text)
    local line = p:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("LEFT", fs, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    p.y = p.y - 22
end

function lib:Check(p, label, tip, get, set)
    local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", 18, p.y)
    local fs = type(cb.Text) == "table" and cb.Text or nil
    if not fs then
        fs = cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    end
    fs:SetFontObject(GameFontHighlight)
    fs:SetText(label)
    cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    Tooltip(cb, label, tip)
    p.refreshers[#p.refreshers + 1] = function() cb:SetChecked(get() and true or false) end
    p.y = p.y - 28
    return cb
end

function lib:Slider(p, label, minV, maxV, step, fmt, get, set, tip)
    local fs = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 22, p.y)
    fs:SetText(label)
    local val = p:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    val:SetPoint("LEFT", fs, "RIGHT", 8, 0)

    local s = CreateFrame("Slider", nil, p, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(260, 17)
    s:SetPoint("TOPLEFT", 22, p.y - 18)
    s:SetBackdrop({
        bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
        edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8,
        insets = { left = 3, right = 3, top = 6, bottom = 6 },
    })
    local thumb = s:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    thumb:SetSize(32, 32)
    s:SetThumbTexture(thumb)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    if s.SetObeyStepsOnDrag then s:SetObeyStepsOnDrag(true) end
    s:EnableMouseWheel(true)
    s:SetScript("OnMouseWheel", function(self, delta)
        self:SetValue(math.min(maxV, math.max(minV, self:GetValue() + delta * step)))
    end)

    local lo = s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    lo:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 2, 0)
    lo:SetText(fmt:format(minV))
    local hi = s:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hi:SetPoint("TOPRIGHT", s, "BOTTOMRIGHT", -2, 0)
    hi:SetText(fmt:format(maxV))

    local function Show(v) val:SetText(fmt:format(v)) end
    s:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        Show(v)
        if not p.refreshing then set(v) end
    end)
    Tooltip(s, label, tip)
    p.refreshers[#p.refreshers + 1] = function()
        local v = tonumber(get()) or minV
        Show(v)
        s:SetValue(v)
    end
    p.y = p.y - 52
    return s
end

-- One row of buttons: { {label, onClick, tooltip}, ... }; label may be a function (re-read on refresh)
function lib:Buttons(p, list)
    local x = 20
    for _, b in ipairs(list) do
        local btn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
        local function Label() return type(b[1]) == "function" and b[1]() or b[1] end
        btn:SetText(Label())
        btn:SetSize(math.max(110, btn:GetFontString():GetStringWidth() + 24), 22)
        if type(b[1]) == "function" then
            p.refreshers[#p.refreshers + 1] = function() btn:SetText(Label()) end
        end
        btn:SetPoint("TOPLEFT", x, p.y)
        btn:SetScript("OnClick", function() b[2]() p:Refresh() end)
        Tooltip(btn, Label(), b[3])
        x = x + btn:GetWidth() + 8
    end
    p.y = p.y - 30
end

-- Radio group drawn as checkboxes on one row: options = { {value, text}, ... }
function lib:Radio(p, options, get, set)
    local x, boxes = 18, {}
    for _, o in ipairs(options) do
        local cb = CreateFrame("CheckButton", nil, p, "UIRadioButtonTemplate")
        cb:SetPoint("TOPLEFT", x, p.y - 4)
        local fs = (type(cb.text) == "table" and cb.text) or (type(cb.Text) == "table" and cb.Text)
            or cb:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        fs:ClearAllPoints()
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
        fs:SetFontObject(GameFontHighlight)
        fs:SetText(o[2])
        cb.value = o[1]
        cb:SetScript("OnClick", function()
            set(o[1])
            for _, b in ipairs(boxes) do b:SetChecked(b.value == o[1]) end
        end)
        boxes[#boxes + 1] = cb
        x = x + 30 + fs:GetStringWidth() + 16
    end
    p.refreshers[#p.refreshers + 1] = function()
        local cur = get()
        for _, b in ipairs(boxes) do b:SetChecked(b.value == cur) end
    end
    p.y = p.y - 30
end

function lib:Note(p, text)
    local fs = p:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    fs:SetPoint("TOPLEFT", 22, p.y)
    fs:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    fs:SetJustifyH("LEFT")
    fs:SetText(text)
    p.y = p.y - 20
end

-- Language picker shared by all addons ("auto" = follow the game client).
function lib:Language(p, ns, db, onChange, label)
    local opts = { { "auto", "Auto (" .. GetLocale() .. ")" } }
    for _, code in ipairs(ns:AvailableLocales()) do
        opts[#opts + 1] = { code, ns.Locales[code]._name }
    end
    self:Radio(p, opts,
        function() return db.locale or "auto" end,
        function(v)
            db.locale = (v ~= "auto") and v or nil
            ns:ApplyLocale(db.locale)
            if onChange then onChange() end
        end)
    if label then self:Note(p, label) end
end

---------------------------------------------------------------------------
-- "Buy me a coffee" section with copyable fields
---------------------------------------------------------------------------
local function CopyBox(p, label, value)
    local fs = p:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    fs:SetPoint("TOPLEFT", 22, p.y)
    fs:SetText(label)
    local eb = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
    eb:SetSize(380, 20)
    eb:SetPoint("TOPLEFT", 28, p.y - 16)
    eb:SetAutoFocus(false)
    eb:SetFontObject(GameFontHighlightSmall)
    eb:SetText(value)
    eb:SetCursorPosition(0)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnMouseUp", function(self) self:SetFocus(); self:HighlightText() end)
    eb:SetScript("OnTextChanged", function(self, userInput)
        if userInput then self:SetText(value); self:HighlightText() end
    end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    p.y = p.y - 44
end

function lib:Support(p)
    local S = self.SUPPORT or {}
    if (S.paypal or "") == "" and (S.pix or "") == "" then return end
    self:Section(p, PT and "Apoie com um café" or "Buy me a coffee")
    self:Note(p, PT and "Gostou dos addons? Clique no campo, Ctrl+C para copiar e cole no navegador ou no app do banco."
        or "Enjoying the addons? Click a field, press Ctrl+C to copy, then paste it in your browser or bank app.")
    if (S.paypal or "") ~= "" then CopyBox(p, "PayPal", S.paypal) end
    if (S.pix or "") ~= "" then CopyBox(p, PT and "PIX (Brasil)" or "PIX (Brazil)", S.pix) end
end
