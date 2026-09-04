-- synca vendored build: mobile-patched Thugsense fork hosted in this repo
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ywhshhs/synca/main/Thugsense/Library.lua"))()

-- Config storage (defined first so callbacks never hit nil)
local C = {
    Enable = false,
    AutoTarget = false,
    TeamCheck = false,
    FOV = false,
    FOVSize = 100,
    FOVMode = "Center",
    FOVOpacity = 40,
    FOVFilled = false,
    FOVFillColor = Color3.fromRGB(166, 147, 243),
    FOVFillOpacity = 20,
    FOVThickness = 2,
    WallCheck = false,
    AliveCheck = true,
    Smoothness = 10,
    PredictionEnabled = false,
    Prediction = 5,
    TargetPart = "Head",
    Tracer = false,
    TracerOrigin = "Cursor",
    Highlight = false,
    HighlightColor = Color3.fromRGB(255, 60, 60),
    HighlightOpacity = 50,
    ESPHighlight = false,
    ESPHighlightColor = Color3.fromRGB(170, 140, 255),
    ESPHighlightOpacity = 50,
    BoxESP = false,
    BoxColor = Color3.fromRGB(255, 255, 255),
    HealthBar = false,
    NameESP = false,
    DistanceESP = false,
    ESPTracer = false,
    ESPTracerColor = Color3.fromRGB(255, 255, 255),
    ESPTracerOrigin = "Bottom",
    StickyLock = true,
    AutoFire = false,
    AutoFireDelay = 0.15,
    AutoFireRange = 25,
    BoxStyle = "Box",
    BoxOutline = false,
    HealthNumber = false,
    Skeleton = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    ESPMaxDistance = 0,
    TargetOnly = false,
    TargetPlayer = "",
    Strafe = false,
    StrafeRadius = 12,
    StrafeSpeed = 120,
    StrafeHeight = 0,
    ServerPos = false,
    ServerPosColor = Color3.fromRGB(0, 255, 0),
}

-- Drawing objects BEFORE UI (callbacks fire immediately on creation for sliders,
-- so fovCircle must already exist or launch throws "attempt to index nil")
local fovCircle
do
    local ok, obj = pcall(function() return Drawing.new("Circle") end)
    if ok and obj and typeof(obj) ~= "string" then
        fovCircle = obj
    else
        -- Executor has no Drawing support: dummy object that absorbs property sets
        fovCircle = setmetatable({}, { __index = function() return nil end, __newindex = function() end })
    end
end
pcall(function()
    fovCircle.Visible = false
    fovCircle.Thickness = 2
    fovCircle.Color = Color3.fromRGB(166, 147, 243)
    fovCircle.Transparency = 0.4
    fovCircle.Filled = false
    fovCircle.Radius = 100
end)

-- Crosshair: "Cross" is NOT a valid Drawing type (valid: Line, Circle, Square,
-- Text, Image, Triangle), so Drawing.new("Cross") returns an error string ->
-- line 26 crash. Build crosshair from two Lines instead, with pcall guards
-- so mobile executors without Drawing support don't crash at all.
local crossH, crossV
pcall(function()
    crossH = Drawing.new("Line")
    crossH.Visible = false
    crossH.Thickness = 1
    crossH.Color = Color3.fromRGB(166, 147, 243)
    crossH.Transparency = 0.7
    crossV = Drawing.new("Line")
    crossV.Visible = false
    crossV.Thickness = 1
    crossV.Color = Color3.fromRGB(166, 147, 243)
    crossV.Transparency = 0.7
end)
local function setCrosshair(visible, x, y)
    pcall(function()
        if crossH and crossV then
            crossH.Visible = visible
            crossV.Visible = visible
            if x and y then
                crossH.From = Vector2.new(x - 7, y)
                crossH.To = Vector2.new(x + 7, y)
                crossV.From = Vector2.new(x, y - 7)
                crossV.To = Vector2.new(x, y + 7)
            end
        end
    end)
end

-- Target tracer line (origin -> targeted part), pcall-guarded for executors
-- without Drawing support.
local tracerLine
do
    local ok, obj = pcall(function() return Drawing.new("Line") end)
    if ok and obj and typeof(obj) ~= "string" then
        tracerLine = obj
    else
        tracerLine = setmetatable({}, { __index = function() return nil end, __newindex = function() end })
    end
end
pcall(function()
    tracerLine.Visible = false
    tracerLine.Thickness = 1
    tracerLine.Color = Color3.fromRGB(166, 147, 243)
    tracerLine.Transparency = 0.8
end)

-- FOV fill disc (outline circle stays separate so both keep own opacity)
local fovFill
do
    local ok, obj = pcall(function() return Drawing.new("Circle") end)
    if ok and obj and typeof(obj) ~= "string" then
        fovFill = obj
    else
        fovFill = setmetatable({}, { __index = function() return nil end, __newindex = function() end })
    end
end
pcall(function()
    fovFill.Visible = false
    fovFill.Filled = true
    fovFill.Color = Color3.fromRGB(166, 147, 243)
    fovFill.Transparency = 0.2
    fovFill.Radius = 100
end)

-- Server-position ghost: client-only marker showing where the SERVER sees you
-- while strafing (the orbit point). Purely visual, never replicates/collides.
local serverMarker = nil
pcall(function()
    local p = Instance.new("Part")
    p.Name = "SyncaServerPos"
    p.Anchored = true
    p.CanCollide = false
    p.CanQuery = false
    p.CanTouch = false
    p.Transparency = 1
    p.Material = Enum.Material.Neon
    p.Color = Color3.fromRGB(0, 255, 0)
    p.Size = Vector3.new(3, 5, 2)
    p.CFrame = CFrame.new(0, -100, 0)
    p.Parent = workspace
    serverMarker = p
end)

-- True only when the executor really supports Drawing (dummy fallback tables
-- absorb property reads as nil, so typeof check distinguishes them).
local HAS_DRAWING = typeof(fovCircle.Visible) == "boolean"

local Window = Library:Window({
    Name = "Aimbot",
    FadeSpeed = 0.25
})

local Watermark = Library:Watermark("Aimbot")
local KeybindList = Library:KeybindList()

local CombatTab = Window:Page({Name = "Combat", Columns = 2, Subtabs = false})
local VisualsTab = Window:Page({Name = "Visuals", Columns = 2, Subtabs = false})
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- Sections
local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = 1})
local AdvancedSection = CombatTab:Section({Name = "Advanced", Side = 2})
local TargetSection = CombatTab:Section({Name = "Target", Side = 2})
local ESPSection = VisualsTab:Section({Name = "ESP", Side = 1})

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

-- Alive Check toggle (skip dead players when on)
AimbotSection:Toggle({Name = "Alive Check", Flag = "AliveCheck", Default = true, Callback = function(Value)
    C.AliveCheck = Value
end})

-- FOV toggle + colorpicker
AimbotSection:Toggle({Name = "FoV", Flag = "FOV", Default = false, Callback = function(Value)
    C.FOV = Value
    if fovCircle then
        fovCircle.Visible = Value and C.Enable
    end
end}):Colorpicker({Name = "FoV Color", Flag = "FoV Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    if fovCircle and typeof(Value) == "Color3" then
        fovCircle.Color = Value
    end
end})

-- FOV Size slider (fires immediately at creation, so nil-guard fovCircle)
AimbotSection:Slider({Name = "FoV Size", Min = 10, Max = 300, Default = 100, Suffix = " px", Decimals = 1, Flag = "FOVSize", Callback = function(Value)
    C.FOVSize = Value
    if fovCircle then
        fovCircle.Radius = Value
    end
end})

AimbotSection:Slider({Name = "FoV Opacity", Min = 0, Max = 100, Default = 40, Suffix = "%", Decimals = 1, Flag = "FOVOpacity", Callback = function(Value)
    C.FOVOpacity = Value
end})

AimbotSection:Toggle({Name = "FoV Filled", Flag = "FOVFilled", Default = false, Callback = function(Value)
    C.FOVFilled = Value
end}):Colorpicker({Name = "Fill Color", Flag = "FOV Fill Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.FOVFillColor = Value end
end})

AimbotSection:Slider({Name = "Fill Opacity", Min = 0, Max = 100, Default = 20, Suffix = "%", Decimals = 1, Flag = "FOVFillOpacity", Callback = function(Value)
    C.FOVFillOpacity = Value
end})

AimbotSection:Slider({Name = "FoV Thickness", Min = 1, Max = 5, Default = 2, Suffix = "px", Decimals = 1, Flag = "FOVThickness", Callback = function(Value)
    C.FOVThickness = Value
end})

-- FOV anchor: locked to screen center, or follows the cursor/touch point
AimbotSection:Dropdown({Name = "FoV Position", Flag = "FOVMode", Default = "Center", Items = {"Center", "Cursor"}, Callback = function(Value)
    C.FOVMode = Value
end})

-- Wall Check toggle
AimbotSection:Toggle({Name = "Wall Check", Flag = "WallCheck", Default = false, Callback = function(Value)
    C.WallCheck = Value
end})

-- Targeted part (aliases resolve on both R6 and R15, see PART_ALIASES)
AimbotSection:Dropdown({Name = "Target Part", Flag = "TargetPart", Default = "Head", Items = {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, Callback = function(Value)
    C.TargetPart = Value
end})

-- Target highlight: one Highlight on the whole character model (every part)
AimbotSection:Toggle({Name = "Target Highlight", Flag = "Highlight", Default = false, Callback = function(Value)
    C.Highlight = Value
end}):Colorpicker({Name = "Highlight Color", Flag = "Highlight Color", Default = Color3.fromRGB(255, 60, 60), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.HighlightColor = Value end
end})

AimbotSection:Slider({Name = "Highlight Opacity", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1, Flag = "HighlightOpacity", Callback = function(Value)
    C.HighlightOpacity = Value
end})

-- Smoothness slider
AdvancedSection:Slider({Name = "Smoothness", Min = 1, Max = 100, Default = 10, Suffix = "x", Decimals = 1, Flag = "Smoothness", Callback = function(Value)
    C.Smoothness = Value
end})

-- Prediction toggle (no more resetting the slider to 0)
AdvancedSection:Toggle({Name = "Prediction", Flag = "PredictionEnabled", Default = false, Callback = function(Value)
    C.PredictionEnabled = Value
end})

-- Prediction slider
AdvancedSection:Slider({Name = "Prediction", Min = 0, Max = 50, Default = 5, Suffix = " studs", Decimals = 1, Flag = "Prediction", Callback = function(Value)
    C.Prediction = Value
end})

-- Target tracer: line from origin to the currently targeted part
TargetSection:Toggle({Name = "Sticky Lock", Flag = "StickyLock", Default = true, Callback = function(Value)
    C.StickyLock = Value
end})

TargetSection:Toggle({Name = "Auto Fire", Flag = "AutoFire", Default = false, Callback = function(Value)
    C.AutoFire = Value
end})

TargetSection:Slider({Name = "Fire Delay", Min = 0.05, Max = 1, Default = 0.15, Suffix = "s", Decimals = 2, Flag = "AutoFireDelay", Callback = function(Value)
    C.AutoFireDelay = Value
end})

TargetSection:Slider({Name = "Fire Range", Min = 5, Max = 100, Default = 25, Suffix = "px", Decimals = 1, Flag = "AutoFireRange", Callback = function(Value)
    C.AutoFireRange = Value
end})

TargetSection:Toggle({Name = "Target Tracer", Flag = "Tracer", Default = false, Callback = function(Value)
    C.Tracer = Value
end}):Colorpicker({Name = "Tracer Color", Flag = "Tracer Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    if tracerLine and typeof(Value) == "Color3" then
        tracerLine.Color = Value
    end
end})

TargetSection:Dropdown({Name = "Tracer Origin", Flag = "TracerOrigin", Default = "Cursor", Items = {"Cursor", "Bottom", "Top"}, Callback = function(Value)
    C.TracerOrigin = Value
end})

-- Target menu: lock onto ONE player, ignore everyone else
TargetSection:Toggle({Name = "Target Only", Flag = "TargetOnly", Default = false, Callback = function(Value)
    C.TargetOnly = Value
end})

local function playerNames()
    local Svc = game:GetService("Players")
    local lp = Svc.LocalPlayer
    local names = {}
    for _, p in ipairs(Svc:GetPlayers()) do
        if p ~= lp then table.insert(names, p.Name) end
    end
    table.sort(names)
    return names
end

local targetList = TargetSection:Listbox({Name = "Target", Flag = "SelectedTarget", Items = playerNames(), Size = 120, Callback = function(Value)
    C.TargetPlayer = (type(Value) == "table" and Value[1]) or Value or ""
end})

TargetSection:Button({Name = "Refresh Targets", Callback = function()
    local names = playerNames()
    pcall(function() targetList:Refresh(names) end)
    if C.TargetPlayer ~= "" and not table.find(names, C.TargetPlayer) then
        C.TargetPlayer = ""
    end
end})

game:GetService("Players").PlayerAdded:Connect(function()
    pcall(function() targetList:Refresh(playerNames()) end)
end)

game:GetService("Players").PlayerRemoving:Connect(function(p)
    pcall(function() targetList:Refresh(playerNames()) end)
    if C.TargetPlayer == p.Name then C.TargetPlayer = "" end
end)

-- C-sync strafe: orbit the selected/locked target on the server while you
-- keep walking freely on your screen. Pair with Target Only + Auto Fire.
TargetSection:Toggle({Name = "Strafe Target", Flag = "Strafe", Default = false, Callback = function(Value)
    C.Strafe = Value
end})

TargetSection:Slider({Name = "Strafe Radius", Min = 5, Max = 30, Default = 12, Suffix = " studs", Decimals = 1, Flag = "StrafeRadius", Callback = function(Value)
    C.StrafeRadius = Value
end})

TargetSection:Slider({Name = "Strafe Speed", Min = 10, Max = 360, Default = 120, Suffix = " deg/s", Decimals = 1, Flag = "StrafeSpeed", Callback = function(Value)
    C.StrafeSpeed = Value
end})

TargetSection:Slider({Name = "Strafe Height", Min = -5, Max = 10, Default = 0, Suffix = " studs", Decimals = 1, Flag = "StrafeHeight", Callback = function(Value)
    C.StrafeHeight = Value
end})

TargetSection:Toggle({Name = "Server Position", Flag = "ServerPos", Default = false, Callback = function(Value)
    C.ServerPos = Value
end}):Colorpicker({Name = "Server Color", Flag = "Server Color", Default = Color3.fromRGB(0, 255, 0), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.ServerPosColor = Value end
end})

-- Full ESP suite (everyone passing the Team Check filter)
ESPSection:Toggle({Name = "ESP Highlight", Flag = "ESPHighlight", Default = false, Callback = function(Value)
    C.ESPHighlight = Value
end}):Colorpicker({Name = "ESP Color", Flag = "ESP Color", Default = Color3.fromRGB(170, 140, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.ESPHighlightColor = Value end
end})

ESPSection:Slider({Name = "ESP Opacity", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1, Flag = "ESPHighlightOpacity", Callback = function(Value)
    C.ESPHighlightOpacity = Value
end})

ESPSection:Toggle({Name = "Box ESP", Flag = "BoxESP", Default = false, Callback = function(Value)
    C.BoxESP = Value
end}):Colorpicker({Name = "Box Color", Flag = "Box Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.BoxColor = Value end
end})

ESPSection:Dropdown({Name = "Box Style", Flag = "BoxStyle", Default = "Box", Items = {"Box", "Corners"}, Callback = function(Value)
    C.BoxStyle = Value
end})

ESPSection:Toggle({Name = "Box Outline", Flag = "BoxOutline", Default = false, Callback = function(Value)
    C.BoxOutline = Value
end})

ESPSection:Toggle({Name = "Health Bar", Flag = "HealthBar", Default = false, Callback = function(Value)
    C.HealthBar = Value
end})

ESPSection:Toggle({Name = "Health Number", Flag = "HealthNumber", Default = false, Callback = function(Value)
    C.HealthNumber = Value
end})

ESPSection:Toggle({Name = "Name ESP", Flag = "NameESP", Default = false, Callback = function(Value)
    C.NameESP = Value
end})

ESPSection:Toggle({Name = "Distance ESP", Flag = "DistanceESP", Default = false, Callback = function(Value)
    C.DistanceESP = Value
end})

ESPSection:Toggle({Name = "ESP Tracer", Flag = "ESPTracer", Default = false, Callback = function(Value)
    C.ESPTracer = Value
end}):Colorpicker({Name = "ESP Tracer Color", Flag = "ESP Tracer Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.ESPTracerColor = Value end
end})

ESPSection:Dropdown({Name = "ESP Tracer Origin", Flag = "ESPTracerOrigin", Default = "Bottom", Items = {"Cursor", "Bottom", "Top"}, Callback = function(Value)
    C.ESPTracerOrigin = Value
end})

ESPSection:Toggle({Name = "Skeleton ESP", Flag = "Skeleton", Default = false, Callback = function(Value)
    C.Skeleton = Value
end}):Colorpicker({Name = "Skeleton Color", Flag = "Skeleton Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.SkeletonColor = Value end
end})

ESPSection:Slider({Name = "ESP Max Distance", Min = 0, Max = 2000, Default = 0, Suffix = " studs", Decimals = 1, Flag = "ESPMaxDistance", Callback = function(Value)
    C.ESPMaxDistance = Value
end})

-- Aim Bot State
local AIMBOT = {
    Target = nil,
    TargetPart = nil,
    Lock = nil,
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UIS = game:GetService("UserInputService")

-- FOV anchor point: screen center, or live cursor/touch position
local function getFovCenter()
    local cam = workspace.CurrentCamera
    if not cam then return Vector2.new(0, 0) end
    if C.FOVMode == "Cursor" then
        local ok, pos = pcall(function() return UIS:GetMouseLocation() end)
        if ok and pos then return Vector2.new(pos.X, pos.Y) end
    end
    local sc = cam.ViewportSize / 2
    return Vector2.new(sc.X, sc.Y)
end

-- Helpers
-- Team objects compare by instance. (The old code read player.Team.TeamId,
-- which does not exist, so it compared nil == nil and treated EVERYONE as a
-- teammate, making the aimbot target nobody.)
local function isTeamMate(player)
    if not C.TeamCheck then return false end
    if not player or not player.Team then return false end
    if not LocalPlayer.Team then return false end
    return player.Team == LocalPlayer.Team
end

local function isValidTarget(player)
    if not player then return false end
    if player == LocalPlayer then return false end
    local char = player.Character
    if not char then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    if not char:FindFirstChild("Head") then return false end
    -- Alive check (toggleable): skip the dead when on
    if C.AliveCheck then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
    end
    if isTeamMate(player) then return false end
    return true
end

-- R6 + R15 part resolver: each dropdown option maps to its R6 name first,
-- then the R15 equivalent. Falls back to Head so a missing part never breaks
-- targeting.
local PART_ALIASES = {
    ["Head"] = {"Head"},
    ["HumanoidRootPart"] = {"HumanoidRootPart"},
    ["Torso"] = {"Torso", "UpperTorso"},
    ["Left Arm"] = {"Left Arm", "LeftUpperArm"},
    ["Right Arm"] = {"Right Arm", "RightUpperArm"},
    ["Left Leg"] = {"Left Leg", "LeftUpperLeg"},
    ["Right Leg"] = {"Right Leg", "RightUpperLeg"},
}

local function getAimPart(player)
    local char = player and player.Character
    if not char then return nil, nil end
    local aliases = PART_ALIASES[C.TargetPart] or PART_ALIASES["Head"]
    for _, name in ipairs(aliases) do
        local part = char:FindFirstChild(name)
        if part then return part.Position, part end
    end
    local head = char:FindFirstChild("Head")
    if head then return head.Position, head end
    return nil, nil
end

-- Wall check must ignore the TARGET's own body too: the old version only
-- excluded our character, so the ray always hit the enemy's head/limbs and
-- reported "blocked", making the aimbot target nobody.
local function canSeeTarget(targetPos, targetPlayer)
    if not C.WallCheck then return true end
    local cam = workspace.CurrentCamera
    if not cam then return true end
    local char = LocalPlayer.Character
    local cameraPos = cam.CFrame.Position
    local direction = targetPos - cameraPos
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    local filter = {}
    if char then
        table.insert(filter, char)
    end
    local targetChar = targetPlayer and targetPlayer.Character
    if targetChar then
        table.insert(filter, targetChar)
    end
    if #filter > 0 then
        rayParams.FilterDescendantsInstances = filter
    end
    local ok, result = pcall(function()
        return workspace:Raycast(cameraPos, direction, rayParams)
    end)
    if not ok then return true end
    if result then return false end
    return true
end

local function isInFOV(targetPos)
    if not C.FOV then return true end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local screenPos, onScreen = cam:WorldToViewportPoint(targetPos)
    if not onScreen then return false end
    -- Same anchor + radius as the drawn circle, so visuals match targeting exactly
    local anchor = getFovCenter()
    local distance = math.sqrt((screenPos.X - anchor.X)^2 + (screenPos.Y - anchor.Y)^2)
    return distance <= C.FOVSize
end

local function findClosestTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    -- Target Only: ignore everyone except the selected listbox player
    if C.TargetOnly then
        if C.TargetPlayer == "" then return nil end
        local only = Players:FindFirstChild(C.TargetPlayer)
        if not only or not isValidTarget(only) then return nil end
        local opos, opart = getAimPart(only)
        if not opos then return nil end
        if not isInFOV(opos) then return nil end
        if not canSeeTarget(opos, only) then return nil end
        AIMBOT.TargetPart = opart
        return only
    end
    local closest = nil
    local closestDist = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if not isValidTarget(player) then continue end
        local pos, part = getAimPart(player)
        if not pos then continue end
        if not isInFOV(pos) then continue end
        if not canSeeTarget(pos, player) then continue end
        local dist = (cam.CFrame.Position - pos).Magnitude
        if dist < closestDist then
            closestDist = dist
            closest = player
            AIMBOT.TargetPart = part
        end
    end
    return closest
end

-- Sticky-lock validation: the lock holds while the target is alive, visible
-- and inside the FOV/screen. Look away (or break line of sight) to drop it.
local function isLockValid(target)
    if not target then return false end
    if not isValidTarget(target) then return false end
    if C.TargetOnly and (C.TargetPlayer == "" or target.Name ~= C.TargetPlayer) then return false end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local pos, _ = getAimPart(target)
    if not pos then return false end
    if C.FOV then
        local screenPos, onScreen = cam:WorldToViewportPoint(pos)
        if not onScreen then return false end
        local anchor = getFovCenter()
        local d = math.sqrt((screenPos.X - anchor.X)^2 + (screenPos.Y - anchor.Y)^2)
        if d > C.FOVSize then return false end
    else
        local _, onScreen = cam:WorldToViewportPoint(pos)
        if not onScreen then return false end
    end
    if not canSeeTarget(pos, target) then return false end
    return true
end

local function executeAim(target, dt)
    local cam = workspace.CurrentCamera
    if not cam then return end
    local headPos, headPart = getAimPart(target)
    if not headPos then return end

    local velocity = Vector3.new(0, 0, 0)
    local char = target.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root and root.Velocity then
        velocity = root.Velocity
    end

    -- Only lead the target when prediction is toggled on AND it is actually
    -- moving; otherwise aim at the part directly.
    local predictedPos = headPos
    if C.PredictionEnabled and C.Prediction > 0 and velocity.Magnitude > 0.5 then
        predictedPos = headPos + (velocity.Unit * C.Prediction)
    end

    local targetCF = CFrame.lookAt(cam.CFrame.Position, predictedPos)

    -- Higher smoothness = slower glide, 1 = instant snap. dt-corrected so the
    -- feel is identical at any frame rate (same glide at 30fps and 144fps).
    local rate = 1 / math.max(C.Smoothness, 1)
    local alpha = 1 - math.pow(1 - rate, (dt or 0.016) * 60)
    cam.CFrame = cam.CFrame:Lerp(targetCF, math.clamp(alpha, 0, 1))
end

-- Single Highlight instance, reparented whenever the target changes. One Highlight
-- on the character model covers every body part, not just the selected aim part.
local targetHighlight = nil
local highlightedChar = nil
local function updateHighlight()
    local want = C.Highlight and C.Enable and AIMBOT.Target ~= nil
    local char = want and AIMBOT.Target.Character or nil
    if targetHighlight then
        if not want or highlightedChar ~= char or targetHighlight.Parent ~= char then
            pcall(function() targetHighlight:Destroy() end)
            targetHighlight, highlightedChar = nil, nil
        end
    end
    if want and char and not targetHighlight then
        local ok, hl = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "SyncaTarget"
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.Parent = char
            return h
        end)
        if ok and hl then targetHighlight, highlightedChar = hl, char end
    end
    if targetHighlight then
        pcall(function()
            targetHighlight.FillColor = C.HighlightColor
            targetHighlight.OutlineColor = C.HighlightColor
            targetHighlight.FillTransparency = 1 - (C.HighlightOpacity / 100)
            targetHighlight.OutlineTransparency = 0
        end)
    end
end

-- Per-player ESP drawings + highlight, created once and reused. Drawings need
-- the Drawing library; Highlights are plain Instances and work everywhere.
local espCache = {}

local function clearEspEntry(player)
    local e = espCache[player]
    if not e then return end
    espCache[player] = nil
    pcall(function()
        if e.box then e.box:Remove() end
        if e.hpBg then e.hpBg:Remove() end
        if e.hp then e.hp:Remove() end
        if e.text then e.text:Remove() end
        if e.dist then e.dist:Remove() end
        if e.tracer then e.tracer:Remove() end
        if e.boxBg then e.boxBg:Remove() end
        if e.cn then for _, ln in ipairs(e.cn) do ln:Remove() end end
        if e.hpNum then e.hpNum:Remove() end
        if e.sk then for _, ln in ipairs(e.sk) do ln:Remove() end end
        if e.hl then e.hl:Destroy() end
    end)
end

local function hideEspEntry(e)
    pcall(function()
        if e.box then e.box.Visible = false end
        if e.hpBg then e.hpBg.Visible = false end
        if e.hp then e.hp.Visible = false end
        if e.text then e.text.Visible = false end
        if e.dist then e.dist.Visible = false end
        if e.tracer then e.tracer.Visible = false end
        if e.boxBg then e.boxBg.Visible = false end
        if e.cn then for _, ln in ipairs(e.cn) do ln.Visible = false end end
        if e.hpNum then e.hpNum.Visible = false end
        if e.sk then for _, ln in ipairs(e.sk) do ln.Visible = false end end
        if e.hl then e.hl.Enabled = false end
    end)
    -- Reset box smoothing so a reappearing player never slides in from stale coords
    e.sx = nil
end

local function getEspEntry(player)
    local e = espCache[player]
    if e then return e end
    e = {}
    if HAS_DRAWING then
        pcall(function()
            e.box = Drawing.new("Square")
            e.box.Visible = false
            e.box.Filled = false
            e.box.Thickness = 1
            e.hpBg = Drawing.new("Line")
            e.hpBg.Visible = false
            e.hpBg.Thickness = 4
            e.hp = Drawing.new("Line")
            e.hp.Visible = false
            e.hp.Thickness = 2
            e.text = Drawing.new("Text")
            e.text.Visible = false
            e.text.Size = 13
            e.text.Center = true
            e.text.Outline = true
            e.dist = Drawing.new("Text")
            e.dist.Visible = false
            e.dist.Size = 13
            e.dist.Center = false
            e.dist.Outline = true
            e.tracer = Drawing.new("Line")
            e.tracer.Visible = false
            e.tracer.Thickness = 1
            e.boxBg = Drawing.new("Square")
            e.boxBg.Visible = false
            e.boxBg.Filled = false
            e.boxBg.Thickness = 1
            e.cn = {}
            for i = 1, 8 do
                local ln = Drawing.new("Line")
                ln.Visible = false
                ln.Thickness = 1
                e.cn[i] = ln
            end
            e.hpNum = Drawing.new("Text")
            e.hpNum.Visible = false
            e.hpNum.Size = 13
            e.hpNum.Center = false
            e.hpNum.Outline = true
            e.sk = {}
            for i = 1, 5 do
                local ln = Drawing.new("Line")
                ln.Visible = false
                ln.Thickness = 1
                e.sk[i] = ln
            end
        end)
    end
    espCache[player] = e
    return e
end

-- 2D bounding box of a character model, clamped to the viewport.
local function getCharBox(char, cam)
    local ok, cf, size = pcall(function() return char:GetBoundingBox() end)
    if not ok or not cf then return nil end
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local anyVisible = false
    for _, sx in ipairs({-1, 1}) do
        for _, sy in ipairs({-1, 1}) do
            for _, sz in ipairs({-1, 1}) do
                local corner = (cf * CFrame.new(size.X * sx / 2, size.Y * sy / 2, size.Z * sz / 2)).Position
                local sp, on = cam:WorldToViewportPoint(corner)
                if on then anyVisible = true end
                if sp.X < minX then minX = sp.X end
                if sp.Y < minY then minY = sp.Y end
                if sp.X > maxX then maxX = sp.X end
                if sp.Y > maxY then maxY = sp.Y end
            end
        end
    end
    if not anyVisible then return nil end
    minX = math.clamp(minX, 0, cam.ViewportSize.X)
    minY = math.clamp(minY, 0, cam.ViewportSize.Y)
    maxX = math.clamp(maxX, 0, cam.ViewportSize.X)
    maxY = math.clamp(maxY, 0, cam.ViewportSize.Y)
    if maxX - minX < 2 or maxY - minY < 2 then return nil end
    return minX, minY, maxX, maxY
end

local function espTracerOrigin(cam)
    if C.ESPTracerOrigin == "Top" then
        return Vector2.new(cam.ViewportSize.X / 2, 0)
    elseif C.ESPTracerOrigin == "Cursor" then
        local okm, mp = pcall(function() return UIS:GetMouseLocation() end)
        if okm and mp then return Vector2.new(mp.X, mp.Y) end
        return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
    end
    return Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
end

local function updateESP(dt)
    local cam = workspace.CurrentCamera
    if not cam then return end
    for player, _ in pairs(espCache) do
        if not Players:FindFirstChild(player.Name) then
            clearEspEntry(player)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        local e = getEspEntry(player)
        -- Same eligibility as aiming (respects Team Check), minus FOV/wall gates:
        -- ESP shows everyone on screen.
        if not isValidTarget(player) then
            hideEspEntry(e)
            continue
        end
        local char = player.Character
        if not char then
            hideEspEntry(e)
            continue
        end
        if C.ESPMaxDistance > 0 then
            local hrp0 = char:FindFirstChild("HumanoidRootPart")
            if hrp0 and (cam.CFrame.Position - hrp0.Position).Magnitude > C.ESPMaxDistance then
                hideEspEntry(e)
                continue
            end
        end
        -- ESP highlight (Instance-based, works without Drawing support)
        if C.ESPHighlight then
            if not e.hl or e.hlChar ~= char or e.hl.Parent ~= char then
                if e.hl then pcall(function() e.hl:Destroy() end) end
                e.hl, e.hlChar = nil, nil
                local okh, hl = pcall(function()
                    local h = Instance.new("Highlight")
                    h.Name = "SyncaESP"
                    h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
                    h.Parent = char
                    return h
                end)
                if okh and hl then e.hl, e.hlChar = hl, char end
            end
            if e.hl then
                pcall(function()
                    e.hl.Enabled = true
                    e.hl.FillColor = C.ESPHighlightColor
                    e.hl.OutlineColor = C.ESPHighlightColor
                    e.hl.FillTransparency = 1 - (C.ESPHighlightOpacity / 100)
                    e.hl.OutlineTransparency = 0
                end)
            end
        elseif e.hl then
            pcall(function() e.hl.Enabled = false end)
        end
        if not HAS_DRAWING then continue end
        local minX, minY, maxX, maxY = getCharBox(char, cam)
        if not minX then
            hideEspEntry(e)
            if e.hl then pcall(function() e.hl.Enabled = false end) end
            continue
        end
        -- Smooth the rect toward its new position: raw bounding-box corners
        -- jump around on fast camera flicks, the smoothed rect does not.
        local w, h = maxX - minX, maxY - minY
        local k = 1 - math.exp(-18 * (dt or 0.016))
        if e.sx == nil then
            e.sx, e.sy, e.sw, e.sh = minX, minY, w, h
        else
            e.sx += (minX - e.sx) * k
            e.sy += (minY - e.sy) * k
            e.sw += (w - e.sw) * k
            e.sh += (h - e.sh) * k
        end
        local sx, sy, sw, sh = e.sx, e.sy, e.sw, e.sh
        local cx = sx + sw / 2
        local sbot = sy + sh
        if C.BoxESP then
            if C.BoxStyle == "Corners" and e.cn then
                if e.box then e.box.Visible = false end
                if e.boxBg then e.boxBg.Visible = false end
                local L = math.clamp(math.min(sw, sh) * 0.25, 4, 30)
                local pts = {
                    {sx, sy, sx + L, sy}, {sx, sy, sx, sy + L},
                    {sx + sw, sy, sx + sw - L, sy}, {sx + sw, sy, sx + sw, sy + L},
                    {sx, sbot, sx + L, sbot}, {sx, sbot, sx, sbot - L},
                    {sx + sw, sbot, sx + sw - L, sbot}, {sx + sw, sbot, sx + sw, sbot - L},
                }
                for i = 1, 8 do
                    local ln = e.cn[i]
                    local p = pts[i]
                    ln.Visible = true
                    ln.From = Vector2.new(p[1], p[2])
                    ln.To = Vector2.new(p[3], p[4])
                    ln.Color = C.BoxColor
                end
            else
                if e.cn then for _, ln in ipairs(e.cn) do ln.Visible = false end end
                if C.BoxOutline and e.boxBg then
                    e.boxBg.Visible = true
                    e.boxBg.Position = Vector2.new(sx - 1, sy - 1)
                    e.boxBg.Size = Vector2.new(sw + 2, sh + 2)
                    e.boxBg.Color = Color3.fromRGB(0, 0, 0)
                elseif e.boxBg then
                    e.boxBg.Visible = false
                end
                if e.box then
                    e.box.Visible = true
                    e.box.Position = Vector2.new(sx, sy)
                    e.box.Size = Vector2.new(sw, sh)
                    e.box.Color = C.BoxColor
                end
            end
        else
            if e.box then e.box.Visible = false end
            if e.boxBg then e.boxBg.Visible = false end
            if e.cn then for _, ln in ipairs(e.cn) do ln.Visible = false end end
        end
        if C.HealthBar and e.hpBg and e.hp then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local frac = 0
            if hum and hum.MaxHealth > 0 then
                frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            end
            local bx = sx - 5
            e.hpBg.Visible = true
            e.hpBg.From = Vector2.new(bx, sbot)
            e.hpBg.To = Vector2.new(bx, sy)
            e.hpBg.Color = Color3.fromRGB(0, 0, 0)
            e.hp.Visible = true
            e.hp.From = Vector2.new(bx, sbot)
            e.hp.To = Vector2.new(bx, sbot - sh * frac)
            e.hp.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0)
        else
            if e.hpBg then e.hpBg.Visible = false end
            if e.hp then e.hp.Visible = false end
        end
        if C.HealthNumber and e.hpNum then
            local hum2 = char:FindFirstChildOfClass("Humanoid")
            if hum2 and hum2.MaxHealth > 0 then
                e.hpNum.Visible = true
                e.hpNum.Text = tostring(math.floor(hum2.Health + 0.5))
                e.hpNum.Position = Vector2.new(sx - 32, sy - 16)
                e.hpNum.Color = Color3.fromRGB(255, 255, 255)
            else
                e.hpNum.Visible = false
            end
        elseif e.hpNum then
            e.hpNum.Visible = false
        end
        -- Name centered top-middle; distance pinned to the top-right corner
        -- (opposite the left-side health bar).
        if C.NameESP and e.text then
            e.text.Visible = true
            e.text.Text = player.Name
            e.text.Position = Vector2.new(cx, sy - 16)
            e.text.Color = Color3.fromRGB(255, 255, 255)
        elseif e.text then
            e.text.Visible = false
        end
        if C.DistanceESP and e.dist then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = math.floor((cam.CFrame.Position - hrp.Position).Magnitude)
                e.dist.Visible = true
                e.dist.Text = "[" .. d .. "m]"
                e.dist.Position = Vector2.new(sx + sw + 3, sy - 16)
                e.dist.Color = Color3.fromRGB(255, 255, 255)
            else
                e.dist.Visible = false
            end
        elseif e.dist then
            e.dist.Visible = false
        end
        if C.ESPTracer and e.tracer then
            e.tracer.Visible = true
            e.tracer.From = espTracerOrigin(cam)
            e.tracer.To = Vector2.new(cx, sbot)
            e.tracer.Color = C.ESPTracerColor
        elseif e.tracer then
            e.tracer.Visible = false
        end
        if C.Skeleton and e.sk then
            local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
            local head = char:FindFirstChild("Head")
            local la = char:FindFirstChild("Left Arm") or char:FindFirstChild("LeftUpperArm")
            local ra = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
            local ll = char:FindFirstChild("Left Leg") or char:FindFirstChild("LeftUpperLeg")
            local rl = char:FindFirstChild("Right Leg") or char:FindFirstChild("RightUpperLeg")
            local segs = {{head, torso}, {torso, la}, {torso, ra}, {torso, ll}, {torso, rl}}
            for i, pair in ipairs(segs) do
                local ln = e.sk[i]
                local a, b = pair[1], pair[2]
                if a and b then
                    local pa, oa = cam:WorldToViewportPoint(a.Position)
                    local pb, ob = cam:WorldToViewportPoint(b.Position)
                    if oa and ob then
                        ln.Visible = true
                        ln.From = Vector2.new(pa.X, pa.Y)
                        ln.To = Vector2.new(pb.X, pb.Y)
                        ln.Color = C.SkeletonColor
                    else
                        ln.Visible = false
                    end
                else
                    ln.Visible = false
                end
            end
        elseif e.sk then
            for _, ln in ipairs(e.sk) do ln.Visible = false end
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    clearEspEntry(player)
end)

-- C-sync strafe engine: on Heartbeat (post-physics, pre-replication) teleport
-- to the orbit point so the SERVER replicates you circling the target; on
-- RenderStepped (pre-render) restore your real CFrame so YOU keep walking
-- freely on your screen. Works where the client owns character physics.
local RunService = game:GetService("RunService")
local strafeAngle = 0
local savedCF = nil
local displaced = false

local function getStrafeTarget()
    if not C.Strafe then return nil end
    local p = nil
    if C.TargetPlayer ~= "" then
        p = Players:FindFirstChild(C.TargetPlayer)
    else
        p = AIMBOT.Target
    end
    if not p or not isValidTarget(p) then return nil end
    return p
end

RunService.Heartbeat:Connect(function(dt)
    pcall(function()
        if serverMarker then serverMarker.Transparency = 1 end
        if not C.Strafe then return end
        local t = getStrafeTarget()
        if not t then return end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local thc = t.Character
        local thrp = thc and thc:FindFirstChild("HumanoidRootPart")
        if not hrp or not thrp then return end
        strafeAngle += math.rad(C.StrafeSpeed) * (dt or 0.016)
        local center = thrp.Position + Vector3.new(0, C.StrafeHeight, 0)
        local orbitPos = center + Vector3.new(math.cos(strafeAngle) * C.StrafeRadius, 0, math.sin(strafeAngle) * C.StrafeRadius)
        -- Only snapshot when not already displaced: a second Heartbeat before
        -- the next render must NOT overwrite the real position with the orbit
        -- one (that collapse is what left users stuck following the target).
        if not displaced then
            savedCF = hrp.CFrame
            displaced = true
        end
        hrp.CFrame = CFrame.lookAt(orbitPos, Vector3.new(center.X, orbitPos.Y, center.Z))
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        if serverMarker and C.ServerPos then
            serverMarker.Color = C.ServerPosColor
            serverMarker.CFrame = hrp.CFrame
            serverMarker.Transparency = 0.5
        end
    end)
end)

-- Auto Fire click: executor click first, VirtualInputManager fallback.
-- Non-blocking (release is deferred) so the render loop never yields.
local lastShot = 0
local VIM = nil
pcall(function() VIM = game:GetService("VirtualInputManager") end)
local function fireClick()
    if typeof(mouse1click) == "function" then
        pcall(mouse1click)
        return
    end
    -- Mobile/universal fallback: activate the held tool directly (melee swings,
    -- most guns). mouse-button synthesis often does nothing on touch devices.
    local ch = LocalPlayer.Character
    local tool = ch and ch:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
        return
    end
    if typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
        pcall(mouse1press)
        task.delay(0.05, function() pcall(mouse1release) end)
    elseif VIM then
        pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, true, game, 0) end)
        task.delay(0.05, function()
            pcall(function() VIM:SendMouseButtonEvent(0, 0, 0, false, game, 0) end)
        end)
    end
end

-- Main render loop (wrapped so one bad frame never kills the aimbot)
game:GetService("RunService").RenderStepped:Connect(function(dt)
    pcall(function()
        -- C-sync restore FIRST: show yourself walking freely before render.
        -- Runs whenever displaced, even if strafe was just toggled off, so you
        -- can never get stuck at the orbit point.
        if displaced and savedCF then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = savedCF end
            displaced = false
            savedCF = nil
        end
        local cam = workspace.CurrentCamera
        if not cam then return end
        local anchor = getFovCenter()
        fovCircle.Position = anchor
        fovCircle.Radius = C.FOVSize
        fovCircle.Transparency = C.FOVOpacity / 100
        fovCircle.Thickness = C.FOVThickness
        fovFill.Position = anchor
        fovFill.Radius = C.FOVSize
        fovFill.Color = C.FOVFillColor
        fovFill.Transparency = C.FOVFillOpacity / 100

        -- Update FOV visualization (follows the master Enable switch)
        fovCircle.Visible = C.FOV and C.Enable
        fovFill.Visible = C.FOV and C.FOVFilled and C.Enable
        setCrosshair(C.Enable, anchor.X, anchor.Y)

        -- Target tracer: draw origin -> live target part position
        local traceFrom, traceTo = nil, nil
        if C.Tracer and C.Enable and AIMBOT.Target then
            local tPos, _ = getAimPart(AIMBOT.Target)
            if tPos then
                local sp, onScreen = cam:WorldToViewportPoint(tPos)
                if onScreen then
                    traceTo = Vector2.new(sp.X, sp.Y)
                    if C.TracerOrigin == "Bottom" then
                        traceFrom = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y)
                    elseif C.TracerOrigin == "Top" then
                        traceFrom = Vector2.new(cam.ViewportSize.X / 2, 0)
                    else
                        local okm, mp = pcall(function() return UIS:GetMouseLocation() end)
                        if okm and mp then traceFrom = Vector2.new(mp.X, mp.Y) end
                    end
                end
            end
        end
        if traceFrom and traceTo then
            tracerLine.Visible = true
            tracerLine.From = traceFrom
            tracerLine.To = traceTo
        else
            tracerLine.Visible = false
        end

        updateHighlight()
        updateESP(dt)

        -- Enable is the master switch: nothing aims while it is off. While on,
        -- hold a sticky lock on one target instead of re-picking closest every
        -- frame (that re-picking was the tug-of-war). The lock drops when the
        -- target dies, hides, or leaves the FOV/screen — look away to release.
        if C.Enable then
            if C.StickyLock then
                if not isLockValid(AIMBOT.Lock) then
                    AIMBOT.Lock = findClosestTarget()
                end
            else
                AIMBOT.Lock = findClosestTarget()
            end
            AIMBOT.Target = AIMBOT.Lock
            if AIMBOT.Target then
                executeAim(AIMBOT.Target, dt)
                if C.AutoFire then
                    local ap, _ = getAimPart(AIMBOT.Target)
                    if ap then
                        local asp, aon = cam:WorldToViewportPoint(ap)
                        if aon then
                            local dd = math.sqrt((asp.X - anchor.X)^2 + (asp.Y - anchor.Y)^2)
                            if dd <= C.AutoFireRange and os.clock() - lastShot >= C.AutoFireDelay then
                                lastShot = os.clock()
                                fireClick()
                            end
                        end
                    end
                end
            else
                AIMBOT.TargetPart = nil
            end
        else
            AIMBOT.Lock = nil
            AIMBOT.Target = nil
            AIMBOT.TargetPart = nil
        end
    end)
end)

-- Init library (loads autoload config)
Library:Init()

-- Load notification
Library:Notification("Aimbot loaded", 5, Library.Theme.Accent, {"rbxassetid://135757045959142", Color3.fromRGB(149, 255, 139)})
