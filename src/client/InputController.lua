--!nonstrict
-- Keyboard and mouse bindings. Touch actions are driven by the on-screen
-- action bar and the dialogue tap target instead, so the mobile joystick and
-- jump button keep working.
--
-- Connections are stored so a rebuild can tear the old ones down; that is what
-- stops a re-sync from installing a second set of handlers.

local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)

local State = require(script.Parent.State)

local InputController = {}

local connections: { RBXScriptConnection } = {}
local handlers = {
	transform = nil :: (() -> ())?,
	attack = nil :: (() -> ())?,
	slam = nil :: (() -> ())?,
	bolt = nil :: (() -> ())?,
	dash = nil :: (() -> ())?,
	ultimate = nil :: (() -> ())?,
	advance = nil :: (() -> ())?,
}

local function isAdvanceKey(keyCode: Enum.KeyCode): boolean
	for _, key in Config.Input.AdvanceKeys do
		if key == keyCode then
			return true
		end
	end
	return false
end

function InputController.teardown()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)
end

function InputController.bind(callbacks)
	InputController.teardown()
	handlers.transform = callbacks.transform
	handlers.attack = callbacks.attack
	handlers.slam = callbacks.slam
	handlers.bolt = callbacks.bolt
	handlers.dash = callbacks.dash
	handlers.ultimate = callbacks.ultimate
	handlers.advance = callbacks.advance

	table.insert(
		connections,
		UserInputService.InputBegan:Connect(function(input, processed)
			-- `processed` is true when Roblox's own UI (chat, menu) or one of our
			-- buttons already consumed the input. Never fight it.
			if processed then
				return
			end

			if State.dialogueOpen and isAdvanceKey(input.KeyCode) then
				if handlers.advance then
					handlers.advance()
				end
				return
			end

			if not State.combatAllowed() then
				return
			end

			if input.KeyCode == Config.Input.TransformKey or input.KeyCode == Config.Input.TransformGamepadKey then
				if handlers.transform then
					handlers.transform()
				end
			elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Config.Input.PrimaryGamepadKey then
				if handlers.attack then
					handlers.attack()
				end
			elseif (input.KeyCode == Config.Input.SlamKey or input.KeyCode == Config.Input.SlamGamepadKey) and handlers.slam then
				handlers.slam()
			elseif (input.KeyCode == Config.Input.BoltKey or input.KeyCode == Config.Input.BoltGamepadKey) and handlers.bolt then
				handlers.bolt()
			elseif (input.KeyCode == Config.Input.DashKey or input.KeyCode == Config.Input.DashGamepadKey) and handlers.dash then
				handlers.dash()
			elseif (input.KeyCode == Config.Input.UltimateKey or input.KeyCode == Config.Input.UltimateGamepadKey) and handlers.ultimate then
				handlers.ultimate()
			end
		end)
	)
end

return InputController
