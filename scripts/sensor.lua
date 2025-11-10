------------------------------------------------------------------------
-- Inventory Sensor Data Management
------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')

local Area = require('stdlib.area.area')
local Direction = require('stdlib.area.direction')
local Position = require('stdlib.area.position')
local table = require('stdlib.utils.table')

---@type inventory_sensor.SupportedEntities
local sensor_entities = require('scripts.supported-entities')

------------------------------------------------------------------------

---@class inventory_sensor.Sensor
---@field scan_offset number
---@field scan_range number
local InventorySensor = {
    scan_offset = Framework.settings:startup_setting(const.settings_scan_offset_name),
    scan_range = Framework.settings:startup_setting(const.settings_scan_range_name),
}

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

---@param entity LuaEntity?
---@return inventory_sensor.ScanTemplate?
local function locate_scan_template(entity)
    if not (entity and entity.valid) then return nil end
    assert(entity)

    ---@type inventory_sensor.ScanTemplate?
    local scan_template = sensor_entities.supported_entities[entity.type] and
        (sensor_entities.supported_entities[entity.type][entity.name] or sensor_entities.supported_entities[entity.type]['*'])

    if not scan_template then return nil end

    -- if there is a validate function, it must pass
    if scan_template.validate and not scan_template.validate(entity) then return nil end

    return scan_template
end

--------------------------------------------------------------------------------
-- configure
--------------------------------------------------------------------------------

---@param entity LuaEntity?
---@return string?
local function get_entity_key(entity)
    if not (entity and entity.valid) then return nil end

    return entity.type .. '__' .. entity.name
end

---@param index defines.inventory
---@return inventory_sensor.Contributor
local function create_inventory_contributor(index)
    return function(sensor_data, sink)
    end
end

---@param sensor_data inventory_sensor.Data
---@param scan_template inventory_sensor.ScanTemplate
function InventorySensor.update_supported(sensor_data, scan_template)
    if not (sensor_data.scan_entity and sensor_data.scan_entity.valid) then return end

    -- turn everything off first, enable default contributors
    sensor_data.state.contributors = {}
    sensor_data.config.contributors = {}

    if scan_template.contributors then
        for name, enabled in pairs(scan_template.contributors) do
            assert(sensor_entities.contributors[name])

            ---@type inventory_sensor.ContributorInfo
            local contributor_info = {
                name = assert(const.inventories[name]),
                enabled = enabled,
            }
            sensor_data.state.contributors[name] = contributor_info
            if not enabled then
                -- not enabled -> needs to be a config item from the GUI
                sensor_data.config.contributors[name] = {
                    name = assert(const.inventories[name]),
                    enabled = enabled,
                    mode = 'one',
                    inverted = false,
                }
            end
        end
    end

    -- update the available inventories
    if scan_template.inventories then
        local inventory_map = {}
        for key in pairs(scan_template.inventories) do
            inventory_map[defines.inventory[key]] = key
        end

        for i = 1, sensor_data.scan_entity.get_max_inventory_index() do
            local name = inventory_map[i]
            if name then
                -- check that the entity actually has the inventory
                local inventory = sensor_data.scan_entity.get_inventory(i --[[@as defines.inventory]])
                if inventory then
                    assert(sensor_entities.contributors[name])

                    local name_key = assert(scan_template.inventories[name])

                    sensor_data.state.contributors[name] = {
                        name = assert(const.inventories[name_key]),
                        enabled = false,
                    }

                    sensor_data.config.contributors[name] = {
                        name = assert(const.inventories[name_key]),
                        enabled = (i == scan_template.primary),
                        mode = 'one',
                        inverted = false,
                    }
                end
            end
        end
    end

    if not scan_template.primary and table_size(sensor_data.config.contributors) == 1 then
        local _, contributor_info = next(sensor_data.config.contributors)
        contributor_info.enabled = true
    end

    sensor_data.state.reset_on_connect = true
    sensor_data.state.reconnect_key = get_entity_key(sensor_data.scan_entity)
end

---@param sensor_data inventory_sensor.Data
---@param config inventory_sensor.Config?
function InventorySensor.reconfigure(sensor_data, config)
    if not config then return end

    sensor_data.config.enabled = config.enabled
    sensor_data.config.read_grid = config.read_grid
    sensor_data.config.inventory_status = config.inventory_status
    sensor_data.config.contributors = util.copy(config.contributors)
end

----------------------------------------------------------------------------------------------------
-- create/destroy
----------------------------------------------------------------------------------------------------

--
-- inventory sensor states
--
-- "create" -> creates entity
-- "scan" -> look for entities to connect to.
-- "connect" -> choose an entity, serve its inventory
-- "disconnect" -> either through entity deleted, sensor or entity moved out of range
--

---@param sensor_entity LuaEntity
---@param config inventory_sensor.Config?
---@return inventory_sensor.Data
function InventorySensor.new(sensor_entity, config)
    ---@type inventory_sensor.Data
    local data = {
        sensor_entity = sensor_entity,
        inventories = {},
        config = {
            enabled = true,
            read_grid = false,
            inventory_status = false,
            contributors = {},
        },
        state = {
            status = sensor_entity.status,
            -- if a config was provided, do not reset state at next connect
            -- this allows blueprints to work
            reset_on_connect = not config,
            contributors = {},
        },
    }

    if config then InventorySensor.reconfigure(data, config) end

    return data
end

---@param sensor_data inventory_sensor.Data
function InventorySensor.destroy(sensor_data)
    if not sensor_data then return end
    sensor_data.sensor_entity = nil -- don't destroy; lifecycle is managed by the game and destroying prevents ghosts from showing
end

---@param sensor_data inventory_sensor.Data
---@param unit_number integer
function InventorySensor.validate(sensor_data, unit_number)
    return sensor_data.sensor_entity and sensor_data.sensor_entity.valid and sensor_data.sensor_entity.unit_number == unit_number
end

----------------------------------------------------------------------------------------------------
-- scan
----------------------------------------------------------------------------------------------------

---@param entity LuaEntity
---@return boolean
local function sensor_horizontal(entity)
    return entity.direction == defines.direction.west or entity.direction == defines.direction.east
end

---@param sensor_data inventory_sensor.Data
---@return BoundingBox scan_area
function InventorySensor.create_scan_area(sensor_data)
    assert(sensor_data.sensor_entity)

    local entity = sensor_data.sensor_entity
    local position = Position(entity.position)
    local area = Area.new {
        position + { -0.5, -InventorySensor.scan_offset },
        position + { 0.5, InventorySensor.scan_offset }
    }
    area = sensor_horizontal(entity) and area or area:flip()
    area = area:translate(Direction.opposite(entity.direction), InventorySensor.scan_range - 0.5)

    return area
end

---@param sensor_data inventory_sensor.Data
---@param force boolean?
---@return boolean scanned True if scan happened
function InventorySensor.scan(sensor_data, force)
    if sensor_data.config.enabled then
        local interval = sensor_data.scan_interval or Framework.settings:runtime_setting(const.settings_find_entity_interval_name)

        local scan_time = sensor_data.scan_time or 0
        if not (force or (game.tick - scan_time >= interval)) then return false end

        sensor_data.scan_time = game.tick

        -- if force is set, always create the scan area, otherwise, if a scan area
        -- already exists, use that
        sensor_data.scan_area = (not force) and sensor_data.scan_area or InventorySensor.create_scan_area(sensor_data)

        if Framework.settings:startup_setting('debug_mode') then
            rendering.draw_rectangle {
                color = { r = 0.5, g = 0.5, b = 1 },
                surface = sensor_data.sensor_entity.surface,
                left_top = sensor_data.scan_area.left_top,
                right_bottom = sensor_data.scan_area.right_bottom,
                time_to_live = 10,
            }
        end

        local entities = sensor_data.sensor_entity.surface.find_entities(sensor_data.scan_area)

        for _, entity in pairs(entities) do
            if InventorySensor.connect(sensor_data, entity) then return true end
        end
    end

    -- not connected
    InventorySensor.disconnect(sensor_data)

    return true
end

----------------------------------------------------------------------------------------------------
-- load/clear
----------------------------------------------------------------------------------------------------

---@param sensor_data inventory_sensor.Data
---@return LuaLogisticSection
function InventorySensor.get_section(sensor_data)
    -- empty the signals sections

    local control = assert(sensor_data.sensor_entity.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior ]]
    if control.sections_count == 0 then control.add_section() end

    return assert(control.get_section(1))
end

--- Loads the state of the connected entity into the sensor.
---@param sensor_data inventory_sensor.Data
---@param force boolean?
---@return boolean entity was loaded
function InventorySensor.load(sensor_data, force)
    local load_time = sensor_data.load_time or 0
    if not (force or (game.tick - load_time >= Framework.settings:runtime_setting(const.settings_update_interval_name))) then return false end
    sensor_data.load_time = game.tick

    local section = InventorySensor.get_section(sensor_data)
    section.filters = {}

    if not sensor_data.config.enabled then return false end
    local scan_entity = sensor_data.scan_entity
    if not (scan_entity and scan_entity.valid) then return false end

    local scan_template = locate_scan_template(scan_entity)
    if not scan_template then return false end

    ---@type table<string, number>
    local cache = {}

    ---@type LogisticFilter[]
    local filters = {}

    ---@type inventory_sensor.InventoryStatus
    local totalInventoryStatus = {
        blockedSlotIndex = 0,
        emptySlotCount = 0,
        filledSlotCount = 0,
        totalSlotCount = 0,
        usedSlotPercentage = 0,
        filteredSlotCount = 0,
        totalItemCount = 0,
        totalFluidsCount = 0,
        totalFluidAmount = 0,
        availableFluidsCount = 0,
        totalFluidCapacity = 0,
        usedFluidPercentage = 0,
        emptyFluidsCount = 0,
    }

    ---@type fun(filter: LogisticFilter)
    local sink = function(filter)
        if filter.min == 0 then return end

        local signal = assert(filter.value)
        local key = ('%s:%s:%s'):format(signal.name, signal.type or 'item', signal.quality or 'normal')
        local index = cache[key]
        if not index then
            table.insert(filters, filter)
            cache[key] = #filters
        else
            filters[index].min = filters[index].min + filter.min
        end
    end

    local burner = scan_entity.burner
    local remaining_fuel = 0

    -- load inventories for the entity
    -- if table_size(sensor_data.state.inventories) > 0 then
    --     for inventory_index in pairs(sensor_data.state.inventories) do
    --         local inventory = scan_entity.get_inventory(inventory_index)
    --         if inventory and inventory.valid then
    --             ---@type inventory_sensor.InventoryStatus
    --             local inventoryStatus = {
    --                 totalItemCount = 0,
    --             }

    --             if sensor_data.config.inventory_status then
    --                 inventoryStatus.totalSlotCount = #inventory
    --                 inventoryStatus.emptySlotCount = inventory.count_empty_stacks()
    --                 inventoryStatus.filledSlotCount = inventoryStatus.totalSlotCount - inventoryStatus.emptySlotCount
    --                 inventoryStatus.filteredSlotCount = inventory.count_empty_stacks(true) - inventoryStatus.emptySlotCount

    --                 if inventory.supports_bar() then
    --                     inventoryStatus.blockedSlotIndex = (inventory.get_bar() < inventoryStatus.totalSlotCount) and inventory.get_bar() or 0
    --                 end
    --             end

    --             for _, item in pairs(inventory.get_contents()) do
    --                 sink { value = { name = item.name, type = 'item', quality = item.quality or 'normal' }, min = item.count }

    --                 if sensor_data.config.inventory_status then
    --                     inventoryStatus.totalItemCount = inventoryStatus.totalItemCount + item.count -- accumulate the amount of all items
    --                 end

    --                 if burner and (inventory_index == defines.inventory.fuel) then
    --                     local fuel = prototypes.item[item.name]
    --                     if fuel and fuel.fuel_value then
    --                         remaining_fuel = remaining_fuel + math.max((fuel.fuel_value / 1e6) * item.count, 0)
    --                     end
    --                 end
    --             end

    --             for k, v in pairs(inventoryStatus) do
    --                 totalInventoryStatus[k] = totalInventoryStatus[k] + v
    --             end
    --         end
    --     end
    -- end

    -- get fluids
    for i = 1, scan_entity.fluids_count, 1 do
        local fluid = scan_entity.get_fluid(i)
        if sensor_data.config.inventory_status then
            ---@type inventory_sensor.InventoryStatus
            local fluidStatus = {}
            fluidStatus.availableFluidsCount = fluid and (fluid.amount > 0) and 1 or 0
            fluidStatus.totalFluidAmount = fluid and fluid.amount or 0
            local entity_capacity = scan_entity.prototype.get_fluid_capacity()
            if entity_capacity > 0 then
                fluidStatus.totalFluidsCount = 1
                fluidStatus.totalFluidCapacity = entity_capacity
                fluidStatus.emptyFluidsCount = fluidStatus.totalFluidsCount - fluidStatus.availableFluidsCount
            end

            if scan_entity.fluidbox and (#scan_entity.fluidbox >= i) then
                fluidStatus.totalFluidsCount = (scan_entity.fluidbox.get_capacity(i) > 0) and 1 or 0
                fluidStatus.totalFluidCapacity = scan_entity.fluidbox.get_capacity(i) or 0
                fluidStatus.emptyFluidsCount = fluidStatus.totalFluidsCount - fluidStatus.availableFluidsCount
            end

            for k, v in pairs(fluidStatus) do
                totalInventoryStatus[k] = totalInventoryStatus[k] + v
            end

            if fluid then
                sink { value = { type = 'fluid', name = fluid.name, quality = 'normal' }, min = math.ceil(fluid.amount) }
            end
        end
    end

    -- add virtual signals for inventory
    if sensor_data.config.inventory_status then
        if totalInventoryStatus.totalSlotCount ~= 0 then
            totalInventoryStatus.usedSlotPercentage = totalInventoryStatus.filledSlotCount * 100 / totalInventoryStatus.totalSlotCount
        end

        if totalInventoryStatus.totalFluidCapacity ~= 0 then
            totalInventoryStatus.usedFluidPercentage = totalInventoryStatus.totalFluidAmount * 100 / totalInventoryStatus.totalFluidCapacity
        end

        for signal_name, field_name in pairs(const.inventory_status_signals) do
            local value = totalInventoryStatus[field_name]
            if value ~= 0 then
                sink { value = { type = 'virtual', name = 'signal-' .. signal_name, quality = 'normal' }, min = value }
            end
        end
    end

    -- add specific static signals
    if scan_template.signals then
        for _, name in pairs(scan_template.signals) do
            assert(const.signals[name])
            sink { value = const.signals[name], min = 1 }
        end
    end

    -- add custom items
    for name, contributor_info in pairs(sensor_data.state.contributors) do
        if contributor_info.enabled or (sensor_data.config.contributors[name] and sensor_data.config.contributors[name].enabled) then
            local contributor = assert(sensor_entities.contributors[name])
            contributor(sensor_data, sink)
        end
    end

    local temperature = scan_entity.temperature
    if temperature then
        sink { value = const.signals.temperature_signal, min = temperature }
    end

    -- if this is a burner entity, add burner signal
    if burner then
        if burner.remaining_burning_fuel > 0 then
            remaining_fuel = remaining_fuel + burner.remaining_burning_fuel / 1e6 -- Joule -> MJ
        end
        sink { value = const.signals.fuel_signal, min = math.min(math.floor(remaining_fuel + 0.5), 2 ^ 31 - 1) }
    end

    if Framework.settings:startup_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 1, b = 0.3 },
            surface = sensor_data.sensor_entity.surface,
            left_top = sensor_data.sensor_entity.bounding_box.left_top,
            right_bottom = sensor_data.sensor_entity.bounding_box.right_bottom,
            time_to_live = 2,
        }
    end

    section.filters = filters

    return true
end

----------------------------------------------------------------------------------------------------
-- connect/disconnect
----------------------------------------------------------------------------------------------------

---@param sensor_data inventory_sensor.Data
---@param entity LuaEntity
---@return boolean connected
function InventorySensor.connect(sensor_data, entity)
    if not (entity and entity.valid) then return false end
    if sensor_entities.blacklist[entity.name] then return false end

    -- reconnect to the same entity
    if sensor_data.scan_entity and sensor_data.scan_entity.valid and sensor_data.scan_entity.unit_number == entity.unit_number then return true end

    local scan_controller = locate_scan_template(entity)
    if not scan_controller then return false end

    sensor_data.scan_entity = entity
    sensor_data.scan_interval = scan_controller.interval or scan_frequency.stationary -- unset scan interval -> stationary
    -- FIXME    sensor_data.inventories = table.array_to_dictionary(scan_controller.inventories or {}, true)
    sensor_data.config.scan_entity_id = entity.unit_number

    local entity_key = get_entity_key(entity)

    if sensor_data.state.reset_on_connect and not (sensor_data.state.reconnect_key and entity_key == sensor_data.state.reconnect_key) then
        -- FIXME        sensor_data.config.logistic_member_index = nil
    end

    sensor_data.state.reconnect_key = entity_key

    -- burners also look at fuel
    -- TODO if entity.burner then
    --     sensor_data.state.inventories[defines.inventory.fuel] = true
    -- end

    -- update the list of supported inventories for the entity.
    -- Not all entities support all possible inventories
    InventorySensor.update_supported(sensor_data, scan_controller)

    InventorySensor.load(sensor_data, true)

    if Framework.settings:startup_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 0.3, g = 1, b = 0.3 },
            surface = sensor_data.sensor_entity.surface,
            left_top = sensor_data.scan_area.left_top,
            right_bottom = sensor_data.scan_area.right_bottom,
            time_to_live = 10,
        }
    end

    return true
end

---@param sensor_data inventory_sensor.Data
function InventorySensor.disconnect(sensor_data)
    if not sensor_data.scan_entity then return end

    sensor_data.scan_entity = nil
    sensor_data.scan_interval = nil
    sensor_data.scan_time = nil
    sensor_data.load_time = nil

    sensor_data.state.status = nil
    sensor_data.state.contributors = {}

    sensor_data.config.scan_entity_id = nil
    sensor_data.config.contributors = {}

    local section = InventorySensor.get_section(sensor_data)
    section.filters = {}

    if Framework.settings:startup_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 0.3, b = 0.3 },
            surface = sensor_data.sensor_entity.surface,
            left_top = sensor_data.scan_area.left_top,
            right_bottom = sensor_data.scan_area.right_bottom,
            time_to_live = 10,
        }
    end
end

----------------------------------------------------------------------------------------------------
-- ticker
----------------------------------------------------------------------------------------------------

---@param sensor_data inventory_sensor.Data
---@return boolean if entity was either scanned or loaded
function InventorySensor.tick(sensor_data)
    if not (sensor_data.sensor_entity and sensor_data.sensor_entity.valid) then
        sensor_data.config.enabled = false
        sensor_data.state.status = defines.entity_status.marked_for_deconstruction
        return false
    else
        sensor_data.state.status = sensor_data.sensor_entity.status

        local scanned = InventorySensor.scan(sensor_data)
        local loaded = InventorySensor.load(sensor_data)
        return scanned or loaded
    end
end

----------------------------------------------------------------------------------------------------

return InventorySensor
