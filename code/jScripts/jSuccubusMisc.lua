--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
-- HELPER FUNCTIONS (hero specific), by Janine Weber @ 2017
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

local _G = getfenv(0)
local object = _G.object

runfile "bots/jScripts/jGeneral.lua"
runfile "bots/jScripts/jGeneralMovement.lua"


object.jSuccubusMisc = object.jSuccubusMisc or {}
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
--						 GAME PARAMETERS RELATED TO SUCCUBUS													 --
-------------------------------------------------------------------------------
local unitRange = 0

local Q_CD = {
  15000, 15000, 15000, 15000
}
local Q_Mana = {
  95, 105, 115, 125
}
local Q_Range = {
  1000,1000,1000,1000
}
local Q_DebuffDuration = {
  10000, 12000, 14000, 16000
}
local Q_DebuffReduction = { --in percent
  26, 34, 42, 50
}
local Q_GameRange = {}
local Q_Level = {
	0, 0, 1, 1, 1,
	1, 1, 2, 2, 3,
	3, 3, 4, 4, 4,
	4, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

local W_CD = {
  15000, 15000, 15000, 15000
}
local W_Mana = {
  125, 150, 175, 200
}
local W_Range = {
  625, 625, 625, 625
}
local W_DmgAndHeal = { --true dmg
  90, 160, 230, 300
}
local W_GameRange = {}
local W_Level = {
	1, 1, 1, 2, 3,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

local E_CD = { -- can be used on enemy or self, succ can always dispell + 1. second target is invulnerable
  15000, 14000, 13000, 12000
}
local E_Mana = {
  130, 140, 150, 160
}
local E_Range = {
  500, 575, 650, 725
}
local E_SleepDuration = {
  4000, 5000, 6000, 7000
}
local E_SleepDmg = { -- per second true dmg
  20, 20, 20, 20
}
local E_GameRange = {}
local E_Level = {
	0, 1, 1, 1, 1,
	1, 1, 1, 2, 2,
	2, 3, 3, 4, 4,
	4, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

local R_CD = {
  100000, 85000, 70000
}
local R_Mana = {
  150, 250, 350
}
local R_Range = {
  625, 625, 625
}
local R_ChannelTime = { --stuns
  5000, 5000, 5000
}
local R_DebuffDamage = { -- per second
  100, 160, 220
}
local R_ManaDrain = { -- percent
  25, 25, 25
}
local R_GameRange = {}
local R_Level = {
	0, 0, 0, 0, 0,
	1, 1, 1, 1, 1,
	2, 2, 2, 2, 2,
	3, 3, 3, 3, 3,
	3, 3, 3, 3, 3
}

local Attr_Level = {
	0, 0, 0, 0, 0,
	0, 0, 0, 0, 0,
	0, 0, 0, 0, 1,
	1, 2, 3, 4, 5,
	6, 7, 8, 9, 10
}

-- init
function jSuccubusMisc.setup()
	unitRange = core.GetExtraRange(core.unitSelf)
	for i=1,4 do
		local qRange = unitRange*2 + Q_Range[i]
		Q_GameRange[i] = qRange*qRange
		local wRange = unitRange*2 + W_Range[i]
		W_GameRange[i] = wRange*wRange
		local eRange = unitRange*2 + E_Range[i]
		E_GameRange[i] = eRange*eRange
		if i ~= 4 then
			local rRange = unitRange*2 + R_Range[i]
			R_GameRange[i] = rRange*rRange
		end
	end
end

--debuffs inflicted on me
local MyselfQdebuff = false
local MyselfQdebuff_Timestamp = 0
local MyselfEdebuffByEnemy = false
local MyselfEdebuffByEnemyTimestamp = 0
local MyselfEdebuffBySelf = false
local MyselfEdebuffByMyselfTimestamp = 0
local MyselfRdebuff = false
local MyselfRdebuff_Timestamp = 0

-- debuffs infliced on opponent succ
local EnemyQdebuff = false
local EnemyQdebuff_Timestamp = 0
local EnemyEdebuffByEnemy = false
local EnemyEdebuffByEnemyTimestamp = 0
local EnemyEdebuffBySelf = false
local EnemyEdebuffByMyselfTimestamp = 0
local EnemyRdebuff = false
local EnemyRdebuff_Timestamp = 0

-- succ opponent keeping track of
local EnemySuccQ_Used = false
local EnemySuccQ_Timestamp = 0
local EnemySuccW_Used = false
local EnemySuccW_Timestamp = 0
local EnemySuccE_Used = false
local EnemySuccE_Timestamp = 0
local EnemySuccR_Used = false
local EnemySuccR_Timestamp = 0

-- setup for next match
function jSuccubusMisc.reset()
	MyselfQdebuff = false
	MyselfQdebuff_Timestamp = 0

	MyselfEdebuffByEnemy = false
	MyselfEdebuffByEnemyTimestamp = 0
	MyselfEdebuffBySelf = false
	MyselfEdebuffByMyselfTimestamp = 0

	MyselfRdebuff = false
	MyselfRdebuff_Timestamp = 0

	-- debuffs infliced on opponent succ
	EnemyQdebuff = false
	EnemyQdebuff_Timestamp = 0

	EnemyEdebuffByEnemy = false
	EnemyEdebuffByEnemyTimestamp = 0
	EnemyEdebuffBySelf = false
	EnemyEdebuffByMyselfTimestamp = 0

	EnemyRdebuff = false
	EnemyRdebuff_Timestamp = 0

	-- succ opponent keeping track of
	EnemySuccQ_Used = false
	EnemySuccQ_Timestamp = 0
	EnemySuccW_Used = false
	EnemySuccW_Timestamp = 0
	EnemySuccE_Used = false
	EnemySuccE_Timestamp = 0
	EnemySuccR_Used = false
	EnemySuccR_Timestamp = 0
end

-- get ability level depending on succubus level
function jSuccubusMisc.succLeveltoAbility(succLvl, ability)
	if ability == 0 then --Q
		return Q_Level[succLvl]
	elseif ability == 1 then --W
		return W_Level[succLvl]
	elseif ability == 2 then --E
		return E_Level[succLvl]
	elseif ability == 3 then --R
		return R_Level[succLvl]
	end
end

-------------------------------------------------------------------------------
--						 						 ABILITY CD/IN RANGE															 --
-------------------------------------------------------------------------------
function jSuccubusMisc.inRange_Q(distance, succQLvl) -- all, sq distance
	 if distance <= Q_GameRange[succQLvl] then
		 return 1
	 else
		 return -1
	 end
end
function jSuccubusMisc.enemyGetQCD(succQLvl)
	if EnemySuccQ_Used then
		local over, scaledCD = jGeneral.scaleCD_ts(EnemySuccQ_Timestamp, Q_CD[succQLvl])
		if over then
			EnemySuccQ_Used = false
		end
		return scaledCD
	else
		return 1
	end
end
function jSuccubusMisc.myselfGetQCD()
	if skills.smitten:GetActualRemainingCooldownTime() > 0 then
		local timeRemaining = skills.smitten:GetActualRemainingCooldownTime()
		local succQLvl = skills.smitten:GetLevel()
		local scaledCD = jGeneral.scaleCD_tr(timeRemaining, Q_CD[succQLvl])
		return scaledCD
	else
		return 1
	end
end

function jSuccubusMisc.inRange_W(distance, succWLvl) -- all
	 if distance <= W_GameRange[succWLvl] then
		 return 1
	 else
		 return -1
	 end
end
function jSuccubusMisc.enemyGetWCD(succWLvl)
	if EnemySuccW_Used then
		local over, scaledCD = jGeneral.scaleCD_ts(EnemySuccW_Timestamp, W_CD[succWLvl])
		if over then
			EnemySuccW_Used = false
		end
		return scaledCD
	else
		return 1
	end
end
function jSuccubusMisc.myselfGetWCD()
	if skills.heartache:GetActualRemainingCooldownTime() > 0 then
		local timeRemaining = skills.heartache:GetActualRemainingCooldownTime()
		local succWLvl = skills.heartache:GetLevel()
		local scaledCD = jGeneral.scaleCD_tr(timeRemaining, W_CD[succWLvl])
		return scaledCD
	else
		return 1
	end
end

function jSuccubusMisc.inRange_E(distance, succELvl) -- all
	 if distance <= E_GameRange[succELvl] then
		 return 1
	 else
		 return -1
	 end
end
function jSuccubusMisc.enemyGetECD(succELvl)
	if EnemySuccE_Used then
		local over, scaledCD = jGeneral.scaleCD_ts(EnemySuccE_Timestamp, E_CD[succELvl])
		if over then
			EnemySuccE_Used = false
		end
		return scaledCD
	else
		return 1
	end
end
function jSuccubusMisc.myselfGetECD()
	if skills.mesmerize:GetActualRemainingCooldownTime() > 0 then
		local timeRemaining = skills.mesmerize:GetActualRemainingCooldownTime()
		local succELvl = skills.mesmerize:GetLevel()
		local scaledCD = jGeneral.scaleCD_tr(timeRemaining, E_CD[succELvl])
		return scaledCD
	else
		return 1
	end
end

function jSuccubusMisc.inRange_R(distance, succRLvl) -- all
	 if distance <= R_GameRange[succRLvl] then
		 return 1
	 else
		 return -1
	 end
end
function jSuccubusMisc.enemyGetRCD(succRLvl)
	if EnemySuccR_Used then
		local over, scaledCD = jGeneral.scaleCD_ts(EnemySuccR_Timestamp, R_CD[succRLvl])
		if over then
			EnemySuccR_Used = false
		end
		return scaledCD
	else
		return 1
	end
end
function jSuccubusMisc.myselfGetRCD()
	if skills.hold:GetActualRemainingCooldownTime() > 0 then
		local timeRemaining = skills.hold:GetActualRemainingCooldownTime()
		local succRLvl = skills.hold:GetLevel()
		local scaledCD = jGeneral.scaleCD_tr(timeRemaining, R_CD[succRLvl])
		return scaledCD
	else
		return 1
	end
end

-------------------------------------------------------------------------------
--						 									 BUFFS/DEBUFFS															 --
-------------------------------------------------------------------------------
function jSuccubusMisc.enemyGetQDebuff(succQLvl)
	if EnemyQdebuff then
		local over, scaledCD = jGeneral.scaleBuff(EnemyQdebuff_Timestamp, Q_DebuffDuration[succQLvl])
	 	if over then
	 		EnemyQdebuff = false
	 	end
	 	return scaledCD
	 else
	 	return -1
	end
end
function jSuccubusMisc.myselfGetQDebuff(succQLvl)
	if MyselfQdebuff then
		local over, scaledCD = jGeneral.scaleBuff(MyselfQdebuff_Timestamp, Q_DebuffDuration[succQLvl])
		if over then
			MyselfQdebuff = false
		end
		return scaledCD
	else
		return -1
	end
end

function jSuccubusMisc.enemyGetEDebuff(succELvl)
	if EnemyEdebuffBySelf then
		local over, scaledCD = jGeneral.scaleBuff(EnemyEdebuffByMyselfTimestamp, E_SleepDuration[succELvl])
		if over then
			EnemyEdebuffBySelf = false
		end
		return scaledCD
	elseif EnemyEdebuffByEnemy then
		local over, scaledCD = jGeneral.scaleBuff(EnemyEdebuffByEnemyTimestamp, E_SleepDuration[succELvl])
		if over then
			EnemyEdebuffByEnemy = false
		end
		return scaledCD
	else
		return -1
	end
end
function jSuccubusMisc.myselfGetEDebuff(succELvl)
	if MyselfEdebuffBySelf then
		local over, scaledCD = jGeneral.scaleBuff(MyselfEdebuffByMyselfTimestamp, E_SleepDuration[succELvl])
		if over then
			MyselfEdebuffBySelf = false
		end
		return scaledCD
	elseif MyselfEdebuffByEnemy then
		local over, scaledCD = jGeneral.scaleBuff(MyselfEdebuffByEnemyTimestamp, E_SleepDuration[succELvl])
		if over then
			MyselfEdebuffByEnemy = false
		end
		return scaledCD
	else
		return -1
	end
end

function jSuccubusMisc.enemyGetRDebuff(succRLvl)
	if EnemyRdebuff then
		local over, scaledCD = jGeneral.scaleBuff(EnemyRdebuff_Timestamp, R_ChannelTime[succRLvl])
		if over then
			EnemyRdebuff = false
		end
		return scaledCD
	else
		return -1
	end
end
function jSuccubusMisc.myselfGetRDebuff(succRLvl)
	if MyselfRdebuff then
		local over, scaledCD = jGeneral.scaleBuff(MyselfRdebuff_Timestamp, R_ChannelTime[succRLvl])
		if over then
			MyselfRdebuff = false
		end
		return scaledCD
	else
		return -1
	end
end

-------------------------------------------------------------------------------
--									 RECORD WHEN ENEMY USES ABILITIES												 --
-------------------------------------------------------------------------------
function jSuccubusMisc.enemyCheckCDs(unitTarget, EventData) -- record the opponent succ cds
	if EventData.Type == "Debuff" then
		-- Q used
		if EventData.StateName == "State_Succubis_Ability1" then
			if not EnemySuccQ_Used then
				EnemySuccQ_Used = true
				EnemySuccQ_Timestamp = HoN.GetMatchTime()
			end
		end
	end

	if EventData.Type == "Damage" then
		if EventData.InflictorName == "Ability_Succubis2" then
			-- w used
			if not EnemySuccW_Used then
				EnemySuccW_Used = true
				EnemySuccW_Timestamp = HoN.GetMatchTime()
			end
		end

		if EventData.InflictorName == "State_Succubis_Ability3" then
			if EventData.SourcePlayerName ~= object:GetName() then
				if not EnemySuccE_Used then
					EnemySuccE_Used = true
					EnemySuccE_Timestamp = HoN.GetMatchTime()
				end
			end
		end
	end

	if EventData.Type == "State" then
		if EventData.StateName == "State_Succubis_Ability4" then
			-- R used
			if not EnemySuccR_Used then
				EnemySuccR_Used = true
				EnemySuccR_Timestamp = HoN.GetMatchTime()
			end
		end
	end
end
function jSuccubusMisc.enemyCheckCDs_ESelf(unitTarget)
	if unitTarget:HasState("State_Succubis_Ability3") then
		if not EnemySuccE_Used then
			EnemySuccE_Used = true
			EnemySuccE_Timestamp = HoN.GetMatchTime()
		end
	end
end

-------------------------------------------------------------------------------
--						 					MONITOR BUFFS/DEBUFFS	ON ENEMY											 --
-------------------------------------------------------------------------------
function jSuccubusMisc.enemyCheckDebuffs(unitTarget)
	local unitSelf = core.unitSelf
	if unitTarget:HasState("State_Succubis_Ability1") then
		--Q
		if not EnemyQdebuff then
			EnemyQdebuff = true
			EnemyQdebuff_Timestamp = HoN.GetMatchTime()
		end
	else
		EnemyQdebuff = false
	end
	if unitTarget:HasState("State_Succubis_Ability3") then
		--E
		if not EnemyEdebuffBySelf and not EnemyEdebuffByEnemy then
			EnemyEdebuffBySelf = true
			EnemyEdebuffByMyselfTimestamp = HoN.GetMatchTime()
		end
	else
		EnemyEdebuffBySelf = false
		EnemyEdebuffByEnemy = false
	end
	if unitTarget:HasState("State_Succubis_Ability4") then
		--R
		if not EnemyRdebuff then
			EnemyRdebuff = true
			EnemyRdebuff_Timestamp = HoN.GetMatchTime()
		end
	else
		EnemyRdebuff = false
	end
end

-------------------------------------------------------------------------------
--						 					MONITOR BUFFS/DEBUFFS ON SELF												 --
-------------------------------------------------------------------------------
function jSuccubusMisc.myselfCheckDebuffs_E(EventData)
	local unitSelf = core.unitSelf
	if EventData.Type == "Damage" then
		if EventData.InflictorName == "State_Succubis_Ability3" then
			if EventData.SourcePlayerName ~= object:GetName() then
				--E by opp
				if not MyselfEdebuffByEnemy then
					MyselfEdebuffByEnemy = true
					MyselfEdebuffByEnemyTimestamp = HoN.GetMatchTime()
				end
			else
				--E by self
				if not MyselfEdebuffBySelf then
					MyselfEdebuffBySelf = true
					MyselfEdebuffByMyselfTimestamp = HoN.GetMatchTime()
				end
			end
		end
	end
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Succubis3" then
			-- E by opp
			if EventData.TargetPlayerName ~= object:GetName() then
				EnemyEdebuffByEnemy = true
				EnemyEdebuffByEnemyTimestamp = HoN.GetMatchTime()
			-- E by self
			else
				MyselfEdebuffBySelf = true
				MyselfEdebuffByMyselfTimestamp = HoN.GetMatchTime()
			end
		end
	end
	if unitSelf and not unitSelf:HasState("State_Succubis_Ability3") then
		MyselfEdebuffBySelf = false
		MyselfEdebuffByEnemy = false
	end
end
function jSuccubusMisc.myselfCheckDebuffs_QR()
	local unitSelf = core.unitSelf
	if unitSelf:HasState("State_Succubis_Ability1") then
		-- Q
		if not MyselfQdebuff then
			MyselfQdebuff = true
			MyselfQdebuff_Timestamp = HoN.GetMatchTime()
		end
	else
		MyselfQdebuff = false
	end
	if unitSelf:HasState("State_Succubis_Ability4") then
		-- R
		if not MyselfRdebuff then
			MyselfRdebuff = true
			MyselfRdebuff_Timestamp = HoN.GetMatchTime()
		end
	else
		MyselfRdebuff = false
	end
end

function jSuccubusMisc.myselfCanActivateE()
	if MyselfEdebuffBySelf then
		return 1
	elseif MyselfEdebuffByEnemy then
		return 0
	else
		if skills.mesmerize:CanActivate() then
			return 1
		else
			return 0
		end
	end
end

-------------------------------------------------------------------------------
--									 					EXECUTE ABILITIES															 --
-------------------------------------------------------------------------------
function jSuccubusMisc.useAbility_Q(unitTarget, interruptAA, queue)
	core.OrderAbilityEntity(object, skills.smitten, unitTarget, interruptAA, queue)
end
function jSuccubusMisc.useAbility_W(unitTarget, interruptAA, queue)
	core.OrderAbilityEntity(object, skills.heartache, unitTarget, interruptAA, queue)
end
function jSuccubusMisc.useAbility_E(unitTarget, interruptAA, queue)
	core.OrderAbilityEntity(object, skills.mesmerize, unitTarget, interruptAA, queue)
end
function jSuccubusMisc.useAbility_ESelf(interruptAA, queue) -- cancel after Invulnerability
	local unitSelf = core.unitSelf
	if skills.mesmerize:GetActualRemainingCooldownTime() == 0 then
		core.OrderAbilityEntity(object, skills.mesmerize, unitSelf, interruptAA, queue)
	else
		local timeSince = HoN.GetMatchTime() - MyselfEdebuffByMyselfTimestamp
		if timeSince >= 1000 then
			core.OrderAbilityEntity(object, skills.mesmerize, unitSelf, interruptAA, queue)
		else
			jGeneralMovement.standstill(interruptAA, queue, false)
		end
	end
end
function jSuccubusMisc.useAbility_R(unitTarget, interruptAA, queue)
	core.OrderAbilityEntity(object, skills.hold, unitTarget, interruptAA, queue)
end

-------------------------------------------------------------------------------
--					 			CHECK IF ACTION (ABILITY/AA) WAS EXECUTED									 --
-------------------------------------------------------------------------------
function jSuccubusMisc.abilityWasExecuted(EventData)
	--abilities
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Succubis1" then
			object.lastExecutedAction = 5
			object.executingAction = false
			object.executedAction = true
		elseif EventData.InflictorName == "Ability_Succubis2" then
			object.lastExecutedAction = 6
			object.executingAction = false
			object.executedAction = true
		elseif EventData.InflictorName == "Ability_Succubis3" then
			if MyselfEdebuffBySelf then
				object.lastExecutedAction = 8
				local timeSince = HoN.GetMatchTime() - MyselfEdebuffByMyselfTimestamp
				if timeSince >= 1000 then
					object.executingAction = false
					object.executedAction = true
				end
			elseif EnemyEdebuffByEnemy then
				object.lastExecutedAction = 7
				local timeSince = HoN.GetMatchTime() - EnemyEdebuffByMyselfTimestamp
				if timeSince >= 1000 then
					object.executingAction = false
					object.executedAction = true
				end
			end
		elseif EventData.InflictorName == "Ability_Succubis4" then
			object.executingAction = false
			object.lastExecutedAction = 9
			object.executedAction = true
		end
	end
	-- AA opp hero
	if EventData.Type == "Attack"
		and EventData.InflictorName == "Projectile_SuccubisAttack"
		and object.actionToExecute == 4 and EventData.TargetPlayerName ~= nil
		and object.executingAction then
			object.executingAction = false
			object.executedAction = true
	end
	-- AA creep or tower
	if EventData.Type == "Attack"
		and EventData.InflictorName == "Projectile_SuccubisAttack"
		and (object.actionToExecute == 11 or object.actionToExecute == 12 or
				object.actionToExecute == 10) and EventData.TargetPlayerName == nil and
				object.executingAction then
			if EventData.TargetName == "Creep_LegionRanged" or EventData.TargetName == "Creep_HellbourneRanged" or EventData.TargetName == "Creep_LegionMelee" or EventData.TargetName == "Creep_HelLbourneMelee" then
				if object.actionToExecute == 11 or object.actionToExecute == 12 then
					object.executingAction = false
					object.executedAction = true
				end
			else
				if object.actionToExecute == 10 then
					object.executingAction = false
					object.executedAction = true
				end
			end
	end
end

-------------------------------------------------------------------------------
--					 			helper functions for picking next action									 --
-------------------------------------------------------------------------------
-- opponent is visible
function jSuccubusMisc.action_wM_CI(input, unitSelf, unitTarget, isRandom)
	-- info needed to decide whether an action can be used
	local targetIsInvulnerable = unitTarget:IsInvulnerable()
	local qCD = input[11]
	local wCD = input[12]
	local eCD = input[13]
	local rCD = input[14]
	local qR = input[15]
	local wR = input[16]
	local eR = input[17]
	local rR = input[18]
	local aaCD
	if unitSelf:IsAttackReady() then
		aaCD = 1
	else
		aaCD = -1
	end
	local aaRE = input[5]
	local aaRT = jGeneral.withinTowerAARange()
	local aaRM
	if input[25] == 1 or input[26] == 1 then
		aaRM = 1
	else
		aaRM = -1
	end
	local nEM
	local tEnemyCreeps = core.localUnits["EnemyCreeps"]
	if core.NumberElements(tEnemyCreeps) > 0 then
		nEM = 1
	else
		nEM = -1
	end

	--pick action to execute
	local nextAction
	if isRandom then
		nextAction = jSuccubusMisc.randomAction_wM(qCD, qR, wCD, wR, eCD, eR, rCD, rR, aaCD, aaRE, aaRT, aaRM, nEM, targetIsInvulnerable)
		object.actionToExecute = nextAction
		object.actionToExecute_IsRandom = 1
	else
		nextAction = jSuccubusMisc.nnAction_wM(input, qCD, qR, wCD, wR, eCD, eR, rCD, rR, aaCD, aaRE, aaRT, aaRM, nEM, targetIsInvulnerable)
		object.actionToExecute = nextAction
		object.actionToExecute_IsRandom = 0
	end
end
-- opponent is out of sight
function jSuccubusMisc.action_wM_CI_unknown(input, unitSelf, isRandom)
	local eCD = input[13]
	local aaCD
	if unitSelf:IsAttackReady() then
		aaCD = 1
	else
		aaCD = -1
	end
	local aaRE = input[5]
	local aaRT = jGeneral.withinTowerAARange()
	local aaRM
	if input[25] == 1 or input[26] == 1 then
		aaRM = 1
	else
		aaRM = -1
	end
	local nEM
	local tEnemyCreeps = core.localUnits["EnemyCreeps"]
	if core.NumberElements(tEnemyCreeps) > 0 then
		nEM = 1
	else
		nEM = -1
	end
	local nextAction
	if isRandom then
		nextAction = jSuccubusMisc.randomAction_wM_unknown(eCD, aaCD, aaRT, aaRM, nEM)
		object.actionToExecute = nextAction
		object.actionToExecute_IsRandom = 1
	else
		nextAction = jSuccubusMisc.nnAction_wM_unknown(input, eCD, aaCD, aaRT, aaRM, nEM)
		object.actionToExecute = nextAction
		object.actionToExecute_IsRandom = 0
	end
end

-------------------------------------------------------------------------------
--					 								PICKING A RANDOM ACTION													 --
-- 1: pursue (opponent)
-- 2: flee (to turret)
-- 3: hold
-- 4: AA (opponent)
-- 5: Q
-- 6: W
-- 7: E, enemy
-- 8: E, self
-- 9: R
-- 10: AA (turret)
-- 11: AA (minion (deny/lasthit))
-------------------------------------------------------------------------------
-- opponent visible
function jSuccubusMisc.randomAction_wM(qCD, qR, wCD, wR, eCD, eR, rCD, rR, aaCD, aaRE, aaRT, aaRM, nEM, targetIsInvulnerable)
	local unitSelf = core.unitSelf
	local actionOk = false
	local nextAction = -1
	local ffirst = true
	while not actionOk do
		actionOk = true
		nextAction = jGeneral.jRandom(1,object.nAs)
		if nextAction == 4 then
			if aaCD == -1 or aaRE == -1 then
				actionOk = false
			end
		elseif nextAction == 5 then
			if qCD < 1 or qR == -1 or not skills.smitten:CanActivate() or targetIsInvulnerable then
				actionOk = false
			end
		elseif nextAction == 6 then
			if wCD < 1 or wR == -1 or not skills.heartache:CanActivate() or targetIsInvulnerable then
				actionOk = false
			end
		elseif nextAction == 7 then
			if eCD < 1 or eR == -1 or not skills.mesmerize:CanActivate() or targetIsInvulnerable then
				actionOk = false
			end
		elseif nextAction == 8 then
			if eCD < 1  or not skills.mesmerize:CanActivate() then
				actionOk = false
			end
		elseif nextAction == 9 then
			if rCD < 1 or rR == -1 or not skills.hold:CanActivate() or targetIsInvulnerable then
				actionOk = false
			end
		elseif nextAction == 10 then
			if aaCD == -1 or aaRT == -1 then
				actionOk = false
			end
		elseif nextAction == 11 then
			if aaCD == -1 or nEM == -1 then
				actionOk = false
			end
		end
	end
	return nextAction
end
-- opponent out of sight
function jSuccubusMisc.randomAction_wM_unknown(input, eCD, aaCD, aaRT, aaRM, nEM)
	local unitSelf = core.unitSelf
	local actionOk = false
	local nextAction = -1
	local ffirst = true
	while not actionOk do
		actionOk = true
		nextAction = jGeneral.jRandom(1,object.nAs)
		if nextAction == 4 then
			actionOk = false
		elseif nextAction == 5 then
			actionOk = false
		elseif nextAction == 6 then
			actionOk = false
		elseif nextAction == 7 then
			actionOk = false
		elseif nextAction == 8 then
			if eCD < 1  or not skills.mesmerize:CanActivate() then
				actionOk = false
			end
		elseif nextAction == 9 then
			actionOk = false
		elseif nextAction == 10 then
			if aaCD == -1 or aaRT == -1 then
				actionOk = false
			end
		elseif nextAction == 11 then
			if aaCD == -1 or nEM == -1 then
				actionOk = false
			end
		end
	end
	return nextAction
end

-------------------------------------------------------------------------------
--									PICKING ACTION DETERMINED BEST BY NN										 --
-- 1: pursue (opponent)
-- 2: flee (to turret)
-- 3: hold
-- 4: AA (opponent)
-- 5: Q
-- 6: W
-- 7: E, enemy
-- 8: E, self
-- 9: R
-- 10: AA (turret)
-- 11: AA (minion (deny/lasthit))
-------------------------------------------------------------------------------
-- opponent visible
function jSuccubusMisc.nnAction_wM(input, qCD, qR, wCD, wR, eCD, eR, rCD, rR, aaCD, aaRE, aaRT, aaRM, nEM, targetIsInvulnerable)
	local unitSelf = core.unitSelf
	local bestChance = 0
	local nextAction = -1
	for i=1,object.nAs do
		for j=1,object.nAs do
			if i == j then
				input[object.nIsWA+j] = 1
			else
				input[object.nIsWA+j] = -1
			end
		end
		local ntYj, ntYk = jNN.evaluateState(input)
		if nextAction == -1 then
			nextAction = i
			bestChance = ntYk[1]
		else
			local actionOk = true
			if i ==  4 then
				if aaCD == -1 or aaRE == -1 then
					actionOk = false
				end
			elseif i ==  5 then
				if qCD < 1 or qR == -1 or not skills.smitten:CanActivate() or targetIsInvulnerable then
					actionOk = false
				end
			elseif i ==  6 then
				if wCD < 1 or wR == -1 or not skills.heartache:CanActivate() or targetIsInvulnerable then
					actionOk = false
				end
			elseif i ==  7 then
				if eCD < 1 or eR == -1 or not skills.mesmerize:CanActivate() or targetIsInvulnerable then
					actionOk = false
				end
			elseif i ==  8 then
				if eCD < 1  or not skills.mesmerize:CanActivate() then
					actionOk = false
				end
			elseif i ==  9 then
				if rCD < 1 or rR == -1 or not skills.hold:CanActivate() or targetIsInvulnerable then
					actionOk = false
				end
			elseif i ==  10 then
				if aaCD == -1 or aaRT == -1 then
					actionOk = false
				end
			elseif i == 11 then
				if aaCD == -1 or nEM == -1 then
					actionOk = false
				end
			end
			if actionOk and bestChance < ntYk[1] then
				nextAction = i
				bestChance = ntYk[1]
			end
		end
	end
	return nextAction
end
-- opponent not in sight
function jSuccubusMisc.nnAction_wM_unknown(input, eCD, aaCD, aaRT, aaRM, nEM)
	local bestChance = 0
	local nextAction = -1
	local unitSelf = core.unitSelf
	for i=1,object.nAs do
		for j=1,object.nAs do
			if i == j then
				input[object.nIsWA+j] = 1
			else
				input[object.nIsWA+j] = -1
			end
		end
		local ntYj, ntYk = jNN.evaluateState(input)
		if nextAction == -1 then
			nextAction = i
			bestChance = ntYk[1]
		else
			local actionOk = true
			if i == 4 then
				actionOk = false
			elseif i == 5 then
				actionOk = false
			elseif i == 6 then
				actionOk = false
			elseif i == 7 then
				actionOk = false
			elseif i == 8 then
				if eCD < 1 or not skills.mesmerize:CanActivate() then
					actionOk = false
				end
			elseif i == 9 then
				actionOk = false
			elseif i == 10 then
				if aaCD == -1 or aaRT == -1 then
					actionOk = false
				end
			elseif nextAction == 11 then
				if aaCD == -1 or nEM == -1 then
					actionOk = false
				end
			end
			if actionOk and bestChance < ntYk[1] then
				nextAction = i
				bestChance = ntYk[1]
			end
		end
	end
	return nextAction
end

-------------------------------------------------------------------------------
--														EXECUTING ACTIONS															 --
-------------------------------------------------------------------------------
-- opponent visible
function jSuccubusMisc.act_wM(action, unitTarget, interruptAA, queue, shouldHold, shouldClamp)
	if action == 1 then
		jGeneralMovement.moveTowardsOpponent(unitTarget, interruptAA, queue, shouldHold, shouldClamp)
	elseif action == 2 then
		jGeneralMovement.flee_wM(interruptAA, queue, shouldHold, shouldClamp)
	elseif action == 3 then
		jGeneralMovement.standstill(interruptAA, queue, shouldClamp)
	elseif action == 4 then
		jGeneralMovement.attack(unitTarget, queue, shouldClamp)
	elseif action == 5 then
		jSuccubusMisc.useAbility_Q(unitTarget, interruptAA, queue)
	elseif action == 6 then
		jSuccubusMisc.useAbility_W(unitTarget, interruptAA, queue)
	elseif action == 7 then
		jSuccubusMisc.useAbility_E(unitTarget, interruptAA, queue)
	elseif action == 8 then
		jSuccubusMisc.useAbility_ESelf(interruptAA, queue)
	elseif action == 9 then
		jSuccubusMisc.useAbility_R(unitTarget, interruptAA, queue)
	elseif action == 10 then
		if object.oppTower and object.oppTower:IsTower() then
			jGeneralMovement.attackTurret(object.oppTower, queue, shouldClamp)
		end
	elseif action == 11 then
		-- attack creeps
		--		last hit > deny > pushing
		jGeneral.act_attackCreep(queue, shouldHold, shouldClamp)
	end
end
--opponent not in sight
function jSuccubusMisc.act_wM_unknown(action, interruptAA, queue, shouldHold, shouldClamp)
	if action == 1 then
		jGeneralMovement.moveTowardsOpponentTower(interruptAA, queue, shouldHold, shouldClamp)
	elseif action == 2 then
		jGeneralMovement.flee_wM(interruptAA, queue, shouldHold, shouldClamp)
	elseif action == 3 then
		jGeneralMovement.standstill(interruptAA, queue, shouldClamp)
	elseif action == 4 then
	elseif action == 5 then
	elseif action == 6 then
	elseif action == 7 then
	elseif action == 8 then
		jSuccubusMisc.useAbility_ESelf(interruptAA, queue)
	elseif action == 9 then
	elseif action == 10 then
		if object.oppTower and object.oppTower:IsTower() then
			jGeneralMovement.attackTurret(object.oppTower, queue, shouldClamp)
		end
	elseif action == 11 then
		jGeneral.act_attackCreep(queue, shouldHold, shouldClamp)
	end
end
