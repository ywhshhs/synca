-- synca vendored build: mobile-patched Thugsense fork hosted in this repo
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/ywhshhs/synca/main/Thugsense/Library.lua"))()

-- Config storage (defined first so callbacks never hit nil)
local C = {
    Enable = false,
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
    Triggerbot = false,
    TriggerDelay = 0.1,
    TriggerLock = true,
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
    FillRainbow = false,
    FillPulse = false,
    OutlineColor = Color3.fromRGB(0, 0, 0),
    OutlineOpacity = 100,
    OutlineRainbow = false,
    NameColor = Color3.fromRGB(255, 255, 255),
    DistanceColor = Color3.fromRGB(255, 255, 255),
    HealthNumberColor = Color3.fromRGB(255, 255, 255),
    ESPSmoothing = 18,
    Priority = "Closest",
    Deadzone = 2,
    Humanize = 0,
    BoxFill = false,
    BoxFillColor = Color3.fromRGB(255, 255, 255),
    BoxFillOpacity = 30,
    TeamColors = false,
    Fly = false,
    FlySpeed = 60,
    Speed = false,
    SpeedAmount = 40,
    JumpPower = false,
    JumpPowerAmount = 50,
    InfJump = false,
    Noclip = false,
    CFrameMode = false,
    Resolver = false,
    ResolverRate = 60,
    PredictionVertical = 0.13,
    SmoothnessVertical = 10,
    AirOffset = false,
    AirOffsetAmount = 2,
    RetargetDelay = 0,
    TargetDot = false,
    TargetDotSize = 6,
    TargetDotFilled = true,
    SpoofVelocity = false,
    SpoofType = "Prediction Breaker",
    SpoofStrength = 500,
    FakeLag = false,
    FakeLagInterval = 0.2,
    VelDesync = false,
    VelDesyncRange = 2,
    UndergroundDepth = 6,
    AntiVoid = true,
    Desync = false,
    DesyncMode = "Void",
    VoidTime = 0.4,
    NormalTime = 0.13,
    DesyncGhost = true,
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
-- Creation order = draw order: the outline ring is created FIRST so it sits
-- behind the main ring (a same-size ring created later would cover it).
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

-- Target Dot ring on the locked aim point
local lockDot
pcall(function()
    lockDot = Drawing.new("Circle")
end)
if lockDot == nil or typeof(lockDot) == "string" then
    lockDot = setmetatable({}, { __index = function() return nil end, __newindex = function() end })
end
pcall(function()
    lockDot.Visible = false
    lockDot.Filled = false
    lockDot.Radius = 6
    lockDot.Color = Color3.fromRGB(255, 150, 150)
end)

-- True only when the executor really supports Drawing (dummy fallback tables
-- absorb property reads as nil, so typeof check distinguishes them).
local HAS_DRAWING = typeof(fovCircle.Visible) == "boolean"

-- Noclip (Nameless Admin pattern, rewritten from scratch): originals live in
-- a weak table (dead parts evaporate on their own). step() records originals
-- once and forces everything off, skipping redundant writes. unclip()
-- restores originals exactly (clip/unnoclip symmetry). Step runs immediately
-- on toggle plus every PreSimulation tick, so no physics step ever sees it.
local noclipOrig = setmetatable({}, { __mode = "k" })
local function noclipStep()
    if not C.Noclip then return end
    local ok, ch = pcall(function() return game:GetService("Players").LocalPlayer.Character end)
    if not ok or not ch then return end
    for _, part in ipairs(ch:GetDescendants()) do
        if part:IsA("BasePart") then
            if noclipOrig[part] == nil then noclipOrig[part] = part.CanCollide end
            if part.CanCollide == true then part.CanCollide = false end
        end
    end
end
local function unclip()
    for part, was in pairs(noclipOrig) do
        if typeof(part) == "Instance" and part.Parent and part:IsA("BasePart") then
            part.CanCollide = was == true
        end
        noclipOrig[part] = nil
    end
end

-- Physics-step subscription with Heartbeat fallback (PreSimulation runs
-- pre-physics, which is what makes noclip-style writes stick).
local function onPhysicsStep(fn)
    local _rs = game:GetService("RunService")
    local ok = pcall(function()
        _rs.PreSimulation:Connect(fn)
    end)
    if not ok then _rs.Heartbeat:Connect(fn) end
end

-- Mobile fly controls: the thumbstick already drives Humanoid.MoveDirection
-- (so steering works on touch), but vertical has no keys there. These
-- on-screen hold-to-rise/sink buttons appear only on touch devices while
-- Fly is enabled. Declared up here so the engine below captures the locals.
local flyUpHeld, flyDownHeld = false, false
local flyGui = nil
do
    local _tuis = game:GetService("UserInputService")
    local isTouch = _tuis.TouchEnabled and not _tuis.KeyboardEnabled
    if isTouch then
        pcall(function()
            local parent = nil
            pcall(function()
                if typeof(gethui) == "function" then parent = gethui() end
            end)
            if not parent then parent = game:GetService("CoreGui") end
            local gui = Instance.new("ScreenGui")
            gui.Name = "synca_fly"
            gui.ResetOnSpawn = false
            gui.Enabled = false
            gui.Parent = parent
            local function mkbutton(text, yOff)
                local b = Instance.new("TextButton")
                b.Size = UDim2.new(0, 64, 0, 64)
                b.Position = UDim2.new(1, -84, 0.5, yOff)
                b.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
                b.BackgroundTransparency = 0.3
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
                b.TextSize = 28
                b.Font = Enum.Font.SourceSansBold
                b.Text = text
                local c = Instance.new("UICorner")
                c.CornerRadius = UDim.new(0, 12)
                c.Parent = b
                b.Parent = gui
                return b
            end
            local function bind(btn, set)
                btn.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        set(true)
                    end
                end)
                btn.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        set(false)
                    end
                end)
            end
            bind(mkbutton("\226\150\178", -76), function(v) flyUpHeld = v end)
            bind(mkbutton("\226\150\189", 0), function(v) flyDownHeld = v end)
            flyGui = gui
        end)
    end
end

local Window = Library:Window({
    Name = "synca",
    FadeSpeed = 0.25
})

local Watermark = Library:Watermark("synca")
local KeybindList = Library:KeybindList()

local CombatTab = Window:Page({Name = "Combat", Columns = 2, Subtabs = false})
local VisualsTab = Window:Page({Name = "Visuals", Columns = 2, Subtabs = false})
local MovementTab = Window:Page({Name = "Movement", Columns = 2, Subtabs = false})
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- Sections
local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = 1})
local FOVSection = CombatTab:Section({Name = "Field of View", Side = 1})
local TargetSection = CombatTab:Section({Name = "Target", Side = 1})
local SmoothSection = CombatTab:Section({Name = "Smoothing", Side = 2})
local PredictSection = CombatTab:Section({Name = "Prediction", Side = 2})
local TriggerSection = CombatTab:Section({Name = "Triggerbot", Side = 2})
local ESPSection = VisualsTab:Section({Name = "ESP", Side = 1})
local HealthSection = VisualsTab:Section({Name = "Health", Side = 1})
local TextSection = VisualsTab:Section({Name = "Text", Side = 1})
local TracerSection = VisualsTab:Section({Name = "Tracers", Side = 2})
local SkeletonSection = VisualsTab:Section({Name = "Skeleton", Side = 2})
local PerfSection = VisualsTab:Section({Name = "Performance", Side = 2})

-- Enable toggle with keybind chained on
AimbotSection:Toggle({Name = "Enable", Flag = "Enable", Default = false, Callback = function(Value)
    C.Enable = Value
end}):Keybind({Name = "Hotkey", Flag = "Hotkey", Default = Enum.KeyCode.RightShift, Mode = "Toggle", Callback = function(Value)
    C.Enable = Value
end})

-- Team Check toggle
AimbotSection:Toggle({Name = "Team Check", Flag = "TeamCheck", Default = false, Callback = function(Value)
    C.TeamCheck = Value
end})

-- Alive Check toggle (skip dead players when on)
AimbotSection:Toggle({Name = "Alive Check", Flag = "AliveCheck", Default = true, Callback = function(Value)
    C.AliveCheck = Value
end})

-- FOV toggle + colorpickers (separate statements: Colorpicker() returns the
-- picker extension, not the toggle, so chaining a second picker would error)
local FoVToggle = FOVSection:Toggle({Name = "FoV", Flag = "FOV", Default = false, Callback = function(Value)
    C.FOV = Value
    if fovCircle then
        fovCircle.Visible = Value
    end
end})
FoVToggle:Colorpicker({Name = "FoV Color", Flag = "FoV Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.FoVColor = Value end
    if fovCircle and typeof(Value) == "Color3" then
        fovCircle.Color = Value
    end
end})
FoVToggle:Colorpicker({Name = "Locked Color", Flag = "Locked Color", Default = Color3.fromRGB(255, 150, 150), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.LockedColor = Value end
end})

-- FOV Size slider (fires immediately at creation, so nil-guard fovCircle)
FOVSection:Slider({Name = "FoV Size", Min = 10, Max = 300, Default = 100, Suffix = " px", Decimals = 1, Flag = "FOVSize", Callback = function(Value)
    C.FOVSize = Value
    if fovCircle then
        fovCircle.Radius = Value
    end
end})

FOVSection:Slider({Name = "FoV Opacity", Min = 0, Max = 100, Default = 40, Suffix = "%", Decimals = 1, Flag = "FOVOpacity", Callback = function(Value)
    C.FOVOpacity = Value
end})

FOVSection:Toggle({Name = "FoV Filled", Flag = "FOVFilled", Default = false, Callback = function(Value)
    C.FOVFilled = Value
end}):Colorpicker({Name = "Fill Color", Flag = "FOV Fill Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.FOVFillColor = Value end
end})

FOVSection:Slider({Name = "Fill Opacity", Min = 0, Max = 100, Default = 20, Suffix = "%", Decimals = 1, Flag = "FOVFillOpacity", Callback = function(Value)
    C.FOVFillOpacity = Value
end})

FOVSection:Toggle({Name = "Fill Rainbow", Flag = "FillRainbow", Default = false, Callback = function(Value)
    C.FillRainbow = Value
end})

FOVSection:Toggle({Name = "Fill Pulse", Flag = "FillPulse", Default = false, Callback = function(Value)
    C.FillPulse = Value
end})

FOVSection:Slider({Name = "FoV Thickness", Min = 1, Max = 5, Default = 2, Suffix = "px", Decimals = 1, Flag = "FOVThickness", Callback = function(Value)
    C.FOVThickness = Value
end})

local OutlineToggle = FOVSection:Toggle({Name = "FoV Outline", Flag = "FOVOutline", Default = false, Callback = function(Value)
    C.FOVOutline = Value
end})
OutlineToggle:Colorpicker({Name = "Outline Color", Flag = "Outline Color", Default = Color3.fromRGB(0, 0, 0), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.OutlineColor = Value end
end})

FOVSection:Slider({Name = "Outline Opacity", Min = 0, Max = 100, Default = 100, Suffix = "%", Decimals = 1, Flag = "OutlineOpacity", Callback = function(Value)
    C.OutlineOpacity = Value
end})

FOVSection:Toggle({Name = "Outline Rainbow", Flag = "OutlineRainbow", Default = false, Callback = function(Value)
    C.OutlineRainbow = Value
end})

FOVSection:Toggle({Name = "FoV Rainbow", Flag = "FoVRainbow", Default = false, Callback = function(Value)
    C.FoVRainbow = Value
end})

FOVSection:Slider({Name = "Rainbow Speed", Min = 1, Max = 10, Default = 2, Suffix = "s", Decimals = 1, Flag = "RainbowSpeed", Callback = function(Value)
    C.RainbowSpeed = Value
end})

-- FOV anchor: locked to screen center, or follows the cursor/touch point
FOVSection:Dropdown({Name = "FoV Position", Flag = "FOVMode", Default = "Center", Items = {"Center", "Cursor"}, Callback = function(Value)
    C.FOVMode = Value
end})

-- Wall Check toggle
AimbotSection:Toggle({Name = "Wall Check", Flag = "WallCheck", Default = false, Callback = function(Value)
    C.WallCheck = Value
end})

-- Targeted part (aliases resolve on both R6 and R15, see PART_ALIASES)
TargetSection:Dropdown({Name = "Target Part", Flag = "TargetPart", Default = "Head", Items = {"Head", "HumanoidRootPart", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg"}, Callback = function(Value)
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
TargetSection:Toggle({Name = "Target Highlight", Flag = "Highlight", Default = false, Callback = function(Value)
    C.Highlight = Value
end}):Colorpicker({Name = "Highlight Color", Flag = "Highlight Color", Default = Color3.fromRGB(255, 60, 60), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.HighlightColor = Value end
end})

TargetSection:Slider({Name = "Highlight Opacity", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1, Flag = "HighlightOpacity", Callback = function(Value)
    C.HighlightOpacity = Value
end})

-- Target Dot: ring on the locked aim point itself
TargetSection:Toggle({Name = "Target Dot", Flag = "TargetDot", Default = false, Callback = function(Value)
    C.TargetDot = Value
end})

TargetSection:Slider({Name = "Target Size", Min = 2, Max = 12, Default = 6, Suffix = "px", Decimals = 1, Flag = "TargetDotSize", Callback = function(Value)
    C.TargetDotSize = Value
end})

TargetSection:Toggle({Name = "Target Filled", Flag = "TargetDotFilled", Default = true, Callback = function(Value)
    C.TargetDotFilled = Value
end})

-- Smoothness slider
SmoothSection:Slider({Name = "Smoothness", Min = 1, Max = 100, Default = 10, Suffix = "x", Decimals = 1, Flag = "Smoothness", Callback = function(Value)
    C.Smoothness = Value
end})

SmoothSection:Slider({Name = "Aim Deadzone", Min = 0, Max = 20, Default = 2, Suffix = "px", Decimals = 1, Flag = "Deadzone", Callback = function(Value)
    C.Deadzone = Value
end})

SmoothSection:Slider({Name = "Humanize", Min = 0, Max = 10, Default = 0, Suffix = "", Decimals = 1, Flag = "Humanize", Callback = function(Value)
    C.Humanize = Value
end})

-- Prediction toggle (no more resetting the slider to 0)
PredictSection:Toggle({Name = "Enable Prediction", Flag = "PredictionEnabled", Default = false, Callback = function(Value)
    C.PredictionEnabled = Value
end})

-- Prediction slider
PredictSection:Slider({Name = "Prediction", Min = 0, Max = 50, Default = 5, Suffix = " studs", Decimals = 1, Flag = "Prediction", Callback = function(Value)
    C.Prediction = Value
end})

-- Triggerbot: clicks when the cursor sits on a valid enemy
TriggerSection:Toggle({Name = "Triggerbot", Flag = "Triggerbot", Default = false, Callback = function(Value)
    C.Triggerbot = Value
end})

TriggerSection:Slider({Name = "Trigger Delay", Min = 0, Max = 1, Default = 0.1, Suffix = "s", Decimals = 2, Flag = "TriggerDelay", Callback = function(Value)
    C.TriggerDelay = Value
end})

TriggerSection:Toggle({Name = "Require Lock", Flag = "TriggerLock", Default = true, Callback = function(Value)
    C.TriggerLock = Value
end})

-- Vertical prediction (time-factor on Y velocity, Azure-style)
PredictSection:Slider({Name = "Vertical Prediction", Min = 0, Max = 1, Default = 0.13, Suffix = "s", Decimals = 2, Flag = "PredictionVertical", Callback = function(Value)
    C.PredictionVertical = Value
end})

-- Resolver: differentiate real velocity from position history (beats
-- velocity spoofing), refreshed at the set rate while locked
PredictSection:Toggle({Name = "Resolver", Flag = "Resolver", Default = false, Callback = function(Value)
    C.Resolver = Value
end})

PredictSection:Slider({Name = "Resolver Rate", Min = 1, Max = 200, Default = 60, Suffix = "hz", Decimals = 1, Flag = "ResolverRate", Callback = function(Value)
    C.ResolverRate = Value
end})

-- Air Offset: extra lift when the target is airborne (Freefall)
PredictSection:Toggle({Name = "Air Offset", Flag = "AirOffset", Default = false, Callback = function(Value)
    C.AirOffset = Value
end})

PredictSection:Slider({Name = "Air Offset Amount", Min = -10, Max = 10, Default = 2, Suffix = " studs", Decimals = 1, Flag = "AirOffsetAmount", Callback = function(Value)
    C.AirOffsetAmount = Value
end})

-- Re-target Delay: cooldown after a lock drops before acquiring again
TriggerSection:Slider({Name = "Re-target Delay", Min = 0, Max = 2, Default = 0, Suffix = "s", Decimals = 2, Flag = "RetargetDelay", Callback = function(Value)
    C.RetargetDelay = Value
end})

-- Vertical smoothing (mouse aim mode only)
SmoothSection:Slider({Name = "Vertical Smoothing", Min = 1, Max = 100, Default = 10, Suffix = "x", Decimals = 1, Flag = "SmoothnessVertical", Callback = function(Value)
    C.SmoothnessVertical = Value
end})

local MiscSection = CombatTab:Section({Name = "Movement", Side = 2})

-- Velocity Spoof: what the server sees for your velocity (masking)
MiscSection:Toggle({Name = "Velocity Spoof", Flag = "SpoofVelocity", Default = false, Callback = function(Value)
    C.SpoofVelocity = Value
end})

MiscSection:Dropdown({Name = "Spoof Type", Flag = "SpoofType", Default = "Prediction Breaker", Items = {"Prediction Breaker", "Underground", "Sky"}, Callback = function(Value)
    C.SpoofType = Value
end})

MiscSection:Slider({Name = "Spoof Strength", Min = 50, Max = 2000, Default = 500, Suffix = " vel", Decimals = 1, Flag = "SpoofStrength", Callback = function(Value)
    C.SpoofStrength = Value
end})

-- Fake Lag: chop replication via NetworkIsSleeping (executor-gated)
MiscSection:Toggle({Name = "Fake Lag", Flag = "FakeLag", Default = false, Callback = function(Value)
    C.FakeLag = Value
end})

MiscSection:Slider({Name = "Lag Interval", Min = 0.05, Max = 1, Default = 0.2, Suffix = "s", Decimals = 2, Flag = "FakeLagInterval", Callback = function(Value)
    C.FakeLagInterval = Value
end})

-- Velocity Desync: randomize replicated velocity each tick, then restore
MiscSection:Toggle({Name = "Velocity Desync", Flag = "VelDesync", Default = false, Callback = function(Value)
    C.VelDesync = Value
end})

MiscSection:Slider({Name = "Velocity Range", Min = 1, Max = 10, Default = 2, Suffix = "k", Decimals = 1, Flag = "VelDesyncRange", Callback = function(Value)
    C.VelDesyncRange = Value
end})

MiscSection:Slider({Name = "Underground Depth", Min = 1, Max = 30, Default = 6, Suffix = " studs", Decimals = 1, Flag = "UndergroundDepth", Callback = function(Value)
    C.UndergroundDepth = Value
end})

MiscSection:Toggle({Name = "Anti Void", Flag = "AntiVoid", Default = true, Callback = function(Value)
    C.AntiVoid = Value
    applyAntiVoid(Value)
end})

-- Desync (csync-style): server replicates a flung/fake body while your
-- camera stays pinned to your real spot, then restores every tick
MiscSection:Toggle({Name = "Desync", Flag = "Desync", Default = false, Callback = function(Value)
    C.Desync = Value
end})

MiscSection:Dropdown({Name = "Desync Mode", Flag = "DesyncMode", Default = "Void", Items = {"Void", "Pulse", "Underground"}, Callback = function(Value)
    C.DesyncMode = Value
end})

MiscSection:Slider({Name = "Void Time", Min = 0.1, Max = 1, Default = 0.4, Suffix = "s", Decimals = 2, Flag = "VoidTime", Callback = function(Value)
    C.VoidTime = Value
end})

MiscSection:Slider({Name = "Normal Time", Min = 0.05, Max = 0.5, Default = 0.13, Suffix = "s", Decimals = 2, Flag = "NormalTime", Callback = function(Value)
    C.NormalTime = Value
end})

MiscSection:Toggle({Name = "Desync Ghost", Flag = "DesyncGhost", Default = true, Callback = function(Value)
    C.DesyncGhost = Value
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
end}):Colorpicker({Name = "Box Fill Color", Flag = "Box Fill Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.BoxFillColor = Value end
end})

ESPSection:Slider({Name = "Box Fill Opacity", Min = 0, Max = 100, Default = 30, Suffix = "%", Decimals = 1, Flag = "BoxFillOpacity", Callback = function(Value)
    C.BoxFillOpacity = Value
end})

ESPSection:Toggle({Name = "Team Colors", Flag = "TeamColors", Default = false, Callback = function(Value)
    C.TeamColors = Value
end})

HealthSection:Toggle({Name = "Health Bar", Flag = "HealthBar", Default = false, Callback = function(Value)
    C.HealthBar = Value
end})

HealthSection:Dropdown({Name = "Bar Position", Flag = "HealthBarPos", Default = "Left", Items = {"Left", "Top", "Right", "Bottom"}, Callback = function(Value)
    C.HealthBarPos = Value
end})

HealthSection:Toggle({Name = "Health Number", Flag = "HealthNumber", Default = false, Callback = function(Value)
    C.HealthNumber = Value
end})

TextSection:Toggle({Name = "Name ESP", Flag = "NameESP", Default = false, Callback = function(Value)
    C.NameESP = Value
end}):Colorpicker({Name = "Name Color", Flag = "Name Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.NameColor = Value end
end})

TextSection:Toggle({Name = "Distance ESP", Flag = "DistanceESP", Default = false, Callback = function(Value)
    C.DistanceESP = Value
end}):Colorpicker({Name = "Distance Color", Flag = "Distance Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.DistanceColor = Value end
end})

TracerSection:Toggle({Name = "ESP Tracer", Flag = "ESPTracer", Default = false, Callback = function(Value)
    C.ESPTracer = Value
end}):Colorpicker({Name = "ESP Tracer Color", Flag = "ESP Tracer Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.ESPTracerColor = Value end
end})

TracerSection:Dropdown({Name = "ESP Tracer Origin", Flag = "ESPTracerOrigin", Default = "Bottom", Items = {"Cursor", "Bottom", "Top"}, Callback = function(Value)
    C.ESPTracerOrigin = Value
end})

TracerSection:Slider({Name = "Tracer Thickness", Min = 1, Max = 5, Default = 1, Suffix = "px", Decimals = 1, Flag = "ESPTracerThickness", Callback = function(Value)
    C.ESPTracerThickness = Value
end})

TracerSection:Slider({Name = "Tracer Opacity", Min = 0, Max = 100, Default = 100, Suffix = "%", Decimals = 1, Flag = "ESPTracerOpacity", Callback = function(Value)
    C.ESPTracerOpacity = Value
end})

local CrossSection = VisualsTab:Section({Name = "Crosshair", Side = 2})
local FlySection = MovementTab:Section({Name = "Fly", Side = 1})
local SpeedSection = MovementTab:Section({Name = "Speed", Side = 2})
local JumpSection = MovementTab:Section({Name = "Jump", Side = 1})

FlySection:Toggle({Name = "Fly", Flag = "Fly", Default = false, Callback = function(Value)
    C.Fly = Value
    if flyGui then flyGui.Enabled = Value end
end})

FlySection:Slider({Name = "Fly Speed", Min = 10, Max = 200, Default = 60, Suffix = " studs/s", Decimals = 1, Flag = "FlySpeed", Callback = function(Value)
    C.FlySpeed = Value
end})

SpeedSection:Toggle({Name = "Speed", Flag = "Speed", Default = false, Callback = function(Value)
    C.Speed = Value
end})

SpeedSection:Slider({Name = "Speed Amount", Min = 0, Max = 200, Default = 40, Suffix = " studs/s", Decimals = 1, Flag = "SpeedAmount", Callback = function(Value)
    C.SpeedAmount = Value
end})

-- CFrame teleports work where velocity gets stripped; velocity (default)
-- rides physics and replicates naturally, so it draws less attention
SpeedSection:Toggle({Name = "CFrame Mode", Flag = "CFrameMode", Default = false, Callback = function(Value)
    C.CFrameMode = Value
end})

SpeedSection:Toggle({Name = "Noclip", Flag = "Noclip", Default = false, Callback = function(Value)
    C.Noclip = Value
    if Value then pcall(noclipStep) else pcall(unclip) end
end})

JumpSection:Toggle({Name = "Jump Power", Flag = "JumpPower", Default = false, Callback = function(Value)
    C.JumpPower = Value
end})

JumpSection:Slider({Name = "Jump Power Amount", Min = 0, Max = 300, Default = 50, Suffix = "", Decimals = 1, Flag = "JumpPowerAmount", Callback = function(Value)
    C.JumpPowerAmount = Value
end})

JumpSection:Toggle({Name = "Infinite Jump", Flag = "InfJump", Default = false, Callback = function(Value)
    C.InfJump = Value
end})

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

SkeletonSection:Toggle({Name = "Skeleton ESP", Flag = "Skeleton", Default = false, Callback = function(Value)
    C.Skeleton = Value
end}):Colorpicker({Name = "Skeleton Color", Flag = "Skeleton Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.SkeletonColor = Value end
end})

SkeletonSection:Slider({Name = "Skeleton Thickness", Min = 1, Max = 5, Default = 1, Suffix = "px", Decimals = 1, Flag = "SkeletonThickness", Callback = function(Value)
    C.SkeletonThickness = Value
end})

PerfSection:Slider({Name = "ESP Max Distance", Min = 0, Max = 2000, Default = 0, Suffix = " studs", Decimals = 1, Flag = "ESPMaxDistance", Callback = function(Value)
    C.ESPMaxDistance = Value
end})

PerfSection:Slider({Name = "ESP Smoothing", Min = 2, Max = 40, Default = 18, Suffix = "/s", Decimals = 1, Flag = "ESPSmoothing", Callback = function(Value)
    C.ESPSmoothing = Value
end})

SkeletonSection:Toggle({Name = "Head Dot", Flag = "HeadDot", Default = false, Callback = function(Value)
    C.HeadDot = Value
end}):Colorpicker({Name = "Head Color", Flag = "Dot Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.HeadDotColor = Value end
end})

SkeletonSection:Slider({Name = "Head Size", Min = 2, Max = 12, Default = 4, Suffix = "px", Decimals = 1, Flag = "HeadDotSize", Callback = function(Value)
    C.HeadDotSize = Value
end})

TextSection:Slider({Name = "Text Size", Min = 8, Max = 20, Default = 13, Suffix = "px", Decimals = 1, Flag = "ESPTextSize", Callback = function(Value)
    C.ESPTextSize = Value
end})

TextSection:Dropdown({Name = "Text Font", Flag = "ESPFont", Default = "UI", Items = {"UI", "System", "Plex", "Monospace"}, Callback = function(Value)
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
local LOCAL_MOUSE = LocalPlayer:GetMouse()

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

-- Resolver state: true velocity differentiated from position history.
local resolverPos = Vector3.new(0, 0, 0)
local resolverTick = 0
local resolverVel = Vector3.new(0, 0, 0)
local lockDroppedAt = nil

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
    -- Resolver: differentiate true velocity from position history while this
    -- target is held (immune to velocity spoofing), sampled at set rate.
    if C.Resolver and root then
        local now = os.clock()
        if resolverTick == 0 or (now - resolverTick) >= (1 / math.max(C.ResolverRate, 1)) then
            local dtR = now - resolverTick
            if dtR > 0 and resolverTick > 0 then
                resolverVel = (root.Position - resolverPos) / dtR
            end
            resolverTick, resolverPos = now, root.Position
        end
    else
        resolverTick = 0
    end

    -- Lead source priority: resolver > movement direction > raw velocity.
    -- Horizontal in studs along the direction, vertical as time on Y.
    local aimDir = nil
    if C.Resolver and resolverTick > 0 and resolverVel.Magnitude > 0.5 then
        aimDir = resolverVel.Unit
    else
        local md = hum and hum.MoveDirection
        if md and md.Magnitude > 0.1 then
            aimDir = md
        elseif velocity.Magnitude > 0.5 then
            aimDir = velocity.Unit
        end
    end
    local predictedPos = headPos
    if C.PredictionEnabled and C.Prediction > 0 and aimDir then
        local hDir = Vector3.new(aimDir.X, 0, aimDir.Z)
        if hDir.Magnitude > 0.05 then
            predictedPos += hDir.Unit * C.Prediction
        end
        local vy = (C.Resolver and resolverTick > 0) and resolverVel.Y or velocity.Y
        predictedPos += Vector3.new(0, vy * C.PredictionVertical, 0)
    end

    -- Air Offset: extra lift while the target is airborne (Freefall).
    if C.AirOffset and hum then
        local okS, st = pcall(function() return hum:GetState() end)
        if okS and st == Enum.HumanoidStateType.Freefall then
            predictedPos += Vector3.new(0, C.AirOffsetAmount, 0)
        end
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
        local divH = math.max(C.Smoothness, 1)
        local divV = math.max(C.SmoothnessVertical, 1)
        pcall(mousemoverel, (sp.X - anchor.X) / divH, (sp.Y - anchor.Y) / divV)
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
        if e.jd then for _, dot in ipairs(e.jd) do dot:Remove() end end
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
        if e.jd then for _, dot in ipairs(e.jd) do dot.Visible = false end end
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
            e.jd = {}
            for i = 1, 6 do
                local dot = Drawing.new("Circle")
                dot.Visible = false
                dot.Filled = true
                dot.Radius = 2
                e.jd[i] = dot
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
    -- Collect first, delete after: removing keys during pairs traversal is
    -- undefined behavior and can skip entries (leaking their drawings).
    do
        local gone = {}
        for player, _ in pairs(espCache) do
            if not Players:FindFirstChild(player.Name) then
                table.insert(gone, player)
            end
        end
        for _, player in ipairs(gone) do
            clearEspEntry(player)
        end
    end
    for _, player in ipairs(Players:GetPlayers()) do
        -- Same eligibility as aiming (respects Team Check), minus FOV/wall gates:
        -- ESP shows everyone on screen. Checked BEFORE creating drawings so
        -- invalid players never allocate an entry.
        if not isValidTarget(player) then
            local stale = espCache[player]
            if stale then hideEspEntry(stale) end
            continue
        end
        local e = getEspEntry(player)
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
        local k = 1 - math.exp(-math.max(C.ESPSmoothing, 1) * (dt or 0.016))
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
                e.hpNum.Color = C.HealthNumberColor
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
            e.text.Color = C.NameColor
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
                e.dist.Color = C.DistanceColor
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
            -- Joint dots over head/torso/hands/feet so the skeleton reads
            -- as a body instead of bare stick lines.
            local joints = {head, torso, la, ra, ll, rl}
            for i, part in ipairs(joints) do
                local dot = e.jd and e.jd[i]
                if dot and part then
                    local pp, po = cam:WorldToViewportPoint(part.Position)
                    if po then
                        dot.Visible = true
                        dot.Position = Vector2.new(pp.X, pp.Y)
                        dot.Radius = 2
                        dot.Color = C.SkeletonColor
                    else
                        dot.Visible = false
                    end
                elseif dot then
                    dot.Visible = false
                end
            end
        elseif e.sk then
            for _, ln in ipairs(e.sk) do ln.Visible = false end
            if e.jd then for _, dot in ipairs(e.jd) do dot.Visible = false end end
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

-- Shared RunService handle for the velocity spoof / fake lag loops below.
local RSVC = game:GetService("RunService")

-- Movement engine: velocity mode (default, replicates naturally) or CFrame
-- teleport mode. Refs re-fetched every tick so respawns just work.
onPhysicsStep(function(dt)
    pcall(function()
        if not (C.Fly or C.Speed or C.Noclip or C.JumpPower) and next(noclipOrig) == nil then return end
        local ch = LocalPlayer.Character
        local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
        local hum = ch and ch:FindFirstChildOfClass("Humanoid")
        if not ch or not hrp or not hum then return end
        if C.JumpPower then
            hum.UseJumpPower = true
            hum.JumpPower = C.JumpPowerAmount
        end
        if C.Noclip then
            noclipStep()
            -- Hover: phased-out body has no floor, so hold altitude instead
            -- of falling through the world (Ctrl/C or mobile down to sink)
            if not hum.Seated and not C.Fly then
                local vy = 0
                if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) or flyDownHeld then vy = -15 end
                local vv = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(vv.X, vy, vv.Z)
            end
        else
            unclip()
        end
        if hum.Seated then return end
        local md = hum.MoveDirection
        if C.Fly then
            local y = 0
            if UIS:IsKeyDown(Enum.KeyCode.Space) or UIS:IsKeyDown(Enum.KeyCode.E) or flyUpHeld then y = 1
            elseif UIS:IsKeyDown(Enum.KeyCode.Q) or UIS:IsKeyDown(Enum.KeyCode.LeftControl) or flyDownHeld then y = -1 end
            local dir = Vector3.new(md.X, y, md.Z)
            if dir.Magnitude > 1 then dir = dir.Unit end
            if C.CFrameMode then
                hrp.CFrame += dir * C.FlySpeed * (dt or 0.016)
            else
                hrp.AssemblyLinearVelocity = dir * C.FlySpeed
            end
        elseif C.Speed and md.Magnitude > 0.01 then
            if C.CFrameMode then
                hrp.CFrame += md * C.SpeedAmount * (dt or 0.016)
            else
                local v = hrp.AssemblyLinearVelocity
                hrp.AssemblyLinearVelocity = Vector3.new(md.X * C.SpeedAmount, v.Y, md.Z * C.SpeedAmount)
            end
        end
    end)
end)

-- Infinite Jump: single global connection, gated on the flag
UIS.JumpRequest:Connect(function()
    if not C.InfJump then return end
    local ch = LocalPlayer.Character
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if hum and not hum.Seated then
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end)
    end
end)


-- Triggerbot click: executor press first, held-tool fallback for touch.
-- Non-blocking (release is deferred) so the render loop never yields.
local triggerArmedAt = nil
local function triggerFire()
    if typeof(mouse1press) == "function" and typeof(mouse1release) == "function" then
        pcall(mouse1press)
        task.delay(0.05, function() pcall(mouse1release) end)
        return
    end
    local ch = LocalPlayer.Character
    local tool = ch and ch:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    end
end

local function resolveTriggerTarget()
    -- Never fire while dead: clicks accomplish nothing and look odd.
    local lchar = LocalPlayer.Character
    local lhum = lchar and lchar:FindFirstChildOfClass("Humanoid")
    if not lhum or lhum.Health <= 0 then return nil end
    local ok, hit = pcall(function() return LOCAL_MOUSE.Target end)
    if not ok or not hit then return nil end
    local model = hit:FindFirstAncestorOfClass("Model")
    if not model then return nil end
    local player = Players:GetPlayerFromCharacter(model)
    if not player or player == LocalPlayer then return nil end
    if not isValidTarget(player) then return nil end
    if C.TriggerLock and AIMBOT.Target ~= player then return nil end
    return player
end

-- Velocity Spoof: what the server sees for your velocity (masking).
-- Restored every tick so your client never feels it.
task.spawn(function()
    while true do
        if C.SpoofVelocity then
            local ch = LocalPlayer.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    local v = hrp.Velocity
                    local sv = v
                    if C.SpoofType == "Underground" then
                        sv = v + Vector3.new(0, -C.SpoofStrength, 0)
                    elseif C.SpoofType == "Sky" then
                        sv = v + Vector3.new(0, C.SpoofStrength, 0)
                    else
                        sv = Vector3.new(0, 0, 0)
                    end
                    local cf0 = hrp.CFrame
                    local t0 = os.clock()
                    hrp.Velocity = sv
                    RSVC.RenderStepped:Wait()
                    local dtw = math.max(os.clock() - t0, 0.0001)
                    hrp.Velocity = v
                    -- True csync restore: advance from the pre-spoof pose by
                    -- your REAL velocity only. Server got the fake packet;
                    -- your screen continues exactly as if spoof never ran.
                    hrp.CFrame = cf0 + v * dtw
                end)
            end
        else
            task.wait(0.05)
        end
    end
end)

-- Fake Lag: chop replication by sleeping network ownership on an interval.
-- Executor-gated (sethiddenproperty); refuses silently where missing.
task.spawn(function()
    local sleeping, lastFlip = false, 0
    while true do
        if C.FakeLag and typeof(sethiddenproperty) == "function" then
            local ch = LocalPlayer.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp and os.clock() - lastFlip >= C.FakeLagInterval then
                lastFlip = os.clock()
                sleeping = not sleeping
                pcall(sethiddenproperty, hrp, "NetworkIsSleeping", sleeping)
            end
        elseif sleeping then
            sleeping = false
            local ch = LocalPlayer.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then pcall(sethiddenproperty, hrp, "NetworkIsSleeping", false) end
        end
        task.wait(0.03)
    end
end)

-- Velocity Desync: randomize replicated velocity each tick, then restore.
-- Breaks enemy prediction against you.
task.spawn(function()
    while true do
        if C.VelDesync then
            local ch = LocalPlayer.Character
            local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
            if hrp then
                pcall(function()
                    local v = hrp.Velocity
                    local a = math.floor(C.VelDesyncRange * 1000)
                    local rv = Vector3.new(math.random(-a, a), math.random(-a, a), math.random(-a, a))
                    local cf0 = hrp.CFrame
                    local t0 = os.clock()
                    hrp.Velocity = rv
                    RSVC.RenderStepped:Wait()
                    local dtw = math.max(os.clock() - t0, 0.0001)
                    hrp.Velocity = v
                    hrp.CFrame = cf0 + v * dtw
                end)
            end
        else
            task.wait(0.05)
        end
    end
end)

-- Anti Void: NaN kill-height disables local fall destruction (server keeps
-- its own). Applied on launch, on respawn, and every tick while desync runs.
local function applyAntiVoid(on)
    pcall(function()
        workspace.FallenPartsDestroyHeight = on and (-0 / 0) or -500
    end)
end
applyAntiVoid(C.AntiVoid)

LocalPlayer.CharacterAdded:Connect(function()
    if C.AntiVoid then applyAntiVoid(true) end
end)

-- Desync engine (csync pattern): each tick saves the real CFrame, teleports
-- the body to the fake target (the SERVER replicates that), pins the camera
-- to a setback part at the real spot, waits a render step, then restores.
-- A neon ghost shows the server-side body. All client-created visuals only.
local desyncSetback = nil
local desyncGhostFolder = nil
local desyncGhosts = {}
local desyncTimer = 0
local desyncVoidPhase = true
local desyncPhaseT = 0
local desyncWasOn = false

pcall(function()
    desyncSetback = Instance.new("Part")
    desyncSetback.Name = "syncaDesyncSetback"
    desyncSetback.Size = Vector3.new(2, 2, 1)
    desyncSetback.Anchored = true
    desyncSetback.CanCollide = false
    desyncSetback.CanQuery = false
    desyncSetback.CanTouch = false
    desyncSetback.Transparency = 1
    desyncSetback.CFrame = CFrame.new(0, -2000, 0)
    desyncSetback.Parent = workspace
end)

local function desyncClearGhost()
    if desyncGhostFolder then pcall(function() desyncGhostFolder:Destroy() end) end
    desyncGhostFolder = nil
    desyncGhosts = {}
end

local function desyncBuildGhost()
    desyncClearGhost()
    local ch = LocalPlayer.Character
    local root = ch and ch:FindFirstChild("HumanoidRootPart")
    if not ch or not root then return end
    local ok, folder = pcall(function()
        local f = Instance.new("Folder")
        f.Name = "syncaGhost"
        f.Parent = workspace
        return f
    end)
    if not ok or not folder then return end
    desyncGhostFolder = folder
    for _, p in ipairs(ch:GetChildren()) do
        if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
            local okg, ghost = pcall(function()
                local g = Instance.new("Part")
                g.Size = p.Size
                g.Anchored = true
                g.CanCollide = false
                g.CanQuery = false
                g.CanTouch = false
                g.CastShadow = false
                g.Material = Enum.Material.Neon
                g.Color = Color3.fromRGB(0, 140, 255)
                g.Transparency = 0.5
                g.TopSurface = Enum.SurfaceType.Smooth
                g.BottomSurface = Enum.SurfaceType.Smooth
                g.Parent = folder
                return g
            end)
            if okg and ghost then
                desyncGhosts[p] = { part = ghost, offset = root.CFrame:Inverse() * p.CFrame }
            end
        end
    end
end

LocalPlayer.CharacterAdded:Connect(function()
    desyncClearGhost()
    desyncTimer, desyncPhaseT = 0, 0
    desyncVoidPhase = true
    if C.Desync and C.DesyncGhost then
        task.delay(0.15, function()
            if C.Desync then desyncBuildGhost() end
        end)
    end
end)

RSVC.Heartbeat:Connect(function()
    if not C.Desync then
        if desyncWasOn then
            desyncWasOn = false
            pcall(function()
                local cam = workspace.CurrentCamera
                local ch = LocalPlayer.Character
                local hum = ch and ch:FindFirstChildOfClass("Humanoid")
                if cam and hum then cam.CameraSubject = hum end
            end)
            if desyncSetback then desyncSetback.CFrame = CFrame.new(0, -2000, 0) end
            desyncClearGhost()
            desyncTimer, desyncPhaseT = 0, 0
            desyncVoidPhase = true
        end
        return
    end
    desyncWasOn = true
    pcall(function()
        local ch = LocalPlayer.Character
        if not ch then return end
        local root = ch:FindFirstChild("HumanoidRootPart")
        if not root then return end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if C.DesyncGhost and not desyncGhostFolder then desyncBuildGhost() end
        local old = root.CFrame
        local target = old
        if C.DesyncMode == "Void" then
            target = CFrame.new(old.Position + Vector3.new(math.random(-900000000, 900000000), math.random(100000000, 900000000), math.random(-900000000, 900000000)))
        elseif C.DesyncMode == "Pulse" then
            local now = os.clock()
            if desyncPhaseT == 0 then desyncPhaseT = now desyncVoidPhase = true end
            if desyncVoidPhase then
                if now - desyncPhaseT >= C.VoidTime then desyncVoidPhase = false desyncPhaseT = now end
            elseif now - desyncPhaseT >= C.NormalTime then
                desyncVoidPhase = true desyncPhaseT = now
            end
            if desyncVoidPhase then
                target = CFrame.new(old.Position + Vector3.new(math.random(-900000000, 900000000), math.random(100000000, 900000000), math.random(-900000000, 900000000)))
            end
        else -- Underground: configurable depth down, pitched flat
            target = CFrame.new(old.Position - Vector3.new(0, C.UndergroundDepth, 0)) * CFrame.Angles(math.pi / 2, 0, 0)
        end
        if C.AntiVoid or C.Desync then applyAntiVoid(true) end
        root.CFrame = target
        if desyncSetback then
            -- +1.5Y: a Part subject frames lower than a Humanoid one does
            desyncSetback.CFrame = old + Vector3.new(0, 1.5, 0)
            local cam = workspace.CurrentCamera
            if cam and hum then cam.CameraSubject = desyncSetback end
        end
        if C.DesyncGhost then
            local dead = {}
            for real, data in pairs(desyncGhosts) do
                if not real.Parent or not data.part or not data.part.Parent then
                    table.insert(dead, real)
                else
                    data.part.CFrame = target * data.offset
                end
            end
            for _, real in ipairs(dead) do desyncGhosts[real] = nil end
        end
        RSVC.RenderStepped:Wait()
        root.CFrame = old
        if desyncSetback then desyncSetback.CFrame = CFrame.new(0, -2000, 0) end
        local cam2 = workspace.CurrentCamera
        if cam2 and hum then cam2.CameraSubject = hum end
    end)
end)

-- Main render loop (wrapped so one bad frame never kills the aimbot)
game:GetService("RunService").RenderStepped:Connect(function(dt)
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local anchor = getFovCenter()
        fovCircle.Position = anchor
        fovCircle.Radius = C.FOVSize
        fovCircle.Transparency = C.FOVOpacity / 100
        fovCircle.Thickness = C.FOVThickness
        -- Fill sits just inside the ring stroke so the ring stays crisp, and
        -- supports rainbow cycling plus a breathing pulse animation
        local fillColor = C.FOVFillColor
        if C.FillRainbow then
            fillColor = Color3.fromHSV((os.clock() % C.RainbowSpeed) / C.RainbowSpeed, 1, 1)
        end
        local fillOp = C.FOVFillOpacity / 100
        if C.FillPulse then
            fillOp *= (0.55 + 0.45 * math.sin(os.clock() * 4))
        end
        fovFill.Position = anchor
        fovFill.Radius = math.max(C.FOVSize - C.FOVThickness / 2, 1)
        fovFill.Color = fillColor
        fovFill.Transparency = fillOp

        -- Update FOV visualization (follows the FOV switch so the circle can
        -- be sized/positioned before the aimbot itself is enabled)
        local outlineColor = C.OutlineColor
        if C.OutlineRainbow then
            outlineColor = Color3.fromHSV((os.clock() % C.RainbowSpeed) / C.RainbowSpeed, 1, 1)
        end
        fovOutline.Position = anchor
        fovOutline.Radius = C.FOVSize
        fovOutline.Thickness = C.FOVThickness + 2
        fovOutline.Color = outlineColor
        fovOutline.Transparency = C.OutlineOpacity / 100
        fovCircle.Visible = C.FOV
        fovFill.Visible = C.FOV and C.FOVFilled
        fovOutline.Visible = C.FOV and C.FOVOutline

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
                AIMBOT.Lock = nil
                if C.RetargetDelay > 0 then
                    if lockDroppedAt == nil then lockDroppedAt = os.clock() end
                    if os.clock() - lockDroppedAt >= C.RetargetDelay then
                        AIMBOT.Lock = findClosestTarget()
                        lockDroppedAt = nil
                    end
                else
                    AIMBOT.Lock = findClosestTarget()
                end
            else
                lockDroppedAt = nil
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
            lockDroppedAt = nil
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

        -- Target Dot on the locked aim point
        if C.TargetDot and AIMBOT.Target then
            local dp, _ = getAimPart(AIMBOT.Target)
            if dp then
                local dsp, dson = cam:WorldToViewportPoint(dp)
                if dson and lockDot then
                    lockDot.Visible = true
                    lockDot.Position = Vector2.new(dsp.X, dsp.Y)
                    lockDot.Radius = C.TargetDotSize
                    lockDot.Filled = C.TargetDotFilled
                    lockDot.Color = C.LockedColor
                elseif lockDot then
                    lockDot.Visible = false
                end
            elseif lockDot then
                lockDot.Visible = false
            end
        elseif lockDot then
            lockDot.Visible = false
        end

        -- Triggerbot: arm while the cursor rests on a valid enemy, fire once
        -- the delay elapses. Re-arms per shot; gated on the master switch.
        if C.Triggerbot and C.Enable then
            if resolveTriggerTarget() then
                if triggerArmedAt == nil then triggerArmedAt = os.clock() end
                if os.clock() - triggerArmedAt >= C.TriggerDelay then
                    triggerArmedAt = nil
                    triggerFire()
                end
            else
                triggerArmedAt = nil
            end
        else
            triggerArmedAt = nil
        end
    end)
end)

-- Init library (loads autoload config)
Library:Init()

-- Load notification
Library:Notification("Aimbot loaded", 5, Library.Theme.Accent, {"rbxassetid://135757045959142", Color3.fromRGB(149, 255, 139)})
