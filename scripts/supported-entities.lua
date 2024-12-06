---@meta
------------------------------------------------------------------------
-- Supported entities / blacklist
------------------------------------------------------------------------

-- importing globals
local const = require('lib.constants')

local util = require('util')
local table = require('stdlib.utils.table')
local Is = require('stdlib.utils.is')

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
        defines.inventory.car_ammo,
        defines.inventory.fuel,
    },
    validate = function(entity)
        return entity and (entity.speed == 0) -- entity must be standing still
    end,
    contribute = function(is_entity, sink)
        if not Framework.settings:runtime_setting(const.settings_read_equipment_grid_name) then return end
        if not (Is.Valid(is_entity.scan_entity) and is_entity.scan_entity.grid) then return end

        local grid_equipment = is_entity.scan_entity.grid.equipment
        local items = {}
        for _, equipment in pairs(grid_equipment) do
            local name = equipment.prototype.take_result.name
            items[name] = items[name] or {}
            items[name][equipment.quality.name] = (items[name][equipment.quality.name] or 0) + 1
        end
        for name, q in pairs(items) do
            for quality, count in pairs(q) do
                sink { value = { type = 'item', name = name, quality = quality, }, min = count }
            end
        end
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
    car_detected_signal = 1
}
supported_entities.car.tank.signals = {
    tank_detected_signal = 1
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
