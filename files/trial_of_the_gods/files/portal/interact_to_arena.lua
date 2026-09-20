function interacting(entity_who_interacted, entity_interacted, interactable_name)
  if entity_who_interacted == nil or entity_who_interacted == 0 then return end
  if GlobalsGetValue("TOTG_ARENA_ENTER_REQUEST", "") ~= "" then return end
  GlobalsSetValue("TOTG_ARENA_ENTER_REQUEST", tostring(GameGetFrameNum()))
  if GlobalsGetValue("TOTG_ARENA_CLEARED", "0") ~= "1" then
    GamePrintImportant("TRIAL OF THE GODS", "Preparing area")
  end
end
