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

local assembler_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.assembling_machine_input,  -- same as defines.inventory.furnace_source,
        defines.inventory.assembling_machine_output, -- same as defines.inventory.furnace_result,
        defines.inventory.fuel,
    },
    contribute = function(is_entity, sink)
        if not Is.Valid(is_entity.scan_entity) then return end
        local progress = is_entity.scan_entity.crafting_progress
        if progress then
            sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
        end
    end
}

local lab_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.lab_input,
    },
    contribute = function(is_entity, sink)
        if not Is.Valid(is_entity.scan_entity) then return end
        local progress = is_entity.scan_entity.force.research_progress
        if progress then
            sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
        end
    end
}

local reactor_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.fuel,
    },
}

local roboport_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.roboport_robot,
        defines.inventory.roboport_material,
    },
}

local rocketsilo_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.rocket_silo_input,
        defines.inventory.rocket_silo_output,
        defines.inventory.rocket_silo_rocket,
    },
}

------------------------------------------------------------------------

---@type table<string, ISDataController|table<string, ISDataController>>
local supported_entities = {
    -- container-ish
    container = util.copy(container_type),
    ['logistic-container'] = util.copy(container_type),
    ['linked-container'] = util.copy(container_type),
    ['infinity-container'] = util.copy(container_type),
    ['storage-tank'] = util.copy(container_type),

    -- mobile units
    car = {
        car = util.copy(car_type),
        tank = util.copy(car_type),
    },

    ['assembling-machine'] = util.copy(assembler_type),
    furnace = util.copy(assembler_type),

    lab = util.copy(lab_type),

    reactor = util.copy(reactor_type),
    generator = util.copy(reactor_type),
    boiler = util.copy(reactor_type),

    roboport = util.copy(roboport_type),

    ['rocket-silo'] = util.copy(rocketsilo_type),

    
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
