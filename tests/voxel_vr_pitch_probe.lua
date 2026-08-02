-- Driver: verify the OpenXR pitch handed to the voxel camera stays intuitive.
-- This is deterministic and does not require a headset session.
return function(game)
  local handle = game.mods.exports["DRAMATIC_SHAPE"]
  local V = assert(handle and handle.lib, "DRAMATIC_SHAPE exports missing")
  local Voxel3D = V.require("Voxel3D")

  local oldCamera = Voxel3D.camera
  local baseEye = { 0, 10, 0 }
  -- CameraMode's trainer-facing POV uses +Z for "down". OpenXR's neutral
  -- view direction is -Z, so this catches the real camera-basis conversion
  -- rather than accidentally testing the already-compatible -Z direction.
  local baseFocus = { 0, 10, 10 }
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

  local function projectedY(matrix, point)
    local y = matrix[5] * point[1] + matrix[6] * point[2]
      + matrix[7] * point[3] + matrix[8]
    local w = matrix[13] * point[1] + matrix[14] * point[2]
      + matrix[15] * point[3] + matrix[16]
    return y / w * 0.5 + 0.5
  end

  Voxel3D.camera = camera
  local upView = Voxel3D.viewProjection(0, 0, 160, 144)
  assert(Voxel3D.focus[2] > baseFocus[2],
    "positive headset pitch should look upward in the +Z POV basis")
  assert(projectedY(upView, { 0, 10, 10 }) > 0.5,
    "looking up should move a level marker down on the canvas")

  camera.orientationDelta.x = -camera.orientationDelta.x
  local downView = Voxel3D.viewProjection(0, 0, 160, 144)
  assert(Voxel3D.focus[2] < baseFocus[2],
    "negative headset pitch should look downward in the +Z POV basis")
  assert(projectedY(downView, { 0, 10, 10 }) < 0.5,
    "looking down should move a level marker up on the canvas")

  Voxel3D.camera = oldCamera
  print("[vr-pitch] up/down direction passed")
end
