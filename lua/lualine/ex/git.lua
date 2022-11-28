local fs = vim.fs
local fn = vim.fn
local uv = vim.loop

---Reads the whole file and returns its content.
local function read(file_path)
    local f = io.open(file_path, 'r')
    if not f then
        return nil
    end
    local content = f:read('*a')
    f:close()
    return content
end


---Reads {git_HEAD_path} file as git HEAD file and gets the name of the current git branch.
---@param git_HEAD_path string Path to the git file HEAD. Usually, it's the git_root/.git/HEAD.
---@return string # The name of the current branch or first 7 symbols of the commit's hash.
local function read_git_branch(git_HEAD_path)
    local head = read(git_HEAD_path)
    local branch = string.match(head, 'ref: refs/heads/(%w+)')
        or string.match(head, 'ref: refs/tags/(%w+)')
        or string.match(head, 'ref: refs/remotes/(%w+)')
    return branch or head:sub(1, #head - 7)
end

local function read_is_git_staged(git_index_path)
    local index = read(git_index_path)
    if index then error('!' .. index) end
    return index and string.find(index, 'Staged')
end

---@class GitProvider: Object
---@field new fun(root_path: string): GitProvider
--- Creates a new provider around {working_directory} or {vim.fn.getcwd}.
--- Optionaly, the name of the git directory can be passed as {git_root}, or '.git' will be used.
local GitProvider = require('lualine.utils.class'):extend()

---Looking for the path with `.git/` directory outside the {path}.
---@param path string The path to the directory or file, from which the search of
---   the `.git/` directory should begun.
---@return string # The path to the root of the git workspace, or nil.
function GitProvider.find_git_root(path)
    local function is_git_dir(path)
        local dir = path .. '/.git'
        return fn.isdirectory(dir) == 1
    end

    local git_root = is_git_dir(path) and path or nil
    if not git_root then
        for dir in fs.parents(path) do
            if is_git_dir(dir) then
                git_root = dir
                break
            end
        end
    end
    return git_root
end

---@type fun(root_path: string)
---@param root_path string Path to the root of the git working tree.
---  If absent, error will be thrown.
function GitProvider:init(root_path)
    self.__git_root = root_path
end

---Returns a path to the root git directory, or content of the '.git' directory with
---specified {subpath}.
---@param subpath? string The path to file or directory inside the '.git' directory.
---@return string # If {subpath} is ommited, the path to the {git_root} dirctory will be returned,
--- or full path to {git_root}/{git_directory}/{subpath}.
function GitProvider:git_root(subpath)
    if self.__git_root and subpath then
        return string.format('%s/%s/%s', self.__git_root, self.__git_directory, subpath)
    else
        return self.__git_root
    end
end

function GitProvider:get_branch()
    -- git branch already known
    if self.__git_branch then
        return self.__git_branch
    end

    -- git root was not found
    if not self.__git_root then
        return nil
    end

    local HEAD = self:git_root('HEAD')
    -- read current branch
    self.__git_branch = read_git_branch(HEAD)

    -- run poll of HEAD's changes
    self.__poll_head = uv.new_fs_event()
    uv.fs_event_start(self.__poll_head, HEAD, {}, function()
        self.__git_branch = read_git_branch(HEAD)
    end)

    return self.__git_branch
end

function GitProvider:is_workspace()
    return self.__git_root ~= nil
end

function GitProvider:is_workspace_changed()
    -- is_staged is already known
    if self.__staged then
        return true
    end

    -- git root was not found
    if not self.__git_root then
        return nil
    end

    local index = self:git_root('index')

    -- read is_staged
    self.__staged = read_is_git_staged(index)

    -- run poll of the index's changes
    if self.__staged then
        self.__poll_index = uv.new_fs_event()
        uv.fs_event_start(self.__poll_index, index, {}, function()
            self.__staged = read_is_git_staged(index)
        end)
    end

    return self.__staged ~= nil
end

return GitProvider
