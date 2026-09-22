--!strict
-- Fixed-window per-player request limiter. Cheap and good enough to stop a
-- client spamming a remote in a loop.

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Limiter = {
	allow: (self: Limiter, player: Player) -> boolean,
	clear: (self: Limiter, player: Player) -> (),
}

type Bucket = { count: number, windowStart: number }

function RateLimiter.new(count: number, window: number)
	return setmetatable({
		_count = count,
		_window = window,
		_buckets = {} :: { [Player]: Bucket },
	}, RateLimiter)
end

function RateLimiter:allow(player: Player): boolean
	local now = os.clock()
	local bucket = self._buckets[player]
	if not bucket or now - bucket.windowStart >= self._window then
		self._buckets[player] = { count = 1, windowStart = now }
		return true
	end
	if bucket.count >= self._count then
		return false
	end
	bucket.count += 1
	return true
end

function RateLimiter:clear(player: Player)
	self._buckets[player] = nil
end

return RateLimiter
