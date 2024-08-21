local M = {}

function M.get_highlight_color(group_name)
    local hl_details = vim.api.nvim_get_hl(0, { name = group_name, link=false })

    local function rgb_to_hex(rgb)
        if not rgb or rgb == "none" then return "none" end
        return string.format("#%06x", rgb)
    end

    return {
        fg = rgb_to_hex(hl_details.fg),
        bg = rgb_to_hex(hl_details.bg),
        sp = rgb_to_hex(hl_details.sp)
    }
end

local _cached_queries = {}
---@param lang string
---@return vim.treesitter.Query?
---@source https://github.com/stevearc/quicker.nvim/blob/master/lua/quicker/highlight.lua
local function get_highlight_query(lang)
    local query = _cached_queries[lang]
    if query == nil then
        query = vim.treesitter.query.get(lang, "highlights") or false
        _cached_queries[lang] = query
    end
    if query then
        return query
    end
end

---@source https://github.com/stevearc/quicker.nvim/blob/master/lua/quicker/highlight.lua
function M.buf_get_ts_highlights(bufnr, lnum)
    local filetype = vim.bo[bufnr].filetype
    if not filetype or filetype == "" then
        filetype = vim.filetype.match({ buf = bufnr }) or ""
    end
    local lang = vim.treesitter.language.get_lang(filetype) or filetype
    if lang == "" then
        return {}
    end
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang)
    if not ok or not parser then
        return {}
    end

    local row = lnum - 1
    if not parser:is_valid() then
        parser:parse(true)
    end

    local highlights = {}
    parser:for_each_tree(function(tstree, tree)
        if not tstree then
            return
        end

        local root_node = tstree:root()
        local root_start_row, _, root_end_row, _ = root_node:range()

        -- Only worry about trees within the line range
        if root_start_row > row or root_end_row < row then
            return
        end

        local query = get_highlight_query(tree:lang())

        -- Some injected languages may not have highlight queries.
        if not query then
            return
        end

        for capture, node, metadata in query:iter_captures(root_node, bufnr, row, root_end_row + 1) do
            if capture == nil then
                break
            end

            local range = vim.treesitter.get_range(node, bufnr, metadata[capture])
            local start_row, start_col, _, end_row, end_col, _ = unpack(range)
            if start_row > row then
                break
            end
            local capture_name = query.captures[capture]
            local hl = string.format("@%s.%s", capture_name, tree:lang())
            if end_row > start_row then
                end_col = -1
            end
            table.insert(highlights, { start_col, end_col, hl })
        end
    end)

    return highlights
end

return M
