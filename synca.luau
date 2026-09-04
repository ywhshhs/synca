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
    WallCheck = false,
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
local SettingsTab = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- Sections
local AimbotSection = CombatTab:Section({Name = "Aimbot", Side = 1})
local AdvancedSection = CombatTab:Section({Name = "Advanced", Side = 2})
local VisualsSection = CombatTab:Section({Name = "Visuals", Side = 1})

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
VisualsSection:Toggle({Name = "Target Tracer", Flag = "Tracer", Default = false, Callback = function(Value)
    C.Tracer = Value
end}):Colorpicker({Name = "Tracer Color", Flag = "Tracer Color", Default = Color3.fromRGB(166, 147, 243), Callback = function(Value, Alpha)
    if tracerLine and typeof(Value) == "Color3" then
        tracerLine.Color = Value
    end
end})

VisualsSection:Dropdown({Name = "Tracer Origin", Flag = "TracerOrigin", Default = "Cursor", Items = {"Cursor", "Bottom", "Top"}, Callback = function(Value)
    C.TracerOrigin = Value
end})

-- Full ESP suite (everyone passing the Team Check filter)
VisualsSection:Toggle({Name = "ESP Highlight", Flag = "ESPHighlight", Default = false, Callback = function(Value)
    C.ESPHighlight = Value
end}):Colorpicker({Name = "ESP Color", Flag = "ESP Color", Default = Color3.fromRGB(170, 140, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.ESPHighlightColor = Value end
end})

VisualsSection:Slider({Name = "ESP Opacity", Min = 0, Max = 100, Default = 50, Suffix = "%", Decimals = 1, Flag = "ESPHighlightOpacity", Callback = function(Value)
    C.ESPHighlightOpacity = Value
end})

VisualsSection:Toggle({Name = "Box ESP", Flag = "BoxESP", Default = false, Callback = function(Value)
    C.BoxESP = Value
end}):Colorpicker({Name = "Box Color", Flag = "Box Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.BoxColor = Value end
end})

VisualsSection:Toggle({Name = "Health Bar", Flag = "HealthBar", Default = false, Callback = function(Value)
    C.HealthBar = Value
end})

VisualsSection:Toggle({Name = "Name ESP", Flag = "NameESP", Default = false, Callback = function(Value)
    C.NameESP = Value
end})

VisualsSection:Toggle({Name = "Distance ESP", Flag = "DistanceESP", Default = false, Callback = function(Value)
    C.DistanceESP = Value
end})

VisualsSection:Toggle({Name = "ESP Tracer", Flag = "ESPTracer", Default = false, Callback = function(Value)
    C.ESPTracer = Value
end}):Colorpicker({Name = "ESP Tracer Color", Flag = "ESP Tracer Color", Default = Color3.fromRGB(255, 255, 255), Callback = function(Value, Alpha)
    if typeof(Value) == "Color3" then C.ESPTracerColor = Value end
end})

VisualsSection:Dropdown({Name = "ESP Tracer Origin", Flag = "ESPTracerOrigin", Default = "Bottom", Items = {"Cursor", "Bottom", "Top"}, Callback = function(Value)
    C.ESPTracerOrigin = Value
end})

-- Aim Bot State
local AIMBOT = {
    Target = nil,
    TargetPart = nil,
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

local function executeAim(target)
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

    -- Higher smoothness = slower glide, 1 = instant snap.
    local alpha = math.clamp(1 / math.max(C.Smoothness, 1), 0, 1)
    cam.CFrame = cam.CFrame:Lerp(targetCF, alpha)
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
        if e.tracer then e.tracer:Remove() end
        if e.hl then e.hl:Destroy() end
    end)
end

local function hideEspEntry(e)
    pcall(function()
        if e.box then e.box.Visible = false end
        if e.hpBg then e.hpBg.Visible = false end
        if e.hp then e.hp.Visible = false end
        if e.text then e.text.Visible = false end
        if e.tracer then e.tracer.Visible = false end
        if e.hl then e.hl.Enabled = false end
    end)
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
            e.tracer = Drawing.new("Line")
            e.tracer.Visible = false
            e.tracer.Thickness = 1
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

local function updateESP()
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
        local w, h = maxX - minX, maxY - minY
        local cx = (minX + maxX) / 2
        if C.BoxESP and e.box then
            e.box.Visible = true
            e.box.Position = Vector2.new(minX, minY)
            e.box.Size = Vector2.new(w, h)
            e.box.Color = C.BoxColor
        elseif e.box then
            e.box.Visible = false
        end
        if C.HealthBar and e.hpBg and e.hp then
            local hum = char:FindFirstChildOfClass("Humanoid")
            local frac = 0
            if hum and hum.MaxHealth > 0 then
                frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
            end
            local bx = minX - 5
            e.hpBg.Visible = true
            e.hpBg.From = Vector2.new(bx, maxY)
            e.hpBg.To = Vector2.new(bx, minY)
            e.hpBg.Color = Color3.fromRGB(0, 0, 0)
            e.hp.Visible = true
            e.hp.From = Vector2.new(bx, maxY)
            e.hp.To = Vector2.new(bx, maxY - h * frac)
            e.hp.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0)
        else
            if e.hpBg then e.hpBg.Visible = false end
            if e.hp then e.hp.Visible = false end
        end
        if e.text then
            local parts = {}
            if C.NameESP then table.insert(parts, player.Name) end
            if C.DistanceESP then
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local d = math.floor((cam.CFrame.Position - hrp.Position).Magnitude)
                    table.insert(parts, "[" .. d .. "m]")
                end
            end
            if #parts > 0 then
                e.text.Visible = true
                e.text.Text = table.concat(parts, "  ")
                e.text.Position = Vector2.new(cx, minY - 16)
                e.text.Color = Color3.fromRGB(255, 255, 255)
            else
                e.text.Visible = false
            end
        end
        if C.ESPTracer and e.tracer then
            e.tracer.Visible = true
            e.tracer.From = espTracerOrigin(cam)
            e.tracer.To = Vector2.new(cx, maxY)
            e.tracer.Color = C.ESPTracerColor
        elseif e.tracer then
            e.tracer.Visible = false
        end
    end
end

Players.PlayerRemoving:Connect(function(player)
    clearEspEntry(player)
end)

-- Main render loop (wrapped so one bad frame never kills the aimbot)
game:GetService("RunService").RenderStepped:Connect(function(dt)
    pcall(function()
        local cam = workspace.CurrentCamera
        if not cam then return end
        local anchor = getFovCenter()
        fovCircle.Position = anchor
        fovCircle.Radius = C.FOVSize

        -- Update FOV visualization (follows the master Enable switch)
        fovCircle.Visible = C.FOV and C.Enable
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
        updateESP()

        -- Enable is the master switch: nothing aims while it is off.
        -- AutoTarget only selects auto-acquire style, it never forces Enable.
        if C.Enable and C.AutoTarget then
            local target = findClosestTarget()
            if target then
                AIMBOT.Target = target
                local _, part = getAimPart(target)
                AIMBOT.TargetPart = part
                executeAim(target)
            else
                AIMBOT.Target = nil
                AIMBOT.TargetPart = nil
            end
        elseif C.Enable then
            -- Manual mode
            local target = findClosestTarget()
            if target then
                AIMBOT.Target = target
                local _, part = getAimPart(target)
                AIMBOT.TargetPart = part
                executeAim(target)
            else
                AIMBOT.Target = nil
                AIMBOT.TargetPart = nil
            end
        else
            AIMBOT.Target = nil
            AIMBOT.TargetPart = nil
        end
    end)
end)

-- Init library (loads autoload config)
Library:Init()

-- Load notification
Library:Notification("Aimbot loaded", 5, Library.Theme.Accent, {"rbxassetid://135757045959142", Color3.fromRGB(149, 255, 139)})
