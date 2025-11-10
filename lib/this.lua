----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class inventory_sensor.Mod
---@field other_mods table<string, string>
---@field SensorController inventory_sensor.Controller
---@field Gui inventory_sensor.Gui?
This = {
    other_mods = {
        ['even-pickier-dollies'] = 'picker-dollies',
    },
}

Framework.settings:add_defaults(require('lib.settings'))

if script then
    This.SensorController = require('scripts.controller')
    This.Gui = require('scripts.gui')
end

return This
