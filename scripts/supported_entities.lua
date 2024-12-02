---@meta
------------------------------------------------------------------------
-- Supported entities / blacklist
------------------------------------------------------------------------

-- importing globals
require('lib.constants')

local table = require('stdlib.utils.table')

-- generic container with single inventory
local container_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.chest,
    },
}

---@type table<string, ISDataController>
local supported_entities = {
    -- regular containers
    container = container_type,
    ['logistic-container'] = container_type,
    ['linked-container'] = container_type,
    ['infinity-container'] = container_type,
}

---@type table<string, string>
local blacklisted_entities = table.array_to_dictionary {
}

------------------------------------------------------------------------

return {
    supported_entities = supported_entities,
    blacklist = blacklisted_entities
}