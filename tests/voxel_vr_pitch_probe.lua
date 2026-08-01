-- Driver: verify the OpenXR pitch handed to the voxel camera stays intuitive.
-- This is deterministic and does not require a headset session.
return function(game)
  local handle = game.mods.exports["DRAMATIC_SHAPE"]
  local V = assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")
  local Voxel3D = V.require("Voxel3D")

  local oldCamera = Voxel3D.camera
  local baseEye = { 0, 10, 0 }
  local baseFocus = { 0, 10, -10 }
  local angle = math.rad(10)
  local camera = {
    eye = baseEye,
    focus = baseFocus,
    baseEye = baseEye,
    baseFocus = baseFocus,
    orientationDelta = {
      x = math.sin(angle / 2), y = 0, z = 0, w = math.cos(angle / 2),
    },
    fov = math.rad(90),
  }

  Voxel3D.camera = camera
  Voxel3D.viewProjection(0, 0, 160, 144)
  assert(Voxel3D.focus[2] > baseFocus[2],
    "positive headset pitch should look upward")

  camera.orientationDelta.x = -camera.orientationDelta.x
  Voxel3D.viewProjection(0, 0, 160, 144)
  assert(Voxel3D.focus[2] < baseFocus[2],
    "negative headset pitch should look downward")

  Voxel3D.camera = oldCamera
  print("[vr-pitch] up/down direction passed")
end
