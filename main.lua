-- ══════════════════════════════════════════════
--  UI  — SAKURA HUB STYLE  (drop-in replacement)
-- ══════════════════════════════════════════════

-- ── Services (already declared above, re-ref for clarity)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "STEPTHEP_UI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true
if gethui then ScreenGui.Parent = gethui()
else
    local ok, cg = pcall(function() return game:GetService("CoreGui") end)
    ScreenGui.Parent = ok and cg or LocalPlayer:WaitForChild("PlayerGui")
end

-- ── Design tokens (Sakura Hub palette from screenshot)
local T = {
    BG          = Color3.fromRGB(28, 28, 36),   -- main bg
    SIDEBAR     = Color3.fromRGB(22, 22, 30),   -- left sidebar
    PANEL       = Color3.fromRGB(32, 32, 42),   -- right content
    HEADER      = Color3.fromRGB(38, 38, 50),   -- top bar
    ACCENT      = Color3.fromRGB(255, 140, 50), -- orange accent (toggle ON)
    TAB_ACTIVE  = Color3.fromRGB(44, 44, 58),   -- selected tab bg
    TAB_IDLE    = Color3.fromRGB(0,0,0),        -- transparent
    ROW_A       = Color3.fromRGB(36, 36, 46),
    ROW_B       = Color3.fromRGB(30, 30, 40),
    SEC_HDR     = Color3.fromRGB(50, 50, 65),
    TXT_ON      = Color3.fromRGB(230, 230, 240),
    TXT_DIM     = Color3.fromRGB(100, 100, 120),
    TXT_ACC     = Color3.fromRGB(255, 160, 80),
    CLOSE       = Color3.fromRGB(180, 50, 50),
    BTN_CLOSE   = Color3.fromRGB(90, 90, 110),
    LINE        = Color3.fromRGB(55, 55, 70),
}

-- ── Window  (410 × 320 — matches Sakura Hub proportions)
local WIN_W, WIN_H = 410, 320
local SIDEBAR_W    = 100
local HEADER_H     = 42

local Win = Instance.new("Frame")
Win.Name                = "Win"
Win.Size                = UDim2.new(0, WIN_W, 0, WIN_H)
Win.Position            = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Win.BackgroundColor3    = T.BG
Win.BorderSizePixel     = 0
Win.ClipsDescendants    = true
Win.ZIndex              = 10
Win.Parent              = ScreenGui
Instance.new("UICorner", Win).CornerRadius = UDim.new(0, 8)

-- drop shadow (fake — UIStroke on outer frame)
local Shadow = Instance.new("UIStroke")
Shadow.Color            = Color3.fromRGB(0, 0, 0)
Shadow.Thickness        = 2
Shadow.Transparency     = 0.5
Shadow.Parent           = Win

-- ── Header bar
local Header = Instance.new("Frame")
Header.Name             = "Header"
Header.Size             = UDim2.new(1, 0, 0, HEADER_H)
Header.BackgroundColor3 = T.HEADER
Header.BorderSizePixel  = 0
Header.ZIndex           = 11
Header.Parent           = Win

-- Header icon
local HIcon = Instance.new("TextLabel")
HIcon.Text              = "🌸"
HIcon.Size              = UDim2.new(0, 28, 1, 0)
HIcon.Position          = UDim2.new(0, 8, 0, 0)
HIcon.BackgroundTransparency = 1
HIcon.TextSize          = 18
HIcon.Font              = Enum.Font.GothamBold
HIcon.TextColor3        = T.TXT_ON
HIcon.ZIndex            = 12
HIcon.Parent            = Header

-- Header title
local HTitle = Instance.new("TextLabel")
HTitle.Text             = "STEPTHEP"
HTitle.Size             = UDim2.new(0, 160, 0, 20)
HTitle.Position         = UDim2.new(0, 40, 0, 6)
HTitle.BackgroundTransparency = 1
HTitle.TextColor3       = T.TXT_ON
HTitle.TextSize         = 15
HTitle.Font             = Enum.Font.GothamBold
HTitle.TextXAlignment   = Enum.TextXAlignment.Left
HTitle.ZIndex           = 12
HTitle.Parent           = Header

-- Header subtitle
local HSub = Instance.new("TextLabel")
HSub.Text               = "Urban Reload v1.0"
HSub.Size               = UDim2.new(0, 160, 0, 14)
HSub.Position           = UDim2.new(0, 40, 0, 24)
HSub.BackgroundTransparency = 1
HSub.TextColor3         = T.TXT_DIM
HSub.TextSize           = 10
HSub.Font               = Enum.Font.Gotham
HSub.TextXAlignment     = Enum.TextXAlignment.Left
HSub.ZIndex             = 12
HSub.Parent             = Header

-- Minimise button (─)
local MinBtn = Instance.new("TextButton")
MinBtn.Text             = "─"
MinBtn.Size             = UDim2.new(0, 24, 0, 24)
MinBtn.Position         = UDim2.new(1, -56, 0.5, -12)
MinBtn.BackgroundColor3 = T.BTN_CLOSE
MinBtn.TextColor3       = T.TXT_ON
MinBtn.TextSize         = 14
MinBtn.Font             = Enum.Font.GothamBold
MinBtn.BorderSizePixel  = 0
MinBtn.ZIndex           = 13
MinBtn.Parent           = Header
Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 4)

-- Close button (×)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Text           = "×"
CloseBtn.Size           = UDim2.new(0, 24, 0, 24)
CloseBtn.Position       = UDim2.new(1, -28, 0.5, -12)
CloseBtn.BackgroundColor3 = T.CLOSE
CloseBtn.TextColor3     = Color3.new(1,1,1)
CloseBtn.TextSize       = 16
CloseBtn.Font           = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.ZIndex         = 13
CloseBtn.Parent         = Header
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 4)

-- Divider line under header
local HDivider = Instance.new("Frame")
HDivider.Size           = UDim2.new(1, 0, 0, 1)
HDivider.Position       = UDim2.new(0, 0, 0, HEADER_H)
HDivider.BackgroundColor3 = T.LINE
HDivider.BorderSizePixel = 0
HDivider.ZIndex         = 11
HDivider.Parent         = Win

-- ── Sidebar (left column)
local Sidebar = Instance.new("Frame")
Sidebar.Name            = "Sidebar"
Sidebar.Size            = UDim2.new(0, SIDEBAR_W, 1, -HEADER_H - 1)
Sidebar.Position        = UDim2.new(0, 0, 0, HEADER_H + 1)
Sidebar.BackgroundColor3 = T.SIDEBAR
Sidebar.BorderSizePixel = 0
Sidebar.ZIndex          = 11
Sidebar.Parent          = Win

local SideLayout = Instance.new("UIListLayout")
SideLayout.SortOrder   = Enum.SortOrder.LayoutOrder
SideLayout.Padding     = UDim.new(0, 0)
SideLayout.Parent      = Sidebar

-- Vertical divider between sidebar and panel
local VDiv = Instance.new("Frame")
VDiv.Size               = UDim2.new(0, 1, 1, -HEADER_H - 1)
VDiv.Position           = UDim2.new(0, SIDEBAR_W, 0, HEADER_H + 1)
VDiv.BackgroundColor3   = T.LINE
VDiv.BorderSizePixel    = 0
VDiv.ZIndex             = 11
VDiv.Parent             = Win

-- ── Right panel
local Panel = Instance.new("ScrollingFrame")
Panel.Name              = "Panel"
Panel.Size              = UDim2.new(1, -SIDEBAR_W - 1, 1, -HEADER_H - 1)
Panel.Position          = UDim2.new(0, SIDEBAR_W + 1, 0, HEADER_H + 1)
Panel.BackgroundColor3  = T.PANEL
Panel.BorderSizePixel   = 0
Panel.ScrollBarThickness = 3
Panel.ScrollBarImageColor3 = T.ACCENT
Panel.CanvasSize        = UDim2.new(0, 0, 0, 0)
Panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
Panel.ZIndex            = 11
Panel.Parent            = Win

local PanelLayout = Instance.new("UIListLayout")
PanelLayout.SortOrder  = Enum.SortOrder.LayoutOrder
PanelLayout.Padding    = UDim.new(0, 0)
PanelLayout.Parent     = Panel

local PanelPad = Instance.new("UIPadding")
PanelPad.PaddingLeft   = UDim.new(0, 8)
PanelPad.PaddingRight  = UDim.new(0, 8)
PanelPad.PaddingTop    = UDim.new(0, 6)
PanelPad.PaddingBottom = UDim.new(0, 8)
PanelPad.Parent        = Panel

-- ══════════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════════
-- Tab definitions: { name, icon, sections[] }
-- sections = list of widget-builder calls stored per tab
local TABS = {
    { id="General",  icon="⚙",  label="General"  },
    { id="ESP",      icon="👁",  label="ESP"      },
    { id="Aimbot",   icon="🎯",  label="Aimbot"   },
    { id="Keys",     icon="⌨",  label="Keys"     },
    { id="Visuals",  icon="🎨",  label="Visuals"  },
    { id="Fun",      icon="⚡",  label="Fun"      },
    { id="Emotes",   icon="😈",  label="Emotes"   },
    { id="Sound",    icon="🔊",  label="Sound"    },
}

local activeTab     = nil
local tabButtons    = {}
local tabContents   = {}   -- [id] = list of Frame children to show/hide

local function setTab(id)
    -- hide all panel children
    for _, child in ipairs(Panel:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") then
            child.Visible = false
        end
    end
    -- style all tab buttons
    for _, tb in pairs(tabButtons) do
        tb.BackgroundColor3 = Color3.fromRGB(0,0,0)
        tb.BackgroundTransparency = 1
        tb.TextColor3 = T.TXT_DIM
        if tb:FindFirstChildOfClass("Frame") then
            tb:FindFirstChildOfClass("Frame").BackgroundTransparency = 1
        end
    end
    -- show active tab content
    if tabContents[id] then
        for _, child in ipairs(tabContents[id]) do
            child.Visible = true
        end
    end
    -- style active button
    local ab = tabButtons[id]
    if ab then
        ab.BackgroundColor3 = T.TAB_ACTIVE
        ab.BackgroundTransparency = 0
        ab.TextColor3 = T.TXT_ON
        -- accent bar on left
        local bar = ab:FindFirstChild("AccBar")
        if bar then bar.BackgroundTransparency = 0 end
    end
    activeTab = id
end

-- Build sidebar tab buttons
for order, tab in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Name               = tab.id
    btn.Size               = UDim2.new(1, 0, 0, 34)
    btn.BackgroundColor3   = T.TAB_IDLE
    btn.BackgroundTransparency = 1
    btn.Text               = tab.icon .. "  " .. tab.label
    btn.TextColor3         = T.TXT_DIM
    btn.TextSize           = 12
    btn.Font               = Enum.Font.Gotham
    btn.TextXAlignment     = Enum.TextXAlignment.Left
    btn.BorderSizePixel    = 0
    btn.LayoutOrder        = order
    btn.ZIndex             = 12
    btn.Parent             = Sidebar
    -- left-padding
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 10)
    pad.Parent = btn
    -- accent bar (left edge, hidden until active)
    local bar = Instance.new("Frame")
    bar.Name                = "AccBar"
    bar.Size                = UDim2.new(0, 3, 0, 18)
    bar.Position            = UDim2.new(0, 0, 0.5, -9)
    bar.BackgroundColor3    = T.ACCENT
    bar.BorderSizePixel     = 0
    bar.BackgroundTransparency = 1
    bar.ZIndex              = 13
    bar.Parent              = btn
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    tabButtons[tab.id] = btn
    tabContents[tab.id] = {}

    btn.MouseButton1Click:Connect(function() setTab(tab.id) end)

    -- hover
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab.id then
            TweenSvc:Create(btn, TweenInfo.new(0.1), {
                BackgroundTransparency = 0.7,
                BackgroundColor3       = T.TAB_ACTIVE,
            }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.id then
            TweenSvc:Create(btn, TweenInfo.new(0.1), {
                BackgroundTransparency = 1,
            }):Play()
        end
    end)
end

-- ══════════════════════════════════════════════
--  WIDGET BUILDERS  (Sakura Hub style)
-- ══════════════════════════════════════════════
local function regWidget(tabId, widget)
    -- register in tabContents and add to Panel in layout order
    table.insert(tabContents[tabId], widget)
    widget.Visible = false   -- hidden until tab selected
end

-- Section header (grey bar like "SHERIFF" in screenshot)
local sOrder = 0
local function secHeader(tabId, text)
    sOrder += 1
    local f = Instance.new("Frame")
    f.Size               = UDim2.new(1, 0, 0, 24)
    f.BackgroundColor3   = T.SEC_HDR
    f.BorderSizePixel    = 0
    f.LayoutOrder        = sOrder
    f.ZIndex             = 12
    f.Parent             = Panel
    local lbl = Instance.new("TextLabel")
    lbl.Text             = text
    lbl.Size             = UDim2.new(1, -8, 1, 0)
    lbl.Position         = UDim2.new(0, 8, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = T.TXT_ON
    lbl.TextSize         = 11
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 13
    lbl.Parent           = f
    regWidget(tabId, f)
    return f
end

-- Toggle row  (label left, pill right — orange when ON like screenshot)
local function makeToggle(tabId, label, initVal, callback)
    sOrder += 1
    local row = Instance.new("Frame")
    row.Size               = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3   = T.ROW_A
    row.BorderSizePixel    = 0
    row.LayoutOrder        = sOrder
    row.ZIndex             = 12
    row.Parent             = Panel

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label
    lbl.Size               = UDim2.new(1, -58, 1, 0)
    lbl.Position           = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3         = initVal and T.TXT_ON or T.TXT_DIM
    lbl.TextSize           = 13
    lbl.Font               = Enum.Font.Gotham
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 13
    lbl.Parent             = row

    -- pill
    local pill = Instance.new("Frame")
    pill.Size              = UDim2.new(0, 40, 0, 20)
    pill.Position          = UDim2.new(1, -48, 0.5, -10)
    pill.BackgroundColor3  = initVal and T.ACCENT or Color3.fromRGB(55,55,70)
    pill.BorderSizePixel   = 0
    pill.ZIndex            = 13
    pill.Parent            = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local dot = Instance.new("Frame")
    dot.Size               = UDim2.new(0, 14, 0, 14)
    dot.Position           = initVal
        and UDim2.new(1, -17, 0.5, -7)
        or  UDim2.new(0, 3,   0.5, -7)
    dot.BackgroundColor3   = Color3.new(1,1,1)
    dot.BorderSizePixel    = 0
    dot.ZIndex             = 14
    dot.Parent             = pill
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

    local state = initVal
    local function setState(v)
        state = v
        lbl.TextColor3 = v and T.TXT_ON or T.TXT_DIM
        TweenSvc:Create(pill, TweenInfo.new(0.12), {
            BackgroundColor3 = v and T.ACCENT or Color3.fromRGB(55,55,70)
        }):Play()
        TweenSvc:Create(dot, TweenInfo.new(0.12), {
            Position = v
                and UDim2.new(1,-17,0.5,-7)
                or  UDim2.new(0,3,  0.5,-7)
        }):Play()
        callback(v)
    end

    local hitbox = Instance.new("TextButton")
    hitbox.Size            = UDim2.new(1, 0, 1, 0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text            = ""
    hitbox.ZIndex          = 15
    hitbox.Parent          = row
    hitbox.MouseButton1Click:Connect(function() setState(not state) end)

    regWidget(tabId, row)
    return row, setState
end

-- Slider row
local function makeSlider(tabId, label, minV, maxV, initVal, fmtFn, callback)
    sOrder += 1
    local row = Instance.new("Frame")
    row.Size               = UDim2.new(1, 0, 0, 50)
    row.BackgroundColor3   = T.ROW_B
    row.BorderSizePixel    = 0
    row.LayoutOrder        = sOrder
    row.ZIndex             = 12
    row.Parent             = Panel

    local lbl = Instance.new("TextLabel")
    lbl.Text               = label .. "   " .. fmtFn(initVal)
    lbl.Size               = UDim2.new(1, -8, 0, 18)
    lbl.Position           = UDim2.new(0, 10, 0, 6)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3         = T.TXT_ON
    lbl.TextSize           = 12
    lbl.Font               = Enum.Font.GothamBold
    lbl.TextXAlignment     = Enum.TextXAlignment.Left
    lbl.ZIndex             = 13
    lbl.Parent             = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1, -20, 0, 5)
    track.Position         = UDim2.new(0, 10, 0, 32)
    track.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    track.BorderSizePixel  = 0
    track.ZIndex           = 13
    track.Parent           = row
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

    local fill = Instance.new("Frame")
    fill.Size              = UDim2.new((initVal-minV)/(maxV-minV), 0, 1, 0)
    fill.BackgroundColor3  = T.ACCENT
    fill.BorderSizePixel   = 0
    fill.ZIndex            = 14
    fill.Parent            = track
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size              = UDim2.new(0, 12, 0, 12)
    knob.AnchorPoint       = Vector2.new(0.5, 0.5)
    knob.Position          = UDim2.new((initVal-minV)/(maxV-minV), 0, 0.5, 0)
    knob.BackgroundColor3  = Color3.fromRGB(240, 240, 255)
    knob.BorderSizePixel   = 0
    knob.ZIndex            = 15
    knob.Parent            = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local dragging = false
    local function setValue(v)
        v = math.clamp(math.floor(v), minV, maxV)
        local t = (v-minV)/(maxV-minV)
        fill.Size     = UDim2.new(t, 0, 1, 0)
        knob.Position = UDim2.new(t, 0, 0.5, 0)
        lbl.Text      = label .. "   " .. fmtFn(v)
        callback(v)
    end

    local db = Instance.new("TextButton")
    db.Size               = UDim2.new(1, 0, 1, 0)
    db.BackgroundTransparency = 1
    db.Text               = ""
    db.ZIndex             = 16
    db.Parent             = track
    db.MouseButton1Down:Connect(function() dragging = true end)
    UserInputSvc.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
    UserInputSvc.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local abs = track.AbsolutePosition
            local sz  = track.AbsoluteSize
            local relX = math.clamp(i.Position.X - abs.X, 0, sz.X)
            setValue(minV + (relX / sz.X) * (maxV - minV))
        end
    end)

    regWidget(tabId, row)
    return row, setValue
end

-- Key-binding info row (read-only label pair)
local function makeKeyRow(tabId, action, key, alt)
    sOrder += 1
    local row = Instance.new("Frame")
    row.Size               = UDim2.new(1, 0, 0, 28)
    row.BackgroundColor3   = alt and T.ROW_B or T.ROW_A
    row.BorderSizePixel    = 0
    row.LayoutOrder        = sOrder
    row.ZIndex             = 12
    row.Parent             = Panel

    local la = Instance.new("TextLabel")
    la.Text                = action
    la.Size                = UDim2.new(0.6, 0, 1, 0)
    la.Position            = UDim2.new(0, 10, 0, 0)
    la.BackgroundTransparency = 1
    la.TextColor3          = T.TXT_DIM
    la.TextSize            = 12
    la.Font                = Enum.Font.Gotham
    la.TextXAlignment      = Enum.TextXAlignment.Left
    la.ZIndex              = 13
    la.Parent              = row

    local lb = Instance.new("TextLabel")
    lb.Text                = key
    lb.Size                = UDim2.new(0.4, -8, 1, 0)
    lb.Position            = UDim2.new(0.6, 0, 0, 0)
    lb.BackgroundTransparency = 1
    lb.TextColor3          = T.TXT_ACC
    lb.TextSize            = 12
    lb.Font                = Enum.Font.GothamBold
    lb.TextXAlignment      = Enum.TextXAlignment.Right
    lb.ZIndex              = 13
    lb.Parent              = row

    regWidget(tabId, row)
end

-- ══════════════════════════════════════════════
--  POPULATE TABS
-- ══════════════════════════════════════════════

-- ── General tab
secHeader("General", "GENERAL INFO")
makeToggle("General", "Show Hint Strip",  true, function(v) end)  -- cosmetic only

-- ── ESP tab
secHeader("ESP", "ESP SETTINGS")
makeToggle("ESP", "ESP Enable",  CFG.ESP_ENABLED,  function(v) CFG.ESP_ENABLED  = v end)
makeToggle("ESP", "Box",         CFG.ESP_BOX,      function(v) CFG.ESP_BOX      = v end)
makeToggle("ESP", "Name",        CFG.ESP_NAME,     function(v) CFG.ESP_NAME     = v end)
makeToggle("ESP", "Health",      CFG.ESP_HEALTH,   function(v) CFG.ESP_HEALTH   = v end)
makeToggle("ESP", "Distance",    CFG.ESP_DISTANCE, function(v) CFG.ESP_DISTANCE = v end)
makeToggle("ESP", "Skeleton",    CFG.SKE_ENABLED,  function(v) CFG.SKE_ENABLED  = v end)

-- ── Aimbot tab
secHeader("Aimbot", "AIMBOT")
makeToggle("Aimbot", "Aimbot Enable",  CFG.AIM_ENABLED,       function(v) CFG.AIM_ENABLED       = v end)
makeToggle("Aimbot", "Show FOV",       CFG.AIM_FOV_VISIBLE,   function(v)
    CFG.AIM_FOV_VISIBLE = v
    fovCircle.Visible   = v and CFG.AIM_ENABLED
end)
makeToggle("Aimbot", "Visible Check",  CFG.AIM_VISIBLE_CHECK, function(v) CFG.AIM_VISIBLE_CHECK = v end)
makeToggle("Aimbot", "Team Check",     CFG.AIM_TEAM_CHECK,    function(v) CFG.AIM_TEAM_CHECK    = v end)
makeToggle("Aimbot", "Vehicle Lock",   CFG.AIM_VEHICLE,       function(v) CFG.AIM_VEHICLE       = v end)

secHeader("Aimbot", "FOV RADIUS")
makeSlider("Aimbot", "FOV", 20, 500, CFG.AIM_FOV, function(v) return v .. " px" end, function(v)
    CFG.AIM_FOV    = v
    fovCircle.Radius = v
end)

-- ── Keys tab
secHeader("Keys", "KEYBINDS")
makeKeyRow("Keys", "Lock (hold)",   "E",          false)
makeKeyRow("Keys", "ESP Toggle",    "X",          true)
makeKeyRow("Keys", "FOV  +  / −",  "]  /  [",    false)
makeKeyRow("Keys", "Menu Toggle",   "INSERT",     true)
makeKeyRow("Keys", "Mouse Unlock",  "ALT",        false)

-- ── Visuals / Fun / Emotes / Sound — empty stubs shown as "coming soon"
for _, tid in ipairs({"Visuals","Fun","Emotes","Sound"}) do
    sOrder += 1
    local ph = Instance.new("TextLabel")
    ph.Text              = "— coming soon —"
    ph.Size              = UDim2.new(1, 0, 0, 40)
    ph.LayoutOrder       = sOrder
    ph.BackgroundTransparency = 1
    ph.TextColor3        = T.TXT_DIM
    ph.TextSize          = 12
    ph.Font              = Enum.Font.Gotham
    ph.ZIndex            = 12
    ph.Parent            = Panel
    regWidget(tid, ph)
end

-- ══════════════════════════════════════════════
--  DRAG (header drag)
-- ══════════════════════════════════════════════
do
    local dragging, dragStart, startPos
    Header.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = i.Position
            startPos  = Win.Position
        end
    end)
    UserInputSvc.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputSvc.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            Win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- ══════════════════════════════════════════════
--  UI SHOW / HIDE
-- ══════════════════════════════════════════════
local function setUIVisible(v)
    uiVisible = v
    Win.Visible = v
    if not v and mouseUnlocked then lockMouse() end
end

CloseBtn.MouseButton1Click:Connect(function() setUIVisible(false) end)
MinBtn.MouseButton1Click:Connect(function()
    -- toggle panel+sidebar visibility (header stays — click again to restore)
    local collapsed = not Panel.Visible
    Panel.Visible   = not collapsed
    Sidebar.Visible = not collapsed
    VDiv.Visible    = not collapsed
    Win.Size = collapsed
        and UDim2.new(0, WIN_W, 0, WIN_H)
        or  UDim2.new(0, WIN_W, 0, HEADER_H + 2)
end)

-- open on ESP tab by default (closest to screenshot)
setTab("ESP")