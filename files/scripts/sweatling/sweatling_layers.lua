-- sweatling_layers.lua
-- Shared sweatling assembly used by BOTH spawners (the interactable in-world
-- sweatling and the moist-mob ring sweatlings). Produces ordered layer data and
-- attaches sprites/name.
--
-- LAYER RECORD: { layer = "<name>", xml = "<sprite path>" }. Lists are ordered
-- FRONT -> BACK (index 1 = frontmost). merge_layers concatenates lists in that
-- order. attach_sweatling_sprites assigns z_index by position so order holds.
--
-- CONFIG (per-variant, passed to attach_*): the values that legitimately differ
-- between variants or are scale-dependent:
--   { scale, base_z, z_step }
-- name_scale / name_gap are DERIVED from scale here (see attach_sweatling_name),
-- so callers only supply scale.
--
-- MODULE INTERNALS (shared, same for every variant): the cosmetic mapper, path
-- helpers, the SIGN/BORDER decoration paths, font glyph metrics, and BORDER_SIZE
-- (the border.png is 78x78 regardless of variant).

local cmap = dofile_once("mods/recocards_birthday/files/scripts/sweatling/cosmetic_map.lua")

-- Mod-added decorations, resolved through the mapper (single source of truth).
-- The border art is variant-specific, so it's resolved per-call in
-- layer_for_border(id) rather than cached here.
-- font_pixel_white metrics. Width per glyph is 6px (3px for "1"), matching the
-- game's shop price code. Height is 7px (community-documented; the font file
-- isn't in the extracted data to read directly).
local GLYPH_H = 7

-- The name renders larger than the bust content so it stays legible: its scale
-- is a fixed multiple of the bust scale. 
-- Gap above the border = one rendered text-height + a small pad, all
-- scaled, so the whole thing tracks `scale`.
local NAME_SCALE_RATIO = 2.0
-- Default extra px (at name scale) between border top and text. Callers can
-- override per-variant via config.name_pad (interactable vs mob want different
-- spacing); this is the fallback when config.name_pad is nil.
local NAME_PAD = 2

-- The border defines the visible square edge (border.png is 78x78 centered on
-- the origin), so its top sits at (BORDER_SIZE/2)*scale above the origin.
local BORDER_SIZE = 78

local M = {}

-- The border edge size (px, unscaled). Exposed so spawners can align a
-- sweatling's border edges to world features (e.g. sit its bottom on the player
-- Y). Multiply by the variant scale for the on-screen half-extent.
M.BORDER_SIZE = BORDER_SIZE

-- Name box metrics (unscaled px) + scale multiplier. Exposed so moist_mob_spawn
-- can size the ring core to include the name box in the gifter's effective
-- height (see RING_CORE there). NAME_PAD here is only the DEFAULT -- variants
-- pass their own via config.name_pad, so the ring math should use the same
-- per-variant value rather than this default.
M.GLYPH_H = GLYPH_H
M.NAME_PAD = NAME_PAD
M.NAME_SCALE_RATIO = NAME_SCALE_RATIO

-- Resolve a cosmetic id on a layer to its sprite path via the mapper (or nil).
-- nil id => nil path => the slot is skipped (an INTENTIONAL empty slot; we do
-- NOT fall back to a random cosmetic for a present-but-empty user slot).
local function cosmetic_path(layer, id)
    if id == nil then return nil end
    return cmap.path_for(layer, id)
end

-- === Layer producers =========================================================

-- The raised sign (hand slot).
function M.layer_for_sign()
    local entry = nil
    for _=1,64 do
        local candidate = cmap.random("hand")
        if candidate == nil then return nil end
        entry = candidate
        local weight = tonumber(candidate.weight) or 100
        weight = math.max(0,math.min(100,weight))
        if weight >= 100 or Random(1,100) <= weight then
            break
        end
    end
    return { layer = "hand", xml = cmap.path(entry) }
end

-- The decorative border frame (backmost). `border_id` selects the variant art
-- (e.g. "border_giftling" for the interactable, "border_moist_mob" for the mob/
-- gifter); defaults to the original "border".
function M.layer_for_border(border_id)
    local path = cmap.path_for("border", border_id or "border")
    return { layer = "border", xml = path }
end

-- A random base emote (the sweatling face). Always rolled fresh.
-- Caller MUST have called SetRandomSeed first.
function M.layer_for_sweatling()
    return { layer = "sweatling", xml = cmap.path(cmap.random("sweatling")) }
end

-- The floating name is NOT a cosmetic sprite record (it has a distinct text
-- sprite shape) -- see attach_sweatling_name. No producer needed for it.

-- Ordered body/head/neck records from a USER loadout. Empty slots (nil ids) are
-- skipped intentionally -- NO per-slot random fallback (an empty slot is the
-- user's choice / an unpurchased cosmetic). Head exclusivity: prefer full_head,
-- else face + hat.
function M.layers_for_user(u)
    local layers = {}
    local function push(layer, xml)
        if xml ~= nil then layers[#layers + 1] = { layer = layer, xml = xml } end
    end

    push("body", cosmetic_path("body", u.body))
    push("neck", cosmetic_path("neck", u.neck))
    if u.full_head ~= nil then
        push("full_head", cosmetic_path("full_head", u.full_head))
    else
        push("face", cosmetic_path("face", u.face))
        push("hat", cosmetic_path("hat", u.hat))
    end

    return layers
end

-- Ordered body/head/neck records rolled at RANDOM, used when there is NO user
-- record at all (unknown twitch id). Uses the mapper's 2-tier head roll. Caller
-- MUST have called SetRandomSeed first.
function M.layers_random()
    local layers = {}
    local function push(layer, entry)
        if entry ~= nil then
            layers[#layers + 1] = { layer = layer, xml = cmap.path(entry) }
        end
    end

    push("body", cmap.random("body"))
    push("neck", cmap.random("neck"))
    local head = cmap.random_head() or {}
    if head.full_head ~= nil then
        push("full_head", head.full_head)
    else
        push("face", head.face)
        push("hat", head.hat)
    end

    return layers
end

-- Merge any number of ordered layer lists (or single records) into one ordered
-- list, front->back in argument order. Pass records or lists in the desired
-- FRONT -> BACK order, e.g.:
--   merge_layers(layer_for_sign(), layers_for_user(u), layer_for_sweatling(),
--                layer_for_border())
function M.merge_layers(...)
    local merged = {}
    for _, part in ipairs({ ... }) do
        if part == nil then
            -- skip
        elseif part.layer ~= nil and part.xml ~= nil then
            merged[#merged + 1] = part            -- a single record
        else
            for _, rec in ipairs(part) do          -- a list of records
                merged[#merged + 1] = rec
            end
        end
    end
    return merged
end

-- Resolve the cosmetic layer set for a user: their loadout (skipping empty
-- slots, no per-slot fallback), or a fully random set when there's NO user
-- record. This is the common "user or random" body/head/neck decision.
function M.cosmetics_for(u)
    if u ~= nil then return M.layers_for_user(u) end
    return M.layers_random()
end

-- === Attach methods ==========================================================

-- Add the merged cosmetic/base sprite stack in order. z_index of the i-th layer
-- (1-based) = base_z + z_step*(i-1), so index 1 draws frontmost. All sprites are
-- tagged "cosmetic" (grouped, distinct from the name) and drawn at config.scale.
function M.attach_sweatling_sprites(entity, layers, config)
    for i, rec in ipairs(layers) do
        local z_index = config.base_z + config.z_step * (i - 1)
        EntityAddComponent2(entity, "SpriteComponent", {
            _tags = "cosmetic",
            image_file = rec.xml,
            rect_animation = "idle",
            next_rect_animation = "idle",
            offset_x = 0,
            offset_y = 0,
            z_index = z_index,
            update_transform = true,
            has_special_scale = true,
            special_scale_x = config.scale,
            special_scale_y = config.scale,
        })
    end
end

-- Add the floating name as a text SpriteComponent on the entity. name_scale and
-- the vertical lift are DERIVED from config.scale:
--   name_scale = scale * NAME_SCALE_RATIO
function M.attach_sweatling_name(entity, name, config)
    if name == nil or name == "" then return end

    local name_scale = config.scale * NAME_SCALE_RATIO
    local name_pad = config.name_pad or NAME_PAD
    local text_width = #name * 4
    local offset_x = text_width / 2
    local offset_y = ((BORDER_SIZE / 2) * config.scale + (GLYPH_H + name_pad) * name_scale)/name_scale

    EntityAddComponent2(entity, "SpriteComponent", {
        _tags = "sweatling_name",
        image_file = "data/fonts/font_pixel_white.xml",
        is_text_sprite = true,
        emissive = false,
        text = name,
        offset_x = offset_x,
        offset_y = offset_y,
        alpha = 1,
        update_transform = true,
        update_transform_rotation = true,
        has_special_scale = true,
        special_scale_x = name_scale,
        special_scale_y = name_scale,
        -- Name draws on its own layer when config.name_z is set (lower z = in
        -- FRONT). Falls back to base_z (same layer as the cosmetics) otherwise.
        z_index = config.name_z or config.base_z,
    })
end

-- Dress an entity in one call: attach the ordered sprite stack + the floating
-- name, both at config scale/z. This is the common assembly both spawners use;
-- callers only differ in the layer SET they pass and the name.
--   entity : the loaded sweatling entity
--   layers : merged FRONT->BACK layer records (from merge_layers)
--   name   : login/celebrant to show, or nil for no name
--   config : { scale, base_z, z_step, [name_z], [name_pad] }
function M.dress_sweatling(entity, layers, name, config)
    M.attach_sweatling_sprites(entity, layers, config)
    M.attach_sweatling_name(entity, name, config)
end

function M.dress_sweatling_nameless(entity, layers, config)
    M.attach_sweatling_sprites(entity, layers, config)
end

return M
