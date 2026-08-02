-- Voxel world mode: free movement for the first-person rung.
--
-- The engine walks a grid: sixteen frames per cell, four directions,
-- input locked mid-step. Inside a first-person camera that gait reads as
-- riding a rail, so while 1ST drives, this module replaces the WALK and
-- nothing else: the player's position becomes continuous, steered by the
-- camera's own yaw -- push forward and you go where you look, at any
-- angle, sliding along whatever you graze.
--
-- THE GRID IS STILL THE GAME. Every fact the world cares about is a fact
-- about cells -- what blocks, what warps, what rustles, what bites -- and
-- this module keeps the player's logical cell synced to wherever the free
-- walk stands, then reuses the engine's own machinery for every one of
-- those questions:
--
--   passability      the same isWalkableCell / water-while-surfing /
--                    tile-pair / entity-occupancy verdicts Collision
--                    hands the grid walker, asked per cell the player's
--                    body overlaps.
--
--   cell arrival     OverworldState:onStepComplete, the same landing
--                    pipeline a grid step runs -- warps, spinners, gates,
--                    forced currents, poison, repel, encounters, the
--                    step counters -- fired once per cell crossed, which
--                    is exactly the rate a grid walk fires it.
--
--   the special pushes   walking off the map edge, into a ledge, or into
--                    a boulder hands the quantised direction straight to
--                    checkEdgeExit / checkLedgeHop / checkBoulderPush,
--                    the engine's own handlers, which validate and stage
--                    everything themselves (connections, the hop arc,
--                    the two-push arm). While any of those animates a
--                    scripted grid move, this module stands aside and
--                    adopts the result.
--
-- Nothing here writes save state, rolls encounters, or decides what a
-- warp does -- it moves a point, keeps the cell honest, and lets the
-- engine be the engine. Stepping off the rung snaps the point to its
-- cell and hands the walk back to the grid, and with the rung off this
-- module costs one gate check per frame.

-- the mod namespace (see main.lua): V.require loads a sibling module
local V = ...

local FirstPerson = V.require("FirstPerson")

local FreeMove = {}

-- The body: a circle in the ground plane. Small enough to walk every
-- one-cell corridor the grid game has (half a cell is 8), big enough to
-- keep the eye's near plane out of wall faces when sliding along them.
FreeMove.RADIUS = 5.5

-- World pixels per fixed 60Hz frame -- the grid walker's own speeds (16
-- frames per 16px cell on foot, 8 on the bike), so distance covered per
-- second is unchanged and the encounter rate per tile crossed stays the
-- game's own.
FreeMove.WALK = 1.0
FreeMove.BIKE = 2.0
FreeMove.MARKER_MARGIN = 1.5
FreeMove.MARKER_LIFT = 0.18

local EPS = 0.01

-- Keyboard A/D (and the corresponding left/right action from a pad) turn the
-- first-person heading instead of strafing. The pending edge is kept through
-- a continuous crossing so a turn pressed while W is held applies as soon as
-- the player is idle, matching the grid game's input timing.
local function turnLook(dir)
  FirstPerson.lookBy(dir == "right" and -math.pi / 2 or math.pi / 2, 0)
end

local function queueTurn(input, player)
  if input:wasPressed("left") then
    player.povTurnPending = "left"
  elseif input:wasPressed("right") then
    player.povTurnPending = "right"
  end
end

local function applyQueuedTurn(input, player)
  local dir = player.povTurnPending
  if not dir or not input:isDown(dir) then return false end
  turnLook(dir)
  player.facing = FirstPerson.compassFacing()
  player.povTurnPending = nil
  return true
end

-- the free position (player centre, world px) and the px/py we last wrote
-- -- if they differ from the player's, something else (a warp, a script)
-- moved them, and the free walk adopts rather than fights
local pos = nil
local lastPx, lastPy = nil, nil

local function adopt(p)
  pos = { x = p.px + 8, z = p.py + 8 }
  lastPx, lastPy = p.px, p.py
end

function FreeMove.drop()
  pos = nil
end

-- named for the suite: the module's live position, nil while dropped
function FreeMove._pos()
  return pos
end

-- The visible footprint of the logical cell. Keeping this arithmetic pure
-- makes the tile illusion easy to test and keeps the renderer independent
-- of the player's continuous position inside the cell.
function FreeMove.markerRect(cellX, cellY)
  local m = FreeMove.MARKER_MARGIN
  return {
    left = cellX * 16 + m,
    top = cellY * 16 + m,
    right = (cellX + 1) * 16 - m,
    bottom = (cellY + 1) * 16 - m,
  }
end

FreeMove._markerRect = FreeMove.markerRect

-- Draw a subtle outline around the tile the game currently considers the
-- player's cell. This is intentionally a 2D overlay projected from the
-- ground plane: it is rendered once per VR eye by the existing world-FX
-- hook, does not z-fight with the terrain, and remains visible while the
-- continuous camera position travels inside the tile.
function FreeMove.drawMarker(state)
  if not FirstPerson.driving() then return end
  if not (state and state.map and state.player
          and state.player.cellX and state.player.cellY) then return end
  if not (love.graphics and V.require("Voxel3D").project) then return end

  local VoxelScene = V.require("VoxelScene")
  local Voxel3D = V.require("Voxel3D")
  local p = state.player
  local rect = FreeMove.markerRect(p.cellX, p.cellY)
  local ground = VoxelScene.groundAt(state.map, p.cellX, p.cellY)
  local points = {}
  local function corner(x, z)
    local sx, sy = Voxel3D.project(x, ground + FreeMove.MARKER_LIFT, z)
    if not sx or not sy then return false end
    points[#points + 1] = sx
    points[#points + 1] = sy
    return true
  end

  if not (corner(rect.left, rect.top)
          and corner(rect.right, rect.top)
          and corner(rect.right, rect.bottom)
          and corner(rect.left, rect.bottom)) then
    return
  end

  love.graphics.push("all")
  love.graphics.setColor(0.20, 0.88, 1.00, 0.12)
  love.graphics.polygon("fill", points[1], points[2], points[3], points[4],
                        points[5], points[6], points[7], points[8])
  love.graphics.setColor(0.28, 0.94, 1.00, 0.82)
  love.graphics.setLineWidth(2)
  love.graphics.line(points[1], points[2], points[3], points[4],
                     points[5], points[6], points[7], points[8],
                     points[1], points[2])
  love.graphics.pop()
end

-- ------- the per-cell verdict
--
-- The same questions Collision.canMove asks for a grid step, asked of one
-- cell from the player's current standing. The player's OWN cell never
-- blocks -- the body must always be free to leave wherever it stands
-- (a warp mat, the water it is surfing, a cell an NPC just stepped
-- against).

local function pairBlocked(map, surfing, sx, sy, tx, ty)
  local Game = require("src.core.Game")
  local tp = Game.data and Game.data.field and Game.data.field.tilePairs
  if not tp then return false end
  local list = surfing and tp.water or tp.land
  if not list or #list == 0 then return false end
  local tileset = map.def.tileset
  local a = map:cellTile(sx, sy)
  local b = map:cellTile(tx, ty)
  for _, p in ipairs(list) do
    if p.tileset == tileset
       and ((p.a == a and p.b == b) or (p.a == b and p.b == a)) then
      return true
    end
  end
  return false
end

-- Why (cx, cy) refuses the player's body, or nil when it may enter:
-- "bounds" | "tile" | "entity", the grid verdict's own names.
local function blockedCell(state, p, cx, cy)
  if cx == p.cellX and cy == p.cellY then return nil end
  local map = state.map
  if not map:inBounds(cx, cy) then return "bounds" end
  if not map:isWalkableCell(cx, cy) then
    if not (p.surfing and map:isWaterCell(cx, cy)) then return "tile" end
  end
  if pairBlocked(map, p.surfing, p.cellX, p.cellY, cx, cy) then
    return "tile"
  end
  local Collision = require("src.world.Collision")
  if Collision.occupied(state.entities, cx, cy, p) then return "entity" end
  return nil
end

FreeMove._blockedCell = blockedCell   -- named for the suite

-- ------- the slide
--
-- One axis at a time, clamped at the first refusing cell's face: the
-- classic axis-separated walk, which is where wall-sliding comes from --
-- the blocked axis stops and the free one keeps going. Returns the
-- refusal ("bounds"/"tile"/"entity") when this axis was clamped.

local function slideX(state, p, dx)
  if dx == 0 then return nil end
  local r = FreeMove.RADIUS
  local nx = pos.x + dx
  local z0 = math.floor((pos.z - r + EPS) / 16)
  local z1 = math.floor((pos.z + r - EPS) / 16)
  local hit = nil
  local edge = dx > 0 and math.floor((nx + r) / 16)
               or math.floor((nx - r) / 16)
  for zc = z0, z1 do
    hit = blockedCell(state, p, edge, zc)
    if hit then break end
  end
  if hit then
    if dx > 0 then nx = math.min(nx, edge * 16 - r - EPS)
    else nx = math.max(nx, (edge + 1) * 16 + r + EPS) end
  end
  pos.x = nx
  return hit
end

local function slideZ(state, p, dz)
  if dz == 0 then return nil end
  local r = FreeMove.RADIUS
  local nz = pos.z + dz
  local x0 = math.floor((pos.x - r + EPS) / 16)
  local x1 = math.floor((pos.x + r - EPS) / 16)
  local hit = nil
  local edge = dz > 0 and math.floor((nz + r) / 16)
               or math.floor((nz - r) / 16)
  for xc = x0, x1 do
    hit = blockedCell(state, p, xc, edge)
    if hit then break end
  end
  if hit then
    if dz > 0 then nz = math.min(nz, edge * 16 - r - EPS)
    else nz = math.max(nz, (edge + 1) * 16 + r + EPS) end
  end
  pos.z = nz
  return hit
end

-- Reduce a continuous vector to the engine's four-direction vocabulary for
-- step-arrival effects. The physical position remains diagonal and smooth;
-- only the legacy trigger that needs a compass direction uses this value.
local function movementDirection(wx, wz, fallback)
  if math.abs(wx) > math.abs(wz) then
    return wx > 0 and "right" or "left"
  elseif math.abs(wz) > 0 then
    return wz > 0 and "down" or "up"
  end
  return fallback
end

local function crossedBoundaries(dx, dz)
  local crossed = {}
  local function add(dir, travel)
    if travel >= -EPS and travel <= 1 + EPS then
      crossed[#crossed + 1] = { dir = dir, travel = travel }
    end
  end
  if dx > 0 then
    local edge = (math.floor(pos.x / 16) + 1) * 16
    add("right", (edge - pos.x) / dx)
  elseif dx < 0 then
    local edge = math.floor(pos.x / 16) * 16
    add("left", (edge - pos.x) / dx)
  end
  if dz > 0 then
    local edge = (math.floor(pos.z / 16) + 1) * 16
    add("down", (edge - pos.z) / dz)
  elseif dz < 0 then
    local edge = math.floor(pos.z / 16) * 16
    add("up", (edge - pos.z) / dz)
  end
  table.sort(crossed, function(a, b)
    return a.travel < b.travel
  end)
  return crossed
end

-- ------- the blocked push
--
-- The grid game's blocked step is where half its verbs live: the map-edge
-- crossing, the ledge hop, the boulder shove, the route-gate warp fired
-- by collision, and the honest bonk. Hand the engine the quantised
-- direction and let its own handlers decide -- each one validates itself
-- (checkLedgeHop matches the tile pair, checkEdgeExit checks the bounds),
-- so calling them on every firm push is safe. Returns true when one of
-- them took the frame over.
local function pushSpecials(state, dir, why)
  local p = state.player
  p.facing = dir      -- the handlers read the push off the facing
  if why == "bounds" and state:checkEdgeExit(dir) then return true end
  if state:checkLedgeHop(dir) then return true end
  if state:checkBoulderPush(dir) then return true end
  if why ~= "entity" and state:canCollisionWarp() then
    local Game = require("src.core.Game")
    local Warp = require("src.world.Warp")
    local w = Warp.onCollision(state.map, Game.data.field.warpCarpets,
                               p.cellX, p.cellY, dir)
    if w then
      state:takeWarp(w.def)
      return true
    end
  end
  if why ~= "entity" then
    if (state.bumpCooldown or 0) <= 0 then
      local Game = require("src.core.Game")
      require("src.core.Sound").play(Game.data, "Collision")
      state.bumpCooldown = 16
    end
  end
  return false
end

-- ------- the tick
--
-- Runs in place of OverworldState:handleInput while first person drives
-- (see install below), which means it inherits every gate the grid walk
-- has: never during scripted moves, transitions, or with anything above
-- the overworld on the stack.

function FreeMove.tick(state)
  local p = state.player
  local Game = require("src.core.Game")
  local input = Game.input

  queueTurn(input, p)

  -- a grid move is animating -- a ledge hop, a spinner slide, a scripted
  -- walk -- or a cutscene owns the player: stand aside, adopt the result
  if p.moving or p.inputLocked then
    FreeMove.drop()
    return
  end
  if applyQueuedTurn(input, p) then return end
  if not pos or p.px ~= lastPx or p.py ~= lastPy then adopt(p) end

  -- the head is the facing: what A talks to, what the sun's card shows,
  -- which way a bonk points
  p.facing = FirstPerson.compassFacing()

  if input:wasPressed("a") then
    state:interact()
    return
  end
  if input:wasPressed("start") then
    require("src.core.Sound").play(Game.data, "Start_Menu")
    require("src.ui.Screens").push(Game, "StartMenu")
    return
  end

  local mx, mz = FirstPerson.moveVector()
  local wx, wz = FirstPerson.moveWorld(mx, mz)

  -- Cycling Road's downhill pull, the free-walk restatement of the grid
  -- path's simulated PAD_DOWN: south drift with nothing held, braked by
  -- holding A or B exactly as the Route 17 sign promises
  local moving = (mx ~= 0 or mz ~= 0)
  if not moving and Game.save and Game.save.onBike then
    local fm = Game.data.field.forcedMovement
    local braking = input:isDown("a") or input:isDown("b")
    if fm and not braking then
      for _, m in ipairs(fm.slopeMaps or {}) do
        if m == state.map.id then
          wx, wz, moving = 0, 1, true
          break
        end
      end
    end
  end

  if not moving then return end

  state.bumpCooldown = math.max(0, (state.bumpCooldown or 0) - 1)

  local speed = (Game.save and Game.save.onBike) and FreeMove.BIKE
                or FreeMove.WALK
  local dx, dz = wx * speed, wz * speed
  local moveDir = movementDirection(wx, wz, p.facing)
  p.lastMoveDir = moveDir

  -- Ledges are checked before ordinary movement in the engine. A ledge tile
  -- is usually walkable, so waiting for blockedCell() would let a free walk
  -- pass straight over it. Trigger the same two-cell hop on the frame that
  -- the continuous body crosses the relevant boundary. Check every edge
  -- crossed during the frame, in travel order, so an exact diagonal corner
  -- cannot bypass a ledge on its non-dominant axis.
  for _, crossing in ipairs(crossedBoundaries(dx, dz)) do
    if crossing.dir == p.facing and state:checkLedgeHop(crossing.dir) then
      FreeMove.drop()
      return
    end
  end

  local hitX = slideX(state, p, dx)
  local hitZ = slideZ(state, p, dz)

  -- the walk cycle: the wall-bonk clock animates the legs of a player the
  -- grid thinks is standing still, refreshed while the free walk covers
  -- ground (Player:update ticks animClock off it; walkPhase reads it)
  p.bumpFrames = 2

  p.px, p.py = pos.x - 8, pos.z - 8
  lastPx, lastPy = p.px, p.py

  -- the cell the body stands in; crossing into a new one IS a step
  local ncx = math.floor(pos.x / 16)
  local ncy = math.floor(pos.z / 16)
  if ncx ~= p.cellX or ncy ~= p.cellY then
    p.cellX, p.cellY = ncx, ncy
    state:onStepComplete()
    -- a warp or a battle may have moved the world out from under the
    -- walk; the adopt check on the next tick picks the pieces up
    return
  end

  -- a firm push into something that refused: the engine's own blocked-step
  -- verbs, aimed the way the push leans
  local hit, dir
  if hitX and (not hitZ or math.abs(dx) >= math.abs(dz)) then
    hit, dir = hitX, (dx > 0 and "right" or "left")
  elseif hitZ then
    hit, dir = hitZ, (dz > 0 and "down" or "up")
  end
  if hit and math.max(math.abs(dx), math.abs(dz)) > 0.4 * speed then
    if pushSpecials(state, dir, hit) then
      FreeMove.drop()
      return
    end
    -- the push handlers may have turned the facing; the head still rules
    p.facing = FirstPerson.compassFacing()
  end
end

-- ------- the seam
--
-- OverworldState:handleInput is the one choke point where the grid walk
-- reads the pad -- the same seam the engine's own Cycling Road pull and
-- collision warps live behind -- so replacing the walk means wrapping it
-- and nothing else. Every gate ABOVE the call (scripted moves, trainer
-- engagement, transitions, anything on the stack) still applies to the
-- free walk, because the wrap sits below them all.
function FreeMove.install()
  local OverworldState = require("src.world.OverworldController")
  if OverworldState.dramaticShapeFreeMoveHook then return end
  local inner = OverworldState.handleInput

  function OverworldState:handleInput()
    if not FirstPerson.driving() then
      if pos then
        -- stepping off the rung: back onto the grid, on the cell the
        -- free walk stood in
        local p = self.player
        p.px, p.py = p.cellX * 16, p.cellY * 16
        FreeMove.drop()
      end
      return inner(self)
    end
    return FreeMove.tick(self)
  end

  OverworldState.dramaticShapeFreeMoveHook = true
end

return FreeMove
