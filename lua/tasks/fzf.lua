local M = {}


-- Function to format the tasks into a string
M.format = require"tasks.format".tostring
function M.format_task2(task)
    -- Create the file:line format
    local task_line = string.format("%s:%d: - [ ] %s", task.file, task.line, task.description)

    -- Add tags
    if #task.tags > 0 then
        task_line = task_line .. " " .. table.concat(task.tags, " ")
    end

    -- Add parameters (metatags)
    if next(task.parameters) ~= nil then
        for key, value in pairs(task.parameters) do
            task_line = task_line .. string.format(" [%s:: %s]", key, value)
        end
    end

    return task_line
end
-- -- QUERIES
-- SELECT t.id
-- FROM task t
-- JOIN parameters p ON t.id = p.task_id
-- JOIN tags tg ON t.id = tg.task_id
-- WHERE tg.tag = '#research'  -- Filter by the tag
--   AND p.key = 'due_date'    -- Ensure the task has a 'due_date' key
-- ORDER BY p.value ASC;       -- Sort by 'due_date'

-- Function to feed tasks to fzf-lua grep-like search with markdown syntax highlighting
function M.search_tasks(task_list, f_sink)
    if not task_list or #task_list == 0 then
        vim.notify("No tasks found.")
        return
    end

    local format
    if type(task_list[1]) == 'string' then
        format = function(task) return task end
    else
        format = M.format_task
    end
    -- Prepare the list of tasks in a grep-like format
    local task_lines = {}
    for _, task in ipairs(task_list) do
        table.insert(task_lines, format(task))
    end
    if f_sink == nil then
        f_sink = function(selected)
            print("Selected tasks:" .. selected)
        end
    end

    local fzf = require('fzf-lua')
    fzf.run({
        source = task_lines,
        sink = f_sink,
        options = {
            prompt = 'Search Tasks> ',
            preview = 'markdown',
        },
    })
end

-- Example TaskList format
M.TaskList = {
    {
        id = 1,
        filename = "/path/to/file1.md",
        line_number = 10,
        description = "Complete the report",
        parameters = { priority = "high", due = "tomorrow" },
        tags = { "#work", "#report" },
    },
    {
        id = 2,
        filename = "/path/to/file2.md",
        line_number = 15,
        description = "Fix the bug in module",
        parameters = { priority = "urgent" },
        tags = { "#bugfix", "#urgent" },
    }
}

M.format = require"tasks.format".tostring
-- Function to format tasks for display
function M.format_task3(task)
    local task_line = string.format("%s:%d: %s", task.filename, task.line_number, task.description)

    -- Add tags and parameters to the task description
    if #task.tags > 0 then
        task_line = task_line .. " " .. table.concat(task.tags, " ")
    end

    if next(task.parameters) ~= nil then
        for key, value in pairs(task.parameters) do
            task_line = task_line .. string.format(" [%s:: %s]", key, value)
        end
    end

    return task_line
end

-- Function to prompt for refining the search
function M.prompt_refine_search(selected_tasks)
    -- Prompt the user with a confirmation
    local answer = vim.fn.input("Refine search on selected tasks? (y/n): ")
    if answer:lower() == 'y' then
        -- Perform the refined search on the selected tasks
        refined_search(selected_tasks)
    else
        print("Search completed.")
    end
end

-- Function to perform the initial search
function M.initial_search()
    -- Prepare the task lines
    local task_lines = {}
    for _, task in pairs(M.TaskList) do
        table.insert(task_lines, M.format_task(task))
    end

    local fzf = require('fzf-lua')
    -- Perform the fzf search
    fzf.fzf_exec(task_lines, {
        prompt = 'Search Tasks> ',
        multi = true,  -- Allow multiple selections
        actions = {
            -- On selecting tasks, ask if the user wants to refine the search
            ["default"] = function(selected)
                -- Capture the selected tasks
                local selected_tasks = {}
                for _, task_line in ipairs(selected) do
                    -- Extract file and line information (and other data)
                    table.insert(selected_tasks, task_line)
                end

                -- Prompt for refining the search on the selected tasks
                M.prompt_refine_search(selected_tasks)
            end
        }
    })
end

-- Function to perform a refined search on selected tasks
function M.refined_search(selected_tasks)
    local fzf = require('fzf-lua')
    -- Perform another fzf search on the selected tasks
    fzf.fzf_exec(selected_tasks, {
        prompt = 'Refined Search> ',
        multi = true,  -- Allow further multiple selections if needed
        actions = {
            -- Handle refined selection or other actions
            ["default"] = function(final_selection)
                for _, task_line in ipairs(final_selection) do
                    print("Final selected task:", task_line)
                end
            end
        }
    })
end

-- Example usage: Start the initial search
-- initial_search()

return M
