---@meta
----------------------------------------------------------------------------------------------------
-- class definitions
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- sensor.lua
----------------------------------------------------------------------------------------------------

---@class ISDataController
---@field interval scan_frequency,
---@field inventories defines.inventory[]?
---@field validate (fun(entity: LuaEntity): boolean)?
---@field signals table<string, integer>?

---@class InventorySensorConfig
---@field enabled boolean
---@field status defines.entity_status
---@field scan_entity_id integer?


---@class InventorySensorData: InventorySensor
---@field sensor_entity LuaEntity
---@field tags Tags?
---@field debug boolean
---@field config InventorySensorConfig
---@field scan_area BoundingBox?
---@field scan_entity LuaEntity?
---@field scan_interval integer?
---@field scan_time integer?
---@field load_time integer?

----------------------------------------------------------------------------------------------------
-- controller.lua
----------------------------------------------------------------------------------------------------

---@class InvSensorStorage
---@field is InventorySensorData[]
---@field count integer
---@field VERSION integer

----------------------------------------------------------------------------------------------------
-- supported_entities.lua
----------------------------------------------------------------------------------------------------
---@class ISSupportedEntities
---@field supported_entities table<string, ISDataController>
---@field blacklist table<string, string>
