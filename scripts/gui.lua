------------------------------------------------------------------------
-- Inventory Sensor GUI
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local Is = require('stdlib.utils.is')
local table = require('stdlib.utils.table')

local tools = require('framework.tools')
local Matchers = require('framework.matchers')
local signal_converter = require('framework.signal_converter')

local const = require('lib.constants')

local Sensor = require('scripts.sensor')

---@class InventorySensorGui
local Gui = {}

----------------------------------------------------------------------------------------------------
-- UI definition
----------------------------------------------------------------------------------------------------

--- Provides all the events used by the GUI and their mappings to functions. This must be outside the
--- GUI definition as it can not be serialized into storage.
---@return framework.gui_manager.event_definition
local function get_gui_event_definition()
    return {
        events = {
            onWindowClosed = Gui.onWindowClosed,
            onSwitchEnabled = Gui.onSwitchEnabled,
            onToggleGridRead = Gui.onToggleGridRead,
            onToggleGenVirtSignals = Gui.onToggleGenVirtSignals,
        },
        callback = Gui.guiUpdater,
    }
end

--- Returns the definition of the GUI. All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definition ui
function Gui.getUi(gui)
    local gui_events = gui.gui_events

    local is_data = This.SensorController:entity(gui.entity_id)
    assert(is_data)

    return {
        type = 'frame',
        name = 'gui_root',
        direction = 'vertical',
        handler = { [defines.events.on_gui_closed] = gui_events.onWindowClosed },
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
                        handler = { [defines.events.on_gui_click] = gui_events.onWindowClosed },
                    },
                },
            }, -- Title Bar End
            {  -- Body
                type = 'frame',
                style = 'entity_frame',
                style_mods = { width = 424, },
                children = {
                    {
                        type = 'flow',
                        style = 'two_module_spacing_vertical_flow',
                        direction = 'vertical',
                        children = {
                            {
                                type = 'frame',
                                direction = 'horizontal',
                                style = 'framework_subheader_frame',
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
                                        caption = 'ID: ' .. is_data.sensor_entity.unit_number,
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
                                        elem_mods = { entity = is_data.sensor_entity },
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
                                handler = { [defines.events.on_gui_switch_state_changed] = gui_events.onSwitchEnabled },
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
                            {
                                type = 'checkbox',
                                caption = { const:locale('read-grid') },
                                name = 'read-grid',
                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleGridRead },
                                state = false,
                            },
                            {
                                type = 'checkbox',
                                caption = { const:locale('provide-virtual-signals') },
                                name = 'provide-virtual-signals',
                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleGenVirtSignals },
                                state = false,
                            },
                            {
                                type = 'scroll-pane',
                                style = 'deep_slots_scroll_pane',
                                direction = 'vertical',
                                name = 'signal-view-pane',
                                visible = true,
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
            },
        },
    }
end

----------------------------------------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@param is_data inventory_sensor.Data?
function Gui.render_preview(gui, is_data)
    if not is_data then return end

    local signal_view = gui:find_element('signal-view')
    assert(signal_view)

    signal_view.clear()
    local section = Sensor.get_section(is_data)

    for _, filter in pairs(section.filters) do
        local button = signal_view.add {
            type = 'sprite-button',
            style = 'compact_slot',
            number = filter.min,
            sprite = signal_converter:logistic_filter_to_sprite_name(filter),
            tooltip = signal_converter:logistic_filter_to_prototype(filter).localised_name,
            elem_tooltip = signal_converter:logistic_filter_to_elem_id(filter),
        }
        if filter.value.quality and filter.value.quality ~= 'normal' then
            button.add {
                type = 'sprite',
                style = 'framework_quality',
                sprite = 'quality/' .. filter.value.quality,
                resize_to_sprite = false,
                enabled = true,
            }
        end
    end
end

----------------------------------------------------------------------------------------------------
-- UI Callbacks
----------------------------------------------------------------------------------------------------

--- close the UI (button or shortcut key)
---
---@param event EventData.on_gui_click|EventData.on_gui_closed
function Gui.onWindowClosed(event)
    Framework.gui_manager:destroy_gui(event.player_index)
end

local on_off_values = {
    left = false,
    right = true,
}

local values_on_off = table.invert(on_off_values)

--- Enable / Disable switch
---
---@param event EventData.on_gui_switch_state_changed
---@param gui framework.gui
function Gui.onSwitchEnabled(event, gui)
    local is_data = This.SensorController:entity(gui.entity_id)
    if not is_data then return end

    is_data.config.enabled = on_off_values[event.element.switch_state]
end

--- Enable / Disable reading grid
---
---@param event EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleGridRead(event, gui)
    local is_data = This.SensorController:entity(gui.entity_id)
    if not is_data then return end

    is_data.config.read_grid = event.element.state
end

--- Enable / Disable provide virtual signals
---
---@param event EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleGenVirtSignals(event, gui)
    local is_data = This.SensorController:entity(gui.entity_id)
    if not is_data then return end

    is_data.config.provide_virtual_signals = event.element.state
end

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@param is_data inventory_sensor.Data
local function update_config_gui_state(gui, is_data)
    local entity_status = (not is_data.config.enabled) and defines.entity_status.disabled -- if not enabled, status is disabled
        or is_data.config.status                                                          -- if enabled, the registered state takes precedence if present
        or defines.entity_status.working                                                  -- otherwise, it is working

    local lamp = gui:find_element('lamp')
    lamp.sprite = tools.STATUS_SPRITES[entity_status]

    local status = gui:find_element('status')
    status.caption = { tools.STATUS_NAMES[entity_status] }

    local read_grid = gui:find_element('read-grid')
    read_grid.state = is_data.config.read_grid or false

    local provide_virtual_signals = gui:find_element('provide-virtual-signals')
    provide_virtual_signals.state = is_data.config.provide_virtual_signals or false

    local inv_status = gui:find_element('inv-status')
    if is_data.config.enabled then
        if Is.Valid(is_data.scan_entity) then
            inv_status.caption = { const:locale('reading'), is_data.scan_entity.localised_name }
        else
            inv_status.caption = { const:locale('scanning') }
        end
    else
        inv_status.caption = { const:locale('disabled') }
    end

    local enabled = is_data.config.enabled
    local on_off = gui:find_element('on-off')
    on_off.switch_state = values_on_off[enabled]
end

---@param gui framework.gui
---@param is_data inventory_sensor.Data
local function update_gui_state(gui, is_data)
    Gui.render_preview(gui, is_data)

    local connections = gui:find_element('connections')
    connections.caption = { 'gui-control-behavior.not-connected' }
    for _, color in pairs { 'red', 'green' } do
        local wire_connector = is_data.sensor_entity.get_wire_connector(defines.wire_connector_id['circuit_' .. color], false)

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

---@param gui framework.gui
---@return boolean
function Gui.guiUpdater(gui)
    local is_data = This.SensorController:entity(gui.entity_id)
    if not is_data then return false end

    ---@type inventory_sensor.GuiContext
    local context = gui.context

    if not (context.last_config and table.compare(context.last_config, is_data.config)) then
        update_config_gui_state(gui, is_data)
        context.last_config = tools.copy(is_data.config)
    end

    -- always update wire state and preview
    update_gui_state(gui, is_data)

    return true
end

----------------------------------------------------------------------------------------------------
-- open gui handler
----------------------------------------------------------------------------------------------------

---@param event EventData.on_gui_opened
function Gui.onGuiOpened(event)
    local player = Player.get(event.player_index)
    if not player then return end

    -- close an eventually open gui
    Framework.gui_manager:destroy_gui(event.player_index)

    local entity = event and event.entity --[[@as LuaEntity]]
    if not entity then
        player.opened = nil
        return
    end

    assert(entity.unit_number)
    local is_data = This.SensorController:entity(entity.unit_number)

    if not is_data then
        log('Data missing for ' ..
            event.entity.name .. ' on ' .. event.entity.surface.name .. ' at ' .. serpent.line(event.entity.position) .. ' refusing to display UI')
        player.opened = nil
        return
    end

    ---@class inventory_sensor.GuiContext
    ---@field last_config inventory_sensor.Config?
    local gui_state = {
        last_config = nil,
    }

    local gui = Framework.gui_manager:create_gui {
        type = 'combinator-gui',
        player_index = event.player_index,
        parent = player.gui.screen,
        ui_tree_provider = Gui.getUi,
        context = gui_state,
        entity_id = entity.unit_number
    }

    player.opened = gui.root
end

function Gui.onGhostGuiOpened(event)
    local player = Player.get(event.player_index)
    if not player then return end

    player.opened = nil
end

----------------------------------------------------------------------------------------------------
-- Event registration
----------------------------------------------------------------------------------------------------

local function init_gui()
    Framework.gui_manager:register_gui_type('combinator-gui', get_gui_event_definition())

    local match_inventory_sensor = Matchers:matchEventEntityName(const.inventory_sensor_name)
    local match_ghost_inventory_sensor = Matchers:matchEventEntityGhostName(const.inventory_sensor_name)

    Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_inventory_sensor)
    Event.on_event(defines.events.on_gui_opened, Gui.onGhostGuiOpened, match_ghost_inventory_sensor)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
