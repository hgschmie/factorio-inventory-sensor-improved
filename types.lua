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


---@class inventory_sensor.ContributorTemplate
---@field sensor_data inventory_sensor.Data
---@field scan_entity LuaEntity
---@field sink fun(filter: LogisticFilter)
---@field status_sink fun(inventory: inventory_sensor.InventoryStatus)
---@field contributor_info inventory_sensor.ContributorInfo?

---@alias inventory_sensor.TypeMode 'one'|'quantity'

---@class inventory_sensor.ContributorInfo
---@field enabled boolean?
---@field name LocalisedString
---@field mode inventory_sensor.TypeMode?
---@field inverted boolean?

---@class inventory_sensor.ScanTemplate
---@field interval inventory_sensor.scan_frequency Scan frequency
---@field validate (fun(entity: LuaEntity): boolean)? validation function, whether the given entity can be read
---@field inventories (table<defines.inventory, LocalisedString>)? Inventory to name
---@field supported (table<integer, defines.inventory>)? Supported inventories
---@field contributors (table<string, boolean>)? Additional contributors
---@field signals (string[])?
---@field primary defines.inventory? Primary Inventory, enable by default
---@field delegate (fun(delegate: LuaEntity?):LuaEntity?)? Allows a template to declare a delegate to scan

---@class inventory_sensor.Config
---@field enabled boolean
---@field scan_entity_id integer?
---@field contributors table<string, inventory_sensor.ContributorInfo> List of activated contributors in the GUI
---@field inventory_status boolean

---@class inventory_sensor.State
---@field status defines.entity_status
---@field contributors table<string, inventory_sensor.ContributorInfo> List of all available contributors. Updated when the entity changes
---@field reset_on_connect boolean
---@field reconnect_key string?

---@class inventory_sensor.Data
---@field sensor_entity LuaEntity
---@field config inventory_sensor.Config
---@field state inventory_sensor.State
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

----------------------------------------------------------------------------------------------------
-- supported_entities.lua
----------------------------------------------------------------------------------------------------
---@class inventory_sensor.SupportedEntities
---@field supported_entities table<string, table<string, inventory_sensor.ScanTemplate>>
---@field contributors table<string, inventory_sensor.Contributor>
---@field blacklist table<string, string>
---@field global_contributors string[]
