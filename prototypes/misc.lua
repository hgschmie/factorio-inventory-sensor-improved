------------------------------------------------------------------------
-- misc stuff
------------------------------------------------------------------------

local const = require('lib.constants')

local recipe = util.copy(data.raw.recipe['constant-combinator']) --[[@as data.RecipePrototype]]
recipe.name = const.inventory_sensor_name
recipe.icon_size = 128
recipe.icon = const:png('technology/inventory-sensor')
recipe.order = const.order
recipe.results = {
    { type = 'item', name = const.inventory_sensor_name, amount = 1},
}

data:extend { recipe }

assert(data.raw['technology']['circuit-network'])

table.insert(data.raw['technology']['circuit-network'].effects, { type = 'unlock-recipe', recipe = const.inventory_sensor_name })
