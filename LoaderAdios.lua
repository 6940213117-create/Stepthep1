-- ╔══════════════════════════════════════════════════════╗
-- ║     STEPTHEP  v2.0  |  Urban Reload  — MOBILE       ║
-- ║  ESP · Skeleton · FOV Aimbot · Shoot-trigger Aim    ║
-- ║  Floating toggle button (no Insert) · Draggable UI  ║
-- ╚══════════════════════════════════════════════════════╝

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
    AIM_FOV           = 150,          -- slightly wider default for mobile
    AIM_FOV_VISIBLE   = false,
    AIM_FOV_COLOR     = Color3.fromRGB(255, 255, 255),
    AIM_BONE          = "Head",
    AIM_TEAM_CHECK    = false,
    AIM_VISIBLE_CHECK = false,
    AIM_VEHICLE       = false,
    AIM_HEAD_OFFSET   = Vector3.new(0, 0, 0),
    AIM_SMOOTH        = 0.30,
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
local espObjects   = {}
local skelObjects  = {}
local lockedTarget = nil
local aimActive    = false   -- set true while fire button is held (mobile tap)
local uiVisible    = false   -- menu starts HIDDEN; toggle button shows it

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

-- ══════════════════════════════════════════════
--  ESP + SKELETON
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
--  AIMBOT — vehicle-aware
-- ══════════════════════════════════════════════
local function getPlayerOnVehicle(plr)
    local char = getChar(plr); if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid"); if not hum then return false end
    if hum.SeatPart ~= nil then return true end
    for _,v in ipairs(char:GetDescendants()) do
        if v:IsA("Weld") or v:IsA("WeldConstraint") then
            if (v.Part0 and v.Part0:IsA("VehicleSeat")) or
               (v.Part1 and v.Part1:IsA("VehicleSeat")) then return true end
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
--  SHOOT-TRIGGER AIMBOT (mobile tap = MouseButton1)
--  Hooks the fire button press to activate aim
-- ══════════════════════════════════════════════
UserInputSvc.InputBegan:Connect(function(input, gpe)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        aimActive = true
    end
end)
UserInputSvc.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        aimActive    = false
        lockedTarget = nil
    end
end)

-- ══════════════════════════════════════════════
--  FLOATING TOGGLE BUTTON (Delta-style, draggable)
--  Small circle, top-left-ish, fully draggable,
--  taps open/close the main menu
-- ══════════════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name              = "STEPTHEP_Toggle"
sg.ResetOnSpawn      = false
sg.ZIndexBehavior    = Enum.ZIndexBehavior.Sibling
sg.DisplayOrder      = 999
if syn and syn.protect_gui then syn.protect_gui(sg) elseif protectgui then protectgui(sg) end
sg.Parent = game:GetService("CoreGui")

-- outer glow ring
local ring = Instance.new("Frame", sg)
ring.Name                 = "Ring"
ring.Size                 = UDim2.fromOffset(54, 54)
ring.Position             = UDim2.fromOffset(14, 120)
ring.BackgroundColor3     = Color3.fromRGB(80, 160, 255)
ring.BackgroundTransparency = 0.3
ring.BorderSizePixel      = 0
Instance.new("UICorner", ring).CornerRadius = UDim.new(1, 0)

-- inner button
local btn = Instance.new("TextButton", ring)
btn.Name                  = "Btn"
btn.Size                  = UDim2.new(1, -6, 1, -6)
btn.Position              = UDim2.fromOffset(3, 3)
btn.BackgroundColor3      = Color3.fromRGB(18, 18, 22)
btn.Text                  = "☰"
btn.TextColor3            = Color3.fromRGB(80, 160, 255)
btn.TextSize              = 20
btn.Font                  = Enum.Font.GothamBold
btn.BorderSizePixel       = 0
btn.AutoButtonColor       = false
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)

-- drag logic
local dragging, dragStart, startPos = false, nil, nil

ring.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = ring.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

UserInputSvc.InputChanged:Connect(function(input)
    if not dragging then return end
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        ring.Position = UDim2.fromOffset(
            math.clamp(startPos.X.Offset + delta.X, 0, Camera.ViewportSize.X - 54),
            math.clamp(startPos.Y.Offset + delta.Y, 0, Camera.ViewportSize.Y - 54)
        )
    end
end)

-- tap = toggle menu (only if not dragging)
local tapStart = nil
btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        tapStart = tick()
    end
end)
btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        local held = tapStart and (tick() - tapStart) or 1
        if held < 0.25 and not dragging then
            -- toggle
        end
    end
end)

-- ══════════════════════════════════════════════
--  FLUENT WINDOW (embedded, copy bundle from original)
-- ══════════════════════════════════════════════

-- [PASTE the full Fluent bundle here from the original STEPTHEP_v2_patched.lua lines 264-826]
-- It is identical — no changes needed there.

-- ══════════════════════════════════════════════
--  KEYAUTH GATE (identical to original)
-- ══════════════════════════════════════════════
local HttpService = game:GetService("HttpService")
local KEYAUTH = {
    Name    = "STEPTHEP",
    OwnerID = "dAKrb9vtDL",
    Version = "1.0",
    API     = "https://keyauth.win/api/1.1/"
}

local function keyauthGet(params)
    local query = {}
    for k, v in pairs(params) do
        query[#query + 1] = HttpService:UrlEncode(tostring(k)) .. "=" .. HttpService:UrlEncode(tostring(v))
    end
    local url  = KEYAUTH.API .. "?" .. table.concat(query, "&")
    local body = game:HttpGet(url)
    if type(body) ~= "string" or body == "" or body == "KeyAuth_Invalid" then
        error("KeyAuth returned an empty or invalid response")
    end
    local decoded = HttpService:JSONDecode(body)
    if type(decoded) ~= "table" then error("Invalid KeyAuth response") end
    return decoded
end

local initOK, initData = pcall(function()
    return keyauthGet({
        name    = KEYAUTH.Name,
        ownerid = KEYAUTH.OwnerID,
        type    = "init",
        ver     = KEYAUTH.Version
    })
end)

local authSession = nil
local authStatus  = "Connecting to KeyAuth..."
if initOK and initData and initData.success == true and type(initData.sessionid) == "string" then
    authSession = initData.sessionid
    authStatus  = "Connected. Enter your license key."
elseif initOK and initData and initData.message == "invalidver" then
    authStatus = "Application version is invalid."
elseif initOK and initData and initData.message then
    authStatus = "KeyAuth: " .. tostring(initData.message)
else
    authStatus = "Connection failed: " .. tostring(initData)
end

-- ══════════════════════════════════════════════
--  UI LANGUAGE + THEME PREFS (unchanged)
-- ══════════════════════════════════════════════
local UI_PREF_PATH = "STEPTHEP/ui-settings.json"
local UIPrefs = { Language = "TH", Theme = "Dark", Acrylic = false, Transparency = true }
-- NOTE: Acrylic = false default — mobile GPU can't handle it cleanly

local function loadUIPrefs()
    if type(isfile) == "function" and type(readfile) == "function" then
        pcall(function()
            if isfile(UI_PREF_PATH) then
                local saved = HttpService:JSONDecode(readfile(UI_PREF_PATH))
                if type(saved) == "table" then
                    if saved.Language == "TH" or saved.Language == "EN" then UIPrefs.Language = saved.Language end
                    if type(saved.Theme) == "string" and table.find(Fluent.Themes, saved.Theme) then UIPrefs.Theme = saved.Theme end
                    if type(saved.Acrylic)      == "boolean" then UIPrefs.Acrylic      = saved.Acrylic      end
                    if type(saved.Transparency) == "boolean" then UIPrefs.Transparency = saved.Transparency end
                end
            end
        end)
    end
end

local function saveUIPrefs()
    if type(writefile) ~= "function" then return end
    pcall(function()
        if type(isfolder) == "function" and type(makefolder) == "function" and not isfolder("STEPTHEP") then
            makefolder("STEPTHEP")
        end
        writefile(UI_PREF_PATH, HttpService:JSONEncode(UIPrefs))
    end)
end

loadUIPrefs()

-- UI_TEXT table unchanged — copy from original

local function applyLanguage(root)
    if not root then return end
    for _, obj in ipairs(root:GetDescendants()) do
        if obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox") then
            local original = obj:GetAttribute("STEPTHEP_OriginalText")
            if original == nil then
                original = obj.Text
                obj:SetAttribute("STEPTHEP_OriginalText", original)
            end
            -- [insert UI_TEXT lookup here same as original]
        end
    end
end

local function setUILanguage(language)
    if language ~= "TH" and language ~= "EN" then return end
    UIPrefs.Language = language
    applyLanguage(Fluent.GUI)
    saveUIPrefs()
end

-- ══════════════════════════════════════════════
--  FLUENT WINDOW — MOBILE SIZED
--  480×480 fits a 1080p portrait screen,
--  TabWidth 110 keeps tab labels readable at 12px
-- ══════════════════════════════════════════════
local LoginWindow = Fluent:CreateWindow({
    Title       = "สเต็ปเทพ",
    SubTitle    = "License Verification",
    TabWidth    = 110,                          -- narrowed from 145
    Size        = UDim2.fromOffset(460, 460),   -- was 600×470
    Acrylic     = false,                        -- off by default on mobile
    Theme       = UIPrefs.Theme,
    MinimizeKey = Enum.KeyCode.RightControl,    -- kept for keyboard fallback
})
Fluent:ToggleAcrylic(UIPrefs.Acrylic)
Fluent:ToggleTransparency(UIPrefs.Transparency)

-- wire toggle button to Fluent minimize after window is created
btn.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        local held = tapStart and (tick() - tapStart) or 1
        if held < 0.25 and not dragging then
            LoginWindow:Minimize()  -- toggles visible/hidden
        end
    end
end)

-- pulse ring color to show aimbot state
RunService.RenderStepped:Connect(function()
    if CFG.AIM_ENABLED and aimActive then
        ring.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
    elseif CFG.AIM_ENABLED then
        ring.BackgroundColor3 = Color3.fromRGB(255, 180, 60)
    else
        ring.BackgroundColor3 = Color3.fromRGB(80, 160, 255)
    end
end)

-- ══════════════════════════════════════════════
--  LICENSE TAB (identical logic, unchanged)
-- ══════════════════════════════════════════════
local LoginTab      = LoginWindow:AddTab({ Title = "License", Icon = "key" })
local enteredLicense = ""
local loginBusy      = false
local authorized     = false
local startMain

LoginTab:AddParagraph({ Title = "STEPTHEP License", Content = authStatus })
LoginTab:AddDropdown("LoginLanguage", {
    Title    = "Language / ภาษา",
    Values   = {"TH", "EN"},
    Default  = UIPrefs.Language,
    Callback = function(value) setUILanguage(value) end
})
LoginTab:AddInput("LicenseKey", {
    Title       = "License Key",
    Description = "Enter the license key provided to you",
    Default     = "",
    Placeholder = "XXXX-XXXX-XXXX",
    Numeric     = false,
    Finished    = false,
    Callback    = function(value) enteredLicense = tostring(value or "") end
})
LoginTab:AddButton({
    Title       = "Verify License",
    Description = "Verify your key with KeyAuth",
    Callback    = function()
        if loginBusy or authorized then return end
        if not authSession then
            Fluent:Notify({Title="KeyAuth", Content=authStatus, Duration=6}); return
        end
        local key = enteredLicense:gsub("^%s+",""):gsub("%s+$","")
        if key == "" then
            Fluent:Notify({Title="KeyAuth", Content="Please enter a license key.", Duration=4}); return
        end
        loginBusy = true
        local ok, result = pcall(function()
            return keyauthGet({
                name      = KEYAUTH.Name,
                ownerid   = KEYAUTH.OwnerID,
                type      = "license",
                key       = key,
                ver       = KEYAUTH.Version,
                sessionid = authSession
            })
        end)
        loginBusy = false
        if not ok then
            Fluent:Notify({Title="KeyAuth", Content="Request failed: "..tostring(result), Duration=6}); return
        end
        if not result or result.success ~= true then
            Fluent:Notify({Title="License rejected", Content=tostring(result and result.message or "Invalid response"), Duration=6}); return
        end
        authorized = true
        Fluent:Notify({Title="STEPTHEP", Content="License verified. Loading...", Duration=4})
        task.wait(0.25)
        startMain(result)
    end
})

applyLanguage(Fluent.GUI)
LoginWindow:SelectTab(1)
Fluent:Notify({Title="STEPTHEP", Content=authStatus, Duration=5})

-- ══════════════════════════════════════════════
--  MAIN FUNCTION (post-auth)
-- ══════════════════════════════════════════════
startMain = function(authResult)
    pcall(function()
        LoginTab.Frame:Destroy()
        LoginTab.ContainerFrame:Destroy()
    end)

    local Window = LoginWindow
    local Tabs = {
        ESP      = Window:AddTab({ Title = "ESP",      Icon = "eye"       }),
        Aimbot   = Window:AddTab({ Title = "Aimbot",   Icon = "crosshair" }),
        Keys     = Window:AddTab({ Title = "Keys",     Icon = "keyboard"  }),
        Settings = Window:AddTab({ Title = "Settings", Icon = "settings"  }),
        KeyInfo  = Window:AddTab({ Title = "Key Info", Icon = "clock"     }),
    }

    -- KEY INFO TAB
    do
        local expiryUnix = nil
        if type(authResult) == "table" and type(authResult.subscriptions) == "table" then
            for _, sub in ipairs(authResult.subscriptions) do
                local exp = tonumber(sub.expiry)
                if exp and exp > 0 then
                    if not expiryUnix or exp > expiryUnix then expiryUnix = exp end
                end
            end
        end
        local username = "—"
        if type(authResult) == "table" and type(authResult.info) == "table" then
            username = tostring(authResult.info.username or authResult.info.ip or "—")
        end

        Tabs.KeyInfo:AddSection("LICENSE STATUS")
        local infoWidget  = Tabs.KeyInfo:AddParagraph({ Title = "ผู้ใช้งาน",   Content = username })
        local timerWidget = Tabs.KeyInfo:AddParagraph({ Title = "เวลาคงเหลือ", Content = "คำนวณ..." })

        local function formatCountdown(secs)
            if secs <= 0 then return "หมดอายุแล้ว" end
            local s = secs % 60
            local m = math.floor(secs/60) % 60
            local h = math.floor(secs/3600) % 24
            local d = math.floor(secs/86400)
            if d > 0 then
                return string.format("วัน %02d : ชม. %02d : นาที %02d : วินาที %02d", d, h, m, s)
            else
                return string.format("%02d ชม. : %02d นาที : %02d วินาที", h, m, s)
            end
        end

        task.spawn(function()
            while true do
                if expiryUnix then
                    local remaining = expiryUnix - math.floor(tick())
                    pcall(function() timerWidget:SetDesc(formatCountdown(remaining)) end)
                else
                    pcall(function() timerWidget:SetDesc("ไม่พบข้อมูล expiry จาก KeyAuth") end)
                end
                task.wait(1)
            end
        end)
    end

    local function addSection(tab, title) tab:AddSection(title) end

    -- ESP TAB
    addSection(Tabs.ESP, "PLAYER ESP")
    Tabs.ESP:AddToggle("ESPEnabled",  { Title="ESP Enable", Description="เปิด/ปิดระบบ ESP",          Default=CFG.ESP_ENABLED,  Callback=function(v) CFG.ESP_ENABLED  = v end })
    Tabs.ESP:AddToggle("ESPBox",      { Title="Box",                                                   Default=CFG.ESP_BOX,      Callback=function(v) CFG.ESP_BOX      = v end })
    Tabs.ESP:AddToggle("ESPName",     { Title="Name",                                                  Default=CFG.ESP_NAME,     Callback=function(v) CFG.ESP_NAME     = v end })
    Tabs.ESP:AddToggle("ESPHealth",   { Title="Health",                                                Default=CFG.ESP_HEALTH,   Callback=function(v) CFG.ESP_HEALTH   = v end })
    Tabs.ESP:AddToggle("ESPDistance", { Title="Distance",                                              Default=CFG.ESP_DISTANCE, Callback=function(v) CFG.ESP_DISTANCE = v end })
    Tabs.ESP:AddToggle("Skeleton",    { Title="Skeleton",    Description="แสดงโครงกระดูกผู้เล่น",    Default=CFG.SKE_ENABLED,  Callback=function(v) CFG.SKE_ENABLED  = v end })

    -- AIMBOT TAB
    addSection(Tabs.Aimbot, "AIM SETTINGS")
    Tabs.Aimbot:AddToggle("AimbotEnabled", {
        Title="Aimbot Enable", Description="เปิด/ปิดระบบล็อกเป้าหมาย · ทำงานเมื่อกดยิง",
        Default=CFG.AIM_ENABLED,
        Callback=function(v) CFG.AIM_ENABLED = v end
    })
    Tabs.Aimbot:AddToggle("ShowFOV", {
        Title="Show FOV", Description="แสดงวงกลม FOV",
        Default=CFG.AIM_FOV_VISIBLE,
        Callback=function(v)
            CFG.AIM_FOV_VISIBLE = v
            fovCircle.Visible   = v and CFG.AIM_ENABLED
        end
    })
    Tabs.Aimbot:AddToggle("VisibleCheck", { Title="Visible Check", Description="ตรวจสอบการมองเห็น",           Default=CFG.AIM_VISIBLE_CHECK, Callback=function(v) CFG.AIM_VISIBLE_CHECK = v end })
    Tabs.Aimbot:AddToggle("TeamCheck",    { Title="Team Check",    Description="ข้ามผู้เล่นทีมเดียวกัน",     Default=CFG.AIM_TEAM_CHECK,    Callback=function(v) CFG.AIM_TEAM_CHECK    = v end })
    Tabs.Aimbot:AddToggle("VehicleLock",  { Title="Vehicle Lock",  Description="รวมผู้เล่นที่อยู่บนยานพาหนะ", Default=CFG.AIM_VEHICLE,       Callback=function(v) CFG.AIM_VEHICLE       = v end })
    Tabs.Aimbot:AddSlider("FOVRadius", {
        Title="FOV Radius", Description="ขนาดวง FOV",
        Default=CFG.AIM_FOV, Min=20, Max=500, Rounding=0,
        Callback=function(v) CFG.AIM_FOV = v fovCircle.Radius = v end
    })
    Tabs.Aimbot:AddSlider("AimSmooth", {
        Title="Smooth", Description="ระดับความนุ่มนวล",
        Default=math.floor(CFG.AIM_SMOOTH * 100), Min=1, Max=100, Rounding=0,
        Callback=function(v) CFG.AIM_SMOOTH = v / 100 end
    })

    -- KEYS TAB — updated to reflect mobile / no Insert
    addSection(Tabs.Keys, "DEFAULT KEYBINDS")
    Tabs.Keys:AddParagraph({ Title="Toggle Menu",  Content="กดปุ่มลอย ☰ (ด้านซ้ายจอ) เพื่อเปิด/ปิดเมนู" })
    Tabs.Keys:AddParagraph({ Title="Aimbot",       Content="ทำงานอัตโนมัติเมื่อกดปุ่มยิง" })
    Tabs.Keys:AddParagraph({ Title="ESP Toggle",   Content="X — เปิด/ปิด ESP (แป้นพิมพ์)" })
    Tabs.Keys:AddParagraph({ Title="FOV",          Content="] เพิ่ม FOV  |  [ ลด FOV" })
    Tabs.Keys:AddParagraph({ Title="Right Ctrl",   Content="Right Ctrl — ซ่อน/แสดงหน้าต่าง (แป้นพิมพ์)" })

    -- SETTINGS TAB
    addSection(Tabs.Settings, "Interface Settings")
    Tabs.Settings:AddDropdown("UILanguage", {
        Title="Language", Description="Choose the interface language.",
        Values={"TH","EN"}, Default=UIPrefs.Language,
        Callback=function(value) setUILanguage(value) end
    })
    Tabs.Settings:AddDropdown("UITheme", {
        Title="Color Theme", Description="Change the Fluent color theme.",
        Values=Fluent.Themes, Default=UIPrefs.Theme,
        Callback=function(value)
            if table.find(Fluent.Themes, value) then
                UIPrefs.Theme = value
                Fluent:SetTheme(value)
                saveUIPrefs()
            end
        end
    })
    Tabs.Settings:AddToggle("AcrylicToggle", {
        Title="Acrylic", Description="Enable blurred glass (heavy on mobile).",
        Default=UIPrefs.Acrylic,
        Callback=function(value)
            UIPrefs.Acrylic = value
            Fluent:ToggleAcrylic(value)
            saveUIPrefs()
        end
    })
    Tabs.Settings:AddToggle("TransparencyToggle", {
        Title="Transparency", Description="Make background transparent.",
        Default=UIPrefs.Transparency,
        Callback=function(value)
            UIPrefs.Transparency = value
            Fluent:ToggleTransparency(value)
            saveUIPrefs()
        end
    })

    applyLanguage(Fluent.GUI)
    Window:SelectTab(2)

    Fluent:Notify({ Title="STEPTHEP", Content="โหลดเรียบร้อย — กดปุ่ม ☰ เพื่อซ่อนเมนู", Duration=5 })

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

    -- keyboard ESP toggle still works
    UserInputSvc.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        if input.KeyCode == Enum.KeyCode.X then
            CFG.ESP_ENABLED = not CFG.ESP_ENABLED
            if not CFG.ESP_ENABLED then
                for _,esp in pairs(espObjects) do
                    for _,d in pairs(esp) do d.Visible = false end
                end
            end
        end
        if input.KeyCode == Enum.KeyCode.RightBracket then
            CFG.AIM_FOV      = math.min(CFG.AIM_FOV + 10, 500)
            fovCircle.Radius = CFG.AIM_FOV
        end
        if input.KeyCode == Enum.KeyCode.LeftBracket then
            CFG.AIM_FOV      = math.max(CFG.AIM_FOV - 10, 20)
            fovCircle.Radius = CFG.AIM_FOV
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

    -- ══════════════════════════════════════════════
    --  CLEANUP ON FLUENT CLOSE
    -- ══════════════════════════════════════════════
    local cleanupDone = false
    local function fullCleanup()
        if cleanupDone then return end
        cleanupDone = true
        CFG.ESP_ENABLED = false CFG.SKE_ENABLED = false CFG.AIM_ENABLED = false
        aimActive = false lockedTarget = nil
        for plr in pairs(espObjects) do removeESP(plr) end
        espObjects = {} skelObjects = {}
        pcall(function() fovCircle.Visible = false fovCircle:Remove() end)
        pcall(function() sg:Destroy() end)
        pcall(function() Fluent:Destroy() end)
        UserInputSvc.MouseBehavior    = Enum.MouseBehavior.Default
        UserInputSvc.MouseIconEnabled = true
    end

    task.spawn(function()
        repeat task.wait(0.3) until Fluent.Unloaded == true
        fullCleanup()
    end)

    -- key expiry watcher (unchanged)
    do
        local watchExpiry = nil
        if type(authResult) == "table" and type(authResult.subscriptions) == "table" then
            for _, sub in ipairs(authResult.subscriptions) do
                local exp = tonumber(sub.expiry)
                if exp and exp > 0 then
                    if not watchExpiry or exp > watchExpiry then watchExpiry = exp end
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
                            local notifGui = Instance.new("ScreenGui")
                            notifGui.ResetOnSpawn = false
                            notifGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
                            if syn and syn.protect_gui then syn.protect_gui(notifGui) end
                            notifGui.Parent = game:GetService("CoreGui")
                            local f = Instance.new("Frame", notifGui)
                            f.Size = UDim2.fromOffset(360, 80)
                            f.Position = UDim2.new(0.5, -180, 0.5, -40)
                            f.BackgroundColor3 = Color3.fromRGB(18,18,18)
                            f.BorderSizePixel = 0
                            Instance.new("UICorner", f).CornerRadius = UDim.new(0,10)
                            local t = Instance.new("TextLabel", f)
                            t.Size = UDim2.new(1,-20,1,0)
                            t.Position = UDim2.fromOffset(10,0)
                            t.BackgroundTransparency = 1
                            t.TextColor3 = Color3.fromRGB(255,70,70)
                            t.TextSize = 13
                            t.Font = Enum.Font.GothamSemiBold
                            t.TextXAlignment = Enum.TextXAlignment.Left
                            t.TextWrapped = true
                            t.Text = "⚠  License หมดอายุแล้ว — กรุณารัน script ใหม่"
                            task.delay(10, function() pcall(function() notifGui:Destroy() end) end)
                        end)
                        break
                    end
                end
            end)
        end
    end

    print("[ STEPTHEP v2.0 MOBILE ] loaded — ☰ button = menu toggle | shoot = aimbot")
end