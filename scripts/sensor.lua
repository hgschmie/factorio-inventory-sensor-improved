---@meta
------------------------------------------------------------------------
-- Inventory Sensor Data Management
------------------------------------------------------------------------

local const = require('lib.constants')

local Area = require('stdlib.area.area')
local Direction = require('stdlib.area.direction')
local Position = require('stdlib.area.position')
local table = require('stdlib.utils.table')

---@type ISSupportedEntities
local is_entities = require('scripts.supported-entities')

------------------------------------------------------------------------

---@class InventorySensor
local InventorySensor = {}

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

---@param entity LuaEntity?
---@return ISDataController?
local function locate_scan_controller(entity)
    if not (entity and entity.valid) then return nil end

    assert(entity)
    local scan_controller = is_entities.supported_entities[entity.type] and
        (is_entities.supported_entities[entity.type][entity.name] or is_entities.supported_entities[entity.type]['*'])

    if not scan_controller then return nil end

    -- if there is a validate function, it must pass
    if scan_controller.validate and not scan_controller.validate(entity) then return nil end

    return scan_controller
end

--------------------------------------------------------------------------------
-- configure
--------------------------------------------------------------------------------

---@param is_data inventory_sensor.Data
---@param config inventory_sensor.Config?
function InventorySensor.reconfigure(is_data, config)
    if not config then return end

    is_data.config.enabled = config.enabled
    is_data.config.read_grid = config.read_grid
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
---@param tags Tags?
---@return inventory_sensor.Data
function InventorySensor.new(sensor_entity, tags)
    ---@type inventory_sensor.Data
    local data = {
        sensor_entity = sensor_entity,
        inventories = {},
        config = {
            enabled = true,
            read_grid = false,
            status = sensor_entity.status,
        },
    }

    if tags then
        InventorySensor.reconfigure(data, tags.is_config --[[@as inventory_sensor.Config? ]])
    end

    return data
end

---@param is_data inventory_sensor.Data
function InventorySensor.destroy(is_data)
    if not is_data then return end
    is_data.sensor_entity = nil -- don't destroy; lifecycle is managed by the game and destroying prevents ghosts from showing
end

---@param is_data inventory_sensor.Data
---@param unit_number integer
function InventorySensor.validate(is_data, unit_number)
    return is_data.sensor_entity and is_data.sensor_entity.valid and is_data.sensor_entity.unit_number == unit_number
end

----------------------------------------------------------------------------------------------------
-- scan
----------------------------------------------------------------------------------------------------

---@param entity LuaEntity
---@return boolean
local function is_horizontal(entity)
    return entity.direction == defines.direction.west or entity.direction == defines.direction.east
end

---@param is_data inventory_sensor.Data
---@return BoundingBox scan_area
function InventorySensor.create_scan_area(is_data)
    assert(is_data.sensor_entity)

    local scan_offset = Framework.settings:runtime_setting(const.settings_scan_offset_name)
    local scan_range = Framework.settings:runtime_setting(const.settings_scan_range_name)

    local entity = is_data.sensor_entity
    local position = Position(entity.position)
    local area = Area.new { position + { -0.5, -scan_offset }, position + { 0.5, scan_offset } }
    area = is_horizontal(entity) and area or area:flip()
    area = area:translate(Direction.opposite(entity.direction), scan_range - 0.5)

    return area
end

---@param is_data inventory_sensor.Data
---@param force boolean?
---@return boolean scanned True if scan happened
function InventorySensor.scan(is_data, force)
    if is_data.config.enabled then
        local interval = is_data.scan_interval or Framework.settings:runtime_setting(const.settings_find_entity_interval_name)

        local scan_time = is_data.scan_time or 0
        if not (force or (game.tick - scan_time >= interval)) then return false end

        is_data.scan_time = game.tick

        -- if force is set, always create the scan area, otherwise, if a scan area
        -- already exists, use that
        is_data.scan_area = (not force) and is_data.scan_area or InventorySensor.create_scan_area(is_data)

        if Framework.settings:runtime_setting('debug_mode') then
            rendering.draw_rectangle {
                color = { r = 0.5, g = 0.5, b = 1 },
                surface = is_data.sensor_entity.surface,
                left_top = is_data.scan_area.left_top,
                right_bottom = is_data.scan_area.right_bottom,
                time_to_live = 10,
            }
        end

        local entities = is_data.sensor_entity.surface.find_entities(is_data.scan_area)

        for _, entity in pairs(entities) do
            if InventorySensor.connect(is_data, entity) then
                return true
            end
        end
    end

    -- not connected
    InventorySensor.disconnect(is_data)

    return true
end

----------------------------------------------------------------------------------------------------
-- load/clear
----------------------------------------------------------------------------------------------------

---@param is_data inventory_sensor.Data
---@return LuaConstantCombinatorControlBehavior
function InventorySensor.clear(is_data)
    -- empty the signals sections

    local control = is_data.sensor_entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]
    assert(control)

    for i = 1, control.sections_count, 1 do
        control.remove_section(i)
    end

    return control
end

--- Loads the state of the connected entity into the sensor.
---@param is_data inventory_sensor.Data
---@param force boolean?
---@return boolean entity was loaded
function InventorySensor.load(is_data, force)
    local load_time = is_data.load_time or 0
    if not (force or (game.tick - load_time >= Framework.settings:runtime_setting(const.settings_update_interval_name))) then return false end
    is_data.load_time = game.tick

    local control = InventorySensor.clear(is_data)

    if not is_data.config.enabled then return false end
    local scan_entity = is_data.scan_entity
    if not (scan_entity and scan_entity.valid) then return false end

    local scan_controller = locate_scan_controller(scan_entity)
    if not scan_controller then return false end

    ---@type integer
    local idx = 0

    ---@type table<string, table<string, table<string, number>>>
    local cache = {}

    ---@type fun(filter: LogisticFilter)
    local sink = function(filter)
        local signal = filter.value --[[@as SignalFilter]]
        cache[signal.type] = cache[signal.type] or {}
        cache[signal.type][signal.name] = cache[signal.type][signal.name] or {}

        local index = cache[signal.type][signal.name][signal.quality]
        if not index then
            index = idx
            cache[signal.type][signal.name][signal.quality] = index
            idx = idx + 1
            local section = control.sections[math.floor(index / 1000) + 1] or control.add_section()

            local pos = index % 1000 + 1
            section.set_slot(pos, filter)
        else
            local section = control.sections[math.floor(index / 1000) + 1]
            assert(section)

            local pos = index % 1000 + 1
            filter.min = filter.min + section.filters[pos].min
            section.set_slot(pos, filter)
        end
    end

    local burner = scan_entity.burner
    local remaining_fuel = 0

    -- load inventories for the entity
    if table_size(is_data.inventories) > 0 then
        for inventory in pairs(is_data.inventories) do
            local inventory_items = scan_entity.get_inventory(inventory)
            if inventory_items then
                for _, item in pairs(inventory_items.get_contents()) do
                    sink { value = { name = item.name, type = 'item', quality = item.quality or 'normal' }, min = item.count }

                    if burner and (inventory == defines.inventory.fuel) then
                        local fuel = prototypes.item[item.name]
                        if fuel and fuel.fuel_value then
                            remaining_fuel = remaining_fuel + math.max((fuel.fuel_value / 1e6) * item.count, 0)
                        end
                    end
                end
            end
        end
    end

    -- get fluids
    for i = 1, scan_entity.fluids_count, 1 do
        local fluid = scan_entity.get_fluid(i)
        if fluid then
            sink { value = { type = 'fluid', name = fluid.name, quality = 'normal' }, min = math.ceil(fluid.amount) }
        end
    end

    -- add specific static signals
    if scan_controller.signals then
        for name, value in pairs(scan_controller.signals) do
            assert(const.signals[name])
            sink { value = const.signals[name], min = value }
        end
    end

    -- add custom items
    if scan_controller.contribute then
        scan_controller.contribute(is_data, sink)
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

    if Framework.settings:runtime_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 1, b = 0.3 },
            surface = is_data.sensor_entity.surface,
            left_top = is_data.sensor_entity.bounding_box.left_top,
            right_bottom = is_data.sensor_entity.bounding_box.right_bottom,
            time_to_live = 2,
        }
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- connect/disconnect
----------------------------------------------------------------------------------------------------

---@param is_data inventory_sensor.Data
---@param entity LuaEntity
---@return boolean connected
function InventorySensor.connect(is_data, entity)
    if not (entity and entity.valid) then return false end
    if is_entities.blacklist[entity.name] then return false end

    local scan_controller = locate_scan_controller(entity)
    if not scan_controller then return false end

    -- reconnect to the same entity
    if is_data.scan_entity and is_data.scan_entity.unit_number == entity.unit_number then return true end

    is_data.scan_entity = entity
    is_data.scan_interval = scan_controller.interval or scan_frequency.stationary -- unset scan interval -> stationary
    is_data.inventories = table.array_to_dictionary(scan_controller.inventories or {}, true)
    is_data.config.scan_entity_id = entity.unit_number

    -- burners also look at fuel
    if entity.burner then
        is_data.inventories[defines.inventory.fuel] = true
    end

    InventorySensor.load(is_data, true)

    if Framework.settings:runtime_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 0.3, g = 1, b = 0.3 },
            surface = is_data.sensor_entity.surface,
            left_top = is_data.scan_area.left_top,
            right_bottom = is_data.scan_area.right_bottom,
            time_to_live = 10,
        }
    end

    return true
end

---@param is_data inventory_sensor.Data
function InventorySensor.disconnect(is_data)
    if not is_data.scan_entity then return end

    is_data.scan_entity = nil
    is_data.scan_interval = nil
    is_data.inventories = {}
    is_data.scan_time = nil
    is_data.load_time = nil

    is_data.config.scan_entity_id = nil
    is_data.config.status = nil

    InventorySensor.clear(is_data)

    if Framework.settings:runtime_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 0.3, b = 0.3 },
            surface = is_data.sensor_entity.surface,
            left_top = is_data.scan_area.left_top,
            right_bottom = is_data.scan_area.right_bottom,
            time_to_live = 10,
        }
    end
end

----------------------------------------------------------------------------------------------------
-- ticker
----------------------------------------------------------------------------------------------------

---@param is_data inventory_sensor.Data
---@return boolean if entity was either scanned or loaded
function InventorySensor.tick(is_data)
    if not (is_data.sensor_entity and is_data.sensor_entity.valid) then
        is_data.config.enabled = false
        is_data.config.status = defines.entity_status.marked_for_deconstruction
        return false
    else
        is_data.config.status = is_data.sensor_entity.status

        local scanned = InventorySensor.scan(is_data)
        local loaded = InventorySensor.load(is_data)
        return scanned or loaded
    end
end

----------------------------------------------------------------------------------------------------

return InventorySensor
