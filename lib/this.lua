----------------------------------------------------------------------------------------------------
--- Initialize this mod's globals
----------------------------------------------------------------------------------------------------

---@class InvSensorModThis
---@field other_mods table<string, string>
---@field InvSensor InventorySensor
local This = {
    InventorySensor = require('scripts.inventory-sensor'),
}

----------------------------------------------------------------------------------------------------

return function(stage)
    if This['this_' .. stage] then
        This['this_' .. stage](This)
    end

    return This
end
