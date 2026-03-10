-- ======================================================================
--  Z E N I T H  |  Cloud Config System  v2.0
--  Load alongside zenith_loader_*.lua
--
--  HOW IT WORKS:
--  - Every user's saved configs are stored in gamesense shared database
--  - On load, fetches ALL configs from all users automatically
--  - Your configs appear for everyone, everyone's configs appear for you
--  - No discord, no asking around - configs sync automatically
-- ======================================================================

local DB_MY_CONFIGS  = 'zenith_my_configs_v2'       -- your local saves
local DB_ALL_CONFIGS = 'zenith_shared_configs_v2'    -- shared pool (all users)

-- Wait for Zenith main lua to be ready
local function init()
    if not rawget(_G,'menu') or not rawget(_G,'_auth_ok') or not rawget(_G,'gui') then
        client.delay_call(0.5, init)
        return
    end
    start_config_system()
end

function start_config_system()

-- ── State ──────────────────────────────────────────────────────────────
local live    = {}
local cur_sel = 1

-- ── Menu items ─────────────────────────────────────────────────────────
local m_list   = menu.new_item(ui.new_listbox,  'AA','Anti-aimbot angles','Config List',    {'--'})
local m_name   = menu.new_item(ui.new_textbox,  'AA','Anti-aimbot angles','Config Name')
local m_author = menu.new_item(ui.new_label,    'AA','Anti-aimbot angles',' ')
local m_load   = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Load',            function()end)
local m_loadaa = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles',"Load Anti-Aim's", function()end)
local m_save   = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Save My Config',  function()end)
local m_create = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Upload New',      function()end)
local m_delete = menu.new_item(ui.new_button,   'AA','Anti-aimbot angles','Delete Mine',     function()end)
local m_status = menu.new_item(ui.new_label,    'AA','Anti-aimbot angles',' ')

local _all_items = {m_list,m_name,m_author,m_load,m_loadaa,m_save,m_create,m_delete,m_status}

-- Hide all initially
for _,it in ipairs(_all_items) do pcall(ui.set_visible, it.ref, false) end

-- Add Configs page to Zenith dropdown
pcall(function()
    local ref = gui.selection.ref
    local items = ui.get_items(ref)
    for _,v in ipairs(items) do
        if v == 'Configs' then return end
    end
    items[#items+1] = 'Configs'
    ui.set_items(ref, items)
end)

-- ── Helpers ────────────────────────────────────────────────────────────
local function set_status(s)
    pcall(ui.set, m_status.ref, '\ac8c8c8ff'..tostring(s))
end

local function strip(s)
    return (s or ''):match('^%s*(.-)%s*$')
end

local function export_data()
    local out = {}
    for _,item in ipairs(menu.get_items()) do
        if item.is_recorded and item.record_key then
            out[item.record_key] = item.value
        end
    end
    local ok,r = pcall(json.stringify, out)
    return ok and r or '{}'
end

local function apply_data(data_str, aa_only)
    local ok,data = pcall(json.parse, data_str or '{}')
    if not ok or type(data) ~= 'table' then return false end
    for _,item in ipairs(menu.get_items()) do
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

local function refresh_list()
    if #live == 0 then
        pcall(ui.set_items, m_list.ref, {'No configs yet.'})
        pcall(ui.set, m_author.ref, ' ')
        return
    end
    local names = {}
    local me = rawget(_G,'USERNAME') or 'user'
    for i,cfg in ipairs(live) do
        local mine = (cfg.author == me)
        local col  = mine and '\a71bc78ff' or '\a77ccffff'
        local tag  = mine and '[Mine] ' or '[Cloud] '
        names[i] = col..tag..'\affffffff'..cfg.name
    end
    pcall(ui.set_items, m_list.ref, names)
    cur_sel = math.max(1, math.min(cur_sel, #live))
    pcall(ui.set, m_list.ref, cur_sel - 1)
    local sel = live[cur_sel]
    if sel then
        pcall(ui.set, m_name.ref, sel.name)
        pcall(ui.set, m_author.ref, '\ac8c8c8ffby \aff9955ff'..(sel.author or '?'))
    end
end

-- ── Shared DB helpers ──────────────────────────────────────────────────
local function shared_read()
    local ok,v = pcall(database.read, DB_ALL_CONFIGS)
    if ok and type(v)=='string' then
        local ok2,t = pcall(json.parse, v)
        if ok2 and type(t)=='table' then return t end
    end
    return {}
end

local function shared_write(t)
    pcall(database.write, DB_ALL_CONFIGS, json.stringify(t))
end

local function my_read()
    local ok,v = pcall(database.read, DB_MY_CONFIGS)
    if ok and type(v)=='string' then
        local ok2,t = pcall(json.parse, v)
        if ok2 and type(t)=='table' then return t end
    end
    return {}
end

local function my_write(t)
    pcall(database.write, DB_MY_CONFIGS, json.stringify(t))
end

-- ── Load all configs ───────────────────────────────────────────────────
local function reload()
    live = {}
    local me = rawget(_G,'USERNAME') or 'user'

    -- 1. Load shared pool (all users' uploaded configs)
    for _,cfg in ipairs(shared_read()) do
        live[#live+1] = cfg
    end

    -- 2. Merge in your local saves (update existing or add new)
    for _,mine in ipairs(my_read()) do
        local found = false
        for i,cfg in ipairs(live) do
            if cfg.name == mine.name and cfg.author == me then
                live[i] = mine; found = true; break
            end
        end
        if not found then
            table.insert(live, 1, mine)
        end
    end

    refresh_list()
    set_status(string.format('%d config(s) loaded.', #live))
end

-- ── Publish config to shared pool ─────────────────────────────────────
local function publish(cfg)
    local pool = shared_read()
    local me   = rawget(_G,'USERNAME') or 'user'
    local found = false
    for i,p in ipairs(pool) do
        if p.name == cfg.name and p.author == me then
            pool[i] = cfg; found = true; break
        end
    end
    if not found then table.insert(pool, 1, cfg) end
    shared_write(pool)
end

-- ── Callbacks ──────────────────────────────────────────────────────────
m_list:set_callback(function()
    local ok,v = pcall(ui.get, m_list.ref)
    cur_sel = (ok and v or 0) + 1
    local sel = live[cur_sel]
    if sel then
        pcall(ui.set, m_name.ref, sel.name)
        pcall(ui.set, m_author.ref, '\ac8c8c8ffby \aff9955ff'..(sel.author or '?'))
    end
end)

m_load:set_callback(function()
    local sel = live[cur_sel]
    if not sel then set_status('Select a config first.'); return end
    if apply_data(sel.data, false) then
        set_status('Loaded: '..sel.name)
    else
        set_status('Failed to load.')
    end
end)

m_loadaa:set_callback(function()
    local sel = live[cur_sel]
    if not sel then set_status('Select a config first.'); return end
    if apply_data(sel.data, true) then
        set_status("Loaded AA's from: "..sel.name)
    else
        set_status('Failed to load.')
    end
end)

m_save:set_callback(function()
    -- Save + re-publish your currently selected config
    local sel = live[cur_sel]
    local me  = rawget(_G,'USERNAME') or 'user'
    if not sel then set_status('Select a config first.'); return end
    if sel.author ~= me then set_status("Can't overwrite someone else's config."); return end
    local ok_e, data = pcall(export_data)
    sel.data = ok_e and data or '{}'
    -- update local saves
    local saves = my_read()
    local found = false
    for i,s in ipairs(saves) do
        if s.name == sel.name then saves[i] = sel; found = true; break end
    end
    if not found then saves[#saves+1] = sel end
    my_write(saves)
    publish(sel)
    set_status('Saved & synced: '..sel.name)
end)

m_create:set_callback(function()
    local ok_n, name = pcall(ui.get, m_name.ref)
    name = strip(ok_n and name or '')
    if name == '' then set_status('Enter a name first.'); return end
    local me   = rawget(_G,'USERNAME') or 'user'
    local ok_e, data = pcall(export_data)
    local cfg = {
        name   = name,
        author = me,
        data   = ok_e and data or '{}',
    }
    -- save locally
    local saves = my_read()
    saves[#saves+1] = cfg
    my_write(saves)
    -- publish to shared pool so everyone sees it
    publish(cfg)
    -- add to live list
    live[#live+1] = cfg
    cur_sel = #live
    refresh_list()
    set_status('Uploaded: '..name..' (everyone can see it now)')
end)

m_delete:set_callback(function()
    local sel = live[cur_sel]
    local me  = rawget(_G,'USERNAME') or 'user'
    if not sel then set_status('Select a config first.'); return end
    if sel.author ~= me then set_status("Can't delete someone else's config."); return end
    -- remove from local saves
    local saves = my_read()
    for i,s in ipairs(saves) do
        if s.name == sel.name then table.remove(saves,i); break end
    end
    my_write(saves)
    -- remove from shared pool
    local pool = shared_read()
    for i,p in ipairs(pool) do
        if p.name == sel.name and p.author == me then table.remove(pool,i); break end
    end
    shared_write(pool)
    -- remove from live
    table.remove(live, cur_sel)
    cur_sel = math.max(1, cur_sel-1)
    refresh_list()
    set_status('Deleted: '..sel.name)
end)

-- ── Show/hide on page switch ───────────────────────────────────────────
menu.set_callback(function()
    local ok,page = pcall(ui.get, gui.selection.ref)
    if not ok then return end
    if page == 'Configs' then
        for _,it in ipairs(_all_items) do
            pcall(ui.set_visible, it.ref, true)
            if rawget(_G,'_safe_display') then _safe_display(it) end
        end
    else
        for _,it in ipairs(_all_items) do
            pcall(ui.set_visible, it.ref, false)
        end
    end
end)

-- ── Init ──────────────────────────────────────────────────────────────
client.delay_call(1, reload)

end -- start_config_system

client.delay_call(1, init)
