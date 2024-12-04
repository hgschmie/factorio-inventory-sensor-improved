---@meta
------------------------------------------------------------------------
-- Supported entities / blacklist
------------------------------------------------------------------------

-- importing globals
local const = require('lib.constants')

local util = require('util')
local table = require('stdlib.utils.table')

------------------------------------------------------------------------
-- Defined entity types
------------------------------------------------------------------------

-- generic container with single inventory
local container_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.chest,
    },
}

local car_type = {
    interval = scan_frequency.mobile,
    inventories = {
        defines.inventory.car_trunk,
    },
    validate = function(entity)
        return entity and (entity.speed == 0) -- entity must be standing still
    end,
}

------------------------------------------------------------------------

---@type table<string, ISDataController|table<string, ISDataController>>
local supported_entities = {
    -- regular containers
    container = util.copy(container_type),
    ['logistic-container'] = util.copy(container_type),
    ['linked-container'] = util.copy(container_type),
    ['infinity-container'] = util.copy(container_type),
    -- mobile units
    car = {
        car = util.copy(car_type),
        tank = util.copy(car_type),
    },
}

-- patching up
supported_entities.car.car.signals = {
    [const.signal_names.car_detected_signal] = 1
}
supported_entities.car.tank.signals = {
    [const.signal_names.tank_detected_signal] = 1
}

------------------------------------------------------------------------

---@type table<string, string>
local blacklisted_entities = table.array_to_dictionary {
}

local supported_entity_map = {}

-- normalize map. For any type that has no sub-name, use '*' as a wild card
for type, map in pairs(supported_entities) do
    local type_map = {}

    if map.interval then
        type_map['*'] = map
    else
        for name, name_map in pairs(map) do
            type_map[name] = name_map
        end
    end

    supported_entity_map[type] = type_map
end

------------------------------------------------------------------------

return {
    supported_entities = supported_entity_map,
    blacklist = blacklisted_entities
}
