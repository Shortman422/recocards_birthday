local e = GetUpdatedEntityID()
local x, y = EntityGetTransform(e)
local vx_comp, vy_comp, life_comp, age_comp, max_alpha_comp
for _, c in ipairs(EntityGetComponentIncludingDisabled(e, "VariableStorageComponent") or {}) do
  local name = ComponentGetValue2(c, "name")
  if name == "vx" then
    vx_comp = c
  elseif name == "vy" then
    vy_comp = c
  elseif name == "life" then
    life_comp = c
  elseif name == "age" then
    age_comp = c
  elseif name == "max_alpha" then
    max_alpha_comp = c
  end
end
if (not vx_comp) or (not vy_comp) or (not life_comp) or (not age_comp) then EntityKill(e); return end
local vx = ComponentGetValue2(vx_comp, "value_float")
local vy = ComponentGetValue2(vy_comp, "value_float")
local life = ComponentGetValue2(life_comp, "value_int")
local max_alpha = max_alpha_comp and ComponentGetValue2(max_alpha_comp, "value_float") or 0.28
local age = ComponentGetValue2(age_comp, "value_int")
local step = tonumber(ComponentGetValue2(GetUpdatedComponentID(), "execute_every_n_frame")) or 1
for _ = 1, step do
  age = age + 1
  if age >= life then EntityKill(e); return end
  x = x + vx
  y = y + vy
  vx = vx * 0.9995
  vy = vy * 0.9992 - 0.00008
end
ComponentSetValue2(age_comp, "value_int", age)
ComponentSetValue2(vx_comp, "value_float", vx)
ComponentSetValue2(vy_comp, "value_float", vy)
EntitySetTransform(e, x, y)
local s = EntityGetFirstComponentIncludingDisabled(e, "SpriteComponent")
if s then
  local fade_in = math.min(1.0, age / 8.0)
  local fade_out = math.max(0.0, 1.0 - age / life)
  ComponentSetValue2(s, "alpha", fade_in * max_alpha * fade_out)
end
