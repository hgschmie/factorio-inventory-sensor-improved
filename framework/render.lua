---@meta
----------------------------------------------------------------------------------------------------
-- Graphics rendering support
----------------------------------------------------------------------------------------------------

local Event = require('stdlib.event.event')

---@class FrameworkRender
local Rendering = {}

--- Clear all currently outstanding rendered objects.
---@param player_index integer
function Rendering:clearRenderedText(player_index)
    local storage = Framework.runtime:player_storage(player_index)

    if not storage.rendered_objects then return end

    for _, rendered_object in pairs(storage.rendered_objects) do
        if rendered_object then rendered_object.destroy() end
    end
    storage.rendered_objects = {}
end

--- Render a new text element and register it with the renderer.
---@param player_index integer
---@param render_text LuaRendering.draw_text_param
function Rendering:renderText(player_index, render_text)
    local storage = Framework.runtime:player_storage(player_index)
    storage.rendered_objects = storage.rendered_objects or {}

    local render_object = rendering.draw_text(render_text)
    table.insert(storage.rendered_objects, render_object)
end

local function onSelectedEntityChanged(event)
    Framework.render:clearRenderedText(event.player_index)
end

Event.register(defines.events.on_selected_entity_changed, onSelectedEntityChanged)

return Rendering
