--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
-- SUCCBUS BOT LOGIC CODE, by Janine Weber @ 2017
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

local _G = getfenv(0)
local object = _G.object

----------------------------------------------------------
--  								 default settings										--
----------------------------------------------------------

object.myName = object:GetName()

object.bRunLogic		 = true
object.bRunBehaviors	= true
object.bUpdates		 = true
object.bUseShop		 = true

object.bRunCommands	 = true
object.bMoveCommands	 = true
object.bAttackCommands	 = true
object.bAbilityCommands = true
object.bOtherCommands	 = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core		 = {}
object.eventsLib	 = {}
object.metadata	 = {}
object.behaviorLib	 = {}
object.skills		 = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"
runfile "bots/jScripts/jGeneral.lua"
runfile "bots/jScripts/jNN.lua"
runfile "bots/jScripts/jGeneralMovement.lua"
runfile "bots/jScripts/jDataWriter.lua"
runfile "bots/jScripts/jSuccubusMisc.lua"

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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
				= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan,
				_G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos,
				_G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local tBottle = {}
local illusionLib = object.illusionLib

BotEcho(object:GetName()..' loading succubus_main...')

object.heroName = 'Hero_Succubis'

------------------------------
--					 skills				  --
------------------------------
local bSkillsValid = false
-- skillbuild table, 0=smitten, 1=heartache, 2=mesmerize, 3=ult, 4=attribute
object.jSkills = {
	1, 2, 0, 1, 1,
	3, 1, 0, 2, 0,
	3, 2, 0, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}
function object:SkillBuild()
 	local unitSelf = self.core.unitSelf
	-- setup abilities
	if not bSkillsValid then
		skills.smitten = unitSelf:GetAbility(0)
		skills.heartache = unitSelf:GetAbility(1)
		skills.mesmerize = unitSelf:GetAbility(2)
		skills.hold = unitSelf:GetAbility(3)

		if skills.smitten and skills.heartache and skills.mesmerize and skills.hold then
			bSkillsValid = true
		else
			return
		end
	end
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	-- level up abilities
	local nLevel = unitSelf:GetLevel()
	local nLevelPoints = unitSelf:GetAbilityPointsAvailable()
	for i = 1, nLevel do
		unitSelf:GetAbility( object.jSkills[i] ):LevelUp()
	end
end

---------------------------------------------------------
--											Onthink					   						 --
---------------------------------------------------------
local filesLocation = "AAI\\succubusVsSuccubusWM\\setupE\\batch1\\"..object:GetName().."\\"
local heroName = "mSuccubus"
local setupComment = "succ vs succ lvl 16; with towers and minions; 44 + 11 (removed LH/deny) inputs; 15 creeps / turret death / player death, updated map again (more space) more hidden units"

-- NN
object.nIs = 56
object.nHs = 25
object.nOs = 1
object.alpha = 0.3
object.beta = 0.3
object.gamma = 1
object.lambda = 0.9
object.nIsWA = 45
object.nAs = 11
local loadWeights = true
local learning = true
-- ACTIONS:
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

-- e-greedy
object.randomActionChance = 0
object.randomChanceDecrease = 0.0001
object.randomChanceLowerBound = 0.01
local randoming = true

-- match stats
object.currentMatch = 0
object.currentAction = 1
object.matchOver = false
object.matchOutcome = -1
object.resetting = false
object.matchStart = 0
object.matchEnd = 0
object.matchOutcomeStr = ""
local counter = 1

-- action/learning
object.actionToExecute = 3 --hold
object.actionToExecute_IsRandom = 0 -- no
object.lastExecutedAction = 3
object.lastExecutedAction_IsRandom = 0
object.pickingAction = true
object.pickingActionTimestamp = 0
object.executingAction = false
object.executedAction = false
object.lastLearningTimestamp = 0

-- game objects/ids
object.myOpponent = nil
object.myTower = nil
object.oppTower = nil
object.legionTowerId = 26
object.hellbourneTowerId = 17
object.legionHeroId = 31
object.hellbourneHeroId = 39
object.heroLevel = 16

-- to reset match
object.once = false
object.onceResetKill = false
object.initResetDone = false

-- game stats
object.neededCreeps = 15
object.selfCreepKills = 0
object.selfCreepDenies = 0
object.enemyCreepKills = 0
object.enemyCreepDenies = 0

-- creep lists
object.creepLH_index = 1
object.creepLH_nums = 0
object.creepLHTargets = {}
object.creepD_index = 1
object.creepD_nums = 0
object.creepDTargets = {}
object.creepTarget = nil

-- game info (for possible unknown future)
object.lastTargetPosition = {}
object.lastSeenOpponentHealthRegen = 0
object.lastSeenOpponentManaRegen = 0
object.lastSeenOpponentTimestamp = 0
object.hasSeenOppTower = false

function object:onthinkOverride(tGameVariables)
	-- proccess game units (heroes/towers/creeps)
	jGeneral.processUnits(object, tGameVariables)

	-- init objects (enemy and towers)
	jGeneral.setupObjects()

	--#1 at start of test, initialize game setup
	if counter == 1 then
		jGeneral.setupHeroes() --xp/creeps

		-- hero levels
		jGeneral.levelUpHero(object.heroLevel, object.legionHeroId)
		jGeneral.levelUpHero(object.heroLevel, object.hellbourneHeroId)

		-- init hero specifics
		jSuccubusMisc.setup()

		-- init map coordinates
		jGeneralMovement.initMapParameters(0, 3070, 900, 2170, 550, 2520)

		-- init Neural Network
		if loadWeights then
			jNN.loadWeights("mSuccubus1\\"..heroName)
		else
			jNN.initializeWeights()
		end
		local input = jNN.initialInput("mSuccubus", "mSuccubus", true)
		object.tYi = input

		-- init database, write setup parameters
		jDataWriter.initDatabases(filesLocation, heroName)
		jDataWriter.writeParameters(setupComment)
		jDataWriter.writeWeights()

		object.currentMatch = object.currentMatch+1
	else --#1
		-- write weights to DB
		if object.currentMatch % 100 == 1 then
			jDataWriter.writeWeights()
		end

		-- match over?
		jGeneral.checkIfMatchEnded()
		if object.matchOver and not object.resetting then
			jGeneral.declareMatchEnd()
		end

		if object.resetting then
			jGeneral.setupNextMatch()
		else -- ongoing match
			local unitSelf = core.unitSelf
			local unitTarget = behaviorLib.heroTarget

			if unitSelf and unitTarget and unitTarget:IsValid() and core.CanSeeUnit(object, unitTarget) then

				-- collect / update game state knowledge
				jGeneral.recordOppInfo(unitTarget)
				jSuccubusMisc.myselfCheckDebuffs_QR()
				jSuccubusMisc.enemyCheckDebuffs(unitTarget)
				jSuccubusMisc.enemyCheckCDs_ESelf(unitTarget)

				local timesincepicking = HoN.GetMatchTime() - object.pickingActionTimestamp

				if unitSelf:IsStunned() or unitSelf:IsChanneling() then -- unable to act
					--learn from consequences of past actions / opp actions
					jNN.learnWhileCC(unitSelf, unitTarget) -- every 250ms
				else -- not stunned
					if object.pickingAction and timesincepicking >= 250 then
						local input = jNN.collectInput(unitSelf, "mSuccubus", unitTarget, "mSuccubus", true)

						-- pick an action (random chance vs. best evaluated by neural network)
						local jRndA = random()
						if jRndA <= object.randomActionChance then
							jSuccubusMisc.action_wM_CI(input, unitSelf, unitTarget, true)
						else
							jSuccubusMisc.action_wM_CI(input, unitSelf, unitTarget, false)
						end

						-- update our visited state
						jNN.updateLastState(input)

						-- execute action
						jSuccubusMisc.act_wM(object.actionToExecute, unitTarget, true, false, true, false)
					else -- not pickingAction

						-- check non-ability actions
						jGeneral.isActionDone()

						-- continue acting
						if object.executingAction then
							jSuccubusMisc.act_wM(object.actionToExecute, unitTarget, true, false, true, false)
						end

						-- action has been executed!
						if object.executedAction then
							-- learn from action's consequences
							jNN.learnFromPast(unitSelf, unitTarget, true)
						end
					end -- picking end
				end -- stunned end
			else -- no target (opponent MIA)
				-- cannot see opponent, must make use of past information / predictions
				local timesincepicking = HoN.GetMatchTime() - object.pickingActionTimestamp

				if unitSelf:IsStunned() or unitSelf:IsChanneling() then
					jNN.learnWhileCC(unitSelf, nil) -- every 250ms
				else -- not stunned

					if object.pickingAction and timesincepicking >= 250 then
						local input = jNN.collectInput_unknown(unitSelf, "mSuccubus", "mSuccubus", true)

						local jRndA = random()
						if jRndA <= object.randomActionChance then
							local nextAction = jSuccubusMisc.action_wM_CI_unknown(input, unitSelf, true)
						else
							local nextAction = jSuccubusMisc.action_wM_CI_unknown(input, unitSelf, false)
						end

						jNN.updateLastState(input)

						jSuccubusMisc.act_wM_unknown(object.actionToExecute, true, false, true, false)
					else -- not pickingAction
						jGeneral.isActionDone()

						if object.executingAction then
							jSuccubusMisc.act_wM_unknown(object.actionToExecute, true, false, true, false)
						end

						if object.executedAction then
							jNN.learnFromPast(unitSelf, nil, true)
						end
					end -- picking end
				end -- stunned end
			end -- unitTarget end
		end -- reset end
	end -- counter end
	counter = counter + 1
end
object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride

------------------------------------------
--			oncombatevent override		--
------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget

	-- update own conditions
	jSuccubusMisc.myselfCheckDebuffs_E(EventData)

	-- update opponent conditions
	if unitTarget and unitTarget:IsValid() then
		jSuccubusMisc.enemyCheckCDs(unitTarget, EventData)
	end
	jSuccubusMisc.abilityWasExecuted(EventData)
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent	= object.oncombateventOverride

BotEcho('finished loading succubus_main')
