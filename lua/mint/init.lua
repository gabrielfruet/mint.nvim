local M = {}

local marks = require('mint.marks')

function M.setup()
    vim.print('i was called too')
    marks.run()
end

return M
