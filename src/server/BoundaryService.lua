--!strict
-- Static containment plus low-frequency, server-owned fall recovery.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Palette = require(Shared.Palette)

local PlayerService = require(script.Parent.PlayerService)

local BoundaryService = {}

local feedback: RemoteEvent
local pollElapsed = 0
local sampleElapsed = 0

local function region(name: string): any
	return if name == "Ruin" then Config.World.Ruin else Config.World.City
end

function BoundaryService.areaForPlayer(player: Player): string
	local state = PlayerService.get(player)
	return if state and state.inRuin then "Ruin" else "City"
end

function BoundaryService.contains(areaName: string, position: Vector3, inset: number?): boolean
	local bounds = region(areaName)
	local margin = inset or 0
	return math.abs(position.X - bounds.Center.X) <= bounds.HalfSize.X - margin
		and math.abs(position.Z - bounds.Center.Z) <= bounds.HalfSize.Z - margin
		and position.Y >= bounds.FallY
end


local function insideXZ(areaName: string, position: Vector3, inset: number?): boolean
	local bounds = region(areaName)
	local margin = inset or 0
	return math.abs(position.X - bounds.Center.X) <= bounds.HalfSize.X - margin
		and math.abs(position.Z - bounds.Center.Z) <= bounds.HalfSize.Z - margin
end


function BoundaryService.clampDestination(areaName: string, position: Vector3, clearance: number): Vector3
	local bounds = region(areaName)
	return Vector3.new(
		math.clamp(position.X, bounds.Center.X - bounds.HalfSize.X + clearance, bounds.Center.X + bounds.HalfSize.X - clearance),
		position.Y,
		math.clamp(position.Z, bounds.Center.Z - bounds.HalfSize.Z + clearance, bounds.Center.Z + bounds.HalfSize.Z - clearance)
	)
end

local function boundaryPart(parent: Instance, name: string, size: Vector3, position: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Transparency = if Config.World.ShowBoundaries then 0.72 else 1
	part.Color = Palette.Energy.Cyan
	part.Material = if Config.World.ShowBoundaries then Enum.Material.ForceField else Enum.Material.SmoothPlastic
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.CollisionGroup = "Default"
	part:SetAttribute("DevelopmentBoundary", true)
	part.Parent = parent
	return part
end

local function buildWalls(parent: Instance, areaName: string)
	local bounds = region(areaName)
	local folder = Instance.new("Folder")
	folder.Name = areaName
	folder.Parent = parent
	local thickness = 8
	local lengthX = bounds.HalfSize.X * 2 + thickness * 2
	local lengthZ = bounds.HalfSize.Z * 2 + thickness * 2
	local centerY = bounds.Center.Y
	local height = bounds.HalfSize.Y * 2
	boundaryPart(folder, "NorthWall", Vector3.new(lengthX, height, thickness), Vector3.new(bounds.Center.X, centerY, bounds.Center.Z - bounds.HalfSize.Z - thickness / 2))
	boundaryPart(folder, "SouthWall", Vector3.new(lengthX, height, thickness), Vector3.new(bounds.Center.X, centerY, bounds.Center.Z + bounds.HalfSize.Z + thickness / 2))
	boundaryPart(folder, "WestWall", Vector3.new(thickness, height, lengthZ), Vector3.new(bounds.Center.X - bounds.HalfSize.X - thickness / 2, centerY, bounds.Center.Z))
	boundaryPart(folder, "EastWall", Vector3.new(thickness, height, lengthZ), Vector3.new(bounds.Center.X + bounds.HalfSize.X + thickness / 2, centerY, bounds.Center.Z))
end

local function sceneryPart(parent: Instance, name: string, size: Vector3, cframe: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = Palette.City.Rubble
	part.Material = Palette.Material.Rubble
	part.CanCollide = true
	part.CanTouch = false
	part.CastShadow = true
	part.Parent = parent
	return part
end

local function buildCityEdgeScenery(parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "BoundaryScenery"
	folder.Parent = parent
	for _, spec in {
		{ at = Vector3.new(0, 7, -171), yaw = 0 },
		{ at = Vector3.new(0, 7, 171), yaw = 0 },
		{ at = Vector3.new(-171, 7, 0), yaw = math.rad(90) },
		{ at = Vector3.new(171, 7, 0), yaw = math.rad(90) },
	} do
		for index = -2, 2 do
			local localOffset = CFrame.Angles(0, spec.yaw, 0) * CFrame.new(index * 8, math.abs(index) * 0.8, 0)
			sceneryPart(folder, "CollapsedGate", Vector3.new(9, 11 + math.abs(index) * 2, 7), CFrame.new(spec.at) * localOffset * CFrame.Angles(math.rad(index * 4), 0, math.rad(index * 7)))
		end
	end
end

function BoundaryService.build(parent: Instance): Folder
	local old = parent:FindFirstChild("PlayableBoundaries")
	if old then old:Destroy() end
	local folder = Instance.new("Folder")
	folder.Name = "PlayableBoundaries"
	folder:SetAttribute("ShowInDevelopment", Config.World.ShowBoundaries)
	folder.Parent = parent
	buildWalls(folder, "City")
	buildWalls(folder, "Ruin")
	buildCityEdgeScenery(folder)
	return folder
end

local function clearVelocity(character: Model)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.AssemblyLinearVelocity = Vector3.zero
			descendant.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

local function groundedSafe(player: Player, areaName: string)
	local state = PlayerService.get(player)
	local character = state and state.character
	local humanoid = state and state.humanoid
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not state or not character or not humanoid or not root or humanoid.Health <= 0 then return end
	if humanoid.FloorMaterial == Enum.Material.Air or math.abs(root.AssemblyLinearVelocity.Y) > 4 then return end
	if not insideXZ(areaName, root.Position, 12) then return end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { character }
	rayParams.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), rayParams)
	if not hit or not hit.Instance.CanCollide then return end
	state.safeCFrame = CFrame.lookAt(root.Position, root.Position + root.CFrame.LookVector)
	state.lastSafeAt = os.clock()
end

local function recover(player: Player, areaName: string)
	local state = PlayerService.get(player)
	local character = state and state.character
	local humanoid = state and state.humanoid
	if not state or state.recovering or not character or not humanoid or humanoid.Health <= 0 then return end
	state.recovering = true
	PlayerService.cancelTransient(player, "recovery")
	local target = state.safeCFrame or state.checkpoint or region(areaName).SafeFallback
	local clearance = if PlayerService.isTransformed(player) then 10 else 5
	local safePosition = BoundaryService.clampDestination(areaName, target.Position, clearance)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { character }
	overlap.RespectCanCollide = true
	local boxSize = if PlayerService.isTransformed(player) then Vector3.new(9, 13, 9) else Vector3.new(4, 7, 4)
	local function obstructed(position: Vector3): boolean
		for _, part in workspace:GetPartBoundsInBox(CFrame.new(position + Vector3.new(0, boxSize.Y * 0.35, 0)), boxSize, overlap) do
			if part.CanCollide then return true end
		end
		return false
	end
	if obstructed(safePosition) then
		target = region(areaName).SafeFallback
		safePosition = BoundaryService.clampDestination(areaName, target.Position, clearance)
	end
	character:PivotTo(CFrame.lookAt(safePosition, safePosition + target.LookVector))
	clearVelocity(character)
	feedback:FireClient(player, Net.Feedback.Notice, { text = "Returned to safe ground", priority = 3 })
	task.delay(Config.World.RecoveryDebounceSeconds, function()
		local current = PlayerService.get(player)
		if current then current.recovering = false end
	end)
end

local function inspectPlayers(sampleSafe: boolean)
	for _, player in Players:GetPlayers() do
		local state = PlayerService.get(player)
		local character = state and state.character
		local humanoid = state and state.humanoid
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not state or not humanoid or not root or humanoid.Health <= 0 then continue end
		local areaName = if state.inRuin then "Ruin" else "City"
		local bounds = region(areaName)
		if root.Position.Y < bounds.FallY or not insideXZ(areaName, root.Position, -8) then
			recover(player, areaName)
		elseif sampleSafe then
			groundedSafe(player, areaName)
		end
	end
end

function BoundaryService.keepEnemyInRuin(model: Model, fallback: Vector3)
	local root = model.PrimaryPart
	if not root then return end
	if root.Position.Y < Config.World.Ruin.FallY or not insideXZ("Ruin", root.Position, 3) then
		local position = BoundaryService.clampDestination("Ruin", fallback, 8)
		model:PivotTo(CFrame.new(position))
		clearVelocity(model)
	end
end

function BoundaryService.init()
	feedback = Net.get("Feedback")
	RunService.Heartbeat:Connect(function(dt)
		pollElapsed += dt
		sampleElapsed += dt
		if pollElapsed < Config.World.RecoveryPollSeconds then return end
		pollElapsed = 0
		local sampleSafe = sampleElapsed >= Config.World.SafeSampleSeconds
		if sampleSafe then sampleElapsed = 0 end
		inspectPlayers(sampleSafe)
	end)
end

return BoundaryService
