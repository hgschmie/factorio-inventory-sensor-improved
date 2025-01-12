---@meta
------------------------------------------------------------------------
-- Supported entities / blacklist
------------------------------------------------------------------------
assert(script)

local util = require('util')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

------------------------------------------------------------------------
-- helper functions
------------------------------------------------------------------------

---@param entity LuaEntity This must be an entity because we may test during sensor creation
---@return boolean
local function is_stopped(entity)
    if not not (entity and entity.valid) then return false end
    return entity.speed == 0 -- entity must be standing still
end

local valid_train_states = table.array_to_dictionary({
    defines.train_state.wait_signal,
    defines.train_state.wait_station,
    defines.train_state.manual_control,
}, true)

---@param entity LuaEntity This must be an entity because we may test during sensor creation
---@return boolean
local function is_train_stopped(entity)
    if not (not (entity and entity.valid) and entity.train) then return false end
    return valid_train_states[entity.train.state] and true or false
end

---@param is_data inventory_sensor.Data
---@param sink fun(filter: LogisticFilter)
local function read_grid(is_data, sink)
    if not is_data.config.read_grid then return end
    if not (is_data.scan_entity and is_data.scan_entity.valid and is_data.scan_entity.grid) then return end

    local grid_equipment = is_data.scan_entity.grid.equipment
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
end

---@param is_data inventory_sensor.Data
---@param sink fun(filter: LogisticFilter)
local function read_crafting_progress(is_data, sink)
    if not (is_data.scan_entity and is_data.scan_entity.valid) then return end
    local progress = is_data.scan_entity.crafting_progress
    if progress then
        sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
    end
end

---@param is_data inventory_sensor.Data
---@param sink fun(filter: LogisticFilter)
local function read_research_progress(is_data, sink)
    if not (is_data.scan_entity and is_data.scan_entity.valid) then return end
    local progress = is_data.scan_entity.force.research_progress
    if progress then
        sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
    end
end

---@param is_data inventory_sensor.Data
---@param sink fun(filter: LogisticFilter)
local function read_charge(is_data, sink)
    local entity = is_data.scan_entity
    if not not (entity and entity.valid) then return end
    assert(entity)
    sink { value = const.signals.charge_signal, min = math.floor(entity.energy / entity.electric_buffer_size * 100) }
end


------------------------------------------------------------------------
-- Defined entity types
------------------------------------------------------------------------

-- simplest, stationary entity
local stationary_type = {
    interval = scan_frequency.stationary,
}

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
    },
    validate = is_stopped,
    contribute = read_grid,
}

local train_type = {
    interval = scan_frequency.mobile,
    inventories = {
        defines.inventory.cargo_wagon,
        defines.inventory.artillery_wagon_ammo,
    },
    validate = is_train_stopped,
}

local assembler_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.assembling_machine_input,
        defines.inventory.assembling_machine_output,
        defines.inventory.furnace_source,
        defines.inventory.furnace_result,
    },
    contribute = read_crafting_progress,
}

local lab_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.lab_input,
    },
    contribute = read_research_progress,
}

local reactory_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.burnt_result,
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

local turret_type = {
    interval = scan_frequency.stationary,
    inventories = {
        defines.inventory.turret_ammo,
    },
}

local accumulator_type = {
    interval = scan_frequency.stationary,
    contribute = read_charge,
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

    ['spider-vehicle'] = util.copy(car_type),

    ['assembling-machine'] = util.copy(assembler_type),
    furnace = util.copy(assembler_type),

    lab = util.copy(lab_type),

    reactor = util.copy(reactory_type),
    generator = util.copy(stationary_type),
    boiler = util.copy(stationary_type),

    roboport = util.copy(roboport_type),

    ['rocket-silo'] = util.copy(rocketsilo_type),

    locomotive = util.copy(train_type),
    ['cargo-wagon'] = util.copy(train_type),
    ['fluid-wagon'] = util.copy(train_type),
    ['artillery-wagon'] = util.copy(train_type),

    ['artillery-turret'] = util.copy(turret_type),

    ['cargo-landing-pad'] = util.copy(container_type),

    ['accumulator'] = util.copy(accumulator_type),
}

-- patching up
supported_entities.car.car.signals = {
    car_detected_signal = 1
}

supported_entities.car.tank.signals = {
    tank_detected_signal = 1
}

supported_entities['spider-vehicle'].signals = {
    spider_detected_signal = 1
}

supported_entities.locomotive.signals = {
    locomotive_detected_signal = 1
}

supported_entities['cargo-wagon'].signals = {
    wagon_detected_signal = 1
}

supported_entities['fluid-wagon'].signals = {
    wagon_detected_signal = 1
}

supported_entities['artillery-wagon'].signals = {
    wagon_detected_signal = 1
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
