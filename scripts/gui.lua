------------------------------------------------------------------------
-- Inventory Sensor GUI
------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

local tools = require('framework.tools')
local Matchers = require('framework.matchers')
local signal_converter = require('framework.signal_converter')

local const = require('lib.constants')

local Sensor = require('scripts.sensor')

local GUI_NAME = 'inventory-sensor-gui'

---@class inventory_sensor.Gui
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
            onToggleInventoryStatusSignals = Gui.onToggleInventoryStatusSignals,
            onToggleInventorySelect = Gui.onToggleInventorySelect,
            onToggleChangeRequestMode = Gui.onToggleChangeRequestMode,
            onToggleRequestInvert = Gui.onToggleRequestInvert,
        },
        callback = Gui.guiUpdater,
    }
end

--- Returns the definition of the GUI. All events must be mapped onto constants from the gui_events array.
---@param gui framework.gui
---@return framework.gui.element_definition ui
function Gui.getUi(gui)
    local gui_events = gui.gui_events

    local sensor_data = This.SensorController:entity(gui.entity_id)
    assert(sensor_data)

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
                                        name = 'entity-lamp',
                                        style = 'framework_indicator',
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        name = 'entity-status',
                                    },
                                    {
                                        type = 'empty-widget',
                                        style_mods = { horizontally_stretchable = true },
                                    },
                                    {
                                        type = 'label',
                                        style = 'label',
                                        caption = { const:locale('id'), sensor_data.sensor_entity.unit_number },
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
                                        elem_mods = { entity = sensor_data.sensor_entity },
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
                                        caption = { const:locale('status-label') },
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
                                },
                            },
                            {
                                type = 'checkbox',
                                caption = { const:locale('inventory-status-signals') },
                                tooltip = { const:locale('inventory-status-signals-tooltip') },
                                name = 'inventory-status-signals',
                                handler = { [defines.events.on_gui_checked_state_changed] = gui_events.onToggleInventoryStatusSignals },
                                state = false,
                            },
                            {
                                type = 'line',
                            },
                            {
                                type = 'label',
                                style = 'semibold_label',
                                caption = { const:locale('inventories-heading') },
                            },
                            {
                                type = 'table',
                                name = 'inventories',
                                column_count = 3,
                                style_mods = {
                                    top_margin = -8,         -- pull the table a bit closer to the label above
                                    horizontal_spacing = 24, -- space the elements in the table out
                                },
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
---@param sensor_data inventory_sensor.Data?
function Gui.render_preview(gui, sensor_data)
    if not sensor_data then return end

    local signal_view = gui:find_element('signal-view')
    assert(signal_view)

    signal_view.clear()
    local section = Sensor.get_section(sensor_data)

    for _, filter in pairs(section.filters) do
        local button = signal_view.add {
            type = 'sprite-button',
            style = 'compact_slot',
            number = filter.min,
            quality = filter.value.quality,
            sprite = signal_converter:logistic_filter_to_sprite_name(filter),
            tooltip = signal_converter:logistic_filter_to_prototype(filter).localised_name,
            elem_tooltip = signal_converter:logistic_filter_to_elem_id(filter),
        }
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
    local sensor_data = This.SensorController:entity(gui.entity_id)
    if not sensor_data then return end

    sensor_data.config.enabled = on_off_values[event.element.switch_state]
end

--- Enable / Disable provide virtual signals
---
---@param event EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleInventoryStatusSignals(event, gui)
    local sensor_data = This.SensorController:entity(gui.entity_id)
    if not sensor_data then return end

    sensor_data.config.inventory_status = event.element.state
end

---@param event EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleInventorySelect(event, gui)
    local sensor_data = This.SensorController:entity(gui.entity_id)
    if not sensor_data then return end

    local selected = assert(sensor_data.config.contributors[event.element.tags.inventory_name])
    selected.enabled = event.element.state
end

---@param event EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleChangeRequestMode(event, gui)
    local sensor_data = This.SensorController:entity(gui.entity_id)
    if not sensor_data then return end

    local selected = assert(sensor_data.config.contributors[event.element.tags.inventory_name])
    if event.element.state then selected.mode = assert(event.element.tags.report_state) end
end

---@param event EventData.on_gui_checked_state_changed
---@param gui framework.gui
function Gui.onToggleRequestInvert(event, gui)
    local sensor_data = This.SensorController:entity(gui.entity_id)
    if not sensor_data then return end

    local selected = assert(sensor_data.config.contributors[event.element.tags.inventory_name])
    selected.inverted = event.element.state
end

----------------------------------------------------------------------------------------------------
-- GUI state updater
----------------------------------------------------------------------------------------------------

---@param gui framework.gui
---@param sensor_data inventory_sensor.Data
local function update_config_gui_state(gui, sensor_data)
    local sensor_status = (not sensor_data.config.enabled) and defines.entity_status.disabled -- if not enabled, status is disabled
        or sensor_data.state.status                                                           -- if enabled, the registered state takes precedence if present
        or defines.entity_status.working                                                      -- otherwise, it is working

    local entity_lamp = gui:find_element('entity-lamp')
    entity_lamp.sprite = tools.STATUS_SPRITES[sensor_status]

    local entity_status = gui:find_element('entity-status')
    entity_status.caption = { tools.STATUS_NAMES[sensor_status] }

    local status = gui:find_element('status')
    if sensor_data.config.enabled then
        if (sensor_data.scan_entity and sensor_data.scan_entity.valid) then
            status.caption = { const:locale('reading'), sensor_data.scan_entity.localised_name, sensor_data.scan_entity.unit_number }
        else
            status.caption = { const:locale('scanning') }
        end
    else
        status.caption = { const:locale('disabled') }
    end

    local enabled = sensor_data.config.enabled
    local on_off = gui:find_element('on-off')
    on_off.switch_state = values_on_off[enabled]

    -- update inventories

    local inventory_element = assert(gui:find_element('inventories'))
    gui:remove_children('inventories')

    local enabled_count = 0
    -- show all configurable contributors
    for name, contributor_info in pairs(sensor_data.config.contributors) do
        local contributor_state = sensor_data.state.contributors[name]
        local contributor_enabled = contributor_state and contributor_state.enabled or false
        if not contributor_enabled then
            local inventory_config = assert(sensor_data.config.contributors[name])
            enabled_count = enabled_count + (inventory_config.enabled and 1 or 0)
            local config_enabled = enabled and (contributor_state and true or false)

            -- each row has three children: checkbox, radiobuttons and invert
            gui:add_child_elements(inventory_element, {
                {
                    type = 'checkbox',
                    caption = contributor_info.name,
                    name = name .. '-select',
                    elem_tags = { inventory_name = name },
                    handler = { [defines.events.on_gui_checked_state_changed] = gui.gui_events.onToggleInventorySelect },
                    state = inventory_config.enabled,
                    enabled = config_enabled,
                },
                {
                    type = 'flow',
                    direction = 'vertical',
                    children = {
                        {
                            type = 'radiobutton',
                            caption = { '', { const:locale('report-quantity') }, ' [img=info]' },
                            tooltip = { const:locale('report-quantity-description') },
                            name = name .. '-quantity',
                            elem_tags = {
                                inventory_name = name,
                                report_state = 'quantity',
                            },
                            handler = { [defines.events.on_gui_checked_state_changed] = gui.gui_events.onToggleChangeRequestMode },
                            enabled = config_enabled and inventory_config.enabled,
                            state = inventory_config.mode == 'quantity',
                        },
                        {
                            type = 'radiobutton',
                            caption = { const:locale('report-one') },
                            name = name .. '-one',
                            elem_tags = {
                                inventory_name = name,
                                report_state = 'one',
                            },
                            handler = { [defines.events.on_gui_checked_state_changed] = gui.gui_events.onToggleChangeRequestMode },
                            enabled = config_enabled and inventory_config.enabled,
                            state = inventory_config.mode == 'one',
                        },
                    }
                },
                {
                    type = 'checkbox',
                    caption = { '', { const:locale('report-invert') }, ' [img=info]' },
                    tooltip = { const:locale('report-invert-description') },
                    name = name .. '-invert',
                    elem_tags = { inventory_name = name, },
                    handler = { [defines.events.on_gui_checked_state_changed] = gui.gui_events.onToggleRequestInvert },
                    enabled = config_enabled and inventory_config.enabled,
                    state = inventory_config.inverted or false,
                },
            })
        end
    end

    local inventory_status = gui:find_element('inventory-status-signals')
    inventory_status.state = sensor_data.config.inventory_status or false
    inventory_status.enabled = enabled and (enabled_count < 2)
end

---@param gui framework.gui
---@param sensor_data inventory_sensor.Data
local function update_gui_state(gui, sensor_data)
    Gui.render_preview(gui, sensor_data)

    local connections = gui:find_element('connections')
    connections.caption = { 'gui-control-behavior.not-connected' }
    for _, color in pairs { 'red', 'green' } do
        local wire_connector = sensor_data.sensor_entity.get_wire_connector(defines.wire_connector_id['circuit_' .. color], false)

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
    local sensor_data = This.SensorController:entity(gui.entity_id)
    if not sensor_data then return false end

    ---@type inventory_sensor.GuiContext
    local context = gui.context

    if not (context.last_config and table.compare(context.last_config, sensor_data.config))
        or not (context.last_state and table.compare(context.last_state, sensor_data.state)) then
        update_config_gui_state(gui, sensor_data)
        context.last_config = util.copy(sensor_data.config)
        context.last_state = util.copy(sensor_data.state)
    end

    -- always update wire state and preview
    update_gui_state(gui, sensor_data)

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
    local sensor_data = This.SensorController:entity(entity.unit_number)

    if not sensor_data then
        log('Data missing for ' ..
            event.entity.name .. ' on ' .. event.entity.surface.name .. ' at ' .. serpent.line(event.entity.position) .. ' refusing to display UI')
        player.opened = nil
        return
    end

    ---@class inventory_sensor.GuiContext
    ---@field last_config inventory_sensor.Config?
    ---@field last_state inventory_sensor.State?
    local gui_state = {
        last_config = nil,
        last_state = nil,
    }

    local gui = Framework.gui_manager:create_gui {
        type = GUI_NAME,
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
    Framework.gui_manager:register_gui_type(GUI_NAME, get_gui_event_definition())

    local match_inventory_sensor = Matchers:matchEventEntityName(const.inventory_sensor_name)
    local match_ghost_inventory_sensor = Matchers:matchEventEntityGhostName(const.inventory_sensor_name)

    Event.on_event(defines.events.on_gui_opened, Gui.onGuiOpened, match_inventory_sensor)
    Event.on_event(defines.events.on_gui_opened, Gui.onGhostGuiOpened, match_ghost_inventory_sensor)
end

Event.on_init(init_gui)
Event.on_load(init_gui)

return Gui
