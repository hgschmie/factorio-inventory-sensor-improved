---@meta
------------------------------------------------------------------------
-- Inventory Sensor Data Management
------------------------------------------------------------------------

local const = require('lib.constants')

local Is = require('stdlib.utils.is')
local Area = require('stdlib.area.area')

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
    if not Is.Valid(entity) then return nil end

    assert(entity)
    local scan_controller = is_entities.supported_entities[entity.type] and
        (is_entities.supported_entities[entity.type][entity.name] or is_entities.supported_entities[entity.type]['*'])

    if not scan_controller then return nil end

    -- if there is a validate function, it must pass
    if scan_controller.validate and not scan_controller.validate(entity) then return nil end

    return scan_controller
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
---@return InventorySensorData
function InventorySensor.new(sensor_entity, tags)
    ---@type InventorySensorData
    local data = {
        sensor_entity = sensor_entity,
        tags = tags,
        config = {
            enabled = true,
            status = sensor_entity.status,
        },
    }

    InventorySensor.enhance(data)

    return data
end

--- Add the meta methods to the data object. *MUST* be called every time the
--- object is retrieved from storage.
---@param is_data InventorySensorData
function InventorySensor.enhance(is_data)
    if not is_data then return end
    -- dispatch to methods in InventorySensor. This needs to be done through a metatable
    -- as the game does not allow functions directly on data that is put into storage.
    setmetatable(is_data, { __index = InventorySensor })
end

---@param self InventorySensorData
function InventorySensor:destroy()
    self.sensor_entity.destroy()
end

---@param self InventorySensorData
---@param unit_number integer
function InventorySensor:validate(unit_number)
    return Is.Valid(self.sensor_entity) and self.sensor_entity.unit_number == unit_number
end

----------------------------------------------------------------------------------------------------
-- scan
----------------------------------------------------------------------------------------------------

---@param self InventorySensorData
---@return BoundingBox scan_area
function InventorySensor:create_scan_area()
    local scan_offset = Framework.settings:runtime_setting(const.settings_scan_offset_name)
    local scan_range = Framework.settings:runtime_setting(const.settings_scan_range_name)

    local entity = self.sensor_entity

    local scan_area = Area.new(const.normalized_area[entity.direction])
    assert(scan_area)

    if entity.direction == defines.direction.west or entity.direction == defines.direction.east then
        scan_area = scan_area * Area.new { left_top = { scan_range, scan_offset }, right_bottom = { scan_range, scan_offset } }
    else
        scan_area = scan_area * Area.new { left_top = { scan_offset, scan_range }, right_bottom = { scan_offset, scan_range } }
    end

    scan_area = scan_area:offset(entity.position)
    return scan_area:normalize()
end

---@param self InventorySensorData
---@param force boolean?
---@return boolean scanned True if scan happened
function InventorySensor:scan(force)
    if self.config.enabled then
        local interval = self.scan_interval or Framework.settings:runtime_setting(const.settings_find_entity_interval_name)

        local scan_time = self.scan_time or 0
        if not (force or (game.tick - scan_time >= interval)) then return false end

        self.scan_time = game.tick

        -- if force is set, always create the scan area, otherwise, if a scan area
        -- already exists, use that
        self.scan_area = (not force) and self.scan_area or self:create_scan_area()

        if Framework.settings:runtime_setting('debug_mode') then
            rendering.draw_rectangle {
                color = { r = 0.5, g = 0.5, b = 1 },
                surface = self.sensor_entity.surface,
                left_top = self.scan_area.left_top,
                right_bottom = self.scan_area.right_bottom,
                time_to_live = 10,
            }
        end

        local entities = self.sensor_entity.surface.find_entities(self.scan_area)

        for _, entity in pairs(entities) do
            if self:connect(entity) then
                return true
            end
        end
    end

    -- not connected
    self:disconnect()

    return true
end

----------------------------------------------------------------------------------------------------
-- load/clear
----------------------------------------------------------------------------------------------------

---@param self InventorySensorData
---@return LuaConstantCombinatorControlBehavior
function InventorySensor:clear()
    -- empty the signals sections
    local control = self.sensor_entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]

    for i = 1, control.sections_count, 1 do
        control.remove_section(i)
    end

    return control
end



--- Loads the state of the connected entity into the sensor.
---@param self InventorySensorData
---@param force boolean?
---@return boolean entity was loaded
function InventorySensor:load(force)
    local load_time = self.load_time or 0
    if not (force or (game.tick - load_time >= Framework.settings:runtime_setting(const.settings_update_interval_name))) then return false end
    self.load_time = game.tick

    local control = self:clear()

    if not self.config.enabled then return false end
    if not Is.Valid(self.scan_entity) then return false end
    local scan_controller = locate_scan_controller(self.scan_entity)
    if not scan_controller then return false end

    ---@type integer
    local idx = 0

    ---@type table<string, table<string, table<string, number>>>
    local cache = {}

    local sink = function(filter)
        local signal = filter.value
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
            section.set_slot(pos,  filter)
        end
    end

    local burner = self.scan_entity.burner
    local remaining_fuel = 0

    -- load inventories for the entity
    if scan_controller.inventories then
        for _, inventory in pairs(scan_controller.inventories) do
            local inventory_items = self.scan_entity.get_inventory(inventory)
            if inventory_items then
                for _, item in pairs(inventory_items.get_contents()) do
                    sink { value = { name = item.name, type = 'item', quality = item.quality or 'normal' }, min = item.count }

                    -- if this is a burner entity, compute remaining fuel, ignore negative entries
                    if burner and inventory == defines.inventory.fuel then
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

    for i = 1, self.scan_entity.fluids_count, 1 do
        local fluid = self.scan_entity.get_fluid(i)
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
        scan_controller.contribute(self, sink)
    end

    local temperature = self.scan_entity.temperature
    if temperature then
        sink { value = const.signals.temperature_signal, min = temperature }
    end

    -- if this is a burner entity, add burner signal
    if burner then
        if burner.remaining_burning_fuel > 0 then
            remaining_fuel = remaining_fuel + burner.remaining_burning_fuel / 1e6 -- convert to MJ
        end

        sink { value = const.signals.fuel_signal, min = math.min(math.floor(remaining_fuel + 0.5), 2 ^ 31 - 1) }
    end

    if Framework.settings:runtime_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 1, b = 0.3 },
            surface = self.sensor_entity.surface,
            left_top = self.sensor_entity.bounding_box.left_top,
            right_bottom = self.sensor_entity.bounding_box.right_bottom,
            time_to_live = 2,
        }
    end

    return true
end

----------------------------------------------------------------------------------------------------
-- connect/disconnect
----------------------------------------------------------------------------------------------------

---@param self InventorySensorData
---@param entity LuaEntity
---@return boolean connected
function InventorySensor:connect(entity)
    if not Is.Valid(entity) then return false end
    if is_entities.blacklist[entity.name] then return false end

    local scan_controller = locate_scan_controller(entity)
    if not scan_controller then return false end

    local connect_event = self.scan_entity == nil or self.scan_entity.unit_number ~= entity.unit_number

    self.scan_entity = entity
    self.scan_interval = scan_controller.interval or scan_frequency.stationary -- unset scan interval -> stationary
    self.config.scan_entity_id = entity.unit_number

    self:load(true)

    if connect_event and Framework.settings:runtime_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 0.3, g = 1, b = 0.3 },
            surface = self.sensor_entity.surface,
            left_top = self.scan_area.left_top,
            right_bottom = self.scan_area.right_bottom,
            time_to_live = 10,
        }
    end

    return true
end

---@param self InventorySensorData
function InventorySensor:disconnect()
    if not self.scan_entity then return end

    self.scan_entity = nil
    self.scan_interval = nil
    self.config.scan_entity_id = nil

    self:clear()

    if Framework.settings:runtime_setting('debug_mode') then
        rendering.draw_rectangle {
            color = { r = 1, g = 0.3, b = 0.3 },
            surface = self.sensor_entity.surface,
            left_top = self.scan_area.left_top,
            right_bottom = self.scan_area.right_bottom,
            time_to_live = 10,
        }
    end
end

----------------------------------------------------------------------------------------------------
-- ticker
----------------------------------------------------------------------------------------------------

---@param self InventorySensorData
---@return boolean if entity was either scanned or loaded
function InventorySensor:tick()
    if not Is.Valid(self.sensor_entity) then
        self.config.enabled = false
        self.config.status = defines.entity_status.marked_for_deconstruction
        return false
    else
        local old_status = self.config.status
        self.config.status = self.sensor_entity.status

        local scanned = self:scan()
        local loaded = self:load()
        return scanned or loaded
    end
end

----------------------------------------------------------------------------------------------------

return InventorySensor
