---@meta
----------------------------------------------------------------------------------------------------
-- Data Utility - from flib
----------------------------------------------------------------------------------------------------

local util = require('util')

---@class FrameworkDataUtil
local FrameworkDataUtil = {}

--- An empty image. This image is 8x8 to facilitate usage with GUI styles.
FrameworkDataUtil.empty_image = Framework.ROOT .. '/framework/graphics/empty.png'

--- A black image, for use with tool backgrounds. This image is 1x1.
FrameworkDataUtil.black_image = Framework.ROOT .. '/framework/graphics/black.png'

--- A desaturated planner image. Tint this sprite to easily add your own planners.
FrameworkDataUtil.planner_base_image = Framework.ROOT .. '/framework/graphics/planner.png'

--- A dark red button tileset. Used for the `flib_tool_button_dark_red` style.
FrameworkDataUtil.dark_red_button_tileset = Framework.ROOT .. '/framework/graphics/dark-red-button.png'

--- Copy a prototype, assigning a new name and minable properties.
---@param prototype table
---@param new_name string string
---@param remove_icon? boolean
---@return table
function FrameworkDataUtil.copy_prototype(prototype, new_name, remove_icon)
    if not prototype.type or not prototype.name then
        error('Invalid prototype: prototypes must have name and type properties.')
        return ---@diagnostic disable-line
    end
    local p = util.copy(prototype)
    p.name = new_name
    if p.minable and p.minable.result then
        p.minable.result = new_name
    end
    if p.place_result then
        p.place_result = new_name
    end
    if p.result then
        p.result = new_name
    end
    if p.results then
        for _, result in pairs(p.results) do
            if result.name == prototype.name then
                result.name = new_name
            end
        end
    end
    if remove_icon then
        p.icon = nil
        p.icon_size = nil
        p.icon_mipmaps = nil
        p.icons = nil
    end

    return p
end

--- Copy prototype.icon/icons to a new fully defined icons array, optionally adding new icon layers.
---
--- Returns `nil` if the prototype's icons are incorrectly or incompletely defined.
---@param prototype table
---@param new_layers? FrameworkIconSpecification[]
---@return FrameworkIconSpecification[]|nil
function FrameworkDataUtil.create_icons(prototype, new_layers)
    if new_layers then
        for _, new_layer in pairs(new_layers) do
            if not new_layer.icon or not new_layer.icon_size then
                return nil
            end
        end
    end

    if prototype.icons then
        local icons = {}
        for _, v in pairs(prototype.icons) do
            -- Over define as much as possible to minimize weirdness: https://forums.factorio.com/viewtopic.php?f=25&t=81980
            icons[#icons + 1] = {
                icon = v.icon,
                icon_size = v.icon_size or prototype.icon_size,
                icon_mipmaps = v.icon_mipmaps or prototype.icon_mipmaps or 0,
                tint = v.tint,
                scale = v.scale,
                shift = v.shift,
            }
        end
        if new_layers then
            for _, new_layer in pairs(new_layers) do
                icons[#icons + 1] = new_layer
            end
        end
        return icons
    elseif prototype.icon then
        local icons = {
            {
                icon = prototype.icon,
                icon_size = prototype.icon_size,
                icon_mipmaps = prototype.icon_mipmaps,
                tint = { r = 1, g = 1, b = 1, a = 1 },
            },
        }
        if new_layers then
            for _, new_layer in pairs(new_layers) do
                icons[#icons + 1] = new_layer
            end
        end
        return icons
    else
        return nil
    end
end

local exponent_multipliers = {
    ['y'] = 0.000000000000000000000001,
    ['z'] = 0.000000000000000000001,
    ['a'] = 0.000000000000000001,
    ['f'] = 0.000000000000001,
    ['p'] = 0.000000000001,
    ['n'] = 0.000000001,
    ['u'] = 0.000001, -- μ is invalid
    ['m'] = 0.001,
    ['c'] = 0.01,
    ['d'] = 0.1,
    [''] = 1,
    ['da'] = 10,
    ['h'] = 100,
    ['k'] = 1000,
    ['K'] = 1000, -- This isn't SI, but meh
    ['M'] = 1000000,
    ['G'] = 1000000000,
    ['T'] = 1000000000000,
    ['P'] = 1000000000000000,
    ['E'] = 1000000000000000000,
    ['Z'] = 1000000000000000000000,
    ['Y'] = 1000000000000000000000000,
}

--- Convert an energy string to base unit value + suffix.
---
--- Returns `nil` if `energy_string` is incorrectly formatted.
---@param energy_string string
---@return number?
---@return string?
function FrameworkDataUtil.get_energy_value(energy_string)
    if type(energy_string) == 'string' then
        local v, _, exp, unit = string.match(energy_string, '([%-+]?[0-9]*%.?[0-9]+)((%D*)([WJ]))')
        local value = tonumber(v)
        if value and exp and exponent_multipliers[exp] then
            value = value * exponent_multipliers[exp]
            return value, unit
        end
    end
    return nil
end

--- Build a sprite from constituent parts.
---@param name? string
---@param position? MapPosition
---@param filename? string
---@param size? Vector
---@param mipmap_count? number
---@param mods? table
---@return FrameworkSpriteSpecification
function FrameworkDataUtil.build_sprite(name, position, filename, size, mipmap_count, mods)
    local def = {
        type = 'sprite',
        name = name,
        filename = filename,
        position = position,
        size = size,
        mipmap_count = mipmap_count,
        flags = { 'icon' },
    }
    if mods then
        for k, v in pairs(mods) do
            def[k] = v
        end
    end
    return def
end

return FrameworkDataUtil

---@class FrameworkIconSpecification
---@field icon string
---@field icon_size int
---@class FrameworkSpriteSpecification
