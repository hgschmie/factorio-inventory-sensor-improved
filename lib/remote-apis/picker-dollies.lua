--------------------------------------------------------------------------------
-- Support for moving inventory sensors through
-- Even Pickier Dollies (https://mods.factorio.com/mod/even-pickier-dollies)
--------------------------------------------------------------------------------

local Event = require('stdlib.event.event')

local const = require('lib.constants')

--------------------------------------------------------------------------------

local function picker_dollies_moved(event)
    if not (event.moved_entity and event.moved_entity.valid) then return end
    if event.moved_entity.name ~= const.inventory_sensor_name then return end

    This.SensorController:move(event.moved_entity.unit_number)
end

local function picker_dollies_init()
    if remote.interfaces['PickerDollies']['dolly_moved_entity_id'] then
        Event.on_event(remote.call('PickerDollies', 'dolly_moved_entity_id'), picker_dollies_moved)
    end
end


--------------------------------------------------------------------------------

local PickerDollies = {
    on_init = picker_dollies_init,
    on_load = picker_dollies_init,
}

return PickerDollies
