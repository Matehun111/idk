-- ======================================================================
--  Z E N I T H  |  Cloud Config System  v2.0
--  Load alongside zenith_loader_*.lua
-- ======================================================================

local DB_MY  = 'zenith_my_cfgs_v3'
local DB_ALL = 'zenith_shared_cfgs_v3'

local function try_init(attempts)
    attempts = attempts or 0
    if attempts > 60 then return end
    -- Wait until main Zenith script is running and pui is available
    if not rawget(_G,'_auth_ok') or not rawget(_G,'menu') then
        client.delay_call(0.5, function() try_init(attempts+1) end)
        return
    end
    setup()
end

function setup()
    local live    = {}
    local cur_sel = 1
    local ME      = rawget(_G,'USERNAME') or 'user'

    local grp = pui.group('AA', 'Anti-aimbot angles')

    local lbl_title = grp:label('\a71bc78ff\xe2\x94\x81\xe2\x94\x81  Configs  \xe2\x94\x81\xe2\x94\x81')
    local p_list    = grp:listbox('\nConfig List', {'No configs.'})
    local p_author  = grp:label('\ac8c8c8ffSelect a config')
    local p_name    = grp:textbox('Config Name')
    local p_load    = grp:button('Load')
    local p_loadaa  = grp:button("Load Anti-Aim's")
    local p_save    = grp:button('Save')
    local p_create  = grp:button('Create / Upload')
    local p_delete  = grp:button('Delete Mine')
    local p_status  = grp:label(' ')

    local _items = {lbl_title,p_list,p_author,p_name,p_load,p_loadaa,p_save,p_create,p_delete,p_status}

    -- ── DB helpers ──────────────────────────────────────────────────────
    local function jread(key)
        local ok,v = pcall(database.read, key)
        if ok and type(v)=='string' then
            local ok2,t = pcall(json.parse, v)
            if ok2 and type(t)=='table' then return t end
        end
        return {}
    end
    local function jwrite(key, t) pcall(database.write, key, json.stringify(t)) end

    local function set_status(s) p_status:set('\ac8c8c8ff'..tostring(s)) end
    local function strip(s) return (s or ''):match('^%s*(.-)%s*$') end

    -- ── Refresh listbox ─────────────────────────────────────────────────
    local function refresh()
        if #live == 0 then
            p_list:update({'No configs.'})
            p_author:set('\ac8c8c8ffNo configs yet.')
            return
        end
        local names = {}
        for i,cfg in ipairs(live) do
            local mine = cfg.author == ME
            names[i] = (mine and '\a71bc78ff[Mine] ' or '\a77ccffff[Cloud] ')..'\affffffff'..cfg.name
        end
        p_list:update(names)
        cur_sel = math.max(1, math.min(cur_sel, #live))
        p_list:set(cur_sel - 1)
        local sel = live[cur_sel]
        if sel then
            p_name:set(sel.name)
            p_author:set('\ac8c8c8ffby \aff9955ff'..(sel.author or '?'))
        end
    end

    -- ── Config data helpers ─────────────────────────────────────────────
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
        if not ok or type(data)~='table' then return false end
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

    local function publish(cfg)
        local pool = jread(DB_ALL)
        local found = false
        for i,p in ipairs(pool) do
            if p.name==cfg.name and p.author==ME then pool[i]=cfg; found=true; break end
        end
        if not found then table.insert(pool,1,cfg) end
        jwrite(DB_ALL, pool)
    end

    -- ── Load all configs ────────────────────────────────────────────────
    local function reload()
        live = {}
        for _,cfg in ipairs(jread(DB_ALL)) do live[#live+1]=cfg end
        for _,mine in ipairs(jread(DB_MY)) do
            local found=false
            for i,cfg in ipairs(live) do
                if cfg.name==mine.name and cfg.author==ME then live[i]=mine; found=true; break end
            end
            if not found then table.insert(live,1,mine) end
        end
        refresh()
        set_status(string.format('%d config(s).', #live))
    end

    -- ── Callbacks ───────────────────────────────────────────────────────
    p_list:set_callback(function(self)
        cur_sel = (self:get() or 0) + 1
        local sel = live[cur_sel]
        if sel then
            p_name:set(sel.name)
            p_author:set('\ac8c8c8ffby \aff9955ff'..(sel.author or '?'))
        end
    end)

    p_load:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('Select a config first.'); return end
        set_status(apply_data(sel.data,false) and 'Loaded: '..sel.name or 'Load failed.')
    end)

    p_loadaa:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('Select a config first.'); return end
        set_status(apply_data(sel.data,true) and "Loaded AA's: "..sel.name or 'Load failed.')
    end)

    p_save:set_callback(function()
        local sel = live[cur_sel]
        if not sel or sel.author~=ME then set_status("Can't edit this config."); return end
        sel.data = export_data()
        local saves = jread(DB_MY)
        local found=false
        for i,s in ipairs(saves) do if s.name==sel.name then saves[i]=sel;found=true;break end end
        if not found then saves[#saves+1]=sel end
        jwrite(DB_MY, saves)
        publish(sel)
        set_status('Saved & synced: '..sel.name)
    end)

    p_create:set_callback(function()
        local name = strip(p_name:get())
        if name=='' then set_status('Enter a name first.'); return end
        local cfg = {name=name, author=ME, data=export_data()}
        local saves = jread(DB_MY); saves[#saves+1]=cfg; jwrite(DB_MY,saves)
        publish(cfg)
        live[#live+1]=cfg; cur_sel=#live
        refresh()
        set_status('Uploaded: '..name..' (visible to everyone)')
    end)

    p_delete:set_callback(function()
        local sel = live[cur_sel]
        if not sel or sel.author~=ME then set_status("Can't delete this config."); return end
        local name = sel.name
        local saves=jread(DB_MY)
        for i,s in ipairs(saves) do if s.name==name then table.remove(saves,i);break end end
        jwrite(DB_MY,saves)
        local pool=jread(DB_ALL)
        for i,p in ipairs(pool) do if p.name==name and p.author==ME then table.remove(pool,i);break end end
        jwrite(DB_ALL,pool)
        table.remove(live,cur_sel); cur_sel=math.max(1,cur_sel-1)
        refresh(); set_status('Deleted: '..name)
    end)

    -- ── Hook into existing menu.set_callback ────────────────────────────
    -- Use client.set_event_callback on paint to call display every frame
    client.set_event_callback('paint', function()
        for _,it in ipairs(_items) do
            pcall(function() it:display() end)
        end
    end)

    client.delay_call(1, reload)
    set_status('Loading configs...')
end

client.delay_call(1, try_init)
