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
                        caption = { 'entity-name.' .. const.inventory_sensor_name },
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
                style = 'inside_shallow_frame_packed',
                direction = 'vertical',
                children = {
                    {
                        type = 'frame',
                        direction = 'horizontal',
                        children = {
                            {
                                type = 'label',
                                style = 'subheader_label',
                                name = 'connections',
                            },
                            {
                                type = 'label',
                                style = 'label',
                                name = 'connection-red',
                                visible = false,
                            },
                            {
                                type = 'label',
                                style = 'label',
                                name = 'connection-green',
                                visible = false,
                            },
                            {
                                type = 'empty-widget',
                                style_mods = { horizontally_stretchable = true },
                            },
                        },
                    },
                    {
                        type = 'frame',
                        style = 'entity_frame',
                        style_mods = { width = 400, },
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
                                    {
                                        type = 'label',
                                        style = 'semibold_label',
                                        caption = { 'gui-constant.output' },
                                    },
                                    {
                                        type = 'switch',
                                        name = 'on-off',
                                        right_label_caption = { 'gui-constant.on' },
                                        left_label_caption = { 'gui-constant.off' },
                                        handler = { [defines.events.on_gui_switch_state_changed] = Gui.onSwitchEnabled },
                                    },
                                    {
                                        type = 'flow',
                                        style = 'framework_indicator_flow',
                                        children = {
                                            {
                                                type = 'label',
                                                style = 'semibold_label',
                                                caption = { const:locale('inv-status-label') },
                                            },
                                            {
                                                type = 'label',
                                                style = 'label',
                                                name = 'inv-status',
                                            },
                                            {
                                                type = 'empty-widget',
                                                style_mods = { horizontally_stretchable = true },
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    {
                        type = 'scroll-pane',
                        style = 'logistic_sections_scroll_pane',
                        direction = 'vertical',
                        name = 'signal-view-pane',
                        visible = false,
                        vertical_scroll_policy = 'auto-and-reserve-space',
                        horizontal_scroll_policy = 'never',
                        style_mods = {
                            horizontally_stretchable = true,
                        },
                        children = {
                            {
                                type = 'table',
                                style = 'filter_slot_table',
                                name = 'signal-view',
                                column_count = 10,
                                style_mods = {
                                    vertical_spacing = 4,
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
-- helpers
----------------------------------------------------------------------------------------------------

---@param is_entity InventorySensorData?
---@param gui FrameworkGui
function Gui.renderPreview(is_entity, gui)
    if not is_entity then return end

    local signal_view = gui:find_element('signal-view')
    assert(signal_view)
    local signal_view_pane = gui:find_element('signal-view-pane')
    assert(signal_view_pane)

    for _, c in pairs(signal_view.children) do c.destroy() end

    local control = is_entity.sensor_entity.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior ]]

    if is_entity.config.enabled and control.sections_count > 0 and control.sections[1].filters_count > 0 then
        signal_view_pane.visible = true
        for _, filter in pairs(control.sections[1].filters) do
            -- item -> item
            -- fluid -> fluid
            -- virtual -> virtual_signal
            -- <absent> -> item
            local signal_type = (filter.value.type == 'virtual' and 'virtual_signal') or filter.value.type or 'item'
            local signal_name = filter.value.name
            local sprite_type = (signal_type == 'virtual_signal' and 'virtual-signal') or signal_type

            local button = {
                type = 'sprite-button',
                sprite = sprite_type .. '/' .. signal_name,
                number = filter.min,
                style = 'compact_slot', -- 'slot_button',
                tooltip = prototypes[signal_type][signal_name].localised_name,
            }

            if signal_type == 'item' then
                button.elem_tooltip = {
                    type = 'item-with-quality',
                    name = signal_name,
                    quality = filter.value.quality,
                }
            elseif signal_type == 'virtual_signal' then
                button.elem_tooltip = {
                    type = 'signal',
                    signal_type = 'virtual', -- see https://forums.factorio.com/viewtopic.php?f=7&t=123237
                    name = signal_name,
                }
            else
                button.elem_tooltip = {
                    type = signal_type,
                    name = signal_name,
                }
            end

            signal_view.add(button)
        end
    else
        signal_view_pane.visible = false
    end
end

----------------------------------------------------------------------------------------------------
-- close methods
----------------------------------------------------------------------------------------------------

---@param player_index integer?
function Gui.closeByPlayer(player_index)
    if not player_index then return end

    local player, player_data = Player.get(player_index)
    if not player then return end

    local gui = player_data.is_gui

    if (not gui) then return end

    Event.remove(-1, Gui.guiUpdater, nil, gui)
    player_data.is_gui = nil
    Framework.gui_manager:destroy_gui(gui.gui)
end

---@param unit_number integer?
function Gui.closeByEntity(unit_number)
    if not unit_number then return end

    for _, player in pairs(game.players) do
        if player.opened then
            local player_data = Player.pdata(player.index)
            if player_data and player_data.is_gui and player_data.is_gui.is_id == unit_number then
                Gui.closeByPlayer(player.index)
            end
        end
    end
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
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
    Gui.closeByPlayer(event.player_index)
end

local on_off_values = {
    left = false,
    right = true,
}

local values_on_off = table.invert(on_off_values)

--- Enable / Disable switch
---
---@param event EventData.on_gui_switch_state_changed
function Gui.onSwitchEnabled(event)
    local is_entity = locate_config(event)
    if not is_entity then return end

    is_entity.config.enabled = on_off_values[event.element.switch_state]
end

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui FrameworkGui
---@param is_entity InventorySensorData
local function update_config_gui_state(gui, is_entity)
    local entity_status = (not is_entity.config.enabled) and defines.entity_status.disabled -- if not enabled, status is disabled
        or is_entity.config.status                                                          -- if enabled, the registered state takes precedence if present
        or defines.entity_status.working                                                    -- otherwise, it is working

    local lamp = gui:find_element('lamp')
    lamp.sprite = tools.STATUS_SPRITES[entity_status]

    local status = gui:find_element('status')
    status.caption = { tools.STATUS_NAMES[entity_status] }

    local inv_status = gui:find_element('inv-status')
    if is_entity.config.enabled then
        if is_entity.scan_entity then
            inv_status.caption = { const:locale('reading'), is_entity.scan_entity.localised_name }
        else
            inv_status.caption = { const:locale('scanning') }
        end
    else
        inv_status.caption = { const:locale('disabled') }
    end

    local enabled = is_entity.config.enabled
    local on_off = gui:find_element('on-off')
    on_off.switch_state = values_on_off[enabled]
end

---@param gui FrameworkGui
---@param is_entity InventorySensorData
local function update_gui_state(gui, is_entity)
    Gui.renderPreview(is_entity, gui)

    local connections = gui:find_element('connections')
    connections.caption = { 'gui-control-behavior.not-connected' }
    for _, color in pairs { 'red', 'green' } do
        local wire_connector = is_entity.sensor_entity.get_wire_connector(defines.wire_connector_id['circuit_' .. color], false)

        local wire_connection = gui:find_element('connection-' .. color)
        if wire_connector and wire_connector.connection_count > 0 then
            connections.caption = { 'gui-control-behavior.connected-to-network' }
            wire_connection.visible = true
            wire_connection.caption = { 'gui-control-behavior.' .. color .. '-network-id', wire_connector.network_id }
        else
            wire_connection.visible = false
            wire_connection.caption = nil
        end
    end
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
        update_config_gui_state(is_gui.gui, is_entity)
        is_gui.last_config = tools.copy(is_entity.config)
    end

    -- always update wire state and preview
    update_gui_state(is_gui.gui, is_entity)
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
function Gui.onGuiOpened(event)
    local player, player_data = Player.get(event.player_index)
    if not (player and player_data) then return end

    -- close an eventually open gui
    Gui.closeByPlayer(event.player_index)

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

function Gui.onGhostGuiOpened(event)
    local player, player_data = Player.get(event.player_index)
    if not (player and player_data) then return end

    player.opened = nil
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local match_inventory_sensor = tools.create_event_entity_matcher('name', const.inventory_sensor_name)
local match_ghost_inventory_sensor = tools.create_event_ghost_entity_matcher('ghost_name', const.inventory_sensor_name)

Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_inventory_sensor)
Event.on_event(defines.events.on_gui_opened, Gui.onGhostGuiOpened, match_ghost_inventory_sensor)

return Gui
