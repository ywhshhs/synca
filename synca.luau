local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Pandora/Library.lua"))()

local Window = Library:Window({
    Logo = "rbxassetid://124454910007637",
    Build = "developer"
})

local KeybindList = Library:KeybindList()
local Watermark = Library:Watermark("Aimbot", "rbxassetid://124454910007637")

local Pages = {
    ["Combat"] = Window:Page({Icon = "rbxassetid://113972874520335"})
}

local SubPages = {
    ["Aimbot"] = Pages["Combat"]:SubPage({Name = "Aimbot"})
}

local SectionMain = SubPages["Aimbot"]:Section({Name = "Main"})
local SectionAdvanced = SubPages["Aimbot"]:Section({Name = "Advanced"})

-- Toggle: Enable Aimbot
SectionMain:Toggle({
    Name = "Enable",
    Flag = "Enable",
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notification("Aimbot Enabled", 2, Library.Theme.Accent)
        else
            Library:Notification("Aimbot Disabled", 2, Library.Theme["Dark Accent"])
        end
    end
})

-- Toggle: AutoTarget (mobile - auto lock onto targets in FOV)
SectionMain:Toggle({
    Name = "Auto Target",
    Flag = "AutoTarget",
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notification("Auto Target On", 2, Library.Theme.Accent)
        else
            Library:Notification("Auto Target Off", 2, Library.Theme["Dark Accent"])
        end
    end
})

-- Toggle: Team Check
SectionMain:Toggle({
    Name = "Team Check",
    Flag = "TeamCheck",
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notification("Team Check On", 1, Library.Theme.Accent)
        end
    end
})

-- Toggle: FOV Circle
SectionMain:Toggle({
    Name = "FOV",
    Flag = "FOV",
    Default = false,
    Callback = function(Value)
        fovCircle.Visible = Value and (Library.Flags["Enable"] or Library.Flags["AutoTarget"])
        if Value then
            Library:Notification("FOV On", 1, Library.Theme.Accent)
        else
            Library:Notification("FOV Off", 1, Library.Theme["Dark Accent"])
        end
    end
})

-- Slider: FOV Size
SectionMain:Slider({
    Name = "FOV Size",
    Flag = "FOVSize",
    Default = 100,
    Min = 10,
    Max = 300,
    Decimals = 0,
    Suffix = " px",
    Callback = function(Value)
        fovCircle.Radius = Value
    end
})

-- Toggle: Wall Check
SectionMain:Toggle({
    Name = "Wall Check",
    Flag = "WallCheck",
    Default = false,
    Callback = function(Value)
        if Value then
            Library:Notification("Wall Check On", 1, Library.Theme.Accent)
        end
    end
})

-- Keybind: Toggle Aimbot
SectionMain:Keybind({
    Name = "Toggle Aimbot",
    Flag = "AimbotKeybind",
    Default = Enum.KeyCode.RightShift,
    Mode = "Toggle",
    Callback = function(Value)
        -- Value is the toggled state from the keybind
        -- handled by the main Enable toggle through the keybind UI
    end
})

-- Slider: Smoothness
SectionAdvanced:Slider({
    Name = "Smoothness",
    Flag = "Smoothness",
    Default = 10,
    Min = 1,
    Max = 30,
    Decimals = 1,
    Suffix = "x",
    Callback = function(Value)
        -- smoothness multiplier (higher = smoother/slower aim)
    end
})

-- Slider: Prediction
SectionAdvanced:Slider({
    Name = "Prediction",
    Flag = "Prediction",
    Default = 5,
    Min = 0,
    Max = 50,
    Decimals = 1,
    Suffix = " studs",
    Callback = function(Value)
        -- how many studs forward to aim based on enemy velocity
    end
})

-- Create Settings Page
local SettingsPage = Library:CreateSettingsPage(Window, KeybindList, Watermark)

-- Drawing objects for FOV circle visualization
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 2
fovCircle.Color = Color3.fromRGB(166, 147, 243)
fovCircle.Transparency = 0.4
fovCircle.Filled = false
fovCircle.Radius = 100

local crosshair = Drawing.new("Cross")
crosshair.Visible = false
crosshair.Thickness = 1
crosshair.Color = Color3.fromRGB(166, 147, 243)
crosshair.Size = 10
crosshair.Transparency = 0.7

-- Aim Bot State
local AIMBOT = {
    Target = nil,
    TargetPart = nil,
}

-- Helper: Get team ID of a player
local function getTeam(player)
    if not player or not player.Team then return nil end
    return player.Team.TeamId
end

-- Helper: Check if target is on same team
local function isTeamMate(player)
    if not AIMBOT.TeamCheck then return false end
    if not player or not player.Team then return false end
    if not game.Players.LocalPlayer.Team then return false end
    return getTeam(player) == getTeam(game.Players.LocalPlayer)
end

-- Helper: Check if player is a valid target
local function isValidTarget(player)
    if not player then return false end
    if player == game.Players.LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if isTeamMate(player) then return false end
    return true
end

-- Helper: Get head position and part
local function getHeadInfo(player)
    local char = player.Character
    if not char then return nil, nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil, nil end
    return head.Position, head
end

-- Helper: Raycast to check if target is visible (wall check)
local function canSeeTarget(targetPos)
    if not AIMBOT.WallCheck then return true end
    local cameraPos = workspace.CurrentCamera.CFrame.Position
    local direction = targetPos - cameraPos
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
    local result = workspace:Raycast(cameraPos, direction, rayParams)
    if result then return false end
    return true
end

-- Helper: Check if target position is within FOV circle
local function isInFOV(targetPos)
    if not AIMBOT.FOVEnabled then return true end
    local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local centerX = workspace.CurrentCamera.ViewportSize.X / 2
    local centerY = workspace.CurrentCamera.ViewportSize.Y / 2
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    return distance <= AIMBOT.FOVSize
end

-- Helper: Find closest valid target
local function findClosestTarget()
    local closest = nil
    local closestDist = math.huge
    for _, player in pairs(game.Players:GetPlayers()) do
        if not isValidTarget(player) then continue end
        local pos, part = getHeadInfo(player)
        if not pos then continue end
        if not isInFOV(pos) then continue end
        if not canSeeTarget(pos) then continue end
        local dist = (workspace.CurrentCamera.CFrame.Position - pos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
            AIMBOT.TargetPart = part
        end
    end
    return closest
end

-- Helper: Execute aim with prediction and smoothness
local function executeAim(target)
    local headPos, headPart = getHeadInfo(target)
    if not headPos then return end

    local velocity = Vector3.new(0, 0, 0)
    local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if root and root.Velocity then
        velocity = root.Velocity
    end

    -- Prediction: aim ahead based on enemy velocity direction
    local lookDir = velocity.Magnitude > 0 and velocity.Unit or workspace.CurrentCamera.CFrame.LookVector
    local predictedPos = headPos + (lookDir * AIMBOT.Prediction)

    local targetCF = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, predictedPos)

    -- Smooth interpolation
    if AIMBOT.Smoothness > 0 then
        local alpha = math.clamp(AIMBOT.Smoothness * 0.016, 0, 0.15)
        workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCF, alpha)
    else
        workspace.CurrentCamera.CFrame = targetCF
    end
end

-- Main render loop
game:GetService("RunService").RenderStepped:Connect(function(dt)
    local screenCenter = workspace.CurrentCamera.ViewportSize / 2
    fovCircle.Position = Vector2.new(screenCenter.X, screenCenter.Y)
    fovCircle.Radius = AIMBOT.FOVSize

    -- Read all config values from Pandora library flags
    AIMBOT.Enabled = Library.Flags["Enable"] or false
    AIMBOT.AutoTarget = Library.Flags["AutoTarget"] or false
    AIMBOT.TeamCheck = Library.Flags["TeamCheck"] or false
    AIMBOT.FOVEnabled = Library.Flags["FOV"] or false
    AIMBOT.FOVSize = Library.Flags["FOVSize"] or 100
    AIMBOT.WallCheck = Library.Flags["WallCheck"] or false
    AIMBOT.Smoothness = Library.Flags["Smoothness"] or 10
    AIMBOT.Prediction = Library.Flags["Prediction"] or 5

    -- Update FOV circle visibility
    fovCircle.Visible = AIMBOT.FOVEnabled and (AIMBOT.Enabled or AIMBOT.AutoTarget)
    crosshair.Visible = AIMBOT.Enabled or AIMBOT.AutoTarget

    -- Update aimbot state
    if AIMBOT.AutoTarget then
        -- AutoTarget mode: automatically lock onto any player in FOV
        local target = findClosestTarget()
        if target then
            AIMBOT.Target = target
            AIMBOT.TargetPart = getHeadInfo(target)[2]
            AIMBOT.Enabled = true
            executeAim(target)
        else
            AIMBOT.Target = nil
            AIMBOT.TargetPart = nil
            AIMBOT.Enabled = false
        end
    elseif AIMBOT.Enabled then
        -- Manual mode: find and aim at closest target
        local target = findClosestTarget()
        if target then
            AIMBOT.Target = target
            AIMBOT.TargetPart = getHeadInfo(target)[2]
            executeAim(target)
        else
            AIMBOT.Target = nil
            AIMBOT.TargetPart = nil
        end
    end
end)

-- Load notification
task.wait(1)
Library:Notification("Aimbot loaded successfully", 5, Library.Theme.Accent)
