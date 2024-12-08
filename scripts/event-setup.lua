---@meta
--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Player = require('stdlib.event.player')
local tools = require('framework.tools')
local const = require('lib.constants')

local Gui = require('scripts.gui')
local Sensor = require('scripts.sensor')


--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function onInitInvSensor()
    This.SensorController:init()
end

local function onLoadInvSensor()
end

--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onEntityCreated(event)
    local entity = event and event.entity

    assert(entity)

    if not Is.Valid(entity) then return end

    -- register entity for destruction
    script.register_on_object_destroyed(entity)

    local player_index = event.player_index
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findMatchingGhost(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
        tags = tags or entity_ghost.tags or {}
    end

    This.SensorController:create(entity, tags)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onEntityDeleted(event)
    local entity = event and event.entity
    if not entity then return end

    local unit_number = entity.unit_number

    This.SensorController:destroy(unit_number)
    Gui.closeByEntity(unit_number)
end

---@param event EventData.on_object_destroyed
local function onEntityDestroyed(event)
    -- or a main entity?
    local is_entity = This.SensorController:entity(event.useful_id)
    if is_entity then
        -- main entity destroyed
        This.SensorController:destroy(event.useful_id)
        Gui.closeByEntity(event.useful_id)
    end
end

--------------------------------------------------------------------------------
-- Entity move / rotate
--------------------------------------------------------------------------------

local function onEntityMoved(event)
    local entity = event and event.entity
    if not Is.Valid(entity) then return end
    This.SensorController:move(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

---@param event EventData.on_entity_settings_pasted
local function onEntitySettingsPasted(event)
    local player = Player.get(event.player_index)

    if not (Is.Valid(player) and player.force == event.source.force and player.force == event.destination.force) then return end

    local src_entity = This.SensorController:entity(event.source.unit_number)
    local dst_entity = This.SensorController:entity(event.destination.unit_number)

    if not (src_entity and dst_entity) then return end

    dst_entity:reconfigure(src_entity.config)
end

--------------------------------------------------------------------------------
-- Entity cloning
--------------------------------------------------------------------------------

---@param event EventData.on_entity_cloned
local function onEntityCloned(event)
    -- Space Exploration Support
    if not (Is.Valid(event.source) and Is.Valid(event.destination)) then return end

    local src_data = This.SensorController:entity(event.source.unit_number)
    if not src_data then return end

    local tags = { is_config = src_data.config } -- clone the config from the src to the destination

    This.SensorController:create(event.destination, tags)
end

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

---@param changed ConfigurationChangedData?
local function onConfigurationChanged(changed)
    This.SensorController:init()

    -- enable inventory sensor if circuit network is researched.
    for _, force in pairs(game.forces) do
        if force.recipes[const.inventory_sensor_name] and force.technologies['circuit-network'] then
            force.recipes[const.inventory_sensor_name].enabled = force.technologies['circuit-network'].researched
        end
    end

    if Framework.settings:startup_setting(const.settings_update_inventory_sensors_name) then
        for _, surface in pairs(game.surfaces) do
            local entities_to_replace = surface.find_entities_filtered {
                type = 'constant-combinator',
                name = 'item-sensor'
            }

            for _, entity_to_replace in pairs(entities_to_replace) do
                local can_fast_replace = surface.can_fast_replace {
                    name = const.inventory_sensor_name,
                    position = entity_to_replace.position,
                    direction = entity_to_replace.direction,
                    force = entity_to_replace.force,
                }

                local main_entity = surface.create_entity {
                    name = prototypes.entity[const.inventory_sensor_name],
                    position = entity_to_replace.position,
                    direction = entity_to_replace.direction,
                    force = entity_to_replace.force,
                    fast_replace = true,
                }
                if main_entity then
                    This.SensorController:create(main_entity)
                    entity_to_replace.destroy()
                end
            end
        end
    end

    -- disconnect all entities, have them reconnect; this resets the config state of all entities
    for _, entity in pairs(This.SensorController:entities()) do
        entity:disconnect()
    end
end

--------------------------------------------------------------------------------
-- Ticker
--------------------------------------------------------------------------------

local function onTick()
    local interval = Framework.settings:runtime_setting(const.settings_update_interval_name) or 10
    local entities = This.SensorController:entities()
    local process_count = math.ceil(table_size(entities) / interval)
    local index = storage.last_tick_entity
    local entity

    if table_size(entities) == 0 then
        index = nil
    else
        repeat
            index, entity = next(entities, index)
            if entity then
                Sensor.enhance(entity)
                if Is.Valid(entity.sensor_entity) then
                    if entity:tick() then
                        process_count = process_count - 1
                    end
                else
                    This.SensorController:destroy(index)
                end
            end
        until process_count == 0 or not index
    end
    storage.last_tick_entity = index
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local fi_entity_filter = tools.create_event_entity_matcher('name', const.inventory_sensor_name)

-- mod init code
Event.on_init(onInitInvSensor)
Event.on_load(onLoadInvSensor)

-- Configuration changes (runtime and startup)
Event.on_configuration_changed(onConfigurationChanged)
Event.register(defines.events.on_runtime_mod_setting_changed, onConfigurationChanged)

Event.register(defines.events.on_tick, onTick)

-- entity creation/deletion
tools.event_register(tools.CREATION_EVENTS, onEntityCreated, fi_entity_filter)
tools.event_register(tools.DELETION_EVENTS, onEntityDeleted, fi_entity_filter)

-- entity destroy
Event.register(defines.events.on_object_destroyed, onEntityDestroyed, fi_entity_filter)

Event.register(defines.events.on_player_rotated_entity, onEntityMoved, fi_entity_filter)

-- manage ghost building (robot building) Register all ghosts we are interested in
Framework.ghost_manager:register_for_ghost_names(const.inventory_sensor_name)

-- Manage blueprint configuration setting
Framework.blueprint:register_callback(const.inventory_sensor_name, This.SensorController.blueprint_callback)

-- Entity settings pasting
Event.register(defines.events.on_entity_settings_pasted, onEntitySettingsPasted, fi_entity_filter)

-- Entity cloning
Event.register(defines.events.on_entity_cloned, onEntityCloned, fi_entity_filter)
