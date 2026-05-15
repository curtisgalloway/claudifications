-- Claude Fleet Monitor
-- Notification-style panel (top-right) listing Claude CLI sessions waiting for input.

local M = {}

local STATUS_DIR = os.getenv("HOME") .. "/.claude/fleet-status"
local PANEL_W    = 340
local ITEM_H     = 54
local HEADER_H   = 34
local STALE_HOURS = 8

local wv      = nil
local watcher = nil

-- ── helpers ──────────────────────────────────────────────────────────────────

local function extractUUID(itermId)
    -- ITERM_SESSION_ID format: "w12t0p0:UUID" or "w12t0p0:UUID:depth"
    return itermId:match(":([^:]+):") or itermId:match(":(.+)$") or itermId
end

local function parseISO8601(ts)
    if not ts then return 0 end
    local y,mo,d,h,mi,s = ts:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)")
    if not y then return 0 end
    return os.time({year=y,month=mo,day=d,hour=h,min=mi,sec=s})
end

local HOME = os.getenv("HOME")

local function getWaitingSessions()
    local items  = {}
    local now    = os.time()
    local cutoff = now - STALE_HOURS * 3600

    local handle = io.popen('ls "' .. STATUS_DIR .. '" 2>/dev/null')
    if not handle then return items end
    local files = handle:read("*all")
    handle:close()

    for filename in files:gmatch("[^\n]+") do
        if filename:match("%.json$") then
            local path = STATUS_DIR .. "/" .. filename
            local f = io.open(path, "r")
            if f then
                local content = f:read("*all")
                f:close()
                local ok, data = pcall(hs.json.decode, content)
                if ok and data and data.state == "waiting" then
                    local ts = parseISO8601(data.timestamp)
                    if ts >= cutoff then
                        local sid = data.session_id or ""
                        local ago = math.floor((now - ts) / 60)
                        table.insert(items, {
                            project    = data.project or "unknown",
                            cwd        = (data.cwd or ""):gsub(HOME, "~"),
                            iterm_id   = data.iterm_session_id or "",
                            session_id = sid,
                            ago        = ago < 1 and "just now"
                                        or ago == 1 and "1 min ago"
                                        or ago .. " min ago",
                        })
                    else
                        os.remove(path)
                    end
                end
            end
        end
    end
    return items
end

-- ── HTML ─────────────────────────────────────────────────────────────────────

local function buildHTML(items)
    local rows = ""
    for _, it in ipairs(items) do
        rows = rows .. string.format([[
<div class="item">
  <div class="dot"></div>
  <div class="info" onclick="jump('%s','%s')">
    <div class="name">%s</div>
    <div class="meta">%s &bull; %s</div>
  </div>
  <button class="dismiss" onclick="dismiss('%s')" title="Dismiss">✕</button>
</div>]], it.iterm_id, it.session_id, it.project, it.cwd, it.ago, it.session_id)
    end

    return string.format([[<!DOCTYPE html><html><head><meta charset="UTF-8">
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{width:100%%;height:100%%;overflow:hidden}
body{
  font-family:-apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;
  background:rgba(44,44,48,0.97);
  color:#e8e8e8;
  border-radius:12px;
  -webkit-user-select:none;
}
.header{
  display:flex;align-items:center;justify-content:space-between;
  font-size:11px;font-weight:600;color:#888;
  text-transform:uppercase;letter-spacing:.7px;
  padding:10px 14px 8px;
  border-bottom:1px solid rgba(255,255,255,0.08);
}
.close-all{
  background:none;border:none;color:#666;font-size:13px;
  cursor:pointer;padding:0 2px;line-height:1;
}
.close-all:hover{color:#ccc}
.item{
  display:flex;align-items:center;gap:10px;
  padding:10px 14px;
  border-bottom:1px solid rgba(255,255,255,0.06);
}
.item:last-child{border-bottom:none}
.item:hover{background:rgba(255,255,255,0.07)}
.dot{
  width:8px;height:8px;border-radius:50%%;
  background:#f59e0b;flex-shrink:0;
}
.info{min-width:0;flex:1;cursor:pointer}
.info:hover .name{text-decoration:underline;text-underline-offset:2px}
.name{font-size:13px;font-weight:500;color:#fff}
.meta{font-size:11px;color:#888;margin-top:2px;
  white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.dismiss{
  background:none;border:none;color:#555;font-size:12px;
  cursor:pointer;padding:2px 4px;border-radius:4px;flex-shrink:0;line-height:1;
}
.dismiss:hover{color:#ccc;background:rgba(255,255,255,0.1)}
</style></head><body>
<div class="header">
  <span>Claude Agents</span>
  <button class="close-all" onclick="closeAll()" title="Close panel">✕</button>
</div>
%s
<script>
function jump(iid,sid){window.webkit.messageHandlers.fleet.postMessage('jump|'+sid+'|'+iid)}
function dismiss(sid){window.webkit.messageHandlers.fleet.postMessage('dismiss|'+sid+'|')}
function closeAll(){window.webkit.messageHandlers.fleet.postMessage('closeAll||')}
</script>
</body></html>]], rows)
end

-- ── panel ─────────────────────────────────────────────────────────────────────

local function panelFrame(count)
    local sf = hs.screen.mainScreen():frame()
    local h  = HEADER_H + count * ITEM_H
    return {x = sf.x + sf.w - PANEL_W - 10, y = sf.y + 10, w = PANEL_W, h = h}
end

local function showPanel(items)
    if not wv then return end
    wv:frame(panelFrame(#items))
    wv:html(buildHTML(items))
    if not wv:isVisible() then wv:show() end
end

local function hidePanel()
    if wv and wv:isVisible() then wv:hide() end
end

local function updatePanel()
    if not wv then return end
    local items = getWaitingSessions()

    if #items == 0 then
        hidePanel()
        return
    end

    if wv:isVisible() then
        wv:frame(panelFrame(#items))
        wv:html(buildHTML(items))
    else
        hs.sound.getByName("Bubble"):play()
        showPanel(items)
    end
end

-- ── public ───────────────────────────────────────────────────────────────────

function M.show()
    local items = getWaitingSessions()
    if #items > 0 then showPanel(items) else hidePanel() end
end

function M.start()
    local function markDismissed(sid)
        if not sid or sid == "" then return end
        local path = STATUS_DIR .. "/" .. sid .. ".json"
        local f = io.open(path, "r")
        if not f then return end
        local content = f:read("*all")
        f:close()
        local ok, data = pcall(hs.json.decode, content)
        if ok and data then
            data.state = "dismissed"
            local nf = io.open(path, "w")
            if nf then
                nf:write(hs.json.encode(data))
                nf:close()
            end
        end
    end

    local usercontent = hs.webview.usercontent.new("fleet")
    usercontent:setCallback(function(msg)
        local action, sid, iid = msg.body:match("^([^|]*)|([^|]*)|(.*)$")

        if action == "closeAll" then
            local items = getWaitingSessions()
            for _, it in ipairs(items) do markDismissed(it.session_id) end
            hidePanel()
            return
        end

        if action == "dismiss" then
            markDismissed(sid)
            updatePanel()
            return
        end

        if action == "jump" then
            markDismissed(sid)
            updatePanel()
            if iid and iid ~= "" then
                local uuid = extractUUID(iid)
                local script = string.format([[
                    tell application "iTerm2"
                        activate
                        repeat with aWindow in windows
                            repeat with aTab in tabs of aWindow
                                repeat with aSession in sessions of aTab
                                    if unique id of aSession is "%s" then
                                        select aWindow
                                        tell aTab to select
                                        tell aSession to select
                                        return
                                    end if
                                end repeat
                            end repeat
                        end repeat
                    end tell
                ]], uuid)
                hs.osascript.applescript(script)
            else
                hs.application.open("iTerm2")
            end
        end
    end)

    local sf = hs.screen.mainScreen():frame()
    wv = hs.webview.new(
        {x = sf.x + sf.w - PANEL_W - 10, y = sf.y + 10, w = PANEL_W, h = 100},
        usercontent
    )
    wv:windowStyle({"utility", "nonactivating", "closable"})
    wv:level(hs.drawing.windowLevels.floating)
    wv:allowNavigationGestures(false)
    wv:transparent(true)
    wv:windowTitle("Claude Agents")

    hs.execute('mkdir -p "' .. STATUS_DIR .. '"')

    watcher = hs.pathwatcher.new(STATUS_DIR, function()
        hs.timer.doAfter(0.4, updatePanel)
    end)
    watcher:start()

    hs.hotkey.bind({"cmd","shift"}, "`", M.show)
    hs.timer.doAfter(1.0, updatePanel)
end

return M
