---@meta
------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local Area = require('stdlib.area.area')
local table = require('stdlib.utils.table')

--------------------------------------------------------------------------------
-- globals
--------------------------------------------------------------------------------

---@enum scan_frequency
scan_frequency = {
    stationary = 300, -- scan every five seconds
    mobile = 30,      -- scan every 1/2 of a second
    empty = 120       -- scan every 2 seconds
}

local Constants = {}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

-- the current version that is the result of the latest migration
Constants.current_version = 1

Constants.prefix = 'hps__is-'
Constants.name = 'inventory-sensor'
Constants.root = '__inventory-sensor-improved__'
Constants.gfx_location = Constants.root .. '/graphics/'
Constants.order = 'c[combinators]-d[inventory-sensor]'
Constants.config_tag_name = 'is_config'

--------------------------------------------------------------------------------
-- Framework initializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function Constants.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = Constants.prefix,
        -- name is a human readable name
        name = Constants.name,
        -- The filesystem root.
        root = Constants.root,
    }
end

--------------------------------------------------------------------------------
-- Path and name helpers
--------------------------------------------------------------------------------

---@param value string
---@return string result
function Constants:with_prefix(value)
    return self.prefix .. value
end

---@param path string
---@return string result
function Constants:png(path)
    return self.gfx_location .. path .. '.png'
end

---@param id string
---@return string result
function Constants:locale(id)
    return Constants:with_prefix('gui.') .. id
end

--------------------------------------------------------------------------------
-- entity names and maps
--------------------------------------------------------------------------------

-- Base name
Constants.inventory_sensor_name = Constants:with_prefix(Constants.name)

Constants.normalized_area = {
    [defines.direction.north] = Area.normalize { left_top = { x = -1, y = 1 }, right_bottom = { x = 1, y = 0 }, },
    [defines.direction.east] = Area.normalize { left_top = { x = -1, y = 1 }, right_bottom = { x = 0, y = -1 }, },
    [defines.direction.south] = Area.normalize { left_top = { x = -1, y = 0 }, right_bottom = { x = 1, y = -1 }, },
    [defines.direction.west] = Area.normalize { left_top = { x = 0, y = 1 }, right_bottom = { x = 1, y = -1 }, },
}

Constants.signal_names = {
    progress_signal = 'inv-sensor-progress',
    temperature_signal = 'inv-sensor-temperature',
    fuel_signal = 'inv-sensor-fuel',
    charge_signal = 'inv-sensor-charge',
    car_detected_signal = 'inv-sensor-detected-car',
    tank_detected_signal = 'inv-sensor-detected-tank',
    spider_detected_signal = 'inv-sensor-detected-spider',
    wagon_detected_signal = 'inv-sensor-detected-wagon',
    locomotive_detected_signal = 'inv-sensor-detected-locomotive',
    rocket_ready_signal = 'signal-R',
}

Constants.signals = {}
for name, signal in pairs(Constants.signal_names) do
    Constants.signals[name] = { type = 'virtual', name = signal, quality = 'normal' }
end

--------------------------------------------------------------------------------
-- settings
--------------------------------------------------------------------------------

Constants.settings_update_interval_name = 'update_interval'
Constants.settings_find_entity_interval_name = 'find_entity_interval'
Constants.settings_read_equipment_grid_name = 'read_equipment_grid'
Constants.settings_scan_offset_name = 'scan_offset'
Constants.settings_scan_range_name = 'scan_range'
Constants.settings_update_inventory_sensors_name = 'update_inventory_sensors'

Constants.settings_update_interval = Constants:with_prefix(Constants.settings_update_interval_name)
Constants.settings_find_entity_interval = Constants:with_prefix(Constants.settings_find_entity_interval_name)
Constants.settings_read_equipment_grid = Constants:with_prefix(Constants.settings_read_equipment_grid_name)
Constants.settings_scan_offset = Constants:with_prefix(Constants.settings_scan_offset_name)
Constants.settings_scan_range = Constants:with_prefix(Constants.settings_scan_range_name)
Constants.settings_update_inventory_sensors = Constants:with_prefix(Constants.settings_update_inventory_sensors_name)

--------------------------------------------------------------------------------
-- migration
--------------------------------------------------------------------------------

Constants.migration_names = { 'item-sensor' }
Constants.migrations = table.array_to_dictionary(Constants.migration_names)

--------------------------------------------------------------------------------
return Constants
