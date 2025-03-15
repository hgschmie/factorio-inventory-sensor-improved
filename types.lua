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
---@field interval scan_frequency
---@field inventories defines.inventory[]
---@field validate (fun(entity: inventory_sensor.Data): boolean)?
---@field contribute (fun(is_data: inventory_sensor.Data, sink: fun(filter: LogisticFilter)))?
---@field signals table<string, integer>?

---@class inventory_sensor.Config
---@field enabled boolean
---@field status defines.entity_status
---@field scan_entity_id integer?
---@field read_grid boolean

---@class inventory_sensor.Data
---@field sensor_entity LuaEntity
---@field inventories table<defines.inventory, true>
---@field config inventory_sensor.Config
---@field scan_area BoundingBox?
---@field scan_entity LuaEntity?
---@field scan_interval integer?
---@field scan_time integer?
---@field load_time integer?

----------------------------------------------------------------------------------------------------
-- controller.lua
----------------------------------------------------------------------------------------------------

---@class inventory_sensor.Storage
---@field is inventory_sensor.Data[]
---@field count integer
---@field VERSION integer

----------------------------------------------------------------------------------------------------
-- supported_entities.lua
----------------------------------------------------------------------------------------------------
---@class ISSupportedEntities
---@field supported_entities table<string, ISDataController>
---@field blacklist table<string, string>
