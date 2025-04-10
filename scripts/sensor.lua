---@meta
------------------------------------------------------------------------
-- Inventory Sensor Data Management
------------------------------------------------------------------------
assert(script)

local const = require('lib.constants')

local Area = require('stdlib.area.area')
local Direction = require('stdlib.area.direction')
local Position = require('stdlib.area.position')
local table = require('stdlib.utils.table')

---@type ISSupportedEntities
local is_entities = require('scripts.supported-entities')

------------------------------------------------------------------------

---@class InventorySensor
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
    is_data.config.provide_virtual_signals = config.provide_virtual_signals
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
            provide_virtual_signals = false,
            status = sensor_entity.status,
        },
    }

    if config then
        InventorySensor.reconfigure(data, config)
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

    local entity = is_data.sensor_entity
    local position = Position(entity.position)
    local area = Area.new {
        position + { -0.5, -InventorySensor.scan_offset },
        position + { 0.5, InventorySensor.scan_offset }
    }
    area = is_horizontal(entity) and area or area:flip()
    area = area:translate(Direction.opposite(entity.direction), InventorySensor.scan_range - 0.5)

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
---@return LuaLogisticSection
function InventorySensor.get_section(is_data)
    -- empty the signals sections

    local control = assert(is_data.sensor_entity.get_or_create_control_behavior()) --[[@as LuaConstantCombinatorControlBehavior ]]
    if control.sections_count == 0 then
        control.add_section()
    end

    return assert(control.get_section(1))
end

--- Loads the state of the connected entity into the sensor.
---@param is_data inventory_sensor.Data
---@param force boolean?
---@return boolean entity was loaded
function InventorySensor.load(is_data, force)
    local load_time = is_data.load_time or 0
    if not (force or (game.tick - load_time >= Framework.settings:runtime_setting(const.settings_update_interval_name))) then return false end
    is_data.load_time = game.tick

    local section = InventorySensor.get_section(is_data)
    section.filters = {}

    if not is_data.config.enabled then return false end
    local scan_entity = is_data.scan_entity
    if not (scan_entity and scan_entity.valid) then return false end

    local scan_controller = locate_scan_controller(scan_entity)
    if not scan_controller then return false end

    ---@type table<string, number>
    local cache = {}

    ---@type LogisticFilter[]
    local filters = {}

    ---@type table<string, number>
    local workbench = {}

    ---@type fun(filter: LogisticFilter)
    local sink = function(filter)
        local signal = filter.value --[[@as SignalFilter]]
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

    if is_data.config.provide_virtual_signals then
        -- init data for virtual signal update, maybe a signal mapping would be nice in the future
        workbench = {
            -- A=0,
            B=0, -- begin of red bar, if not used in this inventory, but supported, it is usually t + 1
            -- C=0,
            -- D=0, 
            E=0, -- empty slots	or	remaining space for fluid
            F=0, -- full slots	or	amount of fluid
            -- G=0,
            -- H=0,
            I=0, -- total item amount
            -- J=0, 
            -- K=0,
            L=0, -- total amount of liquids
            -- M=0,
            -- N=0,
            -- O=0,
            P=0, -- percent of used slots or fluid
            -- Q=0,
            -- R=0, 
            -- S=0,
            T=0, -- total slot count or total amount of fluid
            -- U=0,
            -- V=0,
            -- W=0, 
            X=0, -- filtered slot count
            -- Z=0
        }
    end
    -- load inventories for the entity
    if table_size(is_data.inventories) > 0 then
        for inventory_index in pairs(is_data.inventories) do
            local inventory = scan_entity.get_inventory(inventory_index)
            if inventory and inventory.valid then
	        if is_data.config.provide_virtual_signals then
		    workbench.T = #inventory
		    workbench.E = inventory.count_empty_stacks()
		    workbench.X = inventory.count_empty_stacks(true) - workbench.E
		    -- workbench.F = workbench.T - workbench.E - workbench.X
		    workbench.F = workbench.T - workbench.E
		    workbench.P = workbench.F * 100  / workbench.T
		    if inventory.supports_bar() then
		        workbench.B = inventory.get_bar()
		        -- local avail_slots = (workbench.T - workbench.B)
		    end
                end
                for _, item in pairs(inventory.get_contents()) do
                    sink { value = { name = item.name, type = 'item', quality = item.quality or 'normal' }, min = item.count }
	            if is_data.config.provide_virtual_signals then
			workbench.I = workbench.I + item.count	-- accumulate the amount of all items
		    end
                    if burner and (inventory_index == defines.inventory.fuel) then
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
	    if is_data.config.provide_virtual_signals then
                workbench.T = workbench.T + scan_entity.fluidbox.get_capacity(i)
                workbench.F = workbench.F + fluid.amount
                workbench.L = workbench.L + fluid.amount
                if workbench.T then
                    workbench.P = workbench.F * 100  / workbench.T
                end
		workbench.E = workbench.T - workbench.F
            end
            sink { value = { type = 'fluid', name = fluid.name, quality = 'normal' }, min = math.ceil(fluid.amount) }
        end
    end

    -- finally turn the workbench values into signals
    if is_data.config.provide_virtual_signals then
        local k,v
        for k,v in pairs(workbench) do
            if workbench[k] ~= 0 then
                sink { value = {type = "virtual",name = "signal-" .. k}, min = v }
            end
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

    section.filters = filters

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
    if is_data.scan_entity and is_data.scan_entity.valid and is_data.scan_entity.unit_number == entity.unit_number then return true end

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

    local section = InventorySensor.get_section(is_data)
    section.filters = {}

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
