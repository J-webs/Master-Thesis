--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
-- GENERAL HELPER FUNCTIONS (hero independent), by Janine Weber @ 2017
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

local _G = getfenv(0)
local object = _G.object

object.jGeneral = object.jGeneral or {}
local core, eventsLib, behaviorLib, metadata, skills,
			jNN, jGeneral, jDataWriter, jGeneralMovement,
			jSuccubusMisc = object.core, object.eventsLib, object.behaviorLib,
											object.metadata, object.skills, object.jNN, object.jGeneral,
											object.jDataWriter, object.jGeneralMovement, object.jSuccubusMisc

local print, ipairs, pairs, string, table, next, type, tinsert,
			tremove, tsort, format, tostring, tonumber, strfind, strsub
				= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next,
					_G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format,
					_G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
				= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan,
					_G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos,
					_G.math.asin, _G.math.max, _G.math.random

-------------------------------------------------------------------------------
--						  SCALE ABILITY CD [-1(just used), 1(available)]							 --
-------------------------------------------------------------------------------
function jGeneral.scaleCD_ts(timestamp, cd)
	local timePassed = HoN.GetMatchTime() - timestamp
	local scaledCD = timePassed*2/cd - 1
	local over = false
	if (timePassed+50) >= cd then
		over = true
		scaledCD = 1
	end
	return over, scaledCD
end
function jGeneral.scaleCD_tr(timeRemaining, cd)
	local timePassed = cd - timeRemaining
	local scaledCD = timePassed*2/cd - 1
	if (timePassed+50) >= cd then
		scaledCD = 1
	end
	return scaledCD
end

-------------------------------------------------------------------------------
--						  SCALE BUFF DURATION [-1(none), 1(just applied)]							 --
-------------------------------------------------------------------------------
function jGeneral.scaleBuff(timestamp, duration)
	local timePassed = HoN.GetMatchTime() - timestamp
	local timeRemaining = duration - timePassed
	local scaledCD = timeRemaining*2/duration - 1
	local over = false
	if (timePassed+50) >= duration then
		over = true
		scaledCD = -1
	end
	return over, scaledCD
end

-- random int value between low-high values
function jGeneral.jRandom(low,high)
	local jrnd = random()*(high-low)+low
	return round(jrnd)
end
-- random real int value between low-high values
function jGeneral.jRandomWeights(low,high)
  local jrnd = random()*(high-low)+low
  if jGeneral.jRandom(1,2)==1 then
    jrnd = jrnd*(-1)
  end
  return jrnd
end

-- hero unit within AA range?
function jGeneral.withinAARange(unitSelf,unitTarget)
	if core.IsUnitInRange(unitSelf,unitTarget,false) then
		return 1
	else
		return -1
	end
end

-- can hero AA opp tower?
function jGeneral.withinTowerAARange()
	local unitSelf = core.unitSelf
	if object.oppTower ~= nil and object.oppTower:IsTower() then
		local range = core.GetAbsoluteAttackRangeToUnit(unitSelf, object.oppTower)
		range = range*range
		local oppTowerPos
		if unitSelf:GetTeam() == 1 then
			oppTowerPos = Vector3.Create(2520,2520) -- hellbourne
		else
			oppTowerPos = Vector3.Create(550,550)		-- legion
		end
		local myDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), oppTowerPos)
		if myDistanceSq < range then
			return 1
		else
			return -1
		end
	else
		return -1
	end
end

-------------------------------------------------------------------------------
--						 							 PROCESS ALL GAME UNITS 												 --
-------------------------------------------------------------------------------
function jGeneral.processUnits(object, tGameVariables)
	StartProfile('onthink')
	if core.coreInitialized == false or core.coreInitialized == nil then
		core.CoreInitialize(object) -- core functions
	end
	if metadata.bInitialized == false then
		metadata.Initialize(tGameVariables.sMapName) -- map data
	end
	 if core.botBrainInitialized == false or core.unitSelf == nil then
	 	core.BotBrainCoreInitialize(tGameVariables) -- bot functions
	 end
	 if object.bRunLogic == false then
	 	StopProfile()
	 	return
	 end
	local nGameTime = HoN.GetGameTime()
	local unitSelf = core.unitSelf
	if object.bUpdates ~= false then
		StartProfile('Updates')
			StartProfile('Update unit collections')
				core.UpdateLocalUnits(object)
				core.UpdateControllableUnits(object)
				core.UpdateCreepTargets(object)
			StopProfile()

			StartProfile('Update Events')
				eventsLib.UpdateRecentEvents()
			StopProfile()

			core.UpdateLane()
			core.FindItems(object)
		StopProfile()
	end
	StartProfile('Validate')
	core.ValidateUnitReferences()
	StopProfile()

	StartProfile('Skills')
	if object.SkillBuild then
		object:SkillBuild() -- bot ability skill ups
	end
	StopProfile()

	-- behavior assessment
	StartProfile('Assess behaviors')
	if nGameTime >= behaviorLib.nNextBehaviorTime then
		object.tEvaluatedBehaviors = {}
		core.AssessBehaviors(object.tEvaluatedBehaviors)
	end
	StopProfile()
end

-- game setup parameters
function jGeneral.setupHeroes()
	Cmd("set hero_respawnTime 100000")
	Cmd("set hero_expBountyTable 0")
	Cmd("set g_experienceRange 0")
	Cmd("set hero_maxLevel 16")
	Cmd("set hero_expUnsharedBountyTable 0")
	Cmd("set g_creepMaxUpgrades 0")
	Cmd("set g_creepMeleeCount \"4,4,4,4,4,4\"")
	Cmd("set g_creepRangedCount \"2,2,2,2,2,2\"")
	Cmd("set g_creepSiegeCount \"0,0,0,0,0,0\"")
	Cmd("set g_creepMeleeFormationCount \"43,43,43,43,43,43\"")
	Cmd("set g_creepRangedFormationCount \"43,43,43,43,43,43\"")
end

-- level up heroes
function jGeneral.levelUpHero(lvl, heroId)
	Cmd("ResetExp "..heroId)
	for i=1,(lvl-1) do
		Cmd("LevelUp "..heroId)
	end
end

-- get notable units (opp hero, towers)
function jGeneral.setupObjects()
	local tEnemyHeroes = HoN.GetHeroes(core.enemyTeam)
	for _, unitHero in pairs(tEnemyHeroes) do
		object.myOpponent = unitHero
		break
	end

	local tTowers = core.allyTowers
	if core.NumberElements(tTowers) > 0 then
		for id, tower in pairs(tTowers) do
			object.myTower = tower
		end
	end

	local tTowers = core.enemyTowers
	if core.NumberElements(tTowers) > 0 then
		for id, tower in pairs(tTowers) do
			object.oppTower = tower
		end
	end
end

-------------------------------------------------------------------------------
--						 							 CHECK MATCH SITUATION 													 --
-------------------------------------------------------------------------------
function jGeneral.getGameStats()
	local selfDead = false
	local oppDead = false
	local selfCreeps = false
	local oppCreeps = false
	local selfTower = false
	local oppTower = false

	-- any agent dead?
	if core.unitSelf and not core.unitSelf:IsAlive() then
		selfDead = true
	end
	if object.myOpponent and not object.myOpponent:IsAlive() then
		oppDead = true
	end
	-- any agent reached creep score?
	if core.unitSelf and
				(core.unitSelf:GetCreepKills()-object.selfCreepKills) >= object.neededCreeps then
		selfCreeps = true
	end
	if object.myOpponent and
				(object.myOpponent:GetCreepKills()-object.enemyCreepKills) >= object.neededCreeps then
		oppCreeps = true
	end
	-- any towers destroyed?
	if (object.tYi[43] <= -1) or
				(object.selfTower ~= nil and not object.selfTower:IsAlive()) or
				(core.NumberElements(core.allyTowers) <= 0) then
		selfTower = true
	end
	if (object.tYi[44] <= -1) or
				(object.oppTower ~= nil and not object.oppTower:IsAlive()) or
				(core.NumberElements(core.enemyTowers) <= 0)  then
		oppTower = true
	end

	return selfDead, oppDead, selfCreeps, oppCreeps, selfTower, oppTower
end
-------------------------------------------------------------------------------
--				 							 CHECK MATCH END CONDITIONS 												 --
-------------------------------------------------------------------------------
function jGeneral.checkIfMatchEnded()
	if not object.matchOver and not object.resetting then
		local selfDead, oppDead, selfCreeps, oppCreeps, selfTower, oppTower = jGeneral.getGameStats()

		-- match over?
		if selfDead or oppDead or selfCreeps or oppCreeps or selfTower or oppTower then
			object.matchEnd = HoN.GetMatchTime()
			object.matchOver = true
			Testing.KillCreeps()
		end
	end
end

-------------------------------------------------------------------------------
--						 							 FINALIZE MATCH END			 												 --
-------------------------------------------------------------------------------
function jGeneral.declareMatchEnd()
	core.OrderHoldClamp(object, core.unitSelf)

	local timeSinceEnd = HoN.GetMatchTime() - object.matchEnd
	if timeSinceEnd >= 1000 then -- wait 1s to officially close match
		local selfDead, oppDead, selfCreeps, oppCreeps, selfTower, oppTower = jGeneral.getGameStats()

		-- who won?
		local iWon = oppDead or selfCreeps or oppTower
		local oppWon = selfDead or oppCreeps or selfTower

		if iWon and not oppWon then
			object.matchOutcome = 1
			object.matchOutcomeStr = "win"
		elseif iWon and oppWon then
			object.matchOutcome = 0.5
			object.matchOutcomeStr = "draw"
		else
			object.matchOutcome = 0
			object.matchOutcomeStr = "loss"
		end

		-- matchoutcomeby - WIN SPECIFICS
		-- selfDead 			oppDead				selfCreeps		oppCreeps 		selfTower			oppTower
		-- am I					is Opp 				is my farm		is opp farm		is my tower		is opp tower
		-- alive/dead		alive/dead		>= bound			>= bound			alive/dead		alive/dead
	  --	1 / 0					1 / 0					1 / 0					1 / 0					1 / 0 				1 / 0
	  object.matchOutcomeBy = ""

		if not selfDead then
			object.matchOutcomeBy = object.matchOutcomeBy .. "1"
		else
			object.matchOutcomeBy = object.matchOutcomeBy .. "0"
		end
		if not oppDead then
			object.matchOutcomeBy = object.matchOutcomeBy .. "1"
		else
			object.matchOutcomeBy = object.matchOutcomeBy .. "0"
		end
		if selfCreeps then
			object.matchOutcomeBy = object.matchOutcomeBy .. "1"
		else
			object.matchOutcomeBy = object.matchOutcomeBy .. "0"
		end
		if oppCreeps then
			object.matchOutcomeBy = object.matchOutcomeBy .. "1"
		else
			object.matchOutcomeBy = object.matchOutcomeBy .. "0"
		end
		if not selfTower then
			object.matchOutcomeBy = object.matchOutcomeBy .. "1"
		else
			object.matchOutcomeBy = object.matchOutcomeBy .. "0"
		end
		if not oppTower then
			object.matchOutcomeBy = object.matchOutcomeBy .. "1"
		else
			object.matchOutcomeBy = object.matchOutcomeBy .. "0"
		end

		local unitSelf = core.unitSelf

		-- match stats
		local jmatchlength = math.abs(HoN.GetMatchTime() - object.matchStart)
		local numberofcreepwaves = floor(jmatchlength/30000) + 1
		local numberoftotalcreeps = numberofcreepwaves*6
		local numberofcreepkills = core.unitSelf:GetCreepKills()-object.selfCreepKills
		local numberofcreepsscaled = numberofcreepkills/numberoftotalcreeps
		local numberofcreepsscaled2 = numberofcreepsscaled/2

		-- console output
		--BotEcho("+++++++++++++++++++++++++++++++++++++OUTCOME "..tostring(object.matchOutcomeStr)..
		--					" by "..tostring(object.matchOutcomeBy) .. " taking "..math.abs(HoN.GetMatchTime() - object.matchStart) ..
		--					" with creep reward "..numberofcreepsscaled2)

		-- save outcome to DB
		jDataWriter.writeOutcome3(object.matchOutcomeStr, object.matchOutcomeBy, math.abs(HoN.GetMatchTime() - object.matchStart))

		-- save action to DB
		jDataWriter.writeAction(object.matchOutcome, object.tYk[1], object.matchStart,
									object.lastExecutedAction, object.lastExecutedAction_IsRandom,
									object.randomActionChance, object.currentMatch, object.currentAction)
		-- NN weight learning
		if learning then
			local reward = {}
			for i=1,object.nOs do
					reward[i] = 0
			end
			local ntYk = {}
			ntYk[1] = object.matchOutcome
			jNN.learn_final(reward, ntYk)
		end

		-- e-greedy adjustment
		if randoming then
			object.randomActionChance = object.randomActionChance - object.randomChanceDecrease
			if object.randomActionChance < object.randomChanceLowerBound then
				object.randomActionChance = object.randomChanceLowerBound
			end
		end

		-- setup for next match!
		local currMTime = HoN.GetMatchTime()
		local spawnsSoFar = floor(currMTime/30000)+1
		local nextSpawn = spawnsSoFar*30000
		if nextSpawn - currMTime < 6000 then
			nextSpawn = nextSpawn + 30000
		end
		object.matchStart = nextSpawn
		object.pickingAction = true
		object.executingAction = false
		object.executedAction = false
		object.matchOutcome = -1
		object.matchStart = object.matchStart+4000
		object.selfCreepKills = unitSelf:GetCreepKills()
		object.selfCreepDenies = unitSelf:GetCreepDenies()
		object.enemyCreepKills = object.myOpponent:GetCreepKills()
		object.enemyCreepDenies = object.myOpponent:GetCreepDenies()
		object.matchOver = false
		object.resetting = true
		object.moveToRandomStartingPosition = true
		object.initResetDone = false
		object.onceResetKill = true
		object.actionToExecute = 3
		object.actionToExecute_IsRandom = 0
		object.lastExecutedAction = 3
		object.lastExecutedAction_IsRandom = 0

		jNN.resetEligibilityTrace()
	else
		jGeneralMovement.standstill(true, false, false)
	end
end

-------------------------------------------------------------------------------
--						 							 PREPARE FOR NEW MATCH	 												 --
-------------------------------------------------------------------------------
function jGeneral.setupNextMatch()
	local currentTime = HoN.GetMatchTime()
	local timeSinceEnd = currentTime - object.matchEnd

	-- kill spawning creeps
	if currentTime <= object.matchStart - 4500 then
		Testing.KillCreeps()
	end

	-- just after match end
	if object.onceResetKill and timeSinceEnd >= 3000 then
		object.currentMatch = object.currentMatch+1
		object.currentAction = 1

		-- kill surviving heroes
		if core.unitSelf and core.unitSelf:IsAlive() then
			if core.unitSelf:GetTeam() == 1 then
				Testing.Kill(object.legionHeroId)
			else
				Testing.Kill(object.hellbourneHeroId)
			end
		end

		-- reset towers: check if tower unit exists, refresh / respawn unit
		if core.unitSelf then
			if core.unitSelf:GetTeam() == 1 then
				if HoN.GameEntityExists(object.legionTowerId) and (object.myTower and object.myTower:IsAlive()) then
					Testing.Refresh(object.legionTowerId)
				else
					object.legionTowerId = Testing.SpawnUnit("Building_LegionTower", 4, 1, 550, 550)
				end
			else
				if HoN.GameEntityExists(object.hellbourneTowerId) and (object.myTower and object.myTower:IsAlive()) then
					Testing.Refresh(object.hellbourneTowerId)
				else
					object.hellbourneTowerId = Testing.SpawnUnit("Building_HellbourneTower", 5, 2,  2520, 2520)
				end
			end
		end
		object.onceResetKill = false
	end

	-- just before next match start
	if currentTime >= object.matchStart - 2000 and not object.initResetDone then
		-- reset hero ability cooldowns
		if core.unitSelf then
			if core.unitSelf:GetTeam() == 1 then
				Testing.Refresh(object.legionHeroId)
			else
				Testing.Refresh(object.hellbourneHeroId)
			end
		end

		-- redefine game units
		local units = HoN.GetUnitsInRadius(Vector3.Create(), 99999, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
		local sortedBuildings = {}
		core.SortBuildings(units, sortedBuildings)
		core.enemyTowers			= sortedBuildings.enemyTowers
		core.enemyRax				= sortedBuildings.enemyRax
		core.enemyMainBaseStructure	= sortedBuildings.enemyMainBaseStructure
		core.enemyWell				= sortedBuildings.enemyWell
		core.enemyWellAttacker		= sortedBuildings.enemyWellAttacker
		core.allyTowers				= sortedBuildings.allyTowers
		core.allyRax				= sortedBuildings.allyRax
		core.allyMainBaseStructure	= sortedBuildings.allyMainBaseStructure
		core.allyWell				= sortedBuildings.allyWell
		core.shops					= sortedBuildings.shops

		object.initResetDone = true
	end

	-- new match: spawn heroes!
	if currentTime >= object.matchStart then
		jSuccubusMisc.reset()
		jNN.initialInput("mSuccubus", "mSuccubus", true)
		Testing.RespawnAllHeroes()
		object.resetting = false
	end
end

-- update opponent stats (for when it isnt visible in future)
function jGeneral.recordOppInfo(unitTarget)
	object.lastSeenOpponentTimestamp = HoN.GetMatchTime()
	object.lastSeenOpponentHealthRegen = unitTarget:GetHealthRegen()
	object.lastSeenOpponentManaRegen = unitTarget:GetManaRegen()
	object.lastTargetPosition = unitTarget:GetPosition()
end

-------------------------------------------------------------------------------
--						 		 HEALTH OF A TOWER [-1(0%), 1(100%)] 											 --
-------------------------------------------------------------------------------
function jGeneral.getTowerHealth(isSelf)
	if isSelf then -- own tower
		if object.myTower ~= nil and object.myTower:IsAlive() then
			local currentHealth = object.myTower:GetHealthPercent()
			if currentHealth ~= nil then
				currentHealth = currentHealth*2 - 1
				return currentHealth
			else
				return object.tYi[43]
			end
		else
			if not object.myTower:IsAlive() then
				return -1
			else
				return object.tYi[43]
			end
		end
	else -- opp tower
		if object.oppTower ~= nil and object.oppTower:IsAlive() then
			local currentHealth = object.oppTower:GetHealthPercent()
			if core.CanSeeUnit(object, object.oppTower) then
				if currentHealth ~= nil then
					currentHealth = currentHealth*2 - 1
					return currentHealth
				else
					return object.tYi[44]
				end
			else
				return object.tYi[44]
			end
		else
			if not object.oppTower:IsAlive() then
				return -1
			else
				return object.tYi[44]
			end
		end
	end
end

-------------------------------------------------------------------------------
--						 		 HEALTH/MANA OF HERO [-1(0%), 1(100%)] 										 --
-------------------------------------------------------------------------------
function jGeneral.getHealth(unit)
	local currentHealth = unit:GetHealthPercent()
	currentHealth = currentHealth*2 - 1
	return currentHealth
end
function jGeneral.getMana(unit)
	local currentMana = unit:GetManaPercent()
	currentMana = currentMana*2 - 1
	return currentMana
end

-- #CS
function jGeneral.getCreepKills(unit)
	local nkills = unit:GetCreepKills()
	return nkills
end
-- #CD
function jGeneral.getCreepDenies(unit)
	local ndenies = unit:GetCreepDenies()
	return ndenies
end

-------------------------------------------------------------------------------
--						 # CREEP KILLS/DENIES [-1(0), 1(neededCreeps)]								 --
-------------------------------------------------------------------------------
function jGeneral.getCreepKills_Scaled(unit, isSelf)
	local alreadyhave
	if isSelf then
		alreadyhave = object.selfCreepKills
	else
		alreadyhave = object.enemyCreepKills
	end
	local nkills = (unit:GetCreepKills()-alreadyhave)*2/object.neededCreeps - 1
	return nkills
end
function jGeneral.getCreepDenies_Scaled(unit, isSelf)
	local alreadyhave
	if isSelf then
		alreadyhave = object.selfCreepDenies
	else
		alreadyhave = object.enemyCreepDenies
	end
	local ndenies = (unit:GetCreepDenies()-alreadyhave)*2/object.neededCreeps - 1
	if ndenies > 1 then
		ndenies = 1
	end
	return ndenies
end


-- shuffle array
function swap(array, index1, index2)
    array[index1], array[index2] = array[index2], array[index1]
end
function shuffle(array)
    local counter = #array
    while counter > 1 do
        local index = math.random(counter)
        swap(array, index, counter)
        counter = counter - 1
    end
end

-------------------------------------------------------------------------------
--				 		 NEXT CREEP WAVE SPAWN [-1(now), 1(in 30s)]										 --
-------------------------------------------------------------------------------
function jGeneral.nextCreepWave()
	local curTime = HoN.GetMatchTime()
	local spawnsSoFar = floor(curTime/30000)+1
	local nextSpawn = spawnsSoFar*30000
	local timeUntil = nextSpawn - curTime
	local timeUntilScaled = timeUntil*2/30000 - 1
	return timeUntilScaled
end

-------------------------------------------------------------------------------
--						 		 CAN DENY A CREEP {-1(can't), 1(can)}											 --
-------------------------------------------------------------------------------
function jGeneral.canDeny()
	local validCreeps = {}
	local	friendlyCreeps = core.localUnits["AllyCreeps"]
	local creepcnt = 0
	local creephp = 0
	local jCnt = 1
	local foundCreeps = false
	-- look at friendly alive creeps
	for id, creep in pairs(friendlyCreeps) do
		local curHP = creep:GetHealth()
		local nDamageMin = core.GetAttackDamageMinOnCreep(creep)
		-- check if we can AA to deny
		if nDamageMin * (1 - creep:GetPhysicalResistance()) >= (curHP - behaviorLib.GetAttackDamageOnCreep(object, creep)) then
			validCreeps[jCnt] = creep
			jCnt = jCnt + 1
			foundCreeps = true
		end
	end
	-- if there deniable creeps, pick random creep
	if foundCreeps then
		shuffle(validCreeps)
		local nums = jCnt - 1
		return validCreeps, 1, nums
	else
		return nil, -1, 0
	end
end

-------------------------------------------------------------------------------
--								 CAN LAST HIT A CREEP {-1(can't), 1(can)}									 --
-------------------------------------------------------------------------------
function jGeneral.canLastHit()
	local validCreeps = {}
	local	enemyCreeps = core.localUnits["EnemyCreeps"]
	local creepcnt = 0
	local creephp = 0
	local jCnt = 1
	local foundCreeps = false
	-- look at enemy alive creeps
	for id, creep in pairs(enemyCreeps) do
		local curHP = creep:GetHealth()
		local nDamageMin = core.GetAttackDamageMinOnCreep(creep)
		-- check if we can AA to last hit
		if nDamageMin * (1 - creep:GetPhysicalResistance()) >= (curHP - behaviorLib.GetAttackDamageOnCreep(object, creep)) then
			validCreeps[jCnt] = creep
			jCnt = jCnt + 1
			foundCreeps = true
		end
	end
	-- if there are killable creeps, pick random one
	if foundCreeps then
		shuffle(validCreeps)
		local nums = jCnt - 1
		return validCreeps, 1, nums
	else
		return nil, -1, 0
	end
end

-- pick lowest friendly/enemy creeps
function jGeneral.getLowestMinion()
	local unitDenyTarget = core.unitAllyCreepTarget
	local unitAttackTarget = core.unitEnemyCreepTarget
	local unitTarget = nil
	local targetType = 0 -- 0: none (no minions or no low minions), 1: ally, 2: enemy
 	unitTarget = behaviorLib.GetCreepAttackTarget(object, unitAttackTarget, unitDenyTarget)
	if unitTarget then
		if unitTarget:GetTeam() == core.myTeam then
			targetType = 1
		else
			targetType = 2
		end
	end
	return targetType, unitTarget
end

-- number of elements in table
function tablelength(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

-- legacy function # creeps alive [-1(0), 1(6 or more)]
function jGeneral.numberOfMinionsUp()
	local tEnemyCreeps = core.localUnits["EnemyCreeps"]
	local allyCreeps = 	core.localUnits["AllyCreeps"]
	local nACreeps = tablelength(allyCreeps)
	local nECreeps = tablelength(tEnemyCreeps)
	nACreeps = nACreeps*2/6 - 1
	nECreeps = nECreeps*2/6 - 1
	if nACreeps > 1 then
		nACreeps = 1
	end
	if nECreeps > 1 then
		nECreeps = 1
	end
	return nACreeps, nECreeps
end

local maxCreepsHP = 1200*4 + 2*1000

-------------------------------------------------------------------------------
--	 HEALTHINESS OF CREEP WAVE [-1(all dead), 1(6 ot more, all healthy)]		 --
-------------------------------------------------------------------------------
function jGeneral.avgMinionHealth(isSelf)
	local enemyCreeps
	if isSelf then
		enemyCreeps = core.localUnits["EnemyCreeps"]
	else
		enemyCreeps = core.localUnits["AllyCreeps"]
	end
	local creepcnt = 0
	local creephp = 0
	for id, creep in pairs(enemyCreeps) do
		curHP = creep:GetHealth()
		creepcnt = creepcnt + 1
		creephp = creephp + curHP
	end
	local creepAvgScale = creephp*2/maxCreepsHP - 1
	if creepAvgScale > 1 then
		creepAvgScale = 1
	end
	return creepAvgScale
end

-------------------------------------------------------------------------------
--IN OPP TOWER RANGE {-1(not inrange), 0(inrange no aggro), 1(inrange aggro)}--
-------------------------------------------------------------------------------
function jGeneral.inTowerRange(unit, isSelf)
	-- heroes AA range
	local nRange = core.GetAbsoluteAttackRange(unit)
	-- get opp towers
	local tTowers
	if isSelf then
		 tTowers = core.enemyTowers
	else
		 tTowers = core.allyTowers
	end

	for id, tower in pairs(tTowers) do
		local nExtraRange = core.GetExtraRange(tower)
		if not tower:IsInvulnerable() and core.IsUnitInRange(unit, tower, nRange + nExtraRange) then
			if core.IsTowerSafe(tower, unit) then -- tower not focusing hero
				return 0
			else -- tower damaging hero
				return 1
			end
		else
			return -1 -- outof range
		end
	end
end

-------------------------------------------------------------------------------
--											 CREEP AGGRO {-1(no), 1(yes)}												 --
-------------------------------------------------------------------------------
function jGeneral.creepAggro(unit, isSelf)
	local creeps
	if isSelf then
		creeps = core.localUnits["EnemyCreeps"]
	else
		creeps = core.localUnits["AllyCreeps"]
	end
	local nCreepAggroUtility = 0
	for id, enemyCreep in pairs(creeps) do
		local unitAggroTarget = enemyCreep:GetAttackTarget()
		if unitAggroTarget and unitAggroTarget:GetUniqueID() == unit:GetUniqueID() then
			return 1
		end
	end
	return -1
end

-- check if non-ability actions have been executed
function jGeneral.isActionDone()
	local sincePicking = HoN.GetMatchTime() - object.pickingActionTimestamp
	local movementAction = object.actionToExecute == 1 or object.actionToExecute == 2 or object.actionToExecute == 3
	if movementAction and object.executingAction then
		if sincePicking >= 250 then
			object.executingAction = false
			object.executedAction = true
		end
	elseif object.actionToExecute == 11 and object.executingAction then
		if object.creepTarget == nil or not object.creepTarget:IsAlive() then
			object.executingAction = false
			object.executedAction = false
			object.pickingAction = true
		end
	end
end

-- attack a creep Last hit > deny > pushing
function jGeneral.act_attackCreep(queue, shouldHold, shouldClamp)
	-- check if we can last hit
	if object.creepLH_nums > 0 then
		local CT = nil
		for ji = 1, object.creepLH_nums do
			local tmpCT = object.creepLHTargets[ji]
			if tmpCT ~= nil and tmpCT:IsAlive() then
				CT = tmpCT
				break
			end
		end
		if CT ~= nil then -- last hit creep still alive?
			object.creepTarget = CT
			jGeneralMovement.attackCreep(CT, queue, shouldClamp)
		else -- no last hit target
			-- check if we can deny
			for ji = 1, object.creepD_nums do
				local tmpCT = object.creepDTargets[ji]
				if tmpCT ~= nil and tmpCT:IsAlive() then
					CT = tmpCT
					break
				end
			end
			if CT ~= nil then -- deny target still alive?
				object.creepTarget = CT
				jGeneralMovement.attackCreep(CT, queue, shouldClamp)
			else
				-- attack a random creep if any are alive
				local CT
				local tEnemyCreeps = core.localUnits["EnemyCreeps"]
				local nCreeps = core.NumberElements(tEnemyCreeps)
				local rnd = jGeneral.jRandom(1,nCreeps)
				local cnt = 1
				if nCreeps > 0 then
					for id, enemyCreep in pairs(tEnemyCreeps) do
						if cnt == rnd then
							CT = enemyCreep
							break
						else
							cnt = cnt + 1
						end
					end
					object.creepTarget = CT
					jGeneralMovement.attackCreep(CT, queue, shouldClamp)
				else -- no creeps alive
					object.executingAction = false
					object.executedAction = false
					object.pickingAction = true
				end
			end
		end
	else
		-- can we deny?
		if object.creepD_nums > 0 then
			local CT = nil
			for ji = 1, object.creepD_nums do
				local tmpCT = object.creepDTargets[ji]
				if tmpCT ~= nil and tmpCT:IsAlive() then
					CT = tmpCT
					break
				end
			end
			if CT ~= nil then -- deny target still alive?
				object.creepTarget = CT
				jGeneralMovement.attackCreep(CT, queue, shouldClamp)
			else
				object.executingAction = false
				object.executedAction = false
				object.pickingAction = true
			end
		else
			-- attack a random creep
			local CT
			local tEnemyCreeps = core.localUnits["EnemyCreeps"]
			local nCreeps = core.NumberElements(tEnemyCreeps)
			local rnd = jGeneral.jRandom(1,nCreeps)
			local cnt = 1
			if nCreeps > 0 then
				for id, enemyCreep in pairs(tEnemyCreeps) do
					if cnt == rnd then
						CT = enemyCreep
						break
					else
						cnt = cnt + 1
					end
				end
				object.creepTarget = CT
				jGeneralMovement.attackCreep(CT, queue, shouldClamp)
			else -- no creeps alive
				object.executingAction = false
				object.executedAction = false
				object.pickingAction = true
			end
		end
	end
end
