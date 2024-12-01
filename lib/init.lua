---@meta
----------------------------------------------------------------------------------------------------
--- Global definitions included in all phases
----------------------------------------------------------------------------------------------------

return function(stage)
    local const = require('lib.constants')

    -- Framework core
    require('framework.init'):init(const.framework_init, stage)

    -- mod code
    This = require('lib.this')(stage)
end
