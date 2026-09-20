local MOD = "mods/recocards_birthday/files/trial_of_the_gods/"

local M = {}
M.CENTER_X = 12000
M.CENTER_Y = 24000
M.INNER_W = 1040
M.INNER_H = 660
M.BORDER = 160
M.SCENE_W = M.INNER_W + M.BORDER * 2
M.SCENE_H = M.INNER_H + M.BORDER * 2
M.SCENE_X = M.CENTER_X - math.floor(M.SCENE_W / 2)
M.SCENE_Y = M.CENTER_Y - math.floor(M.SCENE_H / 2)
M.INNER_X = M.CENTER_X - math.floor(M.INNER_W / 2)
M.INNER_Y = M.CENTER_Y - math.floor(M.INNER_H / 2)
M.PLATFORM_SCENE_X = M.CENTER_X - 118
M.PLATFORM_SCENE_Y = M.CENTER_Y + 30
M.PLATFORM_Y = M.PLATFORM_SCENE_Y + 16
M.PLAYER_SPAWN_X = M.CENTER_X
M.PLAYER_SPAWN_Y = M.PLATFORM_Y - 26
M.PRETRIAL_PORTAL_X = M.CENTER_X + 50
M.PRETRIAL_PORTAL_Y = M.PLATFORM_Y - 30
M.START_MARKER_X = M.CENTER_X - 36
M.START_MARKER_Y = M.PLATFORM_Y - 8
M.FLOOR_PORTAL_X = M.CENTER_X
M.FLOOR_PORTAL_Y = M.CENTER_Y + math.floor(M.INNER_H / 2) - 36

local np_cache = nil
local function NP()
  if np_cache then return np_cache end
  local ok, lib = pcall(require, "noitapatcher")
  if ok and lib then np_cache = lib end
  return np_cache
end

local function force_scene(materials, visuals, x, y, background, map, z)
  local np = NP()
  if np and np.ForceLoadPixelScene then
    local ok = pcall(
      np.ForceLoadPixelScene,
      materials, visuals, x, y, background or "",
      true, true, map or {}, z or 50
    )
    if ok then return end
  end
  LoadPixelScene(
    materials, visuals, x, y, background or "",
    true, true, map or {}, z or 50, true
  )
end

function M.force_build()
  force_scene(
    MOD .. "files/arena/arena_materials.png",
    MOD .. "files/arena/arena_visuals.png",
    M.SCENE_X,
    M.SCENE_Y,
    MOD .. "files/arena/arena_background.png",
    { ["ff7f7f7f"] = "templebrick_static" },
    50
  )
end

function M.force_carve()
  force_scene(
    MOD .. "files/arena/arena_carve_materials.png",
    MOD .. "files/arena/arena_carve_visuals.png",
    M.INNER_X,
    M.INNER_Y,
    "",
    { ["ff000000"] = "air" },
    50
  )
end

function M.ensure_streamer()
  local existing = EntityGetWithTag("totg_arena_streamer") or {}
  for _, e in ipairs(existing) do
    if EntityGetIsAlive(e) then return e end
  end
  local e = EntityCreateNew("totg_arena_streamer")
  EntityAddTag(e, "totg_arena_streamer")
  EntitySetTransform(e, M.CENTER_X, M.CENTER_Y)
  EntityAddComponent2(e, "HitboxComponent", {
    aabb_min_x = -math.floor(M.INNER_W / 2) - 8,
    aabb_min_y = -math.floor(M.INNER_H / 2) - 8,
    aabb_max_x =  math.floor(M.INNER_W / 2) + 8,
    aabb_max_y =  math.floor(M.INNER_H / 2) + 8,
  })
  EntityAddComponent2(e, "StreamingKeepAliveComponent", {})
  return e
end

function M.kill_carvers()
  for _, e in ipairs(EntityGetWithTag("totg_arena_carver") or {}) do
    if EntityGetIsAlive(e) then EntityKill(e) end
  end
end

function M.spawn_cell_carvers()
  local radius = 96
  local step = 120
  local left = M.INNER_X
  local top = M.INNER_Y
  local right = M.INNER_X + M.INNER_W
  local bottom = M.INNER_Y + M.INNER_H

  local xs = {}
  local x = left + radius
  while x < right - radius do
    xs[#xs + 1] = x
    x = x + step
  end
  xs[#xs + 1] = right - radius

  local ys = {}
  local y = top + radius
  while y < bottom - radius do
    ys[#ys + 1] = y
    y = y + step
  end
  ys[#ys + 1] = bottom - radius

  for _, cx in ipairs(xs) do
    for _, cy in ipairs(ys) do
      local e = EntityCreateNew("totg_arena_carver")
      EntityAddTag(e, "totg_arena_carver")
      EntitySetTransform(e, cx, cy)
      EntityAddComponent2(e, "CellEaterComponent", {
        radius = radius,
        eat_probability = 100,
        only_stain = false,
        eat_dynamic_physics_bodies = true,
        limited_materials = false,
      })
      EntityAddComponent2(e, "LifetimeComponent", { lifetime = 24 })
    end
  end
end

function M.restore_platform()
  force_scene(
    MOD .. "files/arena/platform_restore_materials.png",
    MOD .. "files/arena/platform_restore_visuals.png",
    M.PLATFORM_SCENE_X,
    M.PLATFORM_SCENE_Y,
    "",
    { ["ff8a8a8a"] = "rock_static" },
    50
  )
end

function M.clear_platform()
  force_scene(
    MOD .. "files/arena/platform_clear_materials.png",
    MOD .. "files/arena/platform_clear_visuals.png",
    M.PLATFORM_SCENE_X,
    M.PLATFORM_SCENE_Y,
    "",
    { ["ff000000"] = "air" },
    50
  )
end


function M.spawn_platform_eaters()
  for _, e in ipairs(EntityGetWithTag("totg_platform_eater") or {}) do
    if EntityGetIsAlive(e) then EntityKill(e) end
  end
  local y = M.PLATFORM_SCENE_Y + 68
  for _, dx in ipairs({ -72, 0, 72 }) do
    local e = EntityCreateNew("totg_platform_eater")
    EntityAddTag(e, "totg_platform_eater")
    EntitySetTransform(e, M.CENTER_X + dx, y)
    EntityAddComponent2(e, "CellEaterComponent", {
      radius = 82,
      eat_probability = 100,
      only_stain = false,
      eat_dynamic_physics_bodies = true,
      limited_materials = false,
    })
    EntityAddComponent2(e, "LifetimeComponent", { lifetime = 6 })
  end
end

function M.kill_platform_eaters()
  for _, e in ipairs(EntityGetWithTag("totg_platform_eater") or {}) do
    if EntityGetIsAlive(e) then EntityKill(e) end
  end
end

function M.prepare_idle_state(skip_platform, keep_trial_state)
  M.kill_carvers()
  M.kill_platform_eaters()
  if not keep_trial_state then
    GlobalsSetValue("TOTG_TRIAL_state", "idle")
  end
  GlobalsSetValue("TOTG_TRIAL_wand_index", "1")
  GlobalsSetValue("TOTG_TRIAL_phase", "spawn")
  GlobalsSetValue("TOTG_TRIAL_phase_timer", "0")
  GlobalsSetValue("TOTG_TRIAL_active_wand", "0")
  GlobalsSetValue("TOTG_TRIAL_start_request", "")
  GlobalsSetValue("TOTG_TRIAL_saved_active_item", "0")
  GlobalsSetValue("TOTG_TRIAL_borrowed_item", "0")
  GlobalsSetValue("TOTG_TRIAL_borrowed_slot", "-1")
  GlobalsSetValue("TOTG_TRIAL_last_fired_wand", "0")
  if not skip_platform then M.restore_platform() end
  for _,e in ipairs(EntityGetWithTag("totg_return_portal") or {}) do EntityKill(e) end
  for _,e in ipairs(EntityGetWithTag("totg_arena_start_prompt") or {}) do EntityKill(e) end
  for _,e in ipairs(EntityGetWithTag("totg_trial_temp_wand") or {}) do EntityKill(e) end
  EntityLoad(MOD .. "files/portal/return_portal.xml", M.PRETRIAL_PORTAL_X, M.PRETRIAL_PORTAL_Y)
  EntityLoad(MOD .. "files/trial/start_marker.xml", M.START_MARKER_X, M.START_MARKER_Y)
end

local function add_unique_entity(list, seen, e)
  if e ~= nil and e ~= 0 and EntityGetIsAlive(e) and not seen[e] then
    seen[e] = true
    list[#list + 1] = e
  end
end

local function collect_start_portals(x, y)
  local list = {}
  local seen = {}
  for _, tag in ipairs({ "totg_arena_portal", "totg_portal_start", "totg_arena_portal totg_portal_start" }) do
    for _, e in ipairs(EntityGetWithTag(tag) or {}) do
      add_unique_entity(list, seen, e)
    end
  end
  if EntityGetInRadius then
    for _, e in ipairs(EntityGetInRadius(x, y, 220) or {}) do
      if EntityGetName(e) == "totg_arena_portal" then
        add_unique_entity(list, seen, e)
      end
    end
  end
  return list
end

function M.ensure_portal(px, py)
  local stored_x = tonumber(GlobalsGetValue("TOTG_START_PORTAL_X", "0")) or 0
  local stored_y = tonumber(GlobalsGetValue("TOTG_START_PORTAL_Y", "0")) or 0
  local portal_x = stored_x
  local portal_y = stored_y

  if portal_x == 0 and portal_y == 0 then
    if math.abs(px - M.CENTER_X) < M.SCENE_W and math.abs(py - M.CENTER_Y) < M.SCENE_H then
      return
    end
    portal_x = px + 150
    portal_y = py - 42
    GlobalsSetValue("TOTG_START_PORTAL_X", tostring(portal_x))
    GlobalsSetValue("TOTG_START_PORTAL_Y", tostring(portal_y))
    GlobalsSetValue("TOTG_START_RETURN_X", tostring(px + 92))
    GlobalsSetValue("TOTG_START_RETURN_Y", tostring(py - 18))
  end

  local portal_active = GameHasFlagRun("totg_start_portal_activated")
  local desired_tag = portal_active and "totg_portal_active" or "totg_portal_inactive"
  local desired_xml = portal_active
    and (MOD .. "files/portal/start_portal.xml")
    or (MOD .. "files/portal/start_portal_inactive.xml")

  local portals = collect_start_portals(portal_x, portal_y)
  local keep = 0
  local best_dist = 999999999
  for _, e in ipairs(portals) do
    if EntityHasTag(e, desired_tag) then
      local ex, ey = EntityGetTransform(e)
      local dx = ex - portal_x
      local dy = ey - portal_y
      local d = dx * dx + dy * dy
      if d < best_dist then
        keep = e
        best_dist = d
      end
    end
  end

  for _, e in ipairs(portals) do
    if e ~= keep and EntityGetIsAlive(e) then
      EntityKill(e)
    end
  end

  if keep == 0 then
    keep = EntityLoad(desired_xml, portal_x, portal_y)
  else
    EntitySetTransform(keep, portal_x, portal_y)
  end

  return keep
end

return M
