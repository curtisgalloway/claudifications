-- Hammerspoon init.lua

-- Claude fleet monitor: floating panel for waiting Claude CLI agents
if fleet then fleet.stop() end
package.loaded["claude-fleet"] = nil
fleet = require("claude-fleet")
fleet.start()
