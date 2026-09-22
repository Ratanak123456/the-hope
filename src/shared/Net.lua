--!strict
-- Single source of truth for remotes. The server creates them once (safely
-- re-runnable after a Rojo re-sync); the client waits for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "HopeRemotes"

local Net = {}

-- name -> class
local REMOTES: { [string]: string } = {
	-- client -> server
	Transform = "RemoteEvent", -- request Aegis Zero transform toggle
	Attack = "RemoteEvent", -- request an ability; server owns all outcomes
	Action = "RemoteEvent", -- misc verbs: MenuState, DialogueDone, Retry, ...
	-- server -> client
	Feedback = "RemoteEvent", -- all authoritative UI state pushes
}

Net.Remotes = REMOTES

local folder: Folder? = nil

local function serverFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = FOLDER_NAME
	created.Parent = ReplicatedStorage
	return created
end

function Net.init()
	assert(RunService:IsServer(), "Net.init() is server only")
	local parent = serverFolder()
	for name, className in REMOTES do
		local existing = parent:FindFirstChild(name)
		if not (existing and existing.ClassName == className) then
			if existing then
				existing:Destroy()
			end
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = parent
		end
	end
	folder = parent
end

function Net.get(name: string): RemoteEvent
	assert(REMOTES[name], `unknown remote "{name}"`)
	if not folder then
		if RunService:IsServer() then
			folder = serverFolder()
		else
			folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
		end
	end
	local parent = folder :: Folder
	local remote = if RunService:IsServer()
		then parent:FindFirstChild(name)
		else parent:WaitForChild(name, 30)
	assert(remote and remote:IsA("RemoteEvent"), `remote "{name}" is missing`)
	return remote
end

-- Message kinds carried by the Feedback remote (server -> client).
Net.Feedback = {
	Objective = "Objective", -- { chapter, title, detail, progress? }
	Dialogue = "Dialogue", -- { token, speaker, lines }
	DialogueClear = "DialogueClear",
	Transform = "Transform", -- { active, unlocked, phase, duration }
	TransformVFX = "TransformVFX", -- { userId, phase, duration } - all clients
	Cooldown = "Cooldown", -- { ability, duration }
	Hit = "Hit", -- { count, killed } - attacker only
	AttackVFX = "AttackVFX", -- { origin, direction } - all clients
	WardenTelegraph = "WardenTelegraph", -- { position, radius, duration }
	WardenHit = "WardenHit", -- { position, died }
	AbilityState = "AbilityState", -- authoritative acceptance, charge and lock state
	AbilityVFX = "AbilityVFX", -- coordinated world-space attack presentation
	Notice = "Notice", -- short, non-blocking player message
	Encounter = "Encounter", -- { state, remaining, total }
	Phase = "Phase", -- { phase } - high level game phase
	EnemyStatus = "EnemyStatus", -- { active, label, current, max } - aggregate swarm integrity
	TutorialCue = "TutorialCue", -- { highlight, markerTarget, notify, showSkip } - onboarding presentation only
	Progress = "Progress", -- { status: Loading|Ready|Failed, onboardingComplete, stage } - drives the menu's primary action
	WorldMarker = "WorldMarker", -- { target: Instance?, active: boolean } - generic objective marker, any scene
	LocationTitle = "LocationTitle", -- { text: string } - a short "Central Plaza — 11:47 AM" style title card
	SceneState = "SceneState", -- { stage } - informs the client which Chapter One scene is now active
	Scene02Invasion = "Scene02Invasion", -- fires once: tells the client to run the Scene 2 invasion cutscene
	HumanCombat = "HumanCombat", -- { enabled: boolean } - shows/hides Scene 3's temporary emergency-staff action-bar slots
	Scene04Collapse = "Scene04Collapse", -- fires once: tells the client to run the street-collapse cutscene
	Scene09Ending = "Scene09Ending", -- fires once: tells the client to run Chapter One's ending cutscene
	ChapterComplete = "ChapterComplete", -- { rescued: number, unlocked: string } - opens the chapter-completion screen
}

-- Verbs carried by the Action remote (client -> server).
Net.Action = {
	MenuState = "MenuState", -- (inMenu: boolean)
	DialogueDone = "DialogueDone", -- (token: number)
	DialogueChoice = "DialogueChoice", -- (choiceId: string)
	Retry = "Retry",
	ReturnToSurface = "ReturnToSurface",
	SkipTutorial = "SkipTutorial",
	RequestTraining = "RequestTraining", -- ask to practice again after onboarding
	RetryProgress = "RetryProgress", -- retry a failed save/progress fetch from the menu
	SkipScene01 = "SkipScene01", -- Chapter One Scene 1's opening cinematic Skip button
	Scene02Done = "Scene02Done", -- Scene 2's cutscene ended, naturally or via Skip - same end state either way
	Scene04Done = "Scene04Done", -- Scene 4's collapse cutscene ended, naturally or via Skip - same end state either way
	Scene09Done = "Scene09Done", -- Scene 9's ending cutscene ended, naturally or via Skip - opens the chapter-completion screen
	ChapterOneContinue = "ChapterOneContinue", -- "Continue" pressed on the chapter-completion screen
	ChapterOneReturnToMenu = "ChapterOneReturnToMenu", -- "Return to Menu" pressed on the chapter-completion screen
}

return Net
