---@meta
----------------------------------------------------------------------------------------------------
--- framework types
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- ghost_manager.lua
----------------------------------------------------------------------------------------------------

---@class FrameworkAttachedEntity
---@field entity LuaEntity
---@field name string?
---@field position MapPosition?
---@field orientation float?
---@field tags Tags?
---@field player_index integer
---@field tick integer

---@class FrameworkGhostManagerState
---@field ghost_entities FrameworkAttachedEntity[]

----------------------------------------------------------------------------------------------------
--- gui.lua
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
--- init.lua
----------------------------------------------------------------------------------------------------

---@class FrameworkConfig
---@field name string The human readable name for the module
---@field prefix string A prefix for all game registered elements
---@field root string The module root name
---@field log_tag string? A custom logger tag
---@field remote_name string? The name for the remote interface. If defined, the mod will have a remote interface.

----------------------------------------------------------------------------------------------------
--- settings.lua
----------------------------------------------------------------------------------------------------

---@alias FrameworkSettingsStorage table<string, (FrameworkSettingValue|table<string, FrameworkSettingValue?>)?>?

---@class FrameworkSettingsProvider
---@field values FrameworkSettingsStorage
---@field load_value fun(name: string, player_index: integer?): ModSetting?
---@field store_value fun(name: string, value: FrameworkSettingValue, player_index: integer?)?
---@field get_values fun(self: FrameworkSettingsProvider, player_index: integer?): FrameworkSettingsStorage
---@field set_values fun(self: FrameworkSettingsProvider, values: table<string, FrameworkSettingValue?>, player_index: integer?)
---@field clear fun(self: FrameworkSettingsProvider, player_index: integer?)

---@alias FrameworkSettingValue (int)|(double)|(boolean)|(string)|(Color)

---@class FrameworkSetting
---@field key string
---@field value FrameworkSettingValue

---@alias FrameworkSettingsGroup table<string, FrameworkSetting>
