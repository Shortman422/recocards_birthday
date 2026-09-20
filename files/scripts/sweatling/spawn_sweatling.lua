-- Dresses the INTERACTABLE birthday sweatling (the card). Cosmetic/name assembly
-- is shared with the moist-mob sweatlings via sweatling_layers.lua; this file
-- owns the interactable specifics: the layer SET (sign + author cosmetics +
-- emote + giftling border), the physics AABB scaling, and the author pick-up
-- prompt. Called from init.lua's spawn_note on an already-loaded entity via the
-- global RQ_DressSweatling(entity, author).

local sweatling_users =
    dofile_once("mods/recocards_birthday/files/scripts/sweatling/sweatling_users.lua")
local SL =
    dofile_once("mods/recocards_birthday/files/scripts/sweatling/sweatling_layers.lua")

-- Interactable presentation config (per-variant; see sweatling_layers.lua).
-- scale = on-screen bust size; base_z/z_step place the layer stack in the
-- foreground play layer (low z draws in front). name_pad = px (at name scale)
-- between the border top and the name text.
local CFG = { scale = 0.3, base_z = -0.5, z_step = 0.05, name_pad = 7 }

-- The border defines the visible square edge, so the hitbox/collision match the
-- BORDER (78x78 centered) rather than the bust content. Scaled by CFG.scale.
local BORDER_SIZE = 78
local FOOT = {
    min_x = -BORDER_SIZE / 2, max_x = BORDER_SIZE / 2,
    min_y = -BORDER_SIZE / 2, max_y = BORDER_SIZE / 2,
}

-- Build the interactable's FRONT->BACK layer set: sign, author cosmetics (or
-- random when the author has no loadout), the base emote, then the border.
local function interactable_layers(loadout)
    return SL.merge_layers(
        SL.layer_for_sign(),
        SL.cosmetics_for(loadout),
        SL.layer_for_sweatling(),
        SL.layer_for_border("border_giftling")
    )
end

-- Scale the base emote sprite + the physics AABBs to match the on-screen bust.
-- (Interactable-only: the background variant has no hitbox/collision.)
local function apply_scale_and_physics(entity)
    local hitbox = EntityGetFirstComponentIncludingDisabled(entity, "HitboxComponent")
    if hitbox ~= nil then
        ComponentSetValue2(hitbox, "aabb_min_x", FOOT.min_x * CFG.scale)
        ComponentSetValue2(hitbox, "aabb_max_x", FOOT.max_x * CFG.scale)
        ComponentSetValue2(hitbox, "aabb_min_y", FOOT.min_y * CFG.scale)
        ComponentSetValue2(hitbox, "aabb_max_y", FOOT.max_y * CFG.scale)
    end

    local cdata = EntityGetFirstComponentIncludingDisabled(entity, "CharacterDataComponent")
    if cdata ~= nil then
        ComponentSetValue2(cdata, "collision_aabb_min_x", FOOT.min_x * CFG.scale)
        ComponentSetValue2(cdata, "collision_aabb_max_x", FOOT.max_x * CFG.scale)
        ComponentSetValue2(cdata, "collision_aabb_min_y", FOOT.min_y * CFG.scale)
        ComponentSetValue2(cdata, "collision_aabb_max_y", FOOT.max_y * CFG.scale)
    end
end

-- Set the pick-up prompt (InteractableComponent.ui_text) to carry the card
-- AUTHOR. Noita substitutes $0 with the player's mapped interact keybind at
-- render time. The XML ui_text is a static fallback this overrides at spawn.
local function set_interact_prompt(entity, name)
    local interact =
        EntityGetFirstComponentIncludingDisabled(entity, "InteractableComponent")
    if interact == nil then return end
    ComponentSetValue2(
        interact, "ui_text", "Press $0 to accept " .. name .. "'s card"
    )
end

-- Dress an already-loaded interactable birthday sweatling for a card author.
-- Called from init.lua's spawn_note after the entity + identity vars are set.
-- Cosmetics resolve from the author's configured loadout (sweatling_users), or
-- a random roll when the author has no usable loadout (SL.cosmetics_for handles
-- the nil case). GLOBAL so spawn_note can call it after dofile_once.
--
-- RNG (Noita requires SetRandomSeed before any Random): seed from the entity
-- world position offset per id, so the same sweatling at the same position on
-- the same run seed rolls identically and no warning is logged.
function RQ_DressSweatling(entity, author)
    if entity == nil or entity == 0 or not EntityGetIsAlive(entity) then
        GamePrint("recocards_birthday: RQ_DressSweatling got an invalid entity")
        return
    end

    local x, y = EntityGetTransform(entity)
    SetRandomSeed(x + entity, y - entity)

    -- Author loadout (nil -> SL rolls a random cosmetic set). The name shown is
    -- the author, falling back to the existing default when absent.
    local loadout = sweatling_users.by_author(author)
    local name = author
    if name == nil or name == "" then name = "Birthday Spirit" end

    SL.dress_sweatling(entity, interactable_layers(loadout), name, CFG)
    apply_scale_and_physics(entity)
    set_interact_prompt(entity, name)
end
