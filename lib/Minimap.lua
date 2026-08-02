-- A small, optional 2D view of the current map.
--
-- The voxel scene is still the main view.  This module borrows the engine's
-- own TileRenderer for a 160x144 Game Boy-sized window, puts a player marker
-- over it, and scales that image into a screen-space panel.  It is drawn from
-- the same world state as the voxel scene, so map changes, palettes and the
-- three supported games stay in step automatically.

local V = ...

local ModSetting = V.require("ModSetting")

local Minimap = {}

Minimap.KEY = "minimap"
Minimap.LABEL = "MINIMAP"
Minimap.setting = ModSetting.new(Minimap.KEY, Minimap.LABEL,
                                 { true, false }, { "ON", "OFF" })

Minimap.SOURCE_W = 160
Minimap.SOURCE_H = 144
Minimap.MIN_MAP_W = 160
Minimap.MAX_MAP_W = 320
Minimap.MARGIN = 12
Minimap.PADDING = 6

local cache = {
  canvas = nil,
  mapId = nil,
  camX = nil,
  camY = nil,
  animStamp = nil,
}

local function releaseCanvas()
  if cache.canvas and cache.canvas.release then
    pcall(cache.canvas.release, cache.canvas)
  end
  cache.canvas = nil
  cache.mapId, cache.camX, cache.camY, cache.animStamp = nil, nil, nil, nil
end

-- Layout is kept pure so a headless test can exercise the sizing rules.
-- The source remains a 160x144 frame and is always scaled uniformly.
function Minimap.layout(screenW, screenH)
  if not (screenW and screenH and screenW > 0 and screenH > 0) then
    return nil
  end

  local mapW = math.floor(math.min(Minimap.MAX_MAP_W,
                                   math.max(Minimap.MIN_MAP_W,
                                            screenW * 0.24)))
  local pad = Minimap.PADDING
  local margin = Minimap.MARGIN
  local scale = mapW / Minimap.SOURCE_W
  local mapH = math.floor(Minimap.SOURCE_H * scale + 0.5)
  local panelW = mapW + pad * 2
  local panelH = mapH + pad * 2

  -- Keep the panel usable on a small desktop window too.  This branch is
  -- mostly a safety net for resized windows and headless display probes.
  local maxH = math.max(1, screenH - margin * 2)
  if panelH > maxH then
    scale = math.max(0.5, (maxH - pad * 2) / Minimap.SOURCE_H)
    mapW = math.floor(Minimap.SOURCE_W * scale + 0.5)
    mapH = math.floor(Minimap.SOURCE_H * scale + 0.5)
    panelW = mapW + pad * 2
    panelH = mapH + pad * 2
  end

  return {
    x = margin,
    y = screenH - panelH - margin,
    w = panelW,
    h = panelH,
    mapW = mapW,
    mapH = mapH,
    scale = scale,
  }
end

Minimap._layout = Minimap.layout

local function animationStamp()
  if love and love.timer and love.timer.getTime then
    -- The 2D map has animated water and flowers.  A tenth-second refresh is
    -- enough to keep those readable without rebuilding the view twice per
    -- stereo frame when the player is standing still.
    return math.floor(love.timer.getTime() * 10)
  end
  return 0
end

local function ensureCanvas()
  if cache.canvas then return cache.canvas end
  if not (love.graphics and love.graphics.newCanvas) then return nil end
  local ok, canvas = pcall(love.graphics.newCanvas,
                           Minimap.SOURCE_W, Minimap.SOURCE_H)
  if not ok or not canvas then return nil end
  if canvas.setFilter then pcall(canvas.setFilter, canvas, "nearest", "nearest") end
  cache.canvas = canvas
  return canvas
end

local function playerCenter(player)
  return (player.px or player.cellX * 16) + 8,
         (player.py or player.cellY * 16) + 8
end

local function drawFallbackGrid(map, camX, camY)
  -- The normal path uses TileRenderer.  This fallback keeps the feature safe
  -- during asset loading and in reduced/headless graphics environments.
  if not (map and map.widthCells and map.heightCells) then return end
  for cy = 0, map.heightCells - 1 do
    for cx = 0, map.widthCells - 1 do
      local x = cx * 16 - camX
      local y = cy * 16 - camY
      if x + 16 >= 0 and y + 16 >= 0 and x <= Minimap.SOURCE_W
         and y <= Minimap.SOURCE_H then
        local color
        if map:isWaterCell(cx, cy) then
          color = { 0.20, 0.45, 0.82, 1 }
        elseif map:isGrassCell(cx, cy) then
          color = { 0.28, 0.68, 0.26, 1 }
        elseif map:isWalkableCell(cx, cy) then
          color = { 0.76, 0.70, 0.43, 1 }
        else
          color = { 0.16, 0.20, 0.24, 1 }
        end
        love.graphics.setColor(color)
        love.graphics.rectangle("fill", x, y, 16, 16)
      end
    end
  end
end

local function drawPlayerMarker(player, camX, camY)
  local px, py = playerCenter(player)
  local x, y = px - camX, py - camY
  local facing = player.facing or "down"
  local dx, dy = 0, 1
  if facing == "up" then dy = -1
  elseif facing == "left" then dx, dy = -1, 0
  elseif facing == "right" then dx, dy = 1, 0 end

  local tipX, tipY = x + dx * 6, y + dy * 6
  local sideX, sideY = -dy * 3, dx * 3
  love.graphics.setColor(1.0, 0.88, 0.15, 1)
  love.graphics.polygon("fill",
                        tipX, tipY,
                        x + sideX - dx * 2, y + sideY - dy * 2,
                        x - sideX - dx * 2, y - sideY - dy * 2)
  love.graphics.setColor(0.08, 0.06, 0.02, 1)
  love.graphics.setLineWidth(1)
  love.graphics.polygon("line",
                        tipX, tipY,
                        x + sideX - dx * 2, y + sideY - dy * 2,
                        x - sideX - dx * 2, y - sideY - dy * 2)
end

local function rebuild(state, camX, camY, stamp)
  local canvas = ensureCanvas()
  if not canvas then return nil end
  local target = canvas
  local pushed = false
  local ok = pcall(function()
    love.graphics.push("all")
    pushed = true
    love.graphics.setCanvas(target)
    love.graphics.clear(0.03, 0.04, 0.06, 1)
    love.graphics.setColor(1, 1, 1, 1)

    local renderer = state.map and state.map.renderer
    local rendered = false
    if renderer and renderer.drawMapOnly then
      rendered = pcall(renderer.drawMapOnly, renderer, camX, camY,
                       Minimap.SOURCE_W, Minimap.SOURCE_H)
    end
    if not rendered then drawFallbackGrid(state.map, camX, camY) end

    drawPlayerMarker(state.player, camX, camY)
  end)
  -- The push happens before the canvas switch, so the pop restores the
  -- caller's overlay canvas even if a renderer or asset throws halfway
  -- through the off-screen draw.
  if pushed then pcall(love.graphics.pop) end
  if not ok then return nil end
  cache.mapId = state.map.id
  cache.camX, cache.camY, cache.animStamp = camX, camY, stamp
  return canvas
end

local function currentGameIsOverworld(state)
  local Game = require("src.core.Game")
  return Game and Game.stack and Game.stack:top() == state
end

function Minimap.draw(state, Voxel3D)
  if not Minimap.setting:get() then return end
  if not (state and state.map and state.player and Voxel3D) then return end
  if not currentGameIsOverworld(state) then return end
  if not (love.graphics and love.graphics.push and love.graphics.draw) then return end

  local screenW, screenH = Voxel3D.size()
  local layout = Minimap.layout(screenW, screenH)
  if not layout then return end

  local px, py = playerCenter(state.player)
  local camX = math.floor(px - Minimap.SOURCE_W / 2)
  local camY = math.floor(py - Minimap.SOURCE_H / 2)
  local stamp = animationStamp()
  local canvas = cache.canvas
  if not canvas or cache.mapId ~= state.map.id
     or cache.camX ~= camX or cache.camY ~= camY
     or cache.animStamp ~= stamp then
    canvas = rebuild(state, camX, camY, stamp)
  end
  if not canvas then return end

  local target = Voxel3D.canvas and Voxel3D.canvas() or nil
  if not target then return end
  local pushed = false
  local ok = pcall(function()
    love.graphics.push("all")
    pushed = true
    love.graphics.setCanvas(target)
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setColor(0.02, 0.03, 0.05, 0.88)
    love.graphics.rectangle("fill", layout.x, layout.y,
                            layout.w, layout.h)
    love.graphics.setColor(0.60, 0.92, 1.00, 0.95)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", layout.x, layout.y,
                            layout.w, layout.h)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, layout.x + Minimap.PADDING,
                       layout.y + Minimap.PADDING, 0,
                       layout.scale, layout.scale)
  end)
  if pushed then pcall(love.graphics.pop) end
  if not ok then pcall(love.graphics.setCanvas, target) end
end

function Minimap.invalidate()
  releaseCanvas()
end

return Minimap
