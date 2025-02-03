------------------------------------------------------------------------
-- data phase 3
------------------------------------------------------------------------

require('lib.init')

local const = require('lib.constants')

if Framework.settings:startup_setting(const.settings_update_inventory_sensors_name) then
    for _, migration_name in pairs(const.migration_names) do
        local item_sensor = util.copy(data.raw['constant-combinator']['constant-combinator'])
        item_sensor.name = migration_name

        if not data.raw['constant-combinator'][migration_name] then
            data:extend { item_sensor }
        end
    end
end

Framework.post_data_final_fixes_stage()
