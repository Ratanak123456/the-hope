--!nonstrict
-- Owns the single ScreenGui and the layer frames every screen draws into.
-- Destroying any previous copy first is what stops a Rojo re-sync or a rejoin
-- from stacking duplicate interfaces.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Theme = require(Shared.Theme)

local UIKit = require(script.Parent.Parent.UIKit)

local Root = {}

local GUI_NAME = "HopeUI"

Root.gui = nil :: ScreenGui?
Root.layers = {} :: { [string]: Frame }

function Root.build(): ScreenGui
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	for _, existing in playerGui:GetChildren() do
		if existing.Name == GUI_NAME or existing.Name == "HopeHUD" then
			existing:Destroy()
		end
	end

	local gui = UIKit.create("ScreenGui", {
		Name = GUI_NAME,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
		Parent = playerGui,
	})

	Root.gui = gui
	Root.layers = {}
	for name, order in Theme.Layer do
		Root.layers[name] = UIKit.container({
			Parent = gui,
			Name = name,
			ZIndex = order,
			Size = UDim2.fromScale(1, 1),
		})
	end

	return gui
end

function Root.layer(name: string): Frame
	local layer = Root.layers[name]
	assert(layer, `unknown UI layer "{name}"`)
	return layer
end

function Root.destroy()
	if Root.gui then
		Root.gui:Destroy()
		Root.gui = nil
	end
	Root.layers = {}
end

return Root
