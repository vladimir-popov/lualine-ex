local M = {}

---@type fun(x: any): boolean
---Checks is an argument {x} is empty.
---
---@return boolean #true when the argument is empty.
---The argument is empty when:
---* it is the nil;
---* it has a type 'table' and doesn't have any pair;
---* it has a type 'string' and doesn't have any char;
---otherwise result is false.
M.is_empty = function(x)
    if x == nil then
        return true
    end
    if type(x) == 'table' and next(x) == nil then
        return true
    end
    if type(x) == 'string' and string.len(x) < 1 then
        return true
    end
    return false
end

---@type fun(t1: table, t2: table): table
---The same as `vim.tbl_extend('keep', t1 or {}, t2 or {})`,
M.extend = function(t1, t2)
    return vim.tbl_extend('keep', t1 or {}, t2 or {})
end

---@type fun(dest: table, source: table): table
--- Puts all absent key-value pairs from the {source} to the {dest}.
---@param dest table a table to which data should be added.
---@param source table a table from which a data should be copied.
---@return table dest with added pairs.
M.merge = function(dest, source, already_visited)
    vim.validate({ dest = { dest, 'table' }, source = { source, 'table' } })
    for key, value in pairs(dest) do
        if type(value) == 'table' and type(source[key]) == 'table' then
            already_visited = already_visited or {}
            if not already_visited[value] then
                already_visited[value] = true
                M.merge(value, source[key], already_visited)
            end
        end
    end
    for key, value in pairs(source) do
        if dest[key] == nil then
            dest[key] = value
        end
    end
    return dest
end

---Resolves a {max_length} option of a component.
--- - if {ln} is a function, it invokes that function with the {value} parameter;
--- - if {ln} is number > 0 and < 1, and {laststatus} == 3 then this function
---   calculates a fraction of the {vim.o.columns};
--- - if {ln} is number > 0 and < 1, and {laststatus} ~= 3 then this function
---   calculates a fraction of the {vim.api.nvim_win_get_width(0)};
--- - all other numbers will be returned as is;
--- - in case of all other types the nil will be returned.
---
---@param ln number|fun(value: string) an initial setting for the max_length.
---@param str? string an actual component value which will be passed to the {lng}
---              if it's a function.
---@return integer | nil
M.max_length = function(ln, str)
    ln = (type(ln) == 'function') and ln(str) or ln
    if type(ln) ~= 'number' then
        return nil
    end
    if ln > 0 and ln < 1 then
        return math.floor(
            ln * (vim.o.laststatus == 3 and vim.o.columns or vim.api.nvim_win_get_width(0))
        )
    else
        return ln
    end
end

---Implementation of the {fmt} function to crop the component to the {max_length}.
---@param str string
---@param cmp LualineComponent
---@return string
M.crop = function(str, cmp)
    local crop_opts = cmp.options.crop or {}
    local max_length = M.max_length(cmp.options.max_length, str)
    local stub = crop_opts.stub or '…'
    local str_length = vim.fn.strdisplaywidth(str)
    if max_length == nil or str_length < max_length then
        return str
    end
    local side = crop_opts.side
    if side == nil or (side ~= 'left' and side ~= 'right') then
        side = (cmp.options.self.section < 'x') and 'left' or 'right'
    end
    local crop_length = max_length - vim.fn.strdisplaywidth(stub)
    if side == 'right' then
        str = vim.fn.strcharpart(str, 0, crop_length) .. stub
    elseif side == 'left' then
        str = stub .. vim.fn.strcharpart(str, str_length - crop_length, crop_length)
    end
    return str
end

return M
