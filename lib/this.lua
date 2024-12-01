---@meta
----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class InvSensorModThis
---@field other_mods table<string, string>
---@field SensorController InventorySensorController
local This = {
    other_mods = {
        PickerDollies = 'picker-dollies',
        ['even-pickier-dollies'] = 'picker-dollies',
    },

    SensorController = require('scripts.controller'),
}

Framework.settings:add_defaults(require('scripts.settings'))

----------------------------------------------------------------------------------------------------

return function(stage)
    if This['this_' .. stage] then
        This['this_' .. stage](This)
    end

    return This
end
