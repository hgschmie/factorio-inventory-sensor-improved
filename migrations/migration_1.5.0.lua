--
-- add new "inventory_status" boolean config value

---@type inventory_sensor.Storage
local data = storage.is_data

for _, entity in pairs(data.is) do
    entity.config.inventory_status = entity.config.inventory_status or false
end
