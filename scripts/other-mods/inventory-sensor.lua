--------------------------------------------------------------------------------
-- Inventory Sensor (https://mods.factorio.com/mod/Inventory%20Sensor) support
--------------------------------------------------------------------------------

local const = require('lib.constants')
local Is = require('stdlib.utils.is')

local InventorySensorSupport = {}

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------

InventorySensorSupport.data_final_fixes = function()
    local prototype = data.raw['constant-combinator']['item-sensor']
    if prototype then
        prototype.fast_replaceable_group = 'inventory-sensor'
    end
end

return InventorySensorSupport
