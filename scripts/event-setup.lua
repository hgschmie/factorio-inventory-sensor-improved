--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local const = require('lib.constants')


--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function onInitInvSensor()
    This.InventorySensor:init()
end

local function onLoadInvSensor()
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

---@param changed ConfigurationChangedData?
local function onConfigurationChanged(changed)
    This.InventorySensor:init()

    for _, force in pairs(game.forces) do
        if force.technologies['circuit-network'].researched then
            if force.recipes[const.inventory_sensor_name] then
                force.recipes[const.inventory_sensor_name].enabled = true
            end
        end
    end
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

-- mod init code
Event.on_init(onInitInvSensor)
Event.on_load(onLoadInvSensor)

-- Configuration changes (runtime and startup)
Event.on_configuration_changed(onConfigurationChanged)
Event.register(defines.events.on_runtime_mod_setting_changed, onConfigurationChanged)
