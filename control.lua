------------------------------------------------------------------------
-- runtime code
------------------------------------------------------------------------

require('lib.init')('runtime')

-- setup player management
require('stdlib.event.player').register_events(true)

-- setup events
-- require('scripts.event-setup')

-- setup remote interface
-- require('scripts.remote')

-- other mods code
require('framework.other-mods').runtime()
