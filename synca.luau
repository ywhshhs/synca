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
    BoxStyle = "Box",
    BoxOutline = false,
    HealthNumber = false,
    Skeleton = false,
    SkeletonColor = Color3.fromRGB(255, 255, 255),
    ESPMaxDistance = 0,
    Priority = "Closest",
    Deadzone = 2,
    Humanize = 0,
    BoxFill = false,
    BoxFillColor = Color3.fromRGB(255, 255, 255),
    BoxFillOpacity = 30,
    TeamColors = false,
    Desync = false,
    DesyncMode = "Freeze",
    SpinSpeed = 180,
    FoVColor = Color3.fromRGB(166, 147, 243),
    LockedColor = Color3.fromRGB(255, 150, 150),
    FOVOutline = false,
    FoVRainbow = false,
    RainbowSpeed = 2,
    AimMethod = "Camera",
    HeadDot = false,
    HeadDotColor = Color3.fromRGB(255, 255, 255),
    HeadDotSize = 4,
    HealthBarPos = "Left",
    ESPDepth = "AlwaysOnTop",
    ESPTracerThickness = 1,
    ESPTracerOpacity = 100,
    BoxThickness = 1,
    ESPTextSize = 13,
    ESPFont = "UI",
    SkeletonThickness = 1,
    Crosshair = false,
    CrossColor = Color3.fromRGB(255, 255, 255),
    CrossSize = 12,
    CrossGap = 6,
    CrossDot = true,
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
    fovCircle.NumSides = 64
    fovCircle.Color = Color3.fromRGB(166, 147, 243)
    fovCircle.Transparency = 0.4
    fovCircle.Filled = false
    fovCircle.Radius = 100
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
    fovFill.NumSides = 64
    fovFill.Color = Color3.fromRGB(166, 147, 243)
    fovFill.Transparency = 0.2
    fovFill.Radius = 100
end)

-- FOV outline ring (dark backing behind the main ring)
local fovOutline
pcall(function()
    fovOutline = Drawing.new("Circle")
end)
if fovOutline == nil or typeof(fovOutline) == "string" then
    fovOutline = setmetatable({}, { __index = function() return nil end, __newindex = function() end })
end
pcall(function()
    fovOutline.Visible = false
    fovOutline.Filled = false
    fovOutline.NumSides = 64
    fovOutline.Color = Color3.fromRGB(0, 0, 0)
    fovOutline.Transparency = 1
    fovOutline.Radius = 100
end)

-- Screen-center crosshair overlay (4 lines + dot)
local chT, chB, chL, chR, chDot = nil, nil, nil, nil, nil
pcall(function()
    chT = Drawing.new("Line")
    chB = Drawing.new("Line")
    chL = Drawing.new("Line")
    chR = Drawing.new("Line")
    for _, ln in ipairs({chT, chB, chL, chR}) do
        ln.Visible = false
        ln.Thickness = 1
        ln.Color = Color3.fromRGB(255, 255, 255)
    end
    chDot = Drawing.new("Circle")
    chDot.Visible = false
    chDot.Filled = true
    chDot.Radius = 2
    chDot.Color = Color3.fromRGB(255, 255, 255)
end)

-- True only when the executor really supports Drawing (dummy fallback tables
-- absorb property reads as nil, so typeof check distinguishes them).
local HAS_DRAWING = typeof(fovCircle.Visible) == "boolean"

-- Desync ghost: client-only marker showing where the SERVER sees your body
-- while desynced. Purely visual, never replicates or collides.
local serverMarker = nil
pcall(function()
    local p = Instance.new("Part")
    p.Name = "ItemMarker"
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

local Window = Library:Window({
    Name = "synca",
    FadeSpeed = 0.25
})

local Watermark = Library:Watermark("synca")
local KeybindList = Library:KeybindList()

local CombatTab = Window:Page({Name = "Combat", Columns = 2, Subtabs = false})
local VisualsTab = Window:Page({Name = "Visuals", Columns = 2, Subtabs = false})
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- Sections
local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = 1})
local AdvancedSection = CombatTab:Section({Name = "Advanced", Side = 2})
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
    if typeof(Value) == "Color3" then C.FoVColor = Value end
    if fovCircle and typeof(Value) == "Color3" then
        fovCircle.Color = Value
    end
end}):Colorpicker({Name = "Locked Color", Flag = "Locked Color", Default = Color3.fromRGB(255, 150, 150), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.LockedColor = Value end
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

AimbotSection:Toggle({Name = "FoV Outline", Flag = "FOVOutline", Default = false, Callback = function(Value)
    C.FOVOutline = Value
end})

AimbotSection:Toggle({Name = "FoV Rainbow", Flag = "FoVRainbow", Default = false, Callback = function(Value)
    C.FoVRainbow = Value
end})

AimbotSection:Slider({Name = "Rainbow Speed", Min = 1, Max = 10, Default = 2, Suffix = "s", Decimals = 1, Flag = "RainbowSpeed", Callback = function(Value)
    C.RainbowSpeed = Value
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

-- Acquisition priority: nearest in 3D, nearest to crosshair, or weakest
AimbotSection:Dropdown({Name = "Target Priority", Flag = "Priority", Default = "Closest", Items = {"Closest", "Cursor", "Lowest HP"}, Callback = function(Value)
    C.Priority = Value
end})

-- Aim method: write the camera, or drive the real mouse (mousemoverel)
AimbotSection:Dropdown({Name = "Aim Method", Flag = "AimMethod", Default = "Camera", Items = {"Camera", "Mouse"}, Callback = function(Value)
    C.AimMethod = Value
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

AdvancedSection:Slider({Name = "Aim Deadzone", Min = 0, Max = 20, Default = 2, Suffix = "px", Decimals = 1, Flag = "Deadzone", Callback = function(Value)
    C.Deadzone = Value
end})

AdvancedSection:Slider({Name = "Humanize", Min = 0, Max = 10, Default = 0, Suffix = "", Decimals = 1, Flag = "Humanize", Callback = function(Value)
    C.Humanize = Value
end})

-- Prediction toggle (no more resetting the slider to 0)
AdvancedSection:Toggle({Name = "Prediction", Flag = "PredictionEnabled", Default = false, Callback = function(Value)
    C.PredictionEnabled = Value
end})

-- Prediction slider
AdvancedSection:Slider({Name = "Prediction", Min = 0, Max = 50, Default = 5, Suffix = " studs", Decimals = 1, Flag = "Prediction", Callback = function(Value)
    C.Prediction = Value
end})

local MiscSection = CombatTab:Section({Name = "Movement", Side = 2})

-- Desync: the server replicates a frozen/spinning body while you walk freely.
-- Freeze captures the spot on enable; Spin rotates the replicated body.
MiscSection:Toggle({Name = "Desync", Flag = "Desync", Default = false, Callback = function(Value)
    C.Desync = Value
end})

MiscSection:Dropdown({Name = "Desync Mode", Flag = "DesyncMode", Default = "Freeze", Items = {"Freeze", "Spin"}, Callback = function(Value)
    C.DesyncMode = Value
end})

MiscSection:Slider({Name = "Spin Speed", Min = 10, Max = 360, Default = 180, Suffix = " deg/s", Decimals = 1, Flag = "SpinSpeed", Callback = function(Value)
    C.SpinSpeed = Value
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

ESPSection:Dropdown({Name = "Depth Mode", Flag = "ESPDepth", Default = "AlwaysOnTop", Items = {"AlwaysOnTop", "Occluded"}, Callback = function(Value)
    C.ESPDepth = Value
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

ESPSection:Slider({Name = "Box Thickness", Min = 1, Max = 5, Default = 1, Suffix = "px", Decimals = 1, Flag = "BoxThickness", Callback = function(Value)
    C.BoxThickness = Value
end})

ESPSection:Toggle({Name = "Box Fill", Flag = "BoxFill", Default = false, Callback = function(Value)
    C.BoxFill = Value
end}):Colorpicker({Name = "Fill Color", Flag = "Box Fill Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.BoxFillColor = Value end
end})

ESPSection:Slider({Name = "Fill Opacity", Min = 0, Max = 100, Default = 30, Suffix = "%", Decimals = 1, Flag = "BoxFillOpacity", Callback = function(Value)
    C.BoxFillOpacity = Value
end})

ESPSection:Toggle({Name = "Team Colors", Flag = "TeamColors", Default = false, Callback = function(Value)
    C.TeamColors = Value
end})

ESPSection:Toggle({Name = "Health Bar", Flag = "HealthBar", Default = false, Callback = function(Value)
    C.HealthBar = Value
end})

ESPSection:Dropdown({Name = "Bar Position", Flag = "HealthBarPos", Default = "Left", Items = {"Left", "Top", "Right", "Bottom"}, Callback = function(Value)
    C.HealthBarPos = Value
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

ESPSection:Slider({Name = "Tracer Thickness", Min = 1, Max = 5, Default = 1, Suffix = "px", Decimals = 1, Flag = "ESPTracerThickness", Callback = function(Value)
    C.ESPTracerThickness = Value
end})

ESPSection:Slider({Name = "Tracer Opacity", Min = 0, Max = 100, Default = 100, Suffix = "%", Decimals = 1, Flag = "ESPTracerOpacity", Callback = function(Value)
    C.ESPTracerOpacity = Value
end})

local CrossSection = VisualsTab:Section({Name = "Crosshair", Side = 2})

CrossSection:Toggle({Name = "Crosshair", Flag = "Crosshair", Default = false, Callback = function(Value)
    C.Crosshair = Value
end}):Colorpicker({Name = "Crosshair Color", Flag = "Crosshair Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.CrossColor = Value end
end})

CrossSection:Slider({Name = "Size", Min = 4, Max = 30, Default = 12, Suffix = "px", Decimals = 1, Flag = "CrossSize", Callback = function(Value)
    C.CrossSize = Value
end})

CrossSection:Slider({Name = "Gap", Min = 0, Max = 20, Default = 6, Suffix = "px", Decimals = 1, Flag = "CrossGap", Callback = function(Value)
    C.CrossGap = Value
end})

CrossSection:Toggle({Name = "Center Dot", Flag = "CrossDot", Default = true, Callback = function(Value)
    C.CrossDot = Value
end})

ESPSection:Toggle({Name = "Skeleton ESP", Flag = "Skeleton", Default = false, Callback = function(Value)
    C.Skeleton = Value
end}):Colorpicker({Name = "Skeleton Color", Flag = "Skeleton Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.SkeletonColor = Value end
end})

ESPSection:Slider({Name = "Skeleton Thickness", Min = 1, Max = 5, Default = 1, Suffix = "px", Decimals = 1, Flag = "SkeletonThickness", Callback = function(Value)
    C.SkeletonThickness = Value
end})

ESPSection:Slider({Name = "ESP Max Distance", Min = 0, Max = 2000, Default = 0, Suffix = " studs", Decimals = 1, Flag = "ESPMaxDistance", Callback = function(Value)
    C.ESPMaxDistance = Value
end})

ESPSection:Toggle({Name = "Head Dot", Flag = "HeadDot", Default = false, Callback = function(Value)
    C.HeadDot = Value
end}):Colorpicker({Name = "Dot Color", Flag = "Dot Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.HeadDotColor = Value end
end})

ESPSection:Slider({Name = "Dot Size", Min = 2, Max = 12, Default = 4, Suffix = "px", Decimals = 1, Flag = "HeadDotSize", Callback = function(Value)
    C.HeadDotSize = Value
end})

ESPSection:Slider({Name = "Text Size", Min = 8, Max = 20, Default = 13, Suffix = "px", Decimals = 1, Flag = "ESPTextSize", Callback = function(Value)
    C.ESPTextSize = Value
end})

ESPSection:Dropdown({Name = "Text Font", Flag = "ESPFont", Default = "UI", Items = {"UI", "System", "Plex", "Monospace"}, Callback = function(Value)
    C.ESPFont = Value
end})

-- Aim Bot State
local AIMBOT = {
    Target = nil,
    TargetPart = nil,
    Lock = nil,
    noiseT = 0,
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
    local closest = nil
    local bestScore = math.huge
    for _, player in pairs(Players:GetPlayers()) do
        if not isValidTarget(player) then continue end
        local pos, part = getAimPart(player)
        if not pos then continue end
        if not isInFOV(pos) then continue end
        if not canSeeTarget(pos, player) then continue end
        local score
        if C.Priority == "Cursor" then
            local sp, on = cam:WorldToViewportPoint(pos)
            if not on then continue end
            local anchor = getFovCenter()
            score = math.sqrt((sp.X - anchor.X)^2 + (sp.Y - anchor.Y)^2)
        elseif C.Priority == "Lowest HP" then
            local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if not hum then continue end
            score = hum.Health
        else
            score = (cam.CFrame.Position - pos).Magnitude
        end
        if score < bestScore then
            bestScore = score
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

    local char = target.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local velocity = (root and root.Velocity) or Vector3.new(0, 0, 0)

    -- Lead using movement direction (stable wish-dir, no physics noise),
    -- falling back to velocity for knocks, flings and physics-driven motion.
    local aimDir = nil
    local md = hum and hum.MoveDirection
    if md and md.Magnitude > 0.1 then
        aimDir = md
    elseif velocity.Magnitude > 0.5 then
        aimDir = velocity.Unit
    end
    local predictedPos = headPos
    if C.PredictionEnabled and C.Prediction > 0 and aimDir then
        predictedPos = headPos + (aimDir * C.Prediction)
    end

    -- Humanize: slow sinusoidal wander around the aim point so the camera
    -- never tracks with pixel-perfect linearity (the classic behavioral tell).
    AIMBOT.noiseT += (dt or 0.016)
    local aimPos = predictedPos
    if C.Humanize > 0 then
        local t = AIMBOT.noiseT
        aimPos += Vector3.new(math.sin(t * 3.1), math.sin(t * 2.3 + 1.3), math.sin(t * 2.7 + 2.1)) * (C.Humanize * 0.12)
    end

    -- Deadzone: already on target -> hold still instead of micro-correcting.
    if C.Deadzone > 0 then
        local sp, on = cam:WorldToViewportPoint(aimPos)
        if on then
            local anchor = getFovCenter()
            if math.sqrt((sp.X - anchor.X)^2 + (sp.Y - anchor.Y)^2) <= C.Deadzone then
                return
            end
        end
    end

    -- Mouse mode drives the real cursor (nothing camera-side to flag) and
    -- falls back to camera mode where mousemoverel does not exist.
    if C.AimMethod == "Mouse" and typeof(mousemoverel) == "function" then
        local sp, on = cam:WorldToViewportPoint(aimPos)
        if not on then return end
        local anchor = getFovCenter()
        local div = math.max(C.Smoothness, 1)
        pcall(mousemoverel, (sp.X - anchor.X) / div, (sp.Y - anchor.Y) / div)
        return
    end

    local targetCF = CFrame.lookAt(cam.CFrame.Position, aimPos)

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
            h.Name = "ItemHighlight"
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
        if e.boxFill then e.boxFill:Remove() end
        if e.cn then for _, ln in ipairs(e.cn) do ln:Remove() end end
        if e.hpNum then e.hpNum:Remove() end
        if e.sk then for _, ln in ipairs(e.sk) do ln:Remove() end end
        if e.dot then e.dot:Remove() end
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
        if e.boxFill then e.boxFill.Visible = false end
        if e.cn then for _, ln in ipairs(e.cn) do ln.Visible = false end end
        if e.hpNum then e.hpNum.Visible = false end
        if e.sk then for _, ln in ipairs(e.sk) do ln.Visible = false end end
        if e.dot then e.dot.Visible = false end
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
            e.boxFill = Drawing.new("Square")
            e.boxFill.Visible = false
            e.boxFill.Filled = true
            e.boxFill.Thickness = 0
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
            e.dot = Drawing.new("Circle")
            e.dot.Visible = false
            e.dot.Filled = true
            e.dot.Radius = 4
        end)
    end
    espCache[player] = e
    return e
end

-- Box color: player team color when Team Colors is on, else the picked color.
local function espBoxColor(player)
    if C.TeamColors and player.Team and player.Team.TeamColor then
        return player.Team.TeamColor.Color
    end
    return C.BoxColor
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
                    h.Name = "ItemHighlight"
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
                    e.hl.DepthMode = (C.ESPDepth == "Occluded") and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
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
        -- Text styling (size + typeface)
        if e.text then e.text.Size = C.ESPTextSize end
        if e.dist then e.dist.Size = C.ESPTextSize end
        if e.hpNum then e.hpNum.Size = C.ESPTextSize end
        if C.ESPFont ~= "UI" then
            pcall(function()
                local f = Drawing and Drawing.Fonts and Drawing.Fonts[C.ESPFont]
                if f then
                    if e.text then e.text.Font = f end
                    if e.dist then e.dist.Font = f end
                    if e.hpNum then e.hpNum.Font = f end
                end
            end)
        end
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
                    ln.Color = espBoxColor(player)
                    ln.Thickness = C.BoxThickness
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
                    e.box.Color = espBoxColor(player)
                    e.box.Thickness = C.BoxThickness
                end
            end
        else
            if e.box then e.box.Visible = false end
            if e.boxBg then e.boxBg.Visible = false end
            if e.cn then for _, ln in ipairs(e.cn) do ln.Visible = false end end
        end
        if C.BoxFill and e.boxFill then
            e.boxFill.Visible = true
            e.boxFill.Position = Vector2.new(sx, sy)
            e.boxFill.Size = Vector2.new(sw, sh)
            e.boxFill.Color = C.BoxFillColor
            e.boxFill.Transparency = C.BoxFillOpacity / 100
        elseif e.boxFill then
            e.boxFill.Visible = false
        end
        if C.HealthBar and e.hpBg and e.hp then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local frac = 0
            if hum and hum.MaxHealth > 0 then
                frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            end
            local hcol = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0)
            local side = C.HealthBarPos
            if side == "Top" or side == "Bottom" then
                local by = (side == "Top") and (sy - 5) or (sbot + 5)
                e.hpBg.Visible = true
                e.hpBg.From = Vector2.new(sx, by)
                e.hpBg.To = Vector2.new(sx + sw, by)
                e.hpBg.Color = Color3.fromRGB(0, 0, 0)
                e.hp.Visible = true
                e.hp.From = Vector2.new(sx, by)
                e.hp.To = Vector2.new(sx + sw * frac, by)
                e.hp.Color = hcol
            else
                local bx = (side == "Right") and (sx + sw + 5) or (sx - 5)
                e.hpBg.Visible = true
                e.hpBg.From = Vector2.new(bx, sbot)
                e.hpBg.To = Vector2.new(bx, sy)
                e.hpBg.Color = Color3.fromRGB(0, 0, 0)
                e.hp.Visible = true
                e.hp.From = Vector2.new(bx, sbot)
                e.hp.To = Vector2.new(bx, sbot - sh * frac)
                e.hp.Color = hcol
            end
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
            e.tracer.Thickness = C.ESPTracerThickness
            e.tracer.Transparency = C.ESPTracerOpacity / 100
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
                        ln.Thickness = C.SkeletonThickness
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
        if C.HeadDot and e.dot then
            local hd = char:FindFirstChild("Head")
            if hd then
                local hp, ho = cam:WorldToViewportPoint(hd.Position)
                if ho then
                    e.dot.Visible = true
                    e.dot.Position = Vector2.new(hp.X, hp.Y)
                    e.dot.Radius = C.HeadDotSize
                    e.dot.Color = C.HeadDotColor
                else
                    e.dot.Visible = false
                end
            else
                e.dot.Visible = false
            end
        elseif e.dot then
            e.dot.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    clearEspEntry(player)
end)

-- Desync engine (offset-desync pattern, same family as Nameless Admin's): the
-- anchor is placed on PostSimulation AND Heartbeat (post-physics,
-- pre-replication) so the replicated packet carries the SERVER-side CFrame;
-- RenderStepped (pre-render) restores your real CFrame so YOU walk freely.
-- Freeze = server sees you standing where you enabled it. Spin = server
-- sees you rotating in place. The restore target tracks genuine movement
-- only (placed-vs-real check), resets per life and per mode; the displaced
-- flag stops a hitch from collapsing the desync.
local RSVC = game:GetService("RunService")
local desyncAnchor = nil
local desyncSaved = nil
local desyncPlaced = nil
local desyncDisplaced = false
local desyncLastChar = nil
local desyncLastMode = nil
local DESYNC_EPS = 0.05

-- True when the body is sitting exactly where WE put it (as opposed to a
-- genuine new position from walking/physics). Position-eps plus facing-dot
-- so a same-frame second placement never corrupts the restore target.
local function desyncIsPlaced(cf)
    if not desyncPlaced then return false end
    if (cf.Position - desyncPlaced.Position).Magnitude > DESYNC_EPS then return false end
    return cf.LookVector:Dot(desyncPlaced.LookVector) > 0.999
end

local function desyncPlaceAnchor(dt)
    pcall(function()
        if serverMarker then serverMarker.Transparency = 1 end
        if not C.Desync then
            desyncAnchor = nil
            desyncPlaced = nil
            return
        end
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        -- New life or new mode = fresh desync state.
        if desyncLastChar ~= char or desyncLastMode ~= C.DesyncMode then
            desyncLastChar = char
            desyncLastMode = C.DesyncMode
            desyncAnchor = nil
            desyncPlaced = nil
            desyncDisplaced = false
            desyncSaved = nil
        end
        -- Track the real position, but never mistake our own placed CFrame
        -- for genuine movement (same-frame double placement otherwise snaps
        -- the restore target onto the anchor).
        if not desyncDisplaced then
            desyncSaved = hrp.CFrame
            desyncDisplaced = true
        elseif desyncSaved and not desyncIsPlaced(hrp.CFrame) then
            desyncSaved = hrp.CFrame
        end
        if C.DesyncMode == "Freeze" then
            if not desyncAnchor then desyncAnchor = hrp.CFrame end
            hrp.CFrame = desyncAnchor
            -- Pin the server body: without this it drifts off-anchor between
            -- placements. Spin skips it (better local feel, tracks anyway).
            hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        else
            hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(C.SpinSpeed) * (dt or 0.016), 0)
        end
        desyncPlaced = hrp.CFrame
        if serverMarker then
            serverMarker.CFrame = hrp.CFrame
            serverMarker.Transparency = 0.5
        end
    end)
end

pcall(function()
    RSVC.PostSimulation:Connect(function(dt)
        desyncPlaceAnchor(dt)
    end)
end)
RSVC.Heartbeat:Connect(function(dt)
    desyncPlaceAnchor(dt)
end)

-- Main render loop (wrapped so one bad frame never kills the aimbot)
game:GetService("RunService").RenderStepped:Connect(function(dt)
    pcall(function()
        -- Desync restore FIRST: show your real self before render. Runs even
        -- right after toggling off, so you can never get stuck at the anchor.
        if desyncDisplaced and desyncSaved then
            local dchar = LocalPlayer.Character
            local dhrp = dchar and dchar:FindFirstChild("HumanoidRootPart")
            if dhrp then dhrp.CFrame = desyncSaved end
            desyncDisplaced = false
            desyncSaved = nil
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
        fovOutline.Position = anchor
        fovOutline.Radius = C.FOVSize
        fovOutline.Thickness = C.FOVThickness + 2

        -- Update FOV visualization (follows the master Enable switch)
        fovCircle.Visible = C.FOV and C.Enable
        fovFill.Visible = C.FOV and C.FOVFilled and C.Enable
        fovOutline.Visible = C.FOV and C.FOVOutline and C.Enable

        -- Crosshair overlay at screen center
        pcall(function()
            local showX = C.Crosshair and chT ~= nil
            local vpsz = cam.ViewportSize
            local ccx, ccy = vpsz.X / 2, vpsz.Y / 2
            local cg, cl = C.CrossGap, C.CrossSize
            chT.Visible = showX
            chT.From = Vector2.new(ccx, ccy - cg - cl)
            chT.To = Vector2.new(ccx, ccy - cg)
            chT.Color = C.CrossColor
            chB.Visible = showX
            chB.From = Vector2.new(ccx, ccy + cg)
            chB.To = Vector2.new(ccx, ccy + cg + cl)
            chB.Color = C.CrossColor
            chL.Visible = showX
            chL.From = Vector2.new(ccx - cg - cl, ccy)
            chL.To = Vector2.new(ccx - cg, ccy)
            chL.Color = C.CrossColor
            chR.Visible = showX
            chR.From = Vector2.new(ccx + cg, ccy)
            chR.To = Vector2.new(ccx + cg + cl, ccy)
            chR.Color = C.CrossColor
            if chDot then
                chDot.Visible = showX and C.CrossDot
                chDot.Position = Vector2.new(ccx, ccy)
                chDot.Color = C.CrossColor
            end
        end)

        updateHighlight()
        updateESP(dt)

        -- Enable is the master switch: nothing aims while it is off. While on,
        -- hold a sticky lock on one target instead of re-picking closest every
        -- frame (that re-picking was the tug-of-war). The lock drops when the
        -- target dies, hides, or leaves the FOV/screen — look away to release.
        if C.Enable then
            if not isLockValid(AIMBOT.Lock) then
                AIMBOT.Lock = findClosestTarget()
            end
            AIMBOT.Target = AIMBOT.Lock
            if AIMBOT.Target then
                executeAim(AIMBOT.Target, dt)
            else
                AIMBOT.TargetPart = nil
            end
        else
            AIMBOT.Lock = nil
            AIMBOT.Target = nil
            AIMBOT.TargetPart = nil
        end

        -- Ring color: lock state beats rainbow beats picked color
        local ringColor = C.FoVColor
        if C.FoVRainbow then
            ringColor = Color3.fromHSV((os.clock() % C.RainbowSpeed) / C.RainbowSpeed, 1, 1)
        end
        if AIMBOT.Target then
            ringColor = C.LockedColor
        end
        fovCircle.Color = ringColor
    end)
end)

-- Init library (loads autoload config)
Library:Init()

-- Load notification
Library:Notification("Aimbot loaded", 5, Library.Theme.Accent, {"rbxassetid://135757045959142", Color3.fromRGB(149, 255, 139)})
