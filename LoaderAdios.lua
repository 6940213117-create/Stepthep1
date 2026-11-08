-- ╔══════════════════════════════════════════════════════╗
-- ║          STEPTHEP  v1.1  |  Urban Reload            ║
-- ║   ESP · Skeleton · FOV Aimbot · Vehicle Lock        ║
-- ║   Executor: Xeno / Synapse X / UNC-compliant        ║
-- ║   Mobile patch: shoot-to-lock + floating toggle     ║
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
    -- KEY_LOCK ถูกลบออก — trigger ตอนยิง (MB1) แทนแล้ว
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
local aimActive     = false   -- true เมื่อนิ้วกดปุ่มยิง (MB1 / touch)
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

-- ══════════════════════════════════════════════════════════════
--  [ส่วนนี้คัดลอก Fluent bundle (local Fluent = ...) จากต้นฉบับ
--   ไม่แตะบรรทัดใดเลย — วางทั้งก้อนลงตรงนี้]
-- ══════════════════════════════════════════════════════════════
-- << INSERT ORIGINAL FLUENT BUNDLE HERE (lines 264–826 of source) >>

-- ══════════════════════════════════════════════
--  FLOATING TOGGLE BUTTON  (mobile-first)
--  ปุ่มลอยกลมมุมล่างขวา — แตะเพื่อเปิด/ปิดเมนู Fluent
--  Draggable: กด-ค้างแล้วลาก
-- ══════════════════════════════════════════════
local function createFloatingToggle(onToggle)
    local sg = Instance.new("ScreenGui")
    sg.Name              = "STEPTHEP_FloatBtn"
    sg.ResetOnSpawn      = false
    sg.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset    = true
    if syn and syn.protect_gui then syn.protect_gui(sg) end
    sg.Parent = game:GetService("CoreGui")

    -- ปุ่มหลัก
    local btn = Instance.new("TextButton", sg)
    btn.Size                   = UDim2.fromOffset(56, 56)
    btn.Position               = UDim2.new(1, -68, 1, -80)   -- มุมล่างขวา
    btn.AnchorPoint            = Vector2.new(0, 0)
    btn.BackgroundColor3       = Color3.fromRGB(18, 18, 18)
    btn.BorderSizePixel        = 0
    btn.Text                   = "☰"
    btn.TextColor3             = Color3.fromRGB(240, 240, 240)
    btn.TextSize               = 22
    btn.Font                   = Enum.Font.GothamSemiBold
    btn.AutoButtonColor        = false
    btn.ZIndex                 = 100
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness    = 1.5
    stroke.Color        = Color3.fromRGB(80, 160, 255)
    stroke.Transparency = 0.4

    -- ── Drag logic ──────────────────────────────────────
    local dragging   = false
    local dragStart  = Vector2.new()
    local startPos   = Vector2.new()
    local DRAG_THRESHOLD = 8  -- px — ถ้าขยับน้อยกว่านี้ถือว่า tap

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos  = Vector2.new(
                btn.Position.X.Offset,
                btn.Position.Y.Offset
            )
        end
    end)

    UserInputSvc.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = Vector2.new(input.Position.X, input.Position.Y) - dragStart
            local vp    = Camera.ViewportSize
            local nx    = math.clamp(startPos.X + delta.X, 0, vp.X - 60)
            local ny    = math.clamp(startPos.Y + delta.Y, 0, vp.Y - 60)
            btn.Position = UDim2.new(0, nx, 0, ny)
        end
    end)

    btn.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local releasePos = Vector2.new(input.Position.X, input.Position.Y)
            local moved      = (releasePos - dragStart).Magnitude
            dragging = false
            if moved < DRAG_THRESHOLD then
                -- ถือว่า tap → toggle
                onToggle()
                -- flash เล็กน้อย
                TweenSvc:Create(btn, TweenInfo.new(0.08), {
                    BackgroundColor3 = Color3.fromRGB(50, 110, 180)
                }):Play()
                task.delay(0.12, function()
                    TweenSvc:Create(btn, TweenInfo.new(0.12), {
                        BackgroundColor3 = Color3.fromRGB(18, 18, 18)
                    }):Play()
                end)
            end
        end
    end)

    return sg
end

-- ══════════════════════════════════════════════
--  AIMBOT CORE
-- ══════════════════════════════════════════════
local function getPlayerOnVehicle(plr)
    local char = getChar(plr)
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return root.AssemblyRootPart ~= root
end

local function getBestTarget()
    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local bestDist = math.huge
    local bestPlr  = nil
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr == LocalPlayer then continue end
        if isTeammate(plr) then continue end
        if not CFG.AIM_VEHICLE and getPlayerOnVehicle(plr) then continue end
        local char = getChar(plr)
        if not char then continue end
        local _,human = getRootAndHuman(plr)
        if not human or human.Health <= 0 then continue end
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
    if not CFG.AIM_ENABLED or not aimActive then
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
--  UI VISIBILITY HELPER
-- ══════════════════════════════════════════════
local function setUIVisible(v)
    uiVisible = v
    if Fluent and Fluent.Window then
        Fluent.Window.Root.Visible = v
    end
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
--  INPUT
--  ► MB1 (ปุ่มยิง) → aimActive = true ทันที
--  ► ALT  — unlock/lock mouse (ไม่เปลี่ยน)
--  ► INSERT / RightCtrl — toggle UI (keyboard fallback)
--  ► X, [, ] — ESP / FOV
-- ══════════════════════════════════════════════
UserInputSvc.InputBegan:Connect(function(input, gpe)
    -- INSERT: toggle UI — no gpe check
    if input.KeyCode == CFG.KEY_UI_TOGGLE then
        setUIVisible(not uiVisible)
        return
    end

    -- ALT: toggle mouse — no gpe check
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

    if gpe then return end

    -- ★ SHOOT-TO-LOCK: MB1 กดปุ่บ aimActive = true
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        aimActive = true
        return
    end

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
    -- ★ ปล่อยปุ่มยิง → หยุด aimbot + clear lock
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        aimActive    = false
        lockedTarget = nil
        return
    end
end)

-- ══════════════════════════════════════════════
--  FLOATING BUTTON — สร้างหลัง Fluent โหลด
-- ══════════════════════════════════════════════
-- เรียกหลัง startMain() / หลัง Fluent.Window พร้อม
-- วางได้ทั้ง PC และมือถือ
local _floatGui = createFloatingToggle(function()
    setUIVisible(not uiVisible)
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

-- ════════════════════════════════════════════════════════
--  SECURITY PATCH: fullCleanup() on UI Exit & Key Expiry
-- ════════════════════════════════════════════════════════
local cleanupDone = false
local function fullCleanup()
    if cleanupDone then return end
    cleanupDone = true

    CFG.ESP_ENABLED       = false
    CFG.ESP_BOX           = false
    CFG.ESP_NAME          = false
    CFG.ESP_HEALTH        = false
    CFG.ESP_DISTANCE      = false
    CFG.SKE_ENABLED       = false
    CFG.AIM_ENABLED       = false
    CFG.AIM_FOV_VISIBLE   = false
    CFG.AIM_TEAM_CHECK    = false
    CFG.AIM_VISIBLE_CHECK = false
    CFG.AIM_VEHICLE       = false

    aimActive    = false
    lockedTarget = nil

    for plr in pairs(espObjects) do removeESP(plr) end
    espObjects  = {}
    skelObjects = {}

    pcall(function()
        fovCircle.Visible = false
        fovCircle:Remove()
    end)
    pcall(function()
        UserInputSvc.MouseBehavior    = Enum.MouseBehavior.Default
        UserInputSvc.MouseIconEnabled = true
        mouseUnlocked = false
    end)
    -- ลบปุ่มลอย
    pcall(function() _floatGui:Destroy() end)
    pcall(function() Fluent:Destroy() end)

    print("[ STEPTHEP ] fullCleanup() complete — all features off, drawings removed.")
end

-- Hook 1: Fluent Close → fullCleanup()
task.spawn(function()
    repeat task.wait(0.3) until Fluent.Unloaded == true
    fullCleanup()
end)

-- Hook 2: Key Expiry → fullCleanup()
do
    local watchExpiry = nil
    if type(authResult) == "table" and type(authResult.subscriptions) == "table" then
        for _, sub in ipairs(authResult.subscriptions) do
            local exp = tonumber(sub.expiry)
            if exp and exp > 0 then
                if not watchExpiry or exp > watchExpiry then
                    watchExpiry = exp
                end
            end
        end
    end

    if watchExpiry then
        task.spawn(function()
            while not cleanupDone do
                task.wait(5)
                local now = math.floor(tick())
                if now >= watchExpiry then
                    fullCleanup()
                    task.wait(0.3)
                    pcall(function()
                        local sg = Instance.new("ScreenGui")
                        sg.ResetOnSpawn = false
                        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                        if syn and syn.protect_gui then syn.protect_gui(sg) end
                        sg.Parent = game:GetService("CoreGui")

                        local frame = Instance.new("Frame", sg)
                        frame.Size          = UDim2.fromOffset(400, 90)
                        frame.Position      = UDim2.new(0.5, -200, 0.5, -45)
                        frame.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
                        frame.BorderSizePixel  = 0
                        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
                        Instance.new("UIStroke", frame).Thickness = 1

                        local title = Instance.new("TextLabel", frame)
                        title.Size               = UDim2.new(1, -20, 0, 28)
                        title.Position           = UDim2.fromOffset(10, 8)
                        title.BackgroundTransparency = 1
                        title.TextColor3         = Color3.fromRGB(255, 70, 70)
                        title.TextSize           = 15
                        title.Font               = Enum.Font.GothamSemiBold
                        title.TextXAlignment     = Enum.TextXAlignment.Left
                        title.Text               = "⚠  License หมดอายุแล้ว — กรุณารัน script ใหม่เพื่อเข้าสู่หน้าใส่ Key"

                        local sub2 = Instance.new("TextLabel", frame)
                        sub2.Size                = UDim2.new(1, -20, 0, 22)
                        sub2.Position            = UDim2.fromOffset(10, 44)
                        sub2.BackgroundTransparency = 1
                        sub2.TextColor3          = Color3.fromRGB(150, 150, 150)
                        sub2.TextSize            = 12
                        sub2.Font                = Enum.Font.Gotham
                        sub2.TextXAlignment      = Enum.TextXAlignment.Left
                        sub2.Text                = "ระบบได้ปิด ESP, Aimbot และคืนค่า offset ทุกอย่างแล้ว"

                        task.delay(10, function()
                            pcall(function() sg:Destroy() end)
                        end)
                    end)
                    break
                end
            end
        end)
    end
end

print("[ STEPTHEP v1.1 ] loaded — INSERT/FloatBtn=menu | ALT=mouse | MB1=aim-lock")
