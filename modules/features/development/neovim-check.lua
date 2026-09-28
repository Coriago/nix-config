-- Run by checks.myneovim in a sandbox with a fresh HOME and no network.
local function check()
  assert(vim.v.errmsg == '', vim.v.errmsg)
  assert(vim.env.NVIM_APPNAME == 'myneovim')
  assert(vim.g.mapleader == ' ')
  assert(vim.g.colors_name == 'tokyonight-night')
  assert(vim.fn.maparg('<leader>sf', 'n') ~= '')
  assert(require('blink.cmp').get_lsp_capabilities().textDocument.completion)
  assert(require('telescope').extensions.fzf)
  assert(require('telescope').extensions['ui-select'])
  -- UI and unsupported filetypes must not try to start a missing parser.
  for _, filetype in ipairs { 'TelescopePrompt', 'TelescopeResults', 'text', 'myneovim_unknown' } do
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_set_current_buf(buf)
    vim.bo[buf].filetype = filetype
    assert(vim.v.errmsg == '', filetype .. ': ' .. vim.v.errmsg)
    assert(not vim.treesitter.highlighter.active[buf], filetype .. ': unexpected highlighter')
    vim.api.nvim_buf_delete(buf, { force = true })
  end
  for _, executable in ipairs {
    'nixd', 'lua-language-server', 'pyright-langserver', 'gopls', 'rust-analyzer',
    'typescript-language-server', 'alejandra', 'stylua', 'ruff', 'gofmt', 'rustfmt',
    'prettierd', 'rg', 'fd', 'git',
  } do
    assert(vim.fn.executable(executable) == 1, executable .. ': missing executable')
  end

  local fixtures = {
    { server = 'nixd', file = 'default.nix', text = '{answer=42;}', parser = 'nix' },
    { server = 'lua_ls', file = 'init.lua', text = 'local answer = 42', parser = 'lua', marker = '.luarc.json', config = '{}' },
    { server = 'pyright', file = 'main.py', text = 'answer = 42', parser = 'python', marker = 'pyrightconfig.json', config = '{}' },
    { server = 'gopls', file = 'main.go', text = 'package main\nfunc main() {}', parser = 'go', marker = 'go.mod', config = 'module example.com/smoke\n\ngo 1.24' },
    { server = 'rust_analyzer', file = 'src/main.rs', text = 'fn main() {}', parser = 'rust', marker = 'Cargo.toml', config = '[package]\nname = "smoke"\nversion = "0.1.0"\nedition = "2021"' },
    { server = 'ts_ls', file = 'main.ts', text = 'const answer: number = 42;', parser = 'typescript', marker = 'tsconfig.json', config = '{}' },
  }

  for _, fixture in ipairs(fixtures) do
    local root = vim.env.HOME .. '/projects/' .. fixture.server
    vim.fn.mkdir(root .. '/src', 'p')
    vim.fn.mkdir(root .. '/.git', 'p')
    local function write(path, text)
      vim.fn.writefile(vim.split(text, '\n', { plain = true }), root .. '/' .. path)
    end
    if fixture.marker then write(fixture.marker, fixture.config) end
    write(fixture.file, fixture.text)
    vim.cmd.cd(vim.fn.fnameescape(root))
    vim.cmd.edit(vim.fn.fnameescape(root .. '/' .. fixture.file))
    local buf = vim.api.nvim_get_current_buf()
    assert(vim.treesitter.get_parser(buf, fixture.parser):parse(), fixture.parser .. ': parser failed')
    assert(vim.wait(30000, function()
      local clients = vim.lsp.get_clients { bufnr = buf, name = fixture.server }
      return #clients > 0 and clients[1].initialized
    end, 100), fixture.server .. ': did not attach; see ' .. vim.lsp.log.get_filename())
    assert(vim.fn.maparg('grn', 'n') ~= '', 'LspAttach mappings missing')
    print(fixture.server .. ': attached, parser loaded')
    for _, client in ipairs(vim.lsp.get_clients { bufnr = buf }) do
      client:stop(true)
    end
    vim.cmd.bdelete()
  end

  -- Exercise a real external formatter, rather than only checking PATH.
  vim.cmd.enew()
  vim.bo.filetype = 'nix'
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { '{answer=42;}' })
  local format_error
  require('conform').format({ async = false, timeout_ms = 10000, lsp_format = 'never' }, function(err)
    format_error = err
  end)
  assert(not format_error, tostring(format_error))
  local formatted = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), '\n')
  assert(formatted:find('answer = 42;', 1, true), 'Alejandra did not format: ' .. formatted)
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('myneovim: startup, completion, Telescope, six LSPs, parsers, and formatting passed')
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  vim.cmd 'cquit 1'
else
  vim.cmd 'qa!'
end
