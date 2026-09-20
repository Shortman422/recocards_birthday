local function release_item_controls(player)
  local c = EntityGetFirstComponentIncludingDisabled(player, "ControlsComponent")
  if not c then return end
  ComponentSetValue2(c, "mButtonDownFire", false)
  ComponentSetValue2(c, "mButtonDownFire2", false)
  ComponentSetValue2(c, "mButtonDownChangeItemR", false)
  ComponentSetValue2(c, "mButtonDownChangeItemL", false)
end

function interacting(entity_who_interacted, entity_interacted, interactable_name)
  if entity_who_interacted == nil or entity_who_interacted == 0 then return end
  release_item_controls(entity_who_interacted)
  local gui = EntityGetFirstComponentIncludingDisabled(entity_who_interacted, "InventoryGuiComponent")
  if gui then EntitySetComponentIsEnabled(entity_who_interacted, gui, true) end
  GlobalsSetValue("TOTG_TRIAL_state", "outside")
  GlobalsSetValue("TOTG_TRIAL_start_request", "")
  GlobalsSetValue("TOTG_TRIAL_wand_index", "1")
  GlobalsSetValue("TOTG_TRIAL_phase", "spawn")
  GlobalsSetValue("TOTG_TRIAL_active_wand", "0")
  GlobalsSetValue("TOTG_TRIAL_last_fired_wand", "0")
  GlobalsSetValue("TOTG_ARENA_ENTER_REQUEST", "")
  for _,e in ipairs(EntityGetWithTag("totg_trial_temp_wand") or {}) do EntityKill(e) end
  for _,e in ipairs(EntityGetWithTag("totg_trial_effect") or {}) do if EntityGetIsAlive(e) then EntityKill(e) end end
  for _,e in ipairs(EntityGetWithTag("totg_arena_carver") or {}) do if EntityGetIsAlive(e) then EntityKill(e) end end
  for _,e in ipairs(EntityGetWithTag("totg_portal_particle") or {}) do if EntityGetIsAlive(e) then EntityKill(e) end end

  local sx = tonumber(GlobalsGetValue("TOTG_START_RETURN_X", "0")) or 0
  local sy = tonumber(GlobalsGetValue("TOTG_START_RETURN_Y", "0")) or 0
  if sx == 0 and sy == 0 then
    GamePrintImportant("TRIAL OF THE GODS", "Start return position unavailable")
    return
  end
  EntitySetTransform(entity_who_interacted, sx, sy)
  GamePrintImportant("TRIAL OF THE GODS", "Returned to mines - Trial reset on next entry - quit game and relaunch if spells are active")
end
