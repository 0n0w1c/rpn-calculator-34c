-- rpn.lua

local function get_gui_root(player)
    return player.gui.screen
end

local function ensure_player_state(player)
    storage.rpn_state = storage.rpn_state or {}
    storage.rpn_state[player.index] = storage.rpn_state[player.index] or {
        stack = {},
        history = {},
        entry_fresh = false,
        entry_text = "",
        lastx = nil
    }
    return storage.rpn_state[player.index]
end

local function get_state(player)
    return ensure_player_state(player)
end

local function set_shortcut_toggled(player, toggled)
    if player and player.valid then
        player.set_shortcut_toggled("rpn_4func", toggled)
    end
end

local function destroy_calculator(player)
    local root = get_gui_root(player)
    if root.rpn then
        root.rpn.destroy()
    end
    set_shortcut_toggled(player, false)
end

local function fix_oob_ui(player)
    storage.gui_position = storage.gui_position or {}
    local pos = storage.gui_position[player.index]
    if not pos then return end
    if pos.x < 0 then pos.x = 0 end
    if pos.y < 0 then pos.y = 0 end

    local width = 470
    local height = 560

    if pos.x + width > player.display_resolution.width then
        pos.x = math.max(0, player.display_resolution.width - width)
    end
    if pos.y + height > player.display_resolution.height then
        pos.y = math.max(0, player.display_resolution.height - height)
    end
end

local function format_number(player, value)
    if value == nil then return "" end
    if value ~= value or value == math.huge or value == -math.huge then return "NaN" end

    local decimals = 8
    local abs_value = math.abs(value)
    local text
    if (abs_value ~= 0 and abs_value >= 1000000000) or (abs_value > 0 and abs_value < (10 ^ (-decimals))) then
        text = string.format("%." .. decimals .. "e", value)
    else
        text = string.format("%." .. decimals .. "f", value)
        text = text:gsub("(%..-)0+$", "%1")
        text = text:gsub("%.$", "")
    end
    return text
end

local function led_element(player)
    return get_gui_root(player).rpn.rpn_table.rpn_table_col1.rpn_display_frame.rpn_display_led
end

local function read_entry(player)
    local state = get_state(player)
    return state.entry_text or ""
end

local function peek_stack(player, depth)
    local state = get_state(player)
    local index = #state.stack - (depth or 0)
    if index < 1 then return nil end
    return state.stack[index]
end

local function sync_led_display(player)
    local root = get_gui_root(player)
    if not (root and root.rpn) then return end
    local led = led_element(player)
    local entry = read_entry(player)
    local state = get_state(player)
    if entry ~= "" and not state.entry_fresh then
        led.caption = entry
        led.tooltip = entry
    else
        local x = peek_stack(player, 0)
        local caption = format_number(player, x)
        led.caption = caption
        led.tooltip = caption
    end
end

local function clear_entry(player)
    local state = get_state(player)
    state.entry_text = ""
    state.entry_fresh = false
    sync_led_display(player)
end

local function mark_entry_fresh(player)
    local state = get_state(player)
    state.entry_text = ""
    state.entry_fresh = true
    sync_led_display(player)
end

local function parse_entry(player)
    local text = read_entry(player)
    if text == "" then return nil end
    text = text:gsub(",", ".")
    text = text:gsub("'", "")
    local value = tonumber(text)
    return value
end

local function save_lastx(player, value)
    local state = get_state(player)
    state.lastx = value
end

local function push_history(player, text)
    local state = get_state(player)
    table.insert(state.history, 1, text)
    while #state.history > 24 do
        table.remove(state.history)
    end
end

local function push_stack(player, value)
    local state = get_state(player)
    table.insert(state.stack, value)
    while #state.stack > 4 do
        table.remove(state.stack, 1)
    end
end

local function pop_stack(player)
    local state = get_state(player)
    return table.remove(state.stack)
end

local function peek_stack(player, depth)
    local state = get_state(player)
    local index = #state.stack - (depth or 0)
    if index < 1 then return nil end
    return state.stack[index]
end

local function set_stack_display(player)
    local root = get_gui_root(player)
    if not (root and root.rpn) then return end
    local stack_table = root.rpn.rpn_table.rpn_table_col2.rpn_stack_frame.rpn_stack_table
    local labels = { "T", "Z", "Y", "X" }
    for i, reg in ipairs(labels) do
        local value = peek_stack(player, 4 - i)
        stack_table["rpn_stack_value_" .. reg].caption = format_number(player, value)
    end
end

local function draw_recent_table(player)
    local root = get_gui_root(player)
    if not (root and root.rpn) then return end
    local history_table = root.rpn.rpn_table.rpn_table_col2.rpn_history_frame.rpn_history_pane
        .rpn_result_table
    history_table.clear()
    for i, text in ipairs(get_state(player).history) do
        history_table.add({
            type = "label",
            name = "rpn_history_" .. i,
            caption = text
        })
    end
end

local function refresh_ui(player)
    sync_led_display(player)
    set_stack_display(player)
    draw_recent_table(player)
end

function show_calculator(player)
    local root = get_gui_root(player)
    ensure_player_state(player)

    if not root.rpn then
        local rpn = root.add({ type = "frame", name = "rpn", direction = "vertical" })
        local flow = rpn.add({ type = "flow", name = "rpn_flow" })
        flow.style.horizontally_stretchable = true

        flow.add({
            type = "label",
            name = "rpn_title",
            caption = "RPN Calculator 34C",
            style = "frame_title"
        }).drag_target = rpn

        local widget = flow.add({ type = "empty-widget", style = "draggable_space_header", name = "rpn_drag" })
        widget.drag_target = rpn
        widget.style.horizontally_stretchable = true
        widget.style.minimal_width = 24
        widget.style.natural_height = 24

        flow.add({ type = "sprite-button", sprite = "utility/close", style = "frame_action_button", name = "rpn_close" })

        local table = rpn.add({ type = "table", name = "rpn_table", column_count = 2, vertical_centering = false })

        local col1 = table.add({ type = "flow", name = "rpn_table_col1", direction = "vertical" })
        local display_frame = col1.add({
            type = "frame",
            name = "rpn_display_frame",
            direction = "horizontal",
            style = "rpn_display_frame_style"
        })
        display_frame.style.width = 236
        local display_led = display_frame.add({
            type = "label",
            name = "rpn_display_led",
            caption = "",
            style = "rpn_led_label_style"
        })
        display_led.style.width = 214

        local row1 = col1.add({ type = "flow", name = "rpn_col1_row1", direction = "horizontal" })
        row1.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "", tooltip = "Backspace", name = "rpn_button_BS" }).sprite =
        "sprite_rpn_backspace"
        row1.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "C", tooltip = "Clear all", name = "rpn_button_C" }).sprite =
        "sprite_rpn_dark"
        row1.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "CLX", tooltip = "Clear X", name = "rpn_button_CLX" }).sprite =
        "sprite_rpn_dark"
        row1.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "DROP", tooltip = "Drop X", name = "rpn_button_DROP" }).sprite =
        "sprite_rpn_dark"

        local row1b = col1.add({ type = "flow", name = "rpn_col1_row1b", direction = "horizontal" })
        row1b.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "R↓", tooltip = "Roll down", name = "rpn_button_RDN" }).sprite =
        "sprite_rpn_dark"
        row1b.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "SWAP", tooltip = "Swap X and Y", name = "rpn_button_SWAP" }).sprite =
        "sprite_rpn_dark"
        row1b.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "LASTX", tooltip = "Recall last X", name = "rpn_button_LASTX" }).sprite =
        "sprite_rpn_dark"
        row1b.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "√x", tooltip = "Square root", name = "rpn_button_SQRT" }).sprite =
        "sprite_rpn_dark"

        local row2 = col1.add({ type = "flow", name = "rpn_col1_row2", direction = "horizontal" })
        row2.add({
            type = "button",
            style = "rpn_button_style_dark_wide",
            caption = "ENTER",
            tooltip = "Enter",
            name = "rpn_button_ENT"
        })
        row2.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "%", tooltip = "Percent of Y", name = "rpn_button_PERCENT" }).sprite =
        "sprite_rpn_dark"
        row2.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "1/x", tooltip = "Reciprocal", name = "rpn_button_INV" }).sprite =
        "sprite_rpn_dark"

        local row3 = col1.add({ type = "flow", name = "rpn_col1_row3", direction = "horizontal" })
        row3.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "-", tooltip = "Subtract", name = "rpn_button_SUB" }).sprite =
        "sprite_rpn_dark"
        row3.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "7", tooltip = "7", name = "rpn_button_7" }).sprite =
        "sprite_rpn_light"
        row3.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "8", tooltip = "8", name = "rpn_button_8" }).sprite =
        "sprite_rpn_light"
        row3.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "9", tooltip = "9", name = "rpn_button_9" }).sprite =
        "sprite_rpn_light"

        local row4 = col1.add({ type = "flow", name = "rpn_col1_row4", direction = "horizontal" })
        row4.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "+", tooltip = "Add", name = "rpn_button_ADD" }).sprite =
        "sprite_rpn_dark"
        row4.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "4", tooltip = "4", name = "rpn_button_4" }).sprite =
        "sprite_rpn_light"
        row4.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "5", tooltip = "5", name = "rpn_button_5" }).sprite =
        "sprite_rpn_light"
        row4.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "6", tooltip = "6", name = "rpn_button_6" }).sprite =
        "sprite_rpn_light"

        local row5 = col1.add({ type = "flow", name = "rpn_col1_row5", direction = "horizontal" })
        row5.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "*", tooltip = "Multiply", name = "rpn_button_MUL" }).sprite =
        "sprite_rpn_dark"
        row5.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "1", tooltip = "1", name = "rpn_button_1" }).sprite =
        "sprite_rpn_light"
        row5.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "2", tooltip = "2", name = "rpn_button_2" }).sprite =
        "sprite_rpn_light"
        row5.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "3", tooltip = "3", name = "rpn_button_3" }).sprite =
        "sprite_rpn_light"

        local row6 = col1.add({ type = "flow", name = "rpn_col1_row6", direction = "horizontal" })
        row6.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "/", tooltip = "Divide", name = "rpn_button_DIV" }).sprite =
        "sprite_rpn_dark"
        row6.add({ type = "sprite-button", style = "rpn_button_style_light", caption = "0", tooltip = "0", name = "rpn_button_0" }).sprite =
        "sprite_rpn_light"
        row6.add({ type = "sprite-button", style = "rpn_button_style_light", caption = ".", tooltip = "Decimal point", name = "rpn_button_DOT" }).sprite =
        "sprite_rpn_light"
        row6.add({ type = "sprite-button", style = "rpn_button_style_dark", caption = "+/-", tooltip = "Change sign", name = "rpn_button_CHS" }).sprite =
        "sprite_rpn_dark"

        local col2 = table.add({ type = "flow", name = "rpn_table_col2", direction = "vertical" })
        col2.style.vertical_spacing = 8
        local stack_frame = col2.add({
            type = "frame",
            name = "rpn_stack_frame",
            direction = "vertical",
            style = "inside_shallow_frame_with_padding"
        })
        stack_frame.style.width = 200
        stack_frame.style.top_padding = 6
        stack_frame.style.right_padding = 8
        stack_frame.style.bottom_padding = 6
        stack_frame.style.left_padding = 8
        stack_frame.add({ type = "label", caption = "Stack", name = "rpn_stack_title" })

        local stack_table = stack_frame.add({ type = "table", name = "rpn_stack_table", column_count = 2 })
        stack_table.style.horizontal_spacing = 10
        stack_table.style.vertical_spacing = 4
        for _, reg in ipairs({ "T", "Z", "Y", "X" }) do
            stack_table.add({
                type = "label",
                caption = reg,
                name = "rpn_stack_label_" .. reg
            })
            stack_table.add({
                type = "label",
                caption = "",
                name = "rpn_stack_value_" .. reg,
                tooltip = "Stack register value"
            })
        end

        local history_frame = col2.add({
            type = "frame",
            name = "rpn_history_frame",
            direction = "vertical",
            style = "inside_shallow_frame_with_padding"
        })
        history_frame.style.width = 200
        history_frame.style.height = 236
        history_frame.style.top_padding = 6
        history_frame.style.right_padding = 8
        history_frame.style.bottom_padding = 8
        history_frame.style.left_padding = 8
        history_frame.add({ type = "label", caption = "History", name = "rpn_history_title" })
        local history = history_frame.add({ type = "scroll-pane", name = "rpn_history_pane" })
        history.style.horizontally_stretchable = true
        history.style.vertically_stretchable = true
        history.style.minimal_height = 188
        history.style.maximal_height = 188
        history.add({ type = "table", caption = "", name = "rpn_result_table", column_count = 1 })

        storage.gui_position = storage.gui_position or {}
        if storage.gui_position[player.index] then
            fix_oob_ui(player)
            rpn.location = storage.gui_position[player.index]
        else
            rpn.force_auto_center()
        end

        refresh_ui(player)
    end
    set_shortcut_toggled(player, true)
end

local function hide_calculator(player)
    destroy_calculator(player)
end

function toggle_calculator(player, extended_mode)
    extended_mode = extended_mode or false
    local root = get_gui_root(player)
    if root and root.rpn then
        hide_calculator(player)
    else
        show_calculator(player)
    end
end

local function process_c_key(player)
    local state = get_state(player)
    state.stack = {}
    state.history = {}
    state.lastx = nil
    clear_entry(player)
    refresh_ui(player)
end

local function process_backspace_key(player)
    local state = get_state(player)
    state.entry_text = string.sub(read_entry(player), 1, -2)
    state.entry_fresh = false
    sync_led_display(player)
end

local function push_current_entry(player)
    local value = parse_entry(player)
    if value == nil then
        return false
    end
    push_stack(player, value)
    push_history(player, "ENT " .. format_number(player, value))
    mark_entry_fresh(player)
    refresh_ui(player)
    return true
end

local function ensure_entry_committed(player)
    if read_entry(player) ~= "" then
        return push_current_entry(player)
    end
    return true
end

local function apply_binary(player, symbol, fn)
    if not ensure_entry_committed(player) then return end
    local x = pop_stack(player)
    local y = pop_stack(player)
    if x == nil or y == nil then
        if y ~= nil then push_stack(player, y) end
        if x ~= nil then push_stack(player, x) end
        refresh_ui(player)
        return
    end
    save_lastx(player, x)
    local ok, result = pcall(fn, y, x)
    if not ok or result == nil or result ~= result or result == math.huge or result == -math.huge then
        push_stack(player, y)
        push_stack(player, x)
        refresh_ui(player)
        return
    end
    push_stack(player, result)
    mark_entry_fresh(player)
    push_history(player,
        string.format("%s %s %s -> %s", format_number(player, y), format_number(player, x), symbol,
            format_number(player, result)))
    refresh_ui(player)
end

local function process_equal_key(player)
    if read_entry(player) ~= "" and not get_state(player).entry_fresh then
        push_current_entry(player)
        return
    end

    local x = peek_stack(player, 0)
    if x == nil then
        refresh_ui(player)
        return
    end

    push_stack(player, x)
    mark_entry_fresh(player)
    push_history(player, "ENT " .. format_number(player, x))
    refresh_ui(player)
end

local function process_chs_key(player)
    if read_entry(player) ~= "" then
        local state = get_state(player)
        if string.sub(state.entry_text, 1, 1) == "-" then
            state.entry_text = string.sub(state.entry_text, 2)
        else
            state.entry_text = "-" .. state.entry_text
        end
        state.entry_fresh = false
        sync_led_display(player)
        return
    end
    local x = pop_stack(player)
    if x == nil then
        return
    end
    save_lastx(player, x)
    x = -x
    push_stack(player, x)
    mark_entry_fresh(player)
    push_history(player, "+/- -> " .. format_number(player, x))
    refresh_ui(player)
end

local function process_drop_key(player)
    if read_entry(player) ~= "" then
        clear_entry(player)
        return
    end
    local x = pop_stack(player)
    if x == nil then
        return
    end
    save_lastx(player, x)
    mark_entry_fresh(player)
    push_history(player, "DROP " .. format_number(player, x))
    refresh_ui(player)
end

local function process_swap_key(player)
    if not ensure_entry_committed(player) then return end
    local x = pop_stack(player)
    local y = pop_stack(player)
    if x == nil or y == nil then
        if y ~= nil then push_stack(player, y) end
        if x ~= nil then push_stack(player, x) end
        refresh_ui(player)
        return
    end
    save_lastx(player, x)
    push_stack(player, x)
    push_stack(player, y)
    mark_entry_fresh(player)
    push_history(player, "SWAP")
    refresh_ui(player)
end

local function process_clx_key(player)
    if read_entry(player) ~= "" then
        clear_entry(player)
        return
    end
    local x = pop_stack(player)
    if x == nil then
        return
    end
    save_lastx(player, x)
    push_stack(player, 0)
    mark_entry_fresh(player)
    push_history(player, "CLX")
    refresh_ui(player)
end

local function process_percent_key(player)
    if not ensure_entry_committed(player) then return end
    local x = pop_stack(player)
    local y = pop_stack(player)
    if x == nil or y == nil then
        if y ~= nil then push_stack(player, y) end
        if x ~= nil then push_stack(player, x) end
        refresh_ui(player)
        return
    end
    save_lastx(player, x)
    local result = (y * x) / 100
    push_stack(player, result)
    mark_entry_fresh(player)
    push_history(player,
        string.format("%s %% of %s -> %s", format_number(player, x), format_number(player, y),
            format_number(player, result)))
    refresh_ui(player)
end

local function process_rdn_key(player)
    if not ensure_entry_committed(player) then return end
    local state = get_state(player)
    local n = #state.stack
    if n < 2 then
        refresh_ui(player)
        return
    end
    local start_index = math.max(1, n - 3)
    local first = state.stack[start_index]
    for i = start_index, n - 1 do
        state.stack[i] = state.stack[i + 1]
    end
    state.stack[n] = first
    state.entry_fresh = true
    push_history(player, "R↓")
    refresh_ui(player)
end

local function process_lastx_key(player)
    if not ensure_entry_committed(player) then return end
    local state = get_state(player)
    if state.lastx == nil then
        refresh_ui(player)
        return
    end
    push_stack(player, state.lastx)
    state.entry_fresh = true
    push_history(player, "LASTX " .. format_number(player, state.lastx))
    refresh_ui(player)
end

local function process_inv_key(player)
    if not ensure_entry_committed(player) then return end
    local x = pop_stack(player)
    if x == nil or x == 0 then
        if x ~= nil then push_stack(player, x) end
        refresh_ui(player)
        return
    end
    save_lastx(player, x)
    local result = 1 / x
    push_stack(player, result)
    mark_entry_fresh(player)
    push_history(player, string.format("1/%s -> %s", format_number(player, x), format_number(player, result)))
    refresh_ui(player)
end

local function process_sqrt_key(player)
    if not ensure_entry_committed(player) then return end
    local x = pop_stack(player)
    if x == nil or x < 0 then
        if x ~= nil then push_stack(player, x) end
        refresh_ui(player)
        return
    end
    save_lastx(player, x)
    local result = math.sqrt(x)
    push_stack(player, result)
    mark_entry_fresh(player)
    push_history(player, string.format("√%s -> %s", format_number(player, x), format_number(player, result)))
    refresh_ui(player)
end

local function display_addchar(player, char)
    local state = get_state(player)
    if state.entry_fresh then
        state.entry_text = ""
        state.entry_fresh = false
    end
    state.entry_text = (state.entry_text or "") .. char
    sync_led_display(player)
end

local button_dispatch = {
    ["C"] = process_c_key,
    ["BS"] = process_backspace_key,
    ["DIV"] = function(player) apply_binary(player, "/", function(y, x) return y / x end) end,
    ["MUL"] = function(player) apply_binary(player, "*", function(y, x) return y * x end) end,
    ["SUB"] = function(player) apply_binary(player, "-", function(y, x) return y - x end) end,
    ["ADD"] = function(player) apply_binary(player, "+", function(y, x) return y + x end) end,
    ["ENT"] = process_equal_key,
    ["CHS"] = process_chs_key,
    ["DROP"] = process_drop_key,
    ["SWAP"] = process_swap_key,
    ["PERCENT"] = process_percent_key,
    ["CLX"] = process_clx_key,
    ["RDN"] = process_rdn_key,
    ["LASTX"] = process_lastx_key,
    ["INV"] = process_inv_key,
    ["SQRT"] = process_sqrt_key
}

local button_addchar = {
    ["7"] = "7",
    ["8"] = "8",
    ["9"] = "9",
    ["4"] = "4",
    ["5"] = "5",
    ["6"] = "6",
    ["1"] = "1",
    ["2"] = "2",
    ["3"] = "3",
    ["0"] = "0",
    ["DOT"] = "."
}

function handle_rpn_click(event, player)
    local event_name = event.element.name
    local button_prefix = "rpn_button_"

    if string.sub(event_name, 1, #button_prefix) == button_prefix then
        local button = string.sub(event_name, #button_prefix + 1)
        local dispatch_func = button_dispatch[button]
        if dispatch_func then dispatch_func(player) end
        local addchar = button_addchar[button]
        if addchar then display_addchar(player, addchar) end
    elseif event_name == "rpn_close" then
        hide_calculator(player)
    end
end

function rpn_on_gui_location_changed(event)
    if event.element.name == "rpn" then
        storage.gui_position = storage.gui_position or {}
        storage.gui_position[event.player_index] = event.element.location
    end
end
