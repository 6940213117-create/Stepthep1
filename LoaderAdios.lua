-- ╔══════════════════════════════════════════════════════╗
-- ║          STEPTHEP  v1.2  |  Urban Reload            ║
-- ║   Mobile-safe boot: Fluent guard + KeyAuth fallback ║
-- ╚══════════════════════════════════════════════════════╝

-- ══════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UserInputSvc = game:GetService("UserInputService")
local TweenSvc     = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local Camera       = workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer

-- ══════════════════════════════════════════════
--  SAFE protectgui SHIM
--  executor มือถือหลายตัวไม่มี syn / protectgui
-- ══════════════════════════════════════════════
local function safeProtect(gui)
    if type(protectgui) == "function" then
        pcall(protectgui, gui)
    elseif syn and type(syn.protect_gui) == "function" then
        pcall(syn.protect_gui, gui)
    elseif gethui and type(gethui) == "function" then
        pcall(function() gui.Parent = gethui() end)
        return  -- gethui path sets parent itself
    end
end

-- ══════════════════════════════════════════════
--  SAFE CoreGui PARENT
-- ══════════════════════════════════════════════
local function safeCoreParent(gui)
    local ok = pcall(function()
        safeProtect(gui)
        gui.Parent = game:GetService("CoreGui")
    end)
    if not ok then
        pcall(function() gui.Parent = LocalPlayer:WaitForChild("PlayerGui") end)
    end
end

-- ══════════════════════════════════════════════
--  CONFIG
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
    KEY_ESP_TOGGLE    = Enum.KeyCode.X,
    KEY_FOV_UP        = Enum.KeyCode.RightBracket,
    KEY_FOV_DOWN      = Enum.KeyCode.LeftBracket,
    KEY_UI_TOGGLE     = Enum.KeyCode.Insert,
    KEY_MOUSE_TOGGLE  = Enum.KeyCode.LeftAlt,
}

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
    {"Head","UpperTorso"},{"Head","Torso"},
    {"UpperTorso","LowerTorso"},
    {"Torso","HumanoidRootPart"},{"UpperTorso","HumanoidRootPart"},
    {"UpperTorso","LeftUpperArm"},{"LeftUpperArm","LeftLowerArm"},{"LeftLowerArm","LeftHand"},
    {"UpperTorso","RightUpperArm"},{"RightUpperArm","RightLowerArm"},{"RightLowerArm","RightHand"},
    {"LowerTorso","LeftUpperLeg"},{"LeftUpperLeg","LeftLowerLeg"},{"LeftLowerLeg","LeftFoot"},
    {"LowerTorso","RightUpperLeg"},{"RightUpperLeg","RightLowerLeg"},{"RightLowerLeg","RightFoot"},
    {"Torso","Left Arm"},{"Left Arm","Left Hand"},
    {"Torso","Right Arm"},{"Right Arm","Right Hand"},
    {"Torso","Left Leg"},{"Left Leg","Left Foot"},
    {"Torso","Right Leg"},{"Right Leg","Right Foot"},
}

-- ══════════════════════════════════════════════
--  MOUSE HELPERS
-- ══════════════════════════════════════════════
local function unlockMouse()
    pcall(function()
        UserInputSvc.MouseBehavior    = Enum.MouseBehavior.Default
        UserInputSvc.MouseIconEnabled = true
    end)
    mouseUnlocked = true
end
local function lockMouse()
    pcall(function()
        UserInputSvc.MouseBehavior    = Enum.MouseBehavior.LockCenter
        UserInputSvc.MouseIconEnabled = false
    end)
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

local function getPlayerOnVehicle(plr)
    local char = getChar(plr)
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    return root.AssemblyRootPart ~= root
end

-- ══════════════════════════════════════════════
--  ESP + SKELETON
-- ══════════════════════════════════════════════
local function buildESP(plr)
    if espObjects[plr] then return end
    espObjects[plr] = {
        box    = newDraw("Square",{Visible=false,Color=CFG.ESP_COLOR,Thickness=CFG.ESP_THICKNESS,Filled=false}),
        name   = newDraw("Text",  {Visible=false,Color=CFG.ESP_COLOR,Size=13,Center=true,Outline=true}),
        health = newDraw("Text",  {Visible=false,Color=Color3.fromRGB(80,255,120),Size=12,Center=true,Outline=true}),
        dist   = newDraw("Text",  {Visible=false,Color=Color3.fromRGB(180,180,220),Size=11,Center=true,Outline=true}),
    }
    skelObjects[plr] = {}
    for _,pair in ipairs(BONE_PAIRS) do
        local key = pair[1].."__"..pair[2]
        skelObjects[plr][key] = newDraw("Line",{
            Visible=false,Color=CFG.SKE_COLOR,Thickness=CFG.SKE_THICKNESS,
            From=Vector2.new(0,0),To=Vector2.new(0,0),
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
--  [FLUENT BUNDLE — วางก้อนเดิมจากต้นฉบับตรงนี้ ไม่เปลี่ยนบรรทัดใด]
-- << PASTE ORIGINAL FLUENT BUNDLE (lines 264–826) HERE >>
-- ══════════════════════════════════════════════════════════════

-- ══════════════════════════════════════════════
--  KEYAUTH  (mobile-safe: pcall ทุก layer)
-- ══════════════════════════════════════════════
local KEYAUTH = {
    Name    = "STEPTHEP",
    OwnerID = "dAKrb9vtDL",
    Version = "1.0",
    API     = "https://keyauth.win/api/1.1/",
}

local function keyauthGet(params)
    -- build query string
    local parts = {}
    for k,v in pairs(params) do
        parts[#parts+1] = HttpService:UrlEncode(tostring(k))
            .."="..HttpService:UrlEncode(tostring(v))
    end
    local url = KEYAUTH.API.."?"..table.concat(parts,"&")

    -- executor มือถือบางตัวใช้ request() แทน HttpGet
    local body
    local ok1, r1 = pcall(function()
        return game:HttpGet(url, true)
    end)
    if ok1 and type(r1)=="string" and #r1 > 2 then
        body = r1
    else
        -- fallback: request()
        local ok2, r2 = pcall(function()
            return request and request({Url=url, Method="GET"}).Body
                or syn and syn.request({Url=url, Method="GET"}).Body
        end)
        if ok2 and type(r2)=="string" and #r2 > 2 then
            body = r2
        end
    end

    if not body or body=="" or body=="KeyAuth_Invalid" then
        return {success=false, message="HTTP failed — executor blocked network"}
    end
    local ok3, decoded = pcall(HttpService.JSONDecode, HttpService, body)
    if not ok3 or type(decoded)~="table" then
        return {success=false, message="JSON parse failed"}
    end
    return decoded
end

-- ── init ────────────────────────────────────────────────────
local initData   = keyauthGet({
    name    = KEYAUTH.Name,
    ownerid = KEYAUTH.OwnerID,
    type    = "init",
    ver     = KEYAUTH.Version,
})
local authSession = nil
local authStatus
if initData.success==true and type(initData.sessionid)=="string" then
    authSession = initData.sessionid
    authStatus  = "เชื่อมต่อแล้ว — กรอก License Key"
else
    authStatus  = "KeyAuth: "..(initData.message or "เชื่อมต่อไม่ได้")
end

-- ══════════════════════════════════════════════
--  UI LANGUAGE + THEME
-- ══════════════════════════════════════════════
local UI_PREF_PATH = "STEPTHEP/ui-settings.json"
local UIPrefs = { Language="TH", Theme="Dark", Acrylic=true, Transparency=true }

local function loadUIPrefs()
    pcall(function()
        if type(isfile)=="function" and isfile(UI_PREF_PATH) then
            local s = HttpService:JSONDecode(readfile(UI_PREF_PATH))
            if type(s)=="table" then
                if s.Language=="TH" or s.Language=="EN" then UIPrefs.Language=s.Language end
                if type(s.Theme)=="string" then UIPrefs.Theme=s.Theme end
                if type(s.Acrylic)=="boolean" then UIPrefs.Acrylic=s.Acrylic end
                if type(s.Transparency)=="boolean" then UIPrefs.Transparency=s.Transparency end
            end
        end
    end)
end
local function saveUIPrefs()
    pcall(function()
        if type(writefile)~="function" then return end
        if type(isfolder)=="function" and type(makefolder)=="function"
           and not isfolder("STEPTHEP") then makefolder("STEPTHEP") end
        writefile(UI_PREF_PATH, HttpService:JSONEncode(UIPrefs))
    end)
end
loadUIPrefs()

-- ══════════════════════════════════════════════
--  FLUENT WINDOW  (mobile-safe init)
-- ══════════════════════════════════════════════

-- ★ PATCH: override protectgui ที่ Fluent จะเรียกภายใน
--   ก่อน CreateWindow — ป้องกัน crash executor มือถือ
do
    local _orig_protectgui = protectgui
    protectgui = function(gui)
        pcall(function()
            if _orig_protectgui then _orig_protectgui(gui)
            elseif syn and syn.protect_gui then syn.protect_gui(gui) end
        end)
    end
end

local LoginWindow = Fluent:CreateWindow({
    Title        = "สเต็ปเทพ",
    SubTitle     = "License Verification",
    TabWidth     = 145,
    Size         = UDim2.fromOffset(580, 440),
    Acrylic      = UIPrefs.Acrylic,
    Theme        = UIPrefs.Theme,
    MinimizeKey  = Enum.KeyCode.RightControl,
})
pcall(function() Fluent:ToggleAcrylic(UIPrefs.Acrylic) end)
pcall(function() Fluent:ToggleTransparency(UIPrefs.Transparency) end)

local LoginTab = LoginWindow:AddTab({ Title="License", Icon="key" })

LoginTab:AddParagraph({
    Title   = "STEPTHEP License",
    Content = authStatus,
})

LoginTab:AddDropdown("LoginLanguage",{
    Title    = "Language / ภาษา",
    Values   = {"TH","EN"},
    Default  = UIPrefs.Language,
    Callback = function(v)
        UIPrefs.Language = v
        saveUIPrefs()
    end,
})

local enteredLicense = ""
local loginBusy      = false
local authorized     = false
local startMain      -- forward declare

LoginTab:AddInput("LicenseKey",{
    Title       = "License Key",
    Description = "กรอก Key ที่ได้รับ",
    Default     = "",
    Placeholder = "XXXX-XXXX-XXXX",
    Numeric     = false,
    Finished    = false,
    Callback    = function(v) enteredLicense = tostring(v or "") end,
})

LoginTab:AddButton({
    Title       = "Verify License",
    Description = "ตรวจสอบ Key ผ่าน KeyAuth",
    Callback    = function()
        if loginBusy or authorized then return end
        if not authSession then
            Fluent:Notify({Title="KeyAuth",Content=authStatus,Duration=6})
            return
        end
        local key = enteredLicense:match("^%s*(.-)%s*$")
        if key=="" then
            Fluent:Notify({Title="KeyAuth",Content="กรุณากรอก License Key",Duration=4})
            return
        end
        loginBusy = true
        local result = keyauthGet({
            name      = KEYAUTH.Name,
            ownerid   = KEYAUTH.OwnerID,
            type      = "license",
            key       = key,
            ver       = KEYAUTH.Version,
            sessionid = authSession,
        })
        loginBusy = false
        if not result or result.success~=true then
            Fluent:Notify({
                Title   = "License ไม่ถูกต้อง",
                Content = tostring(result and result.message or "Invalid response"),
                Duration= 6,
            })
            return
        end
        authorized = true
        Fluent:Notify({Title="STEPTHEP",Content="License ผ่าน — กำลังโหลด...",Duration=4})
        task.wait(0.25)
        startMain(result)
    end,
})

LoginWindow:SelectTab(1)
Fluent:Notify({Title="STEPTHEP",Content=authStatus,Duration=5})

-- ══════════════════════════════════════════════
--  FLOATING TOGGLE BUTTON
-- ══════════════════════════════════════════════
local function setUIVisible(v)
    uiVisible = v
    pcall(function() LoginWindow.Root.Visible = v end)
end

local function createFloatingToggle(onToggle)
    local sg = Instance.new("ScreenGui")
    sg.Name           = "STEPTHEP_FloatBtn"
    sg.ResetOnSpawn   = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.IgnoreGuiInset = true
    safeCoreParent(sg)   -- ← ใช้ safe wrapper แทน direct CoreGui

    local btn = Instance.new("TextButton", sg)
    btn.Size               = UDim2.fromOffset(56, 56)
    btn.Position           = UDim2.new(1, -68, 1, -80)
    btn.AnchorPoint        = Vector2.new(0, 0)
    btn.BackgroundColor3   = Color3.fromRGB(18, 18, 18)
    btn.BorderSizePixel    = 0
    btn.Text               = "☰"
    btn.TextColor3         = Color3.fromRGB(240, 240, 240)
    btn.TextSize           = 22
    btn.Font               = Enum.Font.GothamSemiBold
    btn.AutoButtonColor    = false
    btn.ZIndex             = 100
    Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
    local stroke = Instance.new("UIStroke", btn)
    stroke.Thickness    = 1.5
    stroke.Color        = Color3.fromRGB(80, 160, 255)
    stroke.Transparency = 0.4

    local dragging  = false
    local dragStart = Vector2.new()
    local startPos  = Vector2.new()
    local DRAG_THRESHOLD = 8

    btn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch
        or input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging  = true
            dragStart = Vector2.new(input.Position.X, input.Position.Y)
            startPos  = Vector2.new(btn.Position.X.Offset, btn.Position.Y.Offset)
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
            local rel   = Vector2.new(input.Position.X, input.Position.Y)
            local moved = (rel - dragStart).Magnitude
            dragging    = false
            if moved < DRAG_THRESHOLD then
                onToggle()
                TweenSvc:Create(btn, TweenInfo.new(0.08), {
                    BackgroundColor3 = Color3.fromRGB(50,110,180)
                }):Play()
                task.delay(0.12, function()
                    TweenSvc:Create(btn, TweenInfo.new(0.12), {
                        BackgroundColor3 = Color3.fromRGB(18,18,18)
                    }):Play()
                end)
            end
        end
    end)

    return sg
end

local _floatGui = createFloatingToggle(function()
    setUIVisible(not uiVisible)
end)

-- ══════════════════════════════════════════════
--  AIMBOT CORE
-- ══════════════════════════════════════════════
local function getBestTarget()
    local vp     = Camera.ViewportSize
    local center = Vector2.new(vp.X/2, vp.Y/2)
    local bestDist, bestPlr = math.huge, nil
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr==LocalPlayer then continue end
        if isTeammate(plr) then continue end
        if not CFG.AIM_VEHICLE and getPlayerOnVehicle(plr) then continue end
        local char = getChar(plr)
        if not char then continue end
        local _,human = getRootAndHuman(plr)
        if not human or human.Health<=0 then continue end
        local bone = getTargetBone(char)
        if not bone then continue end
        local bonePos = bone.CFrame.Position + CFG.AIM_HEAD_OFFSET
        local screen2d,onScreen = worldToScreen(bonePos)
        if not onScreen then continue end
        if CFG.AIM_VISIBLE_CHECK and not isVisible(char,bonePos) then continue end
        local d = (screen2d - center).Magnitude
        if d < bestDist then bestDist=d; bestPlr=plr end
    end
    return bestPlr
end

local function doAimbot()
    if not CFG.AIM_ENABLED or not aimActive then lockedTarget=nil; return end
    if lockedTarget then
        local char  = getChar(lockedTarget)
        local _,hum = getRootAndHuman(lockedTarget)
        if not hum or hum.Health<=0 then lockedTarget=nil
        elseif CFG.AIM_VISIBLE_CHECK and char then
            local bone = getTargetBone(char)
            if bone and not isVisible(char, bone.CFrame.Position+CFG.AIM_HEAD_OFFSET) then
                lockedTarget=nil
            end
        end
        if lockedTarget and not CFG.AIM_VEHICLE and getPlayerOnVehicle(lockedTarget) then
            lockedTarget=nil
        end
    end
    if not lockedTarget then lockedTarget = getBestTarget() end
    if not lockedTarget then return end
    local char = getChar(lockedTarget)
    local bone = char and getTargetBone(char)
    if not bone then lockedTarget=nil; return end
    local bonePos        = bone.CFrame.Position + CFG.AIM_HEAD_OFFSET
    local screen2d,onScreen = worldToScreen(bonePos)
    if not onScreen then lockedTarget=nil; return end
    local center = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    local delta  = screen2d - center
    if delta.Magnitude > CFG.AIM_FOV then lockedTarget=nil; return end
    local step = math.clamp(CFG.AIM_SMOOTH, 0.01, 1.0)
    mousemoverel(delta.X*step, delta.Y*step)
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
    if plr~=LocalPlayer then onPlayerAdded(plr) end
end
Players.PlayerAdded:Connect(function(plr)
    if plr~=LocalPlayer then onPlayerAdded(plr) end
end)
Players.PlayerRemoving:Connect(removeESP)

-- ══════════════════════════════════════════════
--  INPUT
-- ══════════════════════════════════════════════
UserInputSvc.InputBegan:Connect(function(input, gpe)
    if input.KeyCode == CFG.KEY_UI_TOGGLE then
        setUIVisible(not uiVisible); return
    end
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
    -- ★ SHOOT-TO-LOCK
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        aimActive = true; return
    end
    if input.KeyCode == CFG.KEY_ESP_TOGGLE then
        CFG.ESP_ENABLED = not CFG.ESP_ENABLED
        if not CFG.ESP_ENABLED then
            for _,esp in pairs(espObjects) do
                for _,d in pairs(esp) do d.Visible=false end
            end
        end
    end
    if input.KeyCode == CFG.KEY_FOV_UP then
        CFG.AIM_FOV=math.min(CFG.AIM_FOV+10,500); fovCircle.Radius=CFG.AIM_FOV
    end
    if input.KeyCode == CFG.KEY_FOV_DOWN then
        CFG.AIM_FOV=math.max(CFG.AIM_FOV-10,20); fovCircle.Radius=CFG.AIM_FOV
    end
end)

UserInputSvc.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        aimActive=false; lockedTarget=nil
    end
end)

-- ══════════════════════════════════════════════
--  MAIN LOOP
-- ══════════════════════════════════════════════
RunService.RenderStepped:Connect(function()
    doAimbot()
    fovCircle.Position = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LocalPlayer then updateESP(plr) end
    end
end)

-- ══════════════════════════════════════════════
--  FULL CLEANUP
-- ══════════════════════════════════════════════
local cleanupDone = false
local function fullCleanup()
    if cleanupDone then return end
    cleanupDone = true
    CFG.ESP_ENABLED=false; CFG.ESP_BOX=false; CFG.ESP_NAME=false
    CFG.ESP_HEALTH=false; CFG.ESP_DISTANCE=false
    CFG.SKE_ENABLED=false; CFG.AIM_ENABLED=false
    CFG.AIM_FOV_VISIBLE=false; CFG.AIM_TEAM_CHECK=false
    CFG.AIM_VISIBLE_CHECK=false; CFG.AIM_VEHICLE=false
    aimActive=false; lockedTarget=nil
    for plr in pairs(espObjects) do removeESP(plr) end
    espObjects={}; skelObjects={}
    pcall(function() fovCircle.Visible=false; fovCircle:Remove() end)
    pcall(function()
        UserInputSvc.MouseBehavior    = Enum.MouseBehavior.Default
        UserInputSvc.MouseIconEnabled = true
        mouseUnlocked = false
    end)
    pcall(function() _floatGui:Destroy() end)
    pcall(function() Fluent:Destroy() end)
    print("[ STEPTHEP ] fullCleanup() complete")
end

task.spawn(function()
    repeat task.wait(0.3) until Fluent.Unloaded==true
    fullCleanup()
end)

-- ══════════════════════════════════════════════
--  startMain — main feature tabs
-- ══════════════════════════════════════════════
startMain = function(authResult)
    pcall(function()
        LoginTab.Frame:Destroy()
        LoginTab.ContainerFrame:Destroy()
    end)

    local Window = LoginWindow
    local Tabs = {
        ESP      = Window:AddTab({Title="ESP",      Icon="eye"}),
        Aimbot   = Window:AddTab({Title="Aimbot",   Icon="crosshair"}),
        Keys     = Window:AddTab({Title="Keys",     Icon="keyboard"}),
        Settings = Window:AddTab({Title="Settings", Icon="settings"}),
    }

    -- ── ESP TAB ────────────────────────────────
    local espTab = Tabs.ESP
    espTab:AddSection("PLAYER ESP")

    espTab:AddToggle("ESPEnable",{
        Title    = "ESP Enable",
        Default  = CFG.ESP_ENABLED,
        Callback = function(v) CFG.ESP_ENABLED=v end,
    })
    espTab:AddToggle("ESPBox",{
        Title    = "Box",
        Default  = CFG.ESP_BOX,
        Callback = function(v) CFG.ESP_BOX=v end,
    })
    espTab:AddToggle("ESPName",{
        Title    = "Name",
        Default  = CFG.ESP_NAME,
        Callback = function(v) CFG.ESP_NAME=v end,
    })
    espTab:AddToggle("ESPHealth",{
        Title    = "Health",
        Default  = CFG.ESP_HEALTH,
        Callback = function(v) CFG.ESP_HEALTH=v end,
    })
    espTab:AddToggle("ESPDist",{
        Title    = "Distance",
        Default  = CFG.ESP_DISTANCE,
        Callback = function(v) CFG.ESP_DISTANCE=v end,
    })
    espTab:AddToggle("SKEEnable",{
        Title    = "Skeleton",
        Default  = CFG.SKE_ENABLED,
        Callback = function(v) CFG.SKE_ENABLED=v end,
    })

    -- ── AIMBOT TAB ─────────────────────────────
    local aimTab = Tabs.Aimbot
    aimTab:AddSection("AIM SETTINGS")

    aimTab:AddToggle("AimEnable",{
        Title    = "Aimbot Enable",
        Default  = CFG.AIM_ENABLED,
        Callback = function(v) CFG.AIM_ENABLED=v end,
    })
    aimTab:AddToggle("AimFOVVis",{
        Title    = "Show FOV",
        Default  = CFG.AIM_FOV_VISIBLE,
        Callback = function(v)
            CFG.AIM_FOV_VISIBLE=v
            fovCircle.Visible = v and CFG.AIM_ENABLED
        end,
    })
    aimTab:AddToggle("AimVis",{
        Title    = "Visible Check",
        Default  = CFG.AIM_VISIBLE_CHECK,
        Callback = function(v) CFG.AIM_VISIBLE_CHECK=v end,
    })
    aimTab:AddToggle("AimTeam",{
        Title    = "Team Check",
        Default  = CFG.AIM_TEAM_CHECK,
        Callback = function(v) CFG.AIM_TEAM_CHECK=v end,
    })
    aimTab:AddToggle("AimVehicle",{
        Title    = "Vehicle Lock",
        Default  = CFG.AIM_VEHICLE,
        Callback = function(v) CFG.AIM_VEHICLE=v end,
    })
    aimTab:AddSlider("AimFOV",{
        Title    = "FOV Radius",
        Min=20, Max=500, Default=CFG.AIM_FOV, Rounding=1,
        Callback = function(v)
            CFG.AIM_FOV=v
            fovCircle.Radius=v
        end,
    })
    aimTab:AddSlider("AimSmooth",{
        Title    = "Smooth",
        Min=1, Max=100, Default=math.floor(CFG.AIM_SMOOTH*100), Rounding=1,
        Callback = function(v) CFG.AIM_SMOOTH=v/100 end,
    })

    -- ── KEYS TAB ───────────────────────────────
    local keyTab = Tabs.Keys
    keyTab:AddSection("DEFAULT KEYBINDS")
    keyTab:AddParagraph({Title="Aim Lock",   Content="กดปุ่มยิง (MB1) — ล็อกเป้าอัตโนมัติใน FOV"})
    keyTab:AddParagraph({Title="ESP Toggle", Content="X — เปิด/ปิด ESP"})
    keyTab:AddParagraph({Title="FOV",        Content="] เพิ่ม FOV  |  [ ลด FOV"})
    keyTab:AddParagraph({Title="Mouse",      Content="Left Alt — ปลดล็อก/ล็อกเมาส์"})
    keyTab:AddParagraph({Title="Menu",       Content="กดปุ่ม ☰ ลอย หรือ RightCtrl — เปิด/ปิดเมนู"})

    -- ── SETTINGS TAB ───────────────────────────
    local setTab = Tabs.Settings
    setTab:AddSection("Interface Settings")
    setTab:AddDropdown("SettingsLang",{
        Title    = "Language",
        Values   = {"TH","EN"},
        Default  = UIPrefs.Language,
        Callback = function(v)
            UIPrefs.Language=v
            saveUIPrefs()
        end,
    })
    setTab:AddDropdown("SettingsTheme",{
        Title    = "Color Theme",
        Values   = Fluent.Themes,
        Default  = UIPrefs.Theme,
        Callback = function(v)
            UIPrefs.Theme=v
            Fluent:SetTheme(v)
            saveUIPrefs()
        end,
    })

    Window:SelectTab(1)
    Fluent:Notify({Title="STEPTHEP",Content="โหลดเรียบร้อย — กดปุ่ม ☰ เพื่อเปิด/ปิดเมนู",Duration=5})

    -- Key expiry watcher
    do
        local watchExpiry = nil
        if type(authResult)=="table" and type(authResult.subscriptions)=="table" then
            for _,sub in ipairs(authResult.subscriptions) do
                local exp = tonumber(sub.expiry)
                if exp and exp>0 then
                    if not watchExpiry or exp>watchExpiry then watchExpiry=exp end
                end
            end
        end
        if watchExpiry then
            task.spawn(function()
                while not cleanupDone do
                    task.wait(5)
                    if math.floor(tick()) >= watchExpiry then
                        fullCleanup()
                        task.wait(0.3)
                        pcall(function()
                            local sg = Instance.new("ScreenGui")
                            sg.ResetOnSpawn=false
                            sg.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
                            safeCoreParent(sg)
                            local f=Instance.new("Frame",sg)
                            f.Size=UDim2.fromOffset(400,90)
                            f.Position=UDim2.new(0.5,-200,0.5,-45)
                            f.BackgroundColor3=Color3.fromRGB(18,18,18)
                            f.BorderSizePixel=0
                            Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
                            Instance.new("UIStroke",f).Thickness=1
                            local t=Instance.new("TextLabel",f)
                            t.Size=UDim2.new(1,-20,0,28)
                            t.Position=UDim2.fromOffset(10,8)
                            t.BackgroundTransparency=1
                            t.TextColor3=Color3.fromRGB(255,70,70)
                            t.TextSize=15
                            t.Font=Enum.Font.GothamSemiBold
                            t.TextXAlignment=Enum.TextXAlignment.Left
                            t.Text="⚠  License หมดอายุแล้ว — กรุณารัน script ใหม่"
                            task.delay(10,function() pcall(function() sg:Destroy() end) end)
                        end)
                        break
                    end
                end
            end)
        end
    end
end

print("[ STEPTHEP v1.2 ] loaded — FloatBtn=☰ | MB1=aim-lock | RightCtrl=menu")
