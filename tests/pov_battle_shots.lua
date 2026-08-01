-- Driver: run the staged battle capture with the battle camera in POV mode.
-- This is intentionally a thin wrapper around the normal multi-map capture so
-- the HUD and dialogue composition are exercised by the real render path.
return function(game)
  local handle = game.mods and game.mods.exports
                and game.mods.exports.DRAMATIC_SHAPE
  local V = assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")
  local CameraMode = V.require("CameraMode")
  CameraMode.setting:setIndex(3, game) -- POV
  return dofile("mods/DramaticShapeVoxelMod/tests/battle_shots.lua")(game)
end
