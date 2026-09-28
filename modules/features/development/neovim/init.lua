-- Adapted from https://github.com/nvim-lua/kickstart.nvim (MIT; see LICENSE).
-- Keep Kickstart's readable configuration, but let Nix supply all plugins,
-- language servers, formatters, and compiled Treesitter parsers.
-- Edit this file and rerun `nix run .#myneovim` to use the updated configuration.

-- Options --------------------------------------------------------------------
vim.loader.enable()
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = false

vim.opt.number = true
vim.opt.mouse = 'a'
vim.opt.showmode = false
vim.opt.breakindent = true
vim.opt.undofile = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.signcolumn = 'yes'
vim.opt.updatetime = 250
vim.opt.timeoutlen = 300
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.opt.inccommand = 'split'
vim.opt.cursorline = true
vim.opt.scrolloff = 10
vim.opt.confirm = true
vim.opt.termguicolors = true
vim.schedule(function() vim.opt.clipboard = 'unnamedplus' end)

-- Basic keymaps --------------------------------------------------------------
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')
vim.keymap.set('n', '<leader>q', vim.diagnostic.setloclist, { desc = 'Open diagnostic [Q]uickfix list' })
vim.keymap.set('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
for key, direction in pairs { h = 'left', j = 'lower', k = 'upper', l = 'right' } do
  vim.keymap.set('n', '<C-' .. key .. '>', '<C-w><C-' .. key .. '>', { desc = 'Move focus to the ' .. direction .. ' window' })
end
vim.api.nvim_create_autocmd('TextYankPost', {
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

vim.diagnostic.config {
  severity_sort = true,
  float = { border = 'rounded', source = 'if_many' },
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  virtual_text = true,
}

-- UI and editing -------------------------------------------------------------
require('guess-indent').setup {}
require('gitsigns').setup {
  signs = {
    add = { text = '+' },
    change = { text = '~' },
    delete = { text = '_' },
    topdelete = { text = '‾' },
    changedelete = { text = '~' },
  },
  on_attach = function(buf)
    local gs = require 'gitsigns'
    local function map(key, action, desc)
      vim.keymap.set('n', key, action, { buffer = buf, desc = desc })
    end
    map(']c', function() gs.nav_hunk 'next' end, 'Next Git change')
    map('[c', function() gs.nav_hunk 'prev' end, 'Previous Git change')
    map('<leader>hs', gs.stage_hunk, 'Git [S]tage hunk')
    map('<leader>hr', gs.reset_hunk, 'Git [R]eset hunk')
    map('<leader>hp', gs.preview_hunk, 'Git [P]review hunk')
    map('<leader>hb', gs.blame_line, 'Git [B]lame line')
  end,
}
require('which-key').setup {
  delay = 0,
  icons = { mappings = false },
  spec = {
    { '<leader>s', group = '[S]earch' },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>h', group = 'Git [H]unk' },
    { 'gr', group = 'LSP actions' },
  },
}
require('tokyonight').setup { styles = { comments = { italic = false } } }
vim.cmd.colorscheme 'tokyonight-night'
require('todo-comments').setup { signs = false }
require('mini.ai').setup { n_lines = 500, mappings = { around_next = 'aa', inside_next = 'ii' } }
require('mini.surround').setup()
local statusline = require 'mini.statusline'
statusline.setup { use_icons = false }
statusline.section_location = function() return '%2l:%-2v' end

-- Search ---------------------------------------------------------------------
require('telescope').setup {
  defaults = { preview = { treesitter = false } },
  extensions = { ['ui-select'] = { require('telescope.themes').get_dropdown() } },
}
require('telescope').load_extension 'fzf'
require('telescope').load_extension 'ui-select'
local builtin = require 'telescope.builtin'
for key, item in pairs {
  sh = { builtin.help_tags, '[S]earch [H]elp' },
  sk = { builtin.keymaps, '[S]earch [K]eymaps' },
  sf = { builtin.find_files, '[S]earch [F]iles' },
  ss = { builtin.builtin, '[S]earch [S]elect Telescope' },
  sw = { builtin.grep_string, '[S]earch current [W]ord' },
  sg = { builtin.live_grep, '[S]earch by [G]rep' },
  sd = { builtin.diagnostics, '[S]earch [D]iagnostics' },
  sr = { builtin.resume, '[S]earch [R]esume' },
  ['s.'] = { builtin.oldfiles, '[S]earch recent files' },
  ['<leader>'] = { builtin.buffers, 'Find existing buffers' },
} do
  vim.keymap.set('n', '<leader>' .. key, item[1], { desc = item[2] })
end
vim.keymap.set('n', '<leader>/', function()
  builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown { winblend = 10, previewer = false })
end, { desc = '[/] Fuzzily search current buffer' })

-- Completion and snippets ----------------------------------------------------
require('luasnip').setup {}
require('luasnip.loaders.from_vscode').lazy_load()
require('blink.cmp').setup {
  keymap = { preset = 'default' }, -- C-space: open; C-n/C-p: select; C-y: accept.
  completion = { documentation = { auto_show = true, auto_show_delay_ms = 500 } },
  sources = { default = { 'lsp', 'path', 'snippets', 'buffer' } },
  snippets = { preset = 'luasnip' },
  fuzzy = { implementation = 'lua' }, -- Never download a fuzzy-matcher binary.
  signature = { enabled = true },
}

-- Language servers -----------------------------------------------------------
require('fidget').setup {}
vim.api.nvim_create_autocmd('LspAttach', {
  group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
  callback = function(event)
    local function map(keys, action, desc, mode)
      vim.keymap.set(mode or 'n', keys, action, { buffer = event.buf, desc = 'LSP: ' .. desc })
    end
    map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
    map('gra', vim.lsp.buf.code_action, 'Code [A]ction', { 'n', 'x' })
    map('grd', builtin.lsp_definitions, '[D]efinition')
    map('gd', builtin.lsp_definitions, 'Definition')
    map('grr', builtin.lsp_references, '[R]eferences')
    map('gri', builtin.lsp_implementations, '[I]mplementation')
    map('grt', builtin.lsp_type_definitions, '[T]ype definition')
    map('gO', builtin.lsp_document_symbols, 'Document symbols')
    map('gW', builtin.lsp_dynamic_workspace_symbols, 'Workspace symbols')
    map('K', vim.lsp.buf.hover, 'Hover documentation')
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client:supports_method('textDocument/inlayHint') then
      map('<leader>th', function()
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }, { bufnr = event.buf })
      end, '[T]oggle inlay [H]ints')
    end
  end,
})

local project_tools = require 'project-tools'
local rust_before_init = vim.lsp.config.rust_analyzer.before_init
local rust_root_dir = vim.lsp.config.rust_analyzer.root_dir
local servers = {
  nixd = { settings = { nixd = { formatting = { command = { 'alejandra' } } } } },
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = 'LuaJIT' },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        diagnostics = { globals = { 'vim' } },
        completion = { callSnippet = 'Replace' },
        telemetry = { enable = false },
      },
    },
  },
  pyright = { before_init = project_tools.pyright },
  gopls = { cmd = project_tools.lsp_command { 'gopls' } },
  rust_analyzer = {
    cmd = project_tools.lsp_command { 'rust-analyzer' },
    root_dir = function(buf, on_dir)
      local crate = vim.fs.root(buf, 'Cargo.toml')
      if not crate then return rust_root_dir(buf, on_dir) end
      -- Run metadata inside the crate so rustup sees its rust-toolchain.toml,
      -- even when the editor was launched from a different directory.
      vim.system({ 'cargo', 'metadata', '--no-deps', '--format-version', '1' },
        { cwd = crate, text = true }, function(result)
          vim.schedule(function()
            if result.code ~= 0 then
              vim.notify('Cargo metadata failed: ' .. (result.stderr or ''), vim.log.levels.ERROR)
              return
            end
            on_dir(vim.json.decode(result.stdout).workspace_root or crate)
          end)
        end)
    end,
    before_init = function(params, config)
      project_tools.rust_settings(config)
      rust_before_init(params, config)
    end,
  },
  ts_ls = {},
}
for name, config in pairs(servers) do
  config.capabilities = require('blink.cmp').get_lsp_capabilities(config.capabilities)
  vim.lsp.config(name, config)
  vim.lsp.enable(name)
end

-- Formatting: explicit, so opening someone else's project won't reformat it. --
require('conform').setup {
  default_format_opts = { lsp_format = 'fallback' },
  formatters = {
    ruff_format = { command = project_tools.ruff },
    gofmt = { command = project_tools.gofmt },
    -- rustup chooses a toolchain by working directory, not the input filename.
    rustfmt = { cwd = function(_, ctx) return ctx.dirname end },
  },
  formatters_by_ft = {
    nix = { 'alejandra' },
    lua = { 'stylua' },
    python = { 'ruff_format' },
    go = { 'gofmt' },
    rust = { 'rustfmt' },
    javascript = { 'prettierd' },
    javascriptreact = { 'prettierd' },
    typescript = { 'prettierd' },
    typescriptreact = { 'prettierd' },
    json = { 'prettierd' },
    yaml = { 'prettierd' },
    markdown = { 'prettierd' },
  },
}
vim.keymap.set({ 'n', 'v' }, '<leader>f', function()
  require('conform').format { async = true }
end, { desc = '[F]ormat buffer' })

-- Treesitter uses only Nix-built parsers, with no runtime downloads. -----------
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('kickstart-treesitter', { clear = true }),
  callback = function(event)
    local language = vim.treesitter.language.get_lang(vim.bo[event.buf].filetype)
    if not language then return end
    -- A successful pcall only means no exception was raised. Missing parsers
    -- can return nil, including for UI filetypes such as TelescopePrompt.
    local ok, loaded = pcall(vim.treesitter.language.add, language)
    if ok and loaded then
      vim.treesitter.start(event.buf, language)
    end
  end,
})
