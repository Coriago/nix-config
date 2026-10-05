-- Adapted from https://github.com/nvim-lua/kickstart.nvim (MIT; see LICENSE).init
-- Keep Kickstart's readable configuration, but let Nix supply all plugins,
-- language servers, formatters, and compiled Treesitter parsers.
-- Edit this file and rerun `nix run .#myneovim` to use the updated configuration.

-- Options --------------------------------------------------------------------
vim.loader.enable()
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true
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
vim.keymap.set('n', '<leader>wv', '<cmd>vsplit<CR>', { desc = 'Split window [V]ertically' })
vim.keymap.set('n', '<leader>ws', '<cmd>split<CR>', { desc = '[S]plit window horizontally' })
vim.keymap.set('n', '<leader>wc', '<cmd>close<CR>', { desc = '[C]lose window' })
vim.keymap.set('n', '<leader>w=', '<C-w>=', { desc = 'Equalize window sizes' })
vim.keymap.set('n', '<leader>wt', function()
  vim.cmd 'botright 12new'
  vim.cmd 'terminal'
  vim.cmd 'startinsert'
end, { desc = 'New [T]erminal below' })
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
require('mini.icons').setup()
-- Share mini.icons with plugins that use the nvim-web-devicons API.
require('mini.icons').mock_nvim_web_devicons()
require('snacks').setup {
  input = { enabled = true },
  lazygit = { config = { gui = { nerdFontsVersion = '3' } } },
}
require('oil').setup {
  columns = { 'icon' },
  win_options = { signcolumn = 'yes:2' }, -- Git index on the left, working tree on the right.
  view_options = { show_hidden = true },
  keymaps = {
    -- Keep Ctrl-h/l consistent with editor window navigation.
    ['<C-h>'] = false,
    ['<C-l>'] = false,
    ['<C-s>'] = false,
    ['gs'] = { 'actions.select', opts = { horizontal = true } },
    ['gv'] = { 'actions.select', opts = { vertical = true } },
    ['gR'] = 'actions.refresh',
  },
}
require('oil-git-status').setup {}
vim.api.nvim_create_autocmd('User', {
  pattern = 'OilEnter',
  group = vim.api.nvim_create_augroup('oil-auto-preview', { clear = true }),
  callback = function(event)
    -- OilEnter fires after the directory entries are ready.
    if vim.api.nvim_get_current_buf() == event.data.buf then
      require('oil').open_preview()
    end
  end,
})
vim.keymap.set('n', '-', '<cmd>Oil<CR>', { desc = 'Explore current file directory' })
vim.keymap.set('n', '<leader>e', function() require('oil').open(vim.fn.getcwd()) end,
  { desc = '[E]xplore working directory' })
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
    map('<leader>hd', gs.diffthis, 'Git [D]iff current file')
    map('<leader>tb', gs.toggle_current_line_blame, '[T]oggle Git [B]lame')
  end,
}
require('which-key').setup {
  delay = 0,
  icons = { mappings = true },
  spec = {
    { '<leader>s', group = '[S]earch' },
    { '<leader>t', group = '[T]oggle' },
    { '<leader>h', group = 'Git [H]unk' },
    { '<leader>w', group = '[W]indows and terminal' },
    { '<leader>g', group = '[G]it' },
    { '<leader>a', group = '[A]I' },
    { 'gr', group = 'LSP actions' },
  },
}
require('tokyonight').setup { styles = { comments = { italic = false } } }
vim.cmd.colorscheme 'tokyonight-night'
require('todo-comments').setup { signs = false }
require('mini.ai').setup { n_lines = 500, mappings = { around_next = 'aa', inside_next = 'ii' } }
require('mini.surround').setup()
local statusline = require 'mini.statusline'
statusline.setup { use_icons = true }
statusline.section_location = function() return '%2l:%-2v' end

-- Git UI: Snacks embeds the real Lazygit executable and returns edits here.
vim.keymap.set('n', '<leader>gg', function()
  require('snacks').lazygit { cwd = vim.fn.getcwd() }
end, { desc = 'Open Lazy[G]it (working directory)' })
vim.keymap.set('n', '<leader>gf', function() require('snacks').lazygit.log_file() end,
  { desc = 'Git history of current [F]ile' })

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
  sf = { function() builtin.find_files { hidden = true } end, '[S]earch [F]iles' },
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
local editor_info = require('nix-info').info
-- Chat-based local suggestions, separate from Blink's fast LSP completions.
-- Start manually: this Ollama server serializes requests with other clients.
require('minuet').setup {
  provider = 'openai_compatible',
  n_completions = 1,
  context_window = 2048, -- Characters around the cursor, not tokens.
  request_timeout = 10,
  throttle = 1500,
  debounce = 600,
  provider_options = {
    openai_compatible = {
      name = 'Local Qwen',
      end_point = editor_info.ai_completion_endpoint,
      model = editor_info.ai_completion_model,
      api_key = function() return 'ollama' end, -- Required by client; ignored by Ollama.
      -- Minuet's default few-shot prompt demonstrates multiple alternatives;
      -- Qwen3 8B repeated that pattern even with n_completions = 1.
      few_shots = function() return {} end,
      system = {
        template = 'You are an inline code completion engine. Fill the gap at <cursorPosition> between '
          .. '<contextBeforeCursor> and <contextAfterCursor>. Return exactly one short continuation, '
          .. 'only the missing code. Do not repeat surrounding code. Do not list alternatives, explain, '
          .. 'or use markdown fences. Preserve indentation. Stop as soon as the immediate statement '
          .. 'or small block is complete.',
      },
      optional = { max_tokens = 128, temperature = 0.2, reasoning_effort = 'none' },
    },
  },
  virtualtext = {
    auto_trigger_ft = {},
    keymap = {
      accept_line = '<A-a>',
      next = '<A-]>',
      prev = '<A-[>',
      dismiss = '<A-e>',
    },
  },
}
vim.keymap.set('i', '<A-y>', function()
  require('blink.cmp').hide()
  require('minuet.virtualtext').action.next()
end, { desc = 'Request local AI suggestion' })
vim.keymap.set('n', '<leader>ac', '<cmd>Minuet virtualtext toggle<CR>',
  { desc = 'Toggle automatic AI [C]ompletion (buffer)' })
require('luasnip').setup {}
require('luasnip.loaders.from_vscode').lazy_load()
require('blink.cmp').setup {
  keymap = {
    preset = 'default', -- C-space: open; C-n/C-p: select.
    ['<C-y>'] = {
      function(cmp)
        -- Prefer the completion menu; otherwise accept visible AI ghost text.
        local ai = require('minuet.virtualtext').action
        if not cmp.is_visible() and ai.is_visible() then
          ai.accept_line()
          return true
        end
      end,
      'accept',
      'fallback',
    },
  },
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
  if vim.fn.has('linux') == 1 then
    -- Off by default on Linux; Nix supplies inotifywait for the built-in backend.
    -- Lets servers register watches for project files, including unopened ones.
    config.capabilities = vim.tbl_deep_extend('force', config.capabilities, {
      workspace = { didChangeWatchedFiles = { dynamicRegistration = true } },
    })
  end
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
