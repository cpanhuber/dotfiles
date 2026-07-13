-- Formatting, replaces vim-autoformat. Unlike before (format everything
-- on every write), only filetypes listed here are formatted on save.
-- The taplo entry also replaces the old Cargo.toml lint autocmd.
return {
    'stevearc/conform.nvim',
    event = 'BufWritePre',
    cmd = 'ConformInfo',
    keys = {
        {
            '<leader>.q',
            function() require('conform').format({ async = true, lsp_format = 'fallback' }) end,
            desc = 'Format buffer',
        },
    },
    opts = {
        formatters_by_ft = {
            c = { 'clang_format' },
            cpp = { 'clang_format' },
            javascript = { 'prettier' },
            lua = { 'stylua' },
            python = { 'ruff_format' },
            rust = { 'rustfmt' },
            sh = { 'shfmt' },
            toml = { 'taplo' },
            typescript = { 'prettier' },
        },
        format_on_save = { timeout_ms = 1000, lsp_format = 'never' },
    },
}
