# Dramatic Shape Voxel Mod

A mod for the [Pokémon Gen 1 Recompilation
Project](https://github.com/bryanthaboi/pokemon-gen1-recomp-project).

This is an unofficial fan modification. It is not affiliated with or endorsed
by Nintendo, The Pokémon Company, Game Freak, Creatures, or their partners.

The overworld as a 3D diorama. Terrain is extruded into real geometry,
occlusion comes from a depth buffer rather than a y-sort, characters stand
as leaning sprite slabs, a shadow map throws real cast shadows across
whatever they land on, and an optional tilt-shift pass sells the
miniature-model look.

Water is a surface rather than a texture lying in a hole. It is a field of
one-pixel-wide voxel columns, each standing a whole number of pixels tall and
rising and falling as waves — found by walking the view ray through them in
the shader, so a crest hides what is behind it and shows you its lit side,
with no extra geometry anywhere.

And it reflects. The sky it stands under, in the same bands, the same dither
and off the same clock, so the lake and the sky above it meet at the
waterline with no seam. The sun or moon hanging in it, at the size the
painted disc is drawn, craters and all. Whoever is standing beside it —
walkers, NPCs, the two Pokémon in a staged battle. And on **FULL**, a
screen-space ray march adds the rest of what is on screen: the shoreline, the
trees behind it, the buildings across the bay. How much of it shows is
Fresnel, so the top rung is a mirror and a looking-straight-down rung is a
pond, off the same water.

And battles fought on that world rather than on a white field. When
something picks a fight the map's NPCs are culled, the engine's own wipe
plays over the empty map, and the battle draws over the nearest patch of
clear ground — shot over the shoulder, the player's mon low and left and
the enemy high and right, with a slow parallax drift behind them and a
depth-of-field pass that keeps both of them sharp.

Purely presentational. Nothing here reaches collision, movement, triggers
or scripts — it changes what the world *looks* like and nothing about what
it *is*. The battle arena is where the **camera** goes, not where anybody
goes: no cell, facing, flag or warp is written, so the player is standing
exactly where the fight found them when it ends.

## Controls

Every key is free-roam only, and each one is also a row on the OPTIONS
menu.

| control | does |
| --- | --- |
| `3`, or the **VOXEL** options row | OFF → 15 → 35 → 50 → 75 → POV (FREE) — camera pitch and the compatibility first-person rung; the **CAMERA** row is the clear way to choose views |
| `V`, or the **CAMERA** options row | ABOVE / 3RD / POV (FREE) — switch between the elevated diorama, behind-trainer third person, and character-height first person. POV automatically enables the voxel first-person pass and free movement; ABOVE and 3RD restore tile movement |
| `W/S` or up/down in POV | Walk forward and backward relative to where the trainer is looking |
| `A/D` or left/right in POV | Turn in place without strafing; the turn is applied once per press |
| `5`, or the **V-GRID** options row | OFF / ON — a one-pixel wireframe on every voxel |
| `6`, or the **T-SHIFT** options row | OFF → 1 → 2 → 3 → OFF (miniature blur) |
| `7`, or the **V-CURVE** options row | OFF → 1 → 2 → 3 — bend the world over the horizon |
| `8`, or the **3D-BTL** options row | ON / OFF — fight on the map instead of on a white field |
| `9`, or the **WATER** options row | FULL / SKY / OFF — waves and reflections on water. **SKY** gives the surface its pixel-tall wave columns and puts the sky, the sun, the moon and the cast in them; **FULL** adds a screen-space ray march that also reflects the shoreline, the trees and the buildings standing behind it |
| VR controller | Left or right thumbstick moves; right `A` / `B` select the normal Game Boy buttons; left `X` opens START and left `Y` is SELECT. Click either thumbstick to recenter the seated view on the character. In POV, the stick's forward direction follows the trainer's facing and left/right turns in place |
| the **BACK SPRITES** options row | OFF / ON — keep your own Pokémon on the battle menu, seen from behind in its classic slot, instead of standing it on the map; the foe is still out there. Only on the menu while **3D-BTL** is on, because it decides nothing without it |
| the **DAYTIME** options row | SYNC / DAY / NIGHT / DUSK / DAWN / CYCLE — what time it is outdoors, on the diorama *and* on the flat 2D world; held at SYNC (and off the menu) while VOXEL is FULL |

**3D-BTL** is on by default and is independent of **VOXEL**: battles draw
on the world whether or not the free-roam camera is pitched over.

The mod's settings live in **OPTIONS → MODS → VR → Polymatic Labs Voxel VR →
VOXEL SETTINGS**. The same rows are also available in the normal
OPTIONS menu for quick access.

The **MINIMAP** row is an ON-by-default lower-left panel, raised above the
classic dialogue-box height and inset from the edges, that reuses the original
2D tile renderer for the current map and follows the player. It is available
in the mod manager and the normal OPTIONS menu, including while FULL is
selected.

Two of the engine's own rows are taken away while this mod is installed:
**TILT**, which is the flat fake of what this mode does for real, and **GBC
FX**, a full-screen present pass over the top of the diorama. Both are held at
off rather than merely hidden — a row that is not there cannot switch off a
value an older save arrived with. Uninstall and both come back, at whatever
they were last set to.

The two battle HUD blocks sit on frosted glass rather than on the white field
they used to have behind them: the world underneath, blurred and laid back
down translucent, with the ink flipping white where the ground is dark. The
battle text box and menus keep the engine's ordinary white dialogue paper and
border, so they match open-world conversations when they appear as the small
floating VR panel. The status windows are reduced and follow their Pokémon;
the engine still supplies every name, level, HP bar, and menu glyph.

## Licensing and attribution

The original Dramatic Shape Voxel Mod code and assets remain attributed to
DramaticShape. The upstream snapshot used here did not contain an explicit
redistribution license, so this repository must not be treated as a blanket MIT
license for the original material. Obtain permission from the upstream author
before publishing a public redistributable copy of the complete mod.

Changes authored by Polymatic Labs are available under the MIT License in
[`LICENSE-POLYMATIC-LABS.md`](LICENSE-POLYMATIC-LABS.md). The base engine keeps its own license
and attribution in the engine repository.
