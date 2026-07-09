--------------------------------------------------------------------------------
-- event setup for the mod
--------------------------------------------------------------------------------
assert(script)

local Event = require('stdlib.event.event')
local Player = require('stdlib.event.player')

local Matchers = require('framework.matchers')
local Ticker = require('framework.ticker')

local const = require('lib.constants')

local Sensor = require('scripts.sensor')
local Migration = require('scripts.migration')

--------------------------------------------------------------------------------
-- entity create / delete
--------------------------------------------------------------------------------

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
local function on_entity_created(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end

    ---@type Tags?
    local tags = event.tags

    local config = nil

    local entity_ghost = Framework.Ghost:findGhostForEntity(entity)
    if entity_ghost then
        tags = tags or entity_ghost.tags
    end

    if tags then
        config = This.SensorController.deserialize(tags)
    end

    This.SensorController:create(entity, config)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_entity_died | EventData.script_raised_destroy
local function on_entity_deleted(event)
    local entity = event.entity
    if not (entity and entity.valid) then return end
    assert(entity.unit_number)

    This.SensorController:destroy(entity.unit_number)
    Framework.gui_manager:destroyGuiByEntityId(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity move / rotate
--------------------------------------------------------------------------------

local function on_entity_moved(event)
    local entity = event and event.entity
    if not (entity and entity.valid) then return end
    This.SensorController:move(entity.unit_number)
end

--------------------------------------------------------------------------------
-- Entity settings pasting
--------------------------------------------------------------------------------

---@param event EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(event)
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
local function on_entity_cloned(event)
    if not (event.source and event.source.valid and event.destination and event.destination.valid) then return end

    local src_data = This.SensorController:entity(event.source.unit_number)
    if not src_data then return end

    This.SensorController:create(event.destination, src_data.config)
end

--------------------------------------------------------------------------------
-- Configuration changes (runtime and startup)
--------------------------------------------------------------------------------

local function on_configuration_changed()
    This.SensorController:init()

    -- enable inventory sensor if circuit network is researched.
    for _, force in pairs(game.forces) do
        if force.recipes[const.inventory_sensor_name] and force.technologies['circuit-network'] then
            force.recipes[const.inventory_sensor_name].enabled = force.technologies['circuit-network'].researched
        end
    end

    if Framework.settings:startup_setting(const.settings_update_inventory_sensors_name) then
        assert(Migration)

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

---@param keys ff2.ticker.TickerContext
---@param values ff2.ticker.TickerContext
---@return any
local function ticker_unit_of_work(keys, values)
    ---@type inventory_sensor.Data
    local sensor = values.sensor
    if sensor and sensor.sensor_entity and sensor.sensor_entity.valid then
        if Sensor.tick(sensor) then return end
    elseif keys.sensor then
        This.SensorController:destroy(keys.sensor)
    end
end

local function on_tick()
    local ticker_info = Ticker.getTicker('ticker')
    local tick_interval = Framework.settings:runtime_setting(const.settings_update_interval_name) or 10

    local entities = This.SensorController:entities()
    local entity_count = table_size(entities)
    if entity_count == 0 then return end

    local entities_per_tick = math.max(1, math.ceil(entity_count / tick_interval)) -- at least one

    local context = ticker_info.context or {}

    local iterator = Ticker.createWorkIterator {
        context = context,
        field_name = 'sensor',
        iterable = entities,
    }

    while entities_per_tick > 0 do
        iterator.process(ticker_unit_of_work)
        entities_per_tick = entities_per_tick - 1
    end

    ticker_info.context = context
    ticker_info.last_tick = game.tick
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    local fi_entity_filter = Matchers:matchEventEntityName(const.inventory_sensor_name)

    -- Configuration changes (runtime and startup)
    Event.on_configuration_changed(on_configuration_changed)

    Event.register(defines.events.on_tick, on_tick)

    -- entity creation/deletion
    Event.register(Matchers.CREATION_EVENTS, on_entity_created, fi_entity_filter)
    Event.register(Matchers.DELETION_EVENTS, on_entity_deleted, fi_entity_filter)

    Event.register(defines.events.on_player_rotated_entity, on_entity_moved, fi_entity_filter)

    -- Manage blueprint configuration setting
    Framework.blueprint:registerCallbackForNames(const.inventory_sensor_name, This.SensorController.serialize_config)

    Framework.Ghost:registerForName {
        names = const.inventory_sensor_name
    }

    -- manage tombstones for undo/redo and dead entities
    Framework.Tombstone:registerCallback(const.inventory_sensor_name, {
        create_tombstone = This.SensorController.serialize_config,
        apply_tombstone = Framework.Ghost.mapTombstoneToGhostTags,
    })

    -- Entity settings pasting
    Event.register(defines.events.on_entity_settings_pasted, on_entity_settings_pasted, fi_entity_filter)

    -- Entity cloning
    Event.register(defines.events.on_entity_cloned, on_entity_cloned, fi_entity_filter)
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
