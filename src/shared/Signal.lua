--!nonstrict
-- Minimal signal so modules can talk to each other without circular requires.

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (Connection) -> () }

export type Class = {
	Connect: (Class, handler: (...any) -> ()) -> Connection,
	Fire: (Class, ...any) -> (),
}

function Signal.new(): Class
	return (setmetatable({ _handlers = {} }, Signal) :: any) :: Class
end

function Signal:Connect(handler: (...any) -> ()): Connection
	local handlers = self._handlers
	table.insert(handlers, handler)
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

-- Handlers run on their own threads so one erroring listener cannot break the
-- rest of the chain.
function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		task.spawn(handler, ...)
	end
end

return Signal
