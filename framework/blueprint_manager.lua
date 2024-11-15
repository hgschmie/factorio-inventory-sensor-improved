---@meta
------------------------------------------------------------------------
-- Manage blueprint related state
------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Player = require('stdlib.event.player')
local table = require('stdlib.utils.table')

---@alias FrameworkBlueprintPrepareCallback fun(blueprint: LuaItemStack): BlueprintEntity[]?
---@alias FrameworkBlueprintMapCallback fun(entity: LuaEntity, idx: integer, context: table<string, any>)
---@alias FrameworkBlueprintCallback fun(entity: LuaEntity, idx: integer, blueprint: LuaItemStack, context: table<string, any>)

---@class FrameworkBlueprintManager
---@field map_callbacks table<string, FrameworkBlueprintMapCallback>
---@field callbacks table<string, FrameworkBlueprintCallback>
---@field prepare_blueprint FrameworkBlueprintPrepareCallback?
local FrameworkBlueprintManager = {
    map_callbacks = {},
    callbacks = {},
    prepare_blueprint = nil,
}

------------------------------------------------------------------------
-- Blueprint management
------------------------------------------------------------------------

---@param player LuaPlayer
local function can_access_blueprint(player)
    if not Is.Valid(player) then return false end
    if not player.cursor_stack then return false end

    return (player.cursor_stack.valid_for_read and player.cursor_stack.name == 'blueprint')
end

---@param blueprint LuaItemStack
---@param entity_map table<integer, table<integer, table<string, LuaEntity>>>
function FrameworkBlueprintManager:augment_blueprint(blueprint, entity_map, context)
    if not entity_map or (table_size(entity_map) < 1) then return end
    if not (blueprint and blueprint.is_blueprint_setup()) then return end

    local blueprint_entities = self.prepare_blueprint and self.prepare_blueprint(blueprint) or blueprint.get_blueprint_entities()
    if not blueprint_entities then return end

    -- at this point, the entity_map contains all entities that were captured in the
    -- initial blueprint but the final list (which is part of the blueprint itself) may
    -- have changed as the player can manipulate the blueprint.

    for idx, entity in pairs(blueprint_entities) do
        local x_map = entity_map[entity.position.x]
        if x_map then
            local y_map = x_map[entity.position.y]
            if y_map and y_map[entity.name] then
                local callback = self.callbacks[entity.name]
                if callback then
                    local mapped_entity = y_map[entity.name]
                    callback(mapped_entity, idx, blueprint, context)
                end
            end
        end
    end
end

---@param entity_mapping table<integer, LuaEntity>
---@param context table<string, any>
---@return table<integer, table<integer, table<string, LuaEntity>>> entity_map
function FrameworkBlueprintManager:create_entity_map(entity_mapping, context)
    local entity_map = {}
    if entity_mapping then
        for idx, mapped_entity in pairs(entity_mapping) do
            if self.callbacks[mapped_entity.name] then -- there is a callback for this entity
                local map_callback = self.map_callbacks[mapped_entity.name]
                if map_callback then
                    map_callback(mapped_entity, idx, context)
                end
                local x_map = entity_map[mapped_entity.position.x] or {}
                entity_map[mapped_entity.position.x] = x_map
                local y_map = x_map[mapped_entity.position.y] or {}
                x_map[mapped_entity.position.y] = y_map

                if y_map[mapped_entity.name] then
                    Framework.logger:logf('Duplicate entity found at (%d/%d): %s', mapped_entity.position.x, mapped_entity.position.y, mapped_entity.name)
                else
                    y_map[mapped_entity.name] = mapped_entity
                end
            end
        end
    end

    return entity_map
end

------------------------------------------------------------------------
-- Event code
------------------------------------------------------------------------

---@param event EventData.on_player_setup_blueprint
local function onPlayerSetupBlueprint(event)
    local player, player_data = Player.get(event.player_index)

    local blueprinted_entities = event.mapping.get()
    -- for large blueprints, the event mapping might come up empty
    -- which seems to be a limitation of the game. Fall back to an
    -- area scan
    if table_size(blueprinted_entities) < 1 then
        if not event.area then return end
        blueprinted_entities = player.surface.find_entities_filtered {
            area = event.area,
            force = player.force,
            name = table.keys(Framework.blueprint.callbacks)
        }
    end

    local context = {}
    local entity_map = Framework.blueprint:create_entity_map(blueprinted_entities, context)

    if can_access_blueprint(player) then
        Framework.blueprint:augment_blueprint(player.cursor_stack, entity_map, context)
    else
        -- Player is editing the blueprint, no access for us yet.
        -- onPlayerConfiguredBlueprint picks this up and stores it.
        player_data.current_blueprint_entity_map = entity_map
        player_data.current_blueprint_context = context
    end
end

---@param event EventData.on_player_configured_blueprint
local function onPlayerConfiguredBlueprint(event)
    local player, player_data = Player.get(event.player_index)

    local entity_map = player_data.current_blueprint_entity_map
    local context = player_data.current_blueprint_context or {}

    if entity_map and can_access_blueprint(player) then
        Framework.blueprint:augment_blueprint(player.cursor_stack, entity_map, context)
    end

    player_data.current_blueprint_entity_map = nil
    player_data.current_blueprint_context = nil
end

------------------------------------------------------------------------
-- Registration code
------------------------------------------------------------------------

---@param names string|string[]
---@param callback FrameworkBlueprintCallback
---param map_callback FrameworkBlueprintMapCallback?
function FrameworkBlueprintManager:register_callback(names, callback, map_callback)

    if type(names) ~= 'table' then
        names = { names }
    end

    for _, name in pairs(names) do
        self.callbacks[name] = callback
        if map_callback then
            self.map_callbacks[name] = map_callback
        end
    end
end

---@param callback FrameworkBlueprintPrepareCallback
function FrameworkBlueprintManager:register_preprocessor(callback)
    self.prepare_blueprint = callback
end

-- Blueprint management
Event.register(defines.events.on_player_setup_blueprint, onPlayerSetupBlueprint)
Event.register(defines.events.on_player_configured_blueprint, onPlayerConfiguredBlueprint)

return FrameworkBlueprintManager
