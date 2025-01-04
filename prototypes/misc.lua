------------------------------------------------------------------------
-- misc stuff
------------------------------------------------------------------------

local util = require('util')
local table = require('stdlib.utils.table')

local const = require('lib.constants')

local recipe_prototype = {
    name = const.inventory_sensor_name,
    order = const.order,
    results = {
        { type = 'item', name = const.inventory_sensor_name, amount = 1 },
    }
}

---@type data.RecipePrototype
local recipe = table.merge(util.copy(data.raw.recipe['constant-combinator']), recipe_prototype)

data:extend { recipe }

assert(data.raw['technology']['circuit-network'])

table.insert(data.raw['technology']['circuit-network'].effects, { type = 'unlock-recipe', recipe = const.inventory_sensor_name })
