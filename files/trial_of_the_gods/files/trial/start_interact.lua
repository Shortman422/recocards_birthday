function interacting(entity_who_interacted, entity_interacted, interactable_name)
  if GlobalsGetValue("TOTG_TRIAL_state", "idle") ~= "idle" then return end
  GlobalsSetValue("TOTG_TRIAL_start_request", tostring(GameGetFrameNum()))
end
