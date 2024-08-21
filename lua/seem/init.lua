local M = {}

local marks = require('seem.marks')

function M.setup()
    vim.print('i was called too')
    marks.run()
end

return M
