--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local Matchers = require('framework.matchers')

local const = require('lib.constants')

local Sensor = require('scripts.sensor')
local Migration = require('scripts.migration')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function onEntityCreated(event)
    local entity = event and event.entity

    assert(entity)

    if not (entity and entity.valid) then return end

    -- register entity for destruction
    script.register_on_object_destroyed(entity)

    local player_index = event.player_index
    local tags = event.tags

    local entity_ghost = Framework.ghost_manager:findGhostForEntity(entity)
    if entity_ghost then
        player_index = player_index or entity_ghost.player_index
        tags = tags or entity_ghost.tags or {}
    end

    local config = tags and tags[const.config_tag_name]

    This.SensorController:create(entity, config)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function onEntityDeleted(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    assert(entity.unit_number)

    This.SensorController:destroy(entity.unit_number)
    Framework.gui_manager:destroy_gui_by_entity_id(entity.unit_number)
end

---@param event EventData.on_object_destroyed
local function onObjectDestroyed(event)
    -- main entity destroyed
    This.SensorController:destroy(event.useful_id)
    Framework.gui_manager:destroy_gui_by_entity_id(event.useful_id)
end

--------------------------------------------------------------------------------
-- Entity move / rotate
--------------------------------------------------------------------------------

local function onEntityMoved(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end
    This.SensorController:move(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

---@param event EventData.on_entity_settings_pasted
local function onEntitySettingsPasted(event)
    local player = Player.get(event.player_index)

    if not (player and player.valid and player.force == event.source.force and player.force == event.destination.force) then return end

    local src_entity = This.SensorController:entity(event.source.unit_number)
    local dst_entity = This.SensorController:entity(event.destination.unit_number)

    if not (src_entity and dst_entity) then return end

    Sensor.reconfigure(dst_entity, src_entity.config)
end

--------------------------------------------------------------------------------
-- Entity cloning
--------------------------------------------------------------------------------

---@param event EventData.on_entity_cloned
local function onEntityCloned(event)
    if not (event.source and event.source.valid and event.destination and event.destination.valid) then return end

    local src_data = This.SensorController:entity(event.source.unit_number)
    if not src_data then return end

    This.SensorController:create(event.destination, src_data.config)
end

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

local function onConfigurationChanged()
    This.SensorController:init()

    -- enable inventory sensor if circuit network is researched.
    for _, force in pairs(game.forces) do
        if force.recipes[const.inventory_sensor_name] and force.technologies['circuit-network'] then
            force.recipes[const.inventory_sensor_name].enabled = force.technologies['circuit-network'].researched
        end
    end

    if Framework.settings:startup_setting(const.settings_update_inventory_sensors_name) then
        assert(migration)

        Migration:migrateSensors()
        Migration:migrateBlueprints()

        -- disconnect all entities, have them reconnect; this resets the config state of all entities
        for _, entity in pairs(This.SensorController:entities()) do
            Sensor.disconnect(entity)
        end
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
            if entity and entity.sensor_entity and entity.sensor_entity.valid then
                if Sensor.tick(entity) then
                    process_count = process_count - 1
                end
            elseif index then
                This.SensorController:destroy(index)
            end
        until process_count == 0 or not index
    end

    storage.last_tick_entity = index
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    local fi_entity_filter = Matchers:matchEventEntityName(const.inventory_sensor_name)

    -- Configuration changes (runtime and startup)
    Event.on_configuration_changed(onConfigurationChanged)

    Event.register(defines.events.on_tick, onTick)

    -- entity creation/deletion
    Event.register(Matchers.CREATION_EVENTS, onEntityCreated, fi_entity_filter)
    Event.register(Matchers.DELETION_EVENTS, onEntityDeleted, fi_entity_filter)

    -- entity destroy
    Event.register(defines.events.on_object_destroyed, onObjectDestroyed)

    Event.register(defines.events.on_player_rotated_entity, onEntityMoved, fi_entity_filter)

    -- Manage blueprint configuration setting
    Framework.blueprint:registerCallbackForNames(const.inventory_sensor_name, This.SensorController.serialize_config)

    Framework.ghost_manager:registerForName(const.inventory_sensor_name)

    -- manage tombstones for undo/redo and dead entities
    Framework.tombstone:registerCallback(const.inventory_sensor_name, {
        create_tombstone = This.SensorController.serialize_config,
        apply_tombstone = Framework.ghost_manager.mapTombstoneToGhostTags,
    })

    -- Entity settings pasting
    Event.register(defines.events.on_entity_settings_pasted, onEntitySettingsPasted, fi_entity_filter)

    -- Entity cloning
    Event.register(defines.events.on_entity_cloned, onEntityCloned, fi_entity_filter)
end

--------------------------------------------------------------------------------
-- mod init/load code
--------------------------------------------------------------------------------

local function on_init()
    This.SensorController:init()
    register_events()
end

local function on_load()
    register_events()
end

-- setup player management
Player.register_events(true)

-- mod init code
Event.on_init(on_init)
Event.on_load(on_load)
