------------------------------------------------------------------------
-- mod constant definitions.
--
-- can be loaded into scripts and data
------------------------------------------------------------------------

local Constants = {}

--------------------------------------------------------------------------------
-- main constants
--------------------------------------------------------------------------------

-- the current version that is the result of the latest migration
Constants.current_version = 1

Constants.prefix = 'hps__is-'
Constants.name = 'inventory-sensor'
Constants.root = '__inventory-sensor-improved__'
Constants.gfx_location = Constants.root .. '/graphics/'
Constants.order = 'c[combinators]-d[inventory-sensor]'

--------------------------------------------------------------------------------
-- Framework intializer
--------------------------------------------------------------------------------

---@return FrameworkConfig config
function Constants.framework_init()
    return {
        -- prefix is the internal mod prefix
        prefix = Constants.prefix,
        -- name is a human readable name
        name = Constants.name,
        -- The filesystem root.
        root = Constants.root,
    }
end

--------------------------------------------------------------------------------
-- Path and name helpers
--------------------------------------------------------------------------------

---@param value string
---@return string result
function Constants:with_prefix(value)
    return self.prefix .. value
end

---@param path string
---@return string result
function Constants:png(path)
    return self.gfx_location .. path .. '.png'
end

---@param id string
---@return string result
function Constants:locale(id)
    return Constants:with_prefix('gui.') .. id
end

Constants.inventory_sensor_name = Constants:with_prefix(Constants.name)

--------------------------------------------------------------------------------
-- entity names and maps
--------------------------------------------------------------------------------

-- Base name
Constants.inventory_sensor_name = Constants:with_prefix(Constants.name)

--------------------------------------------------------------------------------
-- localization
--------------------------------------------------------------------------------

Constants.is_entity_name = 'entity-name.' .. Constants.inventory_sensor_name

--------------------------------------------------------------------------------
return Constants
