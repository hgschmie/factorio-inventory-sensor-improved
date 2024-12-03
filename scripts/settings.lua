---@meta
------------------------------------------------------------------------
-- global startup settings
------------------------------------------------------------------------

local const = require('lib.constants')

---@type table<FrameworkSettings.name, FrameworkSettingsGroup>
local Settings = {
    runtime = {
        [const.settings_find_entity_interval_name] = { key = const.settings_find_entity_interval, value = 120 },
        [const.settings_update_interval_name] = { key = const.settings_update_interval, value = 10 },
        [const.settings_read_equipment_grid_name] = { key = const.settings_read_equipment_grid, value = false },
        [const.settings_scan_offset_name] = { key = const.settings_scan_offset, value = 0.2 },
        [const.settings_scan_range_name] = { key = const.settings_scan_range, value = 1.5 },
    },
}

return Settings
