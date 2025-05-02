-- workspace
M = {
    name = '',
    folder = '',
    file = 'tasks.json',
    dbpath = '.tasks'
}

function M.set_folder(self,folder)
    self.folder = folder
end

function M.get_folder(self)
        return self.folder
end

function M.get_filename(self)
    return table.concat({self.folder, self.dbpath, self.file}, '/')
end
require'class'
M = class(M, {constructor = function(self, name, folder)
    self.folder = folder
    self.name = name
    return self
end})

return M

