----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

local const = require('lib.constants')

---@class inventory_sensor.Mod
---@field remote_apis table<string, string>
---@field settings ff2.ModSettings
---@field SensorController inventory_sensor.Controller
---@field Gui inventory_sensor.Gui?
local This = {
    remote_apis = {
        PickerDollies = 'picker-dollies',
    },
    settings = require('lib.settings'),
}

function This.boot()
    This.SensorController = require('scripts.controller')
    This.Gui = require('scripts.gui')
end

--------------------------------------------------------------------------------
-- Framework initializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function This.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = const.prefix,
        -- prefix for log messages
        log_prefix = const.log_prefix,
        -- name is a human readable name
        name = const.name,
        -- The filesystem root.
        root = const.root,
    }
end

return This
