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
    defines.train_state.manual_control_stop,
}, true)

---@param entity LuaEntity This must be an entity because we may test during sensor creation
---@return boolean
local function is_train_stopped(entity)
    if not (entity and entity.valid and entity.train) then return false end
    return (valid_train_states[entity.train.state] and entity.speed == 0) and true or false
end

---@param amount number
---@param contributor_info inventory_sensor.ContributorInfo?
---@return integer result
local function compute_amount(amount, contributor_info)
    if contributor_info then
        local quantity = contributor_info.mode == 'quantity' or false
        local inverted = contributor_info.inverted and true or false
        amount = (quantity and amount or 1) * (inverted and -1 or 1)
    end

    return math.floor(amount + .5)
end

---@type table<string, fun(contributor: inventory_sensor.ContributorTemplate)>
local contributors = {
    [const.inventory_names.grid] = function(contributor)
        local scan_entity = contributor.scan_entity
        if not scan_entity.grid then return end

        local grid_equipment = scan_entity.grid.equipment
        local items = {}
        for _, equipment in pairs(grid_equipment) do
            local name = equipment.prototype.take_result.name
            items[name] = items[name] or {}
            items[name][equipment.quality.name] = (items[name][equipment.quality.name] or 0) + 1
        end
        for name, q in pairs(items) do
            for quality, count in pairs(q) do
                contributor.sink { value = { type = 'item', name = name, quality = quality, }, min = count }
            end
        end
    end,

    [const.inventory_names.fluid] = function(contributor)
        local scan_entity = contributor.scan_entity

        local contributor_info = assert(contributor.contributor_info)

        for i = 1, scan_entity.fluids_count, 1 do
            local fluid = scan_entity.get_fluid(i)

            local amount = compute_amount(fluid and fluid.amount or 0, contributor_info)

            local inventory_status = {}
            inventory_status.availableFluidsCount = (amount ~= 0) and 1 or 0
            inventory_status.totalFluidAmount = amount

            if #scan_entity.fluidbox >= i then
                -- entity with fluid boxes (e.g. a chemical plant)
                local capacity = scan_entity.fluidbox.get_capacity(i)
                inventory_status.totalFluidsCount = (capacity > 0) and 1 or 0
                inventory_status.totalFluidCapacity = capacity
                inventory_status.emptyFluidsCount = inventory_status.totalFluidsCount - inventory_status.availableFluidsCount
            else
                -- entity with "just fluid", e.g. a fluid wagon
                -- this assumes that for non-fluid box entities, there is only one
                -- fluid available
                local entity_capacity = scan_entity.prototype.get_fluid_capacity(scan_entity.quality)
                if entity_capacity > 0 then
                    inventory_status.totalFluidsCount = 1
                    inventory_status.totalFluidCapacity = entity_capacity
                    inventory_status.emptyFluidsCount = inventory_status.totalFluidsCount - inventory_status.availableFluidsCount
                end
            end

            contributor.status_sink(inventory_status)

            if fluid then
                contributor.sink { value = { type = 'fluid', name = fluid.name, quality = 'normal' }, min = amount }
            end
        end
    end,

    [const.inventory_names.crafting_progress] = function(contributor)
        local scan_entity = contributor.scan_entity

        local progress = scan_entity.crafting_progress
        if progress then
            contributor.sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
        end
    end,

    [const.inventory_names.research_progress] = function(contributor)
        local scan_entity = contributor.scan_entity

        local progress = scan_entity.force.research_progress
        if progress then
            contributor.sink { value = const.signals.progress_signal, min = math.floor(progress * 100) }
        end
    end,

    [const.inventory_names.charge] = function(contributor)
        local scan_entity = contributor.scan_entity

        contributor.sink { value = const.signals.charge_signal, min = math.floor(scan_entity.energy / scan_entity.electric_buffer_size * 100) }
    end,

    [const.inventory_names.silo_progress] = function(contributor)
        local scan_entity = contributor.scan_entity

        local progress = math.floor(.5 + (scan_entity.rocket_parts * 100) / scan_entity.prototype.rocket_parts_required)
        local rocket_present = scan_entity.rocket

        if progress == 0 and rocket_present then
            -- old sensor reported 100 when a rocket is fully built
            progress = 100
            rocket_present = nil
        end

        contributor.sink { value = const.signals.progress_signal, min = progress }
        contributor.sink { value = const.signals.rocket_ready_signal, min = rocket_present and 1 or 0 }
    end,

    [const.inventory_names.temperature] = function(contributor)
        local scan_entity = contributor.scan_entity

        local temperature = scan_entity.temperature
        if not temperature then return end

        contributor.sink { value = const.signals.temperature_signal, min = math.floor(.5 + temperature) }
    end,

    [const.inventory_names.burner_fuel] = function(contributor)
        local scan_entity = contributor.scan_entity
        if not scan_entity.burner then return end

        local remaining_fuel = 0
        local fuel_inventory = scan_entity.get_inventory(defines.inventory.fuel)
        if fuel_inventory and fuel_inventory.valid then
            for _, item in pairs(fuel_inventory.get_contents()) do
                local fuel = prototypes.item[item.name]
                if fuel and fuel.fuel_value then
                    remaining_fuel = remaining_fuel + math.max((fuel.fuel_value / 1e6) * item.count, 0)
                end
            end
        end

        if scan_entity.burner.remaining_burning_fuel > 0 then
            remaining_fuel = remaining_fuel + scan_entity.burner.remaining_burning_fuel / 1e6 -- Joule -> MJ
        end

        contributor.sink { value = const.signals.fuel_signal, min = math.min(math.floor(remaining_fuel + 0.5), 2 ^ 31 - 1) }
    end,

    [const.inventory_names.pump_speed] = function(contributor)
        local scan_entity = contributor.scan_entity

        local pump_speed = scan_entity.pumped_last_tick

        contributor.sink { value = const.signals.speed_signal, min = pump_speed }
    end,


}

for name, index in pairs(defines.inventory) do
    contributors[name] = function(contributor)
        local scan_entity = contributor.scan_entity

        local contributor_info = assert(contributor.contributor_info)

        local inventory = scan_entity.get_inventory(index)
        if not (inventory and inventory.valid and #inventory > 0) then return end

        ---@type inventory_sensor.InventoryStatus
        local inventory_status = {
            totalItemCount = 0,
            totalSlotCount = #inventory,
            emptySlotCount = inventory.count_empty_stacks(),
        }

        inventory_status.filledSlotCount = inventory_status.totalSlotCount - inventory_status.emptySlotCount
        inventory_status.filteredSlotCount = inventory.count_empty_stacks(true) - inventory_status.emptySlotCount

        if inventory.supports_bar() then
            inventory_status.blockedSlotIndex = (inventory.get_bar() < inventory_status.totalSlotCount) and inventory.get_bar() or 0
        end

        for _, item in pairs(inventory.get_contents()) do
            if item.count > 0 then
                local amount = compute_amount(item.count, contributor_info)
                contributor.sink { value = { name = item.name, type = 'item', quality = item.quality or 'normal' }, min = amount }
                inventory_status.totalItemCount = inventory_status.totalItemCount + amount -- accumulate the amount of all items
            end
        end

        contributor.status_sink(inventory_status)
    end
end

------------------------------------------------------------------------
-- Defined entity types
------------------------------------------------------------------------

local GLOBAL_CONTRIBUTORS = {
    const.inventory_names.temperature,
    const.inventory_names.burner_fuel,
}

---@type table<string, inventory_sensor.ScanTemplate>
local ENTITY_TYPES = {

    stationary_type = {
        interval = const.scan_frequency.stationary,
    },

    container_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            chest = const.inventory_names.contents,
        },
        primary = defines.inventory.chest,
    },

    logistics_container_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            chest = const.inventory_names.contents,
            logistic_container_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.chest,
    },

    car_type = {
        interval = const.scan_frequency.mobile,
        inventories = {
            car_trunk = const.inventory_names.trunk,
            car_ammo = const.inventory_names.ammo,
            car_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.car_trunk,
        validate = is_stopped,
    },

    locomotive_type = {
        interval = const.scan_frequency.mobile,
        validate = is_train_stopped,
    },

    cargo_wagon_type = {
        interval = const.scan_frequency.mobile,
        inventories = {
            cargo_wagon = const.inventory_names.cargo,
        },
        primary = defines.inventory.cargo_wagon,
        validate = is_train_stopped,
    },

    artillery_wagon_type = {
        interval = const.scan_frequency.mobile,
        inventories = {
            artillery_wagon_ammo = const.inventory_names.ammo,
        },
        primary = defines.inventory.artillery_wagon_ammo,
        validate = is_train_stopped,
    },

    assembler_type = {
        interval = const.scan_frequency.stationary,
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
        interval = const.scan_frequency.stationary,
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

    roboport_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            roboport_robot = const.inventory_names.roboport_robot,
            roboport_material = const.inventory_names.roboport_material,
        },
        primary = defines.inventory.roboport_robot,
    },

    rocketsilo_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            crafter_input = const.inventory_names.input,
            crafter_output = const.inventory_names.output,
            crafter_modules = const.inventory_names.modules,
            crafter_trash = const.inventory_names.trash,
            rocket_silo_rocket = const.inventory_names.rocket_silo_rocket,
            rocket_silo_trash = const.inventory_names.rocket_silo_trash,
        },
        primary = defines.inventory.rocket_silo_rocket,
        contributors = {
            [const.inventory_names.silo_progress] = true,
        },
    },

    turret_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            turret_ammo = const.inventory_names.ammo,
        },
        primary = defines.inventory.turret_ammo,
    },

    accumulator_type = {
        interval = const.scan_frequency.stationary,
        contributors = {
            [const.inventory_names.charge] = true,
        },
    },

    pump_type = {
        interval = const.scan_frequency.stationary,
        contributors = {
            [const.inventory_names.pump_speed] = true,
        },
    },

    asteroid_collector_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            asteroid_collector_output = const.inventory_names.output,
            asteroid_collector_arm = const.inventory_names.arm,
        },
        primary = defines.inventory.asteroid_collector_output,
    },

    space_platform_hub_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            hub_main = const.inventory_names.contents,
            hub_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.hub_main,
    },

    cargo_bay_type = {
        interval = const.scan_frequency.stationary,
        inventories = {
            hub_main = const.inventory_names.contents,
            hub_trash = const.inventory_names.trash,
        },
        primary = defines.inventory.hub_main,
        delegate = function(entity)
            if not (entity and entity.valid) then return nil end
            return entity.cargo_bay_connection_owner
        end,
    },
}

for _, entity_type in pairs(ENTITY_TYPES) do
    entity_type.supported = {}
    entity_type.inventories = entity_type.inventories or {}
    for key in pairs(entity_type.inventories) do
        entity_type.supported[defines.inventory[key]] = key
    end
end

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
    ['electric-energy-interface'] = create_entity(ENTITY_TYPES.accumulator_type),

    ['heat-pipe'] = create_entity(ENTITY_TYPES.stationary_type),
    ['heat-interface'] = create_entity(ENTITY_TYPES.stationary_type),

    ['pump'] = create_entity(ENTITY_TYPES.pump_type),
    ['offshore-pump'] = create_entity(ENTITY_TYPES.pump_type),

    ['asteroid-collector'] = create_entity(ENTITY_TYPES.asteroid_collector_type),
    ['space-platform-hub'] = create_entity(ENTITY_TYPES.space_platform_hub_type),
    ['cargo-bay'] = create_entity(ENTITY_TYPES.cargo_bay_type),
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
    blacklist = blacklisted_entities,
    global_contributors = GLOBAL_CONTRIBUTORS,
}

return sensor_entities
