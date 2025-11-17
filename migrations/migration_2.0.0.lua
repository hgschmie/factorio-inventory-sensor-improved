-----------------------------------------------------------------------
-- Fix the entity status to match the 2.0.0 model
-----------------------------------------------------------------------

local const = require('lib.constants')
local Sensor = require('scripts.sensor')

require('lib.this')

for _, sensor_data in pairs(This.SensorController:entities()) do
    sensor_data.state = sensor_data.state or {
        status = sensor_data.config.status,
        contributors = {},
        reset_on_connect = false,
    }

    sensor_data.config.contributors = {}

    ---@diagnostic disable-next-line:undefined-field
    if sensor_data.config.read_grid then
        sensor_data.config.contributors[const.inventory_name.grid] = sensor_data.config.contributors[const.inventory_name.grid] or {
            name = assert(const.inventories[const.inventory_name.grid]),
            enabled = true,
            mode = 'quantity',
            inverted = false,
        }
    end

    ---@diagnostic disable-next-line:inject-field
    sensor_data.config.read_grid = nil
    ---@diagnostic disable-next-line:inject-field
    sensor_data.config.status = nil
    ---@diagnostic disable-next-line:inject-field
    sensor_data.inventories = nil

    Sensor.disconnect(sensor_data)
end
