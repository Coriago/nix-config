-- Noctalia owns the stream; disabling/reloading the plugin stops the Rust process.
local function quote(value)
  return "'" .. string.gsub(value, "'", "'\\''") .. "'"
end

local runtime = noctalia.getenv("XDG_RUNTIME_DIR")
local appearanceFile = runtime and (runtime .. "/corne-overlay-appearance.json")
local lastAppearance = nil
local fontFamily = nil
local fontFile = nil
local started = false

local function publishAppearance()
  if not appearanceFile then return end
  local output = noctalia.getConfig("monitor") or "focused"
  if output == "focused" then output = noctalia.focusedOutputName() or "" end
  local palette = {}
  for _, role in ipairs({"surface", "on_surface", "surface_variant", "on_surface_variant", "primary", "on_primary", "outline"}) do
    palette[role] = noctalia.getColor(role)
  end
  local appearance = {
    position = noctalia.getConfig("position"),
    output = output,
    margin = noctalia.getConfig("margin"),
    preview = tonumber(noctalia.getConfig("preview")),
    radius = math.clamp((noctalia.getSetting("shell.corner_radius_scale") or 1) * 12, 0, 24),
    palette = palette,
    font_file = fontFile,
  }
  local encoded = noctalia.json.encode(appearance)
  if encoded and encoded ~= lastAppearance then
    -- Atomic replacement keeps the reader from seeing a partially written palette.
    if noctalia.writeFile(appearanceFile .. ".tmp", encoded)
        and noctalia.renameFile(appearanceFile .. ".tmp", appearanceFile) then
      lastAppearance = encoded
    end
  end
end

local function updateFont()
  local family = noctalia.getSetting("shell.font_family") or "sans-serif"
  if family == fontFamily then return end
  fontFamily = family
  noctalia.runAsync({"@fontconfig@/bin/fc-match", "-f", "%{file}", family}, function(result)
    if result.exitCode == 0 and result.stdout ~= "" and family == fontFamily then
      fontFile = result.stdout
      publishAppearance()
    end
  end)
end

function update()
  updateFont()
  publishAppearance()
  if started or not appearanceFile or not lastAppearance then return end
  local layout = noctalia.getConfig("layout_file")
  if not layout or layout == "" then return end
  layout = noctalia.expandPath(layout)
  if not noctalia.fileExists(layout) then return end
  started = noctalia.runStream("exec " .. quote("@out@/bin/corne-overlay") .. " " .. quote(layout)
    .. " --appearance " .. quote(appearanceFile), function(line)
      noctalia.log(line)
    end)
end

-- Settings changes restart this service, replacing the managed stream with current settings.
noctalia.setUpdateInterval(500)
update()
