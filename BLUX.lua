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

local xNewColumnGenerationVariable = config.spaceBetweenColumns
while true do
	local somethingHappend = false
	
	local e = {event.pull(config.FPS)}
	if birdIsAlive and (e[1] == "touch" or e[1] == "key_down") then
		yBird = yBird - config.birdFlyUpSpeed + (not birdIsAlive and 2 or 0)
		somethingHappend = true
		currentUser = e[1] == "touch" and e[6] or e[5]
	end

	moveColumns()
	xNewColumnGenerationVariable = xNewColumnGenerationVariable + 1
	if xNewColumnGenerationVariable >= config.spaceBetweenColumns then
		xNewColumnGenerationVariable = 0
		generateColumn()
	end

	if not somethingHappend then
		if yBird + bird.height - 1 < buffer.screen.height then
			yBird = yBird + config.birdFlyDownSpeed
		else
			scores[currentUser] = math.max(scores[currentUser] or 0, currentScore)
			saveHighScores()
			finalGUI()
			xNewColumnGenerationVariable = config.spaceBetweenColumns
		end
	end

	drawAll()
end
