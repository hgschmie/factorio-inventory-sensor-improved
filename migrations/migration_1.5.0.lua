--
-- add new "inventory_status" boolean config value

local This = require('lib.this')

---@type inventory_sensor.Storage
local data = This:storage()

for _, entity in pairs(data.is) do
    entity.config.inventory_status = entity.config.inventory_status or false
end
