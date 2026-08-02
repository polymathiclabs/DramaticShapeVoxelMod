-- Camera modes for the voxel overworld.
--
-- ABOVE is the original elevated diorama camera. THIRD follows behind the
-- player at character height, and POV places the camera where the player's
-- eyes would be. The same camera record is used by the desktop renderer and
-- as the anchor for the VR runtime, so switching modes cannot make the two
-- views disagree about where the world is.

local V = ...

local ModSetting = V.require("ModSetting")
local Voxel = V.require("VoxelState")

local CameraMode = {}

CameraMode.KEY = "camera"
CameraMode.LABEL = "CAMERA"
CameraMode.MODES = { "above", "third", "pov" }
CameraMode.LABELS = { "ABOVE", "3RD", "POV (FREE)" }

CameraMode.setting = ModSetting.new(CameraMode.KEY, CameraMode.LABEL,
                                    CameraMode.MODES, CameraMode.LABELS)

local DIRECTIONS = {
  down = { 0, 1 },
  up = { 0, -1 },
  right = { 1, 0 },
  left = { -1, 0 },
}

local THIRD_DISTANCE = 80
local THIRD_HEIGHT = 30
local THIRD_LOOK_AHEAD = 12
local POV_HEIGHT = 12
local POV_LOOK_AHEAD = 96
local THIRD_FOV = math.rad(65)
local POV_FOV = math.rad(70)

local function vector(x, y, z)
  return { [1] = x, [2] = y, [3] = z, x = x, y = y, z = z }
end

local function number(value)
  return type(value) == "number" and value == value and value
end

local function playerPosition(state)
  local player = state and state.player
  if not player then return nil end

  local px = number(player.px)
  local py = number(player.py)
  if not (px and py) and number(player.cellX) and number(player.cellY) then
    px, py = player.cellX * 16, player.cellY * 16
  end
  if not (px and py) then return nil end

  local dir = DIRECTIONS[player.facing] or DIRECTIONS.down
  return px + 8, py + 8, dir[1], dir[2]
end

function CameraMode.mode()
  return CameraMode.setting:get() or CameraMode.MODES[1]
end

function CameraMode.isPOV()
  return CameraMode.mode() == "pov"
end

-- Return the base camera in voxel world pixels. `ground` is supplied by the
-- scene because ledges can raise the player above the map's floor.
function CameraMode.view(state, vw, vh, ground)
  local camera = state and state.camera
  if not (camera and number(camera.x) and number(camera.y)
          and number(vw) and number(vh) and vw > 0 and vh > 0) then
    return nil
  end

  local cx, cz = camera.x + vw / 2, camera.y + vh / 2
  local angle = Voxel.angle
  local focal = Voxel.FOCAL
  local distance = focal * vh
  local mode = CameraMode.mode()

  if mode == "above" then
    return {
      eye = vector(cx, distance * math.cos(angle),
                   cz + distance * math.sin(angle)),
      focus = vector(cx, 0, cz),
      up = vector(0, math.sin(angle), -math.cos(angle)),
      right = vector(1, 0, 0),
      fov = 2 * math.atan(1 / (2 * focal)),
      aspect = vw / vh,
      mode = mode,
    }
  end

  local px, pz, dx, dz = playerPosition(state)
  if not (px and pz) then
    -- A map transition can briefly have a camera but no player pose. Keep
    -- rendering safe and visually identical to the old camera in that frame.
    return {
      eye = vector(cx, distance * math.cos(angle),
                   cz + distance * math.sin(angle)),
      focus = vector(cx, 0, cz),
      up = vector(0, math.sin(angle), -math.cos(angle)),
      right = vector(1, 0, 0),
      fov = 2 * math.atan(1 / (2 * focal)),
      aspect = vw / vh,
      mode = "above",
    }
  end

  ground = number(ground) or 0
  if mode == "pov" then
    local eye = vector(px, ground + POV_HEIGHT, pz)
    return {
      eye = eye,
      focus = vector(px + dx * POV_LOOK_AHEAD, ground + POV_HEIGHT,
                     pz + dz * POV_LOOK_AHEAD),
      up = vector(0, 1, 0),
      right = vector(1, 0, 0),
      fov = POV_FOV,
      aspect = vw / vh,
      mode = mode,
    }
  end

  return {
    eye = vector(px - dx * THIRD_DISTANCE, ground + THIRD_HEIGHT,
                 pz - dz * THIRD_DISTANCE),
    focus = vector(px + dx * THIRD_LOOK_AHEAD, ground + 8,
                   pz + dz * THIRD_LOOK_AHEAD),
    up = vector(0, 1, 0),
    right = vector(1, 0, 0),
    fov = THIRD_FOV,
    aspect = vw / vh,
    mode = mode,
  }
end

function CameraMode.row()
  return CameraMode.setting:row()
end

function CameraMode.sync(value)
  CameraMode.setting:sync(value)
end

return CameraMode
