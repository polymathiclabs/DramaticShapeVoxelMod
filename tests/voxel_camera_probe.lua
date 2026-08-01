-- Driver: exercise the voxel camera-mode toggle and capture each view.
--
-- The three captures are deliberately made from the same map and player
-- position. This catches a mode that changes the label but not the actual
-- camera, and verifies that POV does not draw the player's own card.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")
  local handle = game.mods.exports["DRAMATIC_SHAPE"]
  local V = assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")
  local CameraMode = V.require("CameraMode")

  local dir = os.getenv("SHOT_DIR") or "shots/camera"
  local mapId = os.getenv("CAMERA_MAP") or "PALLET_TOWN"
  local x = tonumber(os.getenv("CAMERA_X")) or 10
  local y = tonumber(os.getenv("CAMERA_Y")) or 8
  local facing = os.getenv("CAMERA_FACING") or "down"
  CameraMode.setting:setIndex(1, game)
  Pipelines.setLevel("tiltshift", 0)
  Pipelines.setLevel("voxel", 3)
  U.teleport(game, mapId, x, y, facing)
  U.wait(45)

  local function shot(label)
    game.capturePath = ("%s/%s.png"):format(dir, label)
    U.wait(4)
    print(("[camera] %s mode=%s"):format(label, CameraMode.mode()))
  end

  shot("camera_above")
  game:keypressed("v")
  U.wait(4)
  shot("camera_third")
  game:keypressed("v")
  U.wait(4)
  shot("camera_pov")
  game:keypressed("v")
  U.wait(4)
  print("[camera] returned mode=", CameraMode.mode())
end
