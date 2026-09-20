local MOD = "mods/recocards_birthday/files/trial_of_the_gods/"

local function is_sampo(entity)
  if entity == nil or entity == 0 or not EntityGetIsAlive(entity) then return false end
  if EntityHasTag(entity, "this_is_sampo") or EntityHasTag(entity, "sampo") then return true end

  local filename = string.lower(EntityGetFilename(entity) or "")
  if filename == "data/entities/animals/boss_centipede/sampo.xml" then return true end
  if string.match(filename, "/sampo%.xml$") then return true end

  local name = string.lower(EntityGetName(entity) or "")
  return name == "sampo" or name == "$item_sampo" or string.find(name, "sampo", 1, true) ~= nil
end

local function inventory_contains_sampo(player)
  local function visit(parent)
    for _, child in ipairs(EntityGetAllChildren(parent) or {}) do
      if is_sampo(child) or visit(child) then return true end
    end
    return false
  end
  return visit(player)
end

local function begin_reveal(portal, previous_portal)
  local sprite = EntityGetFirstComponentIncludingDisabled(portal, "SpriteComponent", "totg_portal_visual")
  if sprite then ComponentSetValue2(sprite, "alpha", 0) end

  local interactable = EntityGetFirstComponentIncludingDisabled(portal, "InteractableComponent")
  if interactable then EntitySetComponentIsEnabled(portal, interactable, false) end

  local previous_interactable = EntityGetFirstComponentIncludingDisabled(previous_portal, "InteractableComponent")
  if previous_interactable then EntitySetComponentIsEnabled(previous_portal, previous_interactable, false) end

  EntityAddComponent2(portal, "VariableStorageComponent", {
    name = "totg_activation_frame",
    value_int = GameGetFrameNum(),
  })
  EntityAddComponent2(portal, "VariableStorageComponent", {
    name = "totg_previous_portal",
    value_int = previous_portal,
  })
  EntityAddComponent2(portal, "LuaComponent", {
    script_source_file = MOD .. "files/portal/portal_activation_reveal.lua",
    execute_every_n_frame = 1,
    remove_after_executed = false,
  })
end

function interacting(entity_who_interacted, entity_interacted, interactable_name)
  if entity_who_interacted == nil or entity_who_interacted == 0 then return end

  local require_sampo = ModSettingGet("recocards_birthday.trial_of_the_gods_require_sampo")
  if require_sampo == nil then require_sampo = true end
  if require_sampo and not inventory_contains_sampo(entity_who_interacted) then return end

  if GameHasFlagRun("totg_start_portal_activated") then return end

  local x, y = EntityGetTransform(entity_interacted)
  local portal = EntityLoad(MOD .. "files/portal/start_portal.xml", x, y)
  if portal == nil or portal == 0 then return end

  GameAddFlagRun("totg_start_portal_activated")
  begin_reveal(portal, entity_interacted)
end
