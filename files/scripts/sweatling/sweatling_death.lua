-- script_death handler for the recocards sweatling. Noita calls the function
-- named `death(...)` in this script's lua state when the entity dies (NOT
-- top-level code). On death we read the recocard id/author carried by the
-- entity and hand off to the recocards discovery API to grant the birthday
-- card. On a successful (first-time) grant we load the NEGATIVE/angry
-- (spark_red) dnkMM_56_angry image-emitter at the death position: reaching this
-- path means the sweatling was killed by DAMAGE (an "angry" outcome). The
-- friendly PICK-UP path (sweatling_interact.lua) grants the same card but emits
-- the positive/blue dnkMM_56 instead. (The old hearts FX was removed once the
-- emitters provided the feedback.)
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

function death(damage_type_bit_field,damage_message,entity_thats_responsible,drop_items)
    local entity = GetUpdatedEntityID()

    if
        entity == nil or
        entity == 0 or
        not EntityGetIsAlive(entity)
    then
        return
    end

    -- Quest-reset guard: reset clears found-flags and then EntityKills the
    -- spirits. EntityKill is not expected to fire script_death, but if it ever
    -- did, this death() would run against just-cleared flags and FALSELY grant
    -- the card. reset_persistent_birthday_progress sets this run flag around
    -- its EntityKill loop, so we bail out and never grant during a reset.
    if GameHasFlagRun("recocards_birthday_resetting") then return end

    local id = get_string_var(entity,"recocard_id")
    local author =
        get_string_var(entity,"recocard_author") or "Birthday Spirit"

    -- Guard against a missing id: no grant, no FX, no crash.
    if id == nil or id == "" then return end

    local x,y = EntityGetTransform(entity)

    -- RQ_DiscoverBirthdayCard has the single-grant guard internally and returns
    -- true only on the first successful discovery of this card.
    if RQ_DiscoverBirthdayCard(id,author,"kill") then
        EntityLoad(
            "mods/recocards_birthday/particles/image_emitters/dnkAngry_28.xml",
            x,
            y
        )
    end
end
