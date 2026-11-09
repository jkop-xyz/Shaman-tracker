-- Loads the addon's Core/ files in .toc order into a fresh namespace, the way
-- the game does. Game/ and Init.lua are skipped: they need the real WoW API.
local TOC = "ShamanTracker/ShamanTracker.toc"

local AddonLoader = {}

function AddonLoader.load()
  local ns = {}
  for line in io.lines(TOC) do
    local file = line:match("^%s*(Core[/\\][^%s]+%.lua)%s*$")
    if file then
      local chunk = assert(loadfile("ShamanTracker/" .. file:gsub("\\", "/")))
      chunk("ShamanTracker", ns)
    end
  end
  return ns
end

return AddonLoader
