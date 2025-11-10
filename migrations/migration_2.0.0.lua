-----------------------------------------------------------------------
-- Fix the entity status to match the 2.0.0 model
-----------------------------------------------------------------------

local Sensor = require('scripts.sensor')

require('lib.this')

for _, sensor_data in pairs(This.SensorController:entities()) do
    sensor_data.state = sensor_data.state or {
        status = sensor_data.config.status,
        contributors = {},
        reset_on_connect = false,
    }
    sensor_data.config.status = nil
    sensor_data.config.contributors = {}
    sensor_data.inventories = nil

    Sensor.disconnect(sensor_data)
end
