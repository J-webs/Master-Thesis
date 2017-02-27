--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--
-- HON DATA WRITER, by Janine Weber @ 2017
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++--

local _G = getfenv(0)
local object = _G.object

object.jDataWriter = object.jDataWriter or {}
local core, eventsLib, behaviorLib, metadata, jNN, jGeneral, jDataWriter,
			jGeneralMovement = object.core, object.eventsLib, object.behaviorLib,
												 object.metadata, object.jNN, object.jGeneral,
												 object.jDataWriter, object.jGeneralMovement

local print, ipairs, pairs, string, table, next, type, tinsert,
			tremove, tsort, format, tostring, tonumber, strfind, strsub
				= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next,
					_G.type, _G.table.insert, _G.table.remove, _G.table.sort,
					_G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
				= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan,
					_G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos,
					_G.math.asin, _G.math.max, _G.math.random

local jDBs = jDBs or {}
function jDataWriter.initDatabases(filesLocation, heroName)
  jDBs.path = tostring(filesLocation..heroName)
	print(jDBs.path.."\n")
  jDBs.parametersDB = Database.New(filesLocation..heroName..'_parametersDB.ldb')
  jDBs.jDB_w = Database.New(filesLocation..heroName..'_wDB.ldb')
  jDBs.jDB_v = Database.New(filesLocation..heroName..'_vDB.ldb')
  jDBs.jDB_bw = Database.New(filesLocation..heroName..'_bwDB.ldb')
  jDBs.jDB_bv = Database.New(filesLocation..heroName..'_bvDB.ldb')
  jDBs.jDB_ew = Database.New(filesLocation..heroName..'_ewDB.ldb')
  jDBs.jDB_ev = Database.New(filesLocation..heroName..'_evDB.ldb')
  jDBs.jDB_bew = Database.New(filesLocation..heroName..'_bewDB.ldb')
  jDBs.jDB_bev = Database.New(filesLocation..heroName..'_bevDB.ldb')
  jDBs.jDB_games = Database.New(filesLocation..heroName..'_gamesDB.ldb')
end

function jDataWriter.writeParameters(setupComment)
  jDBs.parametersDB["alpha"] = ""..tostring(object.alpha)
  jDBs.parametersDB["beta"] =  ""..tostring(object.beta)
  jDBs.parametersDB["gamma"] =  ""..tostring(object.gamma)
  jDBs.parametersDB["lambda"] =  ""..tostring(object.lambda)
  jDBs.parametersDB["rndChance"] =  ""..tostring(object.randomActionChance)
  jDBs.parametersDB["rndDecrease"] =  ""..tostring(object.randomChanceDecrease)
  jDBs.parametersDB["lowestRnd"] =  ""..tostring(object.randomChanceLowerBound)
  jDBs.parametersDB["nIs"] =  ""..tostring(object.nIs)
  jDBs.parametersDB["nHs"] =  ""..tostring(object.nHs)
  jDBs.parametersDB["nOs"] =  ""..tostring(object.nOs)
  jDBs.parametersDB["comment"] = setupComment
  jDBs.parametersDB:Flush()
end

function jDataWriter.writeWeights()
  local jVdb = Database.New(jDBs.path..'_vDB_game'..tostring(object.currentMatch)..'.ldb')
  for i = 1,object.nIs do
    for j = 1,object.nHs do
      jDBs.jDB_v[i..","..j] = ""..tostring(object.v[i][j])
      jVdb[i..","..j] = ""..tostring(object.v[i][j])
    end
  end
  jDBs.jDB_v:Flush()
  jVdb:Flush()

  local jWdb = Database.New(jDBs.path..'_wDB_game'..tostring(object.currentMatch)..'.ldb')
  for j = 1,object.nHs do
    for k = 1,object.nOs do
      jDBs.jDB_w[j..","..k] = ""..tostring(object.w[j][k])
      jWdb[j..","..k] = ""..tostring(object.w[j][k])
    end
  end
  jDBs.jDB_w:Flush()
  jWdb:Flush()

  local jBVdb = Database.New(jDBs.path..'_bvDB_game'..tostring(object.currentMatch)..'.ldb')
  for j = 1,object.nHs do
    jDBs.jDB_bv[""..j] = ""..tostring(object.bv[j])
    jBVdb[""..j] = ""..tostring(object.bv[j])
  end
  jDBs.jDB_bv:Flush()
  jBVdb:Flush()

  local jBWdb = Database.New(jDBs.path..'_bwDB_game'..tostring(object.currentMatch)..'.ldb')
  for k = 1,object.nOs do
    jDBs.jDB_bw[""..k] = ""..tostring(object.bw[k])
    jBWdb[""..k] = ""..tostring(object.bw[k])
  end
  jDBs.jDB_bw:Flush()
  jBWdb:Flush()
end

function jDataWriter.writeAction(ntYk, tYk, matchStart,
					action, isRandom, rndChance,
					currentMatch, currentAction)
  local val = {}
  val[1] = ""..tostring(HoN.GetMatchTime()-matchStart) -- timestep
  val[2] = ""..tostring(action)
  val[3] = ""..tostring(isRandom)
  val[4] = ""..tostring(rndChance)
  val[5] = ""..tostring(tYk)
  val[6] = ""..tostring(ntYk-tYk)
  local jDB_thisGame = Database.New(jDBs.path..'_actionSeq_game'..tostring(currentMatch)..'.ldb')
  jDB_thisGame["action"..currentAction] = val
  jDB_thisGame:Flush()
end

function jDataWriter.writeState(input, isFinalState)
  local jDB_state = Database.New(jDBs.path..'_stateSeq_game'..tostring(object.currentMatch)..'.ldb')
  if not isFinalState then
    for i=1,object.nIs do
      jDB_state["action"..object.currentAction.."-beforeInput"..i] = ""..tostring(object.tYi[i])
      jDB_state["action"..object.currentAction.."-afterInput"..i] = ""..tostring(input[i])
    end
  else
    for i=1,object.nIs do
      jDB_state["action"..object.currentAction.."-lastInput"..i] = ""..tostring(object.tYi[i])
    end
  end
  jDB_state:Flush()
end

function jDataWriter.writeOutcome(EventData)
	local val = {}
	if EventData.Type == "Kill" then
		val[1] = "win"
	elseif EventData.Type == "Death" then
		val[1] = "loss"
	end
	local matchlength = HoN.GetMatchTime() - object.matchStart
	val[2] = ""..matchlength
	jDBs.jDB_games["ngame"..object.currentMatch] = val
	jDBs.jDB_games:Flush()
end
function jDataWriter.writeOutcome2(outcome)
	local val = {}
	val[1] = outcome
	local matchlength = HoN.GetMatchTime() - object.matchStart
	val[2] = ""..matchlength
	jDBs.jDB_games["ngame"..object.currentMatch] = val
	jDBs.jDB_games:Flush()
end
function jDataWriter.writeOutcome3(outcome, outcomeBy, matchlength)
	local val = {}
	val[1] = outcome
	val[2] = outcomeBy
	val[3] = ""..tostring(matchlength)
	jDBs.jDB_games["ngame"..object.currentMatch] = val
	jDBs.jDB_games:Flush()
end
function jDataWriter.writeOutcome4(outcome, outcomeBy, matchlength, creepkills, creepdenies)
	local val = {}
	val[1] = outcome
	val[2] = outcomeBy
	val[3] = ""..tostring(matchlength)
	val[4] = ""..tostring(creepkills)
	val[5] = ""..tostring(creepdenies)
	jDBs.jDB_games["ngame"..object.currentMatch] = val
	jDBs.jDB_games:Flush()
end
