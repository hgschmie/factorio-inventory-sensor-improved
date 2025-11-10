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
    if not (entity and entity.valid) then return false end
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
    if not (entity and entity.valid and entity.train) then return false end
    return valid_train_states[entity.train.state] and true or false
end

---@type table<string, inventory_sensor.Contributor>
local contributors = {
    [const.inventory_names.grid] = function(sensor_data, sink)
        if not sensor_data.config.read_grid then return end
        if not (sensor_data.scan_entity and sensor_data.scan_entity.valid and sensor_data.scan_entity.grid) then return end

        local grid_equipment = sensor_data.scan_entity.grid.equipment
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

    [const.inventory_names.crafting_progress] = function(sensor_data, sink)
        if not (sensor_data.scan_entity and sensor_data.scan_entity.valid) then return end
        local progress = sensor_data.scan_entity.crafting_progress
        if progress then
            sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
        end
    end,

    [const.inventory_names.research_progress] = function(sensor_data, sink)
        if not (sensor_data.scan_entity and sensor_data.scan_entity.valid) then return end
        local progress = sensor_data.scan_entity.force.research_progress
        if progress then
            sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
        end
    end,

    [const.inventory_names.charge] = function(sensor_data, sink)
        local entity = sensor_data.scan_entity
        if not (entity and entity.valid) then return end
        sink { value = const.signals.charge_signal, min = math.floor(entity.energy / entity.electric_buffer_size * 100) }
    end,

    [const.inventory_names.silo_progress] = function(sensor_data, sink)
        local entity = sensor_data.scan_entity
        if not (entity and entity.valid) then return end

        local progress = math.ceil((entity.rocket_parts * 100) / entity.prototype.rocket_parts_required)
        local rocket_present = entity.rocket

        if progress == 0 and rocket_present then
            -- old sensor reported 100 when a rocket is fully built
            progress = 100
            rocket_present = nil
        end

        sink { value = const.signals.progress_signal, min = progress }
        sink { value = const.signals.rocket_ready_signal, min = rocket_present and 1 or 0 }
    end,
}

for name in pairs(defines.inventory) do
    contributors[name] = function(sensor_data, sink)
        -- TODO - read an inventory into sink
    end
end

------------------------------------------------------------------------
-- Defined entity types
------------------------------------------------------------------------

---@type table<string, inventory_sensor.ScanTemplate>
local ENTITY_TYPES = {

    stationary_type = {
        interval = scan_frequency.stationary,
        inventories = {
            fuel = const.inventory_names.fuel,
            burnt_result = const.inventory_names.burnt_result,
        },
    },

    container_type = {
        interval = scan_frequency.stationary,
        inventories = {
            chest = const.inventory_names.contents,
        },
        primary = defines.inventory.chest,
    },
    logistics_container_type = {
        interval = scan_frequency.stationary,
        inventories = {
            chest = const.inventory_names.contents,
            logistic_container_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.chest,
    },
    car_type = {
        interval = scan_frequency.mobile,
        inventories = {
            car_trunk = const.inventory_names.contents,
            car_ammo = const.inventory_names.ammo,
            car_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.car_trunk,
        validate = is_stopped,
        contributors = {
            [const.inventory_names.grid] = false, -- must be explicitly enabled
        },
    },
    locomotive_type = {
        interval = scan_frequency.mobile,
        inventories = {
            fuel = const.inventory_names.fuel,
            burnt_result = const.inventory_names.burnt_result,
        },
        primary = defines.inventory.fuel,
        validate = is_train_stopped,
    },
    cargo_wagon_type = {
        interval = scan_frequency.mobile,
        inventories = {
            cargo_wagon = const.inventory_names.cargo,
        },
        primary = defines.inventory.cargo_wagon,
        validate = is_train_stopped,
    },
    artillery_wagon_type = {
        interval = scan_frequency.mobile,
        inventories = {
            artillery_wagon_ammo = const.inventory_names.ammo,
        },
        primary = defines.inventory.artillery_wagon_ammo,
        validate = is_train_stopped,
    },
    assembler_type = {
        interval = scan_frequency.stationary,
        inventories = {
            crafter_input = const.inventory_names.input,
            crafter_output = const.inventory_names.output,
            crafter_modules = const.inventory_names.modules,
            crafter_trash = const.inventory_names.trash,
            assembling_machine_dump = const.inventory_names.dump,
        },
        primary = defines.inventory.crafter_output,
        contributors = {
            [const.inventory_names.crafting_progress] = true,
        },
    },
    lab_type = {
        interval = scan_frequency.stationary,
        inventories = {
            lab_input = const.inventory_names.lab_input,
            lab_modules = const.inventory_names.modules,
            lab_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.lab_input,
        contributors = {
            [const.inventory_names.research_progress] = true,
        },
    },
    reactory_type = {
        interval = scan_frequency.stationary,
        inventories = {
            fuel = const.inventory_names.fuel,
            burnt_result = const.inventory_names.burnt_result,
        },
        primary = defines.inventory.fuel,
    },
    roboport_type = {
        interval = scan_frequency.stationary,
        inventories = {
            roboport_robot = const.inventory_names.roboport_robot,
            roboport_material = const.inventory_names.roboport_material,
        },
        primary = defines.inventory.roboport_robot,
    },
    rocketsilo_type = {
        interval = scan_frequency.stationary,
        inventories = {
            crafter_input = const.inventory_names.input,
            crafter_output = const.inventory_names.output,
            crafter_modules = const.inventory_names.modules,
            crafter_trash = const.inventory_names.trash,
            rocket_silo_rocket = const.inventory_names.rocket_silo_rocket,
            rocket_silo_trash = const.inventory_names.rocket_silotrash,
        },
        primary = defines.inventory.rocket_silo_rocket,
        contributors = {
            [const.inventory_names.silo_progress] = true,
        },
    },
    turret_type = {
        interval = scan_frequency.stationary,
        inventories = {
            turret_ammo = const.inventory_names.ammo,
        },
        primary = defines.inventory.turret_ammo,
    },
    accumulator_type = {
        interval = scan_frequency.stationary,
        contributors = {
            [const.inventory_names.charge] = true,
        },
    }
}

------------------------------------------------------------------------

---@param template inventory_sensor.ScanTemplate
---@param fields table<string, any>?
---@return inventory_sensor.ScanTemplate
local function create_entity(template, fields)
    local entity = util.copy(template)
    if fields then
        for key, values in pairs(fields) do
            entity[key] = entity[key] or {}
            if values[1] then
                entity[key] = table.array_combine(entity[key], values)
            else
                for k, v in pairs(values) do
                    entity[key][k] = v
                end
            end
        end
    end
    return entity
end


---@type table<string, inventory_sensor.ScanTemplate|table<string, inventory_sensor.ScanTemplate>>
local supported_entities = {
    -- container-ish
    container = create_entity(ENTITY_TYPES.container_type),
    ['logistic-container'] = create_entity(ENTITY_TYPES.logistics_container_type),
    ['linked-container'] = create_entity(ENTITY_TYPES.container_type),
    ['infinity-container'] = create_entity(ENTITY_TYPES.logistics_container_type),
    ['storage-tank'] = create_entity(ENTITY_TYPES.container_type),

    -- mobile units
    car = {
        car = create_entity(ENTITY_TYPES.car_type, { signals = { 'car_detected_signal' } }),
        tank = create_entity(ENTITY_TYPES.car_type, { signals = { 'tank_detected_signal' } }),
    },

    ['spider-vehicle'] = create_entity(ENTITY_TYPES.car_type, { signals = { 'spider_detected_signal' } }),

    ['assembling-machine'] = create_entity(ENTITY_TYPES.assembler_type),
    furnace = create_entity(ENTITY_TYPES.assembler_type),

    lab = create_entity(ENTITY_TYPES.lab_type),

    reactor = create_entity(ENTITY_TYPES.stationary_type),
    generator = create_entity(ENTITY_TYPES.stationary_type),
    boiler = create_entity(ENTITY_TYPES.stationary_type),

    roboport = create_entity(ENTITY_TYPES.roboport_type),

    ['rocket-silo'] = create_entity(ENTITY_TYPES.rocketsilo_type),

    locomotive = create_entity(ENTITY_TYPES.locomotive_type, { signals = { 'locomotive_detected_signal' } }),
    ['cargo-wagon'] = create_entity(ENTITY_TYPES.cargo_wagon_type, { signals = { 'wagon_detected_signal' } }),
    ['fluid-wagon'] = create_entity(ENTITY_TYPES.cargo_wagon_type, { signals = { 'wagon_detected_signal' } }),
    ['artillery-wagon'] = create_entity(ENTITY_TYPES.artillery_wagon_type, { signals = { 'wagon_detected_signal' } }),

    ['artillery-turret'] = create_entity(ENTITY_TYPES.turret_type),

    ['cargo-landing-pad'] = create_entity(ENTITY_TYPES.logistics_container_type),

    ['accumulator'] = create_entity(ENTITY_TYPES.accumulator_type),
}

------------------------------------------------------------------------

---@type table<string, string>
local blacklisted_entities = table.array_to_dictionary {
}

---@type table<string, table<string, inventory_sensor.ScanTemplate>>
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

---@type inventory_sensor.SupportedEntities
local sensor_entities = {
    supported_entities = supported_entity_map,
    contributors = contributors,
    blacklist = blacklisted_entities
}

return sensor_entities
