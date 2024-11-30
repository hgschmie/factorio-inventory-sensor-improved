---@meta
------------------------------------------------------------------------
-- Manage all ghost state for robot building
------------------------------------------------------------------------

local Event = require('stdlib.event.event')
local Is = require('stdlib.utils.is')
local Position = require('stdlib.area.position')

local tools = require('framework.tools')

---@alias FrameworkGhostManagerRefreshCallback function(entity: FrameworkAttachedEntity, all_entities: FrameworkAttachedEntity[]): FrameworkAttachedEntity[]

---@class FrameworkGhostManager
---@field refresh_callbacks FrameworkGhostManagerRefreshCallback[]
local FrameworkGhostManager = {
    refresh_callbacks = {},
}

---@return FrameworkGhostManagerState state Manages ghost state
function FrameworkGhostManager:state()
    local storage = Framework.runtime:storage()

    if not storage.ghost_manager then
        ---@type FrameworkGhostManagerState
        storage.ghost_manager = {
            ghost_entities = {},
        }
    end

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
        -- allow 10 seconds of dwelling time until a refresh must have happened
        tick = game.tick + 600,
    }
end

function FrameworkGhostManager:deleteGhost(unit_number)
    local state = self:state()

    if state.ghost_entities[unit_number] then
        state.ghost_entities[unit_number].entity.destroy()
        state.ghost_entities[unit_number] = nil
    end
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
            state.ghost_entities[idx] = nil
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

local function onTick()
    Framework.ghost_manager:tick()
end

-- entities that do not get refreshed will disappear after 10 seconds
local timeout_for_ghosts = 600

function FrameworkGhostManager:tick()
    local state = self:state()

    local all_ghosts = state.ghost_entities --[[@as FrameworkAttachedEntity[] ]]

    for _, ghost_entity in pairs(all_ghosts) do
        local callback = self.refresh_callbacks[ghost_entity.name]
        if callback then
            local entities = callback(ghost_entity, all_ghosts)
            for _, entity in pairs(entities) do
                entity.tick = game.tick + timeout_for_ghosts -- refresh
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
    for _, name in pairs(names) do
        self.refresh_callbacks[name] = callback
    end
end

Event.register(defines.events.on_object_destroyed, onObjectDestroyed)

Event.on_nth_tick(61, onTick)

return FrameworkGhostManager
