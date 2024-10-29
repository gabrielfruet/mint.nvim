local M = {}

local dsutils = require('fruet.utils.ds')
local hlutils = require('fruet.utils.hl')

local lclet = {}
local uclet = {}
local allet = {}

for i = string.byte('a'), string.byte('z') do
    table.insert(lclet, i)
    table.insert(allet, i)
end

-- Populate the table with ASCII codes for A to Z
for i = string.byte('A'), string.byte('Z') do
    table.insert(uclet, i)
    table.insert(allet, i)
end


local function ischar(char)
    local byte = string.byte(char)
    return
        string.byte('a') <= byte and string.byte('z') >= byte
        or
        string.byte('A') <= byte and string.byte('Z') >= byte
end

---@class Mark
---@field bufnr integer
---@field lnum integer
---@field cnum integer
---@field register string
local Mark = {}

function Mark:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

---@return integer[]
function Mark:cursor()
    return {self.lnum, self.cnum}
end

function Mark:name()
    return 'Mark ' .. string.byte(self.register)
end

function Mark:is_global()
    return self.register:upper() == self.register
end

function Mark:delete()
    if self:is_global() then
        vim.api.nvim_del_mark(self.register)
    else
        vim.api.nvim_buf_del_mark(self.bufnr, self.register)
    end
end

local function define_az_marks()
    for i = string.byte('a'), string.byte('z') do
        vim.fn.sign_define('Mark ' .. i, {text=string.char(i)})
    end
end

local function define_AZ_marks()
    for i = string.byte('A'), string.byte('Z') do
        vim.fn.sign_define('Mark ' .. i, {text=string.char(i)})
    end
end

function M.update_global_marks_buffer(bufnr)
    local function rmv_mark_sign(i, bufnr)
        vim.fn.sign_unplace('bookmarks', {buffer=bufnr, id=i})
        M.globalmarks[i] = nil
    end
    local function add_mark_sign(i, bufnr, mark)
        if M.globalmarks[i] ~= nil then
            rmv_mark_sign(i, bufnr)
        end
        M.globalmarks[i] = Mark:new({
            bufnr=bufnr,
            lnum=mark[1],
            cnum=mark[2],
            register=string.char(i),
        })

        vim.fn.sign_place(i, 'bookmarks', 'Mark ' .. i, bufnr, {lnum=mark[1], priority=100})
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    for _, i in pairs(uclet) do
        local mark = vim.api.nvim_buf_get_mark(bufnr, string.char(i))
        if mark[1] ~= 0 then
            add_mark_sign(i,bufnr,mark)
        else
            rmv_mark_sign(i,bufnr)
        end
    end
end


function M.update_local_marks_buffer(bufnr)
    local function rmv_mark_sign(i, bufnr)
        local ret = vim.fn.sign_unplace('bookmarks', {buffer=bufnr, id=i})
        M.localmarks[bufnr][i] = nil
    end
    local function add_mark_sign(i, bufnr, mark)
        if M.localmarks[bufnr] ~= nil and M.localmarks[bufnr][i] ~= nil then
            rmv_mark_sign(i, bufnr)
        end
        M.localmarks[bufnr][i] = Mark:new({
            bufnr=bufnr,
            lnum=mark[1],
            cnum=mark[2],
            register=string.char(i),
        })
        vim.fn.sign_place(i, 'bookmarks', 'Mark ' .. i, bufnr, {lnum=mark[1], priority=100})
    end

    bufnr = bufnr or vim.api.nvim_get_current_buf()
    for _, i in pairs(allet) do
        local mark = vim.api.nvim_buf_get_mark(bufnr, string.char(i))
        if mark[1] ~= 0 then
            add_mark_sign(i,bufnr,mark)
        else
            rmv_mark_sign(i,bufnr)
        end
    end
end

local function show_local_marks()
    local bufnr = vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()
    local marks = M.localmarks[bufnr]

    local list = {}

    for _, mark in pairs(marks) do
        -- i think this is 0-indexing
        local content = vim.api.nvim_buf_get_lines(bufnr, mark.lnum-1, mark.lnum, true)[1]
        table.insert(list, {
            bufnr = mark.bufnr,
            module = ' ' .. mark.register .. ' ',
            lnum = mark.lnum,
            col = mark.cnum,
            text = content,
        })
    end
    vim.fn.setloclist(winnr, {}, ' ', {items=list})
    vim.cmd[[lopen]]
end

---@param fbufnr integer buffer of the floating window
---@param fwinnr integer window of the floating window
---@param marks Mark[] ordered marks
local function show_local_marks_set_keymaps(fbufnr, fwinnr, bufnr, winnr, marks)
    local set_opts = { noremap = true, silent = true, buffer=fbufnr}
    vim.keymap.set('n', 'q', function()
        vim.api.nvim_buf_delete(fbufnr, {})
    end, set_opts)

    ---@type table<string, integer>
    local marks_float_idx_by_char = {}

    for i, mark in ipairs(marks) do
        marks_float_idx_by_char[mark.register] = i
    end

    local function handle_mark(char)
        local line = marks_float_idx_by_char[char]
        vim.api.nvim_win_set_cursor(fwinnr, {line,0})
    end

    local function capture_mark()
        local char = vim.fn.getcharstr()
        if ischar(char) then handle_mark(char) end
    end

    local function delete_mark()
        local cursor = vim.api.nvim_win_get_cursor(fwinnr)
        local lnum = cursor[1]
        vim.api.nvim_set_option_value('modifiable',true, {buf=fbufnr})

        vim.api.nvim_buf_set_lines(fbufnr, lnum-1, lnum, true, {})

        marks[lnum]:delete()
        table.remove(marks, lnum)

        vim.api.nvim_set_option_value('modifiable',false, {buf=fbufnr})
        M.update_local_marks_buffer(bufnr)

        if #marks == 0 then
            vim.api.nvim_win_close(fwinnr, true)
        end
    end

    vim.keymap.set('n', "'", capture_mark, set_opts)
    vim.keymap.set('n', "dm", delete_mark, set_opts)
end

local function show_local_marks_open_window(winnr)
    local win_width = vim.api.nvim_win_get_width(0)
    local win_height = vim.api.nvim_win_get_height(0)

    local height = 10
    local width = 50

    local row = 0
    local col = win_width

    local winopts = {
        relative='win',
        win=winnr,
        width=width,
        height=height,
        col=col,
        row=0,
        style='minimal',
        border='rounded'
    }

    local float_bufnr = vim.api.nvim_create_buf(false, true)

    local winhan = vim.api.nvim_open_win(float_bufnr, true, winopts)
    return float_bufnr, winhan
end

local function show_local_marks2()
    local bufnr = vim.api.nvim_get_current_buf()
    local winnr = vim.api.nvim_get_current_win()
    local marks_by_mark = M.localmarks[bufnr]
    local marks = {}
    for _, mark in pairs(marks_by_mark) do
        table.insert(marks, mark)
    end

    table.sort(marks, function (a,b)
        return a.lnum < b.lnum
    end)

    local n = 0
    for _, mark in pairs(marks) do if mark ~= nil then n = n + 1 end end
    if n == 0 then
        vim.api.nvim_err_write('No available marks for this buffer')
        vim.print('No available marks for this buffer')
        return
    end

    local float_bufnr, winhan = show_local_marks_open_window(winnr)

    local augroup = vim.api.nvim_create_augroup('ShowLocalMarks', {clear=true})

    vim.api.nvim_set_option_value('bufhidden', "delete", {buf=float_bufnr})
    vim.api.nvim_set_option_value('wrap',false, {win=winhan})

    local ns_id = vim.api.nvim_create_namespace("mark_selected_highlight")

    ---@type Mark[]
    local line_mark_map = {}
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    for _, mark in pairs(marks) do
        -- this has to be done because marks can 'fall' if some line got deleted
        local lnum = math.min(mark.lnum, line_count)
        local content = vim.api.nvim_buf_get_lines(bufnr, lnum-1, lnum, false)[1]
        local i = #line_mark_map
        local placehold_mark_text = '\'' .. mark.register .. ' | '
        local pad = #placehold_mark_text

        vim.api.nvim_buf_set_lines(float_bufnr, i, i+1, false, {placehold_mark_text .. content})
        vim.api.nvim_buf_add_highlight(float_bufnr, ns_id, '@text.warning', i, 1, 2)

        for _, hldetails in pairs(hlutils.buf_get_ts_highlights(bufnr, mark.lnum)) do
            local start_col, end_col, hl_group = table.unpack(hldetails)
            vim.api.nvim_buf_add_highlight(float_bufnr, ns_id, hl_group, i, start_col+pad, end_col+pad)
        end

        table.insert(line_mark_map, mark)
    end

    local last_hl_mark = line_mark_map[1]

    local function find_mark_by_float_line(marks, line)
        for i, mark in pairs(marks) do
            if i == line then
                return mark
            end
        end
    end

    vim.api.nvim_create_autocmd('CursorMoved', {
        group=augroup,
        buffer=float_bufnr,
        callback=function ()
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id, last_hl_mark.lnum-1, last_hl_mark.lnum)
            local cursor = vim.api.nvim_win_get_cursor(winhan)
            local selected_line = cursor[1]
            local mark = find_mark_by_float_line(marks, selected_line)
            last_hl_mark = mark
            vim.api.nvim_win_set_cursor(winnr, mark:cursor())
            local hl_id = vim.api.nvim_buf_add_highlight(bufnr, ns_id, "Visual", mark.lnum-1, 0, -1)
        end
    })

    vim.api.nvim_create_autocmd('BufLeave', {
        group=augroup,
        buffer=float_bufnr,
        callback=function ()
            vim.api.nvim_win_close(winhan, true)
            vim.api.nvim_buf_delete(float_bufnr, {force=true})
            vim.api.nvim_buf_clear_namespace(bufnr, ns_id, last_hl_mark.lnum-1, last_hl_mark.lnum)
        end
    })

    vim.api.nvim_set_option_value('modifiable',false, {buf=float_bufnr})
    show_local_marks_set_keymaps(float_bufnr, winhan, bufnr, winnr, marks)
end

function M.delete_mark_at_cursor(winnr, bufnr)
    winnr = winnr or 0
    bufnr = bufnr or vim.api.nvim_win_get_buf(winnr)
    local marks = M.localmarks[bufnr]
    local cursor = vim.api.nvim_win_get_cursor(winnr)
    local lnum = cursor[1]

    for _, mark in pairs(marks) do
        if mark.lnum == lnum then
            mark:delete()
        end
    end
end

function M.run()
    ---@type table<integer,  Mark>
    M.globalmarks = {}
    ---@type table<integer, table<integer, Mark>>
    M.localmarks = dsutils.DefaultTable:new()

    define_az_marks()
    define_AZ_marks()

    vim.api.nvim_create_autocmd({'BufEnter', 'CursorMoved'}, {
        group=vim.api.nvim_create_augroup('AddLocalMarkToBuffer', {clear=true}),
        callback=function(opts) M.update_local_marks_buffer(opts.bufnr) end
    })
    vim.api.nvim_create_autocmd({'BufEnter', 'CursorMoved'}, {
        group=vim.api.nvim_create_augroup('AddGlobalMarkToBuffer', {clear=true}),
        callback=function(opts) M.update_global_marks_buffer(opts.bufnr) end
    })
    vim.api.nvim_create_user_command("ShowLocalMarks", show_local_marks2, {})
    vim.keymap.set('n', 'm?', show_local_marks2, {})
    vim.keymap.set('n', 'dm', M.delete_mark_at_cursor, {})
end

return M
