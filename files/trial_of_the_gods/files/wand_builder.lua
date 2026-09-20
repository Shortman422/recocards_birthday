local MOD = "mods/recocards_birthday/files/trial_of_the_gods/"
local M = {}

local function clear_cards(wand)
  for _, child in ipairs(EntityGetAllChildren(wand) or {}) do
    if EntityHasTag(child, "card_action") or EntityGetFirstComponentIncludingDisabled(child, "ItemActionComponent") then
      EntityKill(child)
    end
  end
end

local function strip_procedural_scripts(wand)
  for _, c in ipairs(EntityGetComponentIncludingDisabled(wand, "LuaComponent") or {}) do
    local src = ComponentGetValue2(c, "script_source_file") or ""
    if string.find(src, "data/scripts/gun/procedural/", 1, true) then
      EntityRemoveComponent(wand, c)
    end
  end
end

function M.create(n, x, y)
  local wand = EntityLoad("data/entities/items/wand_unshuffle_01.xml", x, y)
  if not wand or wand == 0 then return nil end
  strip_procedural_scripts(wand)
  clear_cards(wand)

  local ability = EntityGetFirstComponentIncludingDisabled(wand, "AbilityComponent")
  if not ability then EntityKill(wand); return nil end
  local actions = dofile_once(MOD .. "files/wands/wand_" .. tostring(n) .. "_actions.lua")

  ComponentSetValue2(ability, "mana", 1000000000)
  ComponentSetValue2(ability, "mana_max", 1000000000)
  ComponentSetValue2(ability, "mana_charge_speed", 1000000000)
  ComponentSetValue2(ability, "reload_time_frames", 0)
  ComponentSetValue2(ability, "never_reload", false)
  ComponentObjectSetValue2(ability, "gun_config", "deck_capacity", #actions)
  ComponentObjectSetValue2(ability, "gun_config", "actions_per_round", 1)
  ComponentObjectSetValue2(ability, "gun_config", "reload_time", 0)
  ComponentObjectSetValue2(ability, "gun_config", "shuffle_deck_when_empty", false)
  ComponentObjectSetValue2(ability, "gunaction_config", "fire_rate_wait", 0)
  ComponentObjectSetValue2(ability, "gunaction_config", "spread_degrees", 0)

  local made = 0
  for i, id in ipairs(actions) do
    local card = CreateItemActionEntity(id, x, y)
    if card and card ~= 0 then
      local item = EntityGetFirstComponentIncludingDisabled(card, "ItemComponent")
      if item then
        ComponentSetValue2(item, "inventory_slot", i - 1, 0)
        ComponentSetValue2(item, "is_frozen", true)
        ComponentSetValue2(item, "permanently_attached", false)
      end
      EntityAddChild(wand, card)
      made = made + 1
    else
      GamePrint("TOTG W" .. n .. " INVALID ACTION slot " .. i .. ": " .. tostring(id))
    end
  end

  if made ~= #actions then
    EntityKill(wand)
    return nil
  end

  return wand
end

return M
