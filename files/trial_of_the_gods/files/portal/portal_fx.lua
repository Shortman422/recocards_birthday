local entity = GetUpdatedEntityID()

if GameEntityPlaySoundLoop then
  GameEntityPlaySoundLoop(entity, "totg_portal_sound", 1.0)
end

if GameGetFrameNum() % 2 ~= 0 then return end

local is_return = EntityHasTag(entity, "totg_return_portal")
local x, y = EntityGetTransform(entity)
local img = is_return and "mods/recocards_birthday/files/trial_of_the_gods/files/graphics/particle_blue.png" or "mods/recocards_birthday/files/trial_of_the_gods/files/graphics/particle_purple.png"

local function random_point_in_inner_ellipse(cx, cy)
  for i=1,20 do
    local ox = Randomf(-8.8, 8.8)
    local oy = Randomf(-15.8, 11.8)
    local nx = ox / 8.8
    local ny = oy / 14.8
    if (nx * nx + ny * ny) <= 1.0 then
      return cx + ox, cy + oy
    end
  end
  return cx, cy
end

local particle_center_y = is_return and (y + 6) or (y - 2)

for i=1,2 do
  local px, py = random_point_in_inner_ellipse(x, particle_center_y)
  local drift_angle = Randomf(-3.14159, 3.14159)
  local vx = math.cos(drift_angle) * Randomf(0.00015, 0.0035)
  local vy = -Randomf(0.0004, 0.0060) + math.sin(drift_angle) * 0.0015
  local p = EntityCreateNew("totg_portal_particle")
  EntitySetTransform(p, px, py)
  EntityAddTag(p, "totg_portal_particle")
  EntityAddComponent2(p, "SpriteComponent", {
    image_file = img,
    offset_x = 2,
    offset_y = 2,
    emissive = false,
    alpha = 0.28,
    update_transform = true,
    z_index = 5.1,
  })
  EntityAddComponent2(p, "VariableStorageComponent", { name = "vx", value_float = vx })
  EntityAddComponent2(p, "VariableStorageComponent", { name = "vy", value_float = vy })
  EntityAddComponent2(p, "VariableStorageComponent", { name = "life", value_int = Random(160, 260) })
  EntityAddComponent2(p, "VariableStorageComponent", { name = "age", value_int = 0 })
  EntityAddComponent2(p, "VariableStorageComponent", { name = "max_alpha", value_float = 0.28 })
  EntityAddComponent2(p, "LuaComponent", {
    script_source_file = "mods/recocards_birthday/files/trial_of_the_gods/files/portal/portal_particle_update.lua",
    execute_every_n_frame = 2,
    remove_after_executed = false,
  })
end
