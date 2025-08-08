local M = {
    map_file_line = {},
    default_query = [[jq '[ .[] | select((.status!="done") ]] ..
        [[and ((.tags[] == "#today") or (.tags[] == "#important") ) )  ] |]] ..
        [[ sort_by(.due) | unique | sort_by(.due)']],
    work_query = [[ jq '[ .[] | select(.status != "done" and (.tags[] != "#personal" and ( (.tags[] == "#today") or (.tags[] == "#important") ))) ] | sort_by(.due) | unique | sort_by(.due) ]],
    personal_query = [[ jq '[ .[] | select(.status != "done" and ( (.tags[] == "#personal" and ( (.tags[] == "#today") or (.tags[] == "#important") ))) ] | sort_by(.due) | unique | sort_by(.due) ]],

not_query = [[ jq '[ .[] | select(.status != "done" and (.tags[] != "%s" and ( (.tags[] == "today") or (.tags[] == "#important") ))) ] | sort_by(.due) | unique | sort_by(.due) ]],
    -- work_query = [[jq '[ .[] | select((.status!="done") ]] ..
    --     [[and ((.tags[] == "#today") or (.tags[] == "#important")  ) )  ] |]] ..
    --     [[ sort_by(.due) | unique | sort_by(.due)']],
    last_query = nil,
}
-- [[and ((.tags[] == "#today") or (.tags[] == "#important") or (.tags[] == "#main") ) ) ] |]] ..

-- M = class(M, {constructor = function(self, filename)
--     if filename ~= nil then
--         self.filename = filename
--     end
--     self.sql = sql.Sql(self.path .. self.filename)
--     return self
-- end})

function M.open_context_window(filename, line_nr)
    -- local context_width = math.floor(vim.o.columns * 0.4)
    local context_height = math.floor(vim.o.lines * 0.5)
    local context_row = math.floor((vim.o.lines - context_height) / 4)
    local context_col = math.floor(vim.o.columns * 0.55)

    local content = dev.nvim.utils.get_context(filename, line_nr)

    local win = dev.nvim.ui.float.Window.flex()
    win:config(
        {
            -- relative = 'editor',
            -- size = {
            --     absolute = {
            --         width = context_width,
            --         height = context_height,
            --     },
            -- },

            position = {
                absolute = {
                    row = context_row,
                    col = context_col,
                },
            },
            buffer = dev.nvim.ui.views.get_scratch_opt(),
            border = 'single',
            content = content,
            options = {
                buffer = {
                    modifiable = false,
                },
                window = {
                    winbar = 'file context on line ' .. line_nr,
                }
            },
        }
    )

    win:open()

    line_nr = math.floor(#content / 2)
    vim.api.nvim_win_set_cursor(win.vid, { line_nr, 0 })
end

--- Convert a list of tasks to a quickfix list
---@param tasks table
---@return string
function M.to_qfix(tasks)
    local out = ''
    if tasks == nil then
        print('tasks is nil, cannot convert to quickfix')
        return out
    end
    local tasks_qf, _ = M.format_tasks(tasks)
    if tasks_qf == nil then
        print('tasks_qf is nil, cannot convert to quickfix')
        return out
    end
    for _, task in pairs(tasks_qf) do
        out = out .. string.format('%s:%d: %s\n', task.filename, task.lnum, task.text)
    end

    return out
end

function M.set_custom_hl(buf, line)
    local entry = vim.api.nvim_buf_get_lines(buf, line - 1, line, false)[1]

    if entry == nil then
        print(string.format('could not get line %d from buffer', line))
        return
    end
    local due_date = entry:match("due:: (%d%d%d%d%-%d%d%-%d%d)")
    if due_date == nil then
        print('no due date found')
        return
    end
    local hl_group = 'MetaTags'
    vim.api.nvim_set_hl(0, hl_group, { fg = "#7c6f64", italic = true })  -- Adjust the color as needed
    -- Define the namespace for extmarks (you can use the same namespace for multiple extmarks)
    local ns_id = vim.api.nvim_create_namespace('previewer_due')
    -- Create your custom highlight group with color similar to comments

    -- Set virtual text at a given line (line 2 in this case, 0-based index)
    vim.api.nvim_buf_set_extmark(buf, ns_id, line - 1, 0, {
        virt_text = { { string.format("(due: %s) ", due_date), hl_group } }, -- Text and optional highlight group
        virt_text_pos = "inline",
        priority = 100,
        -- virt_text_pos = "eol",  -- Places the virtual text at the end of the line
    })
end

function M.to_lines(tasks)
    local _, files_qf = M.format_tasks(tasks)
    if files_qf == nil then
        print('files_qf is nil, no tasks found')
        return
    end
    local out = {}
    for _, file_qf in pairs(files_qf) do
        -- local file = task.filename:sub(path:len()+1, task.filename:len())
        -- if file[1] == '/' then
        --     file = file.sub(2, file:len())
        -- end
        table.insert(out, string.format('%s:%d:', file_qf.file, file_qf.line))
    end
    vim.cmd('lcd ' ..require"tasks.query".Query.path)

    return out
end

---format tasks to 'file:line: description' format
---@param tasks table
---@return table
function M.format_file_line(tasks)
    if tasks == nil then
        error('tasks is nil')
    end
    local out = {}
    for _, task in pairs(tasks) do
        if task.linenr == nil then
            error('task.linenr is nil')
        end
        table.insert(out, string.format('%s:%d:', task.filename, task.linenr))
    end

    return out
end

function M.format_tasks_short(tasks)
    local tasks_qf = {}
    local format = require"tasks.format"
    for _, task in pairs(tasks) do
        if task.linenr == nil then
            error('task.linenr is nil')
        end
        table.insert(tasks_qf, {
            filename = task.filename,
            lnum = task.linenr,
            text = (task.description or '') ..
                ' ' .. format.params_to_string(task.parameters) ..
                ' ' .. format.tags_to_string(task.tags)
        })
    end

    return tasks_qf
end

function M.format_timeline(tasks_in)
    local tasks = {}
    local file_line = {}
    if tasks_in == nil then
        vim.notify('tasks_in is nil', vim.log.levels.ERROR)
        return
    end
    local glyphs = require('git-icons')

    local first = true
    local last_due = ''
    local i = 0
    local format = require"tasks.format"
    for _, task in pairs(tasks_in) do
        if task.linenr == nil then
            error('task.linenr is nil')
        end
        if last_due ~= task.due then
            if not first then
                table.insert(tasks, glyphs.horizontal_bar)
                table.insert(tasks, glyphs.horizontal_bar)
                table.insert(tasks, '')
                i = i + 2
            end
            local date_tbl = os.time({
                year = task.due:sub(1, 4),
                month = task.due:sub(6, 7),
                day = task.due:sub(9, 10),
                hour = 0,
                min = 0,
                sec = 0
            })
            local date = os.date('%A, %d de %B de %Y', date_tbl)
            table.insert(tasks, ' ' .. date)
            i = i + 1
            first = false
            table.insert(tasks, '')
        else
            table.insert(tasks, glyphs.horizontal_bar)
        end

        i = i + 1
        last_due = task.due

        table.insert(tasks, glyphs.circle .. ' ' .. format.toshortstring(task))
        i = i + 1
        table.insert(file_line, { file = task.filename, line = task.linenr, buf_line = i, due = task.due })
        i = i + 1
    end

    return tasks, file_line
end

function M.format_tasks(tasks_in)
    local tasks = {}
    local file_line = {}
    if tasks_in == nil then
        vim.notify('tasks_in is nil', vim.log.levels.ERROR)
        return
    end
    local format = require"tasks.format"
    for _, task in pairs(tasks_in) do
        if task.linenr == nil then
            error('task.linenr is nil')
        end
        table.insert(tasks, format.tostring(task))
        table.insert(file_line, { file = task.filename, line = task.linenr })
    end

    return tasks, file_line
end

function M.query_by_due()
    local q = require"tasks.query".Query()
    local tasks = q:select_by_tag_and_due()
    M.tasks = tasks

    return tasks
end

function M.query_by_tag_and_due(tag)
    local q = require"tasks.query".Query()
    local tasks = q:select_by_tag_and_due(tag)
    M.tasks = tasks

    return tasks
end

function M.query_by_tag(tag)
    local q = require"tasks.query".Query()
    local tasks = q:select_by_tag(tag)
    M.tasks = tasks

    return tasks
end

function M.parse_entry(entry_str)
    -- Assume an arbitrary entry in the format of 'file:line'
    local task_splited = require"katu.utils".split(entry_str, ':')
    if task_splited == nil then
        error('task_splited is nil')
    end
    local path = task_splited[1]
    local line = task_splited[2]
    return {
        path = string.format('"%s"', path),
        line = tonumber(line) or 1,
        col = 1,
    }
end

function M.fzf_query_due(tag, ...)
    local opts = { ... }
    opts = opts[1] or {}

    if opts.due == nil then
        opts.due = { order = 'ASC' }
    end
    M.fzf_query(tag, opts)
end

M.query_tag = function(tag, ...)
    local opts = { ... }
    opts = opts[1] or {}
    local tasks
    if opts == nil or opts.due == nil then
        tasks = M.query_by_tag(tag)
        -- else
        --     local order = nil
        --     if opts.due ~= nil and opts.due.order ~= nil then
        --         order = opts.due.order
        --     end
        --     tasks = M.query_by_tag_and_due(tag)--, order)
    end
    M.tasks = tasks
    return tasks
end

function M.fzf_query(tasks, ...)
    -- local tasks = M.query_tag(tag, ...)
    tasks = M.to_lines(tasks)
    M.tasks = tasks
    local opts = { ... }
    opts = opts[1] or {}

    -- debug
    local sink = opts.sink or function(selected)
        if selected then
            for _, task in ipairs(selected) do
                local filename, line_nr = require"katu.utils".get_file_line(task, ':')
                if filename and line_nr then
                    vim.cmd.edit(filename)
                    vim.fn.cursor(line_nr, 1)
                end
            end
        end
    end

    require"fzf-lua".fzf_exec(tasks, {
        previewer = require('dev.nvim.ui.fzf_previewer').Previewer,
        prompt    = 'Tasks❯ ',
        cwd       = require"tasks.query".Query.path,
        fzf_opts  = {
            ["--no-sort"] = true,
        },

        -- actions inherit from 'actions.files' and merge
        actions   = {
            ["default"] = sink
        },
    })
    -- require'fzf-lua'.files(str_tasks, task_query_opts)
end

function M.complete(arg_lead, _, _)
    -- These are the valid completions for the command
    local options = {
        "due",
        "tag",
        "duetag",
        "query",
        "list",
        "help",
        "current",
        "last"
    }
    -- Return all options that start with the current argument lead
    return vim.tbl_filter(function(option)
        return vim.startswith(option, arg_lead)
    end, options)
end

function M.open_due_window(tag)
    local tasks_tb = M.query_by_tag_and_due(tag)
    local tasks_line, files = M.format_tasks(tasks_tb)
    if files == nil then
        vim.notify('No task files found')
        return
    end
    local win = dev.nvim.ui.views.scratch(tasks_line, {
        title = (tag or '') .. ' tasks',
        title_pos = 'center',
        size = {
            flex = true,
        }
    })

    win:open()
    vim.cmd("set ft=markdown")
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Normal', { win = 0, scope = "local" })
    for _, file in ipairs(files) do
        -- M.set_custom_hl(win.buf, i)
        win:set_buf_links(file)
    end
    vim.o.wrap = false
    vim.o.number = false
    vim.o.relativenumber = false
    M.highlight_tags(win.buf)
    -- local opts = vim.api.nvim_win_get_config(win.vid)

    -- Reapply the configuration to the floating window
    vim.cmd.hi('clear FloatTitle')
    -- win.buffer
end

function M.add_virtual_line(i, buf, ns_id, line, glyph, grp)
    vim.api.nvim_buf_set_lines(buf, i, -1, false, line)
    if glyph ~= nil then
        assert(#line == #glyph, 'line and glyph must have the same length')
        assert(#line == #grp, 'line and grp must have the same length')
        assert(ns_id ~= nil, 'ns_id is nil')
        -- get the number of lines in the buffer
        for j = i, i + #line - 1 do
            vim.api.nvim_buf_set_extmark(buf, ns_id, j, 0, {
                virt_text = { { glyph[j - i + 1], grp[j - i + 1] } },
                virt_text_pos = 'inline', -- Place over the existing text
            })
        end
    end
end

function M.create_buf()
    -- Create a new empty buffer

    local buf = vim.api.nvim_create_buf(false, true) -- (listed = false, scratch = true)

    -- Set buffer options if needed
    vim.api.nvim_set_option_value('bufhidden', 'wipe', { buf = buf })
    vim.api.nvim_set_option_value('filetype', 'markdown', { buf = buf }) -- Replace 'your_filetype' as needed

    return buf
end

function M.populate_buffer(buf, tasks)
    local colors = dev.color
    local ns_id = vim.api.nvim_create_namespace('dueHl')
    local grp_late = 'TaskLate'
    local grp_ontime = 'TaskOnTime'
    local grp_date = 'DateHl'
    vim.api.nvim_set_hl(0, grp_late, { fg = colors.faded_red })
    vim.api.nvim_set_hl(0, grp_ontime, { fg = colors.faded_blue })
    vim.api.nvim_set_hl(0, grp_date, { fg = colors.neutral_yellow })

    -- create timeline as virtual text
    local file_line = {}
    if tasks == nil then
        vim.notify('tasks_in is nil', vim.log.levels.ERROR)
        return
    end

    local first = true
    local last_due = ''
    local i = 0
    for _, task in pairs(tasks) do
        if task.linenr == nil then
            error('task.linenr is nil')
        end
        if last_due ~= task.due then
            if not first then
                i = i + 1
                -- M.add_virtual_line(i, buf, ns_id, {''})
                -- i = i + 1
            end
            local date_tbl = os.time({
                year = task.due:sub(1, 4),
                month = task.due:sub(6, 7),
                day = task.due:sub(9, 10),
                hour = 0,
                min = 0,
                sec = 0
            })
            local date = os.date('%A, %d de %B de %Y', date_tbl)
            date = tostring(date)
            date = string.sub(date, 1, 1):upper() .. string.sub(date, 2)

            -- get window size
            vim.api.nvim_buf_set_lines(buf, i, -1, false, { date })
            vim.api.nvim_buf_add_highlight(buf, ns_id, grp_date, i, 0, -1)
            i = i + 1
            first = false
        end

        last_due = task.due
        local tags = ''
        if tasks.tags ~= nil then
            tags = table.concat(task.tags, ' ')
        end
        local task_lines = task.description .. tags .. ' ' .. require"dev.lua.fs".basename(task.filename) .. ':' .. task.linenr

        local task_file_line = { file = task.filename, line = tonumber(task.linenr), due = task.due }
        for j = i, i + #task_lines - 1 do
            M.map_file_line[j] = task_file_line
        end
        table.insert(file_line, { file = task.filename, line = task.linenr, buf_line = i, due = task.due })
        i = i + #task_lines
    end

    -- Buffer.set_buf_links(buf,file_lines)

    for _, fline in ipairs(file_line) do
        M.map_file_line[fline.buf_line] = { file = fline.file, line = tonumber(fline.line), due = fline.due }
    end

    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
        ':lua tasks.views.open_link()<CR>',
        { noremap = true, silent = true }
    )

    return buf
end

function M.populate_buf_timeline(buf, tasks)
    local colors = dev.color
    local ns_id = vim.api.nvim_create_namespace('dueHl')
    local grp_late = 'TaskLate'
    local grp_ontime = 'TaskOnTime'
    local grp_date = 'DateHl'
    local grp_today = 'TodayHl'
    local grp_today_txt = 'TodayWordHl'

    vim.api.nvim_set_hl(0, grp_late, { fg = colors.faded_red })
    vim.api.nvim_set_hl(0, grp_ontime, { fg = colors.faded_blue })
    vim.api.nvim_set_hl(0, grp_date, { fg = colors.neutral_yellow })
    vim.api.nvim_set_hl(0, grp_today, { fg = colors.bright_orange })
    vim.api.nvim_set_hl(0, grp_today_txt, { fg = colors.bright_yellow })

    -- create timeline as virtual text
    local file_line = {}
    if tasks == nil then
        vim.notify('tasks_in is nil', vim.log.levels.ERROR)
        return
    end

    -- get today

    local first = true
    local last_due = ''
    local i = 0

    local today_tbl = os.time()
    today = os.date('%A, %d de %B de %Y', today_tbl)
    today = tostring(today)
    today = today:sub(1, 1):upper() .. today:sub(2)
    vim.api.nvim_buf_set_lines(buf, i, -1, false, { 'Today', '' })
    vim.api.nvim_buf_add_highlight(buf, ns_id, grp_today_txt, i, 0, -1)
    i = i + 2
    vim.api.nvim_buf_set_lines(buf, i, -1, false, { today, '', '' })
    vim.api.nvim_buf_add_highlight(buf, ns_id, grp_today, i, 0, -1)
    i = i + 3


    local glyphs = require('git-icons')
    local grp = grp_ontime
    for _, task in pairs(tasks) do
        if task.linenr == nil then
            -- require"katu.utils".pprint(task, 'Task (linenr is nil): ')
            error('task.linenr is nil')
        end
        if task.due ~= nil and last_due ~= task.due then
            if not first then
                M.add_virtual_line(i, buf, ns_id, { '' }, { glyphs.horizontal_bar }, { grp })
                i = i + 1
                -- M.add_virtual_line(i, buf, ns_id, {''})
                -- i = i + 1
            end
            local date_tbl = os.time({
                year = task.due:sub(1, 4),
                month = task.due:sub(6, 7),
                day = task.due:sub(9, 10),
                hour = 0,
                min = 0,
                sec = 0
            })
            local date = os.date('%A, %d de %B de %Y', date_tbl)
            date = tostring(date)
            date = date:sub(1, 1):upper() .. date:sub(2)
            local is_late = require"katu.utils".is_before(task.due)

            if is_late then
                grp = grp_late
            else
                grp = grp_ontime
            end

            -- get window size
            vim.api.nvim_buf_set_lines(buf, i, -1, false, { date })
            vim.api.nvim_buf_add_highlight(buf, ns_id, grp_date, i, 0, -1)
            i = i + 1
            first = false
        end

        if task.due ~= nil then
            last_due = task.due
        end

        local task_lines = M.split_lines(task.description)
        if task_lines == nil then
            error('task_lines is nil')
        end
        if task.tags ~= nil then
            local tags = M.split_lines(table.concat(task.tags, ' '), ' ')
            require"list".extend(task_lines, tags)
        end
        table.insert(task_lines, ' ' .. require"katu.utils.fs".basename(task.filename) .. ':' .. task.linenr)

        local glyphss = { glyphs.circle }
        for _ = 2, #task_lines do
            table.insert(glyphss, glyphs.horizontal_bar)
        end

        local groups = { grp }
        for _ = 2, #task_lines do
            table.insert(groups, grp)
        end

        local task_file_line = { file = task.filename, line = task.linenr, due = task.due }
        for j = i, i + #task_lines - 1 do
            M.map_file_line[j] = task_file_line
        end
        M.add_virtual_line(i, buf, ns_id, task_lines, glyphss, groups)
        table.insert(file_line, { file = task.filename, line = task.linenr, buf_line = i, due = task.due })
        i = i + #task_lines
    end

    -- Buffer.set_buf_links(buf,file_lines)

    for _, fline in ipairs(file_line) do
        M.map_file_line[fline.buf_line] = { file = fline.file, line = tonumber(fline.line), due = fline.due }
    end

    vim.api.nvim_buf_set_keymap(buf, 'n', '<CR>',
        ':lua tasks.views.open_link()<CR>',
        { noremap = true, silent = true }
    )

    -- lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    return buf
end

function M.split_lines(str, prefix)
    if str == nil then
        error('str is nil')
        return
    end
    if prefix == nil then
        prefix = ' '
    end
    -- divide task_str in lines
    local width = vim.api.nvim_win_get_width(0) - 4
    local n_lines = math.floor(#str / width)
    local lines = {}
    if n_lines > 1 then
        for j = 1, n_lines do
            local line = str:sub((j - 1) * width + 1, j * width)
            table.insert(lines, prefix .. require"katu.utils".trim(line))
        end
    else
        lines = { prefix .. require"katu.utils".trim(str) }
    end
    if lines[#lines] == ' ' then
        table.remove(lines, #lines)
    end
    return lines
end

function M.open_link()
    local linenr = vim.fn.line('.')
    linenr = tonumber(linenr) - 1
    local win = dev.nvim.ui.float.Window.get_win()
    if win ~= nil then
        win:close()
    elseif M.vid_r ~= nil then
        M.close_right()
    end
    if M.map_file_line[linenr] == nil then
        vim.notify('No link found for this task')
        return
    end
    vim.cmd.e(M.map_file_line[linenr].file)
    -- get current window id
    vim.cmd('normal! zR')
    local pos = { M.map_file_line[linenr].line, 0}
    vim.api.nvim_win_set_cursor(0, pos )
    if win ~= nil then
        M.vid = nil
    else
        M.vid_r = nil
    end
end

M.set_hl = function()
    vim.cmd([[match LineNr /\w[^:]*:\d\+/]])
    vim.cmd([[2match Define /#\w\+/]])
    -- vim.cmd([[match ModeMsg /\d\d\d\d-\d\d-\d\d/]])
end

M.config_win = function()
    vim.cmd('setlocal nonumber')
    vim.cmd('setlocal norelativenumber')
    vim.cmd('setlocal signcolumn=no')
end

function M.open_right(buf, _)
    dev.nvim.ui.views.open_fixed_right(buf)
    M.set_hl()
    M.config_win()
    vim.cmd('setlocal nowrap')

    -- M.highlight_tags(buf)

    vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':wincmd c<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':wincmd c<CR>', { noremap = true, silent = true })
    -- get current window id
    M.vid_r = vim.fn.win_getid()
end

function M.toggle_right(...)
    if M.vid_r ~= nil then
        M.close_right()
        M.vid_r = nil
    else
        -- open the window
        local opts = { ... }
        opts = opts[1] or {}
        opts.toggle = true
        M.search(opts)
        M.vid_r = vim.fn.win_getid()
        assert(M.vid_r ~= nil, 'M.vid_r is nil')
    end
end

function M.close_right()
    -- check if vid is defined and is a window
    if M.vid_r ~= nil and vim.api.nvim_win_is_valid(M.vid_r) then
        -- get the list of windows
        local wins = vim.api.nvim_list_wins()
        -- check if the window is the only one
        if #wins > 1 then
            -- close the window
            vim.api.nvim_win_close(M.vid_r, true)
            M.vid_r = nil
        end
    end
end

function M.open_window(buf, title)
    -- M.set_hl()
    -- M.config_win()

    -- M.highlight_tags(buf)

    M.vid = vim.fn.win_getid()
    vim.api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':wincmd c<CR>', { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', ':wincmd c<CR>', { noremap = true, silent = true })

    -- get current window id
    local win = dev.nvim.ui.views.scratch(nil, {
        title = title,
        title_pos = 'center',
        size = {
            flex = true,
        },

        options = {
            buffer = {
                modifiable = true,
            },
            window = {
                wrap = false,
                number = false,
                relativenumber = false,
                signcolumn = 'no',

            },
        },
    })

    win.buf = buf
    win:open()
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Normal', { win = 0, scope = "local" })
    -- vim.cmd("set ft=markdown")
    vim.fn.matchadd("LineNr", "| .*$")

    M.set_hl()
    M.config_win()

    -- win:set_buf_links(file_lines)
    -- M.highlight_tags(win.buf)
    vim.cmd([[2match Define /#\w\+/]])
end

-- Function to highlight the pattern
function M.highlight_tags(bufnr)
    local ns_id = vim.api.nvim_create_namespace("highlight_tags")

    -- Define the orange highlight group
    vim.api.nvim_set_hl(0, 'PatternHighlight', { fg = '#FFA500' }) -- Orange color (Hex: #FFA500)

    -- Define the pattern
    local pattern = '\\[\\w\\+:: [\\w\\d:\\-/]\\+\\]' -- Escaped Lua pattern for your desired regex
    -- Get total lines in the buffer
    local line_count = vim.api.nvim_buf_line_count(bufnr)

    -- Loop through each line and apply highlights
    for line_num = 0, line_count - 1 do
        -- Get the line content
        local line = vim.api.nvim_buf_get_lines(bufnr, line_num, line_num + 1, false)[1]

        -- Find matches using vim.fn.matchstrpos, which returns start and end of a match
        local start_pos
        local end_pos = 0
        repeat
            local res = vim.fn.matchstrpos(line, pattern, end_pos)
            start_pos = tonumber(res[2]) + 1 -- Convert to 1-based index
            end_pos = tonumber(res[3]) + 1   -- Convert to 1-based index
            if start_pos > 0 and end_pos > 0 then
                -- Highlight the match with higher priority to overlay
                -- link highlights
                vim.api.nvim_buf_add_highlight(bufnr, ns_id,
                    'PatternHighlight', line_num,
                    start_pos, end_pos)
            end
        until start_pos == 0 and end_pos == 0 -- Stop if no more matches are found
    end
end

M.init = function()
    -- tasks.indexer.index()
    M.tasks = M.load_tasks()
end

function M.open_current_tag(tag)
    tag = tag or vim.fn.expand('<cWORD>')
    tag = tag:match('(#%w+)')
    if tag == nil then
        vim.notify('No tag found')
        return
    end
    local q = require"tasks.query".Query()
    local opts = {
        tags = { tag },
        status = 'not done'
    }
    -- get windows options
    -- local opt = vim.api.nvim_win_get_config(0)
    local tasks = q:select(opts)
    M.tasks = tasks
    if tasks == nil or #tasks == 0 then
        vim.notify('No tasks found')
        return
    end

    -- create a buffer
    local buf = M.create_buf()
    M.populate_buf_timeline(buf, tasks)
    M.title = tag .. ' tasks'
    M.open_window(buf, M.title)
end

M.load_tasks = function()
    local json_file = M.path .. '/' .. M.filepath .. '/tasks.json'
    local fd = io.open(json_file, 'r')
    if fd == nil then
        print('Failed to open ' .. json_file)
        return
    end
    M.json_tasks = fd:read('*a')

    M.tasks = require"cjson".decode(M.json_tasks)
end
M.write_tasks = function(tasks, filename)
    local json_file = require"tasks.query".Query.get_path('tasks') .. '/' .. filename
    local fd = io.open(json_file, 'w')
    if fd == nil then
        print('Failed to open ' .. json_file)
        return
    end
    fd:write(require"cjson".encode(tasks))
    fd:close()
end

M.search = function(...)
    local opts = { ... }
    opts = opts[1] or {}

    local tasks

    if opts.default then
        local q = require"tasks.query".Query()
        tasks = q:select(M.default_query)
        -- require"katu.utils".pprint(tasks, 'tasks in search: ')
        -- M.write_tasks(tasks, 'tasks_from_query.json')
    elseif opts.search == 'last search' then
        if M.tasks == nil then
            local q = require"tasks.query".Query()
            tasks = q:select(M.default_query)
            M.tasks = tasks
        else
            tasks = M.tasks
        end
    elseif opts.search == 'personal' then
        local q = require"tasks.query".Query()
        tasks = q:select(M.personal_query)
        M.tasks = tasks
    elseif opts.search == 'work' then
        local q = require"tasks.query".Query()
        tasks = q:select(M.work_query)
        M.tasks = tasks
    else
        local q = require"tasks.query".Query()
        if opts.cmd == nil then
            tasks = q:select(opts)
        else
            tasks = q:select(opts.cmd)
        end
        M.tasks = tasks
    end
    M.tasks = tasks

    local title = ''
    if opts.tag then
        title = title .. ' ' .. opts.tag .. ' tasks'
    elseif opts.due then
        title = title .. ' Due tasks'
    elseif opts.status then
        title = title .. ' ' .. opts.status .. ' tasks'
    end

    if tasks == nil or #tasks == 0 then
        vim.notify('No tasks found')
        return
    end
    local buf
    M.title = title
    if opts.float then
        buf = M.create_buf()
        M.open_window(buf, M.title)
        M.populate_buffer(tasks)
    else
        buf = M.create_buf()
        M.open_right(buf, M.title)
        M.populate_buf_timeline(buf, tasks)
    end
    M.tasks = tasks
end

M.open_last_window = function()
    if M.tasks == nil then
        vim.notify('No tasks found (open_last_window)')
        return
    end
    local buf = M.create_buf()
    M.populate_buf_timeline(buf, M.tasks)
    M.open_window(buf, M.title)
end

M.command = function(args)
    local subcommand = args.fargs[1]
    if subcommand == "help" then
        vim.notify("Usage: :Tasks [current|status|due|toggle|default|last|help|log] tag1 tag2 ...")
        return
    end

    local arg = args.fargs

    local tag_pattern = '#%w+'

    local opts = {
        due = nil,
        zellij = {},
        float = nil,
        status = "not done",
        tags = {},
        args = {},
    }

    if #arg == 0 then
        M.search({ default = true })
        return
    end
    while arg ~= nil and #arg > 0 do
        if arg[1]:match(tag_pattern) then
            table.insert(opts.tags, arg[1])
            table.remove(arg, 1)
        elseif arg[1] == 'current' then
            M.open_current_tag()
            return
        elseif arg[1] == 'status' then
            arg.status = arg[2]
            table.remove(arg, 1)
            table.remove(arg, 1)
        elseif arg[1] == 'due' then
            opts.due = true
            table.remove(arg, 1)
        elseif arg[1] == 'toggle' then
            opts.toggle = true
            table.remove(arg, 1)
        elseif arg[1] == 'default' then
            opts.default = true
            table.remove(arg, 1)
        elseif arg[1] == 'last' then
            M.open_last_window()
            return
        elseif arg[1] == 'list' then
            require"tasks.query".list.select()
            return
        elseif subcommand == 'log' then
            vim.cmd('Tasklog ' .. args.args)
            return
        else
            table.insert(opts.args, arg[1])
            table.remove(arg, 1)
        end
    end

    if opts.toggle then
        M.toggle_right(opts)
    else
        M.search(opts)
    end
end
if not (vim == nil) then
    -- create_command
    if not (vim.api.nvim_create_user_command == nil) then
        vim.api.nvim_create_user_command('Tasks',
            function(args)
                M.command(args)
            end,
            { nargs = '*', complete = M.complete }
        )
    end

end
function M.open_window_by_tag(tag)
    local tasks_qf = M.query_by_tag(tag)
    float.qset(tasks_qf)
    float.qopen()
end

return M
