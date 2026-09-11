---@meta
------------------------------------------------------------------------
-- Sensor prototype
------------------------------------------------------------------------

local util = require('util')
local meld = require('meld')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

local item_prototype = {
    name = const.inventory_sensor_name,
    icon = const:png('icon/inventory-sensor-icon'),
    icon_size = 64,
    place_result = const.inventory_sensor_name,
    order = const.order,
}

---@type ItemPrototype
local is_item = table.merge(util.copy(data.raw.item['constant-combinator']), item_prototype)

------------------------------------------------------------------------

local entity_prototype = {

    -- PrototypeBase
    name = const.inventory_sensor_name,
    order = const.order,

    -- ConstantCombinatorPrototype
    ---@diagnostic disable-next-line: undefined-global
    sprites = meld.overwrite(make_4way_animation_from_spritesheet {
        layers =
        {
            {
                filename = const:png('entity/inventory-sensor'),
                width = 114,
                height = 102,
                shift = util.by_pixel_hr(0.0, -15.0),
                scale = 0.5,
            },
            {
                filename = const:png('entity/inventory-sensor-shadow'),
                width = 116,
                height = 74,
                shift = util.by_pixel_hr(25.0, 4.0),
                scale = 0.5,
                draw_as_shadow = true,
            }
        }
    }),
    circuit_wire_connection_points = meld.overwrite {
        {
            wire = {
                red = util.by_pixel_hr(-23, -57),
                green = util.by_pixel_hr(23, -57),
            },
            shadow = {
                red = util.by_pixel_hr(60, -16),
                green = util.by_pixel_hr(72, -10),
            }
        },
        {
            wire = {
                red = util.by_pixel_hr(23, -57),
                green = util.by_pixel_hr(23, -12),
            },
            shadow = {
                red = util.by_pixel_hr(75, -7),
                green = util.by_pixel_hr(75, 32),
            }
        },
        {
            wire = {
                red = util.by_pixel_hr(23, -12),
                green = util.by_pixel_hr(-23, -12),
            },
            shadow = {
                red = util.by_pixel_hr(73, 35),
                green = util.by_pixel_hr(63, 32),
            }
        },
        {
            wire = {
                red = util.by_pixel_hr(-23, -12),
                green = util.by_pixel_hr(-23, -57),
            },
            shadow = {
                red = util.by_pixel_hr(0, -2),
                green = util.by_pixel_hr(0, -36),
            }
        }
    },
    activity_led_sprites = meld.overwrite {
        north = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/green-activity-led'),
            width = 14,
            height = 14,
            shift = util.by_pixel_hr(17, -8)
        },
        east = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/green-activity-led'),
            width = 14,
            height = 14,
            shift = util.by_pixel_hr(-14, -2)
        },
        south = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/green-activity-led'),
            width = 14,
            height = 14,
            shift = util.by_pixel_hr(-19, -36)
        },
        west = util.draw_as_glow {
            scale = 0.5,
            filename = const:png('misc/green-activity-led'),
            width = 14,
            height = 14,
            shift = util.by_pixel_hr(12, -40)
        }
    },

    -- EntityPrototype
    icon = const:png('icon/inventory-sensor-icon'),
    minable = meld.overwrite { mining_time = 0.1, result = const.inventory_sensor_name },
}

---@type ConstantCombinatorPrototype
local is_entity = meld.meld(util.copy(data.raw['constant-combinator']['constant-combinator']), entity_prototype)

data:extend { is_item, is_entity }
