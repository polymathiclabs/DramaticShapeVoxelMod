-- Headless checks for the optional minimap setting and its screen layout.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.load()
local MOD_PATH = os.getenv("DS_MOD_PATH") or "mods/DramaticShapeVoxelMod"
local run = T.sdk.loadMod(MOD_PATH, { data = Data })
T.eq(#run.errors, 0,
  "DRAMATIC_SHAPE loads clean: " .. table.concat(run.errors, "; "))

local Minimap = run.loader.exports.DRAMATIC_SHAPE.lib.require("Minimap")
local schema = run.loader.optionSchemas.DRAMATIC_SHAPE
local schemaRow
for _, row in ipairs(schema or {}) do
  if row.key == "minimap" then schemaRow = row end
end
T.check(schemaRow and schemaRow.type == "choice"
        and schemaRow.default == true,
  "the mod manager receives an ON/OFF minimap choice")
local game = {
  data = Data,
  save = { options = { modOptions = {} } },
  mods = { modOptions = {} },
  writeOptions = function() end,
}

T.eq(Minimap.setting:get(), true, "the minimap starts on")
Minimap.setting:setIndex(2, game)
T.eq(Minimap.setting:get(), false, "the minimap can be switched off")
T.eq(game.save.options.modOptions.DRAMATIC_SHAPE.minimap, false,
  "the minimap writes its value to save options")

local layout = Minimap._layout(1280, 720)
T.check(layout and layout.w > layout.h
        and math.abs((layout.mapW / layout.mapH) - (160 / 144)) < 0.02,
  "the minimap layout keeps the classic frame's aspect ratio")

Minimap.setting:setIndex(1, game)
T.eq(Minimap.setting:get(), true, "the minimap can be switched on again")

run.release()
T.finish("MINIMAP")
