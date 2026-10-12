-- Project tool discovery. Never activate environments globally: different LSP
-- workspaces may need different Python interpreters in the same editor session.
local M = {}

local function executable(path)
  return path and vim.fn.executable(path) == 1
end

function M.lsp_command(command)
  return function(dispatchers, config)
    return vim.lsp.rpc.start(command, dispatchers, {
      cwd = config.root_dir,
      env = config.cmd_env,
    })
  end
end

function M.python(root)
  -- An explicitly activated environment (uv run, venv, Conda) takes priority.
  for _, env in ipairs { 'VIRTUAL_ENV', 'CONDA_PREFIX' } do
    local path = vim.env[env] and vim.env[env] .. '/bin/python'
    if executable(path) then return path end
  end
  root = root or vim.fn.getcwd()
  if vim.env.UV_PROJECT_ENVIRONMENT then
    local env = vim.env.UV_PROJECT_ENVIRONMENT
    if not vim.startswith(env, '/') then
      local project = vim.fs.root(root, 'uv.lock') or vim.fs.root(root, 'pyproject.toml') or root
      env = vim.fs.joinpath(project, env)
    end
    if executable(env .. '/bin/python') then return env .. '/bin/python' end
  end
  -- Search ancestors too: uv workspace members share the workspace's .venv.
  local dir = root
  while dir do
    local path = dir .. '/.venv/bin/python'
    if executable(path) then return path end
    if vim.uv.fs_stat(dir .. '/.git') then break end
    local parent = vim.fs.dirname(dir)
    if parent == dir then break end
    dir = parent
  end
  return vim.fn.exepath('python3')
end

function M.pyright(_, config)
  config.settings = config.settings or {}
  config.settings.python = config.settings.python or {}
  if not config.settings.python.pythonPath then
    config.settings.python.pythonPath = M.python(config.root_dir)
  end
end

function M.ruff(_, ctx)
  local python = M.python(ctx.dirname)
  local path = vim.fs.dirname(python) .. '/ruff'
  return executable(path) and path or 'ruff'
end

function M.gofmt(_, ctx)
  -- `go env` honors GOTOOLCHAIN and go.mod/go.work, unlike a plain gofmt on PATH.
  local result = vim.system({ 'go', 'env', 'GOROOT' }, { cwd = ctx.dirname, text = true }):wait(10000)
  if result.code ~= 0 then
    error('Cannot resolve project Go toolchain: ' .. (result.stderr or 'go env GOROOT failed'))
  end
  local path = vim.trim(result.stdout) .. '/bin/gofmt'
  assert(executable(path), 'Selected Go toolchain has no gofmt: ' .. path)
  return path
end

function M.rust_settings(config)
  -- Only use the bundled sources when the bundled rustc is actually selected.
  -- With rustup, rust-analyzer discovers the selected toolchain's rust-src.
  local info = require('nix-info').info
  local rustc = vim.fn.exepath(vim.env.RUSTC or 'rustc')
  if not vim.env.RUST_SRC_PATH
    and vim.uv.fs_realpath(rustc) == vim.uv.fs_realpath(info.fallback_rustc)
  then
    config.settings = config.settings or {}
    local settings = config.settings['rust-analyzer'] or {}
    settings.cargo = settings.cargo or {}
    if settings.cargo.sysrootSrc == nil then settings.cargo.sysrootSrc = info.fallback_rust_src end
    config.settings['rust-analyzer'] = settings
  end
end

return M
