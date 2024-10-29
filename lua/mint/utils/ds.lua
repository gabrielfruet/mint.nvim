local M = {}

local DefaultTable = {
    __index = function (mk, key)
        mk._tbl[key] = mk._tbl[key] or mk._default()
        return mk._tbl[key]
    end
}

function DefaultTable:new(o, default_factory)
    o = o or {}
    default_factory = default_factory or function () return {} end
    local obj = {
        _tbl = o,
        _default = default_factory
    }
    setmetatable(obj, self)
    return obj
end

M.DefaultTable = DefaultTable

return M
