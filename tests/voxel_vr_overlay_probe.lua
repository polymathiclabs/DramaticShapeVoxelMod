-- Driver: verify that a screen-space dialog/menu overlay is kept in the
-- stereo submission when the voxel overworld remains underneath it.
return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.vr.Runtime")
  local Font = require("src.render.Font")
  local handle = game.mods.exports["DRAMATIC_SHAPE"]
  assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")

  local dir = os.getenv("SHOT_DIR") or "shots/vr-overlay"
  Pipelines.setLevel("tiltshift", 0)
  Pipelines.setLevel("voxel", 3)
  U.teleport(game, os.getenv("CAMERA_MAP") or "ROUTE_1",
             tonumber(os.getenv("CAMERA_X")) or 10,
             tonumber(os.getenv("CAMERA_Y")) or 20,
             os.getenv("CAMERA_FACING") or "up")
  U.wait(35)

  local overlay = { isOpaque = false }
  function overlay:draw()
    -- This is deliberately drawn in the same 160x144 UI space as a real
    -- dialogue/menu state.  The core VR hook must copy it to both eyes.
    Font.drawBox(2, 13, 16, 5)
    Font.draw("VR UI TEST", 24, 112)
  end

  game.stack:push(overlay)
  U.wait(8)
  local status = Runtime.status()
  local native = status.native or {}
  local nativeActions = native.actions or {}
  print("[vr-overlay] runtime enabled=", status.enabled,
        "mode=", status.mode,
        "preview=", status.previewActive,
        "swapchain=", tostring(native.swapchainWidth) .. "x"
          .. tostring(native.swapchainHeight),
        "actions=", nativeActions.available == true)
  local path = ("%s/overlay.png"):format(dir)
  assert(U.shot(game, path), "VR overlay screenshot was not written")
  game.stack:pop()
  U.wait(4)
  print("[vr-overlay] done")
end
