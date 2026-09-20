function wand_fired(gun_entity_id)
  if GlobalsGetValue("TOTG_TRIAL_state", "outside") ~= "running" then return end
  GlobalsSetValue("TOTG_TRIAL_last_fired_wand", tostring(gun_entity_id or 0))
end
