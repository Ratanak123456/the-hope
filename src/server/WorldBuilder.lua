--!nonstrict
-- Orchestrates world generation and keeps the contract the gameplay services
-- depend on: Folder, Prompt, RuinSpawn, CitySpawn, ArenaCenter, EntrancePosition.
--
-- Generation runs in two phases so a player can start moving through the city
-- long before the underground vault, outer backdrop and sky dressing finish:
-- buildEssential() produces a walkable city and unblocks spawning, then
-- finishDecor() fills in everything else while the player is already in
-- control. See Main.server.lua for how the two are sequenced.
--
-- Everything is procedural Roblox geometry - no models, no Toolbox assets, no
-- asset IDs. Generation is deterministic (see Palette.Quality.Seed), so the
-- district is identical between test runs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Palette)
local City = require(script.Parent.World.City)
local Kit = require(script.Parent.World.Kit)
local Ruin = require(script.Parent.World.Ruin)
local Sky = require(script.Parent.World.Sky)
local Backdrop = require(script.Parent.World.Backdrop)

local WorldBuilder = {}

export type World = {
	Folder: Folder,
	Prompt: ProximityPrompt,
	RuinSpawn: CFrame,
	CitySpawn: CFrame,
	PlazaSpawnCFrame: CFrame,
	ArenaCenter: Vector3,
	EntrancePosition: Vector3,
	Neighborhood: any, -- World/Neighborhood.lua's Result - Scene 1's spawn/Daren/Mira marks
	Fountain: Model, -- Central Plaza's fountain/monument - Scene 2's cover point
	FountainPosition: Vector3,
	Notes: { string },
	-- False until finishDecor() has populated the Ruin-derived fields above
	-- with real values and re-enabled the entrance Prompt.
	DecorReady: boolean,
}

--[[
	The default Baseplate's top surface sits at the same height as our street
	layer, which z-fights and blocks the ruin entrance. We neutralise it rather
	than deleting it, so nothing the user built is destroyed and the change is
	trivially reversible in the Explorer.

	The SpawnLocation the user already removed by hand is never recreated here;
	the game's spawn is built by City.lua, well clear of the entrance.
]]
local function neutraliseBaseplate(): string?
	for _, child in workspace:GetChildren() do
		if child:IsA("BasePart") and (child.Name == "Baseplate" or child.Name == "Baseplate_DisabledByHope") then
			if child.Size.X < 200 then continue end
			child.Name = "Baseplate_DisabledByHope"
			child.Transparency = 1
			child.CanCollide = false
			child.CanQuery = false
			child.CanTouch = false
			child.CastShadow = false
			child:SetAttribute("HopeDisabled", true)
			return "Disabled the default Baseplate (renamed Baseplate_DisabledByHope, invisible and non-colliding). Delete it in the Explorer whenever you like."
		end
	end
	return nil
end

local function countParts(root: Instance): number
	local partCount = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			partCount += 1
		end
	end
	return partCount
end

--[[
	Phase 1: everything a freshly spawned player can reach immediately - the
	city district, its spawn point and the ruin entrance prompt.

	This exists so a player's character can start moving as soon as the CITY
	is walkable, instead of waiting for the underground vault, the outer
	backdrop and the sky dressing to finish generating too. Those are built by
	finishDecor() afterward, while the player is already in control.

	The entrance prompt itself is left enabled (Roblox's ProximityPromptService
	does not reliably re-detect a prompt that flips Enabled while a player is
	already standing in range, which would make the whole entrance silently
	inert). Main.server.lua guards the *trigger*, not the prompt, by checking
	world.DecorReady before actually sending anyone down.
]]
function WorldBuilder.buildEssential(): World
	local old = workspace:FindFirstChild("HopeGreybox")
	if old then
		old:Destroy()
	end

	Kit.resetLightBudget()

	local world = Instance.new("Folder")
	world.Name = "HopeGreybox"
	world.Parent = workspace

	local notes: { string } = {}

	local baseplateNote = neutraliseBaseplate()
	if baseplateNote then
		table.insert(notes, baseplateNote)
	end

	local city = City.build(world)

	print(`[SKY BROKE] essential world ready: {countParts(world)} parts, seed {Palette.Quality.Seed}`)
	for _, note in notes do
		warn(`[SKY BROKE] {note}`)
	end

	return {
		Folder = world,
		Prompt = city.Prompt,
		-- Placeholder until finishDecor() runs; DecorReady = false is what
		-- actually stops these from being used before then (see Main.server.lua).
		RuinSpawn = city.SpawnCFrame,
		CitySpawn = city.SpawnCFrame,
		PlazaSpawnCFrame = city.PlazaSpawnCFrame,
		ArenaCenter = city.SpawnCFrame.Position,
		EntrancePosition = city.Crater.Position,
		Neighborhood = city.Neighborhood,
		Fountain = city.Fountain,
		FountainPosition = city.FountainPosition,
		Notes = notes,
		DecorReady = false,
	}
end

--[[
	Phase 2: the ruin vault, the outer backdrop and the sky. Purely additive -
	nothing here is required for a player to stand in the city and move
	around, so it runs after the essential phase has already unblocked
	spawning. Mutates `world` in place (rather than returning a new table) so
	callers that captured the phase-1 world - EncounterService in particular -
	see the completed fields once this finishes.
]]
function WorldBuilder.finishDecor(world: World)
	local ruin = Ruin.build(world.Folder)
	Backdrop.build(world.Folder)
	local skyNotes = Sky.build(world.Folder)
	for _, note in skyNotes do
		table.insert(world.Notes, note)
		warn(`[SKY BROKE] {note}`)
	end

	world.RuinSpawn = ruin.SpawnCFrame
	world.ArenaCenter = ruin.ArenaCentre
	world.DecorReady = true

	print(`[SKY BROKE] full world ready: {countParts(world.Folder)} parts total`)
end

return WorldBuilder
