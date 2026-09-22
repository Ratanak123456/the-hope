--!nonstrict
-- Generic in-game cutscene runner, shared by every Chapter One scene's
-- cutscene from Scene 2 onward (Opening.lua remains its own thing - it is
-- the pre-gameplay menu-to-Scene-1 handoff, already shipped and working, and
-- rewriting it to use this module would be pure regression risk for no
-- behavioural change). Each cutscene using this module gets, for free:
--
--   * a subtitle card and a Skip button (mouse/touch/gamepad via
--     UIKit.button, plus a keyboard shortcut) with the exact same "apply the
--     end state, not just cut the camera" contract as Opening.lua's,
--   * one finalization path regardless of natural completion, Skip, or a
--     caught error, guarded so it can only run once,
--   * a watchdog so a bug inside a shot can never strand the player behind a
--     dead screen with no way out.
--
-- Shots have the exact same shape Opening.lua's do: { name, duration,
-- subtitle = { speaker, text } | nil, enter = () -> state, update =
-- (state, alpha) -> (), leave = (state) -> () }.

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Theme = require(ReplicatedStorage.Shared.Theme)
local Settings = require(script.Parent.Settings)
local UIKit = require(script.Parent.UIKit)

local CutsceneRunner = {}

export type Shot = {
	name: string,
	duration: number,
	subtitle: { any }?, -- { speaker: string?, text: string }
	enter: () -> any,
	update: (state: any, alpha: number) -> (),
	leave: (state: any) -> (),
}

export type PlayOptions = {
	parent: Frame,
	shots: { Shot },
	finish: () -> (),
	onSkip: (() -> ())?, -- fired once, before finish, when Skip is pressed
	skipActionVerb: string?, -- a Net.Action verb fired to the server on Skip
	skipHintText: string?,
	watchdogSeconds: number?,
}

local LOG_PREFIX = "[SKY BROKE] Cutscene:"

local function setCamera(position: Vector3, target: Vector3, sway: number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local offset = if Settings.reducedMotion() then Vector3.zero else Vector3.new(sway or 0, 0, 0)
	camera.CFrame = CFrame.lookAt(position + offset, target)
end
CutsceneRunner.setCamera = setCamera

--[[
	Runs one cutscene to completion. Returns nothing; call `finish` from
	options to know when it is actually done (mirrors Opening.start's shape).
	Safe to call again once a previous run's `finish` has fired - each call
	owns its own token, so an overlapping call from misbehaving caller code
	simply supersedes the older one rather than corrupting shared state.
]]
function CutsceneRunner.play(options: PlayOptions)
	local overlay: Frame
	local card: Frame
	local subtitleLabel: TextLabel
	local speakerLabel: TextLabel
	local skipButton: any
	local skipKeyConnection: RBXScriptConnection? = nil
	local handoffDone = false
	local skipRequested = false

	local function setSubtitle(speaker: string?, text: string)
		speakerLabel.Text = speaker or ""
		speakerLabel.Visible = speaker ~= nil
		subtitleLabel.Text = text
	end

	overlay = UIKit.container({ Parent = options.parent, Name = "Cutscene", Visible = true, ZIndex = 40 })
	UIKit.create("Frame", { Parent = overlay, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 40 })

	card = UIKit.container({ Parent = overlay, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, Theme.Metric.EdgeInset, 1, -Theme.Metric.EdgeInset), Size = UDim2.new(1, -Theme.Metric.EdgeInset * 2 - 140, 0, 68), ZIndex = 41 })
	UIKit.create("UISizeConstraint", { Parent = card, MaxSize = Vector2.new(600, 68), MinSize = Vector2.new(220, 68) })
	UIKit.create("UIGradient", { Parent = card, Rotation = 0, Color = ColorSequence.new(Theme.Color.Void, Theme.Color.Void), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 1) }) })
	speakerLabel = UIKit.text({ Parent = card, Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 16), Font = Theme.Font.Mono, Text = "", TextColor3 = Theme.Color.TealGlow, TextSize = Theme.text("Caption"), ZIndex = 42, Visible = false, Name = "Speaker" })
	subtitleLabel = UIKit.text({ Parent = card, Position = UDim2.fromOffset(18, 28), Size = UDim2.new(1, -36, 0, 32), Font = Theme.Font.Heading, Text = "", TextColor3 = Theme.Color.Text, TextSize = Theme.text("H2"), TextWrapped = true, ZIndex = 42, Name = "Subtitle" })

	local skipHolder = UIKit.container({ Parent = overlay, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -Theme.Metric.EdgeInset, 1, -Theme.Metric.EdgeInset), Size = UDim2.fromOffset(120, 68), ZIndex = 41, Name = "Skip" })
	skipButton = UIKit.button({ Parent = skipHolder, Size = UDim2.new(1, 0, 0, 38), Text = "SKIP", variant = "ghost", ZIndex = 42 })
	UIKit.text({ Parent = skipHolder, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Mono, Text = options.skipHintText or "E / START", TextColor3 = Theme.Color.TextMuted, TextXAlignment = Enum.TextXAlignment.Center, TextSize = Theme.text("Caption"), ZIndex = 42 })

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end

	local function cleanup()
		if skipKeyConnection then
			skipKeyConnection:Disconnect()
			skipKeyConnection = nil
		end
		if overlay then
			overlay:Destroy()
		end
	end

	local function performHandoff()
		if handoffDone then
			return
		end
		handoffDone = true
		local cleanupOk, cleanupErr = pcall(cleanup)
		if not cleanupOk then
			warn(`{LOG_PREFIX} cleanup error (non-fatal): {cleanupErr}`)
		end
		local finishOk, finishErr = pcall(options.finish)
		if not finishOk then
			warn(`{LOG_PREFIX} finish callback error: {finishErr}`)
		end
	end

	local function requestSkip()
		if skipRequested then
			return
		end
		skipRequested = true
		print(`{LOG_PREFIX} Skip pressed`)
		if options.onSkip then
			local ok, err = pcall(options.onSkip)
			if not ok then
				warn(`{LOG_PREFIX} onSkip callback error: {err}`)
			end
		end
		if options.skipActionVerb then
			local ok, err = pcall(function()
				Net.get("Action"):FireServer(options.skipActionVerb, nil)
			end)
			if not ok then
				warn(`{LOG_PREFIX} skip action failed to send: {err}`)
			end
		end
	end

	skipButton.onActivated(requestSkip)
	skipKeyConnection = UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for _, keyCode in Config.Input.AdvanceKeys do
			if input.KeyCode == keyCode then
				requestSkip()
				return
			end
		end
	end)

	task.delay(options.watchdogSeconds or 40, function()
		if not handoffDone then
			warn(`{LOG_PREFIX} watchdog forcing handoff after timeout`)
			performHandoff()
		end
	end)

	task.spawn(function()
		local function waitShot(duration: number): boolean
			local started = os.clock()
			while os.clock() - started < duration do
				if skipRequested then
					return false
				end
				RunService.RenderStepped:Wait()
			end
			return true
		end

		for index, shot in options.shots do
			if skipRequested then
				break
			end
			print(`{LOG_PREFIX} shot {index}/{#options.shots} ({shot.name})`)
			if shot.subtitle then
				setSubtitle(shot.subtitle[1], shot.subtitle[2])
			else
				setSubtitle(nil, "")
			end
			local duration = if Settings.reducedMotion() then 0.4 else shot.duration
			local ok, state = pcall(shot.enter)
			if not ok then
				warn(`{LOG_PREFIX} shot {index} ({shot.name}) enter() error: {state}`)
				state = {}
			end
			local started = os.clock()
			local connection = RunService.RenderStepped:Connect(function()
				local updateOk, updateErr = pcall(shot.update, state, math.clamp((os.clock() - started) / duration, 0, 1))
				if not updateOk then
					warn(`{LOG_PREFIX} shot {index} ({shot.name}) update() error: {updateErr}`)
				end
			end)
			waitShot(duration)
			connection:Disconnect()
			local leaveOk, leaveErr = pcall(shot.leave, state)
			if not leaveOk then
				warn(`{LOG_PREFIX} shot {index} ({shot.name}) leave() error: {leaveErr}`)
			end
		end

		performHandoff()
	end)
end

return CutsceneRunner
