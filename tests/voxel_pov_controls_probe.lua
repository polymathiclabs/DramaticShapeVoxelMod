-- Driver: verify first-person forward movement and turn-in-place controls.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local function holdOnePress(btn, frames)
    table.insert(game.input.pressQueue, btn)
    game.input.state[btn] = true
    U.wait(frames)
    game.input.state[btn] = false
  end
  local Pipelines = require("src.render.Pipelines")
  local handle = game.mods.exports["DRAMATIC_SHAPE"]
  local V = assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")
  local CameraMode = V.require("CameraMode")

  Pipelines.setLevel("tiltshift", 0)
  Pipelines.setLevel("voxel", 3)
  CameraMode.setting:setIndex(3, game) -- POV
  U.teleport(game, os.getenv("CAMERA_MAP") or "ROUTE_1",
             tonumber(os.getenv("CAMERA_X")) or 10,
             tonumber(os.getenv("CAMERA_Y")) or 20, "up")
  U.wait(8)

  -- Pick a plain two-cell stretch so this control test is not coupled to a
  -- particular map coordinate being beside a fence, ledge, NPC or warp.
  local state = game.overworld
  local map = state.map
  local foundX, foundY
  for y = 5, map.heightCells - 5 do
    for x = 5, map.widthCells - 5 do
      local clear = map:isWalkableCell(x, y)
        and map:isWalkableCell(x, y - 1)
        and not map:warpAtCell(x, y)
        and not map:warpAtCell(x, y - 1)
        and not state:npcAtCell(x, y)
        and not state:npcAtCell(x, y - 1)
      if clear then foundX, foundY = x, y; break end
    end
    if foundX then break end
  end
  assert(foundX, "could not find a clear POV movement test cell")
  U.teleport(game, map.id, foundX, foundY, "up")
  U.wait(8)

  local player = game.overworld.player
  local startX, startY = player.cellX, player.cellY
  U.hold(game, "up", 20)
  while player.moving do U.wait(1) end
  assert(player.facing == "up", "forward POV movement changed facing")
  assert(player.cellY < startY, "POV forward movement did not follow facing")

  -- A turn pressed during a step is remembered while the key remains held,
  -- then applied on the first idle frame.
  table.insert(game.input.pressQueue, "up")
  game.input.state.up = true
  U.wait(1)
  table.insert(game.input.pressQueue, "right")
  game.input.state.right = true
  U.wait(1)
  game.input.state.up = false
  while player.moving do U.wait(1) end
  -- handleInput runs before Player:update, so keep the synthetic key down for
  -- the first idle poll after the step lands.
  U.wait(1)
  game.input.state.right = false
  U.wait(3)
  assert(player.facing == "right", "mid-step POV turn was lost")
  U.tap(game, "left")
  U.wait(3)
  assert(player.facing == "up", "mid-step POV turn recovery failed")

  local beforeTurnX, beforeTurnY = player.cellX, player.cellY
  U.tap(game, "right")
  U.wait(3)
  assert(player.facing == "right", "POV right input did not turn in place")
  assert(player.cellX == beforeTurnX and player.cellY == beforeTurnY,
         "POV right turn changed position")
  local turnX, turnY = player.cellX, player.cellY

  holdOnePress("right", 20)
  assert(player.facing == "down", "held POV turn did not make one turn")
  assert(player.cellX == turnX and player.cellY == turnY,
         "held POV turn moved the player")
  U.tap(game, "left")
  U.wait(3)
  assert(player.facing == "right", "POV left turn did not restore heading")

  U.hold(game, "up", 20)
  while player.moving do U.wait(1) end
  assert(player.cellX > turnX, "POV forward movement did not follow new facing")
  assert(player.cellY == turnY, "POV forward movement moved on the old axis")

  local backX, backY = player.cellX, player.cellY
  U.hold(game, "down", 20)
  while player.moving do U.wait(1) end
  assert(player.facing == "right", "POV reverse movement changed facing")
  assert(player.cellX < backX, "POV reverse movement did not oppose facing")
  assert(player.cellY == backY, "POV reverse movement moved on the old axis")

  -- POV must not change controls once the voxel pipeline falls back to 2D.
  local fallbackX, fallbackY = player.cellX, player.cellY
  Pipelines.setLevel("voxel", 0)
  U.tap(game, "left")
  U.wait(3)
  assert(player.facing == "left", "2D fallback kept POV turning active")
  assert(player.cellX == fallbackX and player.cellY == fallbackY,
         "2D fallback changed position during a turn")

  Pipelines.setLevel("voxel", 3)
  CameraMode.setting:setIndex(2, game) -- classic THIRD controls
  local classicX, classicY = player.cellX, player.cellY
  U.tap(game, "right")
  U.wait(3)
  assert(player.facing == "right", "classic third-person controls changed")
  assert(player.cellX == classicX and player.cellY == classicY,
         "classic turn-in-place behavior changed")
  print("[pov] forward, turn, and reverse controls passed")
end
