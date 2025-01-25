---@meta
------------------------------------------------------------------------
-- Manage GUIs and GUI state -- loosely inspired by flib
------------------------------------------------------------------------

-- only works in runtime mode
if not script then return {} end

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')

require('stdlib.utils.string')

local FrameworkGui = require('framework.gui')

local GUI_UPDATE_TICK_INTERVAL = 11

------------------------------------------------------------------------
-- types
------------------------------------------------------------------------

---@alias framework.gui.context table<string, any?>
---@alias framework.gui.update_callback fun(gui: framework.gui, context: framework.gui.context): boolean

---@class framework.gui_manager.create_gui
---@field player_index number
---@field parent LuaGuiElement
---@field ui_tree framework.gui.element_definitions The element definition, or an array of element definitions.
---@field existing_elements table<string, LuaGuiElement>? Optional set of existing GUI elements.
---@field context framework.gui.context? Context element
---@field entity_id number The entity for which a gui is created
---@field update_callback framework.gui.update_callback?

---@class framework.gui_manager
---@field GUI_PREFIX string The prefix for all registered handlers and other global information.
local FrameworkGuiManager = {
    GUI_PREFIX = Framework.PREFIX .. 'gui-',
}

------------------------------------------------------------------------
--
------------------------------------------------------------------------

---@return framework.gui_manager.state state Manages GUI state
function FrameworkGuiManager:state()
    local storage = Framework.runtime:storage()

    ---@class framework.gui_manager.state
    ---@field guis table<number, framework.gui> All registered and known guis for this manager.
    storage.gui_manager = storage.gui_manager or {
        guis = {},
    }

    return storage.gui_manager
end

------------------------------------------------------------------------

--- Dispatch an event to a registered gui.
---@param event framework.gui.event_data
---@return boolean handled True if an event handler was called, False otherwise.
function FrameworkGuiManager:dispatch(event)
    if not event then return false end

    ---@type LuaGuiElement
    local elem = event.element
    if not Is.Valid(elem) then return false end

    local player_index = event.player_index
    local gui = self:find_gui(player_index)
    if not gui then return false end

    -- dispatch to the UI instance
    return gui:dispatch(event)
end

------------------------------------------------------------------------

--- Finds a gui.
---@param player_index number
---@return framework.gui? framework_gui
function FrameworkGuiManager:find_gui(player_index)
    local state = self:state()
    return state.guis[player_index]
end

---@param player_index number
---@parameter gui framework.gui?
function FrameworkGuiManager:set_gui(player_index, gui)
    local state = self:state()
    state.guis[player_index] = gui
end

------------------------------------------------------------------------

--- Creates a new GUI instance.
---@param map framework.gui_manager.create_gui
---@return framework.gui A framework gui instance
function FrameworkGuiManager:create_gui(map)
    assert(map)
    assert(map.parent)
    assert(map.entity_id)

    assert(map.player_index)
    local player_index = map.player_index

    local ui_tree = map.ui_tree
    -- do not change to table_size, '#' returning 0 is the whole point of the check...
    assert(Is.Table(ui_tree) and #ui_tree == 0, 'The UI tree must have a single root!')

    local gui = FrameworkGui.create()
    gui.prefix = self.GUI_PREFIX
    gui.context = map.context or {}
    gui.update_callback = map.update_callback
    gui.entity_id = map.entity_id

    self:destroy_gui(player_index)
    self:set_gui(player_index, gui)

    local root = gui:add_child_elements(map.parent, ui_tree, map.existing_elements)
    gui.root = root

    self.gui_update_tick()

    return gui
end

------------------------------------------------------------------------

---@param entity_id integer?
function FrameworkGuiManager:destroy_gui_by_entity_id(entity_id)
    if not entity_id then return end

    local destroy_list = {}
    for _, player in pairs(game.players) do
        local gui = self:find_gui(player.index)
        if gui and gui.entity_id == entity_id then
            table.insert(destroy_list, player.index)
        end
    end

    for _, player_index in pairs(destroy_list) do
        self:destroy_gui(player_index)
    end
end

------------------------------------------------------------------------

--- Destroys a GUI instance.
---@param player_index number? The gui to destroy
function FrameworkGuiManager:destroy_gui(player_index)
    if not player_index then return end

    local gui = self:find_gui(player_index)
    if not gui then return end

    self:set_gui(player_index, nil)
    if gui.root then gui.root.destroy() end
end

------------------------------------------------------------------------
-- Update ticker
------------------------------------------------------------------------

function FrameworkGuiManager.gui_update_tick()
    local state = Framework.gui_manager:state()
    if table_size(state.guis) == 0 then return end

    local destroy_list = {}
    for gui_id, gui in pairs(state.guis) do
        if not gui:update() then
            table.insert(destroy_list, gui_id)
        end
    end

    if table_size(destroy_list) == 0 then return end

    for _, gui_id in pairs(destroy_list) do
        Framework.gui_manager:destroy_gui(gui_id)
    end
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    -- register all gui events with the framework
    for name, id in pairs(defines.events) do
        if name:starts_with('on_gui_') then
            Event.on_event(id, function(ev)
                Framework.gui_manager:dispatch(ev)
            end)
        end
    end

    Event.on_nth_tick(GUI_UPDATE_TICK_INTERVAL, FrameworkGuiManager.gui_update_tick)
end

Event.on_init(register_events)
Event.on_load(register_events)

return FrameworkGuiManager
