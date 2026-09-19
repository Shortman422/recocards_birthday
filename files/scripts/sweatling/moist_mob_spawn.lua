-- moist_mob_spawn.lua
-- The Moist Mobbing EFFECT (main-context side). Runs from init.lua, which has
-- full game API + a valid world/player -- unlike the streaming callback context.
--
-- MODEL:
--   * A sub/gift opens a 30s WINDOW (or extends it -- a new sub just pushes the
--     end time later; it never clears pending spawns). On the sub/gift event we
--     also spawn 4 emitters + a large named gifter sweatling.
--   * WHILE THE WINDOW IS OPEN, chat messages containing dnkM/dnkMM enqueue a
--     mob sweatling for that chatter. Messages outside the window are ignored.
--   * Mob sweatlings pack into square Chebyshev rings around the gifter (see the
--     ring geometry + allocator below). They are STATIONARY and NAMELESS.
--   * Spawns are AMORTIZED: mob requests go into a queue drained a few per frame
--     (MoistMob_ProcessSpawnQueue) to avoid a single-frame spawn hitch.
--
-- Mob sweatlings share cosmetic assembly with the interactable via
-- sweatling_layers.lua, but use the moist_mob border, no sign, and no name.
-- Requests carry the chatter's numeric twitch id (from the raw IRC tags) so
-- cosmetics resolve via users.by_twitch_id.

local users = dofile_once("mods/recocards_birthday/files/scripts/sweatling/sweatling_users.lua")
local SL    = dofile_once("mods/recocards_birthday/files/scripts/sweatling/sweatling_layers.lua")
local CFG   = dofile_once("mods/recocards_birthday/files/scripts/sweatling/moist_mob_config.lua")

local EMITTER      = "mods/recocards_birthday/particles/image_emitters/dnkMM_56.xml"
local BG_SWEATLING = "mods/recocards_birthday/files/entities/sweatling_background.xml"

-- Per-variant layer configs (see sweatling_layers.lua). Mobs are nameless so
-- CFG_BG needs no name_pad; the gifter is named, and its name_pad also feeds the
-- ring-core sizing below (RING_CORE) so the core grows with the name box.
local CFG_BG     = { scale = 0.2, base_z = -0.5, z_step = 0.01 }
local CFG_GIFTER = { scale = 0.4, base_z = 39,   z_step = 0.01, name_z = -0.5, name_pad = 2 }

-- === Concentric-ring geometry (the moist-mob pulse layout) ===================
-- Mob (rain) sweatlings pack into square Chebyshev rings around the central
-- gifter. Convention (A): each ring cell is exactly one MOB width, and the
-- central m x m core is sized to CONTAIN the gifter (with a thin margin):
--   m       = ceil(GIFTER.scale / BG.scale)     -- mob cells spanning the gifter
--   spacing = BORDER_SIZE * BG.scale            -- mob width in world px
-- These are moist-mob-specific (not shared sweatling assembly), so they live
-- here rather than in sweatling_layers.

local RING_SPACING = SL.BORDER_SIZE * CFG_BG.scale            -- world px / cell (mob width)

-- Core side (m): mob cells needed to span the gifter's EFFECTIVE size = the
-- sprite box PLUS the name box (mirrored above+below to keep the core centered).
--   effective height = GIFTER.scale*BORDER_SIZE + 2 * name_size * (GLYPH_H + name_pad)
--   name_size        = GIFTER.scale * NAME_SCALE_RATIO   (the name's own scale)
--   name_pad         = CFG_GIFTER.name_pad (same per-variant value the name uses)
-- divided by the mob cell width (BG.scale*BORDER_SIZE), ceil'd.
local RING_NAME_SIZE = CFG_GIFTER.scale * SL.NAME_SCALE_RATIO
local RING_NAME_PAD  = CFG_GIFTER.name_pad or SL.NAME_PAD
local RING_CORE = math.ceil(
    (CFG_GIFTER.scale * SL.BORDER_SIZE
        + 2 * RING_NAME_SIZE * (SL.GLYPH_H + RING_NAME_PAD))
    / (CFG_BG.scale * SL.BORDER_SIZE))  -- m

-- Capacity (cell count) of ring k >= 1 around the m x m core:
--   block(k) side = m + 2k; ring k = (m+2k)^2 - (m+2k-2)^2 = 4m + 8k - 4.
local function ring_capacity(k)
    return 4 * RING_CORE + 8 * k - 4
end

-- World positions of the cells on ring k (>=1) around center (cx, cy), ordered
-- CLOCKWISE starting at the TOP-middle-right, so the ring visibly fills in a
-- continuous loop rather than column-by-column. Cells sit on a lattice centered
-- on (cx,cy) with step RING_SPACING; the block at ring k has index half-extent
-- H = (m-1)/2 + k (even/odd-m parity for free -- e.g. m=2 -> +/-0.5, +/-1.5).
--
-- The perimeter is the border of the [-H,H] x [-H,H] index square. We walk it
-- clockwise on screen (Noita +Y is DOWN): across the TOP edge left->right, down
-- the RIGHT edge, across the BOTTOM edge right->left, up the LEFT edge. Corners
-- are emitted once (each edge excludes its trailing corner). The lattice indices
-- are H, H-1, ..., -H (step 1), so both integer and half-integer H work.
local function ring_cells(cx, cy, k)
    local H = (RING_CORE - 1) / 2 + k

    -- Ascending index list -H .. H (step 1); `axis[#axis]` is +H.
    local axis = {}
    local v = -H
    while v <= H + 1e-9 do
        axis[#axis + 1] = v
        v = v + 1
    end
    local n = #axis                     -- cells per side (H*2 + 1)

    local cells = {}
    local function push(ix, iy)
        cells[#cells + 1] =
            { x = cx + ix * RING_SPACING, y = cy + iy * RING_SPACING }
    end

    local top, bottom = -H, H           -- +Y is down, so -H is the top row
    -- TOP edge, left -> right (exclude the last, it's the top-right corner start
    -- of the right edge).
    for a = 1, n - 1 do push(axis[a], top) end
    -- RIGHT edge, top -> bottom (exclude last = bottom-right corner).
    for a = 1, n - 1 do push(H, axis[a]) end
    -- BOTTOM edge, right -> left (exclude last = bottom-left corner).
    for a = n, 2, -1 do push(axis[a], bottom) end
    -- LEFT edge, bottom -> top (exclude last = top-left corner = TOP edge start).
    for a = n, 2, -1 do push(-H, axis[a]) end

    return cells
end

-- === Window + spawn queue state ==============================================

local WINDOW_FRAMES = 30 * 60   -- 30s active window after a sub/gift
local SPAWNS_PER_FRAME = 12      -- mob sweatlings created per frame (amortize)

-- Frame at/after which the window is closed. 0 = never opened / closed.
local window_end_frame = 0
-- Pending mob requests: array of chatter twitch-id strings (FIFO).
local spawn_queue = {}

-- True if the moist-mob window is currently open.
local function window_open()
    return GameGetFrameNum() < window_end_frame
end

-- Open/extend the window to now + WINDOW_FRAMES. Never clears the queue.
local function open_window()
    window_end_frame = GameGetFrameNum() + WINDOW_FRAMES
end

-- === Helpers =================================================================

-- Locate the player entity, tolerating states where the normal "player_unit"
-- is gone. When the player polymorphs (sheep, cessation, etc.) the controlled
-- entity loses the player_unit tag and instead carries a "polymorphed_*" tag,
-- so we fall back to those -- mirroring Noita's own null-room player lookup
-- (data/scripts/magic/null_room/check.lua: nullroom_remove_all_perks).
local PLAYER_TAGS = { "player_unit", "polymorphed_player", "polymorphed_cessation" }

local function find_player()
    for _, tag in ipairs(PLAYER_TAGS) do
        local ents = EntityGetWithTag(tag) or {}
        local e = ents[1]
        if e ~= nil and e ~= 0 then return e end
    end
    return nil
end

local function player_position()
    local player = find_player()
    if player == nil then return nil end
    local x, y = EntityGetTransform(player)
    return x, y
end

-- Offsets (world px, relative to the player) for the 4 emitters.
local EMITTER_RADIUS = 100
local EMITTER_OFFSETS = {
    {  -EMITTER_RADIUS, -EMITTER_RADIUS*2/3 },
    {  -EMITTER_RADIUS,  EMITTER_RADIUS*2/3 },
    {  EMITTER_RADIUS, EMITTER_RADIUS*2/3 },
    {  EMITTER_RADIUS, -EMITTER_RADIUS*2/3 },
}

-- Emitter emission rotation range (radians): tilt in [-pi/3, pi/3] of upright.
local ROT_MIN = -math.pi / 3
local ROT_MAX = math.pi / 3
local function random_rotation()
    return Random(math.floor(ROT_MIN * 1000), math.floor(ROT_MAX * 1000)) / 1000
end

-- Mob sweatling layer set: user cosmetics (or random when no user record) + the
-- base emote. NO sign, NO border, NO name (unlike the gifter/interactable).
local function mob_layers(u)
    return SL.merge_layers(SL.cosmetics_for(u), SL.layer_for_sweatling(),
        SL.layer_for_border("border_moist_mob"))
end

-- === Ring allocator ==========================================================
-- Mob sweatlings fill square Chebyshev rings around the gifter, lowest ring
-- first, cells in order. A ring LOCKS when its LAST slot fills; it unlocks
-- MOB_LIFETIME frames later (matching the last sweatling's LifetimeComponent),
-- and resets to fill again from slot 1. While a ring is locked, allocation
-- overflows to the next unlocked ring. See ring_capacity / ring_cells above.
--
-- Locks are evaluated LAZILY: a lock is just a frame comparison, so we only
-- resolve it when we actually look at a ring during allocation (no per-frame
-- sweep). When no mobs are spawning, the allocator does no work at all.

local MOB_LIFETIME = CFG.mob_lifetime_frames or 180

-- Per-ring state: rings[k] = { next = <1-based next slot>, locked_until = <frame or 0> }.
-- Reset each time a new gifter/window opens (rings are relative to the gifter).
local rings = {}
-- The gifter center the rings are placed around (set when the gifter spawns).
local ring_cx, ring_cy = nil, nil

local function reset_rings(cx, cy)
    rings = {}
    ring_cx, ring_cy = cx, cy
end

-- Fetch ring k's state, LAZILY clearing an expired lock. A ring's lock is just
-- `locked_until` vs the current frame -- nothing has to happen the moment it
-- elapses, only the next time we look at the ring -- so we resolve it on demand
-- here instead of sweeping every ring every frame. When we find a lock that has
-- elapsed, we clear it and reset the ring to refill from slot 1.
local function ring_state(k, now)
    local r = rings[k]
    if r == nil then
        r = { next = 1, locked_until = 0 }
        rings[k] = r
    end
    if r.locked_until ~= 0 and now >= r.locked_until then
        r.locked_until = 0
        r.next = 1
    end
    return r
end

-- Find the lowest ring (k>=1) that is unlocked AND has a free slot. Returns k.
-- Rings grow unboundedly, so this always terminates at some ring with space.
local function lowest_available_ring(now)
    local k = 1
    while true do
        local r = ring_state(k, now)
        if r.locked_until == 0 and r.next <= ring_capacity(k) then
            return k
        end
        k = k + 1
    end
end

-- Allocate the next slot: returns (world_x, world_y) for the cell, advancing the
-- chosen ring's slot counter and LOCKING the ring if this was its last slot.
local function allocate_ring_cell()
    local now = GameGetFrameNum()
    local k = lowest_available_ring(now)
    local r = ring_state(k, now)
    local slot = r.next               -- 1-based
    r.next = slot + 1

    -- Lock the ring when its last slot is taken.
    if slot >= ring_capacity(k) then
        r.locked_until = now + MOB_LIFETIME
    end

    local cells = ring_cells(ring_cx, ring_cy, k)
    local cell = cells[slot]
    return cell.x, cell.y
end

-- === Spawn a stationary mob sweatling ========================================

-- Spawn one stationary mob sweatling at (sx,sy) dressed for user `u` (cosmetics
-- only; nameless). Self-despawns via LifetimeComponent set to MOB_LIFETIME.
-- Caller must SetRandomSeed first (for random cosmetics/emote).
local function spawn_mob_sweatling(sx, sy, u)
    local e = EntityLoad(BG_SWEATLING, sx, sy)
    if e == nil or e == 0 then return end

    SL.dress_sweatling_nameless(e, mob_layers(u), CFG_BG)

    -- Add the self-despawn lifetime fresh (not in the XML) so the component is
    -- born with the config value -- setting it here is reliable, unlike updating
    -- an XML-declared LifetimeComponent after load.
    EntityAddComponent2(e, "LifetimeComponent", { lifetime = MOB_LIFETIME })
end

-- Process one queued request (a chatter twitch id): allocate a ring cell around
-- the gifter and spawn a stationary, nameless mob sweatling there with the
-- chatter's cosmetics (random when the id isn't a known user).
local function process_mob_request(twitch_id)
    if ring_cx == nil then return end  -- no gifter center yet

    SetRandomSeed((ring_cx or 0) + GameGetFrameNum(),
                  (ring_cy or 0) - #spawn_queue - GameGetFrameNum())

    local sx, sy = allocate_ring_cell()
    local u = twitch_id and users.by_twitch_id(twitch_id) or nil
    spawn_mob_sweatling(sx, sy, u)
end

-- === Queue API (called from init.lua) ========================================

-- Enqueue a mob request for a chatter (by numeric twitch id), ONLY while the
-- window is open. Ignored otherwise (gated by a recent sub/gift). Cosmetics
-- resolve from the id if it's a known user, else random; sweatlings are nameless.
function MoistMob_QueuePulse(twitch_id)
    if not window_open() then return end
    if twitch_id == nil or twitch_id == "" then return end
    spawn_queue[#spawn_queue + 1] = twitch_id
end

-- Drain up to SPAWNS_PER_FRAME mob requests. Call every frame from init.lua.
-- Ring locks are resolved lazily during allocation (ring_state), so there's no
-- lock-sweep to do here -- when the queue is empty this is a single length
-- check and returns immediately.
function MoistMob_ProcessSpawnQueue()
    local n = 0
    while #spawn_queue > 0 and n < SPAWNS_PER_FRAME do
        process_mob_request(table.remove(spawn_queue, 1))
        n = n + 1
    end
end

-- === Gifter sweatling (large, behind the player) =============================

local GIFTER_LIFETIME = CFG.gifter_lifetime_frames or (30 * 60)

-- Spawn the central gifter sweatling with its border bottom at the player Y.
-- Stationary, named, persists the whole window (its own lifetime). Its center
-- becomes the origin the mob rings are placed around (reset_rings).
local function spawn_gifter_sweatling(x, y, gifter)
    local u = gifter and users.by_login(gifter) or nil
    local half_h = (SL.BORDER_SIZE / 2) * CFG_GIFTER.scale
    local gx, gy = x, y - half_h
    local e = EntityLoad(BG_SWEATLING, gx, gy)
    if e == nil or e == 0 then return end

    local name = (u and u.login) or gifter
    SL.dress_sweatling(e, mob_layers(u), name, CFG_GIFTER)

    -- Gifter persists the whole window. Add the lifetime fresh (see mob spawn).
    EntityAddComponent2(e, "LifetimeComponent", { lifetime = GIFTER_LIFETIME })

    -- Rings are placed around the gifter center; reset the allocator to it.
    reset_rings(gx, gy)
end

-- === Sub/gift effect =========================================================

-- On a sub/gift: open/extend the window, spawn the emitters + gifter sweatling.
-- The mob itself comes from dnkM chat messages via MoistMob_QueuePulse while the
-- window is open.
function MoistMob_SpawnSubEffect(celebrant)
    open_window()

    local x, y = player_position()
    if x == nil then
        LOG("debug", "mob sub effect: window opened but no player position yet (celebrant="
            .. tostring(celebrant) .. ")")
        return
    end

    SetRandomSeed(x + GameGetFrameNum(), y - GameGetFrameNum())

    -- 4 rotated emitters around the player.
    for _, off in ipairs(EMITTER_OFFSETS) do
        local ex, ey = x + off[1], y + off[2]
        local e = EntityLoad(EMITTER, ex, ey)
        if e ~= nil and e ~= 0 then
            EntitySetTransform(e, ex, ey, random_rotation())
        end
    end

    -- Large gifter sweatling directly behind the player.
    spawn_gifter_sweatling(x, y, celebrant)

    LOG("debug", "mob sub effect: emitters + gifter, window open for celebrant="
        .. tostring(celebrant))

    -- TEST: when simulate_chat_moist_mob is enabled, replay a recorded burst of
    -- dnkM chatters into the mob (alongside any real chat). Config-gated.
    if CFG.simulate_chat_moist_mob and MoistMob_StartReplay then
        MoistMob_StartReplay()
    end
end

-- === TEST replay harness =====================================================
-- Feeds a real recorded burst of dnkM chatters (moist_mob_test_data.lua) into
-- the mob on their original relative timing, so we can gauge volume/cadence
-- without a live channel. Scheduled entries are consumed by MoistMob_TickReplay
-- (called each frame from init.lua). Each row carries the chatter's numeric
-- twitch id, fed through the same window-gated mob path as real chat, so
-- known-user ids (e.g. the leading shortman422) render their real cosmetics.
-- REMOVE this + the data file before ship.

local replay_data = dofile_once("mods/recocards_birthday/files/scripts/sweatling/moist_mob_test_data.lua")
local replay_entries = nil   -- { frame = <abs frame>, twitch_id = <id> }, sorted
local replay_index = 1

function MoistMob_StartReplay()
    local base = GameGetFrameNum()
    replay_entries = {}
    for _, row in ipairs(replay_data) do
        replay_entries[#replay_entries + 1] = {
            frame = base + math.floor(row.t * 60),  -- seconds -> frames
            twitch_id = row.twitch_id,
        }
    end
    replay_index = 1
    LOG("debug", "replay started: " .. tostring(#replay_entries) .. " dnkM messages")
end

-- Fire any replay entries whose scheduled frame has arrived (they call the same
-- window-gated mob path as real chat, using the recorded twitch id). Call each
-- frame from init.lua.
function MoistMob_TickReplay()
    if replay_entries == nil then return end
    local now = GameGetFrameNum()
    while replay_index <= #replay_entries
        and replay_entries[replay_index].frame <= now do
        MoistMob_QueuePulse(replay_entries[replay_index].twitch_id)
        replay_index = replay_index + 1
    end
    if replay_index > #replay_entries then
        replay_entries = nil  -- done
    end
end
