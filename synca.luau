local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/sametexe001/sametlibs/refs/heads/main/Thugsense/Library.lua"))()

local Window = Library:Window({
    Name = "Aimbot",
    FadeSpeed = 0.25
})

local Watermark = Library:Watermark("Aimbot")
local KeybindList = Library:KeybindList()

local CombatTab = Window:Page({Name = "Combat", Columns = 2, Subtabs = false})
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- Config storage
local C = {
    Enable = false,
    AutoTarget = false,
    TeamCheck = false,
    FOV = false,
    FOVSize = 100,
    WallCheck = false,
    Smoothness = 10,
    Prediction = 5,
}

-- Sections
local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = 1})
local AdvancedSection = CombatTab:Section({Name = "Advanced", Side = 2})

-- Enable toggle with keybind chained on
AimbotSection:Toggle({Name = "Enable", Flag = "Enable", Default = false, Callback = function(Value)
    C.Enable = Value
end}):Keybind({Name = "Hotkey", Flag = "Hotkey", Default = Enum.KeyCode.RightShift, Mode = "Toggle", Callback = function(Value)
    C.Enable = Value
end})

-- Auto Target toggle (mobile - auto lock onto targets in FOV)
AimbotSection:Toggle({Name = "Auto Target", Flag = "AutoTarget", Default = false, Callback = function(Value)
    C.AutoTarget = Value
end})

-- Team Check toggle
AimbotSection:Toggle({Name = "Team Check", Flag = "TeamCheck", Default = false, Callback = function(Value)
    C.TeamCheck = Value
end})

-- FOV toggle + colorpicker
AimbotSection:Toggle({Name = "FoV", Flag = "FOV", Default = false, Callback = function(Value)
    C.FOV = Value
    fovCircle.Visible = Value and (C.Enable or C.AutoTarget)
end}):Colorpicker({Name = "FoV Color", Flag = "FoV Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    fovCircle.Color = Value
end})

-- FOV Size slider
AimbotSection:Slider({Name = "FoV Size", Min = 10, Max = 300, Default = 100, Suffix = " px", Decimals = 0, Flag = "FOVSize", Callback = function(Value)
    C.FOVSize = Value
    fovCircle.Radius = Value
end})

-- Wall Check toggle
AimbotSection:Toggle({Name = "Wall Check", Flag = "WallCheck", Default = false, Callback = function(Value)
    C.WallCheck = Value
end})

-- Smoothness slider
AdvancedSection:Slider({Name = "Smoothness", Min = 1, Max = 30, Default = 10, Suffix = "x", Decimals = 1, Flag = "Smoothness", Callback = function(Value)
    C.Smoothness = Value
end})

-- Prediction slider
AdvancedSection:Slider({Name = "Prediction", Min = 0, Max = 50, Default = 5, Suffix = " studs", Decimals = 1, Flag = "Prediction", Callback = function(Value)
    C.Prediction = Value
end})

-- Drawing objects for FOV visualization
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

-- Helpers
local function getTeam(player)
    if not player or not player.Team then return nil end
    return player.Team.TeamId
end

local function isTeamMate(player)
    if not C.TeamCheck then return false end
    if not player or not player.Team then return false end
    if not game.Players.LocalPlayer.Team then return false end
    return getTeam(player) == getTeam(game.Players.LocalPlayer)
end

local function isValidTarget(player)
    if not player then return false end
    if player == game.Players.LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if isTeamMate(player) then return false end
    return true
end

local function getHeadInfo(player)
    local char = player.Character
    if not char then return nil, nil end
    local head = char:FindFirstChild("Head")
    if not head then return nil, nil end
    return head.Position, head
end

local function canSeeTarget(targetPos)
    if not C.WallCheck then return true end
    local cameraPos = workspace.CurrentCamera.CFrame.Position
    local direction = targetPos - cameraPos
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.FilterDescendantsInstances = {game.Players.LocalPlayer.Character}
    local result = workspace:Raycast(cameraPos, direction, rayParams)
    if result then return false end
    return true
end

local function isInFOV(targetPos)
    if not C.FOV then return true end
    local screenPos, onScreen = workspace.CurrentCamera:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    local centerX = workspace.CurrentCamera.ViewportSize.X / 2
    local centerY = workspace.CurrentCamera.ViewportSize.Y / 2
    local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
    return distance <= C.FOVSize
end

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

local function executeAim(target)
    local headPos, headPart = getHeadInfo(target)
    if not headPos then return end

    local velocity = Vector3.new(0, 0, 0)
    local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
    if root and root.Velocity then
        velocity = root.Velocity
    end

    local lookDir = velocity.Magnitude > 0 and velocity.Unit or workspace.CurrentCamera.CFrame.LookVector
    local predictedPos = headPos + (lookDir * C.Prediction)

    local targetCF = CFrame.lookAt(workspace.CurrentCamera.CFrame.Position, predictedPos)

    if C.Smoothness > 0 then
        local alpha = math.clamp(C.Smoothness * 0.016, 0, 0.15)
        workspace.CurrentCamera.CFrame = workspace.CurrentCamera.CFrame:Lerp(targetCF, alpha)
    else
        workspace.CurrentCamera.CFrame = targetCF
    end
end

-- Main render loop
game:GetService("RunService").RenderStepped:Connect(function(dt)
    local screenCenter = workspace.CurrentCamera.ViewportSize / 2
    fovCircle.Position = Vector2.new(screenCenter.X, screenCenter.Y)
    fovCircle.Radius = C.FOVSize

    -- Update FOV visualization
    fovCircle.Visible = C.FOV and (C.Enable or C.AutoTarget)
    crosshair.Visible = C.Enable or C.AutoTarget

    -- AutoTarget mode (mobile)
    if C.AutoTarget then
        local target = findClosestTarget()
        if target then
            AIMBOT.Target = target
            AIMBOT.TargetPart = getHeadInfo(target)[2]
            C.Enable = true
            executeAim(target)
        else
            AIMBOT.Target = nil
            AIMBOT.TargetPart = nil
            C.Enable = false
        end
    elseif C.Enable then
        -- Manual mode
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

-- Init library
Library:Init()

-- Load notification
Library:Notification("Aimbot loaded", 5, Library.Theme.Accent, {"rbxassetid://135757045959142", Color3.fromRGB(149, 255, 139)})
