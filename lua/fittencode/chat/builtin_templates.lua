local builtin_templates = {
    chat = {
        'chat-en.rdt.md',
        'chat-zh-cn.rdt.md'
    },
    task = {
        'diagnose-errors-en.rdt.md',
        'diagnose-errors-zh-cn.rdt.md',
        'diagnose-errors.rdt.md',
        'document-code-en.rdt.md',
        'document-code-zh-cn.rdt.md',
        'edit-code-en.rdt.md',
        'edit-code-zh-cn.rdt.md',
        'explain-code-en.rdt.md',
        'explain-code-w-context.rdt.md',
        'explain-code-zh-cn.rdt.md',
        'find-bugs-en.rdt.md',
        'find-bugs-zh-cn.rdt.md',
        'generate-code-en.rdt.md',
        'generate-code-zh-cn.rdt.md',
        'generate-unit-test-en.rdt.md',
        'generate-unit-test-zh-cn.rdt.md',
        'improve-readability.rdt.md',
        'optimize-code-en.rdt.md',
        'optimize-code-zh-cn.rdt.md',
        'terminal-fix-en.rdt.md',
        'terminal-fix-zh-cn.rdt.md',
        'title-chat-en.rdt.md',
        'title-chat-zh-cn.rdt.md',
    }
}

local TEMPLATE_CATEGORIES = {
    CHAT = 'chat',
    DOCUMENT_CODE = 'document-code',
    EDIT_CODE = 'edit-code',
    EXPLAIN_CODE = 'explain-code',
    FIND_BUGS = 'find-bugs',
    GENERATE_UNIT_TEST = 'generate-unit-test',
    OPTIMIZE_CODE = 'optimize-code'
}

return {
    builtin_templates = builtin_templates,
    TEMPLATE_CATEGORIES = TEMPLATE_CATEGORIES
}
