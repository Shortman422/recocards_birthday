local MOD = "mods/recocards_birthday/files/trial_of_the_gods/"
local builder = nil
local arena = nil

local np = nil
local noitapatcher_error = "not loaded"

local NP_CANDIDATES = {
  "mods/recocards_birthday/files/trial_of_the_gods/NoitaPatcher/load.lua",
  "mods/recocards_birthday/files/trial_of_the_gods/noitapatcher/load.lua",
  "mods/recocards_birthday/files/trial_of_the_gods/Noitapatcher/load.lua",
  "mods/NoitaPatcher/load.lua",
  "mods/noitapatcher/load.lua",
  "mods/quant.ew/NoitaPatcher/load.lua",
  "mods/metamorph_creative_menu/NoitaPatcher/load.lua",
}

local TRIAL_CONTROL_BOOL_FIELDS = {
  "mButtonDownFire", "mButtonDownFire2", "mButtonDownAction",
  "mButtonDownThrow", "mButtonDownKick",
  "mButtonDownLeftClick", "mButtonDownRightClick",
  "mButtonDownChangeItemR", "mButtonDownChangeItemL",
  "mButtonDownDropItem", "mButtonDownDig", "mButtonDownEat",
}

local TRIAL_CONTROL_FRAME_FIELDS = {
  "mButtonFrameFire", "mButtonFrameFire2", "mButtonFrameAction",
  "mButtonFrameThrow", "mButtonFrameKick",
  "mButtonFrameLeftClick", "mButtonFrameRightClick",
  "mButtonFrameChangeItemR", "mButtonFrameChangeItemL",
  "mButtonFrameDropItem", "mButtonFrameDig", "mButtonFrameEat",
}

local function try_load_noitapatcher()
  if np then return true end
  local found_any = false
  for _, path in ipairs(NP_CANDIDATES) do
    if ModDoesFileExist(path) then
      found_any = true
      local ok_call, load_result, load_err = pcall(dofile_once, path)
      if ok_call and load_err == nil then
        local ok_require, lib = pcall(require, "noitapatcher")
        if ok_require and lib and lib.UseItem then
          np = lib
          noitapatcher_error = ""
          GlobalsSetValue("TOTG_NOITAPATCHER", path)
          return true
        end
        noitapatcher_error = "require(noitapatcher): " .. tostring(lib)
      else
        noitapatcher_error = "load.lua: " .. tostring(load_err or load_result)
      end
    end
  end
  GlobalsSetValue("TOTG_NOITAPATCHER", found_any and ("error: " .. tostring(noitapatcher_error)) or "missing")
  return false
end

try_load_noitapatcher()

local function A()
  if not arena then arena = dofile_once(MOD .. "files/arena/setup.lua") end
  return arena
end

local function B()
  if not builder then builder = dofile_once(MOD .. "files/wand_builder.lua") end
  return builder
end

local function sg(k, default)
  return GlobalsGetValue("TOTG_TRIAL_" .. k, tostring(default or ""))
end
local function ss(k, v)
  GlobalsSetValue("TOTG_TRIAL_" .. k, tostring(v))
end

local function get_player()
  local p = EntityGetWithTag("player_unit") or {}
  return p[1] or 0
end

local function kill_tag(tag)
  for _, e in ipairs(EntityGetWithTag(tag) or {}) do
    if EntityGetIsAlive(e) then EntityKill(e) end
  end
end

local function controls(player)
  return EntityGetFirstComponentIncludingDisabled(player, "ControlsComponent")
end

local function inventory_comp(player)
  return EntityGetFirstComponentIncludingDisabled(player, "Inventory2Component")
end

local function find_quick_inventory(player)
  for _, child in ipairs(EntityGetAllChildren(player) or {}) do
    if EntityGetName(child) == "inventory_quick" then return child end
  end
  return 0
end

local function set_inventory_gui_enabled(player, enabled)
  local c = EntityGetFirstComponentIncludingDisabled(player, "InventoryGuiComponent")
  if c then EntitySetComponentIsEnabled(player, c, enabled) end
end

local function ensure_wand_fired_callback(player)
  for _, c in ipairs(EntityGetComponentIncludingDisabled(player, "LuaComponent") or {}) do
    if ComponentGetValue2(c, "script_wand_fired") == MOD .. "files/trial/wand_fired.lua" then
      return
    end
  end
  EntityAddComponent2(player, "LuaComponent", {
    script_wand_fired = MOD .. "files/trial/wand_fired.lua",
    execute_every_n_frame = -1,
  })
end

local function capture_aim(player)
  local c = controls(player)
  local ax, ay, nx, ny = 40, 0, 1, 0
  if c then
    local x, y = ComponentGetValue2(c, "mAimingVector")
    local xx, yy = ComponentGetValue2(c, "mAimingVectorNormalized")
    x, y, xx, yy = tonumber(x), tonumber(y), tonumber(xx), tonumber(yy)
    if x and y and math.abs(x) + math.abs(y) > 0.01 then ax, ay = x, y end
    if xx and yy and math.abs(xx) + math.abs(yy) > 0.01 then nx, ny = xx, yy end
  end
  ss("aim_x", ax); ss("aim_y", ay); ss("aim_nx", nx); ss("aim_ny", ny)
end

local function suppress_trial_item_input(player)
  local c = controls(player)
  if not c then return end
  local frame = GameGetFrameNum()

  for _, field in ipairs(TRIAL_CONTROL_BOOL_FIELDS) do ComponentSetValue2(c, field, false) end
  for _, field in ipairs(TRIAL_CONTROL_FRAME_FIELDS) do ComponentSetValue2(c, field, frame - 2) end

  local ax = tonumber(sg("aim_x", "40")) or 40
  local ay = tonumber(sg("aim_y", "0")) or 0
  local nx = tonumber(sg("aim_nx", "1")) or 1
  local ny = tonumber(sg("aim_ny", "0")) or 0
  local px, py = EntityGetTransform(player)
  ComponentSetValue2(c, "mAimingVector", ax, ay)
  ComponentSetValue2(c, "mAimingVectorNormalized", nx, ny)
  ComponentSetValue2(c, "mAimingVectorNonZeroLatest", ax, ay)
  ComponentSetValue2(c, "mMousePosition", px + ax, py + ay)
  ComponentSetValue2(c, "mGamePadCursorInWorld", px + ax, py + ay)
end

local function zero_player_velocity(player)
  local v = EntityGetFirstComponentIncludingDisabled(player, "VelocityComponent")
  if v then ComponentSetValue2(v, "mVelocity", 0, 0) end
  local d = EntityGetFirstComponentIncludingDisabled(player, "CharacterDataComponent")
  if d then ComponentSetValue2(d, "mVelocity", 0, 0) end
end

local function begin_arena_entry(player)
  local ar = A()
  ar.ensure_streamer()
  ss("state", "entering")
  GlobalsSetValue("TOTG_ARENA_ENTER_REQUEST", "")

  if GlobalsGetValue("TOTG_ARENA_CLEARED", "0") == "1" then
    GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "reentry")
    return
  end

  ar.force_build()
  GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "streaming")
  GlobalsSetValue("TOTG_ARENA_ENTRY_STREAM_END", tostring(GameGetFrameNum() + 75))
  GlobalsSetValue("TOTG_ARENA_ENTRY_END", tostring(GameGetFrameNum() + 180))
  GlobalsSetValue("TOTG_ARENA_ENTRY_NEXT_CARVE", tostring(GameGetFrameNum() + 76))
end

local function update_arena_entry(player)
  local frame = GameGetFrameNum()
  local ar = A()
  local stage = GlobalsGetValue("TOTG_ARENA_ENTRY_STAGE", "streaming")

  if stage == "reentry" then
    ar.kill_carvers()
    ar.prepare_idle_state(false, true)
    ar.restore_platform()
    zero_player_velocity(player)
    EntitySetTransform(player, ar.PLAYER_SPAWN_X, ar.PLAYER_SPAWN_Y)
    zero_player_velocity(player)
    ss("state", "idle")
    GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "done")
    GlobalsSetValue("TOTG_ARENA_POST_TELEPORT_CHECK", tostring(frame + 2))
    GamePrintImportant("TRIAL OF THE GODS", "Entered arena")
    return
  end

  local stream_end = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_STREAM_END", "0")) or 0
  if stage == "streaming" and frame >= stream_end then
    stage = "carving"
    GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", stage)
    ar.force_carve()
    ar.spawn_cell_carvers()
    GlobalsSetValue("TOTG_ARENA_ENTRY_NEXT_CARVE", tostring(frame + 12))
  elseif stage == "carving" then
    local next_carve = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_NEXT_CARVE", "0")) or 0
    if frame >= next_carve then
      ar.force_carve()
      ar.spawn_cell_carvers()
      GlobalsSetValue("TOTG_ARENA_ENTRY_NEXT_CARVE", tostring(frame + 12))
    end
  end

  local finish = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_END", "0")) or 0
  if stage == "carving" and frame >= finish then
    ar.kill_carvers()
    ar.force_carve()
    ar.spawn_cell_carvers()
    GlobalsSetValue("TOTG_ARENA_ENTRY_FINALIZE", tostring(frame + 18))
    GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "finalize")
    return
  end

  if stage == "finalize" then
    local fin = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_FINALIZE", "0")) or 0
    if frame >= fin then
      ar.kill_carvers()
      GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "carver_drain")
      GlobalsSetValue("TOTG_ARENA_ENTRY_PLATFORM_AT", tostring(frame + 36))
    end
    return
  end

  if stage == "carver_drain" then
    local platform_at = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_PLATFORM_AT", "0")) or 0
    if frame >= platform_at then
      ar.kill_carvers()
      ar.prepare_idle_state(true, true)
      GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "platform_spawn")
      GlobalsSetValue("TOTG_ARENA_ENTRY_PLATFORM_AT", tostring(frame + 6))
    end
    return
  end

  if stage == "platform_spawn" then
    local platform_at = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_PLATFORM_AT", "0")) or 0
    if frame >= platform_at then
      ar.kill_carvers()
      ar.restore_platform()
      GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "platform_verify")
      GlobalsSetValue("TOTG_ARENA_ENTRY_PLATFORM_AT", tostring(frame + 12))
    end
    return
  end

  if stage == "platform_verify" then
    local platform_at = tonumber(GlobalsGetValue("TOTG_ARENA_ENTRY_PLATFORM_AT", "0")) or 0
    if frame >= platform_at then
      ar.kill_carvers()
      ar.restore_platform()

      zero_player_velocity(player)
      EntitySetTransform(player, ar.PLAYER_SPAWN_X, ar.PLAYER_SPAWN_Y)
      zero_player_velocity(player)

      GlobalsSetValue("TOTG_ARENA_CLEARED", "1")
      ss("state", "idle")
      GlobalsSetValue("TOTG_ARENA_ENTRY_STAGE", "done")
      GlobalsSetValue("TOTG_ARENA_POST_TELEPORT_CHECK", tostring(frame + 2))
      GamePrintImportant("TRIAL OF THE GODS", "Entered arena")
    end
    return
  end
end

local function post_teleport_safety_check(player)
  local at = tonumber(GlobalsGetValue("TOTG_ARENA_POST_TELEPORT_CHECK", "0")) or 0
  if at <= 0 or GameGetFrameNum() < at then return end
  GlobalsSetValue("TOTG_ARENA_POST_TELEPORT_CHECK", "0")
  local ar = A()
  local x, y = EntityGetTransform(player)
  if math.abs(x - ar.PLAYER_SPAWN_X) > 96 or math.abs(y - ar.PLAYER_SPAWN_Y) > 96 then
    EntitySetTransform(player, ar.PLAYER_SPAWN_X, ar.PLAYER_SPAWN_Y)
    zero_player_velocity(player)
  end
end

local function remove_platform()
  A().clear_platform()
end

local function spawn_exit_portal()
  if #(EntityGetWithTag("totg_return_portal") or {}) > 0 then return end
  local ar = A()
  EntityLoad(MOD .. "files/portal/return_portal.xml", ar.FLOOR_PORTAL_X, ar.FLOOR_PORTAL_Y)
end

local function hide_temp_wand(wand)
  for _, sc in ipairs(EntityGetComponentIncludingDisabled(wand, "SpriteComponent") or {}) do
    EntitySetComponentIsEnabled(wand, sc, false)
  end
end

local function is_wand_entity(item)
  local ability = EntityGetFirstComponentIncludingDisabled(item, "AbilityComponent")
  return ability ~= nil and ComponentGetValue2(ability, "use_gun_script") == true
end

local function quick_wand_in_slot(player, slot_x)
  local quick = find_quick_inventory(player)
  if quick == 0 then return 0 end
  for _, item in ipairs(EntityGetAllChildren(quick) or {}) do
    local ic = EntityGetFirstComponentIncludingDisabled(item, "ItemComponent")
    if ic and is_wand_entity(item) then
      local sx, sy = ComponentGetValue2(ic, "inventory_slot")
      sx, sy = tonumber(sx) or -1, tonumber(sy) or 0
      if sx == slot_x and sy == 0 then return item end
    end
  end
  return 0
end

local function choose_trial_wand_slot(player)
  for slot = 3, 0, -1 do
    if quick_wand_in_slot(player, slot) == 0 then return slot end
  end
  return 3
end

local function ensure_slot_stash()
  local old = EntityGetWithTag("totg_trial_slot_stash") or {}
  for _, e in ipairs(old) do
    if EntityGetIsAlive(e) then return e end
  end
  local e = EntityCreateNew("totg_trial_slot_stash")
  EntityAddTag(e, "totg_trial_slot_stash")
  EntitySetTransform(e, -100000, -100000)
  return e
end

local function borrow_trial_slot(player)
  local quick = find_quick_inventory(player)
  if quick == 0 then return false, "inventory_quick not found" end
  local slot = choose_trial_wand_slot(player)
  local displaced = quick_wand_in_slot(player, slot)
  ss("borrowed_slot", slot)
  ss("borrowed_item", displaced)
  if displaced ~= 0 and EntityGetIsAlive(displaced) then
    local stash = ensure_slot_stash()
    EntityRemoveFromParent(displaced)
    EntityAddChild(stash, displaced)
  end
  return true
end

local function restore_borrowed_slot(player)
  local quick = find_quick_inventory(player)
  if quick == 0 then return end
  local slot = tonumber(sg("borrowed_slot", "3")) or 3
  local displaced = tonumber(sg("borrowed_item", "0")) or 0
  if displaced ~= 0 and EntityGetIsAlive(displaced) then
    EntityRemoveFromParent(displaced)
    EntityAddChild(quick, displaced)
    local ic = EntityGetFirstComponentIncludingDisabled(displaced, "ItemComponent")
    if ic then ComponentSetValue2(ic, "inventory_slot", slot, 0) end
  end
  kill_tag("totg_trial_slot_stash")
  ss("borrowed_item", 0)
  ss("borrowed_slot", -1)
end

local function attach_trial_wand_to_player(player, wand)
  local quick = find_quick_inventory(player)
  if quick == 0 then return false end
  local slot = tonumber(sg("borrowed_slot", "3")) or 3
  EntityRemoveFromParent(wand)
  EntityAddChild(quick, wand)
  local item = EntityGetFirstComponentIncludingDisabled(wand, "ItemComponent")
  if item then
    ComponentSetValue2(item, "inventory_slot", slot, 0)
    ComponentSetValue2(item, "next_frame_pickable", GameGetFrameNum() + 999999)
    ComponentSetValue2(item, "npc_next_frame_pickable", GameGetFrameNum() + 999999)
  end
  return true
end

local function save_active_item(player)
  local inv = inventory_comp(player)
  local active = inv and (tonumber(ComponentGetValue2(inv, "mActiveItem") or 0) or 0) or 0
  ss("saved_active_item", active)
end

local function restore_active_item(player)
  restore_borrowed_slot(player)
  local active = tonumber(sg("saved_active_item", "0")) or 0
  if np and active ~= 0 and EntityGetIsAlive(active) then
    pcall(np.SetActiveHeldEntity, player, active, false, false)
  end
end

local function restore_between_casts(player)
  local active = tonumber(sg("saved_active_item", "0")) or 0
  if np and active ~= 0 and EntityGetIsAlive(active) and EntityGetParent(active) == find_quick_inventory(player) then
    pcall(np.SetActiveHeldEntity, player, active, false, false)
  end
end

local function create_temp_wand(player, index)
  local px, py = EntityGetTransform(player)
  local wand = B().create(index, px, py)
  if not wand or wand == 0 then return 0 end
  EntityAddTag(wand, "totg_trial_temp_wand")
  hide_temp_wand(wand)
  if not attach_trial_wand_to_player(player, wand) then
    EntityKill(wand)
    return 0
  end
  return wand
end

local function ability_cast_frame(wand)
  if wand == 0 or not EntityGetIsAlive(wand) then return -999999 end
  local a = EntityGetFirstComponentIncludingDisabled(wand, "AbilityComponent")
  if not a then return -999999 end
  return tonumber(ComponentGetValue2(a, "mCastDelayStartFrame") or -999999) or -999999
end

local complete_trial

local function tag_trial_effect(projectile_id)
  if projectile_id == nil or projectile_id == 0 or not EntityGetIsAlive(projectile_id) then return end
  EntityAddTag(projectile_id, "totg_trial_effect")
  ss("effect_seen_any", 1)
  ss("last_effect_spawn_frame", GameGetFrameNum())
end

local function effect_in_arena(e, ar, mx, my)
  local x, y = EntityGetTransform(e)
  return math.abs(x - ar.CENTER_X) <= mx and math.abs(y - ar.CENTER_Y) <= my
end

local function refresh_trial_effect_tags(player)
  local ar = A()
  local mx = math.floor(ar.INNER_W / 2) + 256
  local my = math.floor(ar.INNER_H / 2) + 256
  for _, e in ipairs(EntityGetWithTag("projectile") or {}) do
    if EntityGetIsAlive(e) and not EntityHasTag(e, "totg_trial_effect") and effect_in_arena(e, ar, mx, my) then
      local pc = EntityGetFirstComponentIncludingDisabled(e, "ProjectileComponent")
      if pc then
        local who = tonumber(ComponentGetValue2(pc, "mWhoShot") or 0) or 0
        if who == player then tag_trial_effect(e) end
      end
    end
  end
end

local function live_trial_effect_count()
  local n = 0
  local ar = A()
  local mx = math.floor(ar.INNER_W / 2) + 256
  local my = math.floor(ar.INNER_H / 2) + 256
  for _, e in ipairs(EntityGetWithTag("totg_trial_effect") or {}) do
    if EntityGetIsAlive(e) and effect_in_arena(e, ar, mx, my) then n = n + 1 end
  end
  return n
end

local function begin_survival(player)
  restore_active_item(player)
  kill_tag("totg_trial_temp_wand")
  ss("active_wand", 0)
  ss("state", "survival")
  ss("phase", "effects_active")
  ss("survival_started", GameGetFrameNum())
  ss("last_effect_seen_frame", GameGetFrameNum())
  GamePrintImportant("TRIAL OF THE GODS", "All 4 wands cast - survive until the final spell effect expires")
end

local function update_survival(player)
  suppress_trial_item_input(player)
  local frame = GameGetFrameNum()
  if frame % 5 ~= 0 then return end
  local started = tonumber(sg("survival_started", tostring(frame))) or frame
  if frame % 15 == 0 then refresh_trial_effect_tags(player) end
  local live = live_trial_effect_count()
  if live > 0 then
    ss("last_effect_seen_frame", frame)
  else
    if sg("effect_seen_any", "0") == "1" then
      local last_seen = tonumber(sg("last_effect_seen_frame", tostring(frame))) or frame
      local last_spawn = tonumber(sg("last_effect_spawn_frame", tostring(last_seen))) or last_seen
      local quiet_from = math.max(last_seen, last_spawn)
      if frame - quiet_from >= 120 then
        complete_trial(player)
        return
      end
    end
  end
  if frame - started >= 19800 then
    complete_trial(player)
  end
end

local function restore_idle_after_error(player, message)
  suppress_trial_item_input(player)
  restore_active_item(player)
  kill_tag("totg_trial_temp_wand")
  set_inventory_gui_enabled(player, true)
  ss("active_wand", 0)
  ss("state", "idle")
  ss("phase", "spawn")
  ss("start_request", "")
  A().prepare_idle_state()
  GamePrintImportant("TOTG TRIAL ABORTED", message)
end

complete_trial = function(player)
  suppress_trial_item_input(player)
  restore_active_item(player)
  kill_tag("totg_trial_temp_wand")
  set_inventory_gui_enabled(player, true)
  ss("active_wand", 0)
  ss("state", "completed")
  ss("phase", "done")
  spawn_exit_portal()
  GamePrintImportant("TRIAL OF THE GODS", "Trial finished")
end

local function start_trial(player)
  ss("start_request", "")
  if not try_load_noitapatcher() then
    GamePrintImportant(
      "TOTG: NOITAPATCHER REQUIRED",
      "Install NoitaPatcher 1.36.2 (Unsafe Mods) - trial was NOT started"
    )
    return false
  end

  capture_aim(player)
  save_active_item(player)
  local slot_ok, slot_err = borrow_trial_slot(player)
  if not slot_ok then
    GamePrintImportant("TOTG TRIAL ABORTED", tostring(slot_err))
    return false
  end
  set_inventory_gui_enabled(player, true)
  kill_tag("totg_return_portal")
  kill_tag("totg_portal_particle")
  kill_tag("totg_arena_start_prompt")
  kill_tag("totg_trial_temp_wand")
  kill_tag("totg_trial_effect")
  A().kill_platform_eaters()
  ss("effect_seen_any", 0)
  ss("last_effect_spawn_frame", -1)
  ss("last_effect_seen_frame", -1)
  remove_platform()
  ss("state", "running")
  ss("wand_index", 1)
  ss("phase", "spawn")
  ss("phase_timer", GameGetFrameNum() + 5)
  ss("active_wand", 0)
  ss("last_fired_wand", 0)
  GamePrintImportant("TRIAL OF THE GODS", "Trial started - player casts locked")
  return true
end

local function use_trial_wand(player, wand)
  local px, py = EntityGetTransform(player)
  local ax = tonumber(sg("aim_x", "40")) or 40
  local ay = tonumber(sg("aim_y", "0")) or 0
  local nx = tonumber(sg("aim_nx", "1")) or 1
  local ny = tonumber(sg("aim_ny", "0")) or 0
  local origin_x = px + nx * 2
  local origin_y = py + ny * 2 - 1
  local target_x = origin_x + ax
  local target_y = origin_y + ay

  EntitySetTransform(wand, px, py)
  if np.SetActiveHeldEntity then
    np.SetActiveHeldEntity(player, wand, false, false)
  end

  return pcall(
    np.UseItem,
    player, wand,
    true,
    true,
    true,
    origin_x, origin_y,
    target_x, target_y
  )
end

local function update_trial(player)
  suppress_trial_item_input(player)
  local frame = GameGetFrameNum()
  local idx = tonumber(sg("wand_index", "1")) or 1
  local phase = sg("phase", "spawn")
  local timer = tonumber(sg("phase_timer", "0")) or 0
  local wand = tonumber(sg("active_wand", "0")) or 0

  if frame % 15 == 0 then refresh_trial_effect_tags(player) end

  if idx > 4 then
    begin_survival(player)
    return
  end

  if phase == "spawn" then
    if frame < timer then return end
    local w = create_temp_wand(player, idx)
    if w == 0 then
      restore_idle_after_error(player, "Could not create verified wand " .. tostring(idx))
      return
    end
    ss("active_wand", w)
    ss("cast_before", ability_cast_frame(w))
    ss("last_fired_wand", 0)
    if idx == 1 then
      A().spawn_platform_eaters()
      ss("phase", "platform_eat")
      ss("phase_timer", frame + 4)
    else
      ss("phase", "cast")
      ss("phase_timer", frame + 2)
    end
    return
  end

  if wand == 0 or not EntityGetIsAlive(wand) then
    restore_idle_after_error(player, "Temporary trial wand disappeared")
    return
  end

  if np and np.SetActiveHeldEntity and wand ~= 0 and EntityGetIsAlive(wand) then
    pcall(np.SetActiveHeldEntity, player, wand, false, false)
  end

  if phase == "platform_eat" then
    if frame < timer then return end
    A().kill_platform_eaters()
    remove_platform()
    ss("phase", "cast")
    ss("phase_timer", frame + 1)
    return
  end

  if phase == "cast" then
    if frame < timer then return end
    local ok, err = use_trial_wand(player, wand)
    if not ok then
      restore_idle_after_error(player, "NoitaPatcher UseItem error: " .. tostring(err))
      return
    end
    ss("cast_call_frame", frame)
    ss("phase", "verify")
    ss("phase_timer", frame + 12)
    return
  end

  if phase == "verify" then
    local fired_wand = tonumber(sg("last_fired_wand", "0")) or 0
    local before = tonumber(sg("cast_before", "-999999")) or -999999
    local after = ability_cast_frame(wand)
    if fired_wand == wand or after ~= before then
      local cast_frame = tonumber(sg("cast_call_frame", tostring(frame))) or frame
      ss("phase", "cooldown")
      ss("phase_timer", math.max(frame, cast_frame + 34))
      return
    end
    if frame >= timer then
      restore_idle_after_error(player, "Wand " .. tostring(idx) .. " produced no WandFired/Ability cast event")
      return
    end
    return
  end

  if phase == "cooldown" then
    if frame >= timer then
      if wand ~= 0 and EntityGetIsAlive(wand) then EntityKill(wand) end
      restore_between_casts(player)
      ss("wand_index", idx + 1)
      ss("active_wand", 0)
      ss("phase", "spawn")
      ss("phase_timer", frame)
    end
  end
end

function TrialOfTheGods_OnProjectileFired(shooter_id, projectile_id, initial_rng, position_x, position_y, target_x, target_y, send_message, unknown1, multicast_index, unknown3)
  local state = sg("state", "outside")
  if state ~= "running" and state ~= "survival" then return end
  local player = get_player()
  if player == 0 or projectile_id == nil or projectile_id == 0 then return end

  local belongs_to_player = (shooter_id == player)
  local pc = EntityGetFirstComponentIncludingDisabled(projectile_id, "ProjectileComponent")
  if pc then
    local who = tonumber(ComponentGetValue2(pc, "mWhoShot") or 0) or 0
    if who == player then belongs_to_player = true end
  end
  if belongs_to_player then tag_trial_effect(projectile_id) end
end

function TrialOfTheGods_OnPlayerSpawned(player)
  kill_tag("totg_trial_runtime")
  kill_tag("totg_exporter_runtime")
  ensure_wand_fired_callback(player)
  set_inventory_gui_enabled(player, true)
  local px, py = EntityGetTransform(player)
  A().ensure_portal(px, py)
end

function TrialOfTheGods_OnWorldPreUpdate()
  local player = get_player()
  if player == 0 then return end

  post_teleport_safety_check(player)

  local enter_request = GlobalsGetValue("TOTG_ARENA_ENTER_REQUEST", "")
  local state = sg("state", "outside")
  if enter_request ~= "" and state ~= "entering" then
    begin_arena_entry(player)
    state = sg("state", "outside")
  end
  if state == "entering" then
    update_arena_entry(player)
    return
  end

  if state == "idle" and sg("start_request", "") ~= "" then
    start_trial(player)
    state = sg("state", "idle")
  end
  if state == "running" then
    update_trial(player)
  elseif state == "survival" then
    update_survival(player)
  end
end
