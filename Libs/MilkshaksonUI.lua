-- MilkshaksonUI: tiny shared options toolkit for the Milkshakson- addons.
-- Every Milkshakson addon ships this same file; the newest version wins.
-- Creates one "Milkshakson" category under Options > AddOns, with one
-- sub-page per addon. Falls back to a standalone window if the Settings
-- API is unavailable.

local VERSION = 10
local lib = _G.MilkshaksonUI
if lib and (lib.version or 0) >= VERSION then return end
lib = lib or {}
lib.version = VERSION
_G.MilkshaksonUI = lib
lib.panels = lib.panels or {}   -- title -> panel: built again in place when the language changes (v9)

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
    -- built again (language changed): same page, new texts
    if rawget(panel, "category") then
        panel:SetHeight(-panel.y + 24)
        panel:Refresh()
        return rawget(panel, "category")
    end
    local frame = panel.outer or panel
    if panel.Refresh then panel:Refresh() end -- checkboxes reflect saved values right away
    local parent = self:GetParent()
    if parent and Settings.RegisterCanvasLayoutSubcategory then
        local ok, sub = pcall(Settings.RegisterCanvasLayoutSubcategory, parent, frame, name)
        if ok and sub then panel.category = sub; return sub end
    end
    panel.category = Standalone(frame, name)
    return panel.category
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
    -- Same title again (the addon builds its page again after a language change):
    -- empty the page and fill it with the new texts; it stays registered.
    local old = lib.panels[title]
    if old then
        for _, c in ipairs({ old:GetChildren() }) do c:Hide(); c:ClearAllPoints() end
        for _, r in ipairs({ old:GetRegions() }) do r:Hide() end
        rawset(old, "refreshers", {})
        local t = old:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        t:SetPoint("TOPLEFT", 16, -16)
        t:SetText(title)
        local d = old:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -6)
        d:SetPoint("RIGHT", old, "RIGHT", -16, 0)
        d:SetJustifyH("LEFT")
        d:SetText(desc or "")
        old.y = -64
        lib:SupportBanner(old)
        return old
    end
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
    lib:SupportBanner(p)
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
    lib.panels[title] = p
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
            -- this page in the new language too (next frame: not from inside its own click)
            if ns.BuildOptions then
                local function again() pcall(ns.BuildOptions, ns, db) end
                if C_Timer and C_Timer.After then C_Timer.After(0, again) else again() end
            end
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

---------------------------------------------------------------------------
-- "Buy me a coffee" banner at the top of every Milkshakson options page.
-- Addons can't open a browser: the buttons show the link selected in a
-- popup, ready for Ctrl+C.
---------------------------------------------------------------------------
function lib:CopyLink(title, value)
    if not (StaticPopupDialogs and StaticPopup_Show) then return end
    if not StaticPopupDialogs.MILKSHAKSON_COPY_LINK then
        StaticPopupDialogs.MILKSHAKSON_COPY_LINK = {
            text = "%s", button1 = OKAY or "OK", hasEditBox = true, editBoxWidth = 380,
            timeout = 0, whileDead = true, hideOnEscape = true, preferredIndex = 3,
            OnShow = function(self, data)
                local eb = self.editBox or self.EditBox
                if eb then eb:SetText(data or ""); eb:SetFocus(); eb:HighlightText() end
            end,
            EditBoxOnTextChanged = function(self, data)
                if data and self:GetText() ~= data then self:SetText(data); self:HighlightText() end
            end,
            EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
            EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
        }
    end
    StaticPopup_Show("MILKSHAKSON_COPY_LINK", title .. "\n" .. (PT and "Ctrl+C para copiar, depois cole no navegador ou no app do banco."
        or "Ctrl+C to copy, then paste it in your browser or bank app."), nil, value)
end

function lib:SupportBanner(p)
    local S = self.SUPPORT or {}
    if (S.paypal or "") == "" and (S.pix or "") == "" then return end
    local box = CreateFrame("Frame", nil, p, "BackdropTemplate")
    box:SetPoint("TOPLEFT", 16, p.y)
    box:SetPoint("RIGHT", p, "RIGHT", -16, 0)
    box:SetHeight(50)
    if box.SetBackdrop then
        box:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
            insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        box:SetBackdropColor(0.35, 0.2, 0.05, 0.6)
        box:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    end
    local icon = box:CreateTexture(nil, "ARTWORK")
    icon:SetSize(32, 32)
    icon:SetPoint("LEFT", 9, 0)
    icon:SetTexture("Interface\\Icons\\INV_Drink_04")
    local t = box:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, -1)
    t:SetText(PT and "Gostou? Me pague um café" or "Enjoying it? Buy me a coffee")
    local sub = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -3)
    sub:SetText(PT and "Clique para copiar o link" or "Click to copy the link")
    local x = -10
    for _, b in ipairs({ { "pix", PT and "PIX (Brasil)" or "PIX (Brazil)" }, { "paypal", "PayPal" } }) do
        local value = S[b[1]]
        if (value or "") ~= "" then
            local btn = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
            btn:SetText(b[2])
            btn:SetSize(100, 24)
            btn:SetPoint("RIGHT", box, "RIGHT", x, 0)
            btn:SetScript("OnClick", function() lib:CopyLink(b[2], value) end)
            Tooltip(btn, b[2], value)
            x = x - 106
        end
    end
    p.y = p.y - 60
    p.supportShown = true
end

function lib:Support(p)
    if p.supportShown then return end -- already at the top (SupportBanner)
    local S = self.SUPPORT or {}
    if (S.paypal or "") == "" and (S.pix or "") == "" then return end
    self:Section(p, PT and "Apoie com um café" or "Buy me a coffee")
    self:Note(p, PT and "Gostou dos addons? Clique no campo, Ctrl+C para copiar e cole no navegador ou no app do banco."
        or "Enjoying the addons? Click a field, press Ctrl+C to copy, then paste it in your browser or bank app.")
    if (S.paypal or "") ~= "" then CopyBox(p, "PayPal", S.paypal) end
    if (S.pix or "") ~= "" then CopyBox(p, PT and "PIX (Brasil)" or "PIX (Brazil)", S.pix) end
end

---------------------------------------------------------------------------
-- What's new (v10): after an update, a popup with the release notes of the
-- versions since the one last seen. One popup at a time (queued across the
-- Milkshakson addons), a few seconds after login and never in combat.
--   lib:WhatsNew{ title = "Ready Quests", version = "2.13.0", notes = ns.NOTES,
--                 db = savedVars, lang = "ptBR", force = true (options button) }
--   notes = { { v = "2.13.0", en = { "line", ... }, pt = { ... } }, ... } newest first
-- db.seenVersion = last version shown; db.whatsNew == false = don't show on updates.
---------------------------------------------------------------------------
local function VerNum(v)
    local a, b, c = tostring(v or ""):match("(%d+)%.?(%d*)%.?(%d*)")
    return (tonumber(a) or 0) * 1000000 + (tonumber(b) or 0) * 1000 + (tonumber(c) or 0)
end
lib.VerNum = VerNum

local function Markup(line)
    line = line:gsub("%*%*(.-)%*%*", "|cffffd100%1|r")
    line = line:gsub("`(.-)`", "|cff99ccff%1|r")
    return line
end

function lib:WhatsNewText(o)
    local pt = (o.lang or (PT and "ptBR" or "enUS")) == "ptBR"
    local from = (not o.force) and o.db and o.db.seenVersion and VerNum(o.db.seenVersion) or nil
    local out = {}
    for _, n in ipairs(o.notes or {}) do
        local nv = VerNum(n.v)
        if nv <= VerNum(o.version) and (not from or nv > from) then
            if #out > 0 then out[#out + 1] = " " end
            out[#out + 1] = "|cffffd100" .. n.v .. "|r"
            for _, l in ipairs((pt and n.pt) or n.en or {}) do out[#out + 1] = "|cffbbbbbb-|r " .. Markup(l) end
        end
        if not from and not o.force and #out > 0 then break end   -- first time: only the current version
    end
    return table.concat(out, "\n")
end

local function BuildWhatsNew()
    local f = CreateFrame("Frame", "MilkshaksonWhatsNew", UIParent, "BackdropTemplate")
    f:SetSize(460, 360)
    f:SetPoint("CENTER", 0, 60)
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    if f.SetBackdrop then
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
        f:SetBackdropColor(0.04, 0.04, 0.06, 0.96)
        f:SetBackdropBorderColor(1, 0.82, 0, 0.9)
    end
    f.title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 16, -14)
    f.title:SetPoint("RIGHT", -36, 0)
    f.title:SetJustifyH("LEFT")
    local x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", -2, -2)
    x:SetScript("OnClick", function() lib:CloseWhatsNew() end)
    local sf = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 16, -42)
    sf:SetPoint("BOTTOMRIGHT", -34, 48)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(400, 10)
    sf:SetScrollChild(child)
    f.body = child:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    f.body:SetPoint("TOPLEFT")
    f.body:SetWidth(400)
    f.body:SetJustifyH("LEFT")
    f.body:SetSpacing(3)
    f.child, f.scroll = child, sf
    local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("BOTTOMLEFT", 12, 12)
    f.cbText = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    f.cbText:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb:SetScript("OnClick", function(self)
        local o = f.current
        if o and o.db then o.db.whatsNew = self:GetChecked() and true or false end
    end)
    f.cb = cb
    local ok = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    ok:SetSize(90, 24)
    ok:SetPoint("BOTTOMRIGHT", -14, 12)
    ok:SetText(OKAY or "OK")
    ok:SetScript("OnClick", function() lib:CloseWhatsNew() end)
    f:Hide()
    return f
end

function lib:CloseWhatsNew()
    local f = self.wnFrame
    if f then f:Hide(); f.current = nil end
    self:NextWhatsNew()
end

function lib:NextWhatsNew()
    local q = self.wnQueue
    if not q or #q == 0 or (self.wnFrame and self.wnFrame:IsShown()) then return end
    if InCombatLockdown and InCombatLockdown() then
        if not self.wnWait then
            self.wnWait = CreateFrame("Frame")
            self.wnWait:SetScript("OnEvent", function(w) w:UnregisterAllEvents(); lib:NextWhatsNew() end)
        end
        self.wnWait:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    local o = table.remove(q, 1)
    local text = self:WhatsNewText(o)
    if o.db and not o.force then o.db.seenVersion = o.version end
    if text == "" then return self:NextWhatsNew() end
    local f = self.wnFrame or BuildWhatsNew()
    self.wnFrame = f
    local pt = (o.lang or (PT and "ptBR" or "enUS")) == "ptBR"
    f.current = o
    f.title:SetText(("%s %s - %s"):format(o.title or "", o.version or "", pt and "Novidades" or "What's new"))
    f.body:SetText(text)
    f.child:SetHeight((tonumber(f.body:GetStringHeight()) or 100) + 10)
    if f.scroll.SetVerticalScroll then f.scroll:SetVerticalScroll(0) end
    f.cbText:SetText(pt and "Mostrar as novidades quando o addon atualizar" or "Show what's new when the addon updates")
    f.cb:SetShown(o.db ~= nil)
    f.cbText:SetShown(o.db ~= nil)
    f.cb:SetChecked(not (o.db and o.db.whatsNew == false))
    f:Show()
    if f.Raise then f:Raise() end
end

function lib:WhatsNew(o)
    if not o or not o.version then return end
    if not o.force then
        local db = o.db
        if not db or db.whatsNew == false or db.seenVersion == o.version then return end
        if db.seenVersion and VerNum(db.seenVersion) > VerNum(o.version) then db.seenVersion = o.version; return end
    end
    self.wnQueue = self.wnQueue or {}
    for _, e in ipairs(self.wnQueue) do if e.title == o.title then return end end
    table.insert(self.wnQueue, o)
    if o.force or not (C_Timer and C_Timer.After) then
        self:NextWhatsNew()
    else
        C_Timer.After(4, function() lib:NextWhatsNew() end)
    end
end
