-- script_interacting handler for the recocards sweatling. Noita calls the
-- function named `interacting(...)` in this script's lua state when the player
-- interacts with the entity's InteractableComponent. This is the friendly
-- PICK-UP path (the intended "accept card" handoff): it grants the birthday
-- card, emits the POSITIVE/friendly (spark_blue via dnkMM_56.xml) emission, and
-- removes the sweatling.
--
-- Option B: BOTH pick-up and damage-death grant the same card. The only
-- difference is the emission (pick-up = friendly/blue here; damage-death =
-- angry/red in sweatling_death.lua). We emit + kill HERE because EntityKill does
-- NOT fire script_death, so this pick-up kill never runs the damage-death path
-- -- keeping the two emissions cleanly separated while both share the grant.
--
-- The grant + reset-guard logic mirrors sweatling_death.lua so the two paths
-- behave identically w.r.t. discovery and the quest-reset safety.
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

function interacting(entity_who_interacted,entity_interacted,interactable_name)
    if
        entity_interacted == nil or
        entity_interacted == 0 or
        not EntityGetIsAlive(entity_interacted)
    then
        return
    end

    -- Quest-reset guard: mirror sweatling_death.lua. reset clears found-flags
    -- and then removes the spirits; never grant during a reset.
    if GameHasFlagRun("recocards_birthday_resetting") then return end

    local id = get_string_var(entity_interacted,"recocard_id")
    local author =
        get_string_var(entity_interacted,"recocard_author") or "Birthday Spirit"

    -- Guard against a missing id: no grant, no FX, no kill (leave it be).
    if id == nil or id == "" then return end

    local x,y = EntityGetTransform(entity_interacted)

    -- RQ_DiscoverBirthdayCard has the single-grant guard internally and returns
    -- true only on the first successful discovery of this card. Emit the
    -- friendly/blue emission only on that first successful grant.
    if RQ_DiscoverBirthdayCard(id,author) then
        EntityLoad(
            "mods/recocards_birthday/particles/image_emitters/dnkLove_28.xml",
            x,
            y
        )
    end

    -- Remove the sweatling on pick-up regardless of first-vs-repeat grant, so a
    -- re-interacted (already-discovered) sweatling still gets picked up/cleared.
    EntityKill(entity_interacted)
end
