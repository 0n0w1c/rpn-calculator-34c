-- control.lua

require("rpn")

local function on_lua_shortcut(event)
    if event.prototype_name ~= "rpn_4func" then return end
    local player = game.get_player(event.player_index)
    if player then toggle_calculator(player) end
end

local function on_gui_click(event)
    local element = event.element
    if not (element and element.valid) then return end
    if element.name:sub(1, 3) == "rpn" then
        local player = game.get_player(event.player_index)
        if player then handle_rpn_click(event, player) end
    end
end

script.on_event(defines.events.on_lua_shortcut, on_lua_shortcut)
script.on_event(defines.events.on_gui_click, on_gui_click)
script.on_event(defines.events.on_gui_location_changed, rpn_on_gui_location_changed)
