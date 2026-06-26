------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

This, Framework = require('lib.init')()

local const = require('lib.constants')

------------------------------------------------------------------------

require('prototypes.inventory-sensor')
require('prototypes.misc')
require('prototypes.signals')

---@diagnostic disable-next-line: undefined-field
Framework.post_data_stage()
