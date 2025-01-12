---@meta
------------------------------------------------------------------------
-- Manage all ghost state for robot building
------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Position = require('stdlib.area.position')

local tools = require('framework.tools')

local TICK_INTERVAL = 61 -- run all 61 ticks
local ATTACHED_GHOST_LINGER_TIME = 600

---@alias FrameworkGhostManagerRefreshCallback function(entity: FrameworkAttachedEntity, all_entities: FrameworkAttachedEntity[]): FrameworkAttachedEntity[]

---@class FrameworkGhostManager
---@field refresh_callbacks FrameworkGhostManagerRefreshCallback[]
local FrameworkGhostManager = {
    refresh_callbacks = {},
}

---@return FrameworkGhostManagerState state Manages ghost state
function FrameworkGhostManager:state()
    local storage = Framework.runtime:storage()

    ---@type FrameworkGhostManagerState
    storage.ghost_manager = storage.ghost_manager or {
        ghost_entities = {},
    }

    return storage.ghost_manager
end

---@param entity LuaEntity
---@param player_index integer
function FrameworkGhostManager:registerGhost(entity, player_index)
    -- if an entity ghost was placed, register information to configure
    -- an entity if it is placed over the ghost

    local state = self:state()

    state.ghost_entities[entity.unit_number] = {
        -- maintain entity reference for attached entity ghosts
        entity = entity,
        -- but for matching ghost replacement, all the values
        -- must be kept because the entity is invalid when it
        -- replaces the ghost
        name = entity.ghost_name,
        position = entity.position,
        orientation = entity.orientation,
        tags = entity.tags,
        player_index = player_index,
        -- allow 10 seconds of lingering time until a refresh must have happened
        tick = game.tick + ATTACHED_GHOST_LINGER_TIME,
    }
end

function FrameworkGhostManager:deleteGhost(unit_number)
    local state = self:state()

    if not state.ghost_entities[unit_number] then return end
    state.ghost_entities[unit_number].entity.destroy()
    state.ghost_entities[unit_number] = nil
end

---@param entity LuaEntity
---@return FrameworkAttachedEntity? ghost_entities
function FrameworkGhostManager:findMatchingGhost(entity)
    local state = self:state()

    -- find a ghost that matches the entity
    for idx, ghost in pairs(state.ghost_entities) do
        -- it provides the tags and player_index for robot builds
        if entity.name == ghost.name
            and entity.position.x == ghost.position.x
            and entity.position.y == ghost.position.y
            and entity.orientation == ghost.orientation then
            self:deleteGhost(idx)
            return ghost
        end
    end
    return nil
end

--- Find all ghosts within a given area. If a ghost is found, pass
--- it to the callback. If the callback returns a key, move the ghost
--- into the ghost_entities return array under the given key and remove
--- it from storage.
---
---@param area BoundingBox
---@param callback fun(ghost: FrameworkAttachedEntity) : any?
---@return table<any, FrameworkAttachedEntity> ghost_entities
function FrameworkGhostManager:findGhostsInArea(area, callback)
    local state = self:state()

    local ghosts = {}
    for idx, ghost in pairs(state.ghost_entities) do
        local pos = Position.new(ghost.position)
        if pos:inside(area) then
            local key = callback(ghost)
            if key then
                ghosts[key] = ghost
                state.ghost_entities[idx] = nil
            end
        end
    end

    return ghosts
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.script_raised_revive | EventData.script_raised_built
function FrameworkGhostManager.onGhostEntityCreated(event)
    local entity = event and event.entity
    if not Is.Valid(entity) then return end

    script.register_on_object_destroyed(entity)

    Framework.ghost_manager:registerGhost(entity, event.player_index)
end

---@param event EventData.on_object_destroyed
local function onObjectDestroyed(event)
    Framework.ghost_manager:deleteGhost(event.useful_id)
end

--------------------------------------------------------------------------------
-- ticker
--------------------------------------------------------------------------------

function FrameworkGhostManager:tick()
    local state = self:state()

    local all_ghosts = state.ghost_entities --[[@as FrameworkAttachedEntity[] ]]

    if table_size(all_ghosts) == 0 then return end

    for _, ghost_entity in pairs(all_ghosts) do
        local callback = self.refresh_callbacks[ghost_entity.name]
        if callback then
            local entities = callback(ghost_entity, all_ghosts)
            for _, entity in pairs(entities) do
                entity.tick = game.tick + ATTACHED_GHOST_LINGER_TIME -- refresh
            end
        end
    end

    -- remove stale ghost entities
    for id, ghost_entity in pairs(all_ghosts) do
        if ghost_entity.tick < game.tick then
            self:deleteGhost(id)
        end
    end
end

---@param ghost_names string|string[] One or more names to match to the ghost_name field.
function FrameworkGhostManager:register_for_ghost_names(ghost_names)
    local event_matcher = tools.create_event_ghost_entity_name_matcher(ghost_names)
    tools.event_register(tools.CREATION_EVENTS, self.onGhostEntityCreated, event_matcher)
end

---@param attribute string The entity attribute to match.
---@param values string|string[] One or more values to match.
function FrameworkGhostManager:register_for_ghost_attributes(attribute, values)
    local event_matcher = tools.create_event_ghost_entity_matcher(attribute, values)
    tools.event_register(tools.CREATION_EVENTS, self.onGhostEntityCreated, event_matcher)
end

--- Registers a ghost entity for refresh. The callback will receive the entity and must return
--- at least the entity itself to refresh it. It may return additional entities to refresh.
---@param names string|string[]
---@param callback FrameworkGhostManagerRefreshCallback
function FrameworkGhostManager:register_for_ghost_refresh(names, callback)
    if type(names) ~= 'table' then
        names = { names }
    end

    Event.register_if(table_size(self.refresh_callbacks) == 0, -TICK_INTERVAL, function(ev) Framework.ghost_manager:tick() end)

    for _, name in pairs(names) do
        self.refresh_callbacks[name] = callback
    end
end

--------------------------------------------------------------------------------
-- event registration
--------------------------------------------------------------------------------

local function register_events()
    Event.register(defines.events.on_object_destroyed, onObjectDestroyed)
end

Event.on_init(register_events)
Event.on_load(register_events)

return FrameworkGhostManager
