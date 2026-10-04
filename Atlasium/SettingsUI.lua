local ADDON_NAME, ns = ...

local UI = {}
ns.SettingsUI = UI

local L = ns.Localization.Get
local views = {}
local tooltipOwner
local colorOwner

local function Text(parent, font, x, y, width)
    local text = parent:CreateFontString(nil, "ARTWORK", font)
    text:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    text:SetWidth(width)
    text:SetJustifyH("LEFT")
    return text
end

local function ShowTooltip(widget)
    GameTooltip:SetOwner(widget, "ANCHOR_RIGHT")
    GameTooltip:SetText(L(widget.tip), 1, 1, 1, 1, true)
    GameTooltip:Show()
end

local function Tooltip(widget, key)
    widget.tip = key
    widget:SetScript("OnEnter", function(self)
        tooltipOwner = self
        ShowTooltip(self)
    end)
    widget:SetScript("OnLeave", function()
        tooltipOwner = nil
        GameTooltip:Hide()
    end)
end

local function Apply(id, value)
    local ok, message = ns.Settings.Set(id, value)
    if not ok then ns.Core.Print(message) end
end

local function CloseColorPicker()
    if colorOwner and ColorPickerFrame:IsShown() then
        ColorPickerFrame.cancelFunc(ColorPickerFrame.previousValues)
        HideUIPanel(ColorPickerFrame)
    end
    colorOwner = nil
end

--- Open the native color picker, previewing changes and restoring the snapshot on cancellation.
function UI.OpenColorPicker(view)
    if ColorPickerFrame:IsShown() then return end -- another add-on may own the shared picker
    local color = ns.Settings.Get("color")
    local previous = { r = color.r, g = color.g, b = color.b, a = color.a }
    colorOwner = view
    ColorPickerFrame.hasOpacity = true
    ColorPickerFrame.opacity = 1 - color.a
    ColorPickerFrame.previousValues = previous
    local function Preview()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        Apply("color", { r = r, g = g, b = b, a = 1 - OpacitySliderFrame:GetValue() })
    end
    -- SetColorRGB fires OnColorSelect, so suppress callbacks until initialization is complete.
    ColorPickerFrame.func = nil
    ColorPickerFrame.opacityFunc = nil
    ColorPickerFrame.cancelFunc = function(snapshot) Apply("color", snapshot) end
    ColorPickerFrame:SetColorRGB(color.r, color.g, color.b)
    ShowUIPanel(ColorPickerFrame)
    ColorPickerFrame.func = Preview
    ColorPickerFrame.opacityFunc = Preview
end

local function BuildContent(parent, prefix)
    local view = { parent = parent, labels = {}, controls = {} }
    table.insert(views, view)
    view.title = Text(parent, "GameFontNormalLarge", 16, -16, 380)
    view.immediate = Text(parent, "GameFontHighlightSmall", 16, -42, 380)
    local scroll = CreateFrame("ScrollFrame", prefix .. "Scroll", parent, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, -70)
    scroll:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -38, 16)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetWidth(360)
    content:SetHeight(790)
    scroll:SetScrollChild(content)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local offset = math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 36))
        self:SetVerticalScroll(offset)
    end)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(1, width)) end)
    view.scroll = scroll
    local y = 0

    local function Label(key, font, height)
        local label = Text(content, font or "GameFontNormal", 0, y, 350)
        table.insert(view.labels, { text = label, key = key })
        y = y - (height or 30)
        return label
    end

    local function Check(id, key, tip)
        local widget = CreateFrame("CheckButton", prefix .. id, content, "UICheckButtonTemplate")
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", -4, y)
        local label = _G[widget:GetName() .. "Text"]
        label:SetFontObject("GameFontHighlight")
        label:SetWidth(320)
        label:SetJustifyH("LEFT")
        table.insert(view.labels, { text = label, key = key })
        widget:SetScript("OnClick", function(self)
            if not view.rendering then
                local checked = self:GetChecked() and true or false
                PlaySound(checked and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
                Apply(id, checked)
            end
        end)
        Tooltip(widget, tip or (id .. "Tip"))
        view.controls[id] = widget
        y = y - 42
    end

    local function Slider(id, tip)
        local entry = ns.Settings.entries[id]
        local widget = CreateFrame("Slider", prefix .. id, content, "OptionsSliderTemplate")
        widget:SetPoint("TOPLEFT", content, "TOPLEFT", 8, y - 20)
        widget:SetWidth(320)
        widget:SetMinMaxValues(entry.min, entry.max)
        widget:SetValueStep(entry.step)
        _G[widget:GetName() .. "Low"]:SetText(tostring(entry.min))
        _G[widget:GetName() .. "High"]:SetText(tostring(entry.max))
        widget.valueLabel = _G[widget:GetName() .. "Text"]
        widget:SetScript("OnValueChanged", function(_, value)
            if view.rendering then return end
            local rounded = entry.min + math.floor((value - entry.min) / entry.step + 0.5) * entry.step
            Apply(id, math.max(entry.min, math.min(entry.max, rounded)))
        end)
        Tooltip(widget, tip or (id .. "Tip"))
        view.controls[id] = widget
        y = y - 68
    end

    Label("general")
    Label("language", "GameFontHighlight", 20)
    local dropdown = CreateFrame("Frame", prefix .. "Language", content, "UIDropDownMenuTemplate")
    dropdown:EnableMouse(true)
    dropdown:SetPoint("TOPLEFT", content, "TOPLEFT", -16, y)
    UIDropDownMenu_SetWidth(dropdown, 200)
    UIDropDownMenu_Initialize(dropdown, function()
        for _, language in ipairs(ns.Localization.languages) do
            local info = UIDropDownMenu_CreateInfo()
            info.text, info.value = language.name, language.code
            info.checked = ns.Localization.GetLanguage() == language.code
            info.func = function() Apply("language", language.code) end
            UIDropDownMenu_AddButton(info)
        end
    end)
    Tooltip(dropdown, "languageTip")
    view.controls.language = dropdown
    y = y - 50

    Label("minimap")
    Check("button", "button")
    Slider("angle")
    Check("minimapZoom", "minimapZoom")
    Check("tiles", "tiles")
    Label("worldmap")
    Check("mapNav", "mapNav")
    Slider("maxZoom")
    Slider("step")
    Check("fog", "fog")
    local colorButton = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    colorButton:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    colorButton:SetWidth(285)
    colorButton:SetHeight(24)
    colorButton:SetScript("OnClick", function() UI.OpenColorPicker(view) end)
    Tooltip(colorButton, "colorTip")
    view.controls.color = colorButton
    local swatch = colorButton:CreateTexture(nil, "ARTWORK")
    swatch:SetPoint("LEFT", colorButton, "RIGHT", 10, 0)
    swatch:SetWidth(20)
    swatch:SetHeight(20)
    view.swatch = swatch
    y = y - 46
    Label("advanced")
    Check("debug", "debug", "debugDescription")
    Label("debugDescription", "GameFontHighlightSmall", 70)
    content:SetHeight(-y)
    parent:SetScript("OnShow", function() UI.Refresh() end)
    parent:HookScript("OnHide", function()
        if colorOwner == view then CloseColorPicker() end
        if tooltipOwner and tooltipOwner:IsShown() then
            tooltipOwner = nil
            GameTooltip:Hide()
        end
    end)
    return view
end

--- Refresh both views without invoking setting callbacks or changing saved values.
function UI.Refresh()
    if not ns.db then return end
    for _, view in ipairs(views) do
        view.rendering = true
        view.title:SetText(L("title"))
        view.immediate:SetText(L("immediate"))
        for _, label in ipairs(view.labels) do label.text:SetText(L(label.key)) end
        for id, widget in pairs(view.controls) do
            local value = ns.Settings.Get(id)
            if id == "language" then
                local languageCode = ns.Localization.GetLanguage()
                UIDropDownMenu_SetSelectedValue(widget, languageCode)
                -- The native dropdown list is shared with every other menu; set its caption explicitly.
                for _, language in ipairs(ns.Localization.languages) do
                    if language.code == languageCode then UIDropDownMenu_SetText(widget, language.name) end
                end
            elseif id == "color" then
                widget:SetText(L("color"))
                view.swatch:SetTexture(value.r, value.g, value.b, value.a)
            elseif ns.Settings.entries[id].min then
                widget:SetValue(value)
                widget.valueLabel:SetText(L(id, string.format("%.2f", value):gsub("%.?0+$", "")))
            else
                widget:SetChecked(value)
            end
        end
        view.rendering = false
    end
    if UI.defaultsButton then UI.defaultsButton:SetText(L("defaults")) end
    if UI.closeButton then UI.closeButton:SetText(L("close")) end
    if tooltipOwner and GameTooltip:GetOwner() == tooltipOwner then ShowTooltip(tooltipOwner) end
end

local function CreateWindow()
    local window = CreateFrame("Frame", "AtlasiumSettingsWindow", UIParent, "UIPanelDialogTemplate")
    window:Hide()
    window:SetWidth(450)
    window:SetHeight(540)
    window:SetPoint("CENTER", UIParent, "CENTER")
    window:SetFrameStrata("DIALOG")
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window.title:SetText(ADDON_NAME)
    local drag = CreateFrame("Frame", nil, window)
    drag:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -4)
    drag:SetPoint("TOPRIGHT", window, "TOPRIGHT", -32, -4)
    drag:SetHeight(24)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() window:StartMoving() end)
    drag:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)
    window:HookScript("OnHide", function() window:StopMovingOrSizing() end)
    table.insert(UISpecialFrames, window:GetName())
    local body = CreateFrame("Frame", nil, window)
    body:SetPoint("TOPLEFT", window, "TOPLEFT", 8, -26)
    body:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -8, 42)
    UI.windowView = BuildContent(body, "AtlasiumSettingsWindow")
    window:HookScript("OnShow", UI.Refresh)
    window:HookScript("OnHide", function() if colorOwner == UI.windowView then CloseColorPicker() end end)
    local defaults = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    defaults:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", 18, 14)
    defaults:SetWidth(170)
    defaults:SetHeight(24)
    defaults:SetScript("OnClick", function() CloseColorPicker(); ns.Settings.ResetDefaults() end)
    UI.defaultsButton = defaults
    local close = CreateFrame("Button", nil, window, "UIPanelButtonTemplate")
    close:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -18, 14)
    close:SetWidth(100)
    close:SetHeight(24)
    close:SetScript("OnClick", function() window:Hide() end)
    UI.closeButton = close
    UI.window = window
end

--- Show the standalone settings window, creating it on first use.
function UI.Show()
    if not ns.db then return end
    if not UI.window then CreateWindow() end
    UI.Refresh()
    UI.window:Show()
end

--- Open or close the standalone settings window.
function UI.Toggle()
    if UI.window and UI.window:IsShown() then UI.window:Hide() else UI.Show() end
end

--- Register the matching Interface Options panel once after saved variables are ready.
function UI.RegisterPanel()
    if UI.panel then return end
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    panel.name = ADDON_NAME
    UI.panelView = BuildContent(panel, "AtlasiumSettingsPanel")
    panel.refresh = UI.Refresh
    panel.default = function() CloseColorPicker(); ns.Settings.ResetDefaults() end
    -- Changes apply immediately. Blizzard supplies no-op okay/cancel callbacks when omitted.
    InterfaceOptions_AddCategory(panel)
    UI.panel = panel
    UI.Refresh()
end

ns.Core.RegisterEvent("PLAYER_LOGIN", UI.RegisterPanel)
ColorPickerFrame:HookScript("OnHide", function() colorOwner = nil end)
