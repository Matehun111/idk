-- ======================================================================
--  Z E N I T H  |  Cloud Config System  v2.0
--  Load alongside zenith_loader_*.lua
--  Adds a config section directly into the Anti-aimbot angles column.
--  All users share configs automatically via gamesense shared database.
-- ======================================================================

local DB_MY  = 'zenith_my_cfgs_v3'
local DB_ALL = 'zenith_shared_cfgs_v3'

-- Wait for main Zenith script to load
local function try_init(attempts)
    attempts = attempts or 0
    if attempts > 60 then return end
    if not rawget(_G,'menu') or not rawget(_G,'_auth_ok') then
        client.delay_call(0.5, function() try_init(attempts+1) end)
        return
    end
    -- ready
    setup()
end

function setup()
    local live    = {}
    local cur_sel = 1
    local ME      = rawget(_G,'USERNAME') or 'user'

    -- ── Create pui group directly (same as main script) ────────────────
    local grp = pui.group('AA', 'Anti-aimbot angles')

    local lbl_title  = grp:label('\a71bc78ff━━  Configs  ━━')
    local p_list     = grp:listbox('\nConfig List', {'No configs.'})
    local p_author   = grp:label('\ac8c8c8ff Select a config')
    local p_name     = grp:textbox('Config Name')
    local p_load     = grp:button('Load')
    local p_loadaa   = grp:button("Load Anti-Aim's")
    local p_save     = grp:button('Save')
    local p_create   = grp:button('Create / Upload')
    local p_delete   = grp:button('Delete Mine')
    local p_status   = grp:label(' ')

    -- ── Helpers ─────────────────────────────────────────────────────────
    local function set_status(s)
        p_status:set('\ac8c8c8ff'..tostring(s))
    end

    local function strip(s)
        return (s or ''):match('^%s*(.-)%s*$')
    end

    local function shared_read()
        local ok,v = pcall(database.read, DB_ALL)
        if ok and type(v)=='string' then
            local ok2,t = pcall(json.parse,v)
            if ok2 and type(t)=='table' then return t end
        end
        return {}
    end

    local function shared_write(t)
        pcall(database.write, DB_ALL, json.stringify(t))
    end

    local function my_read()
        local ok,v = pcall(database.read, DB_MY)
        if ok and type(v)=='string' then
            local ok2,t = pcall(json.parse,v)
            if ok2 and type(t)=='table' then return t end
        end
        return {}
    end

    local function my_write(t)
        pcall(database.write, DB_MY, json.stringify(t))
    end

    local function refresh()
        if #live == 0 then
            p_list:update({'No configs.'})
            p_author:set('\ac8c8c8ffNo configs yet.')
            return
        end
        local names = {}
        for i,cfg in ipairs(live) do
            local mine = cfg.author == ME
            local col  = mine and '\a71bc78ff' or '\a77ccffff'
            local tag  = mine and '[Mine] ' or '[Cloud] '
            names[i]   = col..tag..'\affffffff'..cfg.name
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

    local function export_data()
        local out = {}
        local items = menu.get_items and menu.get_items() or {}
        for _,item in ipairs(items) do
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

    local function publish(cfg)
        local pool = shared_read()
        local found = false
        for i,p in ipairs(pool) do
            if p.name==cfg.name and p.author==ME then
                pool[i]=cfg; found=true; break
            end
        end
        if not found then table.insert(pool,1,cfg) end
        shared_write(pool)
    end

    -- ── Load all configs ────────────────────────────────────────────────
    local function reload()
        live = {}
        -- shared pool first
        for _,cfg in ipairs(shared_read()) do
            live[#live+1] = cfg
        end
        -- merge own saves (update or prepend)
        for _,mine in ipairs(my_read()) do
            local found = false
            for i,cfg in ipairs(live) do
                if cfg.name==mine.name and cfg.author==ME then
                    live[i]=mine; found=true; break
                end
            end
            if not found then table.insert(live,1,mine) end
        end
        refresh()
        set_status(string.format('%d config(s) loaded.', #live))
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
        if apply_data(sel.data, false) then
            set_status('Loaded: '..sel.name)
        else
            set_status('Load failed.')
        end
    end)

    p_loadaa:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('Select a config first.'); return end
        if apply_data(sel.data, true) then
            set_status("Loaded AA's: "..sel.name)
        else
            set_status('Load failed.')
        end
    end)

    p_save:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('Select a config.'); return end
        if sel.author ~= ME then set_status("Can't edit others config."); return end
        local data = export_data()
        sel.data = data
        local saves = my_read()
        local found = false
        for i,s in ipairs(saves) do
            if s.name==sel.name then saves[i]=sel; found=true; break end
        end
        if not found then saves[#saves+1]=sel end
        my_write(saves)
        publish(sel)
        set_status('Saved & synced: '..sel.name)
    end)

    p_create:set_callback(function()
        local name = strip(p_name:get())
        if name=='' then set_status('Enter a name first.'); return end
        local cfg = {
            name   = name,
            author = ME,
            data   = export_data(),
        }
        local saves = my_read()
        saves[#saves+1] = cfg
        my_write(saves)
        publish(cfg)
        live[#live+1] = cfg
        cur_sel = #live
        refresh()
        set_status('Created & uploaded: '..name)
    end)

    p_delete:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('Select a config.'); return end
        if sel.author ~= ME then set_status("Can't delete others config."); return end
        local name = sel.name
        local saves = my_read()
        for i,s in ipairs(saves) do
            if s.name==name then table.remove(saves,i); break end
        end
        my_write(saves)
        local pool = shared_read()
        for i,p in ipairs(pool) do
            if p.name==name and p.author==ME then table.remove(pool,i); break end
        end
        shared_write(pool)
        table.remove(live, cur_sel)
        cur_sel = math.max(1, cur_sel-1)
        refresh()
        set_status('Deleted: '..name)
    end)

    -- ── Display hook ────────────────────────────────────────────────────
    menu.set_callback(function()
        lbl_title:display()
        p_list:display()
        p_author:display()
        p_name:display()
        p_load:display()
        p_loadaa:display()
        p_save:display()
        p_create:display()
        p_delete:display()
        p_status:display()
    end)

    client.delay_call(1, reload)
end

client.delay_call(1, try_init)
