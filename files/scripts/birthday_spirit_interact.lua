dofile_once("mods/recocards_birthday/files/scripts/util.lua")
dofile_once("mods/recocards_birthday/files/scripts/birthday_card_discovery.lua")

local function get_string_var(entity,name)
    local vars =
        EntityGetComponent(
            entity,
            "VariableStorageComponent"
        ) or {}

    for _,component in ipairs(vars) do
        if ComponentGetValue2(component,"name") == name then
            return ComponentGetValue2(component,"value_string")
        end
    end

    return nil
end

local function spawn_hearts(x,y)
    for i=1,5 do
        local h =
            EntityLoad(
                "mods/recocards_birthday/files/entities/birthday_heart_fx.xml",
                x + (i-3)*3,
                y - 6 - math.abs(i-3)
            )

        if h ~= nil and h ~= 0 then
            local v =
                EntityGetFirstComponentIncludingDisabled(
                    h,
                    "VelocityComponent"
                )

            if v ~= nil then
                ComponentSetValue2(
                    v,
                    "mVelocity",
                    (i-3)*5,
                    -12-math.abs(i-3)*2
                )
            end
        end
    end
end

function interacting(entity_who_interacted,entity_interacted,interactable_name)
    if
        entity_interacted == nil or
        entity_interacted == 0 or
        not EntityGetIsAlive(entity_interacted)
    then
        return
    end

    local id =
        get_string_var(
            entity_interacted,
            "recocard_id"
        )

    local author =
        get_string_var(
            entity_interacted,
            "recocard_author"
        ) or "Birthday Spirit"

    if id == nil or id == "" then return end

    local x,y = EntityGetTransform(entity_interacted)

    if RQ_DiscoverBirthdayCard(id,author,"pickup") then
        spawn_hearts(x,y)
    end

    EntityKill(entity_interacted)
end
