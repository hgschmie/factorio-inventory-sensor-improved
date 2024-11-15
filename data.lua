------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

require('lib.init')('data')

local const = require('lib.constants')

------------------------------------------------------------------------

require('prototypes.inventory-sensor')
-- require('prototypes.filter-combinator')

-- ------------------------------------------------------------------------

-- ---@type data.ItemPrototype
-- local item = util.copy(data.raw.item['arithmetic-combinator'])
-- item.name = const.filter_combinator_name
-- item.place_result = const.filter_combinator_name
-- item.icon = const:png('filter-combinator-improved')
-- item.flags = { 'mod-openable' }
-- item.order = 'c[combinators]-b[filter-combinator-improved]'

-- ---@type data.RecipePrototype
-- local recipe = util.copy(data.raw.recipe['arithmetic-combinator'])
-- recipe.name = const.filter_combinator_name
-- recipe.results[1].name = const.filter_combinator_name
-- recipe.order = item.order

-- data:extend { item, recipe }

-- table.insert(data.raw['technology']['circuit-network'].effects, { type = 'unlock-recipe', recipe = const.filter_combinator_name })

------------------------------------------------------------------------
require('framework.other-mods').data()
