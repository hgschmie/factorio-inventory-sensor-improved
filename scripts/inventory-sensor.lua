------------------------------------------------------------------------
-- Inventory Sensor main code
------------------------------------------------------------------------

local Is = require('stdlib.utils.is')
local table = require('stdlib.utils.table')
local tools = require('framework.tools')

local const = require('lib.constants')

---@class InventorySensor
local InvSensor = {}

------------------------------------------------------------------------

------------------------------------------------------------------------
-- init setup
------------------------------------------------------------------------

--- Setup the global fico data structure.
function InvSensor:init()
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
function InvSensor:totalCount()
    return storage.is_data.count
end

--- Returns data for all inventory sensors.
---@return InvSensorData[] entities
function InvSensor:entities()
    return storage.is_data.is
end

--- Returns data for a given inventory sensor
---@param entity_id integer main unit number (== entity id)
---@return InvSensorData? entity
function InvSensor:entity(entity_id)
    return storage.is_data.is[entity_id]
end

--- Sets or clears a inventory sensor entity
---@param entity_id integer The unit_number of the primary
---@param is_entity InvSensorData?
function InvSensor:setEntity(entity_id, is_entity)
    assert((is_entity ~= nil and storage.is_data.is[entity_id] == nil)
        or (is_entity == nil and storage.is_data.is[entity_id] ~= nil))

    if (is_entity) then
        assert(Is.Valid(is_entity.main) and is_entity.main.unit_number == entity_id)
    end

    storage.is_data.is[entity_id] = is_entity
    storage.is_data.count = storage.is_data.count + ((is_entity and 1) or -1)

    if storage.is_data.count < 0 then
        storage.is_data.count = table_size(storage.is_data.is)
        Framework.logger:logf('Inventory Sensor count got negative (bug), size is now: %d', storage.is_data.count)
    end
end

return InvSensor
