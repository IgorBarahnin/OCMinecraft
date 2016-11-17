local image = require("image")
local buffer = require("doubleBuffering")
local keyboard = require("keyboard")
local bigLetters = require("bigLetters")
local fs = require("filesystem")
local serialization = require("serialization")
local ecs = require("ECSAPI")

local function clicked(x, y, object)
	if x >= object[1] and y >= object[2] and x <= object[3] and y <= object[4] then
		return true
	end
	return false
end

local function wait()
	while true do
		local e = {event.pull()}
		if e[1] == "touch" or e[1] == "key_down" then
			currentUser = e[6]
			return
		end
	end
end

wait()
