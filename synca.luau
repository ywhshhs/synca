--[[
	Universal Aimbot Script
	Built with Bitch Bot GUI Framework
	Features: Team Check, FOV Circle, Wall Check, Smoothness, Prediction
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local InputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LOCAL_PLAYER = Players.LocalPlayer
local LOCAL_CHARACTER = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
local LOCAL_MOUSE = LOCAL_PLAYER:GetMouse()

-- Aim Bot Configuration
local AIMBOT = {
	Enabled = false,
	TeamCheck = false,
	FOVEnabled = false,
	FOVSize = 100,
	WallCheck = false,
	Smoothness = 10,
	Prediction = 5,
	Target = nil,
	TargetPart = nil,
}

-- Drawing objects for FOV visualization
local fovCircle = Drawing.new("Circle")
fovCircle.Visible = false
fovCircle.Thickness = 2
fovCircle.Color = Color3.fromRGB(127, 72, 163)
fovCircle.Transparency = 0.4
fovCircle.Filled = false
fovCircle.Radius = AIMBOT.FOVSize

-- Team Check Helper
local function getTeam(player)
	if not player or not player.Team then return nil end
	return player.Team.TeamId
end

local function isTeamMate(player)
	if not AIMBOT.TeamCheck then return false end
	if not player or not player.Team then return false end
	if not LOCAL_PLAYER.Team then return false end
	return getTeam(player) == getTeam(LOCAL_PLAYER)
end

local function isValidTarget(player)
	if not player then return false end
	if player == LOCAL_PLAYER then return false end
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
	if not AIMBOT.WallCheck then return true end
	local cameraPos = Camera.CFrame.Position
	local direction = targetPos - cameraPos
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {LOCAL_CHARACTER}
	local result = workspace:Raycast(cameraPos, direction, rayParams)
	if result then return false end
	return true
end

local function isInFOV(targetPos)
	if not AIMBOT.FOVEnabled then return true end
	local screenPos, onScreen = Camera:WorldToViewportPoint(targetPos)
	if not onScreen then return false end
	local centerX = Camera.ViewportSize.X / 2
	local centerY = Camera.ViewportSize.Y / 2
	local distance = math.sqrt((screenPos.X - centerX)^2 + (screenPos.Y - centerY)^2)
	return distance <= AIMBOT.FOVSize
end

local function findClosestTarget()
	local closest = nil
	local closestDist = math.huge
	for _, player in pairs(Players:GetPlayers()) do
		if not isValidTarget(player) then continue end
		local headPos = getHeadInfo(player)
		if not headPos then continue end
		local pos = headPos[1]
		if not isInFOV(pos) then continue end
		if not canSeeTarget(pos) then continue end
		local dist = (Camera.CFrame.Position - pos).Magnitude
		if dist < closestDist then
			closestDist = dist
			closest = player
			AIMBOT.TargetPart = headPos[2]
		end
	end
	return closest
end

local function predictPosition(position, velocity)
	local predicted = position + (velocity * AIMBOT.Prediction)
	return predicted
end

local function executeAim(target)
	local headPos, headPart = getHeadInfo(target)
	if not headPos then return end

	-- Get velocity for prediction
	local velocity = Vector3.new(0, 0, 0)
	local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if root and root.Velocity then
		velocity = root.Velocity
	end

	-- Prediction: aim half studs forward based on velocity direction
	local lookDir = velocity.Magnitude > 0 and velocity.Unit or Camera.CFrame.LookVector
	local predictedPos = headPos + (lookDir * AIMBOT.Prediction)

	-- Smooth interpolation
	local targetCF = CFrame.lookAt(Camera.CFrame.Position, predictedPos)
	if AIMBOT.Smoothness > 0 then
		local alpha = math.clamp(AIMBOT.Smoothness * 0.016, 0, 0.15)
		Camera.CFrame = Camera.CFrame:Lerp(targetCF, alpha)
	else
		Camera.CFrame = targetCF
	end
end

-- Render loop
RunService.RenderStepped:Connect(function(dt)
	local screenCenter = Camera.ViewportSize / 2
	fovCircle.Position = Vector2.new(screenCenter.X, screenCenter.Y)
	fovCircle.Radius = AIMBOT.FOVSize
	fovCircle.Visible = AIMBOT.FOVEnabled and AIMBOT.Enabled

	if AIMBOT.Enabled then
		local target = findClosestTarget()
		if target then
			AIMBOT.Target = target
			executeAim(target)
		else
			AIMBOT.Target = nil
			AIMBOT.TargetPart = nil
		end
	end
end)

-- Toggle with DELETE key
InputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Delete then
		AIMBOT.Enabled = not AIMBOT.Enabled
	end
end)

-- Save/Load config support for Bitch Bot framework
local function saveConfig(data)
	return {
		Enabled = AIMBOT.Enabled,
		TeamCheck = AIMBOT.TeamCheck,
		FOVEnabled = AIMBOT.FOVEnabled,
		FOVSize = AIMBOT.FOVSize,
		WallCheck = AIMBOT.WallCheck,
		Smoothness = AIMBOT.Smoothness,
		Prediction = AIMBOT.Prediction,
	}
end

local function loadConfig(data)
	if data then
		AIMBOT.Enabled = data.Enabled or false
		AIMBOT.TeamCheck = data.TeamCheck or false
		AIMBOT.FOVEnabled = data.FOVEnabled or false
		AIMBOT.FOVSize = data.FOVSize or 100
		AIMBOT.WallCheck = data.WallCheck or false
		AIMBOT.Smoothness = data.Smoothness or 10
		AIMBOT.Prediction = data.Prediction or 5
	end
end

-- Return module for integration
return {
	Config = AIMBOT,
	Save = saveConfig,
	Load = loadConfig,
	GetTarget = function() return AIMBOT.Target end,
	IsEnabled = function() return AIMBOT.Enabled end,
}
