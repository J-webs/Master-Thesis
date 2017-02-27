--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
-- MOVEMENT RELATED HELPER FUNCTIONS, by Janine Weber @ 2017
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

local _G = getfenv(0)
local object = _G.object

object.jGeneralMovement = object.jGeneralMovement or {}
local core, eventsLib, behaviorLib, metadata, jNN, jGeneral, jDataWriter,
			jGeneralMovement = object.core, object.eventsLib, object.behaviorLib,
												 object.metadata, object.jNN, object.jGeneral,
												 object.jDataWriter, object.jGeneralMovement

local print, ipairs, pairs, string, table, next, type, tinsert,
			tremove, tsort, format, tostring, tonumber, strfind, strsub
				= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next,
					_G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format,
					_G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
				= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan,
				 	_G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos,
					_G.math.asin, _G.math.max, _G.math.random

local mapParameters = mapParameters or {}

function jGeneralMovement.initMapParameters(minCoordinate, maxCoordinate, legionSpawn, hellbourneSpawn, legionTower, hellbourneTower)
	-- map max/min coordinates
  mapParameters.minCoord = minCoordinate
  mapParameters.maxCoord = maxCoordinate

	-- max squared root distance of map
	mapParameters.maxDistanceSq = (mapParameters.maxCoord - mapParameters.minCoord)*(mapParameters.maxCoord - mapParameters.minCoord)*2

	-- center positions
	mapParameters.center = (mapParameters.maxCoord - mapParameters.minCoord)/2
  mapParameters.halfCenter = mapParameters.maxCoord/4

	-- hero spawns
  mapParameters.legiSpawn = legionSpawn
  mapParameters.hellSpawn = hellbourneSpawn

	-- tower positions
	mapParameters.legionTower = legionTower
	mapParameters.hellbourneTower = hellbourneTower

	-- unit specific parameters
	mapParameters.unitRange = core.GetExtraRange(core.unitSelf)
	mapParameters.unitRangeSq = mapParameters.unitRange * mapParameters.unitRange
	mapParameters.unitTargetWidths = 2*mapParameters.unitRange
	mapParameters.unitTargetWidthsSq = mapParameters.unitTargetWidths*mapParameters.unitTargetWidths
end

function jGeneralMovement.getLegionTower()
	return Vector3.Create(mapParameters.legionTower, mapParameters.legionTower)
end

function jGeneralMovement.getHellbourneTower()
	return Vector3.Create(mapParameters.hellbourneTower, mapParameters.hellbourneTower)
end

-- hero distance to center [-1(at center), 1(max distance)]
function jGeneralMovement.getDistanceToCenter(unit)
	 local unitX = unit:GetPosition().x - mapParameters.minCoord
	 local unitY = unit:GetPosition().y - mapParameters.minCoord
	 local distX = abs(unitX - mapParameters.center)*2/mapParameters.center - 1
	 local distY = abs(unitY - mapParameters.center)*2/mapParameters.center - 1
	 return distX, distY
end

-- distance between heroes [-1(on top of each other), 1(max distance)]
function jGeneralMovement.getDistanceBetweenHeroes(unitSelfPos,unitTargetPos)
	local distance = Vector3.Distance2DSq(unitSelfPos, unitTargetPos)
	return distance*2/mapParameters.maxDistanceSq - 1
end

-- order hero to move to specified position
function jGeneralMovement.move(pos, interruptAA, queue, shouldHold, shouldClamp)
	local unitSelf = core.unitSelf
  if shouldHold then
    if shouldClamp then
      core.OrderMoveToPosAndHoldClamp(object, unitSelf, pos, interruptAA, queue)
    else
      core.OrderMoveToPosAndHold(object, unitSelf, pos, interruptAA, queue)
    end
  else
    if shouldClamp then
      core.OrderMoveToPosClamp(object, unitSelf, pos, interruptAA, queue)
    else
      core.OrderMoveToPos(object, unitSelf, pos, interruptAA, queue)
    end
  end
end

-- flee towards appropriate tower
function jGeneralMovement.flee_wM(interruptAA, queue, shouldHold, shouldClamp)
	local unitSelf = core.unitSelf
	local team = unitSelf:GetTeam()
	local newPos
	if team == 1 then
		newPos = Vector3.Create(200, 550)
	else
		newPos = Vector3.Create(mapParameters.hellbourneTower+400, mapParameters.hellbourneTower+400)
	end
	jGeneralMovement.move(newPos, interruptAA, queue, shouldHold, shouldClamp)
end

-- legacy function
function jGeneralMovement.vectorFromTo(fromPos, toPos)
  local from_xScaled = fromPos.x - mapParameters.minCoord
  local from_yScaled = fromPos.y - mapParameters.minCoord
  local to_xScaled = toPos.x - mapParameters.minCoord
  local to_yScaled = toPos.y - mapParameters.minCoord
  local targetX = to_xScaled - from_xScaled
  local targetY = to_yScaled - from_yScaled
  local vecLength = math.sqrt(targetX*targetX + targetY*targetY)

  local direction = {}
  direction.x = targetX/vecLength
  direction.y = targetY/vecLength
  return direction
end

-- legacy function
function jGeneralMovement.distanceToBorders(unit)
  local unitX = unit:GetPosition().x
  local unitY = unit:GetPosition().y

  local distance = {}
  distance.toW = unitX - mapParameters.minCoord
  distance.toE = mapParameters.maxCoord - unitX
  distance.toN = mapParameters.maxCoord - unitY
  distance.toS = unitY - mapParameters.minCoord

  return distance
end

-- move towards opponent (hero)
function jGeneralMovement.moveTowardsOpponent(unitTarget, interruptAA, queue, shouldHold, shouldClamp)
	local disttotower = Vector3.Distance2D(core.unitSelf:GetPosition(), object.myTower:GetPosition())
	if disttotower < 300 then
		-- have to walk around our own tower first
		local myx = core.unitSelf:GetPosition().x
		local myy = core.unitSelf:GetPosition().y

		local disttoborderx = math.abs(myx-150)
		local disttobordery = math.abs(myy-150)

		if disttoborderx < disttobordery then
			jGeneralMovement.move(Vector3.Create(200, 1500), interruptAA, queue, shouldHold, shouldClamp)
		else
			jGeneralMovement.move(Vector3.Create(1500, 200), interruptAA, queue, shouldHold, shouldClamp)
		end
	else
		-- move directly towards enemy
		jGeneralMovement.move(unitTarget:GetPosition(), interruptAA, queue, shouldHold, shouldClamp)
	end
end
-- move towards oppnent (tower)
function jGeneralMovement.moveTowardsOpponentTower(interruptAA, queue, shouldHold, shouldClamp)
	local disttotower = Vector3.Distance2D(core.unitSelf:GetPosition(), object.myTower:GetPosition())
	if disttotower < 300 then
		-- have to walk around our own tower first
		local myx = core.unitSelf:GetPosition().x
		local myy = core.unitSelf:GetPosition().y

		local disttoborderx = math.abs(myx-150)
		local disttobordery = math.abs(myy-150)

		if disttoborderx < disttobordery then
			jGeneralMovement.move(Vector3.Create(200, 1500), interruptAA, queue, shouldHold, shouldClamp)
		else
			jGeneralMovement.move(Vector3.Create(1500, 200), interruptAA, queue, shouldHold, shouldClamp)
		end
	else
		-- move directly towards enemy tower
		local unitSelf = core.unitSelf
		if unitSelf:GetTeam() == 1 then
			jGeneralMovement.move(Vector3.Create(mapParameters.hellbourneTower, mapParameters.hellbourneTower), interruptAA, queue, shouldHold, shouldClamp)
		else
			jGeneralMovement.move(Vector3.Create(mapParameters.legionTower, mapParameters.legionTower), interruptAA, queue, shouldHold, shouldClamp)
		end
	end
end

-- legacy function
function jGeneralMovement.getAngle(unitLocation, targetLocation)
  local dx = targetLocation.x - unitLocation.x
  local dy = targetLocation.y - unitLocation.y
  local theta = atan2(dy, dx)
  local degree = theta * 180 / pi
  if theta < 0 then
    degree = theta + 360
  end
  return degree
end

-- legacy function
function jGeneralMovement.withinLimits(coord)
	if coord >= mapParameters.minCoord and coord <= mapParameters.maxCoord then
		return true
	else
		return false
	end
end

function jGeneralMovement.isInRange()
	local newpos = Vector3.Create(randomX, randomY)
	local dist = Vector3.Distance2DSq(core.unitSelf:GetPosition(), newpos)
	if dist <= 12000 then
		return true
	else
		return false
	end
end

function jGeneralMovement.attack(unitTarget, queue, shouldClamp)
  if shouldClamp then
    core.OrderAttackClamp(object, core.unitSelf, unitTarget, queue)
  else
    core.OrderAttack(object, core.unitSelf, unitTarget, queue)
  end
end
function jGeneralMovement.attackTurret(enemyTurret, queue, shouldClamp)
	if shouldClamp then
		core.OrderAttackClamp(object, core.unitSelf, enemyTurret, queue)
	else
		core.OrderAttack(object, core.unitSelf, enemyTurret, queue)
	end
end
function jGeneralMovement.attackCreep(enemyCreep, queue, shouldClamp)
	if shouldClamp then
		core.OrderAttackClamp(object, core.unitSelf, enemyCreep, queue)
	else
		core.OrderAttack(object, core.unitSelf, enemyCreep, queue)
	end
end

function jGeneralMovement.standstill(interruptAA, queue, shouldClamp)
  if shouldClamp then
    core.OrderHoldClamp(object, core.unitSelf, interruptAA, queue)
  else
    core.OrderHold(object, core.unitSelf, interruptAA, queue)
  end
end
