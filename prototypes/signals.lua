---@meta
------------------------------------------------------------------------
-- Signals
------------------------------------------------------------------------
local const = require('lib.constants')

local function base_icon_png(name)
    return '__base__/graphics/icons/' .. name .. '.png'
end

local signals = {
    {
        type = 'virtual-signal',
        name = const.signal_names.progress_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = const:png('icon/progress'),           icon_size = 64, icon_mipmaps = 4 },
        },
        icon_size = 32,
        subgroup = 'sensor-signals',
        order = 'is-ba',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.temperature_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = const:png('icon/temperature'),        icon_size = 64, icon_mipmaps = 4 },
        },
        icon_size = 32,
        subgroup = 'sensor-signals',
        order = 'is-bb',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.fuel_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = const:png('icon/fuel'),               icon_size = 64, icon_mipmaps = 4 },
        },
        icon_size = 32,
        subgroup = 'sensor-signals',
        order = 'is-bc',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.charge_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = const:png('icon/charge'),             icon_size = 64, icon_mipmaps = 4 },
        },
        icon_size = 32,
        subgroup = 'sensor-signals',
        order = 'is-bd',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.speed_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = const:png('icon/speed'),           icon_size = 64, icon_mipmaps = 4 },
        },
        icon_size = 32,
        subgroup = 'sensor-signals',
        order = 'is-be',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.power_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = const:png('icon/power'),           icon_size = 64, icon_mipmaps = 4 },
        },
        icon_size = 32,
        subgroup = 'sensor-signals',
        order = 'is-bf',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.car_detected_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = base_icon_png('car'),                 icon_size = 64, icon_mipmaps = 4, scale = 0.375 },
        },
        subgroup = 'sensor-signals',
        order = 'is-da',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.tank_detected_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = base_icon_png('tank'),                icon_size = 64, icon_mipmaps = 4, scale = 0.375 },
        },
        subgroup = 'sensor-signals',
        order = 'is-db',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.spider_detected_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = base_icon_png('spidertron'),          icon_size = 64, icon_mipmaps = 4, scale = 0.375 },
        },
        subgroup = 'sensor-signals',
        order = 'is-dc',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.wagon_detected_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = base_icon_png('cargo-wagon'),         icon_size = 64, icon_mipmaps = 4, scale = 0.375 },
        },
        subgroup = 'sensor-signals',
        order = 'is-dd',
    },
    {
        type = 'virtual-signal',
        name = const.signal_names.locomotive_detected_signal,
        icons = {
            { icon = base_icon_png('signal/signal_green'), icon_size = 64, icon_mipmaps = 4 },
            { icon = base_icon_png('locomotive'),          icon_size = 64, icon_mipmaps = 4, scale = 0.375 },
        },
        subgroup = 'sensor-signals',
        order = 'is-dc',
    }
}

local item_subgroup = {
    type = 'item-subgroup',
    name = 'sensor-signals',
    group = 'signals',
    order = 'x[sensor-signals]'
}

data:extend { item_subgroup }
data:extend(signals)
