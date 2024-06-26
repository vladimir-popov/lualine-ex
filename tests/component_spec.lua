local u = require('tests.ex.lualine')
local uc = require('lualine.utils.color_utils')
local ex = require('lualine.ex')
local eq = assert.are.equal
local neq = assert.are.not_equal
local same = assert.are.same
local l = require('tests.ex.lualine')
local t = require('tests.ex.busted') --:ignore_all_tests()

describe('ex.component', function()
    it('should have the same methods as lualine.component', function()
        local Test = require('lualine.ex.component'):extend()
        -- check only few:
        assert(type(Test.update_status) == 'function')
        assert(type(Test.draw) == 'function')
    end)
    it('child should have the same methods as ex.component', function()
        local Test = require('lualine.ex.component'):extend()
        -- check only few:
        assert(type(Test.pre_init) == 'function')
        assert(type(Test.post_init) == 'function')
    end)
    it('child`s default options should include parent`s', function()
        -- given:
        local Test = require('lualine.ex.component'):extend({ parent_opt = true })
        -- when:
        local Child = Test:extend({ child_opt = true })
        -- then:
        local clue = vim.inspect(Child.default_options)
        assert(Child.default_options.parent_opt, clue)
        assert(Child.default_options.child_opt, clue)
    end)
    it('child`s default options should override parent`s', function()
        -- given:
        local Test = require('lualine.ex.component'):extend({ opt = false })
        -- when:
        local Child = Test:extend({ opt = true })
        -- then:
        local clue = vim.inspect(Child.default_options)
        assert(Child.default_options.opt, clue)
    end)
    it('instance of the child should have the same methods as a parent', function()
        -- given:
        local Test = require('lualine.ex.component'):extend()
        function Test:test()
            return true
        end

        local Child = Test:extend()
        -- when:
        local child = Child:new(u.opts({ icon = { align = 'right' } }))
        -- then:
        assert(type(child.test) == 'function')
    end)
end)
describe('A child of the ex.component', function()
    it('should have the passed default options as a property', function()
        -- given:
        local def_opts = { test = 'test' }
        -- when:
        local Ex = require('lualine.ex.component'):extend(def_opts)
        -- then:
        for key, orig in pairs(def_opts) do
            eq(orig, Ex.default_options[key])
        end
    end)

    it('should has a color for disabled state in the default options', function()
        -- when:
        local Ex = require('lualine.ex.component'):extend({})
        -- then:
        neq(nil, Ex.default_options.disabled_color)
    end)

    describe('on initialization', function()
        it('should merge init options with defaults', function()
            -- given:
            local Ex = require('lualine.ex.component'):extend({ icon = { '!' } })
            local init_opts = u.opts({ icon = { align = 'right' } })
            -- when:
            local icon = Ex(init_opts).options.icon
            -- then:
            same({ '!', align = 'right' }, icon)
        end)

        it('should invoke `post_init` hook with init and default options', function()
            -- given:
            local def_opts = { test = 'test' }
            local Ex = require('lualine.ex.component'):extend(def_opts)
            local init_opts = u.opts()
            local passed_opts
            function Ex:post_init()
                passed_opts = self.options
            end

            -- when:
            Ex(init_opts)
            -- then:
            for key, orig in pairs(ex.extend(init_opts, def_opts)) do
                same(orig, passed_opts[key])
            end
        end)
    end)

    describe('on draw', function()
        it('should show the icon even for the empty component in disabled state', function()
            -- given:
            local Child = require('lualine.ex.component'):extend({
                icon = '!',
                is_enabled = function()
                    return false
                end,
            })
            function Child:update_status()
                return ''
            end

            local cmp = Child(u.opts())

            -- when:
            local rendered_component = u.render_component(cmp)
            local ctbl = u.match_rendered_component(rendered_component)

            -- then:
            eq('!', ctbl.icon, 'Unexpected icon from rendered component: ' .. rendered_component)
        end)

        it('should not show the component at all if `cond` returns false', function()
            -- given:
            local Child = require('lualine.ex.component'):extend({
                icon = '!',
                cond = function()
                    return false
                end,
            })
            function Child:update_status()
                return 'some_text'
            end

            local cmp = Child(u.opts())

            -- when:
            local rendered_component = u.render_component(cmp)

            -- then:
            eq('', rendered_component)
        end)

        it('should use `disabled_color` if the component is not enabled', function()
            -- given:
            local Child = require('lualine.ex.component'):extend()
            function Child:update_status()
                return 'some_text'
            end

            function Child:is_enabled()
                return false
            end

            local cmp = Child(u.opts())

            -- when:
            local rendered_component = u.render_component(cmp)
            local ctbl = u.match_rendered_component(rendered_component)

            -- then:
            local expected_fg = uc.color_name2rgb(Child.default_options.disabled_color.fg)
            l.eq_colors(
                expected_fg,
                ctbl.color.fg,
                'Wrong color in the rendered component: ' .. rendered_component
            )
        end)

        it('should return back the hl, when component become enabled again', function()
            -- given:
            local is_enabled = true
            local Child = require('lualine.ex.component'):extend({
                color = { fg = 'green' },
            })
            function Child:update_status()
                return 'some_text'
            end

            function Child:is_enabled()
                return is_enabled
            end

            local cmp = Child(u.opts())

            -- when:
            local ctbl_before = u.match_component(cmp)
            is_enabled = false
            local ctbl_disabled = u.match_component(cmp)
            is_enabled = true
            local ctbl_after = u.match_component(cmp)

            -- then:
            eq(ctbl_before.hl, ctbl_after.hl)
        end)
    end)
end)
