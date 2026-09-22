--!strict
--[[
	Frame-rate-independent motion maths for the cinematic's vehicles.

	This module owns NO instances, NO connections and NO update loop. Env.lua
	still owns vehicle construction and placement (see its header); this is
	only the small amount of time-dependent arithmetic that sat inline there
	and was silently assuming a 60 Hz render.

	Two things were wrong with that, and both are visible rather than
	theoretical:

	  * speed was derived as `distance * 60`. On a machine rendering at 30 the
	    truck reported half its real speed, so the snow spray thinned out and
	    the weight-transfer pitch halved; above 60 both exaggerated.
	  * the suspension blended 18% of the way toward the solved attitude
	    ONCE PER RENDERED FRAME, so the hull settled twice as fast at 120 fps
	    as at 60. "Restrained and heavy" is a time constant, not a per-frame
	    fraction.

	Everything here is pure: same inputs, same outputs, no globals. That is
	what makes it checkable without a running game.
]]

local VehicleMotion = {}

-- A single wheel of a vehicle. `place` is the rigid-placement closure
-- Kit.rigid returns for that wheel's model; `offset` is its position in the
-- chassis's own flat (yaw-only) frame. `groundY`/`deflection` are solved each
-- frame by Env.settleVehicle and are absent until it has run once.
export type WheelHandle = {
	model: Model,
	place: (CFrame) -> (),
	offset: Vector3,
	side: number,
	z: number,
	groundY: number?,
	deflection: number?,
}

-- The vehicle itself. `body` is everything rigid to the hull; `wheels` are
-- siblings of it so the two move independently. `spin` is accumulated wheel
-- angle in radians, `speed` is studs/second, and `pitch`/`roll`/`lift` are the
-- smoothed suspension attitude.
export type VehicleHandle = {
	model: Model,
	body: Model,
	placeBody: (CFrame) -> (),
	wheels: { WheelHandle },
	base: CFrame,
	length: number,
	width: number,
	deckY: number,
	spin: number,
	pitch: number,
	roll: number,
	lift: number,
	speed: number,
	groundY: number?,
	lastPos: Vector3?,
	spray: ParticleEmitter?,
	sprayHost: BasePart?,
	lights: { SpotLight },
}

-- Below this, a frame is treated as having no duration at all: dividing by it
-- would turn floating-point noise into an enormous speed. Roblox can deliver a
-- zero-length step after a hitch or on the first frame of a resumed session.
local MIN_STEP = 1e-5

--[[
	Studs per second covered over `deltaTime`, from a signed distance.

	`distance` is signed (reversing must not spin the wheels forwards) but a
	speed is not, so the sign is dropped here and kept by the caller where it
	is still needed.
]]
function VehicleMotion.speed(distance: number, deltaTime: number): number
	if deltaTime <= MIN_STEP then
		return 0
	end
	return math.abs(distance) / deltaTime
end

--[[
	The blend factor that moves a value `responsiveness`-per-second of the way
	toward its target, whatever the frame rate.

	`value += (target - value) * expAlpha(k, dt)` converges on the same curve in
	the same WALL-CLOCK time at 30, 60 or 240 fps, which a bare per-frame
	fraction does not. Higher k is a stiffer, faster-settling response; the
	value returned is always in [0, 1].
]]
function VehicleMotion.expAlpha(responsiveness: number, deltaTime: number): number
	if deltaTime <= MIN_STEP then
		return 0
	end
	return 1 - math.exp(-responsiveness * deltaTime)
end

--[[
	Signed acceleration in studs/second^2 between two speeds a frame apart.
	Used only for the small squat/dive pitch on top of the terrain attitude.
]]
function VehicleMotion.acceleration(current: number, previous: number, deltaTime: number): number
	if deltaTime <= MIN_STEP then
		return 0
	end
	return (current - previous) / deltaTime
end

return VehicleMotion
