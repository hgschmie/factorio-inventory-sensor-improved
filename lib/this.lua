---@meta
----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class InventorySensorMod
---@field other_mods table<string, string>
---@field SensorController InventorySensorController
---@field Gui InventorySensorGui?
This = {
    other_mods = {
        PickerDollies = 'picker-dollies',
        ['even-pickier-dollies'] = 'picker-dollies',
    },
}

Framework.settings:add_defaults(require('lib.settings'))

if script then
    This.SensorController = require('scripts.controller')
    This.Gui = require('scripts.gui')
end

return This
