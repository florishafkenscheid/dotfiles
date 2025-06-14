return {
  'saghen/blink.cmp',
  version = '1.*',
  build = 'cargo build --release',
  opts = {
    keymap = {
        preset = 'default',

        -- Navigation
        ['<Up>'] = { 'select_prev', 'fallback' },
        ['<Down>'] = { 'select_next', 'fallback' },

        -- Functionality
        ['<D-space>'] = { 'show', 'show_documentation', 'hide_documentation' },
        ['<D-e>'] = { 'hide' },
        ['<return>'] = { 'select_and_accept', 'fallback' },

        ['<C-b>'] = { 'scroll_documentation_up', 'fallback' },
        ['<C-f>'] = { 'scroll_documentation_down', 'fallback' },
    },
  },
  opts_extend = { "sources.default" }
}
