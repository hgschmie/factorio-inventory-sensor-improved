# Improved Inventory Sensor

The inventory sensor reads the inventories of most entities that can store items inside, including:

* stationary entities: container (including logistics and linked containers), storage tanks, assembling machines, furnaces, labs, reactor, generator, boiler, roboports, rocket silos, artillery turrets, accumulators and cargo landing pads.
* mobile entities: cars (including tank), spidertrons, locomotives, cargo wagon, fluid wagon and artillery wagon

For most entities, it reads the main inventory (or input and output for assembling machine and furnaces).

This mod was inspired by the [Inventory Sensor](https://mods.factorio.com/mod/Inventory%20Sensor) by 0ptera. It is drop-in compatible (uses the same
signal names and supplies the same signals) but offers more features (and different bugs).

Uicons by [Flaticon](https://www.flaticon.com/uicons) provided the signal icons

## Features

* GUI provides updating view of the signals created by the sensor
* enable / disable equipment grid reading on a per-sensor basis
* can be rotated and moved (with [Even Pickier Dollies](https://mods.factorio.com/mod/even-pickier-dollies))
* supports blueprinting, cloning and settings copying
* debug mode shows scan area and connect/disconnect events

### Virtual signals about scanned entities

When enabling the `Generate inventory status signals` setting in the GUI, the sensor will create a number of virtual signals that describe the inventories of the connected entity. Note that for entities that have more than inventory (e.g. Assembly Machines), this is a summary across all inventories and not just for a single inventory.

Item specific signals:

* B - slot number for the "red bar" (blocked slots). Note: Only one inventory can have blocked slots
* E - Sum of all empty slots in the inventories
* F - Sum of all used slots in the inventories
* T - Total number of slots in all inventories
* P - Percentage of slots used (ignoring filtered and blocked slots) across all inventories
* X - Total number of filtered slots (in inventories that use a filter)
* I - Total number of items in all inventories

Fluid signals:

Display information about fluids in an entity.

* A - Number of fluids in the entity
* L - Total amount of fluid in the entity
* D - Number of empty fluids (empty fluid boxes for entities that use fluid boxes, otherwise 1 if the entity contains no fluid)
* C - Total number of fluids supported by the entity
* V - Total fluid capacity across all fluids
* Q - Percentage of fluid capacity used

When an entity uses fluid boxes and has the same fluid for input and output, the count may be off.

## Settings

* 'Update interval' controls how often a sensor is updated. Default is every 10 ticks. Changing this value influences the amount of time the mod spends per tick.
* 'Entity scan interval' controls how often the sensor looks for an entity to connect to. This is most important for sensors that should scan for mobile entities. Once it has connected, the scan interval changes; for mobile entities, it will scan every 30 ticks to see whether the mobile entity has moved away, for stationary entities it will scan every 300 ticks.
* 'Scan offset' controls the width of the scan area. The default is 0.2 tiles, so the scan area is 0.4 tiles wide.
* 'Scan range' controlls the depth of the scan area. The default is 1.5 tiles.

Changing 'Scan offset' and 'Scan range' should be done with caution and may lead to unexpected results!

## Upgrading from Inventory Sensor

The mod provides a startup setting which, when set, will replace all existing Inventory Sensor entities with the Improved Inventory Sensor:

* Set the "Update old Inventory sensor entities" startup setting from the main menu settings.
* Load a game. If there are Inventory Sensors, they will be replaced and the game will print a summary line for each surface.
* Save the game and exit.
* Unset the "Update old Inventory sensor entities" startup setting from the main menu settings.

You can now uninstall the Inventory Sensor mod as it is no longer used.

[NOTE: Due to a bug in the Inventory Sensor code, only Inventory Sensor versions of 2.0.3 or newer support upgrading. Trying to upgrade an earlier version will report an error on the game console. Update the Inventory Sensor mod to 2.0.3 or newer.]
