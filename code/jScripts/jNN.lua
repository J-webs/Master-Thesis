--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
-- NEURAL NETWORK IMPLEMENTATIOn, by Janine Weber @ 2017
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

local _G = getfenv(0)
local object = _G.object

runfile "bots/jScripts/jGeneral.lua"
runfile "bots/jScripts/jGeneralMovement.lua"
runfile "bots/jScripts/jSuccubusMisc.lua"
runfile "bots/jScripts/jDataWriter.lua"


object.jNN = object.jNN or {}
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

local maxTowerHealth = 1500

-------------------------------------------------------------------------------
--								  COLLECT INPUT INFORMATION (opp visible)									 --
-------------------------------------------------------------------------------
function jNN.collectInput(unitSelf, hero1, unitTarget, hero2, AAI)
	-- hero independent info
	local input = {}
	input[1] = jGeneral.getHealth(unitSelf)
	input[2] = jGeneral.getHealth(unitTarget)
	input[3] = jGeneral.getMana(unitSelf)
	input[4] = jGeneral.getMana(unitTarget)
	input[5] = jGeneral.withinAARange(unitSelf, unitTarget)
	local distance = Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition())
	input[6] = jGeneralMovement.getDistanceBetweenHeroes(unitSelf:GetPosition(),unitTarget:GetPosition())
	local distSX, distSY = jGeneralMovement.getDistanceToCenter(unitSelf)
	input[7] = distSX
	input[8] = distSY
	local distTX, distTY = jGeneralMovement.getDistanceToCenter(unitTarget)
	input[9] = distTX
	input[10] = distTY
	local cnt = 11

	-- own hero specific info
	if hero1 == "mSuccubus" then
		-- ability CDs
		input[cnt] = jSuccubusMisc.myselfGetQCD()
		input[cnt+1] = jSuccubusMisc.myselfGetWCD()
		input[cnt+2] = jSuccubusMisc.myselfGetECD()
		input[cnt+3] = jSuccubusMisc.myselfGetRCD()

		-- ability in range
		local succLvl = unitSelf:GetLevel()
		local succQLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 0)
		local succWLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 1)
		local succELvl = jSuccubusMisc.succLeveltoAbility(succLvl, 2)
		local succRLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 3)
		input[cnt+4] = jSuccubusMisc.inRange_Q(distance, succQLvl)
		input[cnt+5] = jSuccubusMisc.inRange_W(distance, succWLvl)
		input[cnt+6] = jSuccubusMisc.inRange_E(distance, succELvl)
		input[cnt+7] = jSuccubusMisc.inRange_R(distance, succRLvl)

		-- conditions infliced on opponent
		input[cnt+8] = jSuccubusMisc.enemyGetQDebuff(succQLvl)
		input[cnt+9] = jSuccubusMisc.enemyGetEDebuff(succELvl)
		input[cnt+10] = jSuccubusMisc.enemyGetRDebuff(succRLvl)

		-- conditions infliced on self
		input[cnt+11] = jSuccubusMisc.myselfGetEDebuff(succELvl)

		-- # of creep denies / kills
		input[cnt+12] = jGeneral.getCreepKills_Scaled(unitSelf, true)
		input[cnt+13] = jGeneral.getCreepDenies_Scaled(unitSelf, true)

		-- can deny/last hit creep
		local creep1, iCanD, creep1Num = jGeneral.canDeny()
		input[cnt+14] = iCanD
		object.creepD_index = 1
		object.creepD_nums = creep1Num
		object.creepDTargets = creep1
		local creep2, iCanLH, creep2Num = jGeneral.canLastHit()
		input[cnt+15] = iCanLH
		object.creepLH_index = 1
		object.creepLH_nums = creep2Num
		object.creepLHTargets = creep2

		-- heroes within tower range (and wether tower aggro)
		input[cnt+16] = jGeneral.inTowerRange(unitSelf, true)
		input[cnt+17] = jGeneral.inTowerRange(unitTarget, false)

		-- avg health of creeps
		local nACreeps, nECreeps = jGeneral.numberOfMinionsUp()
		input[cnt+18] = jGeneral.avgMinionHealth(true)
		input[cnt+19] = jGeneral.avgMinionHealth(false)

		-- can auto attack
		if unitSelf:IsAttackReady() then
			input[cnt+20] = 1
		else
			input[cnt+20] = -1
		end

		-- taking dmg from minions
		input[cnt+21] = jGeneral.creepAggro(unitSelf, true)
		cnt = cnt+21+1
	end

	-- opponent hero specific info
	if hero2 == "mSuccubus" then
		-- abilites, estimations
		local succLvl = unitSelf:GetLevel()
		local succQLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 0)
		local succWLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 1)
		local succELvl = jSuccubusMisc.succLeveltoAbility(succLvl, 2)
		local succRLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 3)
		input[cnt] = jSuccubusMisc.enemyGetQCD(succQLvl)
		input[cnt+1] = jSuccubusMisc.enemyGetWCD(succWLvl)
		input[cnt+2] = jSuccubusMisc.enemyGetECD(succELvl)
		input[cnt+3] = jSuccubusMisc.enemyGetRCD(succRLvl)

		-- conditions inflicted by opponent
		input[cnt+4] = jSuccubusMisc.myselfGetQDebuff(succQLvl)
		input[cnt+5] = jSuccubusMisc.myselfGetRDebuff(succRLvl)

		-- in case opponent is different hero
		if hero1 ~= "mSuccubus" then
			-- ability ranges
			input[cnt+6] = jSuccubusMisc.inRange_Q(distance, succQLvl)
			input[cnt+7] = jSuccubusMisc.inRange_W(distance, succWLvl)
			input[cnt+8] = jSuccubusMisc.inRange_E(distance, succELvl)
			input[cnt+9] = jSuccubusMisc.inRange_R(distance, succRLvl)
			cnt = cnt+9+1
		else
			cnt = cnt+5+1
		end

		-- opponent's # of creep denies/kills
		input[cnt] = jGeneral.getCreepKills_Scaled(unitTarget, false)
		input[cnt+1] = jGeneral.getCreepDenies_Scaled(unitTarget, false)

		-- opponent can AA
		if unitTarget:IsAttackReady() then
			input[cnt+2] = 1
		else
			input[cnt+2] = -1
		end

		-- opponent has creep aggro
		input[cnt+3] = jGeneral.creepAggro(unitTarget, false)
		cnt = cnt + 3
	end

	cnt = cnt + 1

	-- general game info
	input[cnt] = jGeneral.getTowerHealth(true)
	input[cnt+1] = jGeneral.getTowerHealth(false)
	input[cnt+2] = jGeneral.nextCreepWave()
	cnt = cnt+2
	if AAI then
		for i=1,object.nAs do
			input[cnt+i] = 0
		end
	end
	return input
end

-------------------------------------------------------------------------------
--							  COLLECT INPUT INFORMATION (opp not visible)								 --
-------------------------------------------------------------------------------
function jNN.collectInput_unknown(unitSelf, hero1, hero2, AAI)
	local input = {}
	input[1] = jGeneral.getHealth(unitSelf)

	-- estimate opponent's health/mana based on regen
	local timeSinceLastSeen = (HoN.GetMatchTime() - object.lastSeenOpponentTimestamp)/1000
	input[2] = object.tYi[2] + object.lastSeenOpponentHealthRegen*timeSinceLastSeen
	input[3] = jGeneral.getMana(unitSelf)
	input[4] = object.tYi[4] + object.lastSeenOpponentManaRegen*timeSinceLastSeen

	input[5] = -1 -- not in AA range
	input[6] = 1 	-- max distance btw heroes
	local distSX, distSY = jGeneralMovement.getDistanceToCenter(unitSelf)
	input[7] = distSX
	input[8] = distSY

	-- max distance from opp to center
	input[9] = 1
	input[10] = 1
	local cnt = 11

	if hero1 == "mSuccubus" then
		input[cnt] = jSuccubusMisc.myselfGetQCD()
		input[cnt+1] = jSuccubusMisc.myselfGetWCD()
		input[cnt+2] = jSuccubusMisc.myselfGetECD()
		input[cnt+3] = jSuccubusMisc.myselfGetRCD()

		local succLvl = unitSelf:GetLevel()
		local succQLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 0)
		local succWLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 1)
		local succELvl = jSuccubusMisc.succLeveltoAbility(succLvl, 2)
		local succRLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 3)

		-- not in ability range
		input[cnt+4] = -1
		input[cnt+5] = -1
		input[cnt+6] = -1
		input[cnt+7] = -1

		input[cnt+8] = jSuccubusMisc.enemyGetQDebuff(succQLvl)
		input[cnt+9] = jSuccubusMisc.enemyGetEDebuff(succELvl)
		input[cnt+10] = jSuccubusMisc.enemyGetRDebuff(succRLvl)

		input[cnt+11] = jSuccubusMisc.myselfGetEDebuff(succELvl)

		input[cnt+12] = jGeneral.getCreepKills_Scaled(unitSelf, true)
		input[cnt+13] = jGeneral.getCreepDenies_Scaled(unitSelf, true)

		local creep1, iCanD, creep1Num = jGeneral.canDeny()
		input[cnt+14] = iCanD
		object.creepD_index = 1
		object.creepD_nums = creep1Num
		object.creepDTargets = creep1
		local creep2, iCanLH, creep2Num = jGeneral.canLastHit()
		input[cnt+15] = iCanLH
		object.creepLH_index = 1
		object.creepLH_nums = creep2Num
		object.creepLHTargets = creep2

		input[cnt+16] = jGeneral.inTowerRange(unitSelf, true)
		input[cnt+17] = -1 -- opp not in tower range

		local nACreeps, nECreeps = jGeneral.numberOfMinionsUp()
		input[cnt+18] = jGeneral.avgMinionHealth(true)
		input[cnt+19] = jGeneral.avgMinionHealth(false)

		if unitSelf:IsAttackReady() then
			input[cnt+20] = 1
		else
			input[cnt+20] = -1
		end

		input[cnt+21] = jGeneral.creepAggro(unitSelf, true)
		cnt = cnt+21+1
	end

	if hero2 == "mSuccubus" then
		local succLvl = unitSelf:GetLevel()
		local succQLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 0)
		local succWLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 1)
		local succELvl = jSuccubusMisc.succLeveltoAbility(succLvl, 2)
		local succRLvl = jSuccubusMisc.succLeveltoAbility(succLvl, 3)
		input[cnt] = jSuccubusMisc.enemyGetQCD(succQLvl)
		input[cnt+1] = jSuccubusMisc.enemyGetWCD(succWLvl)
		input[cnt+2] = jSuccubusMisc.enemyGetECD(succELvl)
		input[cnt+3] = jSuccubusMisc.enemyGetRCD(succRLvl)

		input[cnt+4] = jSuccubusMisc.myselfGetQDebuff(succQLvl)
		input[cnt+5] = jSuccubusMisc.myselfGetRDebuff(succRLvl)

		if hero1 ~= "mSuccubus" then
			-- not in ability range
			input[cnt+6] = -1
			input[cnt+7] = -1
			input[cnt+8] = -1
			input[cnt+9] = -1
			cnt = cnt+9+1
		else
			cnt = cnt+5+1
		end
		--last known creep kill/deny count
		input[cnt] = object.tYi[cnt]
		input[cnt+1] = object.tYi[cnt+1]

		input[cnt+2] = 1	-- AA ready
	 	input[cnt+3] = -1 -- opp no creep aggro
	 	cnt = cnt + 3
	end
	cnt = cnt + 1
	input[cnt] = jGeneral.getTowerHealth(true)
	input[cnt+1] = jGeneral.getTowerHealth(false)
	input[cnt+2] = jGeneral.nextCreepWave()
	cnt = cnt+2
	if AAI then
		for i=1,object.nAs do
			input[cnt+i] = 0
		end
	end
	return input
end

-------------------------------------------------------------------------------
--												  SET PREMATCH NN INPUT														 --
-------------------------------------------------------------------------------
function jNN.initialInput(hero1, hero2, AAI)
	local input = {}
	input[1] = 1 	-- self health
	input[2] = 1 	-- opp health
	input[3] = 1 	-- self mana
	input[4] = 1	-- opp mana
	input[5] = -1	-- AA range
	input[6] = 1	-- dist between heroes
	input[7] = 1	-- self dist to center x
	input[8] = 1	-- self dist to center y
	input[9] = 1	-- opp dist to center x
	input[10] = 1	-- opp dist to center y
	local cnt = 11
	if hero1 == "mSuccubus" then
		input[cnt] = 1 			-- Q CD
		input[cnt+1] = 1		-- W CD
		input[cnt+2] = 1		-- E CD
		input[cnt+3] = 1		-- R CD
		input[cnt+4] = -1		-- Q inR
		input[cnt+5] = -1		-- W inR
		input[cnt+6] = -1 	-- E inR
		input[cnt+7] = -1		-- R inR
		input[cnt+8] = -1		-- opp has Q debuff
		input[cnt+9] = -1		-- opp has E debuff
		input[cnt+10] = -1	-- opp has R debuff
		input[cnt+11] = -1	-- self has E debuff
		input[cnt+12] = -1	-- # CS
		input[cnt+13] = -1	-- # CD
		input[cnt+14] = -1	-- can CS
		input[cnt+15] = -1	-- can CD
		input[cnt+16] = -1	-- self in tower range
		input[cnt+17] = -1	-- opp in tower range
		input[cnt+18] = 1		-- own creep health
		input[cnt+19] = 1		-- opp creep health
		input[cnt+20] = 1		-- AA ready
		input[cnt+21] = -1	-- self has creep aggro
		cnt = cnt+21+1
	end
	if hero2 == "mSuccubus" then
		input[cnt] = 1			-- Q CD
		input[cnt+1] = 1		-- W CD
		input[cnt+2] = 1		-- E CD
		input[cnt+3] = 1		-- R CD
		input[cnt+4] = -1		-- self has Q debuff
		input[cnt+5] = -1		-- self has R debuff
		if hero1 ~= "mSuccubus" then
			input[cnt+6] = -1	-- Q inR
			input[cnt+7] = -1	-- W inR
			input[cnt+8] = -1	-- E inR
			input[cnt+9] = -1	-- R inR
			cnt = cnt+9+1
		else
			cnt = cnt+5+1
		end
		input[cnt] = -1		-- opp # CS
		input[cnt+1] = -1	-- opp #CD
		input[cnt+2] = 1	-- opp AA ready
		input[cnt+3] = -1	-- opp has creep aggro
		cnt = cnt + 3
	end
	cnt = cnt + 1
	input[cnt] = 1		-- tower health self
	input[cnt+1] = 1	-- tower health opp
	input[cnt+2] = -1	-- next creep wave
	cnt = cnt+2
	if AAI then
		for i=1,object.nAs do
			input[cnt+i] = 0
		end
	end
	object.tYi = input
	return input
end


-------------------------------------------------------------------------------
--												  INITIALIZE NN WEIGHTS														 --
-------------------------------------------------------------------------------
function jNN.initializeWeights()
	-- weights between values low and high
  local lowv = 0.01
  local highv = 0.15
  local loww = 0.01
  local highw = 0.25

	-- initialize weights with small random values --
  object.w = {} --weights from hidden to output
	object.v = {} --weights from input to hidden
	object.bw = {} -- bias weights to output
	object.bv = {} -- bias weights to hidden
  for j = 1,object.nHs do
    object.w[j] = {}
    for k = 1,object.nOs do
      object.w[j][k] = jGeneral.jRandomWeights(loww,highw)
    end
  end  for i = 1,object.nIs do
    object.v[i] = {}
    for j = 1,object.nHs do
      object.v[i][j] = jGeneral.jRandomWeights(lowv,highv)
    end
  end
  for k = 1,object.nOs do
    object.bw[k] = jGeneral.jRandomWeights(loww,highw)
  end
  for j = 1,object.nHs do
    object.bv[j] = jGeneral.jRandomWeights(lowv,highv)
  end

	-- initialize eligibility traces --
  object.ew = {} -- hidden to output
  object.ev = {} -- input to hidden to output
	object.bew = {} -- bias hidden to output
	object.bev = {} -- bias input to hidden to output
  for i = 1,object.nIs do
    object.ev[i] = {}
    for j = 1,object.nHs do
      object.ev[i][j] = {}
      object.ew[j] = {}
      for k = 1,object.nOs do
        object.ev[i][j][k] = 0
        object.ew[j][k] = 0
      end
    end
  end
  for j = 1,object.nHs do
    object.bev[j] = {}
    for k = 1,object.nOs do
      object.bev[j][k] = 0
    end
  end
  for k = 1,object.nOs do
    object.bew[k] = 0
  end

	-- initialize past neural network state
  object.tYi = {} -- input
	object.tYj = {} -- hidden layer activation
	object.tYk = {} -- output layer activation
  for i = 1,object.nIs do
    object.tYi[i] = 0
  end
  for j = 1,object.nHs do
    object.tYj[j] = 0
  end
  for k = 1,object.nOs do
    object.tYk[k] = 0
  end
end

-------------------------------------------------------------------------------
--											  LOAD SPECIFIC NN WEIGHTS													 --
-------------------------------------------------------------------------------
function jNN.loadWeights(heroName)
	--init objects
	jNN.initializeWeights()
	
	-- read from given database
	local tmp_jDB_w = Database.New(heroName..'_wDB.ldb')
	local tmp_jDB_v = Database.New(heroName..'_vDB.ldb')
	local tmp_jDB_bw = Database.New(heroName..'_bwDB.ldb')
	local tmp_jDB_bv = Database.New(heroName..'_bvDB.ldb')

	-- set weight values
	for i = 1,object.nIs do
		for j = 1,object.nHs do
			object.v[i][j] = tonumber(tmp_jDB_v[i..","..j])
		end
	end
	for j = 1,object.nHs do
		for k = 1,object.nOs do
			object.w[j][k] = tonumber(tmp_jDB_w[j..","..k])
		end
	end
	for k = 1,object.nOs do
	  object.bw[k] = tonumber(tmp_jDB_bw[""..k])
	end
	for j = 1,object.nHs do
	  object.bv[j] = tonumber(tmp_jDB_bv[""..j])
	end

	-- init traces
	for i = 1,object.nIs do
	  for j = 1,object.nHs do
	    for k = 1,object.nOs do
	      object.ev[i][j][k] = 0
	    end
	  end
	end
	  for j = 1,object.nHs do
	    for k = 1,object.nOs do
	      object.ew[j][k] = 0
	    end
	  end
	for j = 1,object.nHs do
	  for k = 1,object.nOs do
	    object.bev[j][k] = 0
	  end
	end
	for k = 1,object.nOs do
	  object.bew[k] = 0
	end
end

-------------------------------------------------------------------------------
--													  CLEAR EVENT TRACES														 --
-------------------------------------------------------------------------------
function jNN.resetEligibilityTrace()
	for i = 1,object.nIs do
	  for j = 1,object.nHs do
	    for k = 1,object.nOs do
	      object.ev[i][j][k] = 0
	    end
	  end
	end
	  for j = 1,object.nHs do
	    for k = 1,object.nOs do
	      object.ew[j][k] = 0
	    end
	  end
	for j = 1,object.nHs do
	  for k = 1,object.nOs do
	    object.bev[j][k] = 0
	  end
	end
	for k = 1,object.nOs do
	  object.bew[k] = 0
	end
end

-- SIGMOID FUNCTION
function jNN.jSigmoid(sum)
  local e = math.exp(1)
  local myexp = e^(-sum)
  local mysig = 1/(1+myexp)
  return mysig
end

-- MEAN SQUARED ERROR
function jNN.jMSE(ntYk,reward)
  local myerror = {}
  for k = 1,object.nOs do
    myerror[k] = reward[k] + object.gamma*ntYk[k] - object.tYk[k]
  end
  return myerror
end

-------------------------------------------------------------------------------
--													  NN FORWARD PASS																 --
-------------------------------------------------------------------------------
function jNN.forwardMove(ntYi)
	-- forward flow from input -> hidden --
	-- weighted sum
  local jSum = {}
  for j = 1,object.nHs do
    jSum[j] = object.bv[j]
  end
  for i = 1,object.nIs do
    for j = 1,object.nHs do
			jSum[j] = jSum[j]+object.v[i][j]*ntYi[i]
    end
  end
	-- activation output
  local ntYj = {}
  for j = 1,object.nHs do
    ntYj[j] = jNN.jSigmoid(jSum[j])
  end

	-- forward flow from hidden -> output --
	-- weighted sum
  local kSum = {}
  for k = 1,object.nOs do
    kSum[k] = object.bw[k]
  end
  for j = 1,object.nHs do
    for k = 1,object.nOs do
      kSum[k] = kSum[k]+object.w[j][k]*ntYj[j]
    end
  end
	--activation output
  local ntYk = {}
  for k = 1,object.nOs do
    ntYk[k] = jNN.jSigmoid(kSum[k])
  end
  return ntYj, ntYk
end
function jNN.evaluateState(predictedState)
  local ntYi = {}
  for i = 1,object.nIs do
    ntYi[i] = predictedState[i]
  end
	local ntYj,ntYk = jNN.forwardMove(ntYi)
  return ntYj, ntYk
end

-- legacy functions
function jNN.learnIntermediateActionAsInput(reward, observedState)
  jNN.learn(reward, observedState, 0, 0, 0)
end
function jNN.learnFinalActionAsInput(reward, observedState, iWon)
  jNN.learn(reward, observedState, 1, iWon, 0)
end
function jNN.learnIntermediateActionAsOut(reward, observedState, actionChosen)
  jNN.learn(reward, observedState, 2, 0, actionChosen)
end
function jNN.learnFinalActionAsOutput(reward, observedState, iWon, actionChosen)
  jNN.learn(reward, observedState, 3, iWon, actionChosen)
end

-------------------------------------------------------------------------------
--							  NN BACKWARD PASS (intermediate actions)										 --
-------------------------------------------------------------------------------
function jNN.learn(reward, input, ntYk)
  local ntYi = {}
  for i = 1,object.nIs do
    ntYi[i] = input[i]
  end

	-- mean squared error at output
  local myerror = jNN.jMSE(ntYk,reward)

	-- init new trace objects
  local n_ev = {}
  local n_ew = {}
  local n_bev = {}
  local n_bew = {}
  for i = 1,object.nIs do
    n_ev[i] = {}
    for j = 1,object.nHs do
      n_bev[j] = {}
      n_ew[j] = {}
      n_ev[i][j] = {}
      for k = 1,object.nOs do
        n_bev[j][k] = 0
        n_bew[k] = 0
        n_ew[j][k] = 0
        n_ev[i][j][k] = 0
      end
    end
  end

	-- COMPUTE UPDATED ELIGIBILITY TRACES
  for k = 1,object.nOs do
    local mk = object.tYk[k]*(1-object.tYk[k]) -- sigmoid derivative (output units)
		-- trace at bias for output
    n_bew[k] = mk + object.bew[k]*object.lambda -- updated trace = sig.deriv. + old elig trace decayed by lambda
    for j = 1,object.nHs do
      n_ew[j][k] = mk*object.tYj[j]	--  sig deriv. * hidden activation
      local mj = n_ew[j][k]*(1-object.tYj[j])*object.w[j][k] -- hidden->output trace * sigmoid derivative (hidden units) * hidden->output weights
			-- trace at bias for hidden
      n_bev[j][k] = mj + object.bev[j][k]*object.lambda
      for i = 1,object.nIs do
				-- trace at input->hidden->output
        n_ev[i][j][k] = mj*object.tYi[i] + object.ev[i][j][k]*object.lambda -- upt trace = gradient + old trace decayed
      end
			-- trace at hidden->output
      n_ew[j][k] = n_ew[j][k] + object.ew[j][k]*object.lambda
    end
  end

	-- COMPUTE WEIGHT CHANGES
  local incrw = {} 	-- hidden->output
  local incrbw = {} -- bias for output
  for k = 1,object.nOs do
    incrbw[k] = n_bew[k]*object.alpha*myerror[k]
  end
  for j = 1,object.nHs do
    incrw[j] = {}
    for k = 1,object.nOs do
      incrw[j][k] = n_ew[j][k]*object.alpha*myerror[k]
    end
  end
  local incrv = {} -- input->hidden
  local incrbv = {}-- bias for hidden
  for i = 1,object.nIs do
    incrv[i] = {}
    for j = 1,object.nHs do
      local sumks = 0
      local bsumks = 0
      for k = 1,object.nOs do
        sumks = sumks+myerror[k]*n_ev[i][j][k]
        bsumks = bsumks+myerror[k]*n_bev[j][k]
      end
      incrv[i][j] = object.alpha*sumks
      incrbv[j] = object.alpha*bsumks
    end
  end

	-- UPDATE WEIGHTS
  for i = 1,object.nIs do
    for j = 1,object.nHs do
      object.v[i][j] = object.v[i][j]+incrv[i][j]
    end
  end
  for j = 1,object.nHs do
    object.bv[j] = object.bv[j]+incrbv[j]
  end
  for j = 1,object.nHs do
    for k = 1,object.nOs do
      object.w[j][k] = object.w[j][k]+incrw[j][k]
    end
  end
  for k = 1,object.nOs do
    object.bw[k] = object.bw[k]+incrbw[k]
  end

  object.tYi = ntYi
  object.tYj, object.tYk = jNN.forwardMove(object.tYi)
  object.ew = n_ew
  object.ev = n_ev
  object.bew = n_bew
  object.bev = n_bev
end

-------------------------------------------------------------------------------
--									  NN BACKWARD PASS (final action)												 --
-------------------------------------------------------------------------------
function jNN.learn_final(reward, ntYk)
	-- update weights given game outcome

	-- MSE
  local myerror = jNN.jMSE(ntYk,reward)

	-- init objects
  local n_ev = {}
  local n_ew = {}
  local n_bev = {}
  local n_bew = {}
  for i = 1,object.nIs do
    n_ev[i] = {}
    for j = 1,object.nHs do
      n_bev[j] = {}
      n_ew[j] = {}
      n_ev[i][j] = {}
      for k = 1,object.nOs do
        n_bev[j][k] = 0
        n_bew[k] = 0
        n_ew[j][k] = 0
        n_ev[i][j][k] = 0
      end
    end
  end

	-- compute updated traces
  for k = 1,object.nOs do
    local mk = object.tYk[k]*(1-object.tYk[k])
    n_bew[k] = mk + object.bew[k]*object.lambda
    for j = 1,object.nHs do
      n_ew[j][k] = mk*object.tYj[j]
      local mj = n_ew[j][k]*(1-object.tYj[j])*object.w[j][k]
      n_bev[j][k] = mj + object.bev[j][k]*object.lambda
      for i = 1,object.nIs do
        n_ev[i][j][k] = mj*object.tYi[i] + object.ev[i][j][k]*object.lambda
      end
      n_ew[j][k] = n_ew[j][k] + object.ew[j][k]*object.lambda
    end
  end

	-- compute weight increments
  local incrw = {}
  local incrbw = {}
  for k = 1,object.nOs do
    incrbw[k] = n_bew[k]*object.alpha*myerror[k]
  end
  for j = 1,object.nHs do
    incrw[j] = {}
    for k = 1,object.nOs do
      incrw[j][k] = n_ew[j][k]*object.alpha*myerror[k]
    end
  end
  local incrv = {}
  local incrbv = {}
  for i = 1,object.nIs do
    incrv[i] = {}
    for j = 1,object.nHs do
      local sumks = 0
      local bsumks = 0
      for k = 1,object.nOs do
        sumks = sumks+myerror[k]*n_ev[i][j][k]
        bsumks = bsumks+myerror[k]*n_bev[j][k]
      end
      incrv[i][j] = object.alpha*sumks
      incrbv[j] = object.alpha*bsumks
    end
  end

	-- update weights
  for i = 1,object.nIs do
    for j = 1,object.nHs do
      object.v[i][j] = object.v[i][j]+incrv[i][j]
    end
  end
  for j = 1,object.nHs do
    object.bv[j] = object.bv[j]+incrbv[j]
  end
  for j = 1,object.nHs do
    for k = 1,object.nOs do
      object.w[j][k] = object.w[j][k]+incrw[j][k]
    end
  end
  for k = 1,object.nOs do
    object.bw[k] = object.bw[k]+incrbw[k]
  end
end

--learn from consequences even though we cannot act
function jNN.learnWhileCC(unitSelf, unitTarget)
	local timeSinceLastLearning = HoN.GetMatchTime() - object.lastLearningTimestamp
	if timeSinceLastLearning >= 250 then --every 250ms
		if object.actionToExecute == 1 or object.actionToExecute == 2 or object.actionToExecute == 3 then
			object.lastExecutedAction = object.actionToExecute
			object.lastExecutedAction_IsRandom = object.actionToExecute_IsRandom
		end
		jNN.learnFromPast(unitSelf, unitTarget, false)
	end
end

--learn from past actions
function jNN.learnFromPast(unitSelf, unitTarget, isAction)
	local input
	if unitTarget ~= nil then
		input = jNN.collectInput(unitSelf, "mSuccubus", unitTarget, "mSuccubus", true)
	else
		input = jNN.collectInput_unknown(unitSelf, "mSuccubus", "mSuccubus", true)
	end
	for i=1,object.nAs do
		if i == object.actionToExecute then
			input[object.nIsWA+i] = 1
		else
			input[object.nIsWA+i] = -1
		end
	end
	-- evaluate state after action
	local ntYj, ntYk = jNN.evaluateState(input)
	--jDataWriter.writeState(input, false)
	--write last action and consequences to database
	if isAction then
		jDataWriter.writeAction(ntYk[1], object.tYk[1], object.matchStart, object.actionToExecute,
						object.actionToExecute_IsRandom, object.randomActionChance, object.currentMatch, object.currentAction)
	end
	-- learn from new situation (better/worse?)
	local reward = {}
	for i=1,object.nOs do
			reward[i] = 0
	end
	if learning then
		jNN.learn(reward, input, ntYk)
	end

	--prepare for next action
	if isAction then
		object.lastExecutedAction = object.actionToExecute
		object.lastExecutedAction_IsRandom = object.actionToExecute_IsRandom
		object.currentAction = object.currentAction + 1
	else
		object.lastExecutedAction = object.lastExecutedAction
		object.lastExecutedAction_IsRandom = object.lastExecutedAction_IsRandom
	end
	object.lastLearningTimestamp = HoN.GetMatchTime()
	object.pickingAction = true
	object.executingAction = false
	object.executedAction = false
end

--record the predecessor state
function jNN.updateLastState(input)
	for i=1,object.nAs do
		if i == object.actionToExecute then
			input[object.nIsWA+i] = 1
		else
			input[object.nIsWA+i] = -1
		end
	end
	object.pickingAction = false
	object.executingAction = true
	object.pickingActionTimestamp = HoN.GetMatchTime()

	local ntYj, ntYk = jNN.evaluateState(input)
	object.tYi = input
	object.tYj = ntYj
	object.tYk = ntYk
end
