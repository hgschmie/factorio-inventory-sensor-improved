------------------------------------------------------------------------
-- runtime code
------------------------------------------------------------------------

require('lib.init')

-- setup player management
require('stdlib.event.player').register_events(true)

-- setup events
require('scripts.event-setup')

-- other mods code
Framework.post_runtime_stage()