---@meta
--------------------------------------------------------------------------------
-- stack combinator migration
--------------------------------------------------------------------------------
assert(script)

local util = require('util')

local Position = require('stdlib.area.position')
local Is = require('stdlib.utils.is')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

if not Framework.settings:startup_setting(const.settings_update_inventory_sensors_name) then return nil end

---@class inventory_sensor.Migration
---@field stats table<string, number>
local Migration = {
    stats = {},
}

---@param src LuaEntity
---@param dst LuaEntity
local function copy_wire_connections(src, dst)
    for wire_connector_id, wire_connector in pairs(src.get_wire_connectors(true)) do
        local dst_connector = dst.get_wire_connector(wire_connector_id, true)
        for _, connection in pairs(wire_connector.connections) do
            if connection.origin == defines.wire_origin.player then
                dst_connector.connect_to(connection.target, false, connection.origin)
            end
        end
    end
end

---@param surface LuaSurface
---@param item_sensor LuaEntity
local function migrate_sensor(surface, item_sensor)
    if not Is.Valid(item_sensor) then return end
    local entities_to_delete = surface.find_entities(Position(item_sensor.position):expand_to_area(0.5))

    local entity_config = {
        name = const.inventory_sensor_name,
        position = item_sensor.position,
        direction = item_sensor.direction,
        force = item_sensor.force,
        quality = item_sensor.quality,
    }

    -- create new main entity in the same spot
    local main = surface.create_entity(entity_config)

    assert(main)

    copy_wire_connections(item_sensor, main)

    This.SensorController:create(main)

    Migration.stats[item_sensor.name] = (Migration.stats[item_sensor.name] or 0) + 1

    for _, entity_to_delete in pairs(entities_to_delete) do
        entity_to_delete.destroy()
    end
end

function Migration:migrateSensors()
    for _, surface in pairs(game.surfaces) do
        self.stats = {}

        local sensors = surface.find_entities_filtered {
            name = const.migration_names,
        }

        for _, sensor in pairs(sensors) do
            migrate_sensor(surface, sensor)
        end

        local stats = ''
        local total = 0
        for name, count in pairs(self.stats) do
            stats = stats .. ('%s: %s'):format(name, count)
            total = total + count
            if next(self.stats, name) then
                stats = stats .. ', '
            end
        end
        if total > 0 then
            game.print { const:locale('migration'), total, surface.name, stats }
        end
    end
end

---------------------------------------------------------------------------

--- Replace old sensor with new
---@param blueprint_entity BlueprintEntity
---@return BlueprintEntity?
local function create_entity(blueprint_entity)
    local new_entity = util.copy(blueprint_entity)
    new_entity.name = const.inventory_sensor_name
    return new_entity
end

---------------------------------------------------------------------------

local BlueprintMigrator = {}

---@param blueprint_entity BlueprintEntity
---@return BlueprintEntity?
function BlueprintMigrator:migrateBlueprintEntity(blueprint_entity)
    if not const.migrations[blueprint_entity.name] then return nil end

    return create_entity(blueprint_entity)
end

---@param blueprint_entities (BlueprintEntity[])?
---@return boolean modified
function BlueprintMigrator:migrateBlueprintEntities(blueprint_entities)
    local dirty = false

    if not blueprint_entities then return dirty end

    for i = 1, #blueprint_entities, 1 do
        local blueprint_entity = blueprint_entities[i]

        if const.migrations[blueprint_entity.name] then
            local new_entity = self:migrateBlueprintEntity(blueprint_entity)
            if new_entity then
                blueprint_entities[i] = new_entity
                dirty = true
            end
        end
    end

    return dirty
end

---@param migration_object (LuaItemStack|LuaRecord)?
---@return boolean
function BlueprintMigrator:executeMigration(migration_object)
    if not (migration_object and migration_object.valid) then return false end

    local blueprint_entities = util.copy(migration_object.get_blueprint_entities())
    if (self:migrateBlueprintEntities(blueprint_entities)) then
        migration_object.set_blueprint_entities(blueprint_entities)
        return true
    end

    return false
end

---@param inventory LuaInventory?
function BlueprintMigrator:processInventory(inventory)
    if not (inventory and inventory.valid) then return end
    for i = 1, #inventory, 1 do
        if inventory[i] then
            if inventory[i].is_blueprint then
                self:executeMigration(inventory[i])
            elseif inventory[i].is_blueprint_book then
                local nested_inventory = inventory[i].get_inventory(defines.inventory.item_main)
                self:processInventory(nested_inventory)
            end
        end
    end
end

---@param record LuaRecord
function BlueprintMigrator:processRecord(record)
    if not (record.valid and record.valid_for_write) then return end

    if record.type == 'blueprint' then
        self:executeMigration(record)
    elseif record.type == 'blueprint-book' then
        for _, nested_record in pairs(record.contents) do
            self:processRecord(nested_record)
        end
    end
end

---------------------------------------------------------------------------

function Migration:migrateBlueprints()
    -- migrate game blueprints
    for _, record in pairs(game.blueprints) do
        BlueprintMigrator:processRecord(record)
    end

    -- migrate blueprints players have in their inventory
    for _, player in pairs(game.players) do
        local inventory = player.get_main_inventory()
        BlueprintMigrator:processInventory(inventory)
    end
end

return Migration
