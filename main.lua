-- ╔══════════════════════════════════════════════════════╗
-- ║          STEPTHEP  v1.1  |  Urban Reload            ║
-- ║   ESP · Skeleton · FOV Aimbot · Vehicle Lock        ║
-- ║   Executor: Xeno / Synapse X / UNC-compliant        ║
-- ╚══════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════
--  CONFIG  — ทุกฟีเจอร์ off เริ่มต้น
-- ══════════════════════════════════════════════
local CFG = {
    ESP_ENABLED       = false,
    ESP_BOX           = false,
    ESP_NAME          = false,
    ESP_HEALTH        = false,
    ESP_DISTANCE      = false,
    ESP_COLOR         = Color3.fromRGB(80, 160, 255),
    ESP_THICKNESS     = 1.5,
    SKE_ENABLED       = false,
    SKE_COLOR         = Color3.fromRGB(255, 210, 80),
    SKE_THICKNESS     = 1.2,
    AIM_ENABLED       = false,
    AIM_FOV           = 120,
    AIM_FOV_VISIBLE   = false,
    AIM_FOV_COLOR     = Color3.fromRGB(255, 255, 255),
    AIM_BONE          = "Head",
    AIM_TEAM_CHECK    = false,
    AIM_VISIBLE_CHECK = false,
    AIM_VEHICLE       = false,
    AIM_HEAD_OFFSET   = Vector3.new(0, 0, 0),
    AIM_SMOOTH        = 0.25,
    KEY_LOCK         = Enum.KeyCode.E,
    KEY_ESP_TOGGLE   = Enum.KeyCode.X,
    KEY_FOV_UP       = Enum.KeyCode.RightBracket,
    KEY_FOV_DOWN     = Enum.KeyCode.LeftBracket,
    KEY_UI_TOGGLE    = Enum.KeyCode.Insert,
    KEY_MOUSE_TOGGLE = Enum.KeyCode.LeftAlt,
}

-- ══════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInputSvc = game:GetService("UserInputService")
local TweenSvc     = game:GetService("TweenService")
local Camera       = workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer

-- ══════════════════════════════════════════════
--  STATE
-- ══════════════════════════════════════════════
local espObjects    = {}
local skelObjects   = {}
local lockedTarget  = nil
local aimActive     = false
local uiVisible     = true
local mouseUnlocked = false

local BONE_PAIRS = {
    {"Head","UpperTorso"},  {"Head","Torso"},
    {"UpperTorso","LowerTorso"},
    {"Torso","HumanoidRootPart"},{"UpperTorso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},  {"LeftUpperArm","LeftLowerArm"},  {"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},  {"LeftUpperLeg","LeftLowerLeg"},  {"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"Torso","Left Arm"},  {"Left Arm","Left Hand"},
    {"Torso","Right Arm"}, {"Right Arm","Right Hand"},
    {"Torso","Left Leg"},  {"Left Leg","Left Foot"},
    {"Torso","Right Leg"}, {"Right Leg","Right Foot"},
}

-- ══════════════════════════════════════════════
--  MOUSE HELPERS
-- ══════════════════════════════════════════════
local function unlockMouse()
    UserInputSvc.MouseBehavior    = Enum.MouseBehavior.Default
    UserInputSvc.MouseIconEnabled = true
    mouseUnlocked = true
end
local function lockMouse()
    UserInputSvc.MouseBehavior    = Enum.MouseBehavior.LockCenter
    UserInputSvc.MouseIconEnabled = false
    mouseUnlocked = false
end

-- ══════════════════════════════════════════════
--  DRAWING HELPERS
-- ══════════════════════════════════════════════
local function newDraw(t, props)
    local d = Drawing.new(t)
    for k,v in pairs(props) do d[k]=v end
    return d
end

local fovCircle = newDraw("Circle",{
    Visible   = false,
    Radius    = CFG.AIM_FOV,
    Color     = CFG.AIM_FOV_COLOR,
    Thickness = 1,
    Filled    = false,
    Position  = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2),
})

-- ══════════════════════════════════════════════
--  UTILITY
-- ══════════════════════════════════════════════
local function getChar(plr) return plr and plr.Character end

local function getRootAndHuman(plr)
    local c = getChar(plr); if not c then return nil,nil end
    return c:FindFirstChild("HumanoidRootPart"), c:FindFirstChildOfClass("Humanoid")
end

local function isTeammate(plr)
    if not CFG.AIM_TEAM_CHECK then return false end
    return plr.Team and LocalPlayer.Team and plr.Team == LocalPlayer.Team
end

local function worldToScreen(pos)
    local sp,on = Camera:WorldToViewportPoint(pos)
    return Vector2.new(sp.X,sp.Y), on, sp.Z
end

local function getTargetBone(char)
    return char:FindFirstChild(CFG.AIM_BONE) or char:FindFirstChild("HumanoidRootPart")
end

local function distanceTo(plr)
    local root = getRootAndHuman(plr)
    local lroot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not root or not lroot then return math.huge end
    return (root.Position - lroot.Position).Magnitude
end

local function isVisible(char, bonePos)
    local origin = Camera.CFrame.Position
    local dir    = bonePos - origin
    local ray    = Ray.new(origin, dir.Unit * dir.Magnitude)
    local hit    = workspace:FindPartOnRayWithIgnoreList(ray, {LocalPlayer.Character})
    if hit == nil then return true end
    return char:IsAncestorOf(hit) or hit:IsDescendantOf(char)
end

local function getPlayerRootPos(plr)
    local char = getChar(plr)
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    return root.Position
end

-- ══════════════════════════════════════════════
--  ESP + SKELETON BUILDER
-- ══════════════════════════════════════════════
local function buildESP(plr)
    if espObjects[plr] then return end
    espObjects[plr] = {
        box    = newDraw("Square",{Visible=false,Color=CFG.ESP_COLOR,  Thickness=CFG.ESP_THICKNESS,Filled=false}),
        name   = newDraw("Text",  {Visible=false,Color=CFG.ESP_COLOR,  Size=13,Center=true,Outline=true}),
        health = newDraw("Text",  {Visible=false,Color=Color3.fromRGB(80,255,120),Size=12,Center=true,Outline=true}),
        dist   = newDraw("Text",  {Visible=false,Color=Color3.fromRGB(180,180,220),Size=11,Center=true,Outline=true}),
    }
    skelObjects[plr] = {}
    for _,pair in ipairs(BONE_PAIRS) do
        local key = pair[1].."__"..pair[2]
        skelObjects[plr][key] = newDraw("Line",{
            Visible=false, Color=CFG.SKE_COLOR, Thickness=CFG.SKE_THICKNESS,
            From=Vector2.new(0,0), To=Vector2.new(0,0),
        })
    end
end

local function removeESP(plr)
    if espObjects[plr] then
        for _,d in pairs(espObjects[plr]) do if d and d.Remove then d:Remove() end end
        espObjects[plr] = nil
    end
    if skelObjects[plr] then
        for _,d in pairs(skelObjects[plr]) do if d and d.Remove then d:Remove() end end
        skelObjects[plr] = nil
    end
end

local function updateESP(plr)
    local esp = espObjects[plr]
    local ske = skelObjects[plr]
    if not esp then return end

    if not CFG.ESP_ENABLED then
        for _,d in pairs(esp) do d.Visible=false end
        if ske then for _,d in pairs(ske) do d.Visible=false end end
        return
    end

    local char = getChar(plr)
    local root,human = getRootAndHuman(plr)
    if not char or not root or not human or human.Health <= 0 then
        for _,d in pairs(esp) do d.Visible=false end
        if ske then for _,d in pairs(ske) do d.Visible=false end end
        return
    end

    local hrpPos = root.Position
    local top2d,onTop = worldToScreen(hrpPos + Vector3.new(0,3.2,0))
    local bot2d,onBot = worldToScreen(hrpPos - Vector3.new(0,3.2,0))

    if not onTop and not onBot then
        for _,d in pairs(esp) do d.Visible=false end
        if ske then for _,d in pairs(ske) do d.Visible=false end end
        return
    end

    local height = math.abs(top2d.Y - bot2d.Y)
    local width  = height * 0.5
    local cx     = (top2d.X + bot2d.X) / 2

    esp.box.Visible = CFG.ESP_BOX
    if CFG.ESP_BOX then
        esp.box.Position = Vector2.new(cx - width/2, top2d.Y)
        esp.box.Size     = Vector2.new(width, height)
    end
    esp.name.Visible = CFG.ESP_NAME
    if CFG.ESP_NAME then
        esp.name.Text     = plr.Name
        esp.name.Position = Vector2.new(cx, top2d.Y - 16)
    end
    esp.health.Visible = CFG.ESP_HEALTH
    if CFG.ESP_HEALTH then
        esp.health.Text     = math.floor(human.Health).." HP"
        esp.health.Position = Vector2.new(cx, bot2d.Y + 2)
    end
    esp.dist.Visible = CFG.ESP_DISTANCE
    if CFG.ESP_DISTANCE then
        esp.dist.Text     = math.floor(distanceTo(plr)).."m"
        esp.dist.Position = Vector2.new(cx, bot2d.Y + 14)
    end

    if ske then
        for _,pair in ipairs(BONE_PAIRS) do
            local key  = pair[1].."__"..pair[2]
            local line = ske[key]
            if not line then continue end
            if not CFG.SKE_ENABLED then line.Visible=false continue end
            local b0 = char:FindFirstChild(pair[1])
            local b1 = char:FindFirstChild(pair[2])
            if not b0 or not b1 then line.Visible=false continue end
            local s0,on0 = worldToScreen(b0.Position)
            local s1,on1 = worldToScreen(b1.Position)
            if not on0 or not on1 then line.Visible=false continue end
            line.From    = s0
            line.To      = s1
            line.Visible = true
        end
    end
end

-- ══════════════════════════════════════════════
--  UI
-- ══════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name            = "STEPTHEP_UI"
ScreenGui.ResetOnSpawn    = false
ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset  = true
if gethui then ScreenGui.Parent = gethui()
else
    local ok,cg = pcall(function() return game:GetService("CoreGui") end)
    ScreenGui.Parent = ok and cg or LocalPlayer:WaitForChild("PlayerGui")
end

local T = {
    BG         = Color3.fromRGB(28,28,36),
    SIDEBAR    = Color3.fromRGB(22,22,30),
    PANEL      = Color3.fromRGB(32,32,42),
    HEADER     = Color3.fromRGB(38,38,50),
    ACCENT     = Color3.fromRGB(255,140,50),
    TAB_SEL    = Color3.fromRGB(44,44,58),
    ROW_A      = Color3.fromRGB(36,36,46),
    ROW_B      = Color3.fromRGB(30,30,40),
    SEC        = Color3.fromRGB(50,50,65),
    TXT_ON     = Color3.fromRGB(230,230,240),
    TXT_DIM    = Color3.fromRGB(100,100,120),
    TXT_ACC    = Color3.fromRGB(255,160,80),
    CLOSE      = Color3.fromRGB(180,50,50),
    MIN_BTN    = Color3.fromRGB(90,90,110),
    LINE       = Color3.fromRGB(55,55,70),
    PILL_OFF   = Color3.fromRGB(55,55,70),
}

local WIN_W  = 420
local WIN_H  = 310
local SIDE_W = 108
local HDR_H  = 42

local Win = Instance.new("Frame")
Win.Name               = "Win"
Win.Size               = UDim2.new(0,WIN_W,0,WIN_H)
Win.Position           = UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2)
Win.BackgroundColor3   = T.BG
Win.BorderSizePixel    = 0
Win.ClipsDescendants   = true
Win.ZIndex             = 10
Win.Parent             = ScreenGui
Instance.new("UICorner",Win).CornerRadius = UDim.new(0,8)

local WinStroke = Instance.new("UIStroke")
WinStroke.Color        = Color3.fromRGB(0,0,0)
WinStroke.Thickness    = 2
WinStroke.Transparency = 0.5
WinStroke.Parent       = Win

local Header = Instance.new("Frame")
Header.Name            = "Header"
Header.Size            = UDim2.new(1,0,0,HDR_H)
Header.BackgroundColor3= T.HEADER
Header.BorderSizePixel = 0
Header.ZIndex          = 11
Header.Parent          = Win

local HIcon = Instance.new("TextLabel")
HIcon.Text             = "🌸"
HIcon.Size             = UDim2.new(0,28,1,0)
HIcon.Position         = UDim2.new(0,8,0,0)
HIcon.BackgroundTransparency = 1
HIcon.TextSize         = 18
HIcon.Font             = Enum.Font.GothamBold
HIcon.TextColor3       = T.TXT_ON
HIcon.ZIndex           = 12
HIcon.Parent           = Header

local HTitle = Instance.new("TextLabel")
HTitle.Text            = "STEPTHEP"
HTitle.Size            = UDim2.new(0,160,0,20)
HTitle.Position        = UDim2.new(0,40,0,5)
HTitle.BackgroundTransparency = 1
HTitle.TextColor3      = T.TXT_ON
HTitle.TextSize        = 15
HTitle.Font            = Enum.Font.GothamBold
HTitle.TextXAlignment  = Enum.TextXAlignment.Left
HTitle.ZIndex          = 12
HTitle.Parent          = Header

local HSub = Instance.new("TextLabel")
HSub.Text              = "Urban Reload v1.1"
HSub.Size              = UDim2.new(0,160,0,13)
HSub.Position          = UDim2.new(0,40,0,24)
HSub.BackgroundTransparency = 1
HSub.TextColor3        = T.TXT_DIM
HSub.TextSize          = 10
HSub.Font              = Enum.Font.Gotham
HSub.TextXAlignment    = Enum.TextXAlignment.Left
HSub.ZIndex            = 12
HSub.Parent            = Header

local MinBtn = Instance.new("TextButton")
MinBtn.Text            = "─"
MinBtn.Size            = UDim2.new(0,24,0,22)
MinBtn.Position        = UDim2.new(1,-54,0.5,-11)
MinBtn.BackgroundColor3= T.MIN_BTN
MinBtn.TextColor3      = T.TXT_ON
MinBtn.TextSize        = 12
MinBtn.Font            = Enum.Font.GothamBold
MinBtn.BorderSizePixel = 0
MinBtn.ZIndex          = 13
MinBtn.Parent          = Header
Instance.new("UICorner",MinBtn).CornerRadius = UDim.new(0,4)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text          = "×"
CloseBtn.Size          = UDim2.new(0,24,0,22)
CloseBtn.Position      = UDim2.new(1,-27,0.5,-11)
CloseBtn.BackgroundColor3 = T.CLOSE
CloseBtn.TextColor3    = Color3.new(1,1,1)
CloseBtn.TextSize      = 16
CloseBtn.Font          = Enum.Font.GothamBold
CloseBtn.BorderSizePixel = 0
CloseBtn.ZIndex        = 13
CloseBtn.Parent        = Header
Instance.new("UICorner",CloseBtn).CornerRadius = UDim.new(0,4)

local HDivider = Instance.new("Frame")
HDivider.Size          = UDim2.new(1,0,0,1)
HDivider.Position      = UDim2.new(0,0,0,HDR_H)
HDivider.BackgroundColor3 = T.LINE
HDivider.BorderSizePixel  = 0
HDivider.ZIndex        = 11
HDivider.Parent        = Win

local Sidebar = Instance.new("Frame")
Sidebar.Name           = "Sidebar"
Sidebar.Size           = UDim2.new(0,SIDE_W,1,-HDR_H-1)
Sidebar.Position       = UDim2.new(0,0,0,HDR_H+1)
Sidebar.BackgroundColor3 = T.SIDEBAR
Sidebar.BorderSizePixel  = 0
Sidebar.ZIndex         = 11
Sidebar.Parent         = Win

local SideLayout = Instance.new("UIListLayout")
SideLayout.SortOrder   = Enum.SortOrder.LayoutOrder
SideLayout.Padding     = UDim.new(0,0)
SideLayout.Parent      = Sidebar

local VDiv = Instance.new("Frame")
VDiv.Size              = UDim2.new(0,1,1,-HDR_H-1)
VDiv.Position          = UDim2.new(0,SIDE_W,0,HDR_H+1)
VDiv.BackgroundColor3  = T.LINE
VDiv.BorderSizePixel   = 0
VDiv.ZIndex            = 11
VDiv.Parent            = Win

local Panel = Instance.new("ScrollingFrame")
Panel.Name             = "Panel"
Panel.Size             = UDim2.new(1,-SIDE_W-1,1,-HDR_H-1)
Panel.Position         = UDim2.new(0,SIDE_W+1,0,HDR_H+1)
Panel.BackgroundColor3 = T.PANEL
Panel.BorderSizePixel  = 0
Panel.ScrollBarThickness   = 3
Panel.ScrollBarImageColor3 = T.ACCENT
Panel.CanvasSize           = UDim2.new(0,0,0,0)
Panel.AutomaticCanvasSize  = Enum.AutomaticSize.Y
Panel.ZIndex           = 11
Panel.Parent           = Win

local PanelLayout = Instance.new("UIListLayout")
PanelLayout.SortOrder  = Enum.SortOrder.LayoutOrder
PanelLayout.Padding    = UDim.new(0,0)
PanelLayout.Parent     = Panel

local PanelPad = Instance.new("UIPadding")
PanelPad.PaddingLeft   = UDim.new(0,8)
PanelPad.PaddingRight  = UDim.new(0,8)
PanelPad.PaddingTop    = UDim.new(0,6)
PanelPad.PaddingBottom = UDim.new(0,8)
PanelPad.Parent        = Panel

-- ══════════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════════
local TABS = {
    {id="ESP",    icon="👁",  label="ESP"    },
    {id="Aimbot", icon="🎯",  label="Aimbot" },
    {id="Keys",   icon="⌨",  label="Keys"   },
    {id="Visuals",icon="🎨",  label="Visuals"},
    {id="Fun",    icon="⚡",  label="Fun"    },
    {id="Emotes", icon="😈",  label="Emotes" },
    {id="Sound",  icon="🔊",  label="Sound"  },
}

local activeTab   = nil
local tabButtons  = {}
local tabContents = {}

local function setTab(id)
    for _,children in pairs(tabContents) do
        for _,w in ipairs(children) do w.Visible = false end
    end
    for _,btn in pairs(tabButtons) do
        btn.BackgroundColor3       = T.SIDEBAR
        btn.BackgroundTransparency = 1
        btn.TextColor3             = T.TXT_DIM
        local bar = btn:FindFirstChild("AccBar")
        if bar then bar.BackgroundTransparency = 1 end
    end
    if tabContents[id] then
        for _,w in ipairs(tabContents[id]) do w.Visible = true end
    end
    local ab = tabButtons[id]
    if ab then
        ab.BackgroundColor3       = T.TAB_SEL
        ab.BackgroundTransparency = 0
        ab.TextColor3             = T.TXT_ON
        local bar = ab:FindFirstChild("AccBar")
        if bar then bar.BackgroundTransparency = 0 end
    end
    activeTab = id
end

for order,tab in ipairs(TABS) do
    tabContents[tab.id] = {}
    local btn = Instance.new("TextButton")
    btn.Name               = tab.id
    btn.Size               = UDim2.new(1,0,0,36)
    btn.BackgroundColor3   = T.SIDEBAR
    btn.BackgroundTransparency = 1
    btn.Text               = tab.icon.."  "..tab.label
    btn.TextColor3         = T.TXT_DIM
    btn.TextSize           = 12
    btn.Font               = Enum.Font.Gotham
    btn.TextXAlignment     = Enum.TextXAlignment.Left
    btn.BorderSizePixel    = 0
    btn.LayoutOrder        = order
    btn.ZIndex             = 12
    btn.Parent             = Sidebar
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0,10)
    pad.Parent      = btn
    local bar = Instance.new("Frame")
    bar.Name                   = "AccBar"
    bar.Size                   = UDim2.new(0,3,0,18)
    bar.Position               = UDim2.new(0,0,0.5,-9)
    bar.BackgroundColor3       = T.ACCENT
    bar.BorderSizePixel        = 0
    bar.BackgroundTransparency = 1
    bar.ZIndex                 = 13
    bar.Parent                 = btn
    Instance.new("UICorner",bar).CornerRadius = UDim.new(1,0)
    tabButtons[tab.id] = btn
    btn.MouseButton1Click:Connect(function() setTab(tab.id) end)
    btn.MouseEnter:Connect(function()
        if activeTab ~= tab.id then
            btn.BackgroundColor3       = T.TAB_SEL
            btn.BackgroundTransparency = 0.6
        end
    end)
    btn.MouseLeave:Connect(function()
        if activeTab ~= tab.id then
            btn.BackgroundTransparency = 1
        end
    end)
end

-- ══════════════════════════════════════════════
--  WIDGET BUILDERS
-- ══════════════════════════════════════════════
local wOrder = 0
local function regWidget(tabId, w)
    table.insert(tabContents[tabId], w)
    w.Visible = false
end

local function secHeader(tabId, text)
    wOrder += 1
    local f = Instance.new("Frame")
    f.Size             = UDim2.new(1,0,0,24)
    f.BackgroundColor3 = T.SEC
    f.BorderSizePixel  = 0
    f.LayoutOrder      = wOrder
    f.ZIndex           = 12
    f.Parent           = Panel
    local lbl = Instance.new("TextLabel")
    lbl.Text           = text
    lbl.Size           = UDim2.new(1,-8,1,0)
    lbl.Position       = UDim2.new(0,8,0,0)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3     = T.TXT_ON
    lbl.TextSize       = 11
    lbl.Font           = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.ZIndex         = 13
    lbl.Parent         = f
    regWidget(tabId, f)
    return f
end

local function makeToggle(tabId, label, desc, initVal, callback)
    wOrder += 1
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0, desc ~= "" and 42 or 36)
    row.BackgroundColor3 = T.ROW_A
    row.BorderSizePixel  = 0
    row.LayoutOrder      = wOrder
    row.ZIndex           = 12
    row.Parent           = Panel

    local strip = Instance.new("Frame")
    strip.Size             = UDim2.new(0,2,1,0)
    strip.BackgroundColor3 = initVal and T.ACCENT or T.TXT_DIM
    strip.BorderSizePixel  = 0
    strip.ZIndex           = 13
    strip.Parent           = row

    local lbl = Instance.new("TextLabel")
    lbl.Text             = label
    lbl.Size             = UDim2.new(1,-58,0,18)
    lbl.Position         = UDim2.new(0,10,0,6)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = initVal and T.TXT_ON or T.TXT_DIM
    lbl.TextSize         = 13
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 13
    lbl.Parent           = row

    if desc and desc ~= "" then
        local dlbl = Instance.new("TextLabel")
        dlbl.Text            = desc
        dlbl.Size            = UDim2.new(1,-58,0,12)
        dlbl.Position        = UDim2.new(0,10,0,24)
        dlbl.BackgroundTransparency = 1
        dlbl.TextColor3      = Color3.fromRGB(80,80,110)
        dlbl.TextSize        = 10
        dlbl.Font            = Enum.Font.Gotham
        dlbl.TextXAlignment  = Enum.TextXAlignment.Left
        dlbl.ZIndex          = 13
        dlbl.Parent          = row
    end

    local pill = Instance.new("Frame")
    pill.Size            = UDim2.new(0,42,0,22)
    pill.Position        = UDim2.new(1,-50,0.5,-11)
    pill.BackgroundColor3= initVal and T.ACCENT or T.PILL_OFF
    pill.BorderSizePixel = 0
    pill.ZIndex          = 13
    pill.Parent          = row
    Instance.new("UICorner",pill).CornerRadius = UDim.new(1,0)

    local dot = Instance.new("Frame")
    dot.Size             = UDim2.new(0,16,0,16)
    dot.Position         = initVal and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)
    dot.BackgroundColor3 = Color3.new(1,1,1)
    dot.BorderSizePixel  = 0
    dot.ZIndex           = 14
    dot.Parent           = pill
    Instance.new("UICorner",dot).CornerRadius = UDim.new(1,0)

    local state = initVal
    local function setState(v)
        state = v
        lbl.TextColor3         = v and T.TXT_ON or T.TXT_DIM
        strip.BackgroundColor3 = v and T.ACCENT or T.TXT_DIM
        TweenSvc:Create(pill,TweenInfo.new(0.15),{BackgroundColor3 = v and T.ACCENT or T.PILL_OFF}):Play()
        TweenSvc:Create(dot, TweenInfo.new(0.15),{Position = v and UDim2.new(1,-19,0.5,-8) or UDim2.new(0,3,0.5,-8)}):Play()
        callback(v)
    end

    local hitbox = Instance.new("TextButton")
    hitbox.Size            = UDim2.new(1,0,1,0)
    hitbox.BackgroundTransparency = 1
    hitbox.Text            = ""
    hitbox.ZIndex          = 15
    hitbox.Parent          = row
    hitbox.MouseButton1Click:Connect(function() setState(not state) end)
    hitbox.MouseEnter:Connect(function()
        TweenSvc:Create(row,TweenInfo.new(0.1),{BackgroundColor3 = T.SEC}):Play()
    end)
    hitbox.MouseLeave:Connect(function()
        TweenSvc:Create(row,TweenInfo.new(0.1),{BackgroundColor3 = T.ROW_A}):Play()
    end)

    regWidget(tabId, row)
    return row, setState
end

local function makeSlider(tabId, label, minV, maxV, initVal, fmtFn, callback)
    wOrder += 1
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,52)
    row.BackgroundColor3 = T.ROW_B
    row.BorderSizePixel  = 0
    row.LayoutOrder      = wOrder
    row.ZIndex           = 12
    row.Parent           = Panel

    local lbl = Instance.new("TextLabel")
    lbl.Text             = label.."   "..fmtFn(initVal)
    lbl.Size             = UDim2.new(1,-8,0,18)
    lbl.Position         = UDim2.new(0,10,0,6)
    lbl.BackgroundTransparency = 1
    lbl.TextColor3       = T.TXT_ON
    lbl.TextSize         = 12
    lbl.Font             = Enum.Font.GothamBold
    lbl.TextXAlignment   = Enum.TextXAlignment.Left
    lbl.ZIndex           = 13
    lbl.Parent           = row

    local track = Instance.new("Frame")
    track.Size             = UDim2.new(1,-20,0,6)
    track.Position         = UDim2.new(0,10,0,32)
    track.BackgroundColor3 = Color3.fromRGB(50,50,65)
    track.BorderSizePixel  = 0
    track.ZIndex           = 13
    track.Parent           = row
    Instance.new("UICorner",track).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame")
    fill.Size            = UDim2.new((initVal-minV)/(maxV-minV),0,1,0)
    fill.BackgroundColor3= T.ACCENT
    fill.BorderSizePixel = 0
    fill.ZIndex          = 14
    fill.Parent          = track
    Instance.new("UICorner",fill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame")
    knob.Size            = UDim2.new(0,14,0,14)
    knob.AnchorPoint     = Vector2.new(0.5,0.5)
    knob.Position        = UDim2.new((initVal-minV)/(maxV-minV),0,0.5,0)
    knob.BackgroundColor3= Color3.fromRGB(230,230,255)
    knob.BorderSizePixel = 0
    knob.ZIndex          = 15
    knob.Parent          = track
    Instance.new("UICorner",knob).CornerRadius = UDim.new(1,0)

    local dragging = false
    local function setValue(v)
        v = math.clamp(math.floor(v), minV, maxV)
        local t = (v-minV)/(maxV-minV)
        fill.Size     = UDim2.new(t,0,1,0)
        knob.Position = UDim2.new(t,0,0.5,0)
        lbl.Text      = label.."   "..fmtFn(v)
        callback(v)
    end

    local db = Instance.new("TextButton")
    db.Size               = UDim2.new(1,0,1,0)
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
            local abs  = track.AbsolutePosition
            local sz   = track.AbsoluteSize
            local relX = math.clamp(i.Position.X - abs.X, 0, sz.X)
            setValue(minV + (relX/sz.X)*(maxV-minV))
        end
    end)

    regWidget(tabId, row)
    return row, setValue
end

local function makeKeyRow(tabId, action, key, alt)
    wOrder += 1
    local row = Instance.new("Frame")
    row.Size             = UDim2.new(1,0,0,28)
    row.BackgroundColor3 = alt and T.ROW_B or T.ROW_A
    row.BorderSizePixel  = 0
    row.LayoutOrder      = wOrder
    row.ZIndex           = 12
    row.Parent           = Panel
    local la = Instance.new("TextLabel")
    la.Text              = action
    la.Size              = UDim2.new(0.6,0,1,0)
    la.Position          = UDim2.new(0,10,0,0)
    la.BackgroundTransparency = 1
    la.TextColor3        = T.TXT_DIM
    la.TextSize          = 12
    la.Font              = Enum.Font.Gotham
    la.TextXAlignment    = Enum.TextXAlignment.Left
    la.ZIndex            = 13
    la.Parent            = row
    local lb = Instance.new("TextLabel")
    lb.Text              = key
    lb.Size              = UDim2.new(0.4,-8,1,0)
    lb.Position          = UDim2.new(0.6,0,0,0)
    lb.BackgroundTransparency = 1
    lb.TextColor3        = T.TXT_ACC
    lb.TextSize          = 12
    lb.Font              = Enum.Font.GothamBold
    lb.TextXAlignment    = Enum.TextXAlignment.Right
    lb.ZIndex            = 13
    lb.Parent            = row
    regWidget(tabId, row)
end

-- ══════════════════════════════════════════════
--  POPULATE TABS
-- ══════════════════════════════════════════════
secHeader("ESP","ESP")
makeToggle("ESP","ESP Enable",   "กรอบ / ชื่อ / HP / ระยะ", CFG.ESP_ENABLED,  function(v) CFG.ESP_ENABLED  =v end)
makeToggle("ESP","Box",          "",                          CFG.ESP_BOX,      function(v) CFG.ESP_BOX      =v end)
makeToggle("ESP","Name",         "",                          CFG.ESP_NAME,     function(v) CFG.ESP_NAME     =v end)
makeToggle("ESP","Health",       "",                          CFG.ESP_HEALTH,   function(v) CFG.ESP_HEALTH   =v end)
makeToggle("ESP","Distance",     "",                          CFG.ESP_DISTANCE, function(v) CFG.ESP_DISTANCE =v end)
makeToggle("ESP","Skeleton",     "โครงกระดูกผู้เล่น",        CFG.SKE_ENABLED,  function(v) CFG.SKE_ENABLED  =v end)

secHeader("Aimbot","AIMBOT")
makeToggle("Aimbot","Aimbot Enable", "hard-lock หัว",        CFG.AIM_ENABLED,       function(v) CFG.AIM_ENABLED       =v end)
makeToggle("Aimbot","Show FOV",      "วงกลม crosshair",       CFG.AIM_FOV_VISIBLE,   function(v)
    CFG.AIM_FOV_VISIBLE = v
    fovCircle.Visible   = v and CFG.AIM_ENABLED and not mouseUnlocked
end)
makeToggle("Aimbot","Visible Check", "ไม่ล็อคคนหลังกำแพง",   CFG.AIM_VISIBLE_CHECK, function(v) CFG.AIM_VISIBLE_CHECK=v end)
makeToggle("Aimbot","Team Check",    "ข้ามทีมเดียวกัน",       CFG.AIM_TEAM_CHECK,    function(v) CFG.AIM_TEAM_CHECK    =v end)
makeToggle("Aimbot","Vehicle Lock",  "ล็อคผู้เล่นบนรถได้",    CFG.AIM_VEHICLE,       function(v) CFG.AIM_VEHICLE       =v end)
secHeader("Aimbot","FOV RADIUS")
makeSlider("Aimbot","FOV",20,500,CFG.AIM_FOV,function(v) return v.." px" end,function(v)
    CFG.AIM_FOV      = v
    fovCircle.Radius = v
end)
secHeader("Aimbot","SMOOTH")
makeSlider("Aimbot","Smooth",1,100,math.floor(CFG.AIM_SMOOTH*100),
    function(v) return v.."%" end,
    function(v) CFG.AIM_SMOOTH = v/100 end
)

secHeader("Keys","KEYBINDS")
makeKeyRow("Keys","Lock (hold)",  "E",         false)
makeKeyRow("Keys","ESP / UI",     "X / INSERT",true)
makeKeyRow("Keys","FOV  +  / −", "]  /  [",   false)
makeKeyRow("Keys","Mouse unlock", "ALT",       true)

for _,tid in ipairs({"Visuals","Fun","Emotes","Sound"}) do
    wOrder += 1
    local ph = Instance.new("TextLabel")
    ph.Text              = "— coming soon —"
    ph.Size              = UDim2.new(1,0,0,40)
    ph.LayoutOrder       = wOrder
    ph.BackgroundTransparency = 1
    ph.TextColor3        = T.TXT_DIM
    ph.TextSize          = 12
    ph.Font              = Enum.Font.Gotham
    ph.ZIndex            = 12
    ph.Parent            = Panel
    regWidget(tid, ph)
end

-- ══════════════════════════════════════════════
--  UI SHOW/HIDE
-- ══════════════════════════════════════════════
local function setUIVisible(v)
    uiVisible   = v
    Win.Visible = v
    if not v and mouseUnlocked then lockMouse() end
end

CloseBtn.MouseButton1Click:Connect(function() setUIVisible(false) end)

MinBtn.MouseButton1Click:Connect(function()
    local collapse = Panel.Visible
    Panel.Visible   = not collapse
    Sidebar.Visible = not collapse
    VDiv.Visible    = not collapse
    Win.Size = collapse
        and UDim2.new(0,WIN_W,0,HDR_H+2)
        or  UDim2.new(0,WIN_W,0,WIN_H)
end)

setTab("ESP")

-- ══════════════════════════════════════════════
--  DRAG
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
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
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
--  AIMBOT — vehicle-aware, smooth, mousemoverel-only
-- ══════════════════════════════════════════════
local function getPlayerOnVehicle(plr)
    local char = getChar(plr)
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return false end
    if hum.SeatPart ~= nil then return true end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("WeldConstraint") then
            local p0 = v.Part0
            local p1 = v.Part1
            if p0 and p0:IsA("VehicleSeat") then return true end
            if p1 and p1:IsA("VehicleSeat") then return true end
        end
    end
    return false
end

local function getBestTarget()
    local center   = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local bestDist = CFG.AIM_FOV
    local bestPlr  = nil
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if isTeammate(plr) then continue end
        local char  = getChar(plr)
        local root,human = getRootAndHuman(plr)
        if not char or not root or not human or human.Health <= 0 then continue end
        if CFG.AIM_VEHICLE == false and getPlayerOnVehicle(plr) then continue end
        local bone = getTargetBone(char)
        if not bone then continue end
        local bonePos = bone.CFrame.Position + CFG.AIM_HEAD_OFFSET
        local screen2d,onScreen = worldToScreen(bonePos)
        if not onScreen then continue end
        if CFG.AIM_VISIBLE_CHECK and not isVisible(char,bonePos) then continue end
        local d = (screen2d - center).Magnitude
        if d < bestDist then bestDist=d bestPlr=plr end
    end
    return bestPlr
end

local function doAimbot()
    if not CFG.AIM_ENABLED or not aimActive or mouseUnlocked then
        lockedTarget = nil return
    end
    if lockedTarget then
        local char  = getChar(lockedTarget)
        local _,human = getRootAndHuman(lockedTarget)
        if not human or human.Health <= 0 then
            lockedTarget = nil
        elseif CFG.AIM_VISIBLE_CHECK and char then
            local bone = getTargetBone(char)
            if bone and not isVisible(char, bone.CFrame.Position + CFG.AIM_HEAD_OFFSET) then
                lockedTarget = nil
            end
        end
        if lockedTarget and CFG.AIM_VEHICLE == false and getPlayerOnVehicle(lockedTarget) then
            lockedTarget = nil
        end
    end
    if not lockedTarget then lockedTarget = getBestTarget() end
    if not lockedTarget then return end

    local char = getChar(lockedTarget)
    local bone = char and getTargetBone(char)
    if not bone then lockedTarget = nil return end

    local bonePos        = bone.CFrame.Position + CFG.AIM_HEAD_OFFSET
    local screen2d,onScreen = worldToScreen(bonePos)
    if not onScreen then lockedTarget = nil return end

    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local delta  = screen2d - center

    if delta.Magnitude > CFG.AIM_FOV then lockedTarget = nil return end

    local step = math.clamp(CFG.AIM_SMOOTH, 0.01, 1.0)
    mousemoverel(delta.X * step, delta.Y * step)
end

-- ══════════════════════════════════════════════
--  PLAYER HOOKS
-- ══════════════════════════════════════════════
local function onPlayerAdded(plr)
    buildESP(plr)
    plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        removeESP(plr)
        buildESP(plr)
    end)
end

for _,plr in ipairs(Players:GetPlayers()) do
    if plr ~= LocalPlayer then onPlayerAdded(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    if plr ~= LocalPlayer then onPlayerAdded(plr) end
end)
Players.PlayerRemoving:Connect(removeESP)

-- ══════════════════════════════════════════════
--  INPUT — ALT ทำงานตลอด ไม่ต้องเปิดเมนูก่อน
-- ══════════════════════════════════════════════
UserInputSvc.InputBegan:Connect(function(input, gpe)
    -- INSERT: toggle UI — no gpe check, fires always
    if input.KeyCode == CFG.KEY_UI_TOGGLE then
        setUIVisible(not uiVisible)
        return
    end

    -- ALT: toggle mouse + FOV — no gpe check, fires always, no uiVisible gate
    if input.KeyCode == CFG.KEY_MOUSE_TOGGLE then
        if mouseUnlocked then
            lockMouse()
            fovCircle.Visible = CFG.AIM_FOV_VISIBLE and CFG.AIM_ENABLED
        else
            unlockMouse()
            fovCircle.Visible = false
        end
        return
    end

    -- everything else: respect gpe so UI clicks don't bleed through
    if gpe then return end

    if input.KeyCode == CFG.KEY_LOCK then aimActive = true end

    if input.KeyCode == CFG.KEY_ESP_TOGGLE then
        CFG.ESP_ENABLED = not CFG.ESP_ENABLED
        if not CFG.ESP_ENABLED then
            for _,esp in pairs(espObjects) do
                for _,d in pairs(esp) do d.Visible = false end
            end
        end
    end

    if input.KeyCode == CFG.KEY_FOV_UP then
        CFG.AIM_FOV      = math.min(CFG.AIM_FOV + 10, 500)
        fovCircle.Radius = CFG.AIM_FOV
    end

    if input.KeyCode == CFG.KEY_FOV_DOWN then
        CFG.AIM_FOV      = math.max(CFG.AIM_FOV - 10, 20)
        fovCircle.Radius = CFG.AIM_FOV
    end
end)

UserInputSvc.InputEnded:Connect(function(input)
    if input.KeyCode == CFG.KEY_LOCK then
        aimActive = false
        lockedTarget = nil
    end
end)

-- ══════════════════════════════════════════════
--  MAIN LOOP
-- ══════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    doAimbot()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then updateESP(plr) end
    end
end)

print("[ STEPTHEP v1.1 ] loaded — INSERT=menu | ALT=mouse(ตลอด) | E=lock")
