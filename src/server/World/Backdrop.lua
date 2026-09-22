--!strict
-- Low-cost scenery outside the collision perimeter.  It hides the cut edge of
-- the playable district without creating another playable map.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local Kit = require(script.Parent.Kit)

local Backdrop = {}

local function mass(folder: Instance, name: string, at: Vector3, size: Vector3, color: Color3)
	Kit.part({ name = name, size = size, cframe = CFrame.new(at), color = color, material = Palette.Material.Concrete, decor = true, castShadow = false, parent = folder })
end

function Backdrop.build(parent: Instance)
	local root = Kit.folder("HopeBackdrop", parent)
	local near = Kit.folder("NearBoundary", root)
	local middle = Kit.folder("MiddleDistance", root)
	local horizon = Kit.folder("DistantHorizon", root)
	local ground = Kit.folder("GroundContinuity", root)
	local facade = Palette.City.Facade[1]
	-- Intentional outer ground, segmented at the perimeter rather than a default plate.
	mass(ground, "OuterGroundNorth", Vector3.new(0, -3.6, -300), Vector3.new(620, 6, 190), Palette.City.Earth)
	mass(ground, "OuterGroundSouth", Vector3.new(0, -3.6, 300), Vector3.new(620, 6, 190), Palette.City.Earth)
	mass(ground, "OuterGroundEast", Vector3.new(300, -3.6, 0), Vector3.new(190, 6, 220), Palette.City.Earth)
	mass(ground, "OuterGroundWest", Vector3.new(-300, -3.6, 0), Vector3.new(190, 6, 220), Palette.City.Earth)
	-- Near boundary: varied blocked streets and retaining facades.
	for _, spec in {
		{Vector3.new(-208, 28, -110), Vector3.new(18, 62, 70)}, {Vector3.new(214, 42, -38), Vector3.new(28, 88, 54)},
		{Vector3.new(-218, 22, 92), Vector3.new(34, 48, 62)}, {Vector3.new(204, 32, 116), Vector3.new(42, 68, 36)},
		{Vector3.new(-80, 20, -208), Vector3.new(70, 46, 24)}, {Vector3.new(92, 34, 210), Vector3.new(82, 72, 28)},
	} do mass(near, "RuinedFacade", spec[1], spec[2], facade) end
	-- Middle landmarks: deliberately sparse and asymmetrical.
	for _, spec in {
		{Vector3.new(-270, 66, -90), Vector3.new(48, 132, 58)}, {Vector3.new(278, 92, 88), Vector3.new(62, 184, 62)},
		{Vector3.new(-250, 38, 188), Vector3.new(90, 76, 48)}, {Vector3.new(240, 46, -210), Vector3.new(110, 92, 44)},
	} do mass(middle, "CityBlock", spec[1], spec[2], Palette.City.Skyline) end
	-- Collapsed elevated roadway, a strong horizontal landmark on the east.
	mass(middle, "OverpassDeck", Vector3.new(238, 48, -8), Vector3.new(150, 8, 22), Palette.City.RoofDeck)
	for _, x in {-310, -255, 310} do mass(middle, "OverpassPillar", Vector3.new(x, 23, -8), Vector3.new(8, 46, 8), Palette.City.Foundation) end
	-- Horizon silhouettes keep every camera direction connected to the ground.
	for _, spec in {
		{Vector3.new(-410, 48, -260), Vector3.new(150, 96, 60)}, {Vector3.new(410, 70, -180), Vector3.new(180, 140, 70)},
		{Vector3.new(-390, 38, 300), Vector3.new(220, 76, 80)}, {Vector3.new(390, 52, 300), Vector3.new(180, 104, 90)},
	} do mass(horizon, "HorizonSilhouette", spec[1], spec[2], Color3.fromRGB(35, 43, 55)) end
	return root
end

return Backdrop
