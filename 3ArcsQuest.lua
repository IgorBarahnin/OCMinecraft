------------------ =====
--	ПОДГОТОВКА  -- ==  ==
------------------ =====

-- подгружаем библиотеки --
local image = require("image")
local buffer = require("doubleBuffering")
local keyboard = require("keyboard")
local fs = require("filesystem")
local serialization = require("serialization")
local ecs = require("ECSAPI")
local colorlib = require("colorlib")

-- Взял с какого то сайта, полезно! Копирует таблицы, хочется модифициравать хар-ки врагов не портя оригинал, естественно потом все чистить! ато как же.
local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- размер массива --
local function getArraySize(array)
	local r = 0
	for i in pairs(array) do
		r = r + 1
	end
	return r
end

-- стартуем буфер --
buffer.start()

------------------------------- =====
--	ИНИЦИАЛИЗАЦИЯ ПЕРЕМЕННЫХ -- ==	==
-------------------------------	=====

-- директории игры --
local aRD  = MineOSCore.getCurrentApplicationResourcesDirectory()
local aID  = (aRD .. "/Images")
local tilesDirectory = "Default"
local aTD  = (aID .. "/tiles/" .. tilesDirectory)
local aED  = (aID .. "/entity")
local aBED = (aID .. "/bigEnemys")
local aSD  = (aID .. "/squad")

-- настройки игры --
local config = {
	FPS                = 0.05,
	dialogWindowSize   = 0.2 ,
	sideMenuWindowSize = 0.32
}

-- пути к файлам --
local path = {
	playerSpritePath = (aID .. "/playerSprite.pic"),
	background = (aTD .. "/background"),
	middle = (aTD .. "/middle"),
}

-- игровые окна --
local windows = {
	dialogWindow   = {
		x = 1,
		y = math.floor(buffer.screen.height * (1-config.dialogWindowSize))+1,
		width = math.floor(buffer.screen.width + 1),
		height = math.floor(buffer.screen.height * config.dialogWindowSize + 1)
	},
	sideMenuWindow = {
		x = math.floor(buffer.screen.width * (1-config.sideMenuWindowSize))+1,
		y=1,
		width = math.floor(buffer.screen.width * config.sideMenuWindowSize + 1),
		height = math.floor(buffer.screen.height + 1)
	},
	mainWindow     = {
		x = 0,
		y = 0,
		xMiddle = math.floor(buffer.screen.width * (1-config.sideMenuWindowSize) /2),
		yMiddle = math.floor(buffer.screen.height * (1-config.dialogWindowSize) /2),
		width = math.floor(buffer.screen.width * (1-config.sideMenuWindowSize)),
		height = math.floor(buffer.screen.height * (1-config.dialogWindowSize))
	}
}
-- глобальные переменные --
local inBattle = false
local menuLock = false
local selectedMenu = 0
local selectedSquadMember = 1
local enemyCount = 1
local keyCode = 1

-- игровое поле --
local mapBottom = {
	{0x1,0x1,0x4,0x4,0x2,0x2,0x2,0x1,0x1,0x2,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x1,0x1,0x4,0x4,0x2,0x1,0x2,0x2,0x2,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x1,0x4,0x4,0x4,0x4,0x4,0x2,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x2,0x2,0x4,0x1,0x2,0x4,0x4,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x1,0x2,0x3,0x3,0x3,0x3,0x3,0x2,0x4,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x2,0x3,0x3,0x3,0x3,0x3,0x2,0x4,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x2,0x3,0x3,0x3,0x3,0x3,0x2,0x1,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x3,0x3,0x3,0x3,0x3,0x2,0x1,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x1,0x2,0x3,0x3,0x3,0x3,0x3,0x1,0x1,0x4,0x4,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x3,0x3,0x3,0x3,0x3,0x1,0x1,0x2,0x4,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x1,0x1,0x1,0x2,0x2,0x2,0x2,0x1,0x1,0x2,0x2,0x4,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x1,0x1,0x2,0x1,0x2,0x1,0x2,0x2,0x2,0x4,0x4,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x1,0x1,0x1,0x1,0x2,0x2,0x2,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x2,0x2,0x1,0x1,0x2,0x2,0x2,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x1,0x2,0x2,0x2,0x2,0x1,0x2,0x2,0x2,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x2,0x1,0x2,0x2,0x2,0x2,0x2,0x4,0x4,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x2,0x2,0x1,0x2,0x2,0x2,0x4,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x1,0x2,0x2,0x1,0x2,0x2,0x2,0x1,0x4,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x2,0x2,0x1,0x1,0x2,0x2,0x2,0x1,0x1,0x4,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2},
	{0x1,0x1,0x1,0x2,0x2,0x2,0x2,0x1,0x1,0x4,0x2,0x2,0x1,0x1,0x2,0x1,0x1,0x1,0x2,0x2}
}
local mapMiddle = {
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,0x2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,0x2,nil,0x1,0x1,nil,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,nil,nil,nil,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,nil,nil,nil,0x1,nil,0x2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,nil,nil,nil,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,nil,nil,nil,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,0x2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,0x2,nil,nil,nil,nil,nil,0x2,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}
}
local mapTop = {
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,0x1,0x1,0x1,0x1,0x1,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil},
	{nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil}
}

-- тайлы карты --
local Tiles = {
-- тайлы заднего плана --
	background = {
	 [0x1] = image.load(path.background .. "/1.pic"),
	 [0x2] = image.load(path.background .. "/2.pic"),
	 [0x3] = image.load(path.background .. "/3.pic"),
	 [0x4] = image.load(path.background .. "/4.pic")
	},
	middle = {
	 [0x1] = image.load(path.middle .. "/1.pic"),
	 [0x2] = image.load(path.middle .. "/2.pic")
	},
	top = {
	 [0x1] = 0x454545
	}
}

-- диалоговое окно --
local dialog = {
	-- переменные
	head = {
		image = image.load(aID .. "/heads/headWindow.pic"),
		head = nil,
		visible = false
	},
	text = "Равным образом новая модель организационной деятельности влечет за собой процесс внедрения и модернизации дальнейших направлений развития. Задача организации, в особенности же укрепление и развитие структуры играет важную роль в формировании систем массового участия. Таким образом новая модель организационной деятельности позволяет оценить значение соответствующий условий активизации.",
	charNum = 0,
	textInDraw = "",
	drawText = {
		{""},
		{""},
		{""},
		{""},
		{""},
		{""},
		{""},
		{""},
	}
}
--формирование текстового массива
local function textFormat(text,width)
	local r = 0
	local i = 0
	local word = ""
	local str = ""
	local textArray = {}
	while i <= string.len(text) do
		if string.sub(text, i, i) ~= "/" then word = word .. string.sub(text, i, i) end
		if string.sub(text, i, i) == " " or string.sub(text, i, i) == "/" then
			str = str .. word
			word = ""
			textArray[r] = str
			if string.len(str) > width-3 or string.sub(text, i, i) == "/" then
				r = r + 1
				textArray[r] = ""
				str = ""
			end
		end
		i = i + 1
	end
	str = str .. word
	textArray[r] = str
	return textArray
end
--функции
function dialog.textInDrawToText(e)
	if e.charNum < string.len(e.textInDraw) then
		e.text = string.sub(e.textInDraw, 1, e.charNum)
		e.charNum = e.charNum+1
	end
end	
function dialog.textFormat(e)
	-- а теперь функция вообще снаружи
	e.drawText = textFormat(e.text,windows.sideMenuWindow.x-3)
	
	--e.drawText[r] = ""
	-- Не эффективно, медленно, вообще де... рево. Но кому не насрать :/. Может еще переделаю, ага переделаю... На что я тут время трачу?
	--while i <= string.len(e.text) do
	--	if string.sub(e.text, i, i) ~= "/" then word = word .. string.sub(e.text, i, i) end
	--	if string.sub(e.text, i, i) == " " or string.sub(e.text, i, i) == "/" then
	--		str = str .. word
	--		word = ""
	--		e.drawText[r] = str
	--		if string.len(str) > windows.sideMenuWindow.x-3 or string.sub(e.text, i, i) == "/" then
	--			r = r + 1
	--			e.drawText[r] = ""
	--			str = ""
	--		end
	--	end
	--	i = i + 1
	--end
	-- Старый код, режет слова, а русский шрифт... вообще кароче ломается.
	
	--while i < math.ceil(string.len(e.text)/(windows.sideMenuWindow.x-1)) do
	--	e.drawText[i]=string.sub (e.text, i*(windows.sideMenuWindow.x-1), i*(windows.sideMenuWindow.x-1)+(windows.sideMenuWindow.x-1)-1)
	--	i=i+1
	--end
end

-- бой --
local battle = {
	turn=1,
	side=1,
	inAttack=false,
	selectedEnemys={},
	selectedEnemysCount=1,
	partyMemberTurn=1,
	ability=1,
	selecter=1,
	attacker=nil,
	experience=0,
	gold=0,
	selectedEnemysNum={}
}
local battleQueue = {}
local function addActionToBattleQueue(ability,attacker,targets)
	table.insert(battleQueue,{
		ability = ability,
		attacker = attacker,
		targets = targets
	})
end
--------------------------
-- расчет характеристик --

local function getAttack(strength,agility)
	return math.floor(strength    )+math.floor(agility/5  )
end

local function getDefence(strength,agility)
	return math.floor(strength/1.5)+math.floor(agility/4  )
end

local function getAccuracy(strength,agility)
	return math.floor(strength/5  )+math.floor(agility    )
end

local function getBlock(strength,agility)
	return math.floor(strength/4  )+math.floor(agility/1.5)
end

local function getDammage(attack,defence,dammage)
	return math.floor((dammage*(math.random(1000,1200)/1100))/(defence/attack))
end

local function blockTest(accuracy,block)
	return math.random(0,100)<(50*(accuracy/block))
end

local function calculateSecondaryCharacteristics(object)
	object.attack   = getAttack  (object.strength,object.agility)
	object.defence  = getDefence (object.strength,object.agility)
	object.accuracy = getAccuracy(object.strength,object.agility)
	object.block    = getBlock   (object.strength,object.agility)
end

local function calculateEquipmentModifier (object, equipment)
	object.attack   = object.attack   + equipment.modifiers.attack
	object.defence  = object.defence  + equipment.modifiers.defence
	object.accuracy = object.accuracy + equipment.modifiers.accuracy
	object.block    = object.block    + equipment.modifiers.block
	object.armour   = object.armour   + equipment.modifiers.armour
	object.health   = object.health   + equipment.modifiers.health
	object.dammage  = equipment.modifiers.dammage
end

local function calculateEquipmentModifiers(object, equipment)
	object.armour = 0
	object.dammage = 1
	if equipment.armour then calculateEquipmentModifier(object, equipment.armour) end
	if equipment.ring   then calculateEquipmentModifier(object, equipment.ring  ) end
	if equipment.shield then calculateEquipmentModifier(object, equipment.shield) end
	if equipment.weapon then calculateEquipmentModifier(object, equipment.weapon) end
end

local function calculateAllCharacteristics(object, equipment)
	calculateSecondaryCharacteristics(object)
	calculateEquipmentModifiers(object, equipment)
end

-- боевой лог --
local battleLog = {}
local function battleLogAddMesage(text)
	table.insert(battleLog,text)
end
local function battleLogInsertInDialog()
	local length = 0
	dialog.text = ""
	for i in pairs(battleLog) do
		length = length + math.ceil(string.len(battleLog[i]) / windows.sideMenuWindow.x)
		if length > buffer.screen.height-windows.dialogWindow.y then table.remove(battleLog ,1);battleLogInsertInDialog();return end
		dialog.text = dialog.text .. battleLog[i] .. "/"
	end
end

-- умения
local abilities = {}
local function createAbilities(name,description,targets,func,couldown,arguments)
	table.insert(abilities,{
		name=name,
		description=description,
		targets=targets,
		func=func,
		couldown=couldown,
		arguments=arguments
	})
end

local function standartAttack(attacker,targets,arguments)
	for i in pairs(targets) do
		local dam = getDammage(attacker.parameters.attack,targets[i].parameters.defence,attacker.parameters.dammage)
		dam = dam - targets[i].parameters.armour
		if dam <= 0 then dam = 1 end
		targets[i].hp = targets[i].hp - dam
		battleLogAddMesage("Target " .. i .. ":" .. targets[i].name .. " take " .. dam .. " dammage")
	end
end
createAbilities("Attack" ,"Standart attack" ,1,standartAttack,0,{})
createAbilities("Defence","Standart defence",1,standartAttack,0,{})

-- враги --
local enemys = {}
local function createEnemy(name,hp,gold,experience,s,a,i,w,hea,arm,dam,imagePath,modifiers)
	table.insert(enemys,{
		name = name,
		hp = hp,
		gold = gold,
		experience = experience,
		couldown = 0,
		abilities = {1,2},
		parameters = {
			strength = s,
			agility = a,
			intelligence = i,
			willpower = w,
			
			attack = getAttack(s,a),
			block = getBlock(s,a),
			accuracy = getAccuracy(s,a),
			defence = getDefence(s,a),
			
			health = hea,
			dammage= dam,
			armour = arm
		},
		modifiers={
			attack = modifiers[1],
			block = modifiers[2],
			accuracy = modifiers[3],
			defence = modifiers[4],
			
			health = modifiers[5],
			dammage= modifiers[6],
			armour = modifiers[7]
		},
		image = image.load(imagePath)
	})
end

local enemysInBattle = {}
local function createBattleEnemy(name)
	table.insert(enemysInBattle,name)
end

--------------
-- ПРЕДМЕТЫ --

-- инвентарь --
local inventory = {}
local function putInInventory(name, category, count)
	if not count then count = 1 end
	for i in pairs(inventory) do
		if inventory[i].name == name then inventory[i].count = inventory[i].count + count; return end
	end
	table.insert(inventory,{
		name = name,
		category = category,
		count = count
	})
end

-- категории (жаль не типы, но type уже юзается) предметов --
local itemCategories = {
	armours = {},
	weapons = {},
	rings   = {},
	shields = {},
	potions = {},
	scrolls = {},
	other   = {}
}
local function itemCreator(category,name,modifiers,func,canUse,oneUse,description)
	table.insert(category,{
		name=name,
		modifiers={
			attack = modifiers[1],
			block = modifiers[2],
			accuracy = modifiers[3],
			defence = modifiers[4],
			
			health = modifiers[5],
			dammage= modifiers[6],
			armour = modifiers[7]
		},
		description=description,
		canUse=canUse,
		oneUse=oneUse,
		func=func
	})
end
local function itemFind(category,name)
	for i in pairs(category) do
		if category[i].name == name then return i end 
	end
end

----------------------------------
-- СТРУКТУРЫ АКТИВНЫХ ЭЛЕМЕНТОВ --
----------------------------------

----------------------- Не в тему
--	ФУНКЦИИ КОЛЛИЗИИ -- Но...
----------------------- Да и неважно

-- тест клетки --
local function mapMeetPlace(xGrid,yGrid)
	if mapMiddle[yGrid+1][xGrid+1] then return true end;
	return false
end

-- "коллизия" --
local function collisionTest(array,e)
	for i in pairs(array) do
		if array[i].xGrid2==e.xGrid2 and array[i].yGrid2==e.yGrid2 then
			return i
		end
	end
	return false
end

-- массив кнопок --
local buttons = {};
-- + генератор
local function createButton(square,bgcolor,text,color,condition,func,arguments)
	table.insert(buttons,{
		square=square,
		bgcolor=bgcolor,
		text=text,
		color=color,
		func=func,
		arguments=arguments,
		condition=condition,
		press=0,
		drawSelf=function(e)
			if e.condition() then
				buffer.square(e.square[1],e.square[2]+1      ,e.square[3],e.square[4]-1,0x333333)
				buffer.button(e.square[1],e.square[2]+e.press,e.square[3],e.square[4]-1,e.bgcolor,e.color,e.text)
			end
		end
	})
end

-- массив активных элементов --
local entitys = {}
-- функции entitys --
local function entityFuncStart(num)
	entitys[num].func(entitys[num].arguments)
	if entitys[num].oneUse then
		table.remove(entitys,num)
	end
end

-- данные игрока --
local player = {
	-- переменные
	x = 0,
	y = 0,
	x2 = 0,
	y2 = 0,
	xGrid = 0,
	yGrid = 0,
	xGrid2= 0,
	yGrid2= 0,
	xDraw = 0,
	yDraw = 0,
	name = "Маритур",
	hp=0,
	couldown = 5,
	abilities = {1,2},
	parameters = {
		strength = 16,
		agility = 12,
		intelligence = 10,
		willpower = 11,
		
		attack = 0,
		block = 0,
		accuracy = 0,
		defence = 0,
		
		health = 100000,
		dammage = 1,
		armour = 0
	},
	equipment = {
		armour = nil,
		weapon = nil,
		shield = nil,
		ring   = nil
	},
	inMove = false,
	image = image.load(path.playerSpritePath),
	squadImage = image.load(aSD .. "/player.pic")
}
	--функции
	function player.drawSelf(e)  buffer.image(windows.mainWindow.xMiddle-8+e.xDraw,windows.mainWindow.yMiddle-4+e.yDraw,e.image) end
	function player.moveRight(e) if not e.inMove and not mapMeetPlace(e.xGrid+1,e.yGrid)then player.xGrid2=player.xGrid2+1; ent = collisionTest(entitys,player); e.x2=e.x2+16; if not ent then e.inMove = true else e.x2=e.x2-16; entityFuncStart(ent) end end end
	function player.moveLeft(e)  if not e.inMove and not mapMeetPlace(e.xGrid-1,e.yGrid)then player.xGrid2=player.xGrid2-1; ent = collisionTest(entitys,player); e.x2=e.x2-16; if not ent then e.inMove = true else e.x2=e.x2+16; entityFuncStart(ent) end end end
	function player.moveDown(e)  if not e.inMove and not mapMeetPlace(e.xGrid,e.yGrid+1)then player.yGrid2=player.yGrid2+1; ent = collisionTest(entitys,player); e.y2=e.y2+ 8; if not ent then e.inMove = true else e.y2=e.y2- 8; entityFuncStart(ent) end end end
	function player.moveUp(e)    if not e.inMove and not mapMeetPlace(e.xGrid,e.yGrid-1)then player.yGrid2=player.yGrid2-1; ent = collisionTest(entitys,player); e.y2=e.y2- 8; if not ent then e.inMove = true else e.y2=e.y2+ 8; entityFuncStart(ent) end end end
	function player.moveSelf(e) 
		if e.x <  e.x2 then e.x =  e.x+2; e.xDraw=e.xDraw+2 end
		if e.x >  e.x2 then e.x =  e.x-2; e.xDraw=e.xDraw-2 end
		if e.y <  e.y2 then e.y =  e.y+1; e.yDraw=e.yDraw+1 end
		if e.y >  e.y2 then e.y =  e.y-1; e.yDraw=e.yDraw-1 end
		if e.y == e.y2 and  e.x == e.x2 then e.inMove = false; e.yDraw=0; e.xDraw=0; e.xGrid = math.floor(e.x/16); e.yGrid = math.floor(e.y/8) end
		e.xGrid2 = math.floor(e.x2/16)
		e.yGrid2 = math.floor(e.y2/8 )
	end
-------------------

-- генератор entity --
local function createEntity(x,y,imagePath,II,variables,func,arguments,oneUse)
	table.insert(entitys,{
		x=x,
		y=y,
		xStart=x,
		yStart=y,
		x2 = x,
		y2 = y,
		xGrid = math.floor(x/16),
		yGrid = math.floor(y/8 ),
		xGrid2= math.floor(x/16),
		yGrid2= math.floor(y/8 ),
		xDraw = 0,
		yDraw = 0,
		inMove = false,
		image=image.load(imagePath),
		variables=variables,
		II=II,
		arguments=arguments,
		func=func,
		oneUse=oneUse,
		drawSelf = function(e)
			buffer.image(e.x+windows.mainWindow.xMiddle-8-player.xGrid*16,e.y+windows.mainWindow.yMiddle-4-player.yGrid*8,e.image)
		end
	})
end

------------
-- ГРУППА --
local squad = {player}
local function addSquadMember(name,hp,parameters,equipment,imagePath)
	table.insert(squad,{
		name = name,
		hp = hp,
		couldown = 5,
		abilities = {1,2},
		parameters = {
			strength = parameters[1],
			agility = parameters[2],
			intelligence = parameters[3],
			willpower = parameters[4],
			
			attack = 0,
			block = 0,
			accuracy = 0,
			defence = 0,
			
			health = hp,
			dammage = 1,
			armour = 0
		},
		equipment = {
			armour = equipment[1],
			weapon = equipment[2],
			shield = equipment[3],
			ring   = equipment[4]
		},
		squadImage = image.load(imagePath),
	})
	for i in pairs(squad) do
		calculateAllCharacteristics(squad[i].parameters,squad[i].equipment)
	end
	selectedSquadMember = 1
end

local function useAbility(e)
	battle.ability=abilities[e[1]]
	battle.attacker=squad[battle.partyMemberTurn]
	battle.selectedEnemysCount=abilities[e[1]].targets
	battle.inAttack=true
	menuLock = true 
end

---------------------------- =====
--	ИНИЦИАЛИЗАЦИЯ ФУНКЦИЙ -- ==  ==
---------------------------- =====

-----------------------------
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ --
-----------------------------

-- функция возврвщает противника по имени --
local function getEnemy(name)
	for i in pairs(enemys) do
		if enemys[i].name == name then return enemys[i] end
	end
end

-- спизж... Взятый из флапи берд клик --
local function clicked(x, y, object)
	if x >= object[1] and y >= object[2] and x <= object[1]+object[3]-1 and y <= object[2]+object[4]-1 then
		return true
	end
	return false
end

-- обработка кнопок --

local function buttonsPress()
	for i in pairs(buttons) do
		buttons[i].press = 0
	end
end

----------------------
-- ОСНОВНЫЕ ФУНКЦИИ --
----------------------

-- Запуск entity II --

local function entitysII()
	for i in pairs(entitys) do
		if not entitys[i].inMove then
			entitys[i].II(entitys[i])
		end
	end
end

-- движение entity --

local function entitysMove()
	for i in pairs(entitys) do
		local e = entitys[i]
		if e.x < e.x2 then e.x=e.x+2; e.xDraw=e.xDraw+2 end
		if e.x > e.x2 then e.x=e.x-2; e.xDraw=e.xDraw-2 end
		if e.y < e.y2 then e.y=e.y+1; e.yDraw=e.yDraw+1 end
		if e.y > e.y2 then e.y=e.y-1; e.yDraw=e.yDraw-1 end
		if e.y == e.y2 and e.x == e.x2 then e.inMove = false end
		e.xGrid  = math.floor((e.x )/16);
		e.yGrid  = math.floor((e.y )/8 );
		e.xGrid2 = math.floor((e.x2)/16);
		e.yGrid2 = math.floor((e.y2)/8 );
	end
end

-- битва --

local function battleStart(enemys)
	battleLog = {}
	battleLogAddMesage("Battle begine!")
	selectedMenu = 3
	enemysInBattle = enemys
	enemyCount = getArraySize(enemysInBattle)
	for i in pairs(enemysInBattle) do
		enemysInBattle[i] = deepcopy(getEnemy(enemysInBattle[i]))
		enemysInBattle[i].name = "E" .. i .. ":" .. enemysInBattle[i].name
	end
	battle.turn = 1
	battle.side = 1
	battle.selectedEnemys = {}
	battle.selectedEnemysCount = 1
	battle.inAttack = false
	battle.partyMemberTurn = 1
	battle.ability = 1
	battle.selecter = 1
	battle.attacker = nil
	battle.experience = 0
	battle.gold = 0
	battleQueue = {}
	battle.selectedEnemysNum = {}
	menuLock = false
	inBattle = true
	battleLogAddMesage(squad[battle.partyMemberTurn].name .. " turn")
	battleLogInsertInDialog()
end

local function battleTurn()
	for i in pairs(battleQueue) do
		battleLogAddMesage("Attacker:" .. battleQueue[i].attacker.name)
		battleQueue[i].attacker.couldown = battleQueue[i].attacker.couldown-battleQueue[i].ability.couldown
		battleQueue[i].ability.func(battleQueue[i].attacker,battleQueue[i].targets,battleQueue[i].ability.arguments)
	end
	for i in pairs(enemysInBattle) do
		if enemysInBattle[i].hp < 1 then
			battle.gold       = math.floor(enemysInBattle[i].gold      *(math.random(1000,1200)/1100))
			battle.experience = math.floor(enemysInBattle[i].experience*(math.random(1000,1200)/1100))
			table.remove(enemysInBattle,i)
			enemyCount=enemyCount-1
			i=i-1
		end
	end
	for i in pairs(squad) do
		if squad[i].couldown > 0 then squad[i].couldown = squad[i].couldown - 1 end
		if squad[i].couldown < 0 then squad[i].couldown = squad[i].couldown + 1 end
	end
	menuLock = false
	battleQueue = {}
	battle.selectedEnemysNum = {}
	battle.partyMemberTurn = 1
	battle.turn = battle.turn + 1
	battle.side = 1
	battle.selectedEnemys = {}
	battle.selectedEnemysCount = 1
	battle.inAttack = false
	battle.partyMemberTurn = 1
	battle.selecter = 1
	battle.attacker=squad[battle.partyMemberTurn]
	selectedMenu = 3
	battleLogAddMesage("Turn " .. battle.turn)
	battleLogAddMesage(squad[battle.partyMemberTurn].name .. " turn")
	battleLogInsertInDialog()
end

local function nextMemberTurn()
	addActionToBattleQueue(battle.ability,battle.attacker,battle.selectedEnemys)
	battle.partyMemberTurn = battle.partyMemberTurn+1
	if battle.partyMemberTurn > getArraySize(squad) then battleTurn(); return end
	battle.side = 1
	battle.selectedEnemysNum = {}
	battle.selectedEnemys = {}
	battle.selectedEnemysCount = 1
	battle.inAttack = false
	battle.selecter = 1
	battle.attacker = squad[battle.partyMemberTurn]
	selectedMenu = 3
	menuLock = false
	battleLogAddMesage(squad[battle.partyMemberTurn].name .. " turn")
	battleLogInsertInDialog()
end

local function battleFinish(rewards, experience)
	selectedMenu = 0
	inBattle = false
	menuLock = false
end

------------------------
-- РАБОТА С КЛАВИШАМИ --
------------------------

local function keysUsage(e)
	keyCode = e
	if not inBattle then
		if e == 30 then player:moveLeft()  end
		if e == 32 then player:moveRight() end
		if e == 17 then player:moveUp()    end
		if e == 31 then player:moveDown()  end
	else
		if battle.inAttack then
			if e == 28 then 
				local selected = false
				for i in pairs(battle.selectedEnemysNum) do
					if battle.selectedEnemysNum[i] == battle.selecter then selected = true end
				end
				if not selected then
					table.insert(battle.selectedEnemys,enemysInBattle[battle.selecter])
					table.insert(battle.selectedEnemysNum,battle.selecter) 
					if getArraySize(battle.selectedEnemys) >= battle.selectedEnemysCount then nextMemberTurn() end 
				end
			end
			if e == 30 then battle.selecter=battle.selecter-1 if battle.selecter < 1 then battle.selecter = enemyCount end end
			if e == 32 then battle.selecter=battle.selecter+1 if battle.selecter > enemyCount then battle.selecter = 1 end end
		end
	end
end

-----------------------
-- ФУНКЦИИ ОТРИСОВКИ --
-----------------------

-- Отрисовка противников в бою --
local function drawEnemys()
	for i in pairs(enemysInBattle) do
		for r in pairs(battle.selectedEnemysNum) do
			if battle.inAttack and battle.selectedEnemysNum[r] == i then buffer.square(math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle-16,64,32,0xFFFFFF) end
		end
		buffer.image (math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle-16,enemysInBattle[i].image)
		buffer.square(math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle+16,64,1,0xFFFFFF)
		buffer.square(math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle+16,math.floor(64*(enemysInBattle[i].hp/enemysInBattle[i].parameters.health)),1,0xFF0000)
	end
	
	if battle.inAttack then 
		local i = battle.selecter
		buffer.square(math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle-16,64,32,0xEEEEEE)
		buffer.image (math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle-16,enemysInBattle[i].image)
		buffer.square(math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle+16,64,1 ,0xFFFFFF)
		buffer.square(math.floor(windows.mainWindow.width/(enemyCount+1))*i-32,windows.mainWindow.yMiddle+16,math.floor(64*(enemysInBattle[i].hp/enemysInBattle[i].parameters.health)),1,0xFF0000)
		
		buffer.square(1,windows.dialogWindow.y-1,windows.sideMenuWindow.x                                                                       ,1,0xFFFFFF)
		buffer.square(1,windows.dialogWindow.y-1,math.floor(windows.sideMenuWindow.x*(enemysInBattle[i].hp/enemysInBattle[i].parameters.health)),1,0xFF0000)
		buffer.text  (math.floor((windows.sideMenuWindow.x/2)-(string.len(enemysInBattle[i].hp.."/"..enemysInBattle[i].parameters.health)/2)),windows.dialogWindow.y-1,0x000000,enemysInBattle[i].hp.."/"..enemysInBattle[i].parameters.health)
	end
end

-- отрисовка entity --
local function entityDraw()
	for i in pairs(entitys) do
		entitys[i]:drawSelf()
	end
end

-- отрисовка кнопок --
local function buttonsDraw()
	for i in pairs(buttons) do
		buttons[i]:drawSelf()
	end
end

---------------------
-- отрисовка карты --

-- отрисовка пола --
local function drawMapBack()
	for i in pairs(mapBottom) do
		for r in pairs(mapBottom[i]) do
			buffer.image((r-1)*16+windows.mainWindow.xMiddle-8-player.xGrid*16,(i-1)*8+windows.mainWindow.yMiddle-4-player.yGrid*8,Tiles.background[mapBottom[i][r]])
		end
	end
end
-- отрисовка стен --
local function drawMapMiddle()
	for i in pairs(mapMiddle) do
		for r in pairs(mapMiddle[i]) do
			buffer.image((r-1)*16+windows.mainWindow.xMiddle-8-player.xGrid*16,(i-1)*8+windows.mainWindow.yMiddle-4-player.yGrid*8,Tiles.middle[mapMiddle[i][r]])
		end
	end
end
-- отрисовка крыши --
local function drawMapTop()
	for i in pairs(mapTop) do
		for r in pairs(mapTop[i]) do
			if	player.yGrid < i - 2 or
				player.yGrid > i + 0 or
				player.xGrid < r - 2 or
				player.xGrid > r + 0 
			then buffer.square((r-1)*16+windows.mainWindow.xMiddle-8-player.xGrid*16,(i-1)*8+windows.mainWindow.yMiddle-4-player.yGrid*8,16,8,Tiles.top[mapTop[i][r]]) end
		end
	end
end

--------------------------------
-- отрисовка диалогового окна --

local function drawDialogWindow()
	buffer.square(1,windows.dialogWindow.y,windows.dialogWindow.width,windows.dialogWindow.height      ,0x888888)
	buffer.square(1,windows.dialogWindow.y,windows.dialogWindow.width,1                                ,0x222222)
	if dialog.head.visible == true then
		buffer.image(1,windows.dialogWindow.y-16,dialog.head.image)
		if dialog.head.head then
			buffer.image(1,windows.dialogWindow.y-16,dialog.head.head)
		end
	end
	dialog:textFormat()
	dialog:textInDrawToText()
	for i in pairs(dialog.drawText) do
		buffer.text(2,windows.dialogWindow.y+1+i,0xBBBBBB,dialog.drawText[i])
	end
end

-----------------------------
-- отрисовка бокового меню --

local function drawSideMenu()
	local squadMember = squad[selectedSquadMember]

	buffer.square(windows.sideMenuWindow.x  , 1,windows.sideMenuWindow.width,windows.sideMenuWindow.height,0x888888          )
	buffer.square(windows.sideMenuWindow.x  , 1,2                           ,windows.sideMenuWindow.height,0x222222          )
	
	buffer.square(windows.sideMenuWindow.x+2, 1,windows.sideMenuWindow.width,7                            ,0xAAAAAA          )
	buffer.square(windows.sideMenuWindow.x+2, 8,windows.sideMenuWindow.width,1                            ,0x222222          )
	
	buffer.text(windows.sideMenuWindow.x+5 , 2, 0x000000, "strength:    " .. squadMember.parameters.strength    )
	buffer.text(windows.sideMenuWindow.x+5 , 3, 0x000000, "agility:     " .. squadMember.parameters.agility     )
	buffer.text(windows.sideMenuWindow.x+5 , 4, 0x000000, "intelligence:" .. squadMember.parameters.intelligence)
	buffer.text(windows.sideMenuWindow.x+5 , 5, 0x000000, "willpower:   " .. squadMember.parameters.willpower   )
	
	buffer.text(windows.sideMenuWindow.x+27, 2, 0x000000, "attack:      " .. squadMember.parameters.attack      )
	buffer.text(windows.sideMenuWindow.x+27, 3, 0x000000, "block:       " .. squadMember.parameters.block       )
	buffer.text(windows.sideMenuWindow.x+27, 4, 0x000000, "accuracy:    " .. squadMember.parameters.accuracy    )
	buffer.text(windows.sideMenuWindow.x+27, 5, 0x000000, "defence:     " .. squadMember.parameters.defence     )
	
	buffer.text(windows.sideMenuWindow.x+5 , 6, 0x000000, "health:      " .. squadMember.parameters.health      )
	buffer.text(windows.sideMenuWindow.x+27, 6, 0x000000, "armour:      " .. squadMember.parameters.armour      )
	buffer.text(windows.sideMenuWindow.x+5 , 7, 0x000000, "dammage:     " .. squadMember.parameters.dammage     )
	
	buffer.square(windows.sideMenuWindow.x+2,12,windows.sideMenuWindow.width,1               ,0x222222          )
	
	if     selectedMenu == 0 then 
		-- меню предметов
		local i = 13
		while i < windows.dialogWindow.y do
			if i%2==0 then
				buffer.square(windows.sideMenuWindow.x+2,i,windows.sideMenuWindow.width,1,0x777777)
			end
			i = i + 1
		end
		for i in pairs(inventory) do
			buffer.text(windows.sideMenuWindow.x+2,i+12,0x000000,inventory[i].name )
			buffer.text((buffer.screen.width+1)-string.len(inventory[i].count),i+12,0x000000,inventory[i].count)
		end
	elseif selectedMenu == 1 then
		-- броня
		buffer.square(windows.sideMenuWindow.x+2,13,windows.sideMenuWindow.width,6,0x777777)
		buffer.text(windows.sideMenuWindow.x+2,13,0x000000,"Armour")
		if squadMember.equipment.armour then
			buffer.text(windows.sideMenuWindow.x+2   ,14,0x000000,squadMember.equipment.armour.name)
			buffer.text(windows.sideMenuWindow.x+2   ,15,0x000000,"Attack  :" .. squadMember.equipment.armour.modifiers.attack  )
			buffer.text(windows.sideMenuWindow.x+2   ,16,0x000000,"Block   :" .. squadMember.equipment.armour.modifiers.block   )
			buffer.text(windows.sideMenuWindow.x+2+14,15,0x000000,"Accuracy:" .. squadMember.equipment.armour.modifiers.accuracy)
			buffer.text(windows.sideMenuWindow.x+2+14,16,0x000000,"Defence :" .. squadMember.equipment.armour.modifiers.defence )
			buffer.text(windows.sideMenuWindow.x+2   ,17,0x000000,"Health  :" .. squadMember.equipment.armour.modifiers.health  )
			buffer.text(windows.sideMenuWindow.x+2+14,17,0x000000,"Armour  :" .. squadMember.equipment.armour.modifiers.armour  )
			buffer.text(windows.sideMenuWindow.x+2   ,18,0x000000,squadMember.equipment.armour.description)
		end
		--
		
		-- Оружие
		
		buffer.text(windows.sideMenuWindow.x+2,19,0x000000,"Weapon")
		if squadMember.equipment.weapon then
			buffer.text(windows.sideMenuWindow.x+2   ,20,0x000000,squadMember.equipment.weapon.name)
			buffer.text(windows.sideMenuWindow.x+2   ,21,0x000000,"Attack  :" .. squadMember.equipment.weapon.modifiers.attack  )
			buffer.text(windows.sideMenuWindow.x+2   ,22,0x000000,"Block   :" .. squadMember.equipment.weapon.modifiers.block   )
			buffer.text(windows.sideMenuWindow.x+2+14,21,0x000000,"Accuracy:" .. squadMember.equipment.weapon.modifiers.accuracy)
			buffer.text(windows.sideMenuWindow.x+2+14,22,0x000000,"Defence :" .. squadMember.equipment.weapon.modifiers.defence )
			buffer.text(windows.sideMenuWindow.x+2   ,23,0x000000,"Health  :" .. squadMember.equipment.weapon.modifiers.health  )
			buffer.text(windows.sideMenuWindow.x+2+14,23,0x000000,"Dammage :" .. squadMember.equipment.weapon.modifiers.dammage )
			buffer.text(windows.sideMenuWindow.x+2   ,24,0x000000,squadMember.equipment.weapon.description)
		end
		--
		
		-- Щит
		buffer.square(windows.sideMenuWindow.x+2,25,windows.sideMenuWindow.width,6,0x777777)
		buffer.text(windows.sideMenuWindow.x+2,25,0x000000,"Shield")
		if squadMember.equipment.shield then
			buffer.text(windows.sideMenuWindow.x+2   ,26,0x000000,squadMember.equipment.shield.name)
			buffer.text(windows.sideMenuWindow.x+2   ,27,0x000000,"Attack  :" .. squadMember.equipment.shield.modifiers.attack  )
			buffer.text(windows.sideMenuWindow.x+2   ,28,0x000000,"Block   :" .. squadMember.equipment.shield.modifiers.block   )
			buffer.text(windows.sideMenuWindow.x+2+14,27,0x000000,"Accuracy:" .. squadMember.equipment.shield.modifiers.accuracy)
			buffer.text(windows.sideMenuWindow.x+2+14,28,0x000000,"Defence :" .. squadMember.equipment.shield.modifiers.defence )
			buffer.text(windows.sideMenuWindow.x+2   ,29,0x000000,"Health  :" .. squadMember.equipment.shield.modifiers.health  )
			buffer.text(windows.sideMenuWindow.x+2+14,29,0x000000,"Armour  :" .. squadMember.equipment.shield.modifiers.armour  )
			buffer.text(windows.sideMenuWindow.x+2   ,30,0x000000,squadMember.equipment.shield.description)
		end
		--
		
		-- Кольцо
		
		buffer.text(windows.sideMenuWindow.x+2,31,0x000000,"Ring")
		if squadMember.equipment.ring then
			buffer.text(windows.sideMenuWindow.x+2   ,32,0x000000,squadMember.equipment.ring.name  )
			buffer.text(windows.sideMenuWindow.x+2   ,33,0x000000,"Attack  :" .. squadMember.equipment.ring.modifiers.attack  )
			buffer.text(windows.sideMenuWindow.x+2   ,34,0x000000,"Block   :" .. squadMember.equipment.ring.modifiers.block   )
			buffer.text(windows.sideMenuWindow.x+2+14,33,0x000000,"Accuracy:" .. squadMember.equipment.ring.modifiers.accuracy)
			buffer.text(windows.sideMenuWindow.x+2+14,34,0x000000,"Defence :" .. squadMember.equipment.ring.modifiers.defence )
			buffer.text(windows.sideMenuWindow.x+2   ,35,0x000000,"Health  :" .. squadMember.equipment.ring.modifiers.health  )
			buffer.text(windows.sideMenuWindow.x+2+14,35,0x000000,"Armour  :" .. squadMember.equipment.ring.modifiers.armour  )
			buffer.text(windows.sideMenuWindow.x+2   ,36,0x000000,squadMember.equipment.ring.name  )
		end
		--

	elseif selectedMenu == 2 then
		-- меню группы
		
		for i in pairs(squad) do
			if i%2 == 0 then buffer.square(windows.sideMenuWindow.x+2,13+(i-1)*8,windows.sideMenuWindow.width,8,0x777777) end
			buffer.image(windows.sideMenuWindow.x+2,13+(i-1)*8,squad[i].squadImage)
			buffer.text(windows.sideMenuWindow.x+2+17,13+(i-1)*8,0x000000,squad[i].name)
			
			buffer.text(windows.sideMenuWindow.x+2+17  ,14+(i-1)*8,0x000000,"STR:" .. squad[i].parameters.strength)
			buffer.text(windows.sideMenuWindow.x+2+17  ,15+(i-1)*8,0x000000,"AGL:" .. squad[i].parameters.agility )
			buffer.text(windows.sideMenuWindow.x+2+17  ,16+(i-1)*8,0x000000,"INT:" .. squad[i].parameters.intelligence)
			buffer.text(windows.sideMenuWindow.x+2+17  ,17+(i-1)*8,0x000000,"WIL:" .. squad[i].parameters.willpower)
			
			buffer.text(windows.sideMenuWindow.x+2+17+9,14+(i-1)*8,0x000000,"ATT:" .. squad[i].parameters.attack)
			buffer.text(windows.sideMenuWindow.x+2+17+9,15+(i-1)*8,0x000000,"BLO:" .. squad[i].parameters.block )
			buffer.text(windows.sideMenuWindow.x+2+17+9,16+(i-1)*8,0x000000,"ACC:" .. squad[i].parameters.accuracy)
			buffer.text(windows.sideMenuWindow.x+2+17+9,17+(i-1)*8,0x000000,"DEF:" .. squad[i].parameters.defence)
			
			buffer.text(windows.sideMenuWindow.x+2+17  ,18+(i-1)*8,0x000000,"ARM:" .. squad[i].parameters.armour)
			buffer.text(windows.sideMenuWindow.x+2+17+9,18+(i-1)*8,0x000000,"DAM:" .. squad[i].parameters.dammage)
			
			buffer.text(windows.sideMenuWindow.x+2+17  ,19+(i-1)*8,0x000000,"HP: " .. squad[i].hp)
			buffer.text(windows.sideMenuWindow.x+2+17+9,19+(i-1)*8,0x000000,"HEA:" .. squad[i].parameters.health)
		end
	elseif selectedMenu == 3 then
		-- меню боя
		local squadMember = squad[battle.partyMemberTurn]
		buffer.square(           windows.sideMenuWindow.x+2                                  ,14,           windows.sideMenuWindow.width     ,1,0xFF0000)
		buffer.square(           windows.sideMenuWindow.x+2                                  ,14,math.floor(windows.sideMenuWindow.width/2)-2,1,0x00FF00)
		buffer.square(math.floor(windows.sideMenuWindow.x+2+windows.sideMenuWindow.width/2)-2,14,1                                           ,1,0xFFFF00)
		if squadMember.couldown >  0 then
			buffer.square(math.floor(windows.sideMenuWindow.x+2+windows.sideMenuWindow.width/2-(windows.sideMenuWindow.width/2)*(squadMember.couldown/ 32)      ),14,math.floor((windows.sideMenuWindow.width/2)*(squadMember.couldown/ 32)),1,0xFFFFFF)
			buffer.text  (math.floor(windows.sideMenuWindow.x+2+windows.sideMenuWindow.width/2-windows.sideMenuWindow.width/4-string.len(squadMember.couldown)/2),14,0x000000,tostring(squadMember.couldown))
		end
		if squadMember.couldown <  0 then
			buffer.square(math.floor(windows.sideMenuWindow.x+2+windows.sideMenuWindow.width/2                                                                  ),14,math.floor((windows.sideMenuWindow.width/2)*(squadMember.couldown/-32)),1,0xFFFFFF)
			buffer.text  (math.floor(windows.sideMenuWindow.x+2+windows.sideMenuWindow.width/2+windows.sideMenuWindow.width/4-string.len(squadMember.couldown)/2),14,0x000000,string.sub(tostring(squadMember.couldown),2))
		end
		if squadMember.couldown == 0 then
			buffer.text  (math.floor(windows.sideMenuWindow.x+2+windows.sideMenuWindow.width/2                                                                )-2,14,0x000000,"0")
		end
	elseif selectedMenu == 4 then
		-- меню магии
		
	elseif selectedMenu == 5 then
		-- меню умений
		for i in pairs(squad[battle.partyMemberTurn].abilities) do
			if i%2 then buffer.square(windows.sideMenuWindow.x+2,13+5*(i-1),windows.sideMenuWindow.width,5,0x777777) end
			buffer.text(windows.sideMenuWindow.x+2,13+5*(i-1),0x000000,abilities[squad[battle.partyMemberTurn].abilities[i]].name)
			buffer.text(buffer.screen.width - string.len("Couldown:" .. abilities[squad[battle.partyMemberTurn].abilities[i]].couldown),13+5*(i-1),0x000000,("Couldown:" .. abilities[squad[battle.partyMemberTurn].abilities[i]].couldown))
			local description = textFormat(abilities[squad[battle.partyMemberTurn].abilities[i]].description,windows.sideMenuWindow.width)
			for r in pairs(description) do
				buffer.text(windows.sideMenuWindow.x+2,14+5*(i-1)+r,0x000000,description[r])
			end
		end
	end
end

------------------------- =====
-- УПРАВЛЯЮЩИЕ ФУНКЦИИ -- ==  ==
------------------------- =====

-- центральная функция движения --
local function mainMove()
	if not inBattle then
		player:moveSelf()
		entitysMove()
		entitysII()
	end
end

-- центральная функция обработки ввода --
local function mainInput()
	buttonsPress()
	-- получение нажатий + антиОшибка --
	local e = {event.pull(config.FPS)}
	-- обработка клавиатуры --
	if e[1] == "key_down" then
		keysUsage(e[4])
	end
	if e[1] == "touch" then
		if battle.inAttack then
			for i in pairs(battle.selectedEnemysNum) do
				if battle.selectedEnemysNum[i] == battle.selecter then selected = true end
			end
			if not selected then
				table.insert(battle.selectedEnemys,enemysInBattle[battle.selecter])
				table.insert(battle.selectedEnemysNum,battle.selecter) 
				if getArraySize(battle.selectedEnemys) >= battle.selectedEnemysCount then nextMemberTurn() end 
			end
			return
		end
		for i in pairs(buttons) do
			if clicked(e[3], e[4], buttons[i].square) and buttons[i].condition() then
				buttons[i].press = 1
				buttons[i].func(buttons[i].arguments)
				return
			end
		end
		if     selectedMenu == 0 then
			for i in pairs(inventory) do
				local squadMember = squad[selectedSquadMember]
				if clicked(e[3], e[4], {windows.sideMenuWindow.x,12+i,buffer.screen.width-windows.sideMenuWindow.x,1}) then
					--putInInventory(inventory[i].name, inventory[i].category)
					if inventory[i].category == itemCategories.armours then 
						if squadMember.equipment.armour then
							putInInventory(squadMember.equipment.armour.name,itemCategories.armours)
							squadMember.equipment.armour = nil
						end
						squadMember.equipment.armour=itemCategories.armours[itemFind(itemCategories.armours,inventory[i].name)]
					end
					if inventory[i].category == itemCategories.weapons then 
						if squadMember.equipment.weapon then
							putInInventory(squadMember.equipment.weapon.name,itemCategories.weapons)
							squadMember.equipment.weapon = nil
						end
						squadMember.equipment.weapon=itemCategories.weapons[itemFind(itemCategories.weapons,inventory[i].name)]
					end
					if inventory[i].category == itemCategories.rings then 
						if squadMember.equipment.ring then
							putInInventory(squadMember.equipment.ring.name,itemCategories.rings)
							squadMember.equipment.ring = nil
						end
						squadMember.equipment.ring=itemCategories.rings[itemFind(itemCategories.rings,inventory[i].name)]
					end
					if inventory[i].category == itemCategories.shields then 
						if squadMember.equipment.shield then
							putInInventory(squadMember.equipment.shield.name,itemCategories.shields)
							squadMember.equipment.shield = nil
						end
						squadMember.equipment.shield=itemCategories.shields[itemFind(itemCategories.shields,inventory[i].name)]
					end
					inventory[i].count=inventory[i].count-1
					if inventory[i].count<1 then table.remove(inventory,i) end
					calculateAllCharacteristics(squadMember.parameters,squadMember.equipment)
				end
			end
		elseif selectedMenu == 1 then
			local squadMember = squad[selectedSquadMember]
			if clicked(e[3], e[4], {windows.sideMenuWindow.x,13+0*6,buffer.screen.width-windows.sideMenuWindow.x,6}) then
				if squadMember.equipment.armour then
					putInInventory(squadMember.equipment.armour.name,itemCategories.armours)
					squadMember.equipment.armour = nil
				end
			end
			if clicked(e[3], e[4], {windows.sideMenuWindow.x,13+1*6,buffer.screen.width-windows.sideMenuWindow.x,6}) then
				if squadMember.equipment.weapon then
					putInInventory(squadMember.equipment.weapon.name,itemCategories.weapons)
					squadMember.equipment.weapon = nil
				end
			end
			if clicked(e[3], e[4], {windows.sideMenuWindow.x,13+2*6,buffer.screen.width-windows.sideMenuWindow.x,6}) then
				if squadMember.equipment.shield then
					putInInventory(squadMember.equipment.shield.name,itemCategories.shields)
					squadMember.equipment.shield = nil
				end
			end
			if clicked(e[3], e[4], {windows.sideMenuWindow.x,13+3*6,buffer.screen.width-windows.sideMenuWindow.x,6}) then
				if squadMember.equipment.ring then
					putInInventory(squadMember.equipment.ring.name,itemCategories.rings)
					squadMember.equipment.ring = nil
				end
			end
			calculateAllCharacteristics(squadMember.parameters,squadMember.equipment)
		elseif selectedMenu == 2 then
			for i in pairs(squad) do
				if clicked(e[3], e[4], {windows.sideMenuWindow.x,13+(i-1)*8,buffer.screen.width-windows.sideMenuWindow.x,8}) then
					selectedSquadMember = i;
				end
			end
		elseif selectedMenu == 3 then
		
		elseif selectedMenu == 4 then
		
		elseif selectedMenu == 5 then
			for i in pairs(squad[battle.partyMemberTurn].abilities) do
				if clicked(e[3], e[4], {windows.sideMenuWindow.x,13+(i-1)*5,buffer.screen.width-windows.sideMenuWindow.x,8}) then
					useAbility({squad[battle.partyMemberTurn].abilities[i]})
				end
			end
		end
	end
end

-- центральная функция отрисовки --
local function mainDraw()
	local frameRenderClock = os.clock()
	
	-- заливка буфера --
	buffer.clear(0x56DBFF)
	
	-- тело вывода в буфер --
	if not inBattle then
		drawMapBack()
		drawMapMiddle()
		player:drawSelf()
		entityDraw()
		drawMapTop()
	else
		drawEnemys()
	end
	drawDialogWindow()
	drawSideMenu()
	buttonsDraw()
	
	for i in pairs(entitys) do
		for r in pairs(entitys[i].variables) do
			buffer.text(2+2*i,1+1*r,0x000000,entitys[i].variables[r])
		end
	end
	
	buffer.text(1 , 1, 0x000000,"freeRAM: "    .. math.doubleToString( computer.freeMemory()          / 1024, 2) .. " KB")
	buffer.text(32, 1, 0x000000,"renderTime: " .. math.doubleToString((os.clock() - frameRenderClock) * 1000, 2) .. " ms")
	buffer.text(64, 1, 0x000000,"Key: "        .. keyCode)
	--buffer.text(96, 1, 0x000000,"Dammage: " .. getDammage(7,7,167))
	--for i in pairs(battle.selectedEnemysNum) do
	--	  buffer.text(96, 1+i, 0x000000, battle.selectedEnemysNum[i] .. "  1")
	--end
	buffer.text(64, 2, 0x000000, "menuLock: " .. tostring(menuLock))
	-- отрисовка изменений --
	buffer.draw()
end

-- главный цикл --
local function mainLoop()
	while true do
		mainInput()
		mainMove()
		mainDraw()
	end
end

------------------- =====
-- ИНИЦИАЛИЗАЦИЯ -- ==  ==
------------------- =====

-- Создание способностей
local function powerAttack(attacker,targets,arguments)
	for i in pairs(targets) do
		local dam = (getDammage(attacker.parameters.attack,targets[i].parameters.defence,attacker.parameters.dammage))*3
		dam = dam - targets[i].parameters.armour
		if dam <= 0 then dam = 1 end
		targets[i].hp = targets[i].hp - dam
		battleLogAddMesage("Target " .. i .. ":" .. targets[i].name .. " take " .. dam .. " dammage")
	end
end
createAbilities("Power attack","Герой ябашит как всемогущий нанося тройной урон одному противнику",1,powerAttack,5,{})
local function powerAttack(attacker,targets,arguments)
	for i in pairs(targets) do
		local dam = (getDammage(attacker.parameters.attack,targets[i].parameters.defence,attacker.parameters.dammage))
		dam = dam - targets[i].parameters.armour
		if dam <= 0 then dam = 1 end
		targets[i].hp = targets[i].hp - dam
		battleLogAddMesage("Target " .. i .. ":" .. targets[i].name .. " take " .. dam .. " dammage")
	end
end
createAbilities("Fisting rain","Разбивает лица сразу трем противникам",3,powerAttack,6,{})

-- функции элементов
local function none(n) return true end

local function collisionToPlayer(e,x,y)
	if (e.xGrid2+x == player.xGrid or e.xGrid2+x == player.xGrid2) and
	   (e.yGrid2+y == player.yGrid or e.yGrid2+y == player.yGrid2) then return true end
	return false
end

local function moveRight(e)
	if not collisionToPlayer(e, 1, 0) and not e.inMove then
		e.x2=e.x2+16;
		e.inMove=true;
		return true;
	end	
	return false
end

local function moveLeft(e)
	if not collisionToPlayer(e,-1, 0) and not e.inMove then
		e.x2=e.x2-16;
		e.inMove=true;
		return true;
	end	
	return false
end

local function moveDown(e)
	if not collisionToPlayer(e, 0, 1) and not e.inMove then
		e.y2=e.y2+8 ;
		e.inMove=true;
		return true;
	end	
	return false
end

local function moveUp(e)
	if not collisionToPlayer(e, 0,-1) and not e.inMove then
		e.y2=e.y2-8 ;
		e.inMove=true;
		return true;
	end	
	return false
end

local function moveRound(e)
	if not e.inMove then
		if e.variables[1] == 3 then if moveUp   (e) then e.variables[1]=0 end return end
		if e.variables[1] == 2 then if moveLeft (e) then e.variables[1]=3 end return end
		if e.variables[1] == 1 then if moveDown (e) then e.variables[1]=2 end return end
		if e.variables[1] == 0 then if moveRight(e) then e.variables[1]=1 end return end
	end
end

local function switchMenu(e)
	if not menuLock then
		if selectedMenu > 2 or not inBattle then 
			selectedMenu = e[1]
		end
	end
end

local function menuEquallyThree()
	if selectedMenu == 3 then return true end
	return false
end

-- шлепаем кнопки
-- local function createButton(square,bgcolor,text,color,func)
createButton({windows.sideMenuWindow.x+math.floor((windows.sideMenuWindow.width-2)/3)*0+2,   9,math.floor((windows.sideMenuWindow.width-2)/3),3}, 0x55DDDD, "ITEMS"    , 0x000000, none            , switchMenu  , {0})
createButton({windows.sideMenuWindow.x+math.floor((windows.sideMenuWindow.width-2)/3)*1+2,   9,math.floor((windows.sideMenuWindow.width-2)/3),3}, 0xDD55DD, "EQUIP"    , 0x000000, none            , switchMenu  , {1})
createButton({windows.sideMenuWindow.x+math.floor((windows.sideMenuWindow.width-2)/3)*2+2,   9,math.floor((windows.sideMenuWindow.width-2)/3),3}, 0xDDDD55, "SQUAD"    , 0x000000, none            , switchMenu  , {2})
createButton({windows.sideMenuWindow.x                                                 +2,14+7,math.floor((windows.sideMenuWindow.width-2)  ),4}, 0xDDDD55, "ATTACK"   , 0x000000, menuEquallyThree, useAbility  , {1})
createButton({windows.sideMenuWindow.x                                                 +2,18+7,math.floor((windows.sideMenuWindow.width-2)  ),4}, 0xDDDD55, "DEFENCE"  , 0x000000, menuEquallyThree, useAbility  , {2})
createButton({windows.sideMenuWindow.x                                                 +2,22+7,math.floor((windows.sideMenuWindow.width-2)  ),4}, 0xDDDD55, "MAGIC"    , 0x000000, menuEquallyThree, switchMenu  , {4})
createButton({windows.sideMenuWindow.x                                                 +2,26+7,math.floor((windows.sideMenuWindow.width-2)  ),4}, 0xDDDD55, "ABILITIES", 0x000000, menuEquallyThree, switchMenu  , {5})
createButton({windows.sideMenuWindow.x                                                 +2,30+7,math.floor((windows.sideMenuWindow.width-2)  ),4}, 0xDDDD55, "RUN"      , 0x000000, menuEquallyThree, battleFinish, { })

-- гладим котиков
-- local function createEnemy(name,hp,s,a,i,w,hea,arm,dam,imagePath,modifiers)
createEnemy("slime",75,45,15,15,10,5,5,75,4,50,aBED .. "/slime.pic",{0,0,0,0,0,0,0})

-- рисуем квадраты
-- local function createEntity(x,y,imagePath,func)
createEntity(4*16,2*8,aED .. "/slime.pic",none     ,{0},battleStart,{"slime","slime","slime"},true )
createEntity(4*16,4*8,aED .. "/def.pic"  ,none     ,{0},none       ,{}                       ,true )
createEntity(4*16,6*8,aED .. "/def.pic"  ,moveRound,{0},none       ,{}                       ,false)

-- создаем легендарную адамантовую плиту усыпаную гранеными камнями и с изображением дворфа жующего мыло
-- local function itemCreator(category,name,modifiers,func,canUse,oneUse,description)
---                                 ---
-- itemCategories.armours            --
-- itemCategories.weapons            --
-- itemCategories.rings              --
-- itemCategories.shields            --
-- itemCategories.potions            --
-- itemCategories.scrolls            --
-- itemCategories.other              --
---                                 ---
-- modifiers.attack   = modifiers[1] --
-- modifiers.block    = modifiers[2] --
-- modifiers.accuracy = modifiers[3] --
-- modifiers.defence  = modifiers[4] --
-- modifiers.health   = modifiers[5] --
-- modifiers.dammage  = modifiers[6] --
-- modifiers.armour   = modifiers[7] --
---                                 ---
itemCreator(itemCategories.armours,"Броня из хитина жука",{0,0,12,0,1500,0 ,65},none,false,false,"Сделанно из жуков с южного побережья Лиссона")
itemCreator(itemCategories.weapons,"Топор"               ,{0,0,0 ,0,0   ,15,0 },none,false,false,"Топор для рубки древесины... или врагов"     )

-- нанимаем анимешных тян в группу 
--local function addSquadMember(name,hp,parameters,equipment,imagePath)
addSquadMember("Лин",15000,{10,10,15,15},{nil,nil,nil,nil},aSD .. "/Lin.pic")

-- получаем посылку с почты
local i = 120
while i > 0 do
	putInInventory("Predmet1", itemCategories.other)
	i = i - 1
end
putInInventory("Predmet7", itemCategories.other)
putInInventory("Predmet5", itemCategories.other)
putInInventory("Predmet5", itemCategories.other)
putInInventory("Predmet6", itemCategories.other)
putInInventory("Predmet2", itemCategories.other)
putInInventory("Predmet3", itemCategories.other)
putInInventory("Predmet4", itemCategories.other)
putInInventory("Predmet4", itemCategories.other)
putInInventory("Predmet4", itemCategories.other)
putInInventory("Predmet8", itemCategories.other, 999)
putInInventory("Predmet8", itemCategories.other, 999)

player.equipment.armour = itemCategories.armours[1]
player.equipment.weapon = itemCategories.weapons[1]
table.insert(player.abilities,3)
table.insert(player.abilities,4)

calculateAllCharacteristics(player.parameters,player.equipment)

-- запуск игры--
mainLoop()
