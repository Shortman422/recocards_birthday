local entity = GetUpdatedEntityID()
local component = GetUpdatedComponentID()
local x, y = EntityGetTransform(entity)

local function storage(name)
  for _, c in ipairs(EntityGetComponentIncludingDisabled(entity, "VariableStorageComponent") or {}) do
    if ComponentGetValue2(c, "name") == name then return c end
  end
  return nil
end

local started_component = storage("totg_activation_frame")
local started = started_component and ComponentGetValue2(started_component, "value_int") or GameGetFrameNum()
local age = GameGetFrameNum() - started
local previous_component = storage("totg_previous_portal")
local previous_portal = previous_component and ComponentGetValue2(previous_component, "value_int") or 0

local particles_spawned = storage("totg_activation_particles_spawned")
if not particles_spawned then
  particles_spawned = EntityAddComponent2(entity, "VariableStorageComponent", {
    name = "totg_activation_particles_spawned",
    value_bool = true,
  })
  SetRandomSeed(x + GameGetFrameNum(), y - GameGetFrameNum())
  for i = 1, 84 do
    local angle = Randomf(-3.14159, 3.14159)
    local radius = Randomf(4, 22)
    local p = EntityCreateNew("totg_portal_activation_particle")
    EntitySetTransform(p, x + math.cos(angle) * radius, y - 2 + math.sin(angle) * radius * 1.45)
    EntityAddTag(p, "totg_portal_particle")
    EntityAddComponent2(p, "SpriteComponent", {
      image_file = "mods/recocards_birthday/files/trial_of_the_gods/files/graphics/particle_purple.png",
      offset_x = 2,
      offset_y = 2,
      emissive = true,
      alpha = 0.38,
      update_transform = true,
      z_index = 5.2,
    })
    EntityAddComponent2(p, "VariableStorageComponent", { name = "vx", value_float = math.cos(angle) * Randomf(0.12, 0.42) })
    EntityAddComponent2(p, "VariableStorageComponent", { name = "vy", value_float = math.sin(angle) * Randomf(0.12, 0.42) - Randomf(0.02, 0.12) })
    EntityAddComponent2(p, "VariableStorageComponent", { name = "life", value_int = Random(42, 78) })
    EntityAddComponent2(p, "VariableStorageComponent", { name = "age", value_int = 0 })
    EntityAddComponent2(p, "VariableStorageComponent", { name = "max_alpha", value_float = 0.38 })
    EntityAddComponent2(p, "LuaComponent", {
      script_source_file = "mods/recocards_birthday/files/trial_of_the_gods/files/portal/portal_particle_update.lua",
      execute_every_n_frame = 1,
      remove_after_executed = false,
    })
  end
end

local sprite = EntityGetFirstComponentIncludingDisabled(entity, "SpriteComponent", "totg_portal_visual")
if sprite then
  local t = math.min(1, math.max(0, age / 18))
  ComponentSetValue2(sprite, "alpha", t * t * (3 - 2 * t))
end

if age >= 18 then
  if sprite then ComponentSetValue2(sprite, "alpha", 1) end
  if previous_portal ~= 0 and EntityGetIsAlive(previous_portal) then EntityKill(previous_portal) end
  local interactable = EntityGetFirstComponentIncludingDisabled(entity, "InteractableComponent")
  if interactable then EntitySetComponentIsEnabled(entity, interactable, true) end
  if started_component then EntityRemoveComponent(entity, started_component) end
  if previous_component then EntityRemoveComponent(entity, previous_component) end
  if particles_spawned then EntityRemoveComponent(entity, particles_spawned) end
  EntityRemoveComponent(entity, component)
end
