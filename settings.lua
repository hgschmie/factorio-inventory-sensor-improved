require('lib.init')('settings')

local const = require('lib.constants')

data:extend({
    {
        type = "int-setting",
        name = const.settings_update_interval,
        order = "aa",
        setting_type = "startup",
        default_value = 10,
        minimum_value = 1,
        maximum_value = 216000, -- 1h
    },
    {
        type = "int-setting",
        name = const.settings_find_entity_interval,
        order = "ab",
        setting_type = "runtime-global",
        default_value = 120,
        minimum_value = 1,
        maximum_value = 216000, -- 1h
    },
    {
        type = "bool-setting",
        name = const.settings_read_equipment_grid,
        order = "ba",
        setting_type = "runtime-global",
        default_value = false,
    },
    {
        type = "double-setting",
        name = const.settings_scan_offset,
        order = "ca",
        setting_type = "runtime-global",
        default_value = 0.2,
    },
    {
        type = "double-setting",
        name = const.settings_scan_range,
        order = "cb",
        setting_type = "runtime-global",
        default_value = 1.5,
    },
    {
        -- Debug mode (framework dependency)
        setting_type = "runtime-global",
        name = Framework.PREFIX .. 'debug-mode',
        type = "bool-setting",
        default_value = false,
        order = "z"
    },
})

--------------------------------------------------------------------------------

require('framework.other-mods').settings()
