---@meta
------------------------------------------------------------------------
-- Inventory Sensor main code
------------------------------------------------------------------------
assert(script)

local Is = require('stdlib.utils.is')

local const = require('lib.constants')

local Sensor = require('scripts.sensor')

------------------------------------------------------------------------

---@class InventorySensorController
local InventorySensorController = {}

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global inventory sensor data structure.
function InventorySensorController:init()
    storage.is_data = storage.is_data or {
        is = {},
        count = 0,
        VERSION = const.current_version,
    } --[[@as inventory_sensor.Storage ]]
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
---@return inventory_sensor.Data[] entities
function InventorySensorController:entities()
    return storage.is_data.is
end

--- Returns data for a given inventory sensor
---@param entity_id integer main unit number (== entity id)
---@return inventory_sensor.Data? entity
function InventorySensorController:entity(entity_id)
    return storage.is_data.is[entity_id]
end

--- Sets or clears a inventory sensor entity
---@param entity_id integer The unit_number of the primary
---@param is_data inventory_sensor.Data?
function InventorySensorController:setEntity(entity_id, is_data)
    assert((is_data ~= nil and storage.is_data.is[entity_id] == nil)
        or (is_data == nil and storage.is_data.is[entity_id] ~= nil))

    if (is_data) then
        assert(Sensor.validate(is_data, entity_id))
    end

    storage.is_data.is[entity_id] = is_data
    storage.is_data.count = storage.is_data.count + ((is_data and 1) or -1)

    if storage.is_data.count < 0 then
        storage.is_data.count = table_size(storage.is_data.is)
        Framework.logger:logf('Inventory Sensor count got negative (bug), size is now: %d', storage.is_data.count)
    end
end

------------------------------------------------------------------------
-- creation
------------------------------------------------------------------------

---@param main_entity LuaEntity
---@param config inventory_sensor.Config?
function InventorySensorController:create(main_entity, config)
    main_entity.rotatable = true

    local is_data = Sensor.new(main_entity, config)
    self:setEntity(main_entity.unit_number, is_data)

    -- initial scan when created
    Sensor.scan(is_data)
end

------------------------------------------------------------------------
-- deletion
------------------------------------------------------------------------

--@param unit_number integer
function InventorySensorController:destroy(unit_number)
    local is_data = self:entity(unit_number)
    if not is_data then return end

    Sensor.destroy(is_data)
    self:setEntity(unit_number, nil)
end

------------------------------------------------------------------------
-- rotate / move
------------------------------------------------------------------------

--@param unit_number integer
function InventorySensorController:move(unit_number)
    local is_data = self:entity(unit_number)
    if not is_data then return end

    Sensor.scan(is_data, true)
end

--------------------------------------------------------------------------------
-- serialization for Blueprinting and Tombstones
--------------------------------------------------------------------------------

---@param entity LuaEntity
---@return table<string, any>?
function InventorySensorController.serialize_config(entity)
    if not Is.Valid(entity) then return end

    local is_data = This.SensorController:entity(entity.unit_number)
    if not is_data then return end

    return {
        [const.config_tag_name] = is_data.config,
    }
end

----------------------------------------------------------------------------------------------------

return InventorySensorController
