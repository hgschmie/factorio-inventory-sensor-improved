--------------------------------------------------------------------------------
-- Support for moving inventory sensors through
-- Even Pickier Dollies (https://mods.factorio.com/mod/even-pickier-dollies)
--------------------------------------------------------------------------------

local const = require('lib.constants')

local PickerDolliesSupport = {}

--------------------------------------------------------------------------------

local function picker_dollies_moved(event)
    if not (event.moved_entity and event.moved_entity.valid) then return end
    if event.moved_entity.name ~= const.inventory_sensor_name then return end

    This.SensorController:move(event.moved_entity.unit_number)
end

--------------------------------------------------------------------------------

PickerDolliesSupport.runtime = function()
    local Event = require('stdlib.event.event')

    local picker_dollies_init = function()
        if not remote.interfaces['PickerDollies'] then return end

        if remote.interfaces['PickerDollies']['dolly_moved_entity_id'] then
            Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)
        end
    end

    Event.on_init(picker_dollies_init)
    Event.on_load(picker_dollies_init)
end

return PickerDolliesSupport
