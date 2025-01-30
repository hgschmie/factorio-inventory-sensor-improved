---@meta
------------------------------------------------------------------------
-- Sensor prototype
------------------------------------------------------------------------

local util = require('util')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

local item_prototype = {
    name = const.inventory_sensor_name,
    icon = const:png('icon/inventory-sensor'),
    icon_size = 64,
    place_result = const.inventory_sensor_name,
    order = const.order,
}

---@type data.ItemPrototype
local is_item = table.merge(util.copy(data.raw.item['constant-combinator']), item_prototype)

------------------------------------------------------------------------

local entity_prototype = {

    -- PrototypeBase
    name = const.inventory_sensor_name,
    order = const.order,

    -- ConstantCombinatorPrototype
    sprites = make_4way_animation_from_spritesheet {
        layers =
        {
            {
                scale = 0.5,
                filename = const:png('entity/inventory-sensor'),
                width = 114,
                height = 102,
                shift = util.by_pixel(0, 5)
            },
            {
                scale = 0.5,
                filename = '__base__/graphics/entity/combinator/constant-combinator-shadow.png',
                width = 98,
                height = 66,
                shift = util.by_pixel(8.5, 5.5),
                draw_as_shadow = true
            }
        }
    },

    -- EntityPrototype
    icon = const:png('icon/inventory-sensor'),
    minable = { mining_time = 0.1, result = const.inventory_sensor_name },
}

---@type data.ConstantCombinatorPrototype
local is_entity = table.merge(util.copy(data.raw['constant-combinator']['constant-combinator']), entity_prototype)

data:extend { is_item, is_entity }
