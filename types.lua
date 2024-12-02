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
---@field inventories defines.inventory[]

---@class InventorySensorData: InventorySensor
---@field sensor_entity LuaEntity
---@field tags Tags?
---@field debug boolean
---@field scan_area BoundingBox?
---@field scan_entity LuaEntity?
---@field scan_controller ISDataController?
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
