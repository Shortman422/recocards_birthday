-- sweatling_extras_map_data.lua
-- Hand-authored, mod-added assets that are NOT part of the scraped dunkbin
-- catalog (emotes, the HBD sign, the border frame). Kept SEPARATE from
-- cosmetics_map_data.lua so re-scraping never clobbers them.
--
-- Same shape as the scraped map: { layers = { <layer> = { <entry>, ... } } }.
-- Entries use a STRING id (asset name) and an explicit `path` relative to the
-- mod root, because these assets live outside gfx/cosmetics/<layer>/<id>.xml
-- (e.g. emotes are under gfx/sweatling/). The mapper honors `path` when set.

local GFX = "mods/recocards_birthday/files/gfx/"

return {
  version = 1,
  layers = {
    -- Base face emotes (character layer). Under gfx/sweatling/.
    sweatling = {
      { id = "emote_angry", name = "Angry", layer = "sweatling", path = GFX .. "sweatling/emote_angry.xml" },
      { id = "emote_cry",   name = "Cry",   layer = "sweatling", path = GFX .. "sweatling/emote_cry.xml" },
      { id = "emote_happy", name = "Happy", layer = "sweatling", path = GFX .. "sweatling/emote_happy.xml" },
      { id = "emote_love",  name = "Love",  layer = "sweatling", path = GFX .. "sweatling/emote_love.xml" },
      { id = "emote_shock", name = "Shock", layer = "sweatling", path = GFX .. "sweatling/emote_shock.xml" },
      { id = "emote_smile", name = "Smile", layer = "sweatling", path = GFX .. "sweatling/emote_smile.xml" },
      { id = "emote_wink",  name = "Wink",  layer = "sweatling", path = GFX .. "sweatling/emote_wink.xml" },
    },
    -- Raised sign (the "hand" slot). Under gfx/cosmetics/hand/.
    hand = {
      { id = "hbd", name = "Happy Birthday Sign", layer = "hand", path = GFX .. "cosmetics/hand/hbd.xml", weight = 50 },
      { id = "hbd1", name = "Happy Birthday Envelope 1", layer = "hand", path = GFX .. "cosmetics/hand/hbd1.xml", weight = 100 },
      { id = "hbd2", name = "Happy Birthday Envelope 2", layer = "hand", path = GFX .. "cosmetics/hand/hbd2.xml", weight = 100 },
      { id = "hbd3", name = "Happy Birthday Envelope 3", layer = "hand", path = GFX .. "cosmetics/hand/hbd3.xml", weight = 100 },
      { id = "hbd4", name = "Happy Birthday brisket", layer = "hand", path = GFX .. "cosmetics/hand/hbd_brisket.xml", weight = 10 },
      { id = "hbd5", name = "Happy Birthday quack", layer = "hand", path = GFX .. "cosmetics/hand/hbd_quack.xml", weight = 25 },
      { id = "hbd6", name = "Happy Birthday Envelope 6", layer = "hand", path = GFX .. "cosmetics/hand/hbd6.xml", weight = 100 },
      { id = "hbd7", name = "Happy Birthday Cupcake", layer = "hand", path = GFX .. "cosmetics/hand/hbd_cupcake.xml", weight = 75 },
      { id = "hbd8", name = "Happy Birthday Envelope 7", layer = "hand", path = GFX .. "cosmetics/hand/hbd7.xml", weight = 100 },
      { id = "hbd9", name = "Happy Birthday Envelope 8", layer = "hand", path = GFX .. "cosmetics/hand/hbd8.xml", weight = 100 },
      { id = "hbd10", name = "Happy Birthday Envelope 9", layer = "hand", path = GFX .. "cosmetics/hand/hbd9.xml", weight = 100 },
      { id = "hbd11", name = "Happy Birthday Envelope 10", layer = "hand", path = GFX .. "cosmetics/hand/hbd10.xml", weight = 100 },
      { id = "hbd12", name = "Happy Birthday Cube", layer = "hand", path = GFX .. "cosmetics/hand/hbd11.xml", weight = 50 },
      { id = "hbd13", name = "Happy Birthday Envelope 12", layer = "hand", path = GFX .. "cosmetics/hand/hbd12.xml", weight = 100 },
      { id = "hbd14", name = "Happy Birthday Envelope 13", layer = "hand", path = GFX .. "cosmetics/hand/hbd13.xml", weight = 100 },
      { id = "hbd15", name = "Happy Birthday Envelope 14", layer = "hand", path = GFX .. "cosmetics/hand/hbd14.xml", weight = 100 },
      { id = "hbd16", name = "Happy Birthday Envelope 15", layer = "hand", path = GFX .. "cosmetics/hand/hbd15.xml", weight = 100 },
      { id = "hbd17", name = "Happy Birthday Mailbox", layer = "hand", path = GFX .. "cosmetics/hand/hbd16.xml", weight = 75 },
      { id = "hbd18", name = "Happy Birthday Door", layer = "hand", path = GFX .. "cosmetics/hand/hbd_door.xml", weight = 35 },
    },
    -- Decorative frames. Under gfx/cosmetics/border/. Variant-specific:
    -- giftling (interactable) and moist_mob (mob/gifter) borders.
    border = {
      { id = "border", name = "Border", layer = "border", path = GFX .. "cosmetics/border/border.xml" },
      { id = "border_giftling", name = "Giftling Border", layer = "border", path = GFX .. "cosmetics/border/border_giftling.xml" },
      { id = "border_moist_mob", name = "Moist Mob Border", layer = "border", path = GFX .. "cosmetics/border/border_moist_mob.xml" },
    },
  },
}
