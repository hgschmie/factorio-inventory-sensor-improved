------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local table = require('stdlib.utils.table')

--------------------------------------------------------------------------------
-- globals
--------------------------------------------------------------------------------

---@enum inventory_sensor.scan_frequency
local scan_frequency = {
    stationary = 300, -- scan every five seconds
    mobile = 30,      -- scan every 1/2 of a second
    empty = 120       -- scan every 2 seconds
}

local Constants = {}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

Constants.prefix = 'hps__is-'
Constants.name = 'inventory-sensor'
Constants.root = '__inventory-sensor-improved__'
Constants.gfx_location = Constants.root .. '/graphics/'
Constants.order = 'c[combinators]-d[inventory-sensor]'
Constants.config_tag_name = 'is_config'
Constants.scan_frequency = scan_frequency

Constants.debug_lifetime = 10
Constants.debug_scan_lifetime = 2

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

Constants.signal_names = {
    progress_signal = 'inv-sensor-progress',
    temperature_signal = 'inv-sensor-temperature',
    fuel_signal = 'inv-sensor-fuel',
    charge_signal = 'inv-sensor-charge',
    speed_signal = 'inv-sensor-speed',
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

Constants.inventory_status_signals = {
    -- blocked slots
    B = 'blockedSlotIndex',
    -- slot counts
    E = 'emptySlotCount',
    F = 'filledSlotCount',
    T = 'totalSlotCount',
    P = 'usedSlotPercentage',
    X = 'filteredSlotCount',
    -- total counts
    I = 'totalItemCount',
    -- fluids
    D = 'emptyFluidsCount',
    A = 'availableFluidsCount',
    C = 'totalFluidsCount',
    V = 'totalFluidCapacity',
    L = 'totalFluidAmount',
    Q = 'usedFluidPercentage',
}

--------------------------------------------------------------------------------
-- locale
--------------------------------------------------------------------------------

---@type table<integer, string>
Constants.inventory = table.invert(defines.inventory)

---@type table<string, LocalisedString>
Constants.inventories = {}

for _, name in pairs {
    'charge', 'crafting_progress', 'grid', 'fluid', 'research_progress', 'silo_progress',
    'contents', 'ammo', 'trash', 'cargo', 'input', 'output', 'modules', 'dump',
    'temperature', 'burner_fuel', 'trunk', 'pump_speed', 'arm',
} do
    Constants.inventories[name] = { Constants:locale('inventory-name-' .. name) }
end

for name in pairs(defines.inventory) do
    Constants.inventories[name] = { Constants:locale('inventory-name-' .. name) }
end

---@type table<string, string>
Constants.inventory_names = {}
for key in pairs(Constants.inventories) do
    Constants.inventory_names[key] = key
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
