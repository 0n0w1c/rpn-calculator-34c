-- rpn-styles.lua

local default_gui = data.raw["gui-style"].default

default_gui.rpn_icon_button =
{
    type = "button_style",
    parent = "button",
    default_font_color = {},
    size = 38,
    top_padding = 1,
    right_padding = 0,
    bottom_padding = 1,
    left_padding = 0,
    left_click_sound = { { filename = "__core__/sound/gui-square-button.ogg", volume = 1 } },
    default_graphical_set =
    {
        filename = "__core__/graphics/gui.png",
        corner_size = 3,
        position = { 8, 0 },
        scale = 1
    }
}

default_gui.rpn_button_style = {
    type = "button_style",
    parent = "rpn_icon_button",
    top_padding = 0,
    right_padding = 0,
    bottom_padding = 0,
    left_padding = 0,
    height = 50,
    width = 50,
    scalable = false
}
default_gui.rpn_button_style_light = {
    type = "button_style",
    parent = "rpn_button_style",
    sprite = "sprite_rpn_light"
}
default_gui.rpn_button_style_dark = {
    type = "button_style",
    parent = "rpn_button_style",
    sprite = "sprite_rpn_dark"
}

default_gui.rpn_button_style_dark_wide = {
    type = "button_style",
    parent = "rpn_button_style_dark",
    width = 104
}

default_gui.rpn_button_style_light_wide = {
    type = "button_style",
    parent = "rpn_button_style_light",
    width = 104
}



default_gui.rpn_display_frame_style = {
    type = "frame_style",
    parent = "inside_shallow_frame_with_padding",
    top_padding = 4,
    right_padding = 10,
    bottom_padding = 4,
    left_padding = 10,
    width = 236,
    height = 36
}

default_gui.rpn_led_label_style = {
    type = "label_style",
    parent = "label",
    font = "default-large",
    font_color = { 1.0, 0.22, 0.12 },
    single_line = true,
    vertical_align = "center",
    horizontal_align = "right"
}
-- sprites
data:extend({
    {
        type = "sprite",
        name = "sprite_rpn_calculator",
        filename = "__rpn-calculator-34c__/graphics/calculator.png",
        width = 64,
        height = 64
    },
    {
        type = "sprite",
        name = "sprite_rpn_backspace",
        filename = "__rpn-calculator-34c__/graphics/backspace.png",
        width = 50,
        height = 50
    },
    {
        type = "sprite",
        name = "sprite_rpn_light",
        filename = "__rpn-calculator-34c__/graphics/light.png",
        width = 50,
        height = 50
    },
    {
        type = "sprite",
        name = "sprite_rpn_dark",
        filename = "__rpn-calculator-34c__/graphics/dark.png",
        width = 50,
        height = 50
    }
})
