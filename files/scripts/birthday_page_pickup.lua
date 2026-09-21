dofile_once("mods/recocards_birthday/files/scripts/util.lua")
dofile_once("mods/recocards_birthday/files/scripts/birthday_card_discovery.lua")

local function get_string_var(entity,name)
    local vars =
        EntityGetComponent(
            entity,
            "VariableStorageComponent"
        ) or {}

    for _,c in ipairs(vars) do
        if ComponentGetValue2(c,"name") == name then
            return ComponentGetValue2(c,"value_string")
        end
    end

    return nil
end

function item_pickup(entity_item, entity_who_picked, item_name)
    local id =
        get_string_var(
            entity_item,
            "recocard_id"
        )

    local author =
        get_string_var(
            entity_item,
            "recocard_author"
        ) or "Birthday Spirit"

    if id ~= nil and id ~= "" then
        RQ_DiscoverBirthdayCard(id,author,"pickup")
    end

    EntityKill(entity_item)
end
