-- Reference: Comment.nvim/lua/Comment/ft.lua

-- Patterns for different languages
local P = {
    cxx_l = '//%s',
    cxx_b = '/*%s*/',
    dbl_hash = '##%s',
    dash = '--%s',
    dash_bracket = '--[[%s]]',
    handlebars = '{{!--%s--}}',
    hash = '#%s',
    hash_bracket = '#[[%s]]',
    haskell_b = '{-%s-}',
    fsharp_b = '(*%s*)',
    html = '<!--%s-->',
    latex = '%%s',
    semicolon = ';%s',
    lisp_l = ';;%s',
    lisp_b = '#|%s|#',
    twig = '{#%s#}',
    vim = '"%s',
    lean_b = '/-%s-/',
    ruby_block = '=begin%s=end',
}

-- Languages that support line/block comments
---@type table<string,string[]>
local L = {
    arduino = { P.cxx_l, P.cxx_b },
    applescript = { P.hash },
    asm = { P.hash },
    astro = { P.html },
    autohotkey = { P.semicolon, P.cxx_b },
    bash = { P.hash },
    beancount = { P.semicolon },
    bib = { P.latex },
    blueprint = { P.cxx_l }, -- Blueprint doesn't have block comments
    c = { P.cxx_l, P.cxx_b },
    cabal = { P.dash },
    cairo = { P.cxx_l },
    cmake = { P.hash, P.hash_bracket },
    conf = { P.hash },
    conkyrc = { P.dash, P.dash_bracket },
    coq = { P.fsharp_b, P.fsharp_b },
    cpp = { P.cxx_l, P.cxx_b },
    cs = { P.cxx_l, P.cxx_b },
    css = { P.cxx_b, P.cxx_b },
    cuda = { P.cxx_l, P.cxx_b },
    cue = { P.cxx_l },
    dart = { P.cxx_l, P.cxx_b },
    dhall = { P.dash, P.haskell_b },
    dnsmasq = { P.hash },
    dosbatch = { 'REM%s' },
    dot = { P.cxx_l, P.cxx_b },
    dts = { P.cxx_l, P.cxx_b },
    editorconfig = { P.hash },
    eelixir = { P.html, P.html },
    elixir = { P.hash },
    elm = { P.dash, P.haskell_b },
    elvish = { P.hash },
    faust = { P.cxx_l, P.cxx_b },
    fennel = { P.semicolon },
    fish = { P.hash },
    func = { P.lisp_l },
    fsharp = { P.cxx_l, P.fsharp_b },
    gdb = { P.hash },
    gdscript = { P.hash },
    gdshader = { P.cxx_l, P.cxx_b },
    gitignore = { P.hash },
    gleam = { P.cxx_l },
    glsl = { P.cxx_l, P.cxx_b },
    gnuplot = { P.hash, P.hash_bracket },
    go = { P.cxx_l, P.cxx_b },
    gomod = { P.cxx_l },
    graphql = { P.hash },
    groovy = { P.cxx_l, P.cxx_b },
    handlebars = { P.handlebars, P.handlebars },
    haskell = { P.dash, P.haskell_b },
    haxe = { P.cxx_l, P.cxx_b },
    hcl = { P.hash, P.cxx_b },
    heex = { P.html, P.html },
    html = { P.html, P.html },
    htmldjango = { P.html, P.html },
    hyprlang = { P.hash },
    idris = { P.dash, P.haskell_b },
    idris2 = { P.dash, P.haskell_b },
    ini = { P.hash },
    jai = { P.cxx_l, P.cxx_b },
    java = { P.cxx_l, P.cxx_b },
    javascript = { P.cxx_l, P.cxx_b },
    javascriptreact = { P.cxx_l, P.cxx_b },
    jq = { P.hash },
    jsonc = { P.cxx_l },
    jsonnet = { P.cxx_l, P.cxx_b },
    julia = { P.hash, '#=%s=#' },
    kdl = { P.cxx_l, P.cxx_b },
    kotlin = { P.cxx_l, P.cxx_b },
    lean = { P.dash, P.lean_b },
    lean3 = { P.dash, P.lean_b },
    lidris = { P.dash, P.haskell_b },
    lilypond = { P.latex, '%{%s%}' },
    lisp = { P.lisp_l, P.lisp_b },
    lua = { P.dash, P.dash_bracket },
    metalua = { P.dash, P.dash_bracket },
    luau = { P.dash, P.dash_bracket },
    markdown = { P.html, P.html },
    make = { P.hash },
    mbsyncrc = { P.dbl_hash },
    mermaid = { '%%%s' },
    meson = { P.hash },
    mojo = { P.hash },
    nextflow = { P.cxx_l, P.cxx_b },
    nim = { P.hash, '#[%s]#' },
    nix = { P.hash, P.cxx_b },
    nu = { P.hash },
    objc = { P.cxx_l, P.cxx_b },
    objcpp = { P.cxx_l, P.cxx_b },
    ocaml = { P.fsharp_b, P.fsharp_b },
    odin = { P.cxx_l, P.cxx_b },
    openscad = { P.cxx_l, P.cxx_b },
    plantuml = { "'%s", "/'%s'/" },
    purescript = { P.dash, P.haskell_b },
    puppet = { P.hash },
    python = { P.hash }, -- Python doesn't have block comments
    php = { P.cxx_l, P.cxx_b },
    prisma = { P.cxx_l },
    proto = { P.cxx_l, P.cxx_b },
    quarto = { P.html, P.html },
    r = { P.hash }, -- R doesn't have block comments
    racket = { P.lisp_l, P.lisp_b },
    rasi = { P.cxx_l, P.cxx_b },
    readline = { P.hash },
    reason = { P.cxx_l, P.cxx_b },
    rego = { P.hash },
    remind = { P.hash },
    rescript = { P.cxx_l, P.cxx_b },
    robot = { P.hash }, -- Robotframework doesn't have block comments
    ron = { P.cxx_l, P.cxx_b },
    ruby = { P.hash, P.ruby_block },
    rust = { P.cxx_l, P.cxx_b },
    sbt = { P.cxx_l, P.cxx_b },
    scala = { P.cxx_l, P.cxx_b },
    scss = { P.cxx_b, P.cxx_b },
    scheme = { P.lisp_l, P.lisp_b },
    sh = { P.hash },
    solidity = { P.cxx_l, P.cxx_b },
    supercollider = { P.cxx_l, P.cxx_b },
    sql = { P.dash, P.cxx_b },
    stata = { P.cxx_l, P.cxx_b },
    svelte = { P.html, P.html },
    swift = { P.cxx_l, P.cxx_b },
    sxhkdrc = { P.hash },
    systemverilog = { P.cxx_l, P.cxx_b },
    tablegen = { P.cxx_l, P.cxx_b },
    teal = { P.dash, P.dash_bracket },
    terraform = { P.hash, P.cxx_b },
    tex = { P.latex },
    template = { P.dbl_hash },
    tidal = { P.dash, P.haskell_b },
    tmux = { P.hash },
    toml = { P.hash },
    twig = { P.twig, P.twig },
    typescript = { P.cxx_l, P.cxx_b },
    typescriptreact = { P.cxx_l, P.cxx_b },
    typst = { P.cxx_l, P.cxx_b },
    v = { P.cxx_l, P.cxx_b },
    vala = { P.cxx_l, P.cxx_b },
    verilog = { P.cxx_l },
    vhdl = { P.dash },
    vim = { P.vim },
    vifm = { P.vim },
    vue = { P.html, P.html },
    wgsl = { P.cxx_l, P.cxx_b },
    xdefaults = { '!%s' },
    xml = { P.html, P.html },
    xonsh = { P.hash }, -- Xonsh doesn't have block comments
    yaml = { P.hash },
    yuck = { P.lisp_l },
    zig = { P.cxx_l }, -- Zig doesn't have block comments
}

local M = {}

-- 定义 line 和 block 变量
M.line = 1
M.block = 2

function M.patterns(ft)
    return L[ft]
end

function M.pattern(ft, style)
    local patterns = M.patterns(ft)
    if not patterns then
        return nil
    end
    return patterns[style]
end

function M.pattern_by_line(ft)
    return M.pattern(ft, M.line)
end

function M.pattern_by_block(ft)
    return M.pattern(ft, M.block)
end

return M
