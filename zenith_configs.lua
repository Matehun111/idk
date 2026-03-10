-- ======================================================================
--  Z E N I T H  |  Config Storage System  v1.0
--  Load this script alongside zenith_loader_*.lua
--  It adds a "Configs" page to the Zenith menu with full save/load.
--  Configs are stored locally in gamesense database.
--  Cloud configs fetched from GitHub JSON.
-- ======================================================================

local CLOUD_URL = 'https://raw.githubusercontent.com/Matehun111/idk/main/zenith_presets.json'
local DB_KEY    = 'zenith_cfgs_v3'

-- ── Wait for main Zenith lua to finish loading ─────────────────────────
local function wait_for_zenith(cb, attempts)
    attempts = attempts or 0
    if attempts > 40 then return end -- give up after 20s
    if not rawget(_G, 'menu') or not rawget(_G, '_auth_ok') then
        client.delay_call(0.5, function() wait_for_zenith(cb, attempts+1) end)
        return
    end
    cb()
end

wait_for_zenith(function()

-- ── State ──────────────────────────────────────────────────────────────
local live    = {}   -- array of {name,author,data,updated,source='local'|'cloud'}
local cur_sel = 1

-- ── menu items ─────────────────────────────────────────────────────────
local m_list   = menu.new_item(ui.new_listbox,  'AA','Anti-aimbot angles','Config List',{'--'})
local m_name   = menu.new_item(ui.new_textbox,  'AA','Anti-aimbot angles','Config Name')
local m_load   = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Load',         function() end)
local m_loadaa = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles',"Load Anti-Aim's", function() end)
local m_save   = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Save',         function() end)
local m_create = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Create New',   function() end)
local m_delete = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Delete',       function() end)
local m_status = menu.new_item(ui.new_label,    'AA','Anti-aimbot angles',' ')

-- Hide all initially
local _all = {m_list,m_name,m_load,m_loadaa,m_save,m_create,m_delete,m_status}
for _,it in ipairs(_all) do pcall(ui.set_visible, it.ref, false) end

-- Add Configs to Zenith pages
local _sel = rawget(_G,'gui') and gui.selection
if _sel and _sel.ref then
    local ok, items = pcall(ui.get_items, _sel.ref)
    if ok and items and not table.concat(items,','):find('Configs') then
        items[#items+1] = 'Configs'
        pcall(ui.set_items, _sel.ref, items)
    end
end

-- ── Helpers ────────────────────────────────────────────────────────────
local function set_status(s)
    pcall(ui.set, m_status.ref, tostring(s))
end

local function strip(s)
    return (s or ''):match('^%s*(.-)%s*$')
end

local function db_read()
    local ok,v = pcall(database.read, DB_KEY)
    if ok and type(v)=='string' then
        local ok2,t = pcall(json.parse, v)
        if ok2 and type(t)=='table' then return t end
    end
    return {}
end

local function db_write(t)
    pcall(database.write, DB_KEY, json.stringify(t))
end

local function save_locals()
    local t = {}
    for _,cfg in ipairs(live) do
        if cfg.source == 'local' then t[#t+1] = cfg end
    end
    db_write(t)
end

local function refresh_list()
    local names = {}
    for i,cfg in ipairs(live) do
        local pfx = cfg.source=='cloud' and '\a77ccffff[Cloud] \affffffff' or '\a71bc78ff[Local] \affffffff'
        names[i] = pfx..cfg.name
    end
    if #names == 0 then names = {'No configs.'} end
    pcall(ui.set_items, m_list.ref, names)
    cur_sel = math.max(1, math.min(cur_sel, #live))
    pcall(ui.set, m_list.ref, cur_sel-1)
    local sel = live[cur_sel]
    if sel then pcall(ui.set, m_name.ref, sel.name) end
end

local function export_data()
    local out = {}
    local items = menu.get_items and menu.get_items() or {}
    for _,item in ipairs(items) do
        if item.is_recorded and item.record_key then
            out[item.record_key] = item.value
        end
    end
    local ok, result = pcall(json.stringify, out)
    return ok and result or '{}'
end

local function apply_data(data_str, aa_only)
    local ok,data = pcall(json.parse, data_str or '{}')
    if not ok or type(data)~='table' then return false end
    local items = menu.get_items and menu.get_items() or {}
    for _,item in ipairs(items) do
        if item.is_recorded and item.record_key then
            local v = data[item.record_key]
            if v ~= nil then
                if aa_only then
                    local k = item.record_key
                    if k:find('^aa') or k:find('^angles') or k:find('^defensive') then
                        pcall(function() item:set(v) end)
                    end
                else
                    pcall(function() item:set(v) end)
                end
            end
        end
    end
    return true
end

-- ── Load configs ───────────────────────────────────────────────────────
local function reload()
    live = {}
    for _,cfg in ipairs(db_read()) do
        cfg.source = 'local'
        live[#live+1] = cfg
    end
    refresh_list()
    set_status('Fetching cloud configs...')
    pcall(function()
        http.get(CLOUD_URL, function(ok, res)
            local body = type(res)=='table' and res.body or res
            if ok and body and #body > 2 then
                local ok2,arr = pcall(json.parse, body)
                if ok2 and type(arr)=='table' then
                    for _,cfg in ipairs(arr) do
                        local dup = false
                        for _,lc in ipairs(live) do
                            if lc.name==cfg.name and lc.source=='local' then dup=true; break end
                        end
                        if not dup then
                            cfg.source = 'cloud'
                            live[#live+1] = cfg
                        end
                    end
                    refresh_list()
                    set_status(string.format('Ready. %d config(s).', #live))
                    return
                end
            end
            set_status(string.format('Ready. %d local config(s).', #live))
        end)
    end)
end

-- ── Callbacks ──────────────────────────────────────────────────────────
m_list:set_callback(function()
    cur_sel = (ui.get(m_list.ref) or 0) + 1
    local sel = live[cur_sel]
    if sel then pcall(ui.set, m_name.ref, sel.name) end
end)

m_load:set_callback(function()
    local sel = live[cur_sel]
    if not sel then set_status('Nothing selected.'); return end
    if apply_data(sel.data, false) then
        set_status('Loaded: '..sel.name)
    else
        set_status('Load failed.')
    end
end)

m_loadaa:set_callback(function()
    local sel = live[cur_sel]
    if not sel then set_status('Nothing selected.'); return end
    if apply_data(sel.data, true) then
        set_status("Loaded AA's: "..sel.name)
    else
        set_status('Load failed.')
    end
end)

m_save:set_callback(function()
    local sel = live[cur_sel]
    if not sel then set_status('Nothing selected.'); return end
    if sel.source == 'cloud' then set_status('Cannot overwrite cloud config.'); return end
    local ok_e, data = pcall(export_data)
    if not ok_e then set_status('Export failed.'); return end
    sel.data = data
    save_locals()
    set_status('Saved: '..sel.name)
end)

m_create:set_callback(function()
    local ok_n, name = pcall(ui.get, m_name.ref)
    name = strip(ok_n and name or '')
    if name == '' then set_status('Enter a name first.'); return end
    local ok_e, data = pcall(export_data)
    local cfg = {
        name    = name,
        author  = rawget(_G,'USERNAME') or 'user',
        data    = ok_e and data or '{}',
        updated = tostring(math.floor(globals.realtime() or 0)),
        source  = 'local',
    }
    live[#live+1] = cfg
    cur_sel = #live
    save_locals()
    refresh_list()
    set_status('Created: '..name)
end)

m_delete:set_callback(function()
    local sel = live[cur_sel]
    if not sel then set_status('Nothing selected.'); return end
    if sel.source == 'cloud' then set_status('Cannot delete cloud config.'); return end
    local name = sel.name
    table.remove(live, cur_sel)
    cur_sel = math.max(1, cur_sel-1)
    save_locals()
    refresh_list()
    set_status('Deleted: '..name)
end)

-- ── Hook into Zenith menu callback ─────────────────────────────────────
rawset(_G, '__configs_show', function()
    for _,it in ipairs(_all) do
        pcall(ui.set_visible, it.ref, true)
        rawget(_G,'_safe_display') and _safe_display(it)
    end
end)

-- Hook the existing menu.set_callback to also call __configs_show on Configs page
local _orig_menu_cb = menu.set_callback
menu.set_callback(function()
    local sel = rawget(_G,'gui') and gui.selection
    if not sel then return end
    local ok, page = pcall(ui.get, sel.ref)
    if ok and page == 'Configs' then
        __configs_show()
    else
        -- hide config items when not on configs page
        for _,it in ipairs(_all) do
            pcall(ui.set_visible, it.ref, false)
        end
    end
end)

-- ── Init ───────────────────────────────────────────────────────────────
client.delay_call(1, reload)

end) -- wait_for_zenith

