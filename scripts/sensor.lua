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

---@type table<defines.inventory, LocalisedString>
local BURNER_TYPE_INVENTORIES = {
    fuel = const.inventory_names.fuel,
    burnt_result = const.inventory_names.burnt_result,
}

---@type table<integer, defines.inventory>
local BURNER_TYPE_SUPPORTED = {
    [defines.inventory.fuel] = 'fuel',
    [defines.inventory.burnt_result] = 'burnt_result',
}

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

-- Create a set of contributors (in state) and a subset that is configurable (in config).
-- Reconnect with and existing config if the same type of entity was reconnected
---@param sensor_data inventory_sensor.Data
---@param scan_template inventory_sensor.ScanTemplate
function InventorySensor.update_supported(sensor_data, scan_template)
    local scan_entity = sensor_data.scan_entity
    -- some entities (e.g. cargo bay) delegate to a different entity
    local scan_delegate = scan_template.delegate and scan_template.delegate(scan_entity) or scan_entity

    if not (scan_delegate and scan_delegate.valid) then return end

    local configured_contributors = sensor_data.config.contributors or {}

    ---@param key string
    ---@param name string
    ---@param enabled boolean?
    local add_contributor = function(key, name, enabled)
        assert(sensor_entities.contributors[key])

        ---@type inventory_sensor.ContributorInfo
        sensor_data.state.contributors[key] = {
            name = assert(const.inventories[name]),
            enabled = enabled or false,
        }

        -- enabled means that this contributor is unconditionally enabled
        -- otherwise needs to be a config item from the GUI
        if enabled then return end

        local contributor_info = configured_contributors[key] or {
            name = assert(const.inventories[name]),
            enabled = enabled or false,
            mode = 'quantity',
            inverted = false,
        }

        sensor_data.config.contributors[key] = contributor_info
    end

    ---@param index defines.inventory?
    ---@param supported table<integer, defines.inventory>
    ---@param inventories table<defines.inventory, LocalisedString>
    local add_inventory = function(index, supported, inventories)
        if not index then return end
        local key = supported[index]
        if not key then return end
        -- check that the entity actually has the inventory
        local inventory = scan_delegate.get_inventory(index)
        if not (inventory and inventory.valid and #inventory > 0) then return end

        add_contributor(key, assert(inventories[key]))
    end

    -- turn everything off first, enable default contributors
    sensor_data.state.contributors = {}
    sensor_data.config.contributors = {}

    if scan_template.contributors then
        for name, enabled in pairs(scan_template.contributors) do
            add_contributor(name, name, enabled)
        end
    end

    -- update the available inventories
    if scan_template.inventories then
        for index = 1, scan_delegate.get_max_inventory_index() do
            add_inventory(index --[[@as defines.inventory]], scan_template.supported, scan_template.inventories)
        end
    end

    if scan_delegate.burner then
        add_inventory(scan_delegate.burner.inventory.index, BURNER_TYPE_SUPPORTED, BURNER_TYPE_INVENTORIES)
        add_inventory(scan_delegate.burner.burnt_result_inventory.index, BURNER_TYPE_SUPPORTED, BURNER_TYPE_INVENTORIES)
    end

    if scan_delegate.fluids_count > 0 then
        add_contributor(const.inventory_names.fluid, const.inventory_names.fluid)
    end

    if scan_delegate.grid then
        add_contributor(const.inventory_name.grid, const.inventory_name.grid)
    end

    -- enable elements if needed
    if table_size(sensor_data.config.contributors) == 1 then
        -- only one, that is the default
        local inventory_name, contributor_info = next(sensor_data.config.contributors)
        -- only enable if not configured
        if not configured_contributors[inventory_name] then contributor_info.enabled = true end
    else
        local primary_inventory = scan_template.primary or defines.inventory.fuel
        local inventory_name = scan_template.supported[primary_inventory] or BURNER_TYPE_SUPPORTED[primary_inventory]
        if inventory_name then
            local contributor_info = sensor_data.config.contributors[inventory_name]
            -- only enable if not configured
            if contributor_info and not configured_contributors[inventory_name] then contributor_info.enabled = true end
        end
    end

    sensor_data.state.reset_on_connect = true
    sensor_data.state.reconnect_key = get_entity_key(scan_entity)
end

---@param sensor_data inventory_sensor.Data
---@param config inventory_sensor.Config?
function InventorySensor.reconfigure(sensor_data, config)
    if not config then return end

    sensor_data.config.enabled = config.enabled
    sensor_data.config.inventory_status = config.inventory_status
    sensor_data.config.contributors = util.copy(config.contributors) or {}

    -- old (pre-2.0.0) config blueprinting
    ---@diagnostic disable-next-line:undefined-field
    if sensor_data.config.read_grid then
        sensor_data.config.contributors[const.inventory_name.grid] = sensor_data.config.contributors[const.inventory_name.grid] or {
            name = assert(const.inventories[const.inventory_name.grid]),
            enabled = true,
            mode = 'quantity',
            inverted = false,
        }
    end
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

        local entities = sensor_data.sensor_entity.surface.find_entities(sensor_data.scan_area)

        if Framework.settings:startup_setting('debug_mode') then
            local color = { r = 0.5, g = 0.5, b = 1 }
            rendering.draw_rectangle {
                color = color,
                surface = sensor_data.sensor_entity.surface,
                left_top = sensor_data.scan_area.left_top,
                right_bottom = sensor_data.scan_area.right_bottom,
                time_to_live = const.debug_lifetime,
            }
            rendering.draw_text {
                text = tostring(#entities),
                surface = sensor_data.sensor_entity.surface,
                target = Area(sensor_data.scan_area):center(),
                color = color,
                scale = 0.5,
                alignment = 'center',
                vertical_alignment = 'middle',
                time_to_live = const.debug_lifetime,
            }
        end

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

    -- some entities (e.g. a cargo bay) want to actually delegate the entity to scan
    local scan_delegate = scan_template.delegate and scan_template.delegate(scan_entity) or scan_entity
    if not (scan_delegate and scan_delegate.valid) then return false end

    ---@type table<string, number>
    local cache = {}

    ---@type LogisticFilter[]
    local filters = {}

    ---@type fun(filter: LogisticFilter)
    local sink = function(filter)
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

    ---@type inventory_sensor.InventoryStatus
    local inventoryStatus = {
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

    ---@param status inventory_sensor.InventoryStatus
    local status_sink = function(status)
        for key, value in pairs(status) do
            inventoryStatus[key] = inventoryStatus[key] + value
        end
    end

    -- add specific static signals
    if scan_template.signals then
        for _, name in pairs(scan_template.signals) do
            assert(const.signals[name])
            sink { value = const.signals[name], min = 1 }
        end
    end

    ---@type inventory_sensor.ContributorTemplate
    local contributor_template = {
        sensor_data = sensor_data,
        scan_entity = scan_delegate,
        sink = sink,
        status_sink = status_sink,
    }

    -- add custom items
    for name, contributor_info in pairs(sensor_data.state.contributors) do
        local contributor_config = sensor_data.config.contributors[name]
        if contributor_info.enabled or (contributor_config and contributor_config.enabled) then
            contributor_template.contributor_info = contributor_config
            local contributor = assert(sensor_entities.contributors[name])
            contributor(contributor_template)
        end
    end

    -- add globals
    contributor_template.contributor_info = nil
    for _, name in pairs(sensor_entities.global_contributors) do
        local contributor = assert(sensor_entities.contributors[name])
        contributor(contributor_template)
    end

    -- add virtual status signals
    if sensor_data.config.inventory_status then
        if inventoryStatus.totalSlotCount ~= 0 then
            inventoryStatus.usedSlotPercentage = math.floor(.5 + (inventoryStatus.filledSlotCount * 100 / inventoryStatus.totalSlotCount))
        end

        if inventoryStatus.totalFluidCapacity ~= 0 then
            inventoryStatus.usedFluidPercentage = math.floor(.5 + (inventoryStatus.totalFluidAmount * 100 / inventoryStatus.totalFluidCapacity))
        end

        for signal_name, field_name in pairs(const.inventory_status_signals) do
            local value = inventoryStatus[field_name]
            if value ~= 0 then
                sink { value = { type = 'virtual', name = 'signal-' .. signal_name, quality = 'normal' }, min = value }
            end
        end
    end

    if Framework.settings:startup_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 1, b = 0.3 },
            surface = sensor_data.sensor_entity.surface,
            left_top = sensor_data.sensor_entity.bounding_box.left_top,
            right_bottom = sensor_data.sensor_entity.bounding_box.right_bottom,
            time_to_live = const.debug_scan_lifetime,
        }
    end

    local final_filter = {}
    for _, filter in pairs(filters) do
        if filter.min ~= 0 then table.insert(final_filter, filter) end
    end

    section.filters = final_filter

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
    if entity.has_flag('not-on-map') then return false end
    if sensor_entities.blacklist[entity.name] then return false end

    -- reconnect to the same entity
    if sensor_data.scan_entity and sensor_data.scan_entity.valid and sensor_data.scan_entity.unit_number == entity.unit_number then return true end

    local scan_controller = locate_scan_template(entity)
    if not scan_controller then return false end

    sensor_data.scan_entity = entity
    sensor_data.scan_interval = scan_controller.interval or const.scan_frequency.stationary -- unset scan interval -> stationary
    sensor_data.config.scan_entity_id = entity.unit_number

    local entity_key = get_entity_key(entity)

    if sensor_data.state.reset_on_connect and not (sensor_data.state.reconnect_key and entity_key == sensor_data.state.reconnect_key) then
        sensor_data.config.contributors = nil
    end

    sensor_data.state.reconnect_key = entity_key

    InventorySensor.update_supported(sensor_data, scan_controller)
    InventorySensor.load(sensor_data, true)

    if Framework.settings:startup_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 0.3, g = 1, b = 0.3 },
            surface = sensor_data.sensor_entity.surface,
            left_top = sensor_data.scan_area.left_top,
            right_bottom = sensor_data.scan_area.right_bottom,
            time_to_live = const.debug_lifetime,
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

    local section = InventorySensor.get_section(sensor_data)
    section.filters = {}

    if Framework.settings:startup_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 0.3, b = 0.3 },
            surface = sensor_data.sensor_entity.surface,
            left_top = sensor_data.scan_area.left_top,
            right_bottom = sensor_data.scan_area.right_bottom,
            time_to_live = const.debug_lifetime,
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
