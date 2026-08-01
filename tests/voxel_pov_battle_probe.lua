-- Driver: verify that the active camera mode also drives staged battles.
return function(game)
  local handle = game.mods.exports["DRAMATIC_SHAPE"]
  local V = assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")
  local CameraMode = V.require("CameraMode")
  local BattleCam = V.require("BattleCam")

  local arena = {
    player = { 24, 72 },
    enemy = { 24, 24 },
    mid = { 24, 48 },
  }

  CameraMode.setting:setIndex(3, game)
  local pov = BattleCam.rig(arena, 0)
  assert(pov and pov.mode == "pov", "POV mode did not reach the battle rig")
  assert(pov.eye[2] > 0 and pov.focus[2] > 0,
         "POV battle camera lost its vertical eye/focus")
  assert(pov.eye[3] > pov.focus[3],
         "POV battle camera is not positioned behind the player's side")

  CameraMode.setting:setIndex(1, game)
  local above = BattleCam.rig(arena, 0)
  assert(above and above.mode == nil,
         "leaving POV did not restore the staged battle rig")
  print("[pov-battle] battle camera toggle passed")
end
