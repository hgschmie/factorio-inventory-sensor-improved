------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

require('lib.init')

local const = require('lib.constants')

------------------------------------------------------------------------

require('prototypes.inventory-sensor')
require('prototypes.misc')
require('prototypes.signals')

------------------------------------------------------------------------
Framework.post_data_stage()