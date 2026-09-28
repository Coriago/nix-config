-- Real uv/rustup projects and an inherited Go toolchain, all offline.
local function check()
  local tools = require 'project-tools'
  local home = vim.env.HOME
  local function write(path, contents)
    vim.fn.mkdir(vim.fs.dirname(path), 'p')
    vim.fn.writefile(vim.split(contents, '\n', { plain = true }), path)
  end
  local function run(cmd, cwd)
    local result = vim.system(cmd, { cwd = cwd, text = true }):wait(30000)
    assert(result.code == 0, table.concat(cmd, ' ') .. ': ' .. (result.stderr or ''))
    return vim.trim(result.stdout or '')
  end
  local function attach(file, name)
    vim.cmd.edit(vim.fn.fnameescape(file))
    local buf = vim.api.nvim_get_current_buf()
    local client
    assert(vim.wait(30000, function()
      client = vim.lsp.get_clients({ bufnr = buf, name = name })[1]
      return client and client.initialized
    end, 100), name .. ': failed to attach')
    return client, buf
  end

  assert(vim.fn.exepath('python3') == home .. '/project-bin/python3', 'wrapper overrode inherited PATH')
  assert(not vim.env.RUST_SRC_PATH, 'wrapper forced bundled Rust sources')

  -- uv creates the project interpreter. The editor should find it unactivated.
  local python_root = home .. '/uv-project'
  write(python_root .. '/pyproject.toml', '[project]\nname = "editor-test"\nversion = "0.1.0"\nrequires-python = ">=3.12,<3.13"\ndependencies = []')
  run({ vim.env.TEST_UV, 'sync', '--python', vim.env.TEST_PYTHON, '--no-install-project' }, python_root)
  local python = python_root .. '/.venv/bin/python'
  assert(tools.python(python_root) == python, 'uv .venv not selected')
  assert(run({ python, '-c', 'import sys; print(sys.version_info.minor)' }) == '12')
  local site = run({ python, '-c', 'import sysconfig; print(sysconfig.get_path("purelib"))' })
  write(site .. '/editor_test_dependency.py', 'answer: int = 42')
  write(python_root .. '/main.py', 'from editor_test_dependency import answer\nprint(answer)')
  local pyright, buf = attach(python_root .. '/main.py', 'pyright')
  assert(pyright.config.settings.python.pythonPath == python, 'Pyright got the wrong interpreter')
  -- A definition inside site-packages proves Pyright sees this venv's packages.
  local definition
  assert(vim.wait(15000, function()
    local response = pyright:request_sync('textDocument/definition', {
      textDocument = { uri = vim.uri_from_bufnr(buf) }, position = { line = 0, character = 38 },
    }, 1000, buf)
    definition = response and response.result and response.result[1]
    return definition ~= nil
  end, 200), 'Pyright could not resolve the venv dependency')
  assert(vim.uri_to_fname(definition.uri or definition.targetUri):find(site, 1, true), 'definition outside project venv')
  pyright:stop(true)

  -- Workspace members find the parent .venv, and a local Ruff beats fallback.
  vim.fn.mkdir(python_root .. '/packages/member', 'p')
  assert(tools.python(python_root .. '/packages/member') == python)
  vim.uv.fs_symlink(vim.fn.exepath('ruff'), python_root .. '/.venv/bin/ruff')
  assert(tools.ruff(nil, { dirname = python_root }) == python_root .. '/.venv/bin/ruff')
  vim.env.VIRTUAL_ENV = home .. '/explicit-env'
  vim.fn.mkdir(vim.env.VIRTUAL_ENV .. '/bin', 'p')
  vim.uv.fs_symlink(vim.env.TEST_PYTHON, vim.env.VIRTUAL_ENV .. '/bin/python')
  assert(tools.python(python_root) == vim.env.VIRTUAL_ENV .. '/bin/python', 'active environment not honored')
  vim.env.VIRTUAL_ENV = nil
  print('Python: uv interpreter, installed-package resolution, workspace discovery, active override, and local Ruff passed')

  -- Register a local toolchain with real rustup, without downloading anything.
  run({ vim.env.TEST_RUSTUP, 'toolchain', 'link', 'editor-test', vim.env.TEST_RUST_TOOLCHAIN })
  local rust_root = home .. '/rust-project'
  write(rust_root .. '/rust-toolchain.toml', '[toolchain]\nchannel = "editor-test"')
  write(rust_root .. '/Cargo.toml', '[package]\nname = "editor_test"\nversion = "0.1.0"\nedition = "2021"')
  write(rust_root .. '/src/main.rs', 'fn main() {}')
  local shims = home .. '/rustup-bin'
  vim.fn.mkdir(shims, 'p')
  for _, name in ipairs { 'rustc', 'cargo', 'rustfmt', 'rust-analyzer' } do
    vim.uv.fs_symlink(vim.env.TEST_RUSTUP, shims .. '/' .. name)
  end
  vim.env.PATH = shims .. ':' .. vim.env.PATH
  assert(run({ vim.env.TEST_RUSTUP, 'show', 'active-toolchain' }, rust_root):find('editor-test', 1, true))
  -- Deliberately keep the editor outside the project to test metadata's cwd.
  vim.cmd.cd(vim.fn.fnameescape(home))
  local rust = attach(rust_root .. '/src/main.rs', 'rust_analyzer')
  assert(not vim.tbl_get(rust.config.settings, 'rust-analyzer', 'cargo', 'sysrootSrc'), 'bundled Rust sources leaked into rustup project')
  local rustfmt = require('conform').get_formatter_config('rustfmt', 0)
  assert(rustfmt.cwd(nil, { dirname = rust_root .. '/src' }) == rust_root .. '/src')
  local formatted = vim.system({ 'rustfmt', '--emit=stdout', '--edition=2021' }, {
    cwd = rust_root, stdin = 'fn main(){}', text = true,
  }):wait(10000)
  assert(formatted.code == 0 and formatted.stdout:find('fn main() {}', 1, true), formatted.stderr)
  rust:stop(true)
  print('Rust: rustup project selection, LSP attachment from outside the project, and rustfmt passed')

  -- Record the go selected by gopls and gofmt. Delegate to a real Go binary.
  local go_root = home .. '/go-project'
  write(go_root .. '/go.mod', 'module example.com/editor-test\n\ngo 1.24')
  write(go_root .. '/main.go', 'package main\nfunc main() {}')
  local go_bin = home .. '/go-bin'
  local log = home .. '/go-invocations'
  write(go_bin .. '/go', '#!' .. vim.env.TEST_SHELL .. '\nprintf "%s|%s\\n" "$PWD" "$*" >> "' .. log .. '"\nexec "' .. vim.env.TEST_GO .. '" "$@"')
  vim.uv.fs_chmod(go_bin .. '/go', 493)
  vim.env.PATH = go_bin .. ':' .. vim.env.PATH
  local gopls = attach(go_root .. '/main.go', 'gopls')
  assert(vim.wait(15000, function()
    return vim.uv.fs_stat(log) ~= nil
  end, 100), 'gopls did not use inherited Go')
  local goroot = run({ 'go', 'env', 'GOROOT' }, go_root)
  assert(tools.gofmt(nil, { dirname = go_root }) == goroot .. '/bin/gofmt')
  gopls:stop(true)
  assert(vim.v.errmsg == '', vim.v.errmsg)
  print('Go: inherited toolchain used by gopls; gofmt selected from project GOROOT')
end

local ok, err = xpcall(check, debug.traceback)
if not ok then
  io.stderr:write(err .. '\n')
  local log = vim.lsp.log.get_filename()
  if vim.fn.filereadable(log) == 1 then
    io.stderr:write(table.concat(vim.fn.readfile(log), '\n') .. '\n')
  end
  vim.cmd 'cquit 1'
else
  vim.cmd 'qa!'
end
