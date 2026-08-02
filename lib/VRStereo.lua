-- Optional stereo adapter for the voxel overworld.
--
-- VoxelScene predates the VR boundary and still calls Voxel3D.beginScene
-- without a slot.  Keep that renderer untouched: while one eye is rendered,
-- this adapter supplies the eye camera and scopes a named scene slot around
-- that call.  Voxel3D therefore owns independent colour/depth resources for
-- the two eye canvases.

local V = ...

local Voxel3D = V.require("Voxel3D")
local VoxelScene = V.require("VoxelScene")
local ShadowMap = V.require("ShadowMap")
local CameraMode = V.require("CameraMode")
local FirstPerson = V.require("FirstPerson")

local VRStereo = {
  LEFT_SLOT = "vr-left",
  RIGHT_SLOT = "vr-right",
}

local function number(value)
  return type(value) == "number" and value == value
         and math.abs(value) < 1e9 and value
end

local function validFov(value)
  if number(value) and value > 0 then return value end
  if type(value) ~= "table" then return nil end
  local result = {}
  for _, key in ipairs({ "left", "right", "up", "down" }) do
    if not number(value[key]) then return nil end
    result[key] = value[key]
  end
  if result.right <= result.left or result.up <= result.down then return nil end
  return result
end

local function component(vector, name, index)
  if type(vector) ~= "table" then return nil end
  return number(vector[name] or vector[index])
end

local function voxelVector(vector)
  local x = component(vector, "x", 1)
  local y = component(vector, "y", 2)
  local z = component(vector, "z", 3)
  if not (x and y and z) then return nil end
  -- Voxel3D's matrix helpers use numeric vectors. Keep the named fields too
  -- so the value remains easy to inspect in a desktop VR preview.
  return { [1] = x, [2] = y, [3] = z, x = x, y = y, z = z }
end

-- Convert the Runtime camera shape to the numeric-vector shape used by the
-- existing voxel matrices. A malformed pose declines stereo for this frame;
-- it must never turn an optional headset path into a blank world.
function VRStereo.camera(view)
  if type(view) ~= "table" then return nil end
  local eye = voxelVector(view.eye)
  local focus = voxelVector(view.focus)
  local fov = validFov(view.fov)
  if not (eye and focus and fov) then return nil end

  local result = {}
  for key, value in pairs(view) do result[key] = value end
  result.eye = eye
  result.focus = focus
  result.fov = fov
  return result
end

function VRStereo.size(view, fallbackW, fallbackH)
  local w = number(view and view.width) or fallbackW
  local h = number(view and view.height) or fallbackH
  if not (w and h and w > 0 and h > 0) then return fallbackW, fallbackH end
  return math.floor(w), math.floor(h)
end

-- Match the voxel camera selected by the player. Runtime.views then adds the
-- per-eye pose, while the scene keeps the same ABOVE / 3RD / POV anchor.
function VRStereo.baseCamera(state, vw, vh, aspect)
  local player = state and state.player
  local ground = player and VoxelScene.groundAt(state.map,
                                                player.cellX, player.cellY)
  local camera = CameraMode.view(state, vw, vh, ground)
  if not camera then return nil end
  camera.aspect = aspect or camera.aspect or vw / vh
  return camera
end

-- Render one complete voxel scene into a private Voxel3D slot. The scoped
-- wrapper is restored even when a driver rejects the eye's canvas.
function VRStereo.render(state, w, h, vw, vh, paletteFor, view, slot, stereoState)
  local camera = VRStereo.camera(view)
  if not camera or type(slot) ~= "string" then return nil end

  local previousCamera = Voxel3D.camera
  local previousBeginScene = Voxel3D.beginScene
  Voxel3D.camera = camera
  -- Let FirstPerson's billboard and marker code read this eye, while its
  -- frame builder preserves the runtime camera instead of replacing it with
  -- the desktop rig. The adoption is scoped to this eye and cleared below.
  if FirstPerson.engaged() then FirstPerson.adoptVReye(camera) end
  Voxel3D.beginScene = function(sceneW, sceneH, cx, cy, viewW, viewH, sky)
    return previousBeginScene(sceneW, sceneH, cx, cy, viewW, viewH, sky,
                              slot)
  end

  local ok, canvas = pcall(VoxelScene.render, state, w, h, vw, vh,
                           paletteFor, stereoState)

  Voxel3D.beginScene = previousBeginScene
  Voxel3D.camera = previousCamera
  FirstPerson.endFrame()
  FirstPerson.adoptVReye(nil)
  if not ok then
    -- A failed scene may have opened a pass before the driver error. Closing
    -- it keeps the subsequent single-eye fallback's graphics state sane.
    pcall(ShadowMap.cancel)
    pcall(Voxel3D.endScene)
    return nil
  end
  return canvas
end

return VRStereo
