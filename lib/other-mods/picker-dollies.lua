--------------------------------------------------------------------------------
-- Even Pickier Dollies (https://mods.factorio.com/mod/even-pickier-dollies)
-- and Picker Dollies (https://mods.factorio.com/mod/PickerDollies) support
--------------------------------------------------------------------------------

local const = require('lib.constants')
local Is = require('stdlib.utils.is')

local PickerDolliesSupport = {}

--------------------------------------------------------------------------------

local function picker_dollies_moved(event)
    if not Is.Valid(event.moved_entity) then return end
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
