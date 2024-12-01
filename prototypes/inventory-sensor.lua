------------------------------------------------------------------------
-- Sensor prototype
------------------------------------------------------------------------

local const = require('lib.constants')

---@type data.ItemPrototype
local is_item = util.copy(data.raw.item['constant-combinator'])

is_item.name = const.inventory_sensor_name
is_item.icon = const:png('icon/inventory-sensor')
is_item.icon_size = 64
is_item.place_result = const.inventory_sensor_name
is_item.order = const.order

------------------------------------------------------------------------

---@type data.ConstantCombinatorPrototype
local is_entity = util.copy(data.raw['constant-combinator']['constant-combinator'])

-- PrototypeBase

is_entity.name = const.inventory_sensor_name
is_entity.order = const.order

-- ConstantCombinatorPrototype

is_entity.sprites = make_4way_animation_from_spritesheet {
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
}

-- EntityPrototype
is_entity.icon = const:png('icon/inventory-sensor')
is_entity.minable = { mining_time = 0.1, result = const.inventory_sensor_name }
is_entity.fast_replaceable_group = nil

data:extend { is_item, is_entity }
