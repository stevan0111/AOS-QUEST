-- My AOS PID : FaY7xf-FYaJopcMkEhKM3NFBfvwOtTtxk-cmO42PIKc
-- Discord Username : stevan01_

-- Initializing global variables to store the latest game state and game host process.
LatestGameState = {}  -- Stores all game data
InAction = false     -- Prevents your bot from doing multiple actions

colors = {
  red = "\27[31m",
  green = "\27[32m",
  blue = "\27[34m",
  reset = "\27[0m",
  gray = "\27[90m"
}

-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Decide the next action based on player proximity, energy, health, and game map analysis.
function decideNextAction()
  local player = LatestGameState.Players[ao.id]
  local targetInRange = false
  local bestTarget = nil

  -- Find closest and weakest target within attack range
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and inRange(player.x, player.y, state.x, state.y, 1) then
      targetInRange = true
      if not bestTarget or state.health < bestTarget.health or (state.health == bestTarget.health and inRange(player.x, player.y, state.x, state.y, 1) < inRange(player.x, player.y, bestTarget.x, bestTarget.y, 1)) then
        bestTarget = state
      end
    end
  end

  if player.energy > 5 and targetInRange then
    print(colors.red .. "Player in range. Attacking." .. colors.reset)
    ao.send({
      Target = Game,
      Action = "PlayerAttack",
      Player = ao.id,
      AttackEnergy = tostring(player.energy),
    })
  else
    print(colors.red .. "No player in range or low energy. Moving randomly." .. colors.reset)
    local directionRandom = {"Up", "Down", "Left", "Right"}
    local randomIndex = math.random(#directionRandom)
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionRandom[randomIndex]})
  end
  InAction = false
end

-- Dynamic risk assessment and retreat function
function assessRiskAndRetreat()
  local player = LatestGameState.Players[ao.id]
  local enemiesNearby = 0
  local highRisk = false

  -- Count nearby enemies
  for target, state in pairs(LatestGameState.Players) do
    if target ~= ao.id and state.team ~= player.team and inRange(player.x, player.y, state.x, state.y, 2) then
      enemiesNearby = enemiesNearby + 1
    end
  end

  -- Assess risk based on health, energy, and nearby enemies
  if player.health < 30 or player.energy < 5 or enemiesNearby > 2 then
    highRisk = true
  end

  -- Retreat if high risk
  if highRisk then
    print(colors.blue .. "High risk detected. Retreating to safer position." .. colors.reset)
    local directionRetreat = {"Up", "Down", "Left", "Right"}
    local safestDirection = directionRetreat[math.random(#directionRetreat)]  -- Simplified logic; could be improved with better pathfinding
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = safestDirection})
    InAction = false
    return true
  end
  return false
end

-- Utilize terrain and obstacles for tactical advantage
function useTerrainForAdvantage()
  local player = LatestGameState.Players[ao.id]
  local bestPosition = {x = player.x, y = player.y}
  local bestScore = 0

  -- Analyze surrounding positions
  local directions = {"Up", "Down", "Left", "Right"}
  for _, dir in ipairs(directions) do
    local newX, newY = player.x, player.y
    if dir == "Up" then newY = newY - 1
    elseif dir == "Down" then newY = newY + 1
    elseif dir == "Left" then newX = newX - 1
    elseif dir == "Right" then newX = newX + 1
    end

    local score = calculateTerrainScore(newX, newY)
    if score > bestScore then
      bestScore = score
      bestPosition = {x = newX, y = newY}
    end
  end

  -- Move to best position
  if bestScore > 0 then
    print(colors.blue .. "Moving to tactically advantageous position." .. colors.reset)
    local directionMove = calculateDirection(player.x, player.y, bestPosition.x, bestPosition.y)
    ao.send({Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMove})
    InAction = false
    return true
  end
  return false
end

-- Calculate score for a given position based on terrain
function calculateTerrainScore(x, y)
  -- Simplified scoring function; could be based on actual terrain data
  local score = 0
  if LatestGameState.Map and LatestGameState.Map[x] and LatestGameState.Map[x][y] then
    if LatestGameState.Map[x][y] == "Obstacle" then
      score = score + 10
    elseif LatestGameState.Map[x][y] == "Cover" then
      score = score + 5
    end
  end
  return score
end

-- Calculate direction to move towards target position
function calculateDirection(x1, y1, x2, y2)
  if x1 < x2 then
    return "Right"
  elseif x1 > x2 then
    return "Left"
  elseif y1 < y2 then
    return "Up"
  else
    return "Down"
  end
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
  "PrintAnnouncements",
  Handlers.utils.hasMatchingTag("Action", "Announcement"),
  function (msg)
    if msg.Event == "Started-Waiting-Period" then
      ao.send({Target = ao.id, Action = "AutoPay"})
    elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
      InAction = true
      ao.send({Target = Game, Action = "GetGameState"})
    elseif InAction then
      print("Previous action still in progress. Skipping.")
    end
    print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
  end
)

-- Handler to trigger game state updates.
Handlers.add(
  "GetGameStateOnTick",
  Handlers.utils.hasMatchingTag("Action", "Tick"),
  function ()
    if not InAction then
      InAction = true
      print(colors.gray .. "Getting game state..." .. colors.reset)
      ao.send({Target = Game, Action = "GetGameState"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
  "AutoPay",
  Handlers.utils.hasMatchingTag("Action", "AutoPay"),
  function (msg)
    print("Auto-paying confirmation fees.")
    ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000"})
  end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
  "UpdateGameState",
  Handlers.utils.hasMatchingTag("Action", "GameState"),
  function (msg)
    local json = require("json")
    LatestGameState = json.decode(msg.Data)
    ao.send({Target = ao.id, Action = "UpdatedGameState"})
    print("Game state updated. Print 'LatestGameState' for detailed view.")
  end
)

-- Handler to decide the next best action.
Handlers.add(
  "decideNextAction",
  Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
  function ()
    if LatestGameState.GameMode ~= "Playing" then
      InAction = false
      return
    end
    print("Deciding next action.")

    -- Check for risk and retreat if necessary
    if assessRiskAndRetreat() then
      return
    end

    -- Utilize terrain for tactical advantage
    if useTerrainForAdvantage() then
      return
    end

    -- Default action
    decideNextAction()
    ao.send({Target = ao.id, Action = "Tick"})
  end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
  "ReturnAttack",
  Handlers.utils.hasMatchingTag("Action", "Hit"),
  function (msg)
    if not InAction then
      InAction = true
      local playerEnergy = LatestGameState.Players[ao.id].energy
      if playerEnergy == nil then
        print(colors.red .. "Unable to read energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy."})
      elseif playerEnergy == 0 then
        print(colors.red .. "Player has insufficient energy." .. colors.reset)
        ao.send({Target = Game, Action = "Attack-Failed", Reason = "Player has no energy."})
      else
        print(colors.red .. "Returning attack." .. colors.reset)
        ao.send({Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy)})
      end
      InAction = false
      ao.send({Target = ao.id, Action = "Tick"})
    else
      print("Previous action still in progress. Skipping.")
    end
  end
)
