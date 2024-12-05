---@meta
------------------------------------------------------------------------
-- Inventory Sensor main code
------------------------------------------------------------------------

local const = require('lib.constants')

local Sensor = require('scripts.sensor')

------------------------------------------------------------------------

---@class InventorySensorController
local InventorySensorController = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global fico data structure.
function InventorySensorController:init()
    storage.is_data = storage.is_data or {
        is = {},
        count = 0,
        VERSION = const.current_version,
    } --[[@as InvSensorStorage ]]
end

------------------------------------------------------------------------
-- attribute getters/setters
------------------------------------------------------------------------

--- Returns the registered total count.
---@return integer count The total count of inventory sensors
function InventorySensorController:totalCount()
    return storage.is_data.count
end

--- Returns data for all inventory sensors.
---@return InventorySensorData[] entities
function InventorySensorController:entities()
    local result = {}
    for index, entity in pairs(storage.is_data.is) do
        Sensor.enhance(entity)
        result[index] = entity
    end

    return result
end

--- Returns data for a given inventory sensor
---@param entity_id integer main unit number (== entity id)
---@return InventorySensorData? entity
function InventorySensorController:entity(entity_id)
    local result = storage.is_data.is[entity_id]
    Sensor.enhance(result)
    return result
end

--- Sets or clears a inventory sensor entity
---@param entity_id integer The unit_number of the primary
---@param is_entity InventorySensorData?
function InventorySensorController:setEntity(entity_id, is_entity)
    assert((is_entity ~= nil and storage.is_data.is[entity_id] == nil)
        or (is_entity == nil and storage.is_data.is[entity_id] ~= nil))

    if (is_entity) then
        assert(is_entity:validate(entity_id))
    end

    storage.is_data.is[entity_id] = is_entity
    storage.is_data.count = storage.is_data.count + ((is_entity and 1) or -1)

    if storage.is_data.count < 0 then
        storage.is_data.count = table_size(storage.is_data.is)
        Framework.logger:logf('Inventory Sensor count got negative (bug), size is now: %d', storage.is_data.count)
    end
end

------------------------------------------------------------------------
-- creation
------------------------------------------------------------------------

---@param main_entity LuaEntity
---@param tags Tags?
function InventorySensorController:create(main_entity, tags)
    main_entity.rotatable = true

    local sensor_entity = Sensor.new(main_entity, tags)
    self:setEntity(main_entity.unit_number, sensor_entity)

    -- initial scan when created
    sensor_entity:scan()
end

------------------------------------------------------------------------
-- deletion
------------------------------------------------------------------------

--@param unit_number integer
function InventorySensorController:destroy(unit_number)
    local is_data = self:entity(unit_number) --[[@as InventorySensorData ]]
    if not is_data then return end

    is_data:destroy()
    self:setEntity(unit_number, nil)
end

------------------------------------------------------------------------
-- rotate / move
------------------------------------------------------------------------

--@param unit_number integer
function InventorySensorController:move(unit_number)
    local is_data = self:entity(unit_number) --[[@as InventorySensorData ]]
    if not is_data then return end

    is_data:scan(true)
end

----------------------------------------------------------------------------------------------------

return InventorySensorController
