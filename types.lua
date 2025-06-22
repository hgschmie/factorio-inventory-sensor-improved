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
---@field inventory_status boolean

---@class inventory_sensor.Data
---@field sensor_entity LuaEntity
---@field inventories table<defines.inventory, true>
---@field config inventory_sensor.Config
---@field scan_area BoundingBox?
---@field scan_entity LuaEntity?
---@field scan_interval integer?
---@field scan_time integer?
---@field load_time integer?

---@class inventory_sensor.InventoryStatus
---@field blockedSlotIndex integer?     -- B
---@field emptySlotCount integer?       -- E
---@field filledSlotCount integer?      -- F
---@field totalSlotCount integer?       -- T
---@field usedSlotPercentage number?    -- P
---@field filteredSlotCount integer?    -- X
---@field totalItemCount integer?       -- I
---@field emptyFluidsCount integer?     -- D
---@field availableFluidsCount integer? -- A
---@field totalFluidsCount integer?     -- C
---@field totalFluidCapacity number?    -- V
---@field totalFluidAmount number?      -- L
---@field usedFluidPercentage number?   -- Q

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
