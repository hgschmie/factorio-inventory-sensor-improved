------------------------------------------------------------------------
-- data phase 1
------------------------------------------------------------------------

require('lib.init')('data')

local const = require('lib.constants')

------------------------------------------------------------------------

require('prototypes.inventory-sensor')
require('prototypes.misc')
require('prototypes.signals')

------------------------------------------------------------------------
require('framework.other-mods').data()
