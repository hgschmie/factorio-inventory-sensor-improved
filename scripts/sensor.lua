---@meta
------------------------------------------------------------------------
-- Inventory Sensor Data Management
------------------------------------------------------------------------

local const = require('lib.constants')

local Is = require('stdlib.utils.is')
local Area = require('stdlib.area.area')

---@type ISSupportedEntities
local is_entities = require('scripts.supported_entities')

------------------------------------------------------------------------

---@class InventorySensor
local InventorySensor = {}

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
        debug = Framework.settings:runtime_setting('debug_mode') --[[@as boolean ]],
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
    local interval = self.scan_interval or Framework.settings:runtime_setting(const.settings_find_entity_interval_name)

    local scan_time = self.scan_time or 0
    if not (force or (game.tick - scan_time >= interval)) then return false end

    self.scan_time = game.tick

    if force then
        self.scan_area = self:create_scan_area()
    else
        self.scan_area = self.scan_area or self:create_scan_area()
    end

    if self.debug then
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

    -- not connected
    self:disconnect()

    return true
end

----------------------------------------------------------------------------------------------------
-- load/clear
----------------------------------------------------------------------------------------------------

---@param self InventorySensorData
---@param sink fun(filter: LogisticFilter)
local function load_inventory(self, sink)
    for _, inventory in pairs(self.scan_controller.inventories) do
        local inventory_items = self.scan_entity.get_inventory(inventory)
        assert(inventory_items)
        for _, item in pairs(inventory_items.get_contents()) do
            sink { value = { name = item.name, type = 'item', quality = item.quality or 'normal' }, min = item.count }
        end
    end
end

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
    if not (force or (game.tick - load_time >= Framework.settings:startup_setting(const.settings_update_interval_name))) then return false end
    self.load_time = game.tick

    local control = self:clear()

    if not Is.Valid(self.scan_entity) then return false end
    if not self.scan_controller then return false end

    ---@type LuaLogisticSection?
    local section
    ---@type integer
    local offset = -1
    ---@type integer
    local idx = 1

    local populate_callback = function(filter)
        local pos
        repeat
            pos = idx - offset * 1000
            if pos > 1000 then section = nil end
            if not section then
                section = control.add_section()
                offset = offset + 1
            end
            assert(section)
        until pos <= 1000
        section.set_slot(idx, filter)
        idx = idx + 1
    end

    load_inventory(self, populate_callback)

    if self.debug then
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
    local scan_controller = is_entities.supported_entities[entity.type]
    if not (Is.Valid(entity) and scan_controller and not is_entities.blacklist[entity.name]) then return false end

    local connect_event = self.scan_entity == nil or self.scan_entity.unit_number ~= entity.unit_number

    self.scan_entity = entity
    self.scan_controller = scan_controller
    self.scan_interval = self.scan_controller.interval or scan_frequency.stationary -- unset scan interval -> stationary
    self.config.scan_entity_id = entity.unit_number

    self:load(true)

    if self.debug and connect_event then
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
    local disconnect_event = self.scan_entity ~= nil

    self.scan_entity = nil
    self.scan_controller = nil
    self.scan_interval = nil
    self.config.scan_entity_id = nil

    self:clear()

    if self.debug and disconnect_event then
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
