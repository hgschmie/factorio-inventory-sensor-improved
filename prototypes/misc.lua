------------------------------------------------------------------------
-- misc stuff
------------------------------------------------------------------------

local const = require('lib.constants')

---@type data.RecipePrototype
local recipe = {
    type = 'recipe',
    name = const.inventory_sensor_name,
    icon_size = 128,
    icon = const:png('technology/inventory-sensor'),
    enabled = false,
    ingredients =
    {
        { type = 'item', name = 'copper-cable',       amount = 5 },
        { type = 'item', name = 'electronic-circuit', amount = 2 }
    },
    results =
    {
        { type = 'item', name = 'constant-combinator', amount = 1 },
    }
}

data:extend { recipe }

assert(data.raw['technology']['circuit-network'])

table.insert(data.raw['technology']['circuit-network'].effects, { type = 'unlock-recipe', recipe = const.inventory_sensor_name })
