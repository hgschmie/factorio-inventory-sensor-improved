---@meta
------------------------------------------------------------------------
-- Inventory Sensor GUI
------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

local tools = require('framework.tools')

local const = require('lib.constants')

---@class InventorySensorGui
local Gui = {}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

---@param is_entity InventorySensorData
---@return FrameworkGuiElemDef ui
function Gui.getUi(is_entity)
    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = { [defines.events.on_gui_closed] = Gui.onWindowClosed },
        elem_mods = { auto_center = true },
        children = {
            { -- Title Bar
                type = 'flow',
                style = 'frame_header_flow',
                drag_target = 'gui_root',
                children = {
                    {
                        type = 'label',
                        style = 'frame_title',
                        caption = { const.locale.entity_name },
                        drag_target = 'gui_root',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'empty-widget',
                        style = 'framework_titlebar_drag_handle',
                        ignored_by_interaction = true,
                    },
                    {
                        type = 'sprite-button',
                        style = 'frame_action_button',
                        sprite = 'utility/close',
                        hovered_sprite = 'utility/close_black',
                        clicked_sprite = 'utility/close_black',
                        mouse_button_filter = { 'left' },
                        handler = { [defines.events.on_gui_click] = Gui.onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {  -- Body
                type = 'frame',
                style = 'entity_frame',
                children = {
                    {
                        type = 'flow',
                        style = 'two_module_spacing_vertical_flow',
                        direction = 'vertical',
                        children = {
                            {
                                type = 'flow',
                                style = 'framework_indicator_flow',
                                children = {
                                    {
                                        type = 'sprite',
                                        name = 'lamp',
                                        style = 'framework_indicator',
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'status',
                                    },
                                    {
                                        type = 'empty-widget',
                                        name = 'spacer',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        caption = 'ID: ' .. is_entity.sensor_entity.unit_number,
                                    },
                                },
                            },
                            {
                                type = 'frame',
                                style = 'deep_frame_in_shallow_frame',
                                name = 'preview_frame',
                                children = {
                                    {
                                        type = 'entity-preview',
                                        name = 'preview',
                                        style = 'wide_entity_button',
                                        elem_mods = { entity = is_entity.sensor_entity },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
    }
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_switch_state_changed|EventData.on_gui_checked_state_changed|EventData.on_gui_elem_changed
---@return InventorySensorData? is_entity
local function locate_config(event)
    local _, player_data = Player.get(event.player_index)
    if not (player_data and player_data.is_gui) then return nil end

    return This.SensorController:entity(player_data.is_gui.is_id) --[[@as InventorySensorData? ]]
end

--- close the UI (button or shortcut key)
---
---@param event EventData.on_gui_click|EventData.on_gui_opened
function Gui.onWindowClosed(event)
    local player, player_data = Player.get(event.player_index)

    local gui = player_data.is_gui

    if (gui) then
        if player.opened == player_data.is_gui.gui.root then
            player.opened = nil
        end

        Event.remove(-1, Gui.guiUpdater, nil, gui)
        player_data.is_gui = nil

        if gui.gui then
            Framework.gui_manager:destroy_gui(gui.gui)
        end
    end
end

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui FrameworkGui
---@param is_entity InventorySensorData
local function update_gui_state(gui, is_entity)
    local entity_status = (not is_entity.config.enabled) and defines.entity_status.disabled -- if not enabled, status is disabled
        or is_entity.config.status                                                          -- if enabled, the registered state takes precedence if present
        or defines.entity_status.working                                                    -- otherwise, it is working

    local lamp = gui:find_element('lamp')
    lamp.sprite = tools.STATUS_SPRITES[entity_status]

    local status = gui:find_element('status')
    status.caption = { tools.STATUS_NAMES[entity_status] }
end

----------------------------------------------------------------------------------------------------
-- Event ticker
----------------------------------------------------------------------------------------------------

---@param is_gui InventorySensorGui
function Gui.guiUpdater(ev, is_gui)
    local is_entity = This.SensorController:entity(is_gui.is_id) --[[@as InventorySensorData ]]
    if not is_entity then
        Event.remove(-1, Gui.guiUpdater, nil, is_gui)
        return
    end

    if not (is_gui.last_config and table.compare(is_gui.last_config, is_entity.config)) then
        update_gui_state(is_gui.gui, is_entity)
        is_gui.last_config = tools.copy(is_entity.config)
    end
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
function Gui.onGuiOpened(event)
    local player, player_data = Player.get(event.player_index)
    if player.opened and player_data.is_gui and player.opened == player_data.is_gui.gui.root then
        player.opened = nil
    end

    -- close an eventually open gui
    Gui.onWindowClosed(event)

    local entity = event and event.entity --[[@as LuaEntity]]
    local is_id = entity.unit_number --[[@as integer]]
    local is_entity = This.SensorController:entity(is_id) --[[@as InventorySensorData ]]

    if not is_entity then
        log('Data missing for ' ..
            event.entity.name .. ' on ' .. event.entity.surface.name .. ' at ' .. serpent.line(event.entity.position) .. ' refusing to display UI')
        player.opened = nil
        return
    end

    local gui = Framework.gui_manager:create_gui(player.gui.screen, Gui.getUi(is_entity))

    ---@class InventorySensorGui
    ---@field gui FrameworkGui
    ---@field is_id integer
    ---@field last_config InventorySensorData?
    player_data.is_gui = {
        gui = gui,
        is_id = is_id,
        last_config = nil,
    }

    Event.register(-1, Gui.guiUpdater, nil, player_data.is_gui)

    player.opened = gui.root
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local match_inventory_sensor = tools.create_event_entity_matcher('name', const.inventory_sensor_name)

Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_inventory_sensor)

return Gui
