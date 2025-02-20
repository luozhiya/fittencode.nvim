local Comment = {}

local COMMENT_DEFS = {
    -- Programming Languages --
    c = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    cpp = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    java = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    python = {
        line = '# {}',
        block = { left = '"""', right = '"""' }
    },
    lua = {
        line = '-- {}',
        block = { left = '--[[', right = ']]' }
    },
    rust = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    go = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    javascript = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    typescript = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    kotlin = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    swift = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    scala = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },

    -- Scripting Languages --
    ruby = {
        line = '# {}',
        block = { left = '=begin', right = '=end' }
    },
    perl = {
        line = '# {}',
        block = { left = '=pod', right = '=cut' }
    },
    php = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    r = {
        line = '# {}',
        block = { left = "#'", right = "#'" }
    },
    sh = {
        line = '# {}',
        block = { left = ": <<'COMMENT'", right = 'COMMENT' }
    },
    powershell = {
        line = '# {}',
        block = { left = '<#', right = '#>' }
    },

    -- Web Technologies --
    html = {
        line = '<!-- {} -->',
        block = { left = '<!--', right = '-->' }
    },
    css = {
        line = nil,
        block = { left = '/*', right = '*/' }
    },
    scss = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    less = {
        line = '// {}',
        block = { left = '/*', right = '*/', middle = ' * ' }
    },
    json = {
        line = nil,
        block = nil
    },
    yaml = {
        line = '# {}',
        block = nil
    },
    xml = {
        line = '<!-- {} -->',
        block = { left = '<!--', right = '-->' }
    },

    -- Configuration Formats --
    toml = {
        line = '# {}',
        block = nil
    },
    ini = {
        line = '; {}',
        block = nil
    },
    cfg = {
        line = '# {}',
        block = nil
    },

    -- Documentation --
    markdown = {
        line = '<!-- {} -->',
        block = { left = '<!--', right = '-->' }
    },
    tex = {
        line = '% {}',
        block = { left = '%{', right = '%}' }
    },
    latex = {
        line = '% {}',
        block = { left = '\\begin{comment}', right = '\\end{comment}' }
    },
    asciidoc = {
        line = '// {}',
        block = { left = '////', right = '////' }
    },

    -- Other Common Formats --
    dockerfile = {
        line = '# {}',
        block = nil
    },
    makefile = {
        line = '# {}',
        block = nil
    },
    sql = {
        line = '-- {}',
        block = { left = '/*', right = '*/' }
    },
    graphql = {
        line = '# {}',
        block = { left = '/*', right = '*/' }
    },
    vim = {
        line = '\" {}',
        block = { left = '\"\"', right = '\"\"', middle = '\"' }
    },
}

function Comment.line_pattern(ft)
    local def = COMMENT_DEFS[ft]
    return def and def.line
end

function Comment.block_pattern(ft)
    local def = COMMENT_DEFS[ft]
    if not def or not def.block then return nil end

    -- Return deep copy to prevent accidental modification
    return vim.deepcopy(def.block)
end

return Comment
