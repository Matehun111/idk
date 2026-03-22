-- ZENITH | NIGHTLY | Cloud Build

local function _safe_display(obj)
    if obj and type(obj)=="table" and type(obj.display)=="function" then
        pcall(obj.display, obj)
    end
end

local function _safe_set_visible(obj, val)
    if type(obj)=="number" then
        pcall(ui.set_visible, obj, val)
    elseif obj and type(obj)=="table" and type(obj.set_visible)=="function" then
        pcall(obj.set_visible, obj, val)
    end
end

if not LPH_OBFUSCATED then
    LPH_NO_VIRTUALIZE = function(...) return ... end
end

local USERNAME = _auth_user or 'user'
local BUILD    = BUILD_VERSION

local _HAS_AIMBOT   = (BUILD == 'beta' or BUILD == 'nightly')
local _HAS_RESOLVER = (BUILD == 'nightly')

local f = string.format
local merge = table.concat

local ffi = require "ffi"
local vector = require "vector"
local http = require "gamesense/http"
local inspect = require 'gamesense/inspect'
local base64 = require "gamesense/base64"
local websockets = require 'gamesense/websockets'
local c_entity = require "gamesense/entity"
local csgo_weapons = require "gamesense/csgo_weapons"
local msgpack = require 'gamesense/msgpack'

local clipboard do
    clipboard = { }

    local GetClipboardTextCount = vtable_bind('vgui2.dll', 'VGUI_System010', 7, 'int(__thiscall*)(void*)')
    local SetClipboardText = vtable_bind('vgui2.dll', 'VGUI_System010', 9, 'void(__thiscall*)(void*, const char*, int)')
    local GetClipboardText = vtable_bind('vgui2.dll', 'VGUI_System010', 11, 'int(__thiscall*)(void*, int, const char*, int)')

    local function set(...)
        local text = tostring(table.concat({ ... }))

        SetClipboardText(text, string.len(text))
    end

    local function get()
        local len = GetClipboardTextCount()

        if len > 0 then
            local char_arr = ffi.typeof('char[?]')(len)
            GetClipboardText(0, char_arr, len)
            local text = ffi.string(char_arr, len - 1)

            local text_end do
                text_end = text:find('_zenith')

                if text_end then
                    text = text:sub(1, text_end)
                end
            end

            return text
        end
    end

    clipboard.set = set
    clipboard.get = get
end

local oprint = print
local function print(...)
    local res = ""

    for _, str in ipairs({...}) do
        res = res .. tostring(str) .. "\t"
    end

    oprint(res)
end

local function print_raw(r, g, b, ...)
    client.color_log(r, g, b, 'Zenith\0')
    client.color_log(150, 150, 150, ' · \0')
    client.color_log(255, 255, 255, f(...))
end

local function contains(list, value)
    for i = 1, #list do
        if list[i] == value then
            return true
        end
    end

    return false
end

--- enumerations
local e_statement = {
    [0]  = "Main",
    [1]  = "Standing",
    [2]  = "Moving",
    [3]  = "Slow Walk",
    [4]  = "Crouched",
    [5]  = "Move Crouched",
    [6]  = "Air",
    [7]  = "Air Crouched",
    [8]  = "Fake Lag"
}

local e_hotkey_mode = {
    [0] = "Always on",
    [1] = "On hotkey",
    [2] = "Toggle",
    [3] = "Off hotkey"
}

local e_hitgroup = {
    [0]  = "generic",
    [1]  = "head",
    [2]  = "chest",
    [3]  = "stomach",
    [4]  = "left arm",
    [5]  = "right arm",
    [6]  = "left leg",
    [7]  = "right leg",
    [8]  = "neck",
    [10] = "gear"
}

--- regions
local utils = { }
local software = { }
local override = { }

local iengineclient = { }
local inetchannel = { }

local ceasar = { }

local menu = { }
local gui = { }

local motion = { }
local windows = { }

local graphics = { }
local decorations = { }

local exploit = { }
local localplayer = { }
local statement = { }

local antiaim = { }
local widgets = { }
local settings = { }

local angles = { }
local defensive = { }
local fast_ladder = { }
local anim_breakers = { }

local disablers = { }
local avoid_backstab = { }
local safe_head = { }
local fs_disablers = { }
local delay_data_all = { }

local yaw_direction = { }
local manual_direction = { }
local hitchance = { }
local log_aimbot_shots = { }

local aa_tweaks = { }
local eventlogs = { }
local watermark = { }
local keybinds = { }
local indicators = { }
local arrows = { }
local velocity_warning = { }
local ctx_bebra = { }
local custom_scope = { }

local clientside_nickname = { }
local trashtalk = { }
local tab_to_game = { }
local buy_bot = { }
local auto_peek = { }
local hit_marker = { }
local unmute = { }
local shared = { }

do
    local escape = {
        ["="] = true,
        ["0"] = true,
        ["1"] = true,
        ["2"] = true,
        ["3"] = true,
        ["4"] = true,
        ["5"] = true,
        ["6"] = true,
        ["7"] = true,
        ["8"] = true,
        ["9"] = true
    }

    local colors = {
        ['black'] = { 0, 0, 0, 0 },
        ['nick'] = { 255, 62, 62, 255 },
        ['default'] = { 198, 203, 209, 255 },
        ['highlight'] = { 151, 177, 187, 255 },
        ['miss'] = { 154, 255, 154, 255 },
        ['idle'] = { 137, 137, 137, 255 }
    }

    utils.unmute = vtable_bind('client.dll', 'GameClientExports001', 3, 'void(__thiscall*)(void*, int)')

    function utils.keys(list)
        local keys = { }

        for k, v in pairs(list) do
            keys[v] = k
        end

        return keys
    end

    function utils.collect_keys(tbl, init)
        local keys = init or { }
        for item, value in next, tbl do
            keys[#keys+1] = item
        end

        return keys
    end

    function utils.clamp(x, min, max)
        return math.max(min, math.min(x, max))
    end

    function utils.round(x)
        if x < 0 then
            return math.ceil(x - 0.5)
        end

        return math.floor(x + 0.5)
    end

    function utils.lerp(a, b, t)
        return a + t * (b - a)
    end

    function utils.inverse_lerp(a, b, v)
        return (v - a) / (b - a)
    end

    function utils.to_hex(r, g, b, a)
        return f("%02x%02x%02x%02x", r, g, b, a)
    end

    function utils.format(str, r, g, b, a)
        if type(str) ~= 'string' then
            return str
        end

        str = string.gsub(str, '[\v\r]', {
            ['\v'] = '\a' .. utils.to_hex(r, g, b, a),
            ['\r'] = '\aFFFFFFFF'
        })

        str = string.gsub(str, "\a%[(.-)%]", function (col)
            local r, g, b, a = unpack(colors[col])
            return '\a' .. utils.to_hex(r, g, b, a)
        end)

        return str
    end

    function utils.map(v, in_a, in_b, out_a, out_b, clamped)
        if clamped then
            v = utils.clamp(v, in_a, in_b)
        end

        return utils.lerp(out_a, out_b, utils.inverse_lerp(in_a, in_b, v))
    end

    function utils.normalize(x, min, max)
        local delta = max - min

        while x < min do
            x = x + delta
        end

        while x > max do
            x = x - delta
        end

        return x
    end

    function utils.normalize_yaw(x)
        return utils.normalize(x, -180, 180)
    end

    function utils.breathe(x)
        x = x % 2.0

        if x > 1.0 then
            x = 2.0 - x
        end

        return x
    end

    function utils.color_lerp(r1, g1, b1, a1, r2, g2, b2, a2, t)
        local r = utils.lerp(r1, r2, t)
        local g = utils.lerp(g1, g2, t)
        local b = utils.lerp(b1, b2, t)
        local a = utils.lerp(a1, a2, t)

        return r, g, b, a
    end

    function utils.win11_fix(input)
        local result = ""

        for i = 1, #input do
            local char = input:sub(i, i)
            local byte = string.byte(char)

            if escape[char] or (byte >= 65 and byte <= 122) then
                result = result .. char
            end
        end

        return result
    end

    function utils.get_eye_position(ent)
        local x1, y1, z1 = entity.get_origin(ent)
        if x1 == nil then return end

        local x2, y2, z2 = entity.get_prop(ent, "m_vecViewOffset")
        if x2 == nil then return end

        return x1 + x2, y1 + y2, z1 + z2
    end
end

local memory do
    memory = { }

    function memory.pattern_scan(module, signature, add)
        local buff = ffi.new("char[1024]")

        local c = 0

        for char in string.gmatch(signature, "..%s?") do
            if char == "? " or char == "?? " then
                buff[c] = 0xcc
            else
                buff[c] = tonumber("0x" .. char)
            end

            c = c + 1
        end

        local result = ffi.cast("uintptr_t", client.find_signature(module, ffi.string(buff)))

        if add and tonumber(result) ~= 0 then
            result = ffi.cast("uintptr_t", tonumber(result) + add)
        end

        return result
    end

    function memory.rel_jmp(addr, pattern)
        if pattern then
            addr = memory.pattern_scan(addr, pattern)
        end

        addr = ffi.cast("uint8_t*", addr)

        local jmp_addr = ffi.cast("uintptr_t", addr)
        local jmp_disp = ffi.cast("int32_t*", jmp_addr + 0x1)[0]

        return ffi.cast("uintptr_t", jmp_addr + 0x5 + jmp_disp)
    end

    function memory.addr_to_num(in_addr)
        return tonumber(ffi.cast("int", in_addr))
    end

    local jmp_ecx = client.find_signature("engine.dll", "\xFF\xE1")
    local fnGetModuleHandle = ffi.cast("uint32_t(__fastcall*)(unsigned int, unsigned int, const char*)", jmp_ecx)
    local fnGetProcAddress = ffi.cast("uint32_t(__fastcall*)(unsigned int, unsigned int, uint32_t, const char*)", jmp_ecx)

    local pGetProcAddress = ffi.cast("uint32_t**", ffi.cast("uint32_t", client.find_signature("engine.dll", "\xFF\x15\xCC\xCC\xCC\xCC\xA3\xCC\xCC\xCC\xCC\xEB\x05")) + 2)[0][0]
    local pGetModuleHandle = ffi.cast("uint32_t**", ffi.cast("uint32_t", client.find_signature("engine.dll", "\xFF\x15\xCC\xCC\xCC\xCC\x85\xC0\x74\x0B")) + 2)[0][0]

    function memory.get_export(module, func, typedef)
        local ctype = ffi.typeof(typedef)

        local fn = fnGetProcAddress(pGetProcAddress, 0, fnGetModuleHandle(pGetModuleHandle, 0, module), func)

        return function (...)
            return ffi.cast(ctype, jmp_ecx)(fn, 0, ...)
        end
    end
end

LPH_NO_VIRTUALIZE(function ()
    do
        software.rage = {
            weapon = {
                weapon_type = ui.reference("Rage", "Weapon type", "Weapon type")
            },

            aimbot = {
                enabled = { ui.reference("Rage", "Aimbot", "Enabled") },
                target_selection = ui.reference("Rage", "Aimbot", "Target selection"),
                minimum_damage = ui.reference("Rage", "Aimbot", "Minimum damage"),
                hitchance = ui.reference('Rage', 'Aimbot', 'Minimum hit chance'),
                auto_scope = ui.reference('Rage', 'Aimbot', 'Automatic Scope'),
                minimum_damage_override = { ui.reference("Rage", "Aimbot", "Minimum damage override") },
                prefer_safe_point = ui.reference("Rage", "Aimbot", "Prefer safe point"),
                force_safe_point = ui.reference("Rage", "Aimbot", "Force safe point"),
                force_body_aim = ui.reference("Rage", "Aimbot", "Force body aim"),
                double_tap = { ui.reference("Rage", "Aimbot", "Double tap") }
            },

            other = {
                quick_peek_assist = { ui.reference("Rage", "Other", "Quick peek assist") },
                duck_peek_assist = ui.reference("Rage", "Other", "Duck peek assist")
            }
        }

        software.aa = {
            angles = {
                enabled = ui.reference("AA", "Anti-aimbot angles", "Enabled"),
                pitch = { ui.reference("AA", "Anti-aimbot angles", "Pitch") },
                yaw_base = ui.reference("AA", "Anti-aimbot angles", "Yaw base"),
                yaw = { ui.reference("AA", "Anti-aimbot angles", "Yaw") },
                yaw_jitter = { ui.reference("AA", "Anti-aimbot angles", "Yaw jitter") },
                body_yaw = { ui.reference("AA", "Anti-aimbot angles", "Body yaw") },
                freestanding_body_yaw = ui.reference("AA", "Anti-aimbot angles", "Freestanding body yaw"),
                edge_yaw = ui.reference("AA", "Anti-aimbot angles", "Edge yaw"),
                freestanding = { ui.reference("AA", "Anti-aimbot angles", "Freestanding") },
                roll = ui.reference("AA", "Anti-aimbot angles", "Roll")
            },

            fakelag = {
                enabled = { ui.reference("AA", "Fake lag", "Enabled") },
                amount = ui.reference("AA", "Fake lag", "Amount"),
                variance = ui.reference("AA", "Fake lag", "Variance"),
                limit = ui.reference("AA", "Fake lag", "Limit")
            },

            other = {
                slow_motion = { ui.reference("AA", "Other", "Slow motion") },
                leg_movement = ui.reference("AA", "Other", "Leg movement"),
                on_shot_antiaim = { ui.reference("AA", "Other", "On shot anti-aim") },
                fake_peek = { ui.reference("AA", "Other", "Fake peek") }
            }
        }

        software.visuals = {
            scope_overlay = ui.reference('VISUALS', 'Effects', 'Remove scope overlay')
        }

        software.misc = {
            miscellaneous = {
                clan_tag_spammer = { ui.reference("Misc", "Miscellaneous", "Clan tag spammer") },
                ping_spike = { ui.reference("Misc", "Miscellaneous", "Ping spike") }
            },

            settings = {
                menu_color = ui.reference("Misc", "Settings", "Menu color"),
                output = ui.reference("Misc", "Miscellaneous", "Draw console output"),
                dpi_scale = ui.reference("Misc", "Settings", "DPI scale"),
                sv_maxusrcmdprocessticks = ui.reference("Misc", "Settings", "sv_maxusrcmdprocessticks2")
            }
        }

        function software.is_double_tap()
            return ui.get(software.rage.aimbot.double_tap[1])
                and ui.get(software.rage.aimbot.double_tap[2])
        end

        function software.is_minimum_damage_override()
            return ui.get(software.rage.aimbot.minimum_damage_override[1])
                and ui.get(software.rage.aimbot.minimum_damage_override[2])
        end

        function software.is_force_body_aim()
            return ui.get(software.rage.aimbot.force_body_aim)
        end

        function software.is_force_safe_point()
            return ui.get(software.rage.aimbot.force_safe_point)
        end

        function software.is_quick_peek_assist()
            return ui.get(software.rage.other.quick_peek_assist[1])
                and ui.get(software.rage.other.quick_peek_assist[2])
        end

        function software.is_freestanding()
            return ui.get(software.aa.angles.freestanding[1])
                and ui.get(software.aa.angles.freestanding[2])
        end

        function software.is_duck_peek_assist()
            return ui.get(software.rage.other.duck_peek_assist)
        end

        function software.is_on_shot_antiaim()
            return ui.get(software.aa.other.on_shot_antiaim[1])
                and ui.get(software.aa.other.on_shot_antiaim[2])
        end

        function software.is_slow_motion()
            return ui.get(software.aa.other.slow_motion[1])
                and ui.get(software.aa.other.slow_motion[2])
        end

        function software.is_edge()
            return ui.get(software.aa.angles.edge_yaw)
        end

        function software.get_color()
            return ui.get(software.misc.settings.menu_color)
        end

        function software.get_dpi_scale()
            local value = ui.get(software.misc.settings.dpi_scale)
            local unit = string.match(value, "(%d+)%%")

            return unit * 0.01
        end

        function software.get_minimum_damage()
            if software.is_minimum_damage_override() then
                return ui.get(software.rage.aimbot.minimum_damage_override[3]), true
            end

            return ui.get(software.rage.aimbot.minimum_damage), false
        end
    end
end)()

do
    local data = { }

    local function get_value(ref)
        local value = { ui.get(ref) }
        local typeof = ui.type(ref)

        if typeof == "hotkey" then
            return { e_hotkey_mode[value[2]] }
        end

        return value
    end

    function override.get(ref, ...)
        local value = data[ref]

        if value == nil then
            return
        end

        return unpack(value)
    end

    function override.set(ref, ...)
        if data[ref] == nil then
            data[ref] = get_value(ref)
        end

        ui.set(ref, ...)
    end

    function override.unset(ref)
        if data[ref] == nil then
            return
        end

        ui.set(ref, unpack(data[ref]))
        data[ref] = nil
    end
end

do
    local native_GetNetChannelInfo = vtable_bind("engine.dll", "VEngineClient014", 78, "void*(__thiscall*)(void*)")

    function iengineclient.get_net_channel_info()
        return native_GetNetChannelInfo()
    end
end

do
    local native_IsLoopback = vtable_thunk(6, "bool(__thiscall*)(void*)")
    local native_IsTimingOut = vtable_thunk(7, "bool(__thiscall*)(void*)")

    local native_GetLatency = vtable_thunk(9, "float(__thiscall*)(void*, int flow)")
    local native_GetAvgLatency = vtable_thunk(10, "float(__thiscall*)(void*, int flow)")

    local native_GetRemoteFramerate = vtable_thunk(25, "void(__thiscall*)(void*, float *pflFrameTime, float *pflFrameTimeStdDeviation, float *pflFrameStartTimeStdDeviation)")

    local pflFrameTime = ffi.new "float[1]"
    local pflFrameTimeStdDeviation = ffi.new "float[1]"
    local pflFrameStartTimeStdDeviation = ffi.new "float[1]"

    local function get_remote_framerate(inetchannelinfo)
        if inetchannelinfo == nil then
            return 0, 0
        end

        local server_var = 0
        local server_framerate = 0

        native_GetRemoteFramerate(inetchannelinfo, pflFrameTime, pflFrameTimeStdDeviation, pflFrameStartTimeStdDeviation)

        if pflFrameTime[0] > 0 then
            server_framerate = pflFrameTime[0] * 1000
            server_var = pflFrameStartTimeStdDeviation[0] * 1000
        end

        return server_framerate, server_var
    end

    function inetchannel.is_loopback(inetchannelinfo)
        return native_IsLoopback(inetchannelinfo)
    end

    function inetchannel.is_timing_out(inetchannelinfo)
        return native_IsTimingOut(inetchannelinfo)
    end

    function inetchannel.get_latency(inetchannelinfo, flow)
        return native_GetLatency(inetchannelinfo, flow)
    end

    function inetchannel.get_avg_latency(inetchannelinfo, flow)
        return native_GetAvgLatency(inetchannelinfo, flow)
    end

    function inetchannel.get_remote_framerate(inetchannelinfo)
        return get_remote_framerate(inetchannelinfo)
    end
end

do
    local function ascii_base(s)
        if string.lower(s) == s then
            return string.byte("a")
        end

        return string.byte("A")
    end

    function ceasar.cipher(s, key)
        local result = string.gsub(s, "%a", function(char)
            local base = ascii_base(s)
            local byte = string.byte(char)

            return string.char(base + (byte - base + key) % 26)
        end)

        return result
    end

    function ceasar.decipher(s, key)
        return ceasar.cipher(s, -key)
    end
end

LPH_NO_VIRTUALIZE(function ()
    do
        local items = { }
        local records = { }

        local callbacks = { }

        local function get_value(ref)
            local value = { pcall(ui.get, ref) }
            if not value[1] then return end

            return unpack(value, 2)
        end

        local function get_keys(value)
            if type(value[1]) == "table" then
                return utils.keys(value[1])
            end

            return { }
        end

        local function update_items()
            for i = 1, #callbacks do
                callbacks[i]()
            end

            for i = 1, #items do
                local item = items[i]

                ui.set_visible(item.ref, item.is_visible)
                item.is_visible = false
            end
        end

        local c_item = { } do
            function c_item:new()
                return setmetatable({ }, self)
            end

            function c_item:init()
                local function callback(ref)
                    self:update_value(ref)
                    self:invoke_callback(ref)

                    update_items()
                end

                ui.set_callback(self.ref, callback)
            end

            function c_item:get()
                return unpack(self.value)
            end

            function c_item:set(...)
                local ref = self.ref

                ui.set(ref, ...)
                self:update_value(ref)
            end

            function c_item:have_key(key)
                return self.keys[key] ~= nil
            end

            function c_item:rawget()
                return ui.get(self.ref)
            end

            function c_item:reset()
                pcall(ui.set, self.ref, unpack(self.default))
            end

            function c_item:record(tab, name)
                if records[tab] == nil then
                    records[tab] = { }
                end

                self.is_recorded = true
                records[tab][name] = self

                return self
            end

            function c_item:save()
                if not self.is_recorded then
                    error("unable to save unrecorded item")
                    return
                end

                self.is_saved = true
                return self
            end

            function c_item:display()
                self.is_visible = true
            end

            function c_item:config_ignore()
                self.saveable = false
                return self
            end

            function c_item:set_callback(callback)
                self.callbacks[#self.callbacks + 1] = callback
            end

            function c_item:update_value(ref)
                local value = { get_value(ref) }
                self.keys = get_keys(value)

                self.value = value
            end

            function c_item:invoke_callback(...)
                for i = 1, #self.callbacks do
                    self.callbacks[i](...)
                end
            end

            function c_item:get_ref()
                return self.ref
            end

            c_item.__index = c_item
        end

        function menu.new_item(fn, ...)
            local ref = fn(...)

            local value = { get_value(ref) }
            local typeof = ui.type(ref)

            local item = c_item:new()

            item.ref = ref
            item.name = select(3, ...)

            item.value = value
            item.default = value

            item.keys = get_keys(value)
            item.callbacks = { }

            item.is_saved = false
            item.is_visible = false
            item.is_recorded = false

            item.saveable = true

            if typeof == "button" then
                item.callbacks[#item.callbacks + 1] = select(4, ...)
            end

            item:init()
            items[#items + 1] = item

            return item
        end

        function menu.get_items()
            return items
        end

        function menu.get_records()
            return records
        end

        function menu.set_callback(callback)
            callbacks[#callbacks + 1] = callback
        end

        function menu.update()
            update_items()
        end

        function menu.get_items()
            return items
        end
    end
end)()

local zenith_config_system do
    zenith_config_system = { }

    local function resolve_item_export(item)
        if not item.saveable then
            return
        end

        if ui.type(item.ref) == "label" or ui.type(item.ref) == "hotkey" then
            return
        end

        return item.value
    end

    local function resolve_item_import(item, data)
        if ui.type(item.ref) == "label" or ui.type(item.ref) == "hotkey" then
            return true
        end

        if not item.saveable then
            return true
        end

        if data == nil then
            return false
        end

        item:set(unpack(data))

        return true
    end

    function zenith_config_system.export_to_str()
        local config_result = { }

        for _, item in ipairs(menu.get_items()) do
            config_result[item.name] = resolve_item_export(item)
        end

        cvar.play:invoke_callback("buttons\\blip1")

        return base64.encode(json.stringify(config_result)) .. '_zenith'
    end

    function zenith_config_system.import_from_str(str)
        str = str:gsub('_zenith', '')
        local status, config = pcall(base64.decode, str)
        if not status then
            print_raw(255, 100, 100, "Failed to decode config")
            return
        end

        status, config = pcall(json.parse, config)
        if not status then
            print_raw(255, 100, 100, "Failed to parse config")
            return
        end

        for _, item in ipairs(menu.get_items()) do
            local imported = resolve_item_import(item, config[item.name])

            if not imported then
                --print_raw(255, 100, 100, merge { "Failed to import ", item.name:gsub("\n", "") })
            end
        end

        cvar.play:invoke_callback("buttons\\blip2")
    end
end

--  ZENITH UI  -  Zenith pui tabs
--  Pages: Home | Builder | Defensive | Visual | Misc | Configs
--  (replaces the original gui.selection combobox approach)

local required = require
local pui = required 'gamesense/pui' or error('failed to load pui')

local anti_aim_states = {"Standing", "Running", "Slowwalk", "Ducking", "Air", "Air+Duck", "Safe", "Fakelag"}
local teams_list = {"CT", "T"}
local custom_aa = {}
local x_sc, y_sc = client.screen_size()

-- pui group references
local group_fakelag = pui.group('AA', 'Fake lag')
local group         = pui.group('AA', 'Anti-aimbot angles')
local group_other   = pui.group('AA', 'Other')

pui.macros.dot = '\v•  \r'

-- ── TAB SELECTOR ───────────────────────────────────────────────────────
local vars = {}

do -- selection
    vars.selection = {}
    vars.selection.label   = group_fakelag:label('\a888888ff────  \affffffff Z E N I T H  \a888888ff────')
    -- tab/aa_tab are plain tables; all pui items rendered unconditionally
    vars.selection.tab     = { value = 'Anti Aim' }
    vars.selection.aa_tab  = { value = 'Features' }
    vars.selection.tab_label = nil
end

-- Stubs for removed pui vars (logic still references these)
vars.aa = vars.aa or {}
vars.aa.encha = vars.aa.encha or {
    get = function(_, key) return false end,
    set = function() end
}
vars.aa.manual_left  = vars.aa.manual_left  or { get = function() return false end }
vars.aa.manual_right = vars.aa.manual_right or { get = function() return false end }

vars.angles = vars.angles or {}
vars.visuals = vars.visuals or {}
vars.visuals.watermark_color2 = vars.visuals.watermark_color2 or {
    get = function() return 195, 198, 255, 255 end
}
vars.misc = vars.misc or {}
vars.misc.selection = vars.misc.selection or {
    get = function(_, key) return false end
}

-- ── USER / BUILD INFO (Fake lag column) ────────────────────────────────
shared = shared or {}
shared.fl_whatsup     = group_fakelag:label(string.format('\a666666ff►  \affffffff%s', USERNAME))
shared.fl_build       = group_fakelag:label(string.format('\a444444ffbuild  \a5599ffff%s', BUILD))
shared.fl_online      = group_fakelag:label('\a444444ffonline  \affd700ff…')
shared.fl_leaderboard = group_fakelag:label('\a444444ffkills  \a888888ff…')

-- shared.online_label: stub that delegates to fl_online (used by websocket callback)
shared.online_label = {
    set = function(_, str)
        if shared.fl_online then shared.fl_online:set(str) end
    end,
    display = function() end,  -- pui labels always visible, no display() needed
    get = function() return 'Online: ...' end,
}

-- ── LOAD COUNTER + ONLINE ───────────────────────────────────────────
do
    -- Times Loaded: increment local counter each load
    local _loads_key = 'zenith_total_loads_v1'
    local ok_l, cur_loads = pcall(database.read, _loads_key)
    cur_loads = (ok_l and type(cur_loads)=='number') and cur_loads or 0
    cur_loads = cur_loads + 1
    pcall(database.write, _loads_key, cur_loads)
    -- value stored, will be applied when label is created below
    rawset(_G, "_zenith_load_count", cur_loads)

    -- Online users: increment on load, decrement on shutdown
    -- Uses counterapi.dev (free, reliable)
    local _ns  = 'zenith-hvh-v2'
    local _key = 'online_users'

    local function _set_online(n)
        if shared.fl_online then
            local col = n > 0 and '\affd700ff' or '\aff6666ff'
            shared.fl_online:set(string.format('\a444444ffonline  %s%d\affffffff', col, n))
        end
    end

    local _incremented = false
    local function _get_count()
        http.get(
            string.format('https://api.counterapi.dev/v1/%s/%s', _ns, _key),
            function(ok, res)
                local body = type(res)=='table' and res.body or res
                if ok and body then
                    local n = body:match('"count":(%d+)')
                    if n then _set_online(tonumber(n)) end
                end
                client.delay_call(60, _get_count)
            end
        )
    end

    local function _increment()
        if _incremented then return end
        _incremented = true
        http.get(
            string.format('https://api.counterapi.dev/v1/%s/%s/up', _ns, _key),
            function(ok, res)
                local body = type(res)=='table' and res.body or res
                if ok and body then
                    local n = body:match('"count":(%d+)')
                    if n then _set_online(tonumber(n)) end
                end
                client.delay_call(60, _get_count)
            end
        )
    end

    client.set_event_callback('shutdown', function()
        if _incremented then
            http.get(string.format('https://api.counterapi.dev/v1/%s/%s/down', _ns, _key), function() end)
        end
    end)

    client.delay_call(2, _increment)
end

-- ── STATISTICS (Misc sidebar) ──────────────────────────────────────────
do
    vars.statistics = {}

    vars.statistics.label_info  = group_other:label('\f<dot>Information')
    vars.statistics.user        = group_other:label('\f<dot>User: \v'..USERNAME)
    vars.statistics.loaded      = group_other:label(string.format('\f<dot>Times Loaded: \v%d', _G._zenith_load_count or 0))
    vars.statistics.time_in_game= group_other:label('\f<dot>Session: ')
end

-- ── HELPERS (Zenith helpers table) ───────────────────────────────────
local smoothy_fn = (function()
    local function ease(t, b, c, d) return c * t / d + b end
    local M = {__metatable=false}
    M.__call = function(self, duration, value)
        local clock = globals.frametime()
        duration = duration or 0.15
        if type(value)=='boolean' then value = value and 1 or 0 end
        if self.value == value then return value end
        if clock<=0 or clock>=duration then self.value=value
        else
            local prev = ease(clock, self.value, value-self.value, duration)
            if math.abs(value-prev)<=0.001 then prev=value end
            self.value = prev
        end
        return self.value
    end
    M.__index = {update=M.__call}
    return function(default)
        return setmetatable({value=default or 0, easing=ease}, M)
    end
end)()

local helpers = {}
helpers['functions'] = {
    alpha_vel        = smoothy_fn(0),
    is_bd_alpha      = smoothy_fn(0),
    velocity_smoth   = smoothy_fn(0),
    time             = globals.realtime(),
    side             = 0, prev_side = 0, canbepressed = true,
    damage_anim      = 0, defensive_ticks = 0, is_backstab = false,
    grenades_list    = {}, prev_wpn = nil, hitmarker_data = {},
    framerate        = 0, last_framerate = 0, ticks = 0, delayed_switch = false,

    is_bounded = function(self, v1x, v1y, v2x, v2y)
        local mx, my = ui.mouse_position()
        return mx >= v1x and mx <= v2x and my >= v1y and my <= v2y
    end,
    lerp2 = function(self, x, v, t)
        if type(x)=='table' then
            return self:lerp2(x[1],v[1],t), self:lerp2(x[2],v[2],t),
                   self:lerp2(x[3],v[3],t), self:lerp2(x[4],v[4],t)
        end
        local delta = v - x
        if type(delta)=='number' and math.abs(delta)<0.005 then return v end
        return delta * t + x
    end,
    get_damage = function(self)
        local en = software.rage.aimbot
        if ui.get(en.minimum_damage_override[1]) and ui.get(en.minimum_damage_override[2]) then
            return ui.get(en.minimum_damage_override[3])
        end
        return ui.get(en.minimum_damage)
    end,
    get_player_weapons = function(self, ent)
        local weapons = {}
        for i=0,63 do
            local w = entity.get_prop(ent,"m_hMyWeapons",i)
            if w==nil then goto continue end
            weapons[#weapons+1]=w
            ::continue::
        end
        return weapons
    end,
    is_class_grenades = function(self, ic)
        if ic=="weapon_smokegrenade"  then return vars.misc.selection:get("Smoke") end
        if ic=="weapon_hegrenade"     then return vars.misc.selection:get("He Grenade") end
        if ic=="weapon_incgrenade" or ic=="weapon_molotov" then return vars.misc.selection:get("Molotov/Incendiary") end
        return false
    end,
    is_needed_weapon = function(self, weapon)
        local info = csgo_weapons(weapon)
        if info.weapon_type_int ~= 9 then return false end
        return self:is_class_grenades(info.item_class)
    end,
    update_player_weapons = function(self, ent)
        local weapons = self:get_player_weapons(ent)
        for i=1,#weapons do
            local w = weapons[i]
            if self:is_needed_weapon(w) then
                self.grenades_list[#self.grenades_list+1]=w
            end
        end
    end,
    rgba_to_hex = function(self,r,g,b,a)
        return string.format('%02x%02x%02x%02x',r,g,b,a)
    end,
    fade_handle = function(self, time, str, r, g, b, a)
        local c1,c2,c3,c4 = vars.visuals.watermark_color2:get()
        local t_out, t_iter = {}, 1
        local ra = (c1-r); local ga = (c2-g); local ba = (c3-b)
        for i=1,#str do
            local iter = (i-1)/(#str-1) + time
            t_out[t_iter] = "\a"..self:rgba_to_hex(
                r+ra*math.abs(math.cos(iter)), g+ga*math.abs(math.cos(iter)),
                b+ba*math.abs(math.cos(iter)), a)
            t_out[t_iter+1] = str:sub(i,i)
            t_iter = t_iter + 2
        end
        return t_out
    end,
    fade_handle2 = function(self, time, str, r, g, b, a)
        a = a or 255
        local c1,c2,c3 = 32, 32, 32
        local t_out, t_iter = {}, 1
        local ra=(c1-r); local ga=(c2-g); local ba=(c3-b)
        for i=1,#str do
            local iter = (i-1)/(#str-1) + time
            t_out[t_iter] = "\a"..self:rgba_to_hex(
                r+ra*math.abs(math.cos(iter)), g+ga*math.abs(math.cos(iter)),
                b+ba*math.abs(math.cos(iter)), a)
            t_out[t_iter+1] = str:sub(i,i)
            t_iter = t_iter + 2
        end
        return t_out
    end,
    manualaa = function(self)
        if not vars.aa.encha:get("Manual AA") then self.side=0; return 0 end
        self.canbepressed = self.time+0.2 < globals.realtime()
        if vars.aa.manual_left:get() and self.canbepressed then
            self.side=1; if self.prev_side==self.side then self.side=0 end; self.time=globals.realtime()
        end
        if vars.aa.manual_right:get() and self.canbepressed then
            self.side=2; if self.prev_side==self.side then self.side=0 end; self.time=globals.realtime()
        end
        self.prev_side=self.side
        return self.side
    end,
    update_session = function(self)
        local rt = globals.realtime()
        local h = math.floor(rt/3600)
        local m = math.floor(rt/60)
        local s = math.floor(rt)
        local text
        if s==1 and h<1 and m<1 then text=s.." Second"
        elseif s>=2 and h<1 and m<1 then text=s.." Seconds"
        elseif m>=2 and h<1 then text=m.." Minutes"
        elseif m==1 and h<1 then text=m.." Minute"
        elseif h<2 then text=h.." Hour"
        else text=h.." Hours" end
        vars.statistics.time_in_game:set('\f<dot>Session: \v'..text)
    end,
    animations = (function()
        local a={data={}}
        function a:clamp(v,mn,mx) return math.min(mx,math.max(mn,v)) end
        function a:animate(k,f,speed)
            if not self.data[k] then self.data[k]=0 end
            speed=speed or 4
            local b=globals.frametime()*speed*(f and -1 or 1)
            self.data[k]=self:clamp(self.data[k]+b,0,1)
            return self.data[k]
        end
        return a
    end)(),
    contains = function(self, s)
        if type(s)~="string" then return false end
        return string.find(s,"%s")~=nil and string.find(s,"%S")~=nil
            or string.find(s,"%s")==nil and string.find(s,"%S")~=nil
    end,
    is_dt_charged = function(self)
        if not entity.get_local_player() then return end
        local lp = entity.get_local_player()
        local weapon = entity.get_player_weapon(lp)
        if lp==nil or weapon==nil then return false end
        if globals.curtime()-(16*globals.tickinterval()) < entity.get_prop(lp,'m_flNextAttack') then return false end
        if globals.curtime()-(0*globals.tickinterval()) < entity.get_prop(weapon,'m_flNextPrimaryAttack') then return false end
        return true
    end,
    is_defensive = function(self, index)
        self.defensive_ticks = math.max(entity.get_prop(index,'m_nTickBase'), self.defensive_ticks or 0)
        return math.abs(entity.get_prop(index,'m_nTickBase')-self.defensive_ticks)>2
            and math.abs(entity.get_prop(index,'m_nTickBase')-self.defensive_ticks)<14
    end,
}

-- ── HIDE NATIVE AA CONTROLS (mirrors Zenith hide_menu) ───────────────
hide_menu = function(state)
    local aa = software.aa.angles
    local fl = software.aa.fakelag
    local ot = software.aa.other

    ui.set_visible(aa.enabled, state)
    ui.set_visible(aa.pitch[1], state)
    ui.set_visible(aa.pitch[2] or aa.pitch[1], state)
    ui.set_visible(aa.roll, state)
    ui.set_visible(aa.yaw_base, state)
    ui.set_visible(aa.yaw[1], state)
    ui.set_visible(aa.yaw[2] or aa.yaw[1], state)
    ui.set_visible(aa.yaw_jitter[1], state)
    ui.set_visible(aa.yaw_jitter[2] or aa.yaw_jitter[1], state)
    ui.set_visible(aa.body_yaw[1], state)
    ui.set_visible(aa.body_yaw[2] or aa.body_yaw[1], state)
    ui.set_visible(aa.freestanding[1], state)
    ui.set_visible(aa.freestanding[2] or aa.freestanding[1], state)
    ui.set_visible(aa.freestanding_body_yaw, state)
    ui.set_visible(aa.edge_yaw, state)

    ui.set_visible(fl.enabled[1], state)
    ui.set_visible(fl.amount, state)
    ui.set_visible(fl.variance, state)
    ui.set_visible(fl.limit, state)

    ui.set_visible(ot.slow_motion[1], state)
    ui.set_visible(ot.on_shot_antiaim[1], state)
    ui.set_visible(ot.fake_peek[1], state)
    _safe_set_visible(software.aa.other.leg_movement, state)
end

-- watermark label animation (paint_ui)
client.set_event_callback('paint_ui', function()
    if entity.get_local_player() == nil then helpers['functions'].defensive_ticks = 0 end
    if not ui.is_menu_open() then return end

    helpers['functions']:update_session()
    hide_menu(false)

    local ref = software.misc.settings.menu_color
    local r, g, b, a = ui.get(ref)
    local water_ui = helpers['functions']:fade_handle2(-globals.curtime(), '  Z  E  N  I  T  H', r, g, b)
    vars.selection.label:set("                    "..table.concat(water_ui))
end)

client.set_event_callback('shutdown', function()
    -- reset native AA
    local aa = software.aa.angles
    ui.set(aa.yaw[1], "off")
    ui.set(aa.pitch[1], 'off')
    ui.set(aa.yaw_base, "local view")
    ui.set(aa.body_yaw[1], 'off')
    ui.set(aa.yaw_jitter[1], "off")
    hide_menu(true)
end)

-- ── GUI system: create proper menu items for original code compatibility ──────
-- gui.selection: sub-page navigation
gui = gui or {}
-- gui.enabled stub (checkbox removed, always on)
gui.enabled = gui.enabled or { get=function() return true end, set=function() end, set_callback=function() end }

if not gui.selection or not gui.selection.ref then
    -- Build the page list based on version
    local pages = {"⌂  Home", "◆  Builder", "❈  Defensive", "◉  Visual", "☰  Misc", "⚙  Configs"}
    if _HAS_AIMBOT then table.insert(pages, 4, "◎  Aimbot") end
    if _HAS_RESOLVER then table.insert(pages, #pages, "↻  Resolver") end
    gui.selection = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles",
        merge { "\n", "gui.selection" }, pages)
end

function gui.shutdown()
    local aa = software.aa.angles
    ui.set_visible(aa.enabled, true)
end

function gui.frame()
    -- hide native aa controls when our script handles them
    local aa = software.aa.angles
    local fl = software.aa.fakelag
    local ot = software.aa.other
        ui.set_visible(aa.enabled, false)
        ui.set_visible(fl.enabled[1],  false); ui.set_visible(fl.amount,  false)
        ui.set_visible(fl.variance,    false); ui.set_visible(fl.limit,   false)
        ui.set_visible(ot.slow_motion[1],     false)
        ui.set_visible(ot.on_shot_antiaim[1], false)
        ui.set_visible(ot.fake_peek[1],       false)
end

-- Disable aimbot-related UI on stable build
if not _HAS_AIMBOT then
    -- Hide exploit/dt buttons on stable; they'll still exist but be inert
    client.delay_call(0.5, function()
        local function safe_hide(ref)
            pcall(ui.set_visible, ref, false)
        end
        safe_hide(software.rage.aimbot.double_tap[1])
        safe_hide(software.rage.aimbot.force_body_aim)
        safe_hide(software.rage.aimbot.force_safe_point)
    end)
end

do
    local function linear(t, b, c, d)
        return c * t / d + b
    end

    local function get_deltatime()
        return globals.frametime()
    end

    local function solve(easing_fn, prev, new, clock, duration)
        if clock <= 0 then return new end
        if clock >= duration then return new end

        prev = easing_fn(clock, prev, new - prev, duration)

        if type(prev) == "number" then
            if math.abs(new - prev) < 0.001 then
                return new
            end

            local remainder = math.fmod(prev, 1.0)

            if remainder < 0.001 then
                return math.floor(prev)
            end

            if remainder > 0.999 then
                return math.ceil(prev)
            end
        end

        return prev
    end

    function motion.interp(a, b, t, easing_fn)
        easing_fn = easing_fn or linear

        if type(b) == "boolean" then
            b = b and 1 or 0
        end

        return solve(easing_fn, a, b, get_deltatime(), t)
    end
end

LPH_NO_VIRTUALIZE(function ()
    do
        local data = { }
        local queue = { }

        local mouse_pos = vector()
        local mouse_pos_prev = vector()

        local mouse_down = false
        local mouse_clicked = false

        local mouse_down_duration = 0
        local dragging_smth = false

        local mouse_delta = vector()
        local mouse_clicked_pos = vector()

        local hovered_window
        local foreground_window

        local c_window = { } do
            function c_window:new(name)
                local window = { }

                window.name = name

                window.pos = vector()
                window.size = vector()

                window.anchor = vector(0.0, 0.0)

                window.updated = false
                window.dragging = false

                data[name] = window
                queue[#queue + 1] = window

                setmetatable(window, self)
                return window
            end

            function c_window:set_pos(pos)
                local screen = vector(client.screen_size())
                local new_pos = pos:clone()

                new_pos.x = utils.clamp(new_pos.x, 0, screen.x - self.size.x)
                new_pos.y = utils.clamp(new_pos.y, 0, screen.y - self.size.y)

                self.pos = new_pos
            end

            function c_window:set_size(size)
                local size_delta = size - self.size

                self.size = size
                self:set_pos(self.pos - size_delta * self.anchor)
            end

            function c_window:set_anchor(anchor)
                self.anchor = anchor
            end

            function c_window:is_hovering()
                return self.hovering
            end

            function c_window:is_dragging()
                return self.dragging
            end

            function c_window:update()
                self.updated = true
            end

            c_window.__index = c_window
        end

        local function is_collided(point, a, b)
            return point.x >= a.x and point.y >= a.y
                and point.x <= b.x and point.y <= b.y
        end

        local function update_mouse_inputs()
            local cursor = vector(ui.mouse_position())
            local is_down = client.key_state(0x01)

            local delta_time = globals.frametime()

            mouse_pos = cursor
            mouse_delta = mouse_pos - mouse_pos_prev

            mouse_pos_prev = mouse_pos

            mouse_down = is_down
            mouse_clicked = is_down and mouse_down_duration < 0

            mouse_down_duration = is_down and (mouse_down_duration < 0 and 0 or mouse_down_duration + delta_time) or -1

            if mouse_clicked then
                mouse_clicked_pos = mouse_pos
            end
        end

        local function appear_all_windows()
            for i = 1, #queue do
                local window = queue[i]

                local pos = window.pos
                local size = window.size

                local r, g, b, a = 0, 0, 0, 255

                renderer.rectangle(pos.x, pos.y, size.x, size.y, r, g, b, a)
            end
        end

        local function find_hovered_window()
            local found_window = nil

            if ui.is_menu_open() then
                for i = 1, #queue do
                    local window = queue[i]

                    local pos = window.pos
                    local size = window.size

                    if not window.updated then
                        goto continue
                    end

                    if not is_collided(mouse_pos, pos, pos + size) then
                        goto continue
                    end

                    found_window = window
                    ::continue::
                end
            end

            hovered_window = found_window
        end

        local function find_foreground_window()
            if mouse_down then
                if mouse_clicked and hovered_window ~= nil then
                    for i = 1, #queue do
                        local window = queue[i]

                        if window == hovered_window then
                            table.remove(queue, i)
                            table.insert(queue, window)

                            break
                        end
                    end

                    foreground_window = hovered_window
                    return
                end

                return
            end

            foreground_window = nil
        end

        local function update_all_windows()
            for i = 1, #queue do
                local window = queue[i]

                window.updated = false

                window.hovering = false
                window.dragging = false
            end
        end

        local function update_hovered_window()
            if hovered_window == nil then
                return
            end

            hovered_window.hovering = true
        end

        local function update_foreground_window()
            dragging_smth = false
            if foreground_window == nil then
                return
            end

            local new_position = foreground_window.pos + mouse_delta

            foreground_window:set_pos(new_position)
            foreground_window.dragging = true
            dragging_smth = true
        end

        function windows.new(name, x, y)
            local window = data[name]
                or c_window:new(name)

            local screen = vector(client.screen_size())
            window:set_pos(screen * vector(x, y))

            return window
        end

        function windows.frame()
            -- appear_all_windows()
            update_mouse_inputs()

            find_hovered_window()
            find_foreground_window()

            update_all_windows()

            update_hovered_window()
            update_foreground_window()
        end

        client.set_event_callback('setup_command', function (cmd)
            if dragging_smth or hovered_window then
                cmd.in_attack = false
                cmd.in_attack2 = false
            end
        end)
    end
end)()

do
    local alpha_unit = 1 / 255

    local function string_alpha_mod(s, alpha)
        local result = s:gsub("\a(%x%x%x%x%x%x)(%x%x)", function(rgb, a)
            return f("\a%s%02x", rgb, tonumber(a, 16) * alpha)
        end)

        return result
    end

    -- shared.online_label delegated to fl_online below

    graphics.config_import = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Import Configuration", function ()
        zenith_config_system.import_from_str(clipboard.get())
    end):config_ignore()

    graphics.config_default = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Default Configuration", function ()
        zenith_config_system.import_from_str(
            'eyJCb2R5IHlhd1xuY3VzdG9tX2JvZHlfeWF3X1N0YW5kaW5nIjpbIk9mZiJdLCJVdGlsaXR5IHdlYXBvbiI6W3t9XSwiXG5jdXN0b21feWF3XzE4MGxyX21vZGVfRmFrZSBMYWciOlsiU2lkZSBiYXNlZCJdLCItIE9wdGlvbnMiOltbIkRpc2FibGUgb24gV2FybXVwIiwiRGlzYWJsZSBXaGlsZSBObyBFbmVtaWVzIiwiQXZvaWQgQmFja3N0YWIiLCJGYXN0IExhZGRlciIsIkVkZ2UgWWF3IG9uIEZEIl1dLCJZYXcgYmFzZVxuY3VzdG9tX3lhd19iYXNlX0Zha2UgTGFnIjpbIkxvY2FsIHZpZXciXSwiXG5Qb3NpdGlvbiI6WzUwXSwiLSBTdGF0ZVxuZGVmZW5zaXZlOjpzdGF0ZSI6W1siQWlyIiwiU3RhbmRpbmciLCJDcm91Y2hlZCJdXSwiXG5jdXN0b21feWF3X29mZnNldF9TdGFuZGluZyI6WzBdLCJEZWxheVxuY3VzdG9tX0RlbGF5X0Nyb3VjaGVkIjpbNV0sIlJpZ2h0IG9mZnNldFxuY3VzdG9tX3lhd19yaWdodF9TdGFuZGluZyI6WzBdLCJcbmN1c3RvbV95YXdfMTgwbHJfbW9kZV9NYWluIjpbIlNpZGUgYmFzZWQiXSwiUmFuZG9taXphdGlvblxuY3VzdG9tX2ppdHRlcl9yYW5kb21pemF0aW9uX1N0YW5kaW5nIjpbMF0sIllhd1xuY3VzdG9tX3lhd19Nb3ZpbmciOlsiT2ZmIl0sIlxuY3VzdG9tX3lhd19vZmZzZXRfU2xvdyBXYWxrIjpbMF0sIlxuZ3VpLnNlbGVjdGlvbiI6WyJIb21lIl0sIlxuY3VzdG9tX2JvZHlfeWF3X29mZnNldF9GYWtlIExhZyI6WzBdLCJQaXRjaFxuY3VzdG9tX3BpdGNoX01vdmluZyI6WyJPZmYiXSwiRGVsYXlcbmN1c3RvbV9EZWxheV9Nb3ZpbmciOls1XSwiUmlnaHQgb2Zmc2V0XG5jdXN0b21feWF3X3JpZ2h0X0Nyb3VjaGVkIjpbMF0sIi0gSXRlbXNcbndpZGdldHM6Oml0ZW1zIjpbWyJXYXRlcm1hcmsiLCJLZXliaW5kcyIsIlZlbG9jaXR5IFdhcm5pbmciLCJDcm9zc2hhaXIgSW5kaWNhdG9yIiwiRGFtYWdlIEluZGljYXRvciIsIk9uLVNjcmVlbiBMb2dzIiwiSGl0IFJhdGUiXV0sIkxlZnQgb2Zmc2V0XG5jdXN0b21feWF3X2xlZnRfRmFrZSBMYWciOlswXSwiUmFuZG9taXphdGlvblxuY3VzdG9tX2ppdHRlcl9yYW5kb21pemF0aW9uX0FpciBDcm91Y2hlZCI6WzBdLCJZYXdcbmN1c3RvbV95YXdfU3RhbmRpbmciOlsiT2ZmIl0sIlxuY3VzdG9tX3lhd19vZmZzZXRfTW92aW5nIjpbMF0sIlxuY3VzdG9tX3lhd19vZmZzZXRfQWlyIjpbMF0sIlxuY3VzdG9tX2ppdHRlcl9tb2RlX1Nsb3cgV2FsayI6WyIyLVdheSJdLCJZYXcgYmFzZVxuY3VzdG9tX3lhd19iYXNlX0Nyb3VjaGVkIjpbIkxvY2FsIHZpZXciXSwiWWF3IGppdHRlclxuY3VzdG9tX3lhd19qaXR0ZXJfU3RhbmRpbmciOlsiT2ZmIl0sIkppdHRlciBvZmZzZXRcbmN1c3RvbV9qaXR0ZXJfb2Zmc2V0X0FpciBDcm91Y2hlZCI6WzBdLCJcbmN1c3RvbV9ib2R5X3lhd19vZmZzZXRfQ3JvdWNoZWQiOlswXSwiV2lkZ2V0cyI6W3RydWVdLCJcbmN1c3RvbV9waXRjaF9vZmZzZXRfTW92ZSBDcm91Y2hlZCI6WzBdLCJNYW51YWwgQ29sb3IiOlsxMTMsMTUyLDI1NSwyNTVdLCItIFBpdGNoXG5kZWZlbnNpdmU6OnBpdGNoIjpbIlVwIFN3aXRjaCJdLCJcbmN1c3RvbV9qaXR0ZXJfbW9kZV9BaXIiOlsiMi1XYXkiXSwiRGVsYXlcbmN1c3RvbV9EZWxheV9BaXIgQ3JvdWNoZWQiOls1XSwiVHdlYWtzIjpbdHJ1ZV0sIkJvZHkgeWF3XG5jdXN0b21fYm9keV95YXdfU2xvdyBXYWxrIjpbIk9mZiJdLCJQaXRjaFxuY3VzdG9tX3BpdGNoX1N0YW5kaW5nIjpbIk9mZiJdLCJMZWZ0IG9mZnNldFxuY3VzdG9tX3lhd19sZWZ0X1N0YW5kaW5nIjpbMF0sIlNhZmUgSGVhZCI6W3RydWVdLCJCb2R5IHlhd1xuY3VzdG9tX2JvZHlfeWF3X0FpciI6WyJPZmYiXSwiU2hhcmVkIExvZ28iOlt0cnVlXSwiWWF3XG5jdXN0b21feWF3X1Nsb3cgV2FsayI6WyJPZmYiXSwiRnJlZXN0YW5kaW5nIGJvZHkgeWF3XG5jdXN0b21fZnJlZXN0YW5kaW5nX2JvZHlfeWF3X1Nsb3cgV2FsayI6W2ZhbHNlXSwiWWF3IGppdHRlclxuY3VzdG9tX3lhd19qaXR0ZXJfQWlyIjpbIk9mZiJdLCJQaXRjaFxuY3VzdG9tX3BpdGNoX0FpciI6WyJPZmYiXSwiWWF3IGJhc2VcbmN1c3RvbV95YXdfYmFzZV9NYWluIjpbIkxvY2FsIHZpZXciXSwiTGVmdCBvZmZzZXRcbmN1c3RvbV95YXdfbGVmdF9TbG93IFdhbGsiOlswXSwiU3RhdGUiOlsiTWFpbiJdLCItIERpc2FibGUgT25cbmZzX2Rpc2FibGVyczo6c3RhdGVzIjpbe31dLCJNYW51YWwgWWF3IjpbdHJ1ZV0sIkNvbG9yIjpbMjU1LDI1NSwyNTUsMjU1XSwiWWF3XG5jdXN0b21feWF3X01vdmUgQ3JvdWNoZWQiOlsiT2ZmIl0sIkVuYWJsZSBTbG93IFdhbGsiOltmYWxzZV0sIkxlZnQgb2Zmc2V0XG5jdXN0b21feWF3X2xlZnRfQ3JvdWNoZWQiOlswXSwiXG5jdXN0b21feWF3XzE4MGxyX21vZGVfQ3JvdWNoZWQiOlsiU2lkZSBiYXNlZCJdLCJGcmVlc3RhbmRpbmcgYm9keSB5YXdcbmN1c3RvbV9mcmVlc3RhbmRpbmdfYm9keV95YXdfTW92aW5nIjpbZmFsc2VdLCJcbmN1c3RvbV9waXRjaF9vZmZzZXRfRmFrZSBMYWciOlswXSwiQm9keSB5YXdcbmN1c3RvbV9ib2R5X3lhd19NYWluIjpbIk9mZiJdLCJMZWZ0IG9mZnNldFxuY3VzdG9tX3lhd19sZWZ0X01vdmUgQ3JvdWNoZWQiOlswXSwiUmlnaHQgb2Zmc2V0XG5jdXN0b21feWF3X3JpZ2h0X01vdmUgQ3JvdWNoZWQiOlswXSwiTGVmdCBvZmZzZXRcbmN1c3RvbV95YXdfbGVmdF9BaXIgQ3JvdWNoZWQiOlswXSwiUGl0Y2hcbmN1c3RvbV9waXRjaF9Nb3ZlIENyb3VjaGVkIjpbIk9mZiJdLCJLZXliaW5kcyI6W2ZhbHNlXSwiUmFuZG9taXphdGlvblxuY3VzdG9tX2ppdHRlcl9yYW5kb21pemF0aW9uX01haW4iOlswXSwiRGVsYXlcbmN1c3RvbV9EZWxheV9BaXIiOls1XSwiTW9kZSI6WyJEZWZhdWx0Il0sIkVuYWJsZSBGYWtlIExhZyI6W2ZhbHNlXSwiQm9keSB5YXdcbmN1c3RvbV9ib2R5X3lhd19Nb3ZpbmciOlsiT2ZmIl0sIllhd1xuY3VzdG9tX3lhd19NYWluIjpbIk9mZiJdLCJGcmVlc3RhbmRpbmcgYm9keSB5YXdcbmN1c3RvbV9mcmVlc3RhbmRpbmdfYm9keV95YXdfQWlyIENyb3VjaGVkIjpbZmFsc2VdLCJSaWdodCBvZmZzZXRcbmN1c3RvbV95YXdfcmlnaHRfQWlyIENyb3VjaGVkIjpbMF0sIlxuY3VzdG9tX2ppdHRlcl9tb2RlX01vdmUgQ3JvdWNoZWQiOlsiMi1XYXkiXSwiQ3VzdG9tIE5hbWUiOltmYWxzZV0sIkZyZWVzdGFuZGluZyBib2R5IHlhd1xuY3VzdG9tX2ZyZWVzdGFuZGluZ19ib2R5X3lhd19GYWtlIExhZyI6W2ZhbHNlXSwiXG5jdXN0b21fYm9keV95YXdfb2Zmc2V0X01vdmluZyI6WzBdLCJcbmN1c3RvbV9qaXR0ZXJfbW9kZV9Dcm91Y2hlZCI6WyIyLVdheSJdLCJKaXR0ZXIgb2Zmc2V0XG5jdXN0b21faml0dGVyX29mZnNldF9NYWluIjpbMF0sIkJvZHkgeWF3XG5jdXN0b21fYm9keV95YXdfRmFrZSBMYWciOlsiT2ZmIl0sIllhdyBqaXR0ZXJcbmN1c3RvbV95YXdfaml0dGVyX0Zha2UgTGFnIjpbIk9mZiJdLCJSYW5kb21pemF0aW9uXG5jdXN0b21faml0dGVyX3JhbmRvbWl6YXRpb25fRmFrZSBMYWciOlswXSwiRnJlZXN0YW5kaW5nIGJvZHkgeWF3XG5jdXN0b21fZnJlZXN0YW5kaW5nX2JvZHlfeWF3X1N0YW5kaW5nIjpbZmFsc2VdLCJKaXR0ZXIgb2Zmc2V0XG5jdXN0b21faml0dGVyX29mZnNldF9Nb3ZlIENyb3VjaGVkIjpbMF0sIkppdHRlciBvZmZzZXRcbmN1c3RvbV9qaXR0ZXJfb2Zmc2V0X0Zha2UgTGFnIjpbMF0sIlxuY3VzdG9tX2ppdHRlcl9tb2RlX0Zha2UgTGFnIjpbIjItV2F5Il0sIlBpdGNoXG5jdXN0b21fcGl0Y2hfRmFrZSBMYWciOlsiT2ZmIl0sIkNsaWVudC1TaWRlIE5pY2tuYW1lIjpbZmFsc2VdLCJcbmN1c3RvbV9waXRjaF9vZmZzZXRfQWlyIENyb3VjaGVkIjpbMF0sIlJpZ2h0IG9mZnNldFxuY3VzdG9tX3lhd19yaWdodF9GYWtlIExhZyI6WzBdLCJSYW5kb21pemF0aW9uXG5jdXN0b21faml0dGVyX3JhbmRvbWl6YXRpb25fQ3JvdWNoZWQiOlswXSwiQ3VzdG9tIFNjb3BlIE92ZXJsYXkiOltmYWxzZV0sIlxuY3VzdG9tX2ppdHRlcl9tb2RlX0FpciBDcm91Y2hlZCI6WyIyLVdheSJdLCJZYXdcbmN1c3RvbV95YXdfRmFrZSBMYWciOlsiT2ZmIl0sIlNlY29uZGFyeSB3ZWFwb24iOlsiTm9uZSJdLCJBcHBseSI6e30sIlxuY3VzdG9tX3BpdGNoX29mZnNldF9BaXIiOlswXSwiXG5jdXN0b21fYm9keV95YXdfb2Zmc2V0X0FpciBDcm91Y2hlZCI6WzBdLCJCb2R5IHlhd1xuY3VzdG9tX2JvZHlfeWF3X0FpciBDcm91Y2hlZCI6WyJPZmYiXSwiXG5jdXN0b21feWF3X29mZnNldF9NYWluIjpbMF0sIlxuY3VzdG9tX3lhd18xODBscl9tb2RlX1N0YW5kaW5nIjpbIlNpZGUgYmFzZWQiXSwiWWF3IGppdHRlclxuY3VzdG9tX3lhd19qaXR0ZXJfTW92ZSBDcm91Y2hlZCI6WyJPZmYiXSwiWWF3IGppdHRlclxuY3VzdG9tX3lhd19qaXR0ZXJfQWlyIENyb3VjaGVkIjpbIk9mZiJdLCJCb2R5IHlhd1xuY3VzdG9tX2JvZHlfeWF3X0Nyb3VjaGVkIjpbIk9mZiJdLCJGcmVlc3RhbmRpbmcgYm9keSB5YXdcbmN1c3RvbV9mcmVlc3RhbmRpbmdfYm9keV95YXdfQWlyIjpbZmFsc2VdLCJcbmN1c3RvbV95YXdfb2Zmc2V0X0FpciBDcm91Y2hlZCI6WzBdLCJBbmltYXRpb24gQnJlYWtlcnMiOlt0cnVlXSwiLSBDb2xvclxud2lkZ2V0czo6Y29sb3JfcGlja2VyIjpbMTEzLDE1MiwyNTUsMjU1XSwiSml0dGVyIG9mZnNldFxuY3VzdG9tX2ppdHRlcl9vZmZzZXRfQ3JvdWNoZWQiOlswXSwiXG5jdXN0b21feWF3X29mZnNldF9Nb3ZlIENyb3VjaGVkIjpbMF0sIllhd1xuY3VzdG9tX3lhd19BaXIgQ3JvdWNoZWQiOlsiT2ZmIl0sIllhdyBiYXNlXG5jdXN0b21feWF3X2Jhc2VfTW92ZSBDcm91Y2hlZCI6WyJMb2NhbCB2aWV3Il0sIllhdyBiYXNlXG5jdXN0b21feWF3X2Jhc2VfQWlyIjpbIkxvY2FsIHZpZXciXSwiXG5jdXN0b21faml0dGVyX21vZGVfU3RhbmRpbmciOlsiMi1XYXkiXSwiUmFuZG9taXphdGlvblxuY3VzdG9tX2ppdHRlcl9yYW5kb21pemF0aW9uX01vdmluZyI6WzBdLCJSaWdodCBvZmZzZXRcbmN1c3RvbV95YXdfcmlnaHRfQWlyIjpbMF0sIlBpdGNoXG5jdXN0b21fcGl0Y2hfQWlyIENyb3VjaGVkIjpbIk9mZiJdLCJKaXR0ZXIgb2Zmc2V0XG5jdXN0b21faml0dGVyX29mZnNldF9TdGFuZGluZyI6WzBdLCJcbmN1c3RvbV95YXdfMTgwbHJfbW9kZV9Nb3ZlIENyb3VjaGVkIjpbIlNpZGUgYmFzZWQiXSwiLSBTdGF0ZXNcbnNhZmVfaGVhZDo6c3RhdGVzIjpbWyJBaXIgS25pZmUiLCJTdGFuZGluZyIsIkNyb3VjaGVkIl1dLCJFbmFibGUgQWlyIENyb3VjaGVkIjpbZmFsc2VdLCJEZWZlbnNpdmUgQUEiOlt0cnVlXSwiRW5hYmxlIENyb3VjaGVkIjpbZmFsc2VdLCJcbmN1c3RvbV95YXdfMTgwbHJfbW9kZV9BaXIgQ3JvdWNoZWQiOlsiU2lkZSBiYXNlZCJdLCJcbmN1c3RvbV95YXdfMTgwbHJfbW9kZV9BaXIiOlsiU2lkZSBiYXNlZCJdLCJZYXdcbmN1c3RvbV95YXdfQWlyIjpbIk9mZiJdLCJSYW5kb21pemF0aW9uXG5jdXN0b21faml0dGVyX3JhbmRvbWl6YXRpb25fQWlyIjpbMF0sIlByaW1hcnkgd2VhcG9uIjpbIk5vbmUiXSwiWWF3IGJhc2VcbmN1c3RvbV95YXdfYmFzZV9BaXIgQ3JvdWNoZWQiOlsiTG9jYWwgdmlldyJdLCJZYXcgYmFzZVxuY3VzdG9tX3lhd19iYXNlX1Nsb3cgV2FsayI6WyJMb2NhbCB2aWV3Il0sIi0gWWF3XG5kZWZlbnNpdmU6OnlhdyI6WyI1LVdheSJdLCJMZWZ0IG9mZnNldFxuY3VzdG9tX3lhd19sZWZ0X0FpciI6WzBdLCJcbmN1c3RvbV9ib2R5X3lhd19vZmZzZXRfTW92ZSBDcm91Y2hlZCI6WzBdLCJcbmN1c3RvbV9ib2R5X3lhd19vZmZzZXRfQWlyIjpbMF0sIkVuYWJsZSBBaXIiOltmYWxzZV0sIi0gTW9kZVxuZGVmZW5zaXZlOjptb2RlIjpbWyJPbiBTaG90IEFudGkgQWltIiwiRG91YmxlIFRhcCJdXSwiXG5jdXN0b21fcGl0Y2hfb2Zmc2V0X01haW4iOlswXSwiRnJlZXN0YW5kaW5nIGJvZHkgeWF3XG5jdXN0b21fZnJlZXN0YW5kaW5nX2JvZHlfeWF3X01vdmUgQ3JvdWNoZWQiOltmYWxzZV0sIlxuY3VzdG9tX3BpdGNoX29mZnNldF9TbG93IFdhbGsiOlswXSwiUmFuZG9taXphdGlvblxuY3VzdG9tX2ppdHRlcl9yYW5kb21pemF0aW9uX01vdmUgQ3JvdWNoZWQiOlswXSwiLSBGdW5jdGlvbnNcbnNldHRpbmdzOjp0d2Vha3MiOltbIkxvZyBBaW1ib3QgU2hvdHMiLCJUcmFzaHRhbGsiLCJVbm11dGUgU2lsZW5jZWQgUGxheWVycyIsIkNvbnNvbGUgRmlsdGVyIiwiRGFtYWdlIE1hcmtlciJdXSwiRGVsYXlcbmN1c3RvbV9EZWxheV9GYWtlIExhZyI6WzVdLCItIE9wdGlvbnNcbm1hbnVhbF9kaXJlY3Rpb246Om9wdGlvbnMiOltbIkRpc2FibGUgWWF3IE1vZGlmaWVycyIsIkZyZWVzdGFuZGluZyBCb2R5IFlhdyIsIkR1Y2sgRXhwbG9pdCJdXSwiRGVsYXlcbmN1c3RvbV9EZWxheV9Nb3ZlIENyb3VjaGVkIjpbNV0sIkRlbGF5XG5jdXN0b21fRGVsYXlfU2xvdyBXYWxrIjpbNV0sIllhdyBiYXNlXG5jdXN0b21feWF3X2Jhc2VfU3RhbmRpbmciOlsiTG9jYWwgdmlldyJdLCJCdXkgQm90IjpbZmFsc2VdLCJFbmFibGUgTW92aW5nIjpbZmFsc2VdLCJMZWZ0IG9mZnNldFxuY3VzdG9tX3lhd19sZWZ0X01vdmluZyI6WzBdLCJSaWdodCBvZmZzZXRcbmN1c3RvbV95YXdfcmlnaHRfTWFpbiI6WzBdLCJcbmN1c3RvbV9ib2R5X3lhd19vZmZzZXRfU2xvdyBXYWxrIjpbMF0sIkRlbGF5XG5jdXN0b21fRGVsYXlfU3RhbmRpbmciOls1XSwiXG5PZmZzZXQiOlsxMF0sIllhdyBqaXR0ZXJcbmN1c3RvbV95YXdfaml0dGVyX01haW4iOlsiT2ZmIl0sIkRlbGF5XG5jdXN0b21fRGVsYXlfTWFpbiI6WzVdLCJZYXcgYmFzZVxuY3VzdG9tX3lhd19iYXNlX01vdmluZyI6WyJMb2NhbCB2aWV3Il0sIkVuYWJsZSBTdGFuZGluZyI6W2ZhbHNlXSwiUmlnaHQgb2Zmc2V0XG5jdXN0b21feWF3X3JpZ2h0X1Nsb3cgV2FsayI6WzBdLCJNYW51YWwgQXJyb3dzIjpbdHJ1ZV0sIkFudGkgQWltIEJ1aWxkZXIiOlsiUmVjb21tZW5kZWQiXSwiXG5jdXN0b21feWF3XzE4MGxyX21vZGVfU2xvdyBXYWxrIjpbIlNpZGUgYmFzZWQiXSwiUGl0Y2hcbmN1c3RvbV9waXRjaF9Dcm91Y2hlZCI6WyJPZmYiXSwiUmlnaHQgb2Zmc2V0XG5jdXN0b21feWF3X3JpZ2h0X01vdmluZyI6WzBdLCJZYXcgaml0dGVyXG5jdXN0b21feWF3X2ppdHRlcl9Nb3ZpbmciOlsiT2ZmIl0sIk5pY2tuYW1lIjpbIiJdLCJZYXcgaml0dGVyXG5jdXN0b21feWF3X2ppdHRlcl9Dcm91Y2hlZCI6WyJPZmYiXSwiSml0dGVyIG9mZnNldFxuY3VzdG9tX2ppdHRlcl9vZmZzZXRfTW92aW5nIjpbMF0sIlBpdGNoXG5jdXN0b21fcGl0Y2hfTWFpbiI6WyJPZmYiXSwiXG5jdXN0b21feWF3XzE4MGxyX21vZGVfTW92aW5nIjpbIlNpZGUgYmFzZWQiXSwiXG5jdXN0b21feWF3X29mZnNldF9GYWtlIExhZyI6WzBdLCItIERpc3BsYXlcbndpZGdldHM6OmRpc3BsYXkiOltbIlVzZXJuYW1lIiwiTGF0ZW5jeSIsIlRpbWUiLCJGUFMiLCJTZXJ2ZXIgZnJhbWV0aW1lIl1dLCJGcmVlc3RhbmRpbmcgYm9keSB5YXdcbmN1c3RvbV9mcmVlc3RhbmRpbmdfYm9keV95YXdfTWFpbiI6W2ZhbHNlXSwiUmFuZG9taXphdGlvblxuY3VzdG9tX2ppdHRlcl9yYW5kb21pemF0aW9uX1Nsb3cgV2FsayI6WzBdLCJcbmN1c3RvbV9waXRjaF9vZmZzZXRfTW92aW5nIjpbMF0sIkxlZnQgb2Zmc2V0XG5jdXN0b21feWF3X2xlZnRfTWFpbiI6WzBdLCItIExlZyBNb3ZlbWVudCI6WyJTdGF0aWMiXSwiXG5jdXN0b21fYm9keV95YXdfb2Zmc2V0X1N0YW5kaW5nIjpbMF0sIkppdHRlciBvZmZzZXRcbmN1c3RvbV9qaXR0ZXJfb2Zmc2V0X0FpciI6WzBdLCJcbmN1c3RvbV9ib2R5X3lhd19vZmZzZXRfTWFpbiI6WzBdLCJCb2R5IHlhd1xuY3VzdG9tX2JvZHlfeWF3X01vdmUgQ3JvdWNoZWQiOlsiT2ZmIl0sIkZlYXR1cmVzIjpbdHJ1ZV0sIllhd1xuY3VzdG9tX3lhd19Dcm91Y2hlZCI6WyJPZmYiXSwiXG5jdXN0b21fcGl0Y2hfb2Zmc2V0X1N0YW5kaW5nIjpbMF0sIlxuY3VzdG9tX2ppdHRlcl9tb2RlX01haW4iOlsiMi1XYXkiXSwiXG5jdXN0b21faml0dGVyX21vZGVfTW92aW5nIjpbIjItV2F5Il0sIkppdHRlciBvZmZzZXRcbmN1c3RvbV9qaXR0ZXJfb2Zmc2V0X1Nsb3cgV2FsayI6WzBdLCJcdTAwMDdiNmI2NjVmZkFjaWRUZWNoIjpbdHJ1ZV0sIllhdyBqaXR0ZXJcbmN1c3RvbV95YXdfaml0dGVyX1Nsb3cgV2FsayI6WyJPZmYiXSwiXG5jdXN0b21feWF3X29mZnNldF9Dcm91Y2hlZCI6WzBdLCJcbmN1c3RvbV9waXRjaF9vZmZzZXRfQ3JvdWNoZWQiOlswXSwiLSBJbiBBaXIiOlsiU3RhdGljIl0sIlBpdGNoXG5jdXN0b21fcGl0Y2hfU2xvdyBXYWxrIjpbIk9mZiJdLCJGcmVlc3RhbmRpbmcgYm9keSB5YXdcbmN1c3RvbV9mcmVlc3RhbmRpbmdfYm9keV95YXdfQ3JvdWNoZWQiOltmYWxzZV0sIkVuYWJsZSBNb3ZlIENyb3VjaGVkIjpbZmFsc2VdfQ==_zenith'
        )
    end):config_ignore()

    function graphics.text(x, y, r, g, b, a, flags, max_width, ...)
        local text = string_alpha_mod(merge {...}, a * alpha_unit)
        renderer.text(x, y, r, g, b, a, flags, max_width, text)
    end

    function graphics.rectangle(x, y, w, h, r, g, b, a, radius)
        if radius ~= nil and radius > 1 then
            local offset = radius * 2

            renderer.rectangle(x + radius, y, w - offset, h, r, g, b, a)

            renderer.rectangle(x, y + radius, radius, h - offset, r, g, b, a)
            renderer.rectangle(x + w, y + radius, -radius, h - offset, r, g, b, a)

            renderer.circle(x + radius, y + radius, r, g, b, a, radius, 180, 0.25)
            renderer.circle(x + radius, y + h - radius, r, g, b, a, radius, 270, 0.25)
            renderer.circle(x + w - radius, y + h - radius, r, g, b, a, radius, 0, 0.25)
            renderer.circle(x + w - radius, y + radius, r, g, b, a, radius, 90, 0.25)

            return
        end

        renderer.rectangle(x, y, w, h, r, g, b, a)
    end

    function graphics.rectangle_outline(x, y, w, h, r, g, b, a, radius, thickness)
        radius = radius or 0
        thickness = thickness or 1

        renderer.rectangle(x + radius, y, w - radius * 2, thickness, r, g, b, a)
        renderer.rectangle(x + radius, y + h - thickness, w - radius * 2, thickness, r, g, b, a)

        renderer.rectangle(x, y + radius, thickness, h - radius * 2, r, g, b, a)
        renderer.rectangle(x + w - thickness, y + radius, thickness, h - radius * 2, r, g, b, a)

        renderer.circle_outline(x + radius, y + radius, r, g, b, a, radius, 180, 0.25, thickness)
        renderer.circle_outline(x + radius, y + h - radius, r, g, b, a, radius, 90, 0.25, thickness)
        renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, a, radius, 0, 0.25, thickness)
        renderer.circle_outline(x + w - radius, y + radius, r, g, b, a, radius, 270, 0.25, thickness)
    end

    function graphics.blur(x, y, w, h)
        -- if true then
        --     return
        -- end

        -- renderer.blur(x, y, w, h)
    end

    function graphics.header(x, y, w, thickness, rounding, r, g, b, a)
        renderer.rectangle(x + rounding, y - thickness, w - (rounding + thickness), thickness, r, g, b, a)

        if rounding ~= 0 then
            -- outer rounding
            local add_rounding = vector(rounding, rounding)
            renderer.circle_outline(x + rounding, y + rounding, r, g, b, a, rounding + thickness, -180, 0.25, thickness)
            renderer.circle_outline(x + w - rounding, y + rounding, r, g, b, a, rounding + thickness, -90, 0.25, thickness)

            -- gradient lines
            local thickness_dv = thickness / 2 - 1
            renderer.gradient(x - thickness, y + rounding, thickness, rounding + 7, r, g, b, a, r, g, b, 0, false)
            renderer.gradient(x + w, y + rounding, thickness, rounding + 7, r, g, b, a, r, g, b, 0, false)
        end
    end

    function graphics.glow(x, y, w, h, r, g, b, a, thickness, radius)
        -- if graphics.low_fps_mitigations:have_key("Glow") then
        -- if true then
        --     return
        -- end

        -- if radius == nil then
        --     return
        -- end

        -- if radius < 1 then
        --     radius = 1
        -- end

        -- thickness = thickness / 2

        -- local t = 1.0
        -- local step = 1 / (thickness - 1)

        -- local offset = radius * 2

        -- renderer.gradient(x + radius, y, w - offset, -thickness, r, g, b, a, r, g, b, 0, false)
        -- renderer.gradient(x + radius, y + h, w - offset, thickness, r, g, b, a, r, g, b, 0, false)
        -- renderer.gradient(x, y + radius, -thickness, h - offset, r, g, b, a, r, g, b, 0, true)
        -- renderer.gradient(x + w, y + radius, thickness, h - offset, r, g, b, a, r, g, b, 0, true)

        -- for i = 1, thickness do
        --     local opacity = a * t

        --     renderer.circle_outline(x + w - radius, y + h - radius, r, g, b, opacity, radius + i, 0, 0.25, 1)
        --     renderer.circle_outline(x + radius, y + h - radius, r, g, b, opacity, radius + i, 90, 0.25, 1)
        --     renderer.circle_outline(x + radius, y + radius, r, g, b, opacity, radius + i, 180, 0.25, 1)
        --     renderer.circle_outline(x + w - radius, y + radius, r, g, b, opacity, radius + i, 270, 0.25, 1)

        --     t = t - step
        -- end
    end
end

do
    local function u8(s)
        return string.gsub(s, "[\128-\191]", "")
    end

    function decorations.wave(s, clock, r1, g1, b1, a1, r2, g2, b2, a2)
        local buffer = { }

        local len = #u8(s)
        local div = 1 / (len - 1)

        local add_r = r2 - r1
        local add_g = g2 - g1
        local add_b = b2 - b1
        local add_a = a2 - a1

        for char in string.gmatch(s, ".[\128-\191]*") do
            local t = utils.breathe(clock)

            local r = r1 + add_r * t
            local g = g1 + add_g * t
            local b = b1 + add_b * t
            local a = a1 + add_a * t

            buffer[#buffer + 1] = "\a"
            buffer[#buffer + 1] = utils.to_hex(r, g, b, a)
            buffer[#buffer + 1] = char

            clock = clock + div
        end

        return merge(buffer)
    end
end

do
    local LAG_COMPENSATION_TELEPORTED_DISTANCE_SQR = 64 * 64

    local data = {
        old_origin = vector(),
        old_simtime = 0.0,

        shift = false,
        breaking_lc = false,

        defensive = {
            begin = 0,
            duration = 0
        },

        lagcompensation = {
            distance = 0.0,
            teleport = false
        },

        defensive_tk = 0
    }

    local function update_tickbase(me)
        local tickcount = globals.tickcount()
        local m_nTickBase = entity.get_prop(me, "m_nTickBase")

        data.shift = tickcount > m_nTickBase
    end

    local function update_defensive(tick)
        data.breaking_lc = true

        data.defensive.begin = globals.tickcount()
        data.defensive.duration = tick
    end

    local function update_teleport(old_origin, new_origin)
        local delta = new_origin - old_origin
        local distance = delta:lengthsqr()

        local is_teleport = distance > LAG_COMPENSATION_TELEPORTED_DISTANCE_SQR

        data.breaking_lc = is_teleport

        data.lagcompensation.distance = distance
        data.lagcompensation.teleport = is_teleport
    end

    local function update_lagcompensation(me)
        local old_origin = data.old_origin
        local old_simtime = data.old_simtime

        local origin = vector(entity.get_origin(me))
        local simtime = toticks(entity.get_prop(me, "m_flSimulationTime"))

        if old_simtime ~= nil then
            local delta = simtime - old_simtime

            if delta < 0 or delta > 0 and delta <= 64 then
                local tick = delta - 1

                update_teleport(old_origin, origin)

                if delta < 0 then
                    update_defensive(math.abs(tick))
                end
            end
        end

        data.old_origin = origin
        data.old_simtime = simtime
    end

    function exploit.get()
        return data
    end

    function exploit.setup_command(cmd)
        local me = entity.get_local_player()
        update_tickbase(me)
    end

    function exploit.net_update()
        local me = entity.get_local_player()

        if me == nil then
            return
        end

        update_lagcompensation(me)
    end

    local native_GetClientEntity = vtable_bind('client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)')

    function exploit.handle_defensive()
        local lp = entity.get_local_player()

        if lp == nil or not entity.is_alive(lp) then
            return
        end

        local Entity = native_GetClientEntity(lp)
        local m_flOldSimulationTime = ffi.cast("float*", ffi.cast("uintptr_t", Entity) + 0x26C)[0]
        local m_flSimulationTime = entity.get_prop(lp, "m_flSimulationTime")

        local delta = m_flOldSimulationTime - m_flSimulationTime

        if delta > 0 then
            data.defensive_tk = globals.tickcount() + toticks(delta - client.real_latency())
            return
        end
    end
end

do
    local MOVING_LIMIT = 1.1 * 3.3
    local DUCK_PEEK_LIMIT = 0.79

    local pre_flags = 0
    local post_flags = 0

    local function get_body_yaw(animstate)
        local body_yaw = animstate.eye_angles_y - animstate.goal_feet_yaw
        body_yaw = utils.normalize_yaw(body_yaw)

        return body_yaw
    end

    localplayer.flags = 0
    localplayer.packets = 0
    localplayer.choking = 1
    localplayer.choking_bool = false

    localplayer.body_yaw = 0
    localplayer.duck_amount = 0

    localplayer.movetype = 0
    localplayer.velocity = 0

    localplayer.is_onground = false
    localplayer.is_crouched = false

    localplayer.is_moving = false
    localplayer.is_landing = false
    localplayer.is_airborne = false

    function localplayer.pre_predict_command(e)
        local me = entity.get_local_player()
        pre_flags = entity.get_prop(me, "m_fFlags")
    end

    function localplayer.predict_command(e)
        local me = entity.get_local_player()
        post_flags = entity.get_prop(me, "m_fFlags")
    end

    function localplayer.net_update()
        local me = entity.get_local_player()
        if me == nil then return end

        local my_data = c_entity(me)
        if my_data == nil then return end

        local animstate = c_entity.get_anim_state(my_data)
        if animstate == nil then return end

        local chokedcommands = globals.chokedcommands()

        local m_fFlags = entity.get_prop(me, "m_fFlags")
        local m_movetype = entity.get_prop(me, "m_movetype")
        local m_flDuckAmount = entity.get_prop(me, "m_flDuckAmount")

        localplayer.flags = m_fFlags
        localplayer.movetype = m_movetype
        localplayer.velocity = animstate.m_velocity

        if chokedcommands == 0 then
            localplayer.packets = localplayer.packets + 1
            localplayer.choking = localplayer.choking * -1
            localplayer.choking_bool = not localplayer.choking_bool

            localplayer.body_yaw = get_body_yaw(animstate)
            localplayer.duck_amount = m_flDuckAmount
        end

        localplayer.is_onground = animstate.on_ground
        localplayer.is_crouched = localplayer.duck_amount > DUCK_PEEK_LIMIT

        localplayer.is_moving = localplayer.velocity > MOVING_LIMIT
        localplayer.is_landing = animstate.hit_in_ground_animation
        localplayer.is_airborne = bit.band(pre_flags, post_flags, 1) == 0
    end
end

do
    local list = { }

    local function add(state)
        list[#list + 1] = state
    end

    local function update_onground()
        if localplayer.is_moving then
            add "Moving"

            if localplayer.is_crouched then
                return
            end

            if localplayer.is_airborne then
                return
            end

            if software.is_slow_motion() then
                add "Slow Walk"
            end

            return
        end

        add "Standing"
    end

    local function update_crouched()
        if not localplayer.is_crouched then
            return
        end

        add "Crouched"

        if localplayer.is_moving then
            add "Move Crouched"
        end
    end

    local function update_airborne()
        if not localplayer.is_airborne then
            return
        end

        add "Air"

        if localplayer.is_crouched then
            add "Air Crouched"
        end
    end

    local function update_exploit()
        if exploit.get().shift or (software.is_double_tap() or software.is_on_shot_antiaim()) then
            return
        end

        add "Fake Lag"
    end

    function statement.get()
        return list
    end

    function statement.add(state)
        add(state)
    end

    function statement.setup_command()
        table.clear(list)

        update_onground()
        update_crouched()
        update_airborne()
        update_exploit()
    end
end

do
    local ctx = { }

    local zenithyaw_ways = {
    ["2-Way"] = { -0.5, 0.5 },
    ["3-Way"] = { -0.5, 0, 0.5 },
    ["5-Way"] = { -0.75, 1, 0, 0.4, -0.25 },
    ["7-Way"] = { -1, -0.57, -0.28, 0, 0.28, 0.57, 1 },
    ["Chaos"] = { -1, -0.72, -0.44, -0.16, 0.16, 0.44, 0.72, 1 }
}
local _chaos_jitter_seed = 0

    local function calculate_jitter_way(n, offset)
        local fmod = localplayer.packets % n
        local center = n / 2

        if n % 2 ~= 0 then
            center = math.floor(center)
        elseif fmod >= center then
            fmod = fmod + 1
        end

        local delta = fmod - center
        local weight = delta / center

        if weight ~= weight or weight == 0 then
            return 0
        end

        return offset * weight
    end

    local function get_statement()
        if not exploit.get().shift and not (software.is_double_tap() or software.is_on_shot_antiaim()) then
            return 'Fake Lag'
        end

        if localplayer.is_airborne then
            return localplayer.is_crouched and "Air Crouched" or 'Air'
        end

        if localplayer.is_crouched then
            return localplayer.is_moving and "Move Crouched" or 'Crouched'
        end

        if localplayer.is_moving then
            return software.is_slow_motion() and 'Slow Walk' or "Moving"
        end

        return 'Standing'
    end

    local function modify_yaw()
        if ctx.yaw == "180 LR" then
            ctx.yaw = "180"

            if ctx.yaw_left == nil then return end
            if ctx.yaw_right == nil then return end

            if ctx.yaw_offset == nil then
                ctx.yaw_offset = 0
            end

            local inverted = localplayer.body_yaw < 0

            if ctx.yaw_180lr_mode == "Switch delay" then
                local delay = ctx.yaw_delay
                local target = delay * 2

                inverted = (localplayer.packets % target) >= delay

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = inverted and
                    1 or -1
            end

            local yaw_add = inverted and
                ctx.yaw_right or ctx.yaw_left

            ctx.yaw_offset = ctx.yaw_offset + yaw_add
            return
        end

        -- velocity jitter bias: lean jitter toward strafe direction
        -- makes it harder to predict which way we'll be on the next shot
        if ctx.yaw_jitter ~= nil and ctx.yaw_jitter ~= 'Off' then
            local lp = entity.get_local_player()
            if lp then
                local vx = entity.get_prop(lp, 'm_vecVelocity[0]') or 0
                local vy = entity.get_prop(lp, 'm_vecVelocity[1]') or 0
                local spd = math.sqrt(vx*vx + vy*vy)
                if spd > 20 then
                    -- get strafe direction relative to view
                    local eye_yaw = localplayer.angles and localplayer.angles.y or 0
                    local vel_yaw = math.deg(math.atan2(vy, vx))
                    local rel = ((vel_yaw - eye_yaw + 180) % 360) - 180
                    -- bias: add small push toward strafe side
                    local bias = rel > 0 and math.min(spd * 0.04, 8) or -math.min(spd * 0.04, 8)
                    ctx.yaw_offset = (ctx.yaw_offset or 0) + bias
                end
            end
        end
    end

        -- velocity jitter bias: lean jitter toward strafe direction
        if ctx.yaw_jitter ~= nil and ctx.yaw_jitter ~= 'Off' then
            local lp = entity.get_local_player()
            if lp then
                local vx = entity.get_prop(lp, 'm_vecVelocity[0]') or 0
                local vy = entity.get_prop(lp, 'm_vecVelocity[1]') or 0
                local spd = math.sqrt(vx*vx + vy*vy)
                if spd > 20 then
                    local eye_yaw = localplayer.angles and localplayer.angles.y or 0
                    local vel_yaw = math.deg(math.atan2(vy, vx))
                    local rel = ((vel_yaw - eye_yaw + 180) % 360) - 180
                    local bias = rel > 0 and math.min(spd * 0.04, 8) or -math.min(spd * 0.04, 8)
                    ctx.yaw_offset = (ctx.yaw_offset or 0) + bias
                end
            end
        end

    local safe_head_presets = {
        [1] = {
            [3] = {
                -- base = "At Target" !!!
                offset = 15,

                inverter = false,

                left_limit = 24,
                right_limit = 24
            },

            [2] = {
                offset = 15,

                inverter = false,

                left_limit = 24,
                right_limit = 24
            }
        },
    }

    local randomized
    local val = 180
    local function modify_jitter()
        -- micro-jitter: add tiny noise every tick to prevent stable tracking
        -- suppressed during auto-peek so the shot goes exactly where aimed
        if ctx.yaw_offset ~= nil and ctx.yaw_jitter ~= 'Off'
        and not ctx._suppress_micro_jitter then
            ctx.yaw_offset = ctx.yaw_offset + client.random_float(-2.5, 2.5)
        end

        -- desync shift: flip jitter_offset sign every 18-26 ticks
        -- makes the desync amount itself cycle, not just the direction
        -- resolvers that pattern-match offset magnitude will mispredict
        if ctx.yaw_jitter ~= nil and ctx.yaw_jitter ~= 'Off'
        and ctx.jitter_offset ~= nil then
            local shift_cycle = 22
            local phase = globals.tickcount() % shift_cycle
            if phase < shift_cycle * 0.45 then
                -- normal phase: use jitter_offset as-is
            elseif phase < shift_cycle * 0.55 then
                -- transition zone: briefly reduce to confuse pattern analysis
                ctx.jitter_offset = ctx.jitter_offset * 0.35
            else
                -- shifted phase: mirror the offset
                ctx.jitter_offset = -ctx.jitter_offset
            end
        end

        -- micro-jitter: add tiny noise every tick to prevent stable tracking
        -- suppressed during auto-peek so the shot goes exactly where aimed
        if ctx.yaw_offset ~= nil and ctx.yaw_jitter ~= 'Off'
        and not ctx._suppress_micro_jitter then
            ctx.yaw_offset = ctx.yaw_offset + client.random_float(-2.5, 2.5)
        end

        -- desync shift: flip jitter_offset sign every 22 ticks
        -- makes the desync amount itself cycle, not just the direction
        -- resolvers that pattern-match offset magnitude will mispredict
        if ctx.yaw_jitter ~= nil and ctx.yaw_jitter ~= 'Off'
        and ctx.jitter_offset ~= nil then
            local shift_cycle = 22
            local phase = globals.tickcount() % shift_cycle
            if phase < shift_cycle * 0.45 then
                -- normal phase: use jitter_offset as-is
            elseif phase < shift_cycle * 0.55 then
                ctx.jitter_offset = ctx.jitter_offset * 0.35
            else
                ctx.jitter_offset = -ctx.jitter_offset
            end
        end

        if ctx.jitter_randomization ~= nil then
            if localplayer.packets % 2 == 0 or randomized == nil then
                randomized = client.random_int(0, (ctx.jitter_offset > 0 and 1 or -1) * ctx.jitter_randomization)
            end

            ctx.jitter_offset = utils.normalize_yaw(ctx.jitter_offset + randomized)
        end

        if ctx.body_yaw == 'Randomize Jitter' then
            ctx.body_yaw = 'Static'
            if localplayer.choking_bool then
                local rand = client.random_int(0, 1)
                val = rand == 1 and 180 or -180
            end
            ctx.body_yaw_offset = val
        elseif ctx.body_yaw == 'Ghost' then
            -- Ghost: body yaw goes OPPOSITE to the current yaw offset
            -- makes body-based resolvers predict the wrong real side
            ctx.body_yaw = 'Static'
            local cur_off = ctx.yaw_offset or 0
            -- if we're offset right, body yaw says left and vice versa
            ctx.body_yaw_offset = cur_off > 0 and -180 or 180
        end

        if ctx.yaw_jitter == "Zenith" then
            local yaw = ctx.yaw_offset
            local state = get_statement()
            local delay_data = delay_data_all[state]

            delay_data.ticks = delay_data.ticks + 1

            local zenith_mode  = ctx.jitter_mode
            local zenith_cycle = ctx.zenith_cycle
            local zenith_delay = ctx.zenith_delay

            local ways = zenithyaw_ways[zenith_mode]
            local way
            if zenith_mode == 'Chaos' then
                -- Chaos: seed mixes tick + packets + body yaw for non-repeating pattern
                _chaos_jitter_seed = (_chaos_jitter_seed
                    + globals.tickcount() * 7
                    + localplayer.packets * 13
                    + math.floor(math.abs(localplayer.body_yaw or 0))) % #ways
                way = ways[_chaos_jitter_seed + 1]
            else
                way = ways[(localplayer.packets % #ways) + 1]
            end

            -- god ( qhose ) forgive me for the piece of code below

            local byaw = localplayer.body_yaw

            if zenith_cycle ~= 4 and not delay_data.is_delay and delay_data.ticks % zenith_cycle == 0 then
                delay_data.is_delay = true
            end

            local ignore_yaw = false
            if delay_data.is_delay then
                if delay_data.current < zenith_delay then
                    delay_data.current = delay_data.current + 1

                    if ctx.zenith_safe then
                        local lp = entity.get_local_player()
                        local current_preset = safe_head_presets[1]
                        local preset_for_team = current_preset[entity.get_prop(lp, 'm_iTeamNum')]

                        yaw = 0 --preset_for_team.offset
                        ctx.body_yaw = 'Static'
                        ctx.body_yaw_offset = 0

                        ignore_yaw = true
                    end

                   yaw = yaw
                else
                    delay_data.is_delay = false
                    delay_data.ticks = 0
                    delay_data.current = 0
                    delay_data.previous_angle = 0
                end
            else
                local angle = 0
                if zenith_mode == "2-Way" and (ctx.body_yaw == "Jitter" or ctx.body_yaw == 'Randomize Jitter') then
                    angle = utils.normalize_yaw(yaw + (byaw < 0 and ctx.jitter_offset / 2 or ctx.jitter_offset * -1 / 2))
                else
                    angle = utils.normalize_yaw(yaw + ctx.jitter_offset * way)
                end

                delay_data.previous_angle = angle
            end

            if not ignore_yaw then
                yaw = delay_data.previous_angle
            end

            ctx.yaw_offset = yaw
            ctx.yaw_jitter = 'Off'
        end

    end

    local function shutdown()
        override.unset(software.aa.angles.enabled)
        override.unset(software.aa.angles.pitch[1])
        override.unset(software.aa.angles.pitch[2])

        override.unset(software.aa.angles.yaw_base)

        override.unset(software.aa.angles.yaw[1])
        override.unset(software.aa.angles.yaw[2])

        override.unset(software.aa.angles.yaw_jitter[1])
        override.unset(software.aa.angles.yaw_jitter[2])

        override.unset(software.aa.angles.body_yaw[1])
        override.unset(software.aa.angles.body_yaw[2])

        override.unset(software.aa.angles.freestanding_body_yaw)

        override.unset(software.aa.angles.edge_yaw)

        override.unset(software.aa.angles.freestanding[1])
        override.unset(software.aa.angles.freestanding[2])

        override.unset(software.aa.angles.roll)
    end

    local function setup()
        yaw_direction.is_freestanding = false
        if ctx.enabled ~= nil then
            override.set(software.aa.angles.enabled, ctx.enabled)
        else
            override.set(software.aa.angles.enabled, true)
        end

        if ctx.pitch ~= nil then
            override.set(software.aa.angles.pitch[1], ctx.pitch)
        end

        if ctx.yaw_base ~= nil then
            override.set(software.aa.angles.yaw_base, ctx.yaw_base)
        end

        if ctx.yaw ~= nil then
            override.set(software.aa.angles.yaw[1], ctx.yaw)
        end

        if ctx.body_yaw ~= nil then
            override.set(software.aa.angles.body_yaw[1], ctx.body_yaw)
        end

        if ctx.edge_yaw ~= nil then
            override.set(software.aa.angles.edge_yaw, ctx.edge_yaw)
        end

        if ctx.freestanding ~= nil then
            yaw_direction.is_freestanding = ctx.freestanding
            override.set(software.aa.angles.freestanding[1], ctx.freestanding)
            override.set(software.aa.angles.freestanding[2], ctx.freestanding and
                "Always on" or "On hotkey")
        end

        if ctx.roll ~= nil then
            override.set(software.aa.angles.roll, ctx.roll)
        end

        local pitch_value = ui.get(software.aa.angles.pitch[1])
        local yaw_value = ui.get(software.aa.angles.yaw[1])
        local body_yaw_value = ui.get(software.aa.angles.body_yaw[1])

        if pitch_value == "Custom" then
            if ctx.pitch_offset ~= nil then
                override.set(software.aa.angles.pitch[2], utils.clamp(ctx.pitch_offset, -89, 89))
            end
        end

        if yaw_value ~= "Off" then
            if ctx.yaw_offset ~= nil then
                override.set(software.aa.angles.yaw[2], utils.normalize_yaw(ctx.yaw_offset))
            end

            if ctx.yaw_jitter ~= nil then
                override.set(software.aa.angles.yaw_jitter[1], ctx.yaw_jitter)
            end

            local yaw_jitter_val = ui.get(software.aa.angles.yaw_jitter[1])

            if yaw_jitter_val ~= "Off" then
                if ctx.jitter_offset ~= nil then
                    override.set(software.aa.angles.yaw_jitter[2], utils.normalize_yaw(ctx.jitter_offset))
                end
            end
        end

        if body_yaw_value ~= "Off" then
            if body_yaw_value ~= "Opposite" then
                if ctx.body_yaw_offset ~= nil then
                    override.set(software.aa.angles.body_yaw[2], utils.normalize_yaw(ctx.body_yaw_offset))
                end
            end

            if ctx.freestanding_body_yaw ~= nil then
                override.set(software.aa.angles.freestanding_body_yaw, ctx.freestanding_body_yaw)
            end
        end
    end

    local function think(e)
        -- break_lc.think(e)
    end

    local function update(e)
        angles.update(ctx)
        yaw_direction.update(ctx)
        auto_peek.perform(ctx)
        manual_direction.update(ctx)

        safe_head.update(e, ctx)
        defensive.handle(e, ctx)
        avoid_backstab.update(ctx)
        disablers.update(e, ctx)
        fs_disablers.update(ctx)
    end

    function antiaim.shutdown()
        shutdown()
    end

    function antiaim.setup_command(e)

        table.clear(ctx)
        shutdown()

        think(e)
        update(e)

        modify_yaw()
        modify_jitter()

        setup()
    end
end

do
    local _last_hurt_tick = 0
    local _flip_body_next = false

    client.set_event_callback('player_hurt', function(e)
        local lp = entity.get_local_player()
        if not lp then return end
        local lp_uid = entity.get_prop(lp, 'm_iUserId')
        if e.userid == lp_uid then
            -- WE got hurt: schedule a body yaw flip for next 4 ticks
            -- breaks enemy resolver side-confirmation
            if angles and angles.type and angles.type:get() ~= 'Off' then
                _flip_body_next = true
                _last_hurt_tick = globals.tickcount()
            end
        end
    end)

    client.set_event_callback('setup_command', function()
        if not _flip_body_next then return end
        if globals.tickcount() - _last_hurt_tick > 4 then
            _flip_body_next = false
            return
        end
        -- flip body yaw for these ticks so their resolver loses confidence
        local ok, cur = pcall(ui.get, software.aa.angles.body_yaw[1])
        if ok and cur and cur ~= 'Off' then
            local ok2, cur_off = pcall(ui.get, software.aa.angles.body_yaw[2])
            if ok2 and cur_off then
                pcall(override.set, software.aa.angles.body_yaw[2],
                    cur_off > 0 and -180 or 180)
            end
        end
    end)
end

do
    -- Lag Peak: when you fire a shot, spike the fake lag to maximum for 1 tick
    -- The shot arrives during a different lagcomp window than the enemy expects,
    -- making it harder for their aimbot to compensate for your real position.
    -- Works best combined with Double Tap.

    local lp_enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Lag Peak")
        :record("aa", "lagpeak::enabled"):save()

    local lp_amount  = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
        merge { "- Peak Amount", "\n", "lagpeak::amount" }, 1, 14, 14, true, "t")
        :record("aa", "lagpeak::amount"):save()

    local lp_recover = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
        merge { "- Recover Ticks", "\n", "lagpeak::recover" }, 1, 6, 2, true, "t")
        :record("aa", "lagpeak::recover"):save()

    local lp_on_dt   = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "- Only on DT")
        :record("aa", "lagpeak::on_dt"):save()

    local lp_on_miss = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Only on Miss")
        :record("aa", "lagpeak::on_miss"):save()

    -- update show function to include on_miss

    _G.__lagpeak_show = function()
        _safe_display(lp_enabled)
        if lp_enabled:get() then
            _safe_display(lp_amount)
            _safe_display(lp_recover)
            _safe_display(lp_on_dt)
            _safe_display(lp_on_miss)
        end
    end

    local _lp_fire_tick  = -999
    local _lp_orig_limit = nil
    local _lp_orig_var   = nil
    local _lp_spiking    = false
    local _lp_spike_end  = -1

    -- trigger lag peak on miss too
    client.set_event_callback("aim_miss", function(e)
        if not lp_enabled:get() then return end
        if not (lp_on_miss and lp_on_miss:get()) then return end
        local fl = software and software.aa and software.aa.fakelag
        if not fl then return end
        pcall(function()
            _lp_orig_limit = ui.get(fl.limit)
            _lp_orig_var   = ui.get(fl.variance)
        end)
        pcall(ui.set, fl.limit,    lp_amount:get())
        pcall(ui.set, fl.variance, 0)
        _lp_spiking   = true
        _lp_fire_tick = globals.tickcount()
        _lp_spike_end = _lp_fire_tick + lp_recover:get()
    end)

    client.set_event_callback("aim_fire", function(e)
        if not lp_enabled:get() then return end
        if lp_on_dt:get() and not software.is_double_tap() then return end
        local fl = software and software.aa and software.aa.fakelag
        if not fl then return end
        -- save current limit before spike
        pcall(function()
            _lp_orig_limit = ui.get(fl.limit)
            _lp_orig_var   = ui.get(fl.variance)
        end)
        -- spike: set fake lag to peak amount
        pcall(ui.set, fl.limit,    lp_amount:get())
        pcall(ui.set, fl.variance, 0)  -- no variance during spike
        _lp_spiking   = true
        _lp_fire_tick = globals.tickcount()
        _lp_spike_end = _lp_fire_tick + lp_recover:get()
    end)

    client.set_event_callback("setup_command", function()
        if not lp_enabled:get() then return end
        if not _lp_spiking then return end
        local fl = software and software.aa and software.aa.fakelag
        if not fl then return end
        -- restore original limit after recover ticks
        if globals.tickcount() >= _lp_spike_end then
            if _lp_orig_limit ~= nil then
                pcall(ui.set, fl.limit,    _lp_orig_limit)
                pcall(ui.set, fl.variance, _lp_orig_var or 0)
            end
            _lp_spiking   = false
            _lp_orig_limit = nil
            _lp_orig_var   = nil
        end
    end)
end

do
    settings.tweaks_enable = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Features")
    : record("settings", "settings::tweaks_enable")
    : save()

    settings.tweaks = menu.new_item(ui.new_multiselect, 'AA', 'Anti-aimbot angles', merge { "- Functions", "\n", "settings::tweaks" }, { 'Log Aimbot Shots', 'Damage Marker' })
    : record("settings", "settings::tweaks")
    : save()
end

do
    widgets.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Widgets")
    : record("visuals", "widgets::enabled")
    : save()

    widgets.color_picker = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", merge { "- Color", "\n", "widgets::color_picker" }, 113, 152, 255, 255)
    : record("visuals", "keybinds::color_picker")
    : save()

    widgets.items = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- Items", "\n", "widgets::items" }, { "Watermark", "Keybinds", "Velocity Warning", "Crosshair Indicator", "Damage Indicator", "On-Screen Logs", 'Hit Rate' })
    : record("visuals", "widgets::items")
    : save()

    widgets.display = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- Display", "\n", "widgets::display" }, { "Username", "Latency", "Time", "FPS", "Server frametime" })
    : record("visuals", "widgets::display")
    : save()

    widgets.custom_name = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Custom Name", { "Username", "Latency", "Time", "FPS", "Server frametime" })
    : record("visuals", "widgets::custom_name")
    : save()

    widgets.custom_name_value = menu.new_item(ui.new_textbox, "AA", "Anti-aimbot angles", "Nickname")
    : record("visuals", "widgets::custom_name_value")
    : save()
end

do
    aa_tweaks.enable = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Tweaks")
    : record("settings", "aa_tweaks::enable")
    : save()

    aa_tweaks.items = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "- Options", { 'Disable on Warmup', 'Disable While No Enemies', 'Avoid Backstab', 'Fast Ladder', 'Edge Yaw on FD', "Auto Peek Improvements" })
    : record("aa", "aa_tweaks::items")
    : save()

    client.set_event_callback('setup_command', function (cmd)
        if not aa_tweaks.enable:get() then
            return
        end

        if not aa_tweaks.items:have_key('Fast Ladder') then
            return
        end

        local lp = entity.get_local_player()
        if lp == nil then
            return
        end

        if entity.get_prop(lp, 'm_MoveType') ~= 9 then
            return
        end

        local weapon = entity.get_player_weapon(lp)
        if weapon == nil then
            return
        end

        local throw_time = entity.get_prop(weapon, 'm_fThrowTime')

        if throw_time ~= nil and throw_time ~= 0 then
            return
        end

        if cmd.forwardmove > 0 then
            if cmd.pitch < 45 then
                cmd.pitch = 89
                cmd.in_moveright = 1
                cmd.in_moveleft = 0
                cmd.in_forward = 0
                cmd.in_back = 1

                if cmd.sidemove == 0 then
                    cmd.yaw = cmd.yaw + 90
                end

                if cmd.sidemove < 0 then
                    cmd.yaw = cmd.yaw + 150
                end

                if cmd.sidemove > 0 then
                    cmd.yaw = cmd.yaw + 30
                end
            end
        elseif cmd.forwardmove < 0 then
            cmd.pitch = 89
            cmd.in_moveleft = 1
            cmd.in_moveright = 0
            cmd.in_forward = 1
            cmd.in_back = 0

            if cmd.sidemove == 0 then
                cmd.yaw = cmd.yaw + 90
            end

            if cmd.sidemove > 0 then
                cmd.yaw = cmd.yaw + 150
            end

            if cmd.sidemove < 0 then
                cmd.yaw = cmd.yaw + 30
            end
        end
    end)
end

do
    local function get_statement()
        if localplayer.is_airborne then
            return "Air";
        end

        if localplayer.is_crouched then
            return "Crouched";
        end

        if localplayer.is_moving then
            if software.is_slow_motion() then
                return "Slow Walk";
            end

            return "Moving";
        end

        return "Standing"
    end

    defensive.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Defensive AA")
    : record("aa", "defensive::enabled")
    : save()

    defensive.mode = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- Mode", "\n", "defensive::mode" }, { "On Shot Anti Aim", "Double Tap" })
    : record("aa", "defensive::mode")
    : save()

    defensive.state = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- State", "\n", "defensive::state" }, { "Air", "Standing", "Moving", "Slow Walk", "Crouched", "On Peek" })
    : record("aa", "defensive::state")
    : save()

    defensive.pitch = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "- Pitch", "\n", "defensive::pitch" }, { "Default", "Zero", "Up", "Up Switch", "Down Switch", "Random", "Jitter Pitch", "Snap Pitch", "Fake Up" })
    : record("aa", "defensive::pitch")
    : save()

    defensive.yaw = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "- Yaw", "\n", "defensive::yaw" }, { "Default", "Sideways", "Forward", "Spinbot", "3-Way", "5-Way", "7-Way", "Chaos", "Random", "Snap", "Snap Jitter" })
    : record("aa", "defensive::yaw")
    : save()

    defensive.snap_range = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
        merge { "- Snap Range", "\n", "defensive::snap_range" }, 45, 180, 120, true, "deg", 1)
    : record("aa", "defensive::snap_range")
    : save()

    defensive.snap_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
        merge { "- Snap Offset", "\n", "defensive::snap_offset" }, -180, 180, 90, true, "deg", 1)
    : record("aa", "defensive::snap_offset")
    : save()

    local modes = {
        ['Double Tap'] = software.is_double_tap,
        ['On Shot Anti Aim'] = software.is_on_shot_antiaim
    }

    local manual_bebra = {
        [0] = 90,
        [1] = -90,
        [2] = 0
    }

    local defensive_3_way = { 90, 180, -90, 180, 90 }
    local defensive_5_way = { 90, 135, 180, 225, 270 }
    local defensive_7_way = { 0, 51, 102, 154, 205, 257, 308 }
    local _chaos_seed      = 0
    local _snap_last_tick   = -999
    local _snap_pitch_val   = 0
    local _snap_pitch_tick  = -999
    local _snap_last_offset = 0
    local _snap_jitter_side = 1

    function defensive.handle(cmd, ctx)
        if not defensive.enabled:get() then
            return
        end

        local lp = entity.get_local_player()
        if lp == nil then
            return
        end

        local work_on_mode = false
        for idx, mode in next, defensive.mode:get() do
            if modes[ mode ] and modes[ mode ]() then
                work_on_mode = true
                break
            end
        end

        local double_tap = exploit.get()
        if not work_on_mode or not double_tap.shift then
            return
        end

        local lp_state = get_statement()

        local should_work = false
        local on_peek = false
        for _, condition in next, defensive.state:get() do
            if condition == 'On Peek' then
                should_work = true
                on_peek = true
                break
            else
                if condition == lp_state then
                    should_work = true
                    break
                end
            end
        end

        if not should_work then
            return
        end

        local weapon = entity.get_player_weapon(lp)
        if weapon == nil then
            return
        end

        local wpn_info = csgo_weapons(weapon)
        if wpn_info == nil then
            return
        end

        if wpn_info.is_revolver then
            return
        end

        if not on_peek then
            cmd.force_defensive = true
        end

        local freestanding = yaw_direction.is_freestanding
        local manual_yaw = manual_direction.get()
        local should_flick = lp_state == 'Crouched' and manual_direction.options:have_key('Duck Exploit')
        local should_ignore = freestanding or (manual_yaw ~= nil and not should_flick)

        if should_flick then
            ctx.body_yaw = 'Static'
            ctx.body_yaw_offset = 180
        end

        local pitch_value, pitch_mode = 0, 'Default'
        do
            local val = defensive.pitch:get()
            if val == 'Zero' then
                pitch_value, pitch_mode = 0, 'Custom'
            elseif val == 'Up' then
                pitch_value, pitch_mode = 0, 'Up'
            elseif val == 'Up Switch' then
                pitch_value, pitch_mode = client.random_float(45, 60) * -1, 'Custom'
            elseif val == 'Down Switch' then
                pitch_value, pitch_mode = client.random_float(45, 60), 'Custom'
            elseif val == 'Random' then
                pitch_value, pitch_mode = client.random_float(-89, 89), 'Custom'
            elseif val == 'Jitter Pitch' then
                -- alternates sharply every shot tick for a stuttering pitch
                local tick = globals.tickcount()
                pitch_value = (tick % 2 == 0) and client.random_float(-75, -55) or client.random_float(55, 75)
                pitch_mode  = 'Custom'
            elseif val == 'Snap Pitch' then
                -- picks a completely new random extreme pitch on each defensive tick
                -- and locks it for that choke window - makes head snap to unexpected height
                local tc = globals.tickcount()
                if tc ~= _snap_pitch_tick then
                    -- snap to either far up or far down, randomly chosen each tick
                    -- this makes it impossible to predict which height to aim at
                    local extremes = { -89, -75, -60, 60, 75, 89 }
                    _snap_pitch_val  = extremes[math.random(1, #extremes)]
                    _snap_pitch_tick = tc
                end
                pitch_value = _snap_pitch_val
                pitch_mode  = 'Custom'
            elseif val == 'Fake Up' then
                -- pitch slightly up (not full 89) to move head out of easy shot placement
                -- without being so extreme it looks obvious
                -- combines well with Snap yaw since the head moves both axes
                pitch_value = client.random_float(-58, -42)
                pitch_mode  = 'Custom'
            end

            if manual_yaw ~= nil and should_flick then
                pitch_value, pitch_mode = client.random_float(-5, 10), 'Custom'
            end
        end

        local yaw_value, yaw_mode = 0, '180'
        do
            local val = defensive.yaw:get()
            if val == 'Sideways' then
                yaw_value = localplayer.choking * 90 + client.random_float(-30, 30)
            elseif val == 'Forward' then
                yaw_value = localplayer.choking * 180 + client.random_float(-30, 30)
            elseif val == 'Spinbot' then
                yaw_value = -180 + (globals.tickcount() % 9) * 40 + client.random_float(-30, 30)
            elseif val == '3-Way' then
                yaw_value = defensive_3_way[localplayer.packets % 5 + 1] + client.random_float(-15, 15)
            elseif val == '5-Way' then
                yaw_value = defensive_5_way[localplayer.packets % 5 + 1] + client.random_float(-15, 15)
            elseif val == '7-Way' then
                yaw_value = defensive_7_way[localplayer.packets % 7 + 1] + client.random_float(-20, 20)
            elseif val == 'Chaos' then
                -- pseudo-random using tick + packet count so it changes every choked packet
                _chaos_seed = (_chaos_seed + globals.tickcount() * 1337 + localplayer.packets * 73) % 360
                yaw_value   = utils.normalize(_chaos_seed - 180, -180, 180)
            elseif val == 'Random' then
                yaw_value = utils.normalize(math.random(-180, 180), -180, 180)
            elseif val == 'Snap' then
                local tc = globals.tickcount()
                if tc ~= _snap_last_tick then
                    local range  = defensive.snap_range:get()
                    local offset = defensive.snap_offset:get()
                    local snap_dir = (localplayer.packets % 2 == 0) and 1 or -1
                    _snap_last_offset = utils.normalize(
                        offset + snap_dir * (range * 0.5 + client.random_float(0, range * 0.5)),
                        -180, 180)
                    _snap_last_tick = tc
                end
                yaw_value = _snap_last_offset
            elseif val == 'Snap Jitter' then
                local tc = globals.tickcount()
                local range  = defensive.snap_range:get()
                local offset = defensive.snap_offset:get()
                if tc ~= _snap_last_tick then
                    _snap_jitter_side = (_snap_jitter_side == 1) and -1 or 1
                    _snap_last_tick = tc
                end
                local flip = (localplayer.packets % 2 == 0) and 1 or -1
                yaw_value = utils.normalize(
                    offset * _snap_jitter_side * flip + client.random_float(-15, 15),
                    -180, 180)
            end

            if manual_yaw ~= nil and should_flick then
                yaw_value = manual_bebra[ manual_yaw ] + client.random_float(0, 10)
            end
        end

        if globals.tickcount() > double_tap.defensive_tk - 2 then
            return
        end

        if avoid_backstab.get() or should_ignore then
            return
        end

        ctx.pitch = pitch_mode
        ctx.pitch_offset = pitch_value
        ctx.yaw = yaw_mode
        ctx.yaw_offset = yaw_value
    end
end

do

    function disablers.count_alive()
        local alive = 0

        for i = 1, globals.maxplayers() do
            if entity.get_classname(i) ~= 'CCSPlayer' then
                goto skip
            end

            if not entity.is_alive(i) or not entity.is_enemy(i) then
                goto skip
            end

            alive = alive + 1
            ::skip::
        end

        return alive
    end

    function disablers.update(cmd, ctx)
        local lp = entity.get_local_player()
        if lp == nil then
            return
        end

        if not aa_tweaks.enable:get() then
            return
        end

        local game_rules = entity.get_game_rules()
        if game_rules == nil then
            return
        end

        local should_disable = false

        if aa_tweaks.items:have_key('Disable on Warmup') and entity.get_prop(game_rules, 'm_bWarmupPeriod') == 1 then
            should_disable = true
        end

        local players = disablers.count_alive()

        if aa_tweaks.items:have_key('Disable While No Enemies') and players == 0 and cmd.in_use ~= 1 then
            should_disable = true
        end

        if not should_disable then
            return
        end

        ctx.enabled = false
    end
end

do
    local is_active = false
    -- configurable range: 180 (tight) to 350 (paranoid)
    -- 220 is default CS:GO knife range + small buffer
    local AVOID_BACKSTAB_MAX_DISTANCE_SQR = 260 * 260

    local function get_enemies_with_knife()
        local enemies = entity.get_players(true)
        if next(enemies) == nil then return { } end

        local list = { }

        for i = 1, #enemies do
            local enemy = enemies[i]
            local wpn = entity.get_player_weapon(enemy)

            if wpn == nil then
                goto continue
            end

            local wpn_class = entity.get_classname(wpn)

            -- detect all melee + taser threats
            local is_melee = wpn_class == "CKnife"
                or wpn_class == "CKnifeGG"
                or wpn_class == "CKnifeCT"
                or wpn_class == "CKnifeT"
                or wpn_class == "CKnifeGhost"
                or wpn_class == "CKnifeFalchion"
                or wpn_class == "CKnifeButterfly"
                or wpn_class == "CKnifeKarambit"
                or wpn_class == "CKnifeBowie"
                or wpn_class == "CKnifeBayonet"
                or wpn_class == "CEliteWeapon"
            if is_melee then
                list[#list + 1] = enemy
            end

            ::continue::
        end

        return list
    end

    local function get_closest_target(me)
        local targets = get_enemies_with_knife()
        if next(targets) == nil then return end

        local best_delta
        local best_target

        local my_origin = vector(entity.get_origin(me))
        local best_distance = AVOID_BACKSTAB_MAX_DISTANCE_SQR

        for i = 1, #targets do
            local target = targets[i]

            local origin = vector(entity.get_origin(target))
            local delta = origin - my_origin

            local distance = delta:lengthsqr()

            if distance < best_distance then
                best_delta = delta
                best_target = target

                best_distance = distance
            end
        end

        return best_target, best_delta
    end

    function avoid_backstab.get()
        return is_active
    end

    function avoid_backstab.update(ctx)
        is_active = false
        if not aa_tweaks.enable:get() then
            return
        end

        if not aa_tweaks.items:have_key('Avoid Backstab') then
            return
        end

        local me = entity.get_local_player()
        local target, delta = get_closest_target(me)

        if target == nil then return end
        if delta == nil then return end

        local view = vector(client.camera_angles())
        local angle = vector(delta:angles())

        local yaw = angle.y - view.y + 180

        if ctx.yaw_offset == nil then
            ctx.yaw_offset = 0
        end

        ctx.yaw_base = "Local view"
        ctx.yaw_offset = ctx.yaw_offset + yaw

        ctx.edge_yaw = false
        ctx.freestanding = false
        is_active = true
    end
end

do
    local is_active = false

    local presets = {
        ["Standing"] = {
            [2] = function(e, ctx, me)
                -- lean slightly left, body says right = harder to trace
                ctx.yaw_offset = -18
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 22
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = -180
            end
        },

        ["Moving"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = -14
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 14
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = -180
            end
        },

        ["Slow Walk"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = -20
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 20
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = -180
            end
        },

        ["Crouched"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = -10
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 45
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = -180
            end
        },

        ["Crouched Air"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = 0

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = -120
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 0

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 120
            end
        },

        ["Air Knife"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = 45

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 35

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
            end
        },

        ["Air Zeus"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = 23

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 0
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 10

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 0
            end
        }
    }

    local sv_gravity = cvar.sv_gravity
    local function extrapolate_entity(ent, pos)
        local tick_interval = globals.tickinterval()

        local velocity = vector(entity.get_prop(ent, "m_vecVelocity"))
        local new_pos = pos:clone()

        local ticks = 25
        if #velocity < 32 then
            ticks = 40
        end

        new_pos.x = new_pos.x + velocity.x * tick_interval * ticks
        new_pos.y = new_pos.y + velocity.y * tick_interval * ticks

        if entity.get_prop(ent, "m_hGroundEntity") == nil then
            new_pos.z = new_pos.z + velocity.z * tick_interval * ticks - sv_gravity:get_float() * tick_interval
        end

        return new_pos
    end

    local function get_statement(me)
        if localplayer.is_airborne then
            local wpn = entity.get_player_weapon(me)
            if wpn == nil then return end

            local classname = entity.get_classname(wpn)

            if classname == "CKnife" then
                return "Air Knife"
            end

            if classname == "CWeaponTaser" then
                return "Air Zeus"
            end

            if localplayer.duck_amount == 1.0 then
                return "Crouched Air"
            end

            return nil
        end

        if localplayer.is_crouched then
            return "Crouched"
        end

        if not localplayer.is_moving then
            return "Standing"
        end

        return nil
    end

    safe_head.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Safe Head")
    : record("aa", "safe_head::enabled")
    : save()

    safe_head.states = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- States", "\n", "safe_head::states" }, { "Air Knife", "Air Zeus", "Standing", "Crouched", "Crouched Air" })
    : record("aa", "safe_head::states")
    : save()

    function safe_head.get()
        return is_active
    end

    function safe_head.update(e, ctx)
        is_active = false

        if not safe_head.enabled:get() then
            return
        end

        local me = entity.get_local_player()

        if manual_direction.get() then
            return
        end

        local team = entity.get_prop(me, "m_iTeamNum")
        if team == nil then
            return
        end

        local wpn = entity.get_player_weapon(me)
        if wpn == nil then
            return
        end

        local threat = client.current_threat()
        if threat == nil then
            return
        end

        local statement = get_statement(me)
        if statement == nil then
            return
        end

        if not safe_head.states:have_key(statement) then
            return
        end

        local should_continue = false
        if statement == "Air Zeus" or statement == "Air Knife" then
            should_continue = true
        else
            local eye_pos = extrapolate_entity(threat, vector(utils.get_eye_position(threat)))
            local head_pos = vector(entity.hitbox_position(me, 0))

            eye_pos.z = eye_pos.z + 5

            if head_pos.z > eye_pos.z then
                local entindex, damage = client.trace_bullet(threat, eye_pos.x, eye_pos.y, eye_pos.z, head_pos.x, head_pos.y, head_pos.z + 6, threat)

                should_continue = damage > 0
            end
        end

        if not should_continue then
            return
        end

        local preset = presets[statement]
        if preset == nil then
            return
        end

        local fn = preset[team]
        if fn == nil then
            return
        end

        ctx.pitch = "Default"
        ctx.yaw_base = "At targets"

        ctx.yaw = "180"
        ctx.yaw_offset = 22

        ctx.yaw_jitter = "Off"

        ctx.body_yaw = "Static"
        ctx.body_yaw_offset = 120

        ctx.freestanding_body_yaw = false

        fn(e, ctx, me)

        is_active = true
    end
end

do
    local LEFT    = 0
    local RIGHT   = 1
    local FORWARD = 2

    local idx
    local data = { }

    local directions = {
        [LEFT]    = -90,
        [RIGHT]   = 90,
        [FORWARD] = 180
    }

    local function get_value(ref)
        local prev_active = data[ref]
        local active, mode, key = ui.get(ref)

        if prev_active == nil then
            data[ref] = active
            return
        end

        if mode == 0 then return end
        if mode == 3 then return end
        if key == nil then return end

        if prev_active ~= active then
            data[ref] = active
            return active, mode, key
        end
    end

    local function update_hotkey(ref, value)
        local active, mode = get_value(ref)
        if active == nil then return end

        if mode == 1 then
            if not active then
                idx = nil
                return
            end

            idx = value
            return
        end

        if mode == 2 then
            if idx == value then
                idx = nil
                return
            end

            idx = value
            return
        end
    end

    local function think()
        if get_value(manual_direction.disabled_manual.ref) ~= nil then
            idx = nil
            return
        end

        update_hotkey(manual_direction.left_manual.ref, LEFT)
        update_hotkey(manual_direction.right_manual.ref, RIGHT)
        update_hotkey(manual_direction.forward_manual.ref, FORWARD)
    end

    manual_direction.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Manual Yaw")
    : record("aa", "manual_direction::enabled")

    manual_direction.arrows = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Manual Arrows")
    : record("aa", "manual_direction::arrows")
    : save()

    manual_direction.color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "Manual Color")
    : record("aa", "manual_direction::color")
    : save()

    manual_direction.options = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- Options", "\n", "manual_direction::options" }, {
        "Disable Yaw Modifiers",
        "Freestanding Body Yaw",
        'Duck Exploit'
    })
    : record("aa", "manual_direction::options")
    : save()

    manual_direction.left_manual = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", merge { "- Left Manual", "\n", "manual_direction::left_manual" })
    : record("aa", "manual_direction::left_manual")

    manual_direction.right_manual = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", merge { "- Right Manual", "\n", "manual_direction::right_manual" })
    : record("aa", "manual_direction::right_manual")

    manual_direction.forward_manual = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", merge { "- Forward Manual", "\n", "manual_direction::forward_manual" })
    : record("aa", "manual_direction::forward_manual")

    manual_direction.disabled_manual = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", merge { "- Disabled Manual", "\n", "manual_direction::disabled_manual" })
    : record("aa", "manual_direction::disabled_manual")

    manual_direction.left_manual:set("Toggle")
    manual_direction.right_manual:set("Toggle")
    manual_direction.forward_manual:set("Toggle")
    manual_direction.disabled_manual:set("Toggle")

    function manual_direction.get()
        return idx
    end

    function manual_direction.frame()
        think()
    end

    function manual_direction.update(ctx)
        if idx == nil then
            return false
        end

        if avoid_backstab.get() then
            return false
        end

        local offset = directions[idx]

        if offset == nil then
            return false
        end

        if ctx.yaw_offset == nil then
            ctx.yaw_offset = 0
        end

        ctx.yaw_base = "Local view"
        ctx.yaw_offset = offset

        if manual_direction.options:have_key("Disable Yaw Modifiers") then
            ctx.yaw_jitter = "Off"
            ctx.body_yaw = "Static"
        end

        if manual_direction.options:have_key("Freestanding Body Yaw") then
            ctx.body_yaw = "Static"
            ctx.body_yaw_offset = 120

            ctx.freestanding_body_yaw = true
        end

        ctx.edge_yaw = false
        ctx.freestanding = false

        return true
    end
end

do
    local DURATION = 7.0

    local inferno = { }
    local regular = { }

    local function draw_event_log(r, g, b, a, msg, kind, stable_key)
        if not settings.tweaks_enable:get() then return end
        eventlogs.add_stable(r, g, b, a, msg, kind or 'hit', stable_key)
    end

    local function push_event_log(data)
        if #regular > 8 then
            table.remove(regular, 1)
        end

        regular[#regular + 1] = data
    end

    local function weapon_to_action(weapon)
        if weapon == "knife" then
            return "Knifed"
        end

        if weapon == "hegrenade" then
            return "Naded"
        end

        return "Hit"
    end

    local function find_inferno_info(ent)
        for i = 1, #inferno do
            local data = inferno[i]

            if data.entity == ent then
                return data
            end
        end

        return nil
    end

    local function get_miss_color(reason)
        if reason == "spread" then
            return eventlogs.spread_color_picker:rawget()
        end

        if reason == "death" or reason == "unregistered shot" then
            return eventlogs.unregistered_color_picker:rawget()
        end

        return eventlogs.miss_color_picker:rawget()
    end

    local function create_event_message(action, hitgroup, ent, damage)
        local name = entity.get_player_name(ent)
        local hitgroup_name = e_hitgroup[hitgroup]

        if action == "Hit" then
            return f(
                "%s ${%s} in the ${%s} for ${%s} damage",
                action, name, hitgroup_name, damage
            )
        end

        return f(
            "%s ${%s} for ${%s} damage",
            action, name, damage
        )
    end

    local function create_inferno_info(ent, damage)
        local data = { }

        data.entity = ent
        data.damage = damage

        data.alpha = 0.0
        data.duration = 7.0

        data.flash_amount = 1.0

        return data
    end

    local function create_event_info(action, hitgroup, ent, damage)
        local data = { }

        data.msg  = create_event_message(action, hitgroup, ent, damage)
        data.kind = 'hit'
        data.alpha    = 0.0
        data.duration = 7.0

        return data
    end

    local function create_miss_info(reason)
        if reason == "?" then reason = "correction" end

        local data = { }
        data.msg    = f("Missed shot due to ${%s}", reason)
        data.reason = reason
        -- classify into icon kind
        if reason == "spread" then
            data.kind = 'spread'
        elseif reason == "unregistered shot" or reason == "player death" or reason == "death" then
            data.kind = 'net'
        else
            data.kind = 'miss'
        end
        data.alpha    = 0.0
        data.duration = 7.0

        return data
    end

    local function update_inferno_logs(dt)
        local r, g, b = widgets.color_picker:rawget()

        for i = #inferno, 1, -1 do
            local data = inferno[i]

            data.duration = math.max(0, data.duration - dt)
            data.alpha = motion.interp(data.alpha, data.duration > 0, 0.045)

            if data.alpha <= 0 then
                table.remove(inferno, i)
            end
        end

        for i = 1, #inferno do
            local data = inferno[i]

            local name = entity.get_player_name(data.entity)
            local damage = data.damage

            draw_event_log(r, g, b, 255 * data.alpha, f("Burned ${%s} for ${%d} damage", name, damage), 'burned', tostring(data))
        end
    end

    local function update_regular_logs(dt)
        local r, g, b = widgets.color_picker:rawget()

        for i = #regular, 1, -1 do
            local data = regular[i]

            data.duration = math.max(0, data.duration - dt)
            data.alpha = motion.interp(data.alpha, data.duration > 0, 0.045)

            if data.alpha <= 0 then
                table.remove(regular, i)
            end
        end

        for i = 1, #regular do
            local data = regular[i]

            local col_r = r
            local col_g = g
            local col_b = b

            if data.reason ~= nil then
                col_r, col_g, col_b = get_miss_color(data.reason)
            end

            draw_event_log(col_r, col_g, col_b, 255 * data.alpha, data.msg, data.kind or 'hit', tostring(data))
        end
    end

    local function handle_input()
        if not settings.tweaks_enable:get() then
            return
        end

        if settings.tweaks:have_key('Log Aimbot Shots') then
            override.set(software.misc.settings.output, false)
        else
            override.unset(software.misc.settings.output)
        end
    end

    settings.tweaks:set_callback(handle_input)
    settings.tweaks_enable:set_callback(handle_input)
    ui.set_callback(software.misc.settings.output, handle_input)
    handle_input()

    function log_aimbot_shots.player_hurt(e)
        if not settings.tweaks_enable:get() then
            return
        end

        local me = entity.get_local_player()

        local userid = client.userid_to_entindex(e.userid)
        local attacker = client.userid_to_entindex(e.attacker)

        local weapon = e["weapon"]
        local damage = e["dmg_health"]

        local hitgroup = e["hitgroup"]

        if userid == me or attacker ~= me then
            return
        end

        if weapon == "inferno" then
            local data = find_inferno_info(userid)

            if data ~= nil then
                data.damage = data.damage + damage
                data.duration = DURATION

                data.flash_amount = 1.0

                return
            end

            inferno[#inferno + 1] = create_inferno_info(userid, damage)
            return
        end

        local action = weapon_to_action(weapon)
        push_event_log(create_event_info(action, hitgroup, userid, damage))
    end

    function log_aimbot_shots.aim_miss(e)
        if not settings.tweaks_enable:get() then
            return
        end

        push_event_log(create_miss_info(e.reason))
    end

    function log_aimbot_shots.frame()
        local dt = globals.frametime()

        update_inferno_logs(dt)
        update_regular_logs(dt)
    end
end

do
    local ALPHA_UNIT   = 1 / 255

    -- ── layout tunables ─────────────────────────────────────────────────────
    local PILL_PAD_X      = 10    -- horizontal padding inside pill
    local PILL_PAD_Y      = 3     -- vertical padding inside pill
    local PILL_RADIUS     = 4     -- corner radius of the pill background
    local PILL_GAP        = 5     -- vertical gap between rows
    local ACCENT_BAR_W    = 3     -- width of the left colour bar
    local SLIDE_TICKS     = 0.18  -- seconds for slide-in animation
    local FADE_IN_TICKS   = 0.12  -- seconds to fade in
    local PILL_BG_ALPHA   = 0.62  -- background darkness (0-1)
    local GLOW_SPREAD     = 18    -- horizontal glow gradient width
    local MAX_ENTRIES     = 10    -- cap live queue

    -- ── icon prefixes by type ────────────────────────────────────────────────
    -- type is set on each log when added:
    --   'hit'  'miss'  'spread'  'net'
    -- Plain ASCII prefixes — safe across all renderers
    local TYPE_ICONS = {
        hit    = "[+] ",
        miss   = "[-] ",
        spread = "[~] ",
        net    = "[?] ",
        burned = "[F] ",
    }

    -- ── helpers ──────────────────────────────────────────────────────────────
    local function ease_out_quart(t)
        local u = 1 - t
        return 1 - u * u * u * u
    end

    local function draw_pill(x, y, w, h, r, g, b, alpha, radius)
        local ia = math.floor(alpha)
        if ia <= 0 then return end
        radius = math.min(radius, math.floor(h / 2))

        -- filled rounded rect (manual: top/bottom strips + left/right strips + 4 circles)
        renderer.rectangle(x + radius, y,         w - radius*2, h,            0, 0, 0, ia)
        renderer.rectangle(x,         y + radius, radius,       h - radius*2, 0, 0, 0, ia)
        renderer.rectangle(x + w - radius, y + radius, radius,  h - radius*2, 0, 0, 0, ia)
        renderer.circle(x + radius,         y + radius,         0,0,0, ia, radius, 180, 0.25)
        renderer.circle(x + radius,         y + h - radius,     0,0,0, ia, radius, 270, 0.25)
        renderer.circle(x + w - radius,     y + h - radius,     0,0,0, ia, radius,   0, 0.25)
        renderer.circle(x + w - radius,     y + radius,         0,0,0, ia, radius,  90, 0.25)
    end

    local function draw_accent_bar(x, y, h, r, g, b, alpha, radius)
        local ia = math.floor(alpha)
        if ia <= 0 then return end
        -- solid bar
        renderer.rectangle(x, y + radius, ACCENT_BAR_W, h - radius * 2, r, g, b, ia)
        renderer.circle(x + radius, y + radius,     r,g,b, ia, radius, 180, 0.25)
        renderer.circle(x + radius, y + h - radius, r,g,b, ia, radius, 270, 0.25)
        -- glow gradient bleeding right
        renderer.gradient(x + ACCENT_BAR_W, y, GLOW_SPREAD, h, r, g, b, math.floor(ia*0.30), r, g, b, 0, false)
    end

    local function replacement(s, col_a, col_b)
        local hex_a = utils.to_hex(unpack(col_a))
        local hex_b = utils.to_hex(unpack(col_b))
        local repl  = f("\a%s%%1\a%s", hex_a, hex_b)
        return string.gsub(s, "${(.-)}", repl)
    end

    -- ── persistent entry list ───────────────────────────────────────────────
    -- Each entry lives here across frames and drives its own alpha.
    -- { r,g,b, msg, kind, spawn_t, alpha_t, target_alpha, key }
    local live_entries  = {}
    local preview_shown = false   -- tracks whether preview is currently visible

    -- ── helpers ──────────────────────────────────────────────────────────────
    local function find_entry_by_key(key)
        for i = 1, #live_entries do
            if live_entries[i].key == key then return live_entries[i], i end
        end
    end

    local function push_entry(r, g, b, msg, kind, key, target_a)
        local now = globals.realtime()
        local e = find_entry_by_key(key)
        if e then
            -- refresh in place — don't reset spawn_t so slide stays settled
            e.r, e.g, e.b   = r, g, b
            e.msg            = msg
            e.kind           = kind
            e.target_alpha   = target_a
            return e
        end
        if #live_entries >= MAX_ENTRIES then
            table.remove(live_entries, 1)
        end
        local entry = {
            r = r, g = g, b = b,
            msg          = msg,
            kind         = kind,
            spawn_t      = now,
            alpha_t      = 0.0,
            target_alpha = target_a,
            key          = key,
        }
        table.insert(live_entries, entry)
        return entry
    end

    -- ── preview ──────────────────────────────────────────────────────────────
    local preview_target = 0.0

    local function update_preview()
        local real_count = 0
        for _, e in ipairs(live_entries) do
            if not e.is_preview then real_count = real_count + 1 end
        end
        local can_show = widgets.enabled:get() and ui.is_menu_open() and real_count == 0
        preview_target = motion.interp(preview_target, can_show and 1 or 0, 0.045)

        local pv = preview_target
        if pv <= 0.01 then
            -- fade out all preview entries
            for _, e in ipairs(live_entries) do
                if e.is_preview then e.target_alpha = 0 end
            end
            return
        end

        local a = pv  -- 0-1, used directly as target_alpha

        local function add_prev(r, g, b, msg, kind, key)
            local e = push_entry(r, g, b, msg, kind, 'prev_'..key, a)
            e.is_preview = true
        end

        local ar, ag, ab = widgets.color_picker:rawget()
        add_prev(ar,ag,ab, "Hit ${vladislav} for ${10} damage",          'hit',  'h1')
        add_prev(ar,ag,ab, "Hit ${monster} in the ${head} for ${103} damage", 'hit', 'h2')

        local mr, mg, mb = eventlogs.miss_color_picker:rawget()
        add_prev(mr,mg,mb, "Missed shot due to ${correction}",       'miss',   'm1')
        add_prev(mr,mg,mb, "Missed shot due to ${prediction error}", 'miss',   'm2')
        add_prev(mr,mg,mb, "Missed shot due to ${lagcomp failure}",  'miss',   'm3')

        local sr, sg, sb = eventlogs.spread_color_picker:rawget()
        add_prev(sr,sg,sb, "Missed shot due to ${spread}",           'spread', 's1')

        local nr, ng, nb = eventlogs.unregistered_color_picker:rawget()
        add_prev(nr,ng,nb, "Missed shot due to ${unregistered shot}", 'net',   'n1')
        add_prev(nr,ng,nb, "Missed shot due to ${player death}",      'net',   'n2')
        add_prev(nr,ng,nb, "Missed shot due to ${death}",             'net',   'n3')
    end

    -- ── widget / window ──────────────────────────────────────────────────────
    local widget = windows.new("##Event Logs", .55, 0.78)
    widget:set_size(vector(330, 125))
    local hovered_alpha = 0

    -- ── draw ─────────────────────────────────────────────────────────────────
    local SLIDE_AMOUNT = 22

    local function draw_eventlogs()
        if not widgets.enabled:get() or not widgets.items:have_key("On-Screen Logs") then
            return
        end

        local screen  = vector(client.screen_size())
        local flags   = "d"
        local now     = globals.realtime()

        local window  = widget
        window.pos.x  = screen.x * 0.5 - 165

        local pos  = window.pos:clone()
        local size = window.size:clone()
        local cx   = pos.x + size.x * 0.5

        hovered_alpha = motion.interp(hovered_alpha,
            ui.is_menu_open() and window:is_hovering() and 1 or 0, 0.095)
        if hovered_alpha > 0 then
            renderer.text(pos.x + size.x * 0.5, pos.y - 12,
                255, 255, 255, math.floor(200 * hovered_alpha), 'c', nil,
                'Drag to reposition.')
            renderer.rectangle(pos.x + 50, pos.y - 2, size.x - 100, 1,
                255, 255, 255, math.floor(80 * hovered_alpha))
        end

        -- tick alpha, prune dead entries
        local i = 1
        while i <= #live_entries do
            local e = live_entries[i]
            e.alpha_t = motion.interp(e.alpha_t, e.target_alpha, 0.07)
            if e.alpha_t < 0.005 and e.target_alpha <= 0 then
                table.remove(live_entries, i)
            else
                i = i + 1
            end
        end

        local draw_y = pos.y

        for idx = 1, #live_entries do
            local e     = live_entries[idx]
            local alpha = e.alpha_t
            if alpha < 0.005 then goto continue_log end

            local age      = now - e.spawn_t
            local slide_p  = math.min(age / SLIDE_TICKS, 1.0)
            local slide_x  = SLIDE_AMOUNT * (1.0 - ease_out_quart(slide_p))

            local r, g, b  = e.r, e.g, e.b
            -- plain_msg: strip ${...} markers for shadow + measure
            local plain_msg = string.gsub(e.msg, "${(.-)}", "%1")
            local icon      = TYPE_ICONS[e.kind] or ""
            local plain_txt = icon .. plain_msg

            -- full_txt: colour-escaped version for main render
            local raw_text  = replacement(e.msg, {r, g, b, 255}, {255, 255, 255, 255})
            local full_txt  = icon .. raw_text

            local tw, th  = renderer.measure_text(flags, plain_txt)
            local pill_w  = tw + PILL_PAD_X * 2 + ACCENT_BAR_W
            local pill_h  = th + PILL_PAD_Y * 2

            local pill_x  = math.floor(cx - pill_w * 0.5 + slide_x)
            local pill_y  = math.floor(draw_y)

            local ia_pill = math.floor(210 * PILL_BG_ALPHA * alpha)
            local ia_bar  = math.floor(255 * alpha)
            local ia_txt  = math.floor(255 * alpha)

            -- pill background
            draw_pill(pill_x, pill_y, pill_w, pill_h, 0, 0, 0, ia_pill, PILL_RADIUS)

            -- right-edge fade
            renderer.gradient(
                pill_x + pill_w - 24, pill_y, 24, pill_h,
                0,0,0,0,  0,0,0, ia_pill,  false)

            -- left accent bar + glow
            draw_accent_bar(pill_x, pill_y, pill_h, r, g, b, ia_bar, PILL_RADIUS)

            -- top highlight
            renderer.gradient(
                pill_x + PILL_RADIUS, pill_y,
                pill_w - PILL_RADIUS * 2, 1,
                255,255,255, math.floor(28 * alpha),
                255,255,255, 0,  false)

            -- text
            local tx = pill_x + ACCENT_BAR_W + PILL_PAD_X
            local ty = pill_y + PILL_PAD_Y
            -- shadow uses plain text (no colour escapes)
            renderer.text(tx+1, ty+1, 0,0,0, math.floor(120*alpha), flags, nil, plain_txt)
            -- main uses colour-escaped text via graphics.text
            graphics.text(tx, ty, 255,255,255, ia_txt, flags, 0, full_txt)

            draw_y = draw_y + pill_h + PILL_GAP

            ::continue_log::
        end

        window:update()
    end

    -- ── colour pickers (unchanged API) ───────────────────────────────────────
    local function get_color(self) return self.r, self.g, self.b end

    local wr, wg, wb = widgets.color_picker:rawget()
    eventlogs.hit_color_picker          = { r=wr,  g=wg,  b=wb,  rawget=get_color }
    eventlogs.spread_color_picker       = { r=255, g=225, b=115, rawget=get_color }
    eventlogs.miss_color_picker         = { r=255, g=98,  b=98,  rawget=get_color }
    eventlogs.unregistered_color_picker = { r=100, g=100, b=255, rawget=get_color }

    -- ── public API ───────────────────────────────────────────────────────────
    -- unique key counter for one-shot entries without a stable handle
    local _entry_seq = 0

    -- add_stable: uses caller-supplied key so the same logical entry is
    -- refreshed in place every frame rather than spawning a new one.
    function eventlogs.add_stable(r, g, b, a, text, kind, key)
        if key == nil then
            _entry_seq = _entry_seq + 1
            key = 'seq_'.._entry_seq
        end
        local e = push_entry(r, g, b, text, kind or 'hit', key, a * ALPHA_UNIT)
        e.is_preview = false
        return e
    end

    -- legacy one-shot add (still used by preview internally)
    function eventlogs.add(r, g, b, a, text, kind)
        return eventlogs.add_stable(r, g, b, a, text, kind, nil)
    end

    function eventlogs.pre_frame()
        -- real shot entries: set target to 0 so they fade once the push stops
        -- (they will be re-pushed each frame while alive via update_regular_logs)
        for _, e in ipairs(live_entries) do
            if not e.is_preview then
                e.target_alpha = 0
            end
        end
    end

    function eventlogs.post_frame()
        update_preview()
        draw_eventlogs()
    end
end

local print_dev do
    print_dev = {
        data = { }
    }

    function print_dev.add(text, time)
        print_dev.data[#print_dev.data+1] = {
            text = text,
            time = time + globals.realtime(),
            alpha = 0.01,
            offset = 0
        }
    end

    client.set_event_callback('paint', function ()
        local realtime = globals.realtime()
        local frametime = globals.frametime()
        local offset = 0

        for i = #print_dev.data, 1, -1 do
            local log = print_dev.data[i]
            if not log then
                goto skip
            end

            if log.offset ~= offset then
                log.offset = utils.clamp(log.offset < offset and log.offset + (200 * frametime) or offset, 0, offset)
            end

            local difference = log.time - realtime
            log.alpha = motion.interp(log.alpha, difference > 0, 0.045)
            if log.alpha <= 0 and difference < 0 then
                table.remove(print_dev.data, i)
                goto skip
            end

            local text_sz = vector(renderer.measure_text('d', log.text))

            graphics.text(8, 5 + log.offset, 255, 255, 255, 255 * log.alpha, 'd', nil, log.text)

            offset = offset + text_sz.y + 1
            ::skip::
        end

        for i = 1, #print_dev.data do
            local log_count = #print_dev.data - i

            if log_count > 7 then
                print_dev.data[ i ].time = 0
            end
        end
    end)

    client.set_event_callback('round_prestart', function ()
        print_dev.data = { }
    end)

    setmetatable(print_dev, {
        __call = function (self, ...)
            print_dev.add(...)
        end
    })
end

do
    local hitgroup_str = {
        [0] = 'generic',
        'head', 'chest', 'stomach',
        'left arm', 'right arm',
        'left leg', 'right leg',
        'neck', 'generic', 'gear'
    }

    local weapon_verb = {
        ['hegrenade'] = 'Naded',
        ['inferno'] = 'Burned',
        ['knife'] = 'Knifed',
    }

    local hex_to_rgb = function( hex )
        hex = hex:gsub('#', '')
        return tonumber('0x' .. hex:sub(1, 2)), tonumber('0x' .. hex:sub(3, 4)), tonumber('0x' .. hex:sub(5, 6))
    end

    local function clean_up(str)
        local text = str:gsub('(\a%x%x%x%x%x%x)%x%x', '%1')
        return text
    end

	local function printc(...)
		for i, v in ipairs{...} do
			local r = "\aD9D9D9" .. v
			for col, text in r:gmatch("\a(%x%x%x%x%x%x)([^\a]*)") do
                local r, g, b = hex_to_rgb(col)
				client.color_log(r, g, b, string.format('%s\0', text))
			end
            client.color_log(255, 255, 255, '\n\0')
		end
	end

    local wanted_damage, wanted_hitgroup, backtrack = 0, 0, 0

    client.set_event_callback("aim_fire", function (e)
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Log Aimbot Shots') then
            return
        end

        wanted_damage = e.damage
        wanted_hitgroup = e.hitgroup
        backtrack = globals.tickcount() - e.tick
    end)

    client.set_event_callback('aim_hit', function (shot)
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Log Aimbot Shots') then
            return
        end

        local target = shot.target
        if target == nil then
            return
        end

        local info = {
            '\rHit ',
            f('\a[nick]%s\r\'s ', entity.get_player_name(target)),
            'in the ',
            shot.hitgroup ~= wanted_hitgroup and f('\a[highlight]%s\r(\a[highlight]%s\r) ', hitgroup_str[ shot.hitgroup ], hitgroup_str[ wanted_hitgroup ]) or f('\a[highlight]%s\r ', hitgroup_str[ shot.hitgroup ]),
            'for ',
            shot.damage ~= wanted_damage and f('\a[highlight]%d\r(\a[highlight]%d\r) ', shot.damage, wanted_damage) or f('\a[highlight]%d\r ', shot.damage),
            'damage ',
            f('(hc: \a[highlight]%d%% \a[idle]· \rhistory: \a[highlight]%dt\r)', shot.hit_chance, backtrack)
        }

        local str = utils.format(table.concat(info, ''), 255, 255, 255, 255)
        printc(f('\aB6E717[gamesense] \aFFFFFF%s', clean_up(str)))
        print_dev(str, 8)
    end)

    client.set_event_callback('aim_miss', function (shot)
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Log Aimbot Shots') then
            return
        end

        local target = shot.target
        if target == nil then
            return
        end

        local info = {
            '\rMissed ',
            f('\a[nick]%s\r\'s ', entity.get_player_name(target)),
            f('\a[highlight]%s\r ', hitgroup_str[ shot.hitgroup ]),
            'due to ',
            f('\a[miss]%s\r ', shot.reason),
            f('(hc: \a[highlight]%d%% \a[idle]· \rhistory: \a[highlight]%dt\r)', shot.hit_chance, backtrack)
        }

        local str = utils.format(table.concat(info, ''), 255, 255, 255, 255)
        printc(f('\aB6E717[gamesense] \aFFFFFF%s', clean_up(str)))
        print_dev(str, 8)
    end)

    client.set_event_callback('player_hurt', function (e)
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Log Aimbot Shots') then
            return
        end

        local lp = entity.get_local_player()
        local victim = client.userid_to_entindex(e.userid)
        local attacker = client.userid_to_entindex(e.attacker)
        if victim == nil or attacker == nil or victim == lp or attacker ~= lp then
            return
        end

        local hitgroup = hitgroup_str[ e.hitgroup ]

        local verb = weapon_verb[ e.weapon ]
        if verb == nil then
            return
        end

        local info = {
            '\r' .. verb,
            f(' \a[nick]%s\r ', entity.get_player_name(victim)),
            'for ',
            f('\a[highlight]%d \rdamage ', e.dmg_health or 0),
            f('(\a[highlight]%d \rhealth remaining)', e.health or 0)
        }

        local str = utils.format(table.concat(info, ''), 255, 255, 255, 255)
        printc(f('\aB6E717[gamesense] \aFFFFFF%s', clean_up(str)))
        print_dev(str, 8)
    end)
end

-- --region hitchance
-- do
--     hitchance.reset = false
--     hitchance.weapons = { 'G3SG1 / SCAR-20', 'AWP', 'SSG 08', 'R8 Revolver', 'Pistol' }

--     hitchance.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Custom Hit Chance")
--     : record("rage", "hitchance::enabled")
--     : save()

--     hitchance.weapon_list = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "- Weapons", hitchance.weapons)
--     : record("rage", "hitchance::weapons")
--     : save()

--     for _, weapon in next, hitchance.weapons do
--         hitchance['Enabled_' .. weapon] = menu.new_item(ui.new_checkbox, 'AA', 'Anti-aimbot angles', f('Enable %s', weapon))
--         : record("rage", "hitchance::enable::" .. weapon)
--         : save()

--         hitchance['Modes_' .. weapon] = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { 'Modes', '\n', weapon }, { 'No Scope', 'In Air' })
--         : record("rage", "hitchance::modes::" .. weapon)
--         : save()

--         hitchance['Distance_' .. weapon] = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { 'Distance', '\n', weapon }, 100, 1001, 500, true, 'm', 0.01, { [1001] = 'Inf.' })
--         : record("rage", "hitchance::distance::" .. weapon)
--         : save()

--         hitchance['No Scope_' .. weapon] = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { 'No Scope', '\n', weapon }, 1, 100, 50, true, '%')
--         : record("rage", "hitchance::noscope::" .. weapon)
--         : save()

--         hitchance['In Air_' .. weapon] = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { 'In Air', '\n', weapon }, 1, 100, 50, true, '%')
--         : record("rage", "hitchance::inair::" .. weapon)
--         : save()
--     end

--     function hitchance.backups()
--         if hitchance.reset then
--             override.unset(software.rage.aimbot.hitchance)
--             override.unset(software.rage.aimbot.auto_scope)
--             hitchance.reset = false
--         end
--     end

--     function hitchance.distance(ent, distance)
--         local my_origin = vector(entity.get_origin(ent))
--         if my_origin == nil then
--             return
--         end

--         local target = client.current_threat()
--         if target == nil then
--             return
--         end

--         local enemy_origin = vector(entity.get_origin(target))
--         if enemy_origin == nil then
--             return
--         end

--         if distance == 1001 then
--             return 'Inf.'
--         end

--         return my_origin:dist(enemy_origin) <= distance
--     end

--     local noscope_ignore = {
--         ['R8 Revolver'] = true,
--         ['Pistol'] = true
--     }

--     client.set_event_callback('setup_command', function (cmd)
--         if not hitchance.enabled:get() then
--             return hitchance.backups()
--         end

--         local lp = entity.get_local_player()
--         if lp == nil then
--             return hitchance.backups()
--         end

--         local wpn = entity.get_player_weapon(lp)
--         if wpn == nil then
--             return hitchance.backups()
--         end

--         if ui.is_menu_open() then
--             return hitchance.backups()
--         end

--         local weapon = ui.get(software.rage.weapon.weapon_type)

--         if not hitchance['Enabled_' .. weapon] then
--             return hitchance.backups()
--         end

--         if not hitchance['Enabled_' .. weapon]:get() then
--             return hitchance.backups()
--         end

--         local distance = hitchance.distance(lp, hitchance[ 'Distance_' .. weapon ]:get())
--         local conditions = hitchance[ 'Modes_' .. weapon ]
--         local is_pistol = noscope_ignore[ weapon ] or false

--         if conditions:have_key('In Air') and localplayer.is_airborne then
--             override.set(software.rage.aimbot.hitchance, hitchance[ 'In Air_' .. weapon]:get())
--         elseif conditions:have_key('No Scope') and entity.get_prop(lp, 'm_bIsScoped') == 0 and distance and not is_pistol then
--             override.set(software.rage.aimbot.hitchance, hitchance[ 'No Scope_' .. weapon]:get())
--             override.set(software.rage.aimbot.auto_scope, false)
--         else
--             return hitchance.backups()
--         end

--         if distance == 'Inf.' then
--             override.unset(software.rage.aimbot.auto_scope)
--         end

--         hitchance.reset = true
--     end)
-- end

do
    local shots do
        shots = {
            total = 0,
            hits = 0,

            reasons = {
                ['prediction error'] = true,
                ['death'] = true
            }
        }

        client.set_event_callback('aim_fire', function (shot)
            shots.total = shots.total + 1
        end)

        client.set_event_callback('aim_hit', function (shot)
            shots.hits = shots.hits + 1
        end)

        client.set_event_callback('player_connect_full', function (e)
            if client.userid_to_entindex(e['userid']) ~= entity.get_local_player() then
                return
            end

            shots.hits = 0
            shots.total = 0
        end)
    end

    client.set_event_callback('paint_ui', function ()
        local lp = entity.get_local_player()
        if lp == nil then
            return
        end

        if not widgets.enabled:get() or not widgets.items:have_key('Hit Rate') then
            return
        end

        local hit_rate = shots.total ~= 0 and (shots.hits / shots.total * 100) or 100

        renderer.indicator(255, 255, 255, 200, f('%s%d%%', hit_rate <= 50 and '◣_◢ ' or '', hit_rate))
    end)

end

do
    function auto_peek.perform(ctx)
        if not aa_tweaks.enable:get() then
            return
        end

        if not aa_tweaks.items:have_key('Auto Peek Improvements') then
            return
        end

        if not software.is_quick_peek_assist() then
            return
        end

        -- clean shot position: zero all jitter so bullet goes exactly where aimed
        ctx.yaw_offset       = 0
        ctx.yaw_jitter       = 'Off'
        ctx.body_yaw         = 'Static'
        ctx.body_yaw_offset  = 0
        ctx.freestanding     = true
        ctx.pitch            = 'Default'
        -- disable micro-jitter during peek shot
        ctx._suppress_micro_jitter = true
    end
end

LPH_NO_VIRTUALIZE(function ()
    do
        local FRAMERATE_AVG_FRAC = 0.9

        local cl_updaterate = cvar["cl_updaterate"]

        local alpha = 0.0
        local offset = vector(6, 5)

        local timer = 0.0
        local framerate = 0.0

        local last_ping = 0.0
        local last_framerate = 1 / globals.absoluteframetime()

        local last_server_framerate = 0.0
        local last_server_var = 0.0

        local texture do
            http.get("https://zenith.dev/assets/logo.png", function(status, response)
                if not status then
                    return
                end

                local code = response.status

                if code >= 200 and code < 300 then
                    texture = renderer.load_png(response.body, 22, 22)
                end
            end)
        end

        local function get_flags()
            return "d"
        end

        local function get_ping(nci)
            if inetchannel.is_loopback(nci) then
                return nil
            end

            local ping = math.max(0, last_ping * 1000)
            ping = math.floor(ping)

            return f("%dms", ping)
        end

        local function get_framerate()
            framerate = FRAMERATE_AVG_FRAC * framerate + (1.0 - FRAMERATE_AVG_FRAC) * globals.absoluteframetime()
            return last_framerate
        end

        local function get_remote_framerate()
            return last_server_framerate, last_server_var
        end

        local function update_timer(nci, dt)
            timer = timer - dt
            if timer > 0 then return end

            do
                local latency = inetchannel.get_latency(nci, 0)
                local update_rate = cl_updaterate:get_float()

                if update_rate > 0.001 then
                    local adjustment = -0.5 / update_rate
                    latency = latency + adjustment
                end

                last_ping = latency
            end

            last_server_framerate, last_server_var = inetchannel.get_remote_framerate(nci)
            last_framerate = framerate > 0 and framerate or 1

            timer = timer + 1.0
        end

        function watermark.frame()
            local can_show_watermark = widgets.enabled:get() and widgets.items:have_key("Watermark")
            alpha = motion.interp(alpha, can_show_watermark, 0.045)

            if alpha <= 0 then
                return
            end

            local lp = entity.get_local_player()
            if lp == nil then
                return
            end

            local nci = iengineclient.get_net_channel_info()
            update_timer(nci, globals.frametime())

            if nci == nil then
                return
            end

            local screen = vector(client.screen_size())
            local pos = vector(screen.x - 9, 9)

            local flags = get_flags()
            local r, g, b = widgets.color_picker:rawget()

            local a = 255

            local radius = 5

            local drawlist = { }

            do
                local label = "Zenith"
                local build = BUILD

                if texture ~= nil then
                    label = ""
                end

                if build ~= nil then
                    build = f("[%s]", build)

                    build = decorations.wave(build, globals.realtime(), 255, 255, 255, 255, r, g, b, a)
                    build = f("%s\affffffff", build)
                end

                drawlist[#drawlist + 1] = merge({ label, build }, "\x20")
            end

            if widgets.display:have_key("Username") then
                local nickname = USERNAME

                if widgets.custom_name:get() then
                    local chosen_nickname = ui.get(widgets.custom_name_value:get_ref())

                    if #chosen_nickname ~= 0 then
                        nickname = chosen_nickname
                    end
                end

                drawlist[#drawlist + 1] = nickname
            end

            if widgets.display:have_key("Latency") then
                drawlist[#drawlist + 1] = get_ping(nci)
            end

            if widgets.display:have_key("FPS") then
                drawlist[#drawlist + 1] = f("%dfps", 1 / get_framerate())
            end

            if widgets.display:have_key("Server frametime") then
                drawlist[#drawlist + 1] = f("sv: %.1f (%.1fms)", get_remote_framerate())
            end

            if widgets.display:have_key("Time") then
                drawlist[#drawlist + 1] = f("%02d:%02d", client.system_time())
            end

            local left_padding = 0

            if texture ~= nil then
                left_padding = 22
            end

            local text = merge(drawlist, " ∙ ")
            local text_size = vector(renderer.measure_text(flags, text))

            local rect_size = vector(text_size.x + offset.x * 2, text_size.y + offset.y * 2)
            rect_size.x = rect_size.x + left_padding

            pos.x = pos.x - rect_size.x

            graphics.header(pos.x, pos.y, rect_size.x, 2, 5, r, g, b, a * alpha)
            --graphics.glow(pos.x, pos.y, rect_size.x, rect_size.y, r, g, b, a * 0.3 * alpha, thickness, radius)
            graphics.rectangle(pos.x, pos.y, rect_size.x, rect_size.y, 0, 0, 0, 100 * alpha, radius)

            if texture ~= nil then
                renderer.texture(texture, pos.x + offset.x - 1, pos.y + (rect_size.y - 22) * 0.5, 22, 22, 255, 255, 255, 255 * alpha, "f")
            end

            graphics.text(
                pos.x + left_padding + offset.x - 1,
                pos.y + (rect_size.y - text_size.y) * 0.5,
                255, 255, 255, 255 * alpha,
                flags, 0, text
            )
        end
    end

    do
        local alpha = 0.0
        local width = 0.0
        local holding = 0.0

        local all_hotkeys = {
    		{
    			ref = { ui.reference("Legit", "Aimbot", "Enabled") },
    			name = "Legit Aimbot",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Legit", "Triggerbot", "Enabled") },
    			name = "Legit Triggerbot",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Rage", "Aimbot", "Enabled") },
    			name = "Rage Aimbot",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Rage", "Aimbot", "Minimum damage override") },
    			name = "Minimum Damage",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Rage", "Aimbot", "Force safe point") },
    			name = "Safe Point",
    			offset = 1
    		},

            {
    			ref = { ui.reference("Rage", "Aimbot", "Force body aim") },
    			name = "Force Body Aim",
    			offset = 1
    		},

    		{
    			ref = { ui.reference("Rage", "Aimbot", "Double tap") },
    			name = "Double Tap",
    			offset = 2
    		},

            {
    			ref = { ui.reference("Rage", "Aimbot", "Quick stop") },
    			name = "Quick Stop",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Rage", "Other", "Quick peek assist") },
    			name = "Quick Peek Assist",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Rage", "Other", "Duck peek assist") },
    			name = "Duck Peek Assist",
    			offset = 1
    		},

    		{
    			ref = { ui.reference("AA", "Anti-aimbot angles", "Freestanding") },
    			name = "Freestanding",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("AA", "Other", "Slow motion") },
    			name = "Slow Motion",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("AA", "Other", "On shot anti-aim") },
    			name = "On Shot Anti-aim",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("AA", "Other", "Fake peek") },
    			name = "Fake Peek",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Misc", "Movement", "Z-Hop") },
    			name = "Z-Hop",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Misc", "Movement", "Pre-speed") },
    			name = "Pre-speed",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Misc", "Movement", "Blockbot") },
    			name = "Blockbot",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Misc", "Movement", "Jump at edge") },
    			name = "Jump At Edge",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Misc", "Miscellaneous", "Last second defuse") },
    			name = "Last Second Defuse",
    			offset = 1
    		},

    		{
    			ref = { ui.reference("Misc", "Miscellaneous", "Free look") },
    			name = "Free Look",
    			offset = 1
    		},

    		{
    			ref = { ui.reference("Misc", "Miscellaneous", "Ping spike") },
    			name = "Ping Spike",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Misc", "Miscellaneous", "Automatic grenade release") },
    			name = "Grenade Release",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Visuals", "Player ESP", "Activation type") },
    			name = "Visuals",
    			offset = 1
    		}
        }

        local active_keys = { }
        local hotkey_modes = { "holding", "toggled", "disabled" }

        local function get_flags()
            return "d"
        end

        local function get_handle()
            local flags = get_flags()
            local existent_keys = { }

            local all_active = false
            local name_width, mode_width = 0, 0

            for i = 1, #all_hotkeys do
                local hotkey = all_hotkeys[i]
                local unique_id = hotkey.ref[1]

                local name = hotkey.name
                local offset = hotkey.offset or 1

                local active = true
                local collected = { }

                for j = 1, offset do
                    collected[j] = hotkey.ref[j]
                end

                for j = 1, offset do
                    if not ui.get(collected[j]) then
                        active = false
                        break
                    end
                end

                if active then
                    existent_keys[unique_id] = true
                    all_active = true
                end

                local _, mode = ui.get(collected[#collected])
                if mode == 0 then goto continue end

                mode = hotkey_modes[mode] or "~"
                mode = merge { "[", mode, "]" }

                if active_keys[unique_id] == nil then
                    active_keys[unique_id] = {
                        alpha = 0,
                        height = 0,

                        name_width = 0,
                        mode_width = 0,

                        name = name,
                        mode = mode
                    }
                end

                local value = active_keys[unique_id] do
                    local name_size = vector(renderer.measure_text(flags, name))
                    local mode_width = vector(renderer.measure_text(flags, mode))

                    value.name = name
                    value.mode = mode

                    value.height = math.max(name_size.y, mode_width.y)

                    value.name_width = name_size.x
                    value.mode_width = mode_width.x
                end

                ::continue::
            end

            for k, v in pairs(active_keys) do
                local active = existent_keys[k] ~= nil

                v.alpha = motion.interp(v.alpha, active, 0.045)

                if v.alpha <= 0 then
                    active_keys[k] = nil
                elseif active or v.alpha >= 0.25 then
                    if name_width < v.name_width then
                        name_width = v.name_width
                    end

                    if mode_width < v.mode_width then
                        mode_width = v.mode_width
                    end
                end
            end

            return active_keys, all_active, name_width, mode_width
        end

        keybinds.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Keybinds")
        : record("visuals", "keybinds::enabled")
        : save()

        keybinds.window = windows.new("##keybinds", 0.025, 0.415)
        keybinds.window:set_size(vector(125, 22))

        function keybinds.frame()
            local me = entity.get_local_player()
            if me == nil then return end

            local window = keybinds.window
            local hotkeys, all_active, name_width, mode_width = get_handle()

            local menu_check = ui.is_menu_open() or (next(hotkeys) ~= nil and all_active)
            local can_show_hotkeys = widgets.enabled:get() and widgets.items:have_key("Keybinds") and menu_check

            alpha = motion.interp(alpha, can_show_hotkeys, 0.045)
            holding = motion.interp(holding, (can_show_hotkeys and window:is_dragging()) and 0.6 or 1.0, 0.045)

            if alpha <= 0 then
                return
            end

            local flags = get_flags()
            local r, g, b = widgets.color_picker:get()

            local a = 255

            local radius = 5
            local thickness = 10

            local offset_ins = vector(10, 5)

            local keyval_gap = 20
            local keyval_rounding = math.floor(radius * .5)

            -- header
            local pos = window.pos

            local text = "keybinds"
            local text_size = vector(renderer.measure_text(flags, text))
            local text_size_base = vector(renderer.measure_text(flags, "\v"))

            width = motion.interp(width, math.max(
                offset_ins.x * 4 + text_size.x * (text_size.y / text_size_base.y),
                keyval_rounding * 2 + name_width + mode_width + keyval_gap,
                125
            ), 0.045)

            local max_width = math.floor(width + 0.85)
            local rect_size = vector(max_width, text_size.y + offset_ins.y * 2)

            if alpha > 0.5 then
                graphics.blur(pos.x, pos.y, rect_size.x, rect_size.y)
            end

            graphics.header(pos.x, pos.y, rect_size.x, 2, 5, r, g, b, a * alpha * holding)
            graphics.glow(pos.x, pos.y, rect_size.x, rect_size.y, r, g, b, a * 0.3 * alpha * holding, thickness, radius)
            graphics.rectangle(pos.x, pos.y, rect_size.x, rect_size.y, 0, 0, 0, 100 * alpha * holding, radius)

            renderer.text(
                pos.x + (rect_size.x - text_size.x) * 0.5,
                pos.y + (rect_size.y - text_size.y) * 0.5,
                255, 255, 255, 255 * alpha * holding,
                flags, 0, text
            )

            -- contents
            local offset = 2

            for _, v in pairs(active_keys) do
                local alpha = alpha * v.alpha
                local text_size, text_alpha = vector(v.name_width, v.height), 0

                if alpha >= 0.25 then
                    text_alpha = math.min(1.0, utils.map(alpha, 0.25, 1.0, 0.0, 1.2))
                end

                local text_position = vector(pos.x + keyval_rounding, pos.y + rect_size.y + 4 + offset)

                local value_start = rect_size.x - v.mode_width
                local value_alpha = utils.map(value_start - v.name_width, 0.0, keyval_gap, 0.0, 1.0, true)

                local h_alpha = text_alpha * holding

                renderer.text(text_position.x, text_position.y, 255, 255, 255, 255 * h_alpha, flags, 0, v.name)
                renderer.text(text_position.x + rect_size.x - keyval_rounding * 2 - v.mode_width, text_position.y, 255, 255, 255, 255 * h_alpha * value_alpha, flags, 0, v.mode)

                offset = offset + text_alpha * (text_size.y + text_size.y * 0.35)
            end

            window:set_size(rect_size)
            window:update()
        end
    end

    do
        local alpha = 0.0
        local align = 0.0

        local damage_alpha = 0.0
        local damage_value = 0.0
        local damage_moving = 0.0
        local damage_holding = 0.0

        local screen = vector(client.screen_size())
        local window = windows.new("##damage", 0.5 + 15 / screen.x, 0.5 - 15 / screen.y)

        window:set_anchor(vector(0.0, 1.0))
        window:set_size(vector(22, 22))

        local features = {
            {
                get = software.is_double_tap,
                text = "DT",
                alpha = 0
            },

            {
                get = software.is_on_shot_antiaim,
                text = "HS",
                alpha = 0
            },

            {
                get = software.is_duck_peek_assist,
                text = "FD",
                alpha = 0
            },

            {
                get = software.is_minimum_damage_override,
                text = "DMG",
                alpha = 0
            }
        }

        local function get_statement()
            if software.is_edge() then
                return 'EDGE'
            end

            if safe_head.get() then
                return "SAFE"
            end

            if localplayer.is_airborne then
                return "AIR"
            end

            if localplayer.is_crouched then
                return "CROUCH"
            end

            if localplayer.is_moving then
                if software.is_slow_motion() then
                    return "S.WALK"
                end

                return "RUN"
            end

            return "STAND"
        end

        ctx_bebra.condition = get_statement

        function indicators.frame()
            local me = entity.get_local_player()
            if me == nil then return end

            local wpn = entity.get_player_weapon(me)
            if wpn == nil then return end

            local wpn_info = csgo_weapons(wpn)
            if wpn_info == nil then return end

            local menu_check = ui.is_menu_open()
            local alive_check = entity.is_alive(me)

            local scoped_check = entity.get_prop(me, "m_bIsScoped")
            local grenade_check = wpn_info.weapon_type_int == 9

            local damage = software.get_minimum_damage()

            local can_show_indicators = widgets.enabled:get() and widgets.items:have_key("Crosshair Indicator") and alive_check
            local can_move_indicators = can_show_indicators and scoped_check == 1

            local can_show_damage = widgets.enabled:get() and widgets.items:have_key("Damage Indicator") and not (wpn_info.weapon_type_int == 0 or wpn_info.weapon_type_int == 9) or menu_check
            local can_move_damage = can_show_damage and menu_check

            alpha = motion.interp(alpha, can_show_indicators and (grenade_check and 0.4 or 1.0) or 0.0, 0.045)
            align = motion.interp(align, can_move_indicators, 0.045)

            damage_alpha = motion.interp(damage_alpha, can_show_damage, 0.045)
            damage_value = motion.interp(damage_value, damage, 0.045)
            damage_moving = motion.interp(damage_moving, can_move_damage, 0.045)
            damage_holding = motion.interp(damage_holding, (can_move_damage and window:is_dragging()) and 0.6 or 1.0, 0.045)

            local flags = "-d"
            local clock = globals.realtime()

            local screen = vector(client.screen_size())
            local center = screen * 0.5

            local r1, g1, b1 = widgets.color_picker:rawget()
            local r2, g2, b2, a2 = 255, 255, 255, 255

            local r, g, b, a = utils.color_lerp(
                r1, g1, b1, 255,
                r2, g2, b2, a2,
                utils.breathe(clock + 0.5 - 0.5 * align)
            )

            -- damage
            if damage_alpha > 0 then
                local value = utils.round(damage_value)
                local text = f("%d", value)

                if damage == 0 then
                    text = "AUTO"
                end

                if value > 100 then
                    text = f("HP +%d", value - 100)
                end

                local measure = vector(renderer.measure_text(flags, text))
                measure.x = measure.x + 1

                local pos = window.pos:clone()
                local rect_size = vector(measure.x + 18, measure.y + 16)

                local text_position = pos:clone()

                text_position.x = text_position.x + (rect_size.x - measure.x) * 0.5
                text_position.y = text_position.y + (rect_size.y - measure.y) * 0.5

                if damage_moving > 0 then
                    graphics.rectangle_outline(pos.x, pos.y, rect_size.x, rect_size.y, 255, 255, 255, 128 * damage_moving * damage_holding, 7)
                end

                local r3, g3, b3 = r, g, b
                if not can_show_indicators then
                    r3 = r1
                    g3 = g1
                    b3 = b1
                end

                renderer.text(text_position.x - 1, text_position.y, r3, g3, b3, a * damage_alpha * damage_holding, flags, 0, text)

                window:set_size(rect_size)
                window:update()
            end

            if alpha <= 0 then
                return
            end

            -- header
            local pos = center:clone()

            pos.x = pos.x + utils.round(10 * align)
            pos.y = pos.y + 20

            do
                local text = "Z E N I T H"

                local measure = vector(renderer.measure_text(flags, text))
                measure.x = measure.x + 1

                local text_position = pos:clone()
                local text_offset = (measure.x * 0.5) * (1 - align)

                text_position.x = text_position.x - utils.round(text_offset)

                -- graphics.glow(text_position.x + 1, text_position.y + 2, measure.x, 4, r, g, b, a * alpha * 0.1, 10, 1)
                -- renderer.rectangle(text_position.x + 1, text_position.y + 2, measure.x, 4, r, g, b, a * alpha * 0.1)

                text = decorations.wave(text, clock, r1, g1, b1, 255, r2, g2, b2, a2)
                graphics.text(text_position.x, text_position.y, r, g, b, a * alpha, flags, 0, text)

                pos.y = pos.y + measure.y
            end

            do
                local text = get_statement()

                local measure = vector(renderer.measure_text(flags, text))
                measure.x = measure.x + 1

                local text_position = pos:clone()
                local text_offset = (measure.x * 0.5) * (1 - align)

                text_position.x = text_position.x - utils.round(text_offset)

                renderer.text(text_position.x, text_position.y, r, g, b, a * alpha, flags, 0, text)
                pos.y = pos.y + measure.y
            end

            for i = 1, #features do
                local feature = features[i]

                local value_check = feature.get()
                local can_show_feature = can_show_indicators and value_check

                feature.alpha = motion.interp(feature.alpha, can_show_feature, 0.045)

                if feature.alpha <= 0 then
                    goto continue
                end

                local text = feature.text
                local alpha = feature.alpha * alpha

                local measure = vector(renderer.measure_text(flags, text))
                measure.x = measure.x + 1

                local text_position = pos:clone()
                local text_offset = (measure.x * 0.5) * (1 - align)

                text_position.x = text_position.x - utils.round(text_offset)

                renderer.text(text_position.x, text_position.y, r, g, b, a * alpha, flags, 0, text)
                pos.y = pos.y + utils.round(measure.y * feature.alpha)

                ::continue::
            end
        end
    end

    do
        local alpha = 0
        local left_alpha = 0
        local right_alpha = 0

        local screen = vector(client.screen_size()) * .5

        function arrows.frame()
            local lp = entity.get_local_player()
            if lp == nil then
                return
            end

            local wpn = entity.get_player_weapon(lp)
            if wpn == nil then return end

            local wpn_info = csgo_weapons(wpn)
            if wpn_info == nil then return end

            local can_show_arrows = manual_direction.enabled:get() and manual_direction.arrows:get() and entity.is_alive(lp)
            local can_move_indicators = can_show_indicators and scoped_check == 1

            alpha = motion.interp(alpha, can_show_arrows and (wpn_info.weapon_type_int == 9 and 0.4 or 1.0) or 0.0, 0.045)
            if alpha <= 0 then
                return
            end

            local r, g, b, a = manual_direction.color:rawget()
            a = 255 * alpha

            local manual_direction = manual_direction.get()

            left_alpha = motion.interp(left_alpha, manual_direction == 0 and 1 or 0, 0.045)
            if left_alpha ~= 0 then
                renderer.text(screen.x - 50, screen.y - 16, r, g, b, a * left_alpha, '+', nil, '<')
            end

            right_alpha = motion.interp(right_alpha, manual_direction == 1 and 1 or 0, 0.045)
            if right_alpha ~= 0 then
                renderer.text(screen.x + 39, screen.y - 16, r, g, b, a * right_alpha, '+', nil, '>')
            end
        end
    end

    do
        local alpha = 0.0
        local holding = 0.0
        local hovering = 0.0

        local function renderer_bar(x, y, w, h, r, g, b, a, pct)
            --graphics.glow(x, y, w, h, r, g, b, a * 0.15, 222, h * 0.5)
            renderer.rectangle(x, y, w, h, 0, 0, 0, a)
            renderer.rectangle(x + 1, y + 1, (w - 2) * pct, h - 2, r, g, b, a)
        end

        velocity_warning.window = windows.new("##velocity_warning", 0.5, 0.3)

        velocity_warning.window:set_anchor(vector(0.5, 0.0))
        velocity_warning.window:set_size(vector(180, 4))

        function velocity_warning.frame()
            local me = entity.get_local_player()
            if me == nil then return end

            local window = velocity_warning.window
            local modifier = entity.get_prop(me, "m_flVelocityModifier")

            local menu_check = ui.is_menu_open()

            local alive_check = entity.is_alive(me)
            local velocity_check = modifier < 1.0

            local is_dragging = window:is_dragging()
            local is_hovering = window:is_hovering()

            local can_show_warning = widgets.enabled:get() and widgets.items:have_key("Velocity Warning") and ((alive_check and velocity_check) or menu_check)

            alpha = motion.interp(alpha, can_show_warning, 0.045)
            holding = motion.interp(holding, (can_show_warning and is_dragging) and 0.6 or 1.0, 0.045)
            hovering = motion.interp(hovering, (can_show_warning and is_hovering and not is_dragging) and 1.0 or 0.0, 0.045)

            if alpha <= 0 then
                return
            end

            if menu_check and (not velocity_check or not alive_check) then
                modifier = math.min(1, globals.tickcount() % 200 / 150)
            end

            local flags = "d"
            local percent = (1 - modifier) * 100

            local r, g, b = widgets.color_picker:get()

            local a = 255

            if modifier < 1.0 then
                r = utils.lerp(255, r, modifier)
                g = utils.lerp(75, g, modifier)
                b = utils.lerp(75, b, modifier)
            end

            -- indication
            local pos = window.pos:clone()
            local size = window.size:clone()

            local text = f("Max velocity was reduced by %d%%", percent)
            local text_size = vector(renderer.measure_text(flags, text))

            renderer.text(
                pos.x + (size.x - text_size.x) * 0.5,
                pos.y,
                255, 255, 255, 255 * alpha * holding,
                flags, 0, text
            )

            pos.y = pos.y + text_size.y
            pos.y = pos.y + 5

            local bar_pos = pos:clone()
            local bar_size = vector(text_size.x + 28, 4)

            renderer_bar(bar_pos.x, bar_pos.y, bar_size.x, bar_size.y, r, g, b, a * alpha * holding, modifier)
            pos.y = pos.y + bar_size.y + 5

            if hovering > 0 then
                renderer.text(
                    pos.x,
                    pos.y,
                    255, 255, 255, 255 * alpha * hovering,
                    flags, 0, "Press M2 to center."
                )
            end

            local window_size = vector(math.max(text_size.x, bar_size.x), text_size.y + bar_size.y + 5)

            if is_hovering and not is_dragging and client.key_state(0x02) then
                local screen = vector(client.screen_size())

                window:set_pos(vector(
                    (screen.x - size.x) * 0.5,
                    window.pos.y
                ))
            end

            window:set_size(window_size)
            window:update()
        end
    end

    do
        custom_scope.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Custom Scope Overlay")
        : record("aa", "custom_scope::enabled")
        : save()

        custom_scope.color = menu.new_item(ui.new_color_picker, "AA", "Anti-aimbot angles", "Color", 255, 255, 255, 255)
        : record("aa", "custom_scope::color")
        : save()

        custom_scope.mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "Mode", { 'Default', 'T' })
        : record("aa", "custom_scope::mode")
        : save()

        custom_scope.position = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nPosition", 0, 500, 50, true, 'px')
        : record("aa", "custom_scope::position")
        : save()

        custom_scope.offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "\nOffset", 0, 500, 10, true, 'px')
        : record("aa", "custom_scope::offset")
        : save()

        local alpha = 0
        client.set_event_callback('paint_ui', function ()
            ui.set(software.visuals.scope_overlay, true)
        end)

        client.set_event_callback('paint', function ()
            if not custom_scope.enabled:get() then
                return
            end

            ui.set(software.visuals.scope_overlay, false)

            local lp = entity.get_local_player()
            if lp == nil then
                return
            end

            local width, height = client.screen_size()
            local offset, position = custom_scope.offset:get() * height / 1080, custom_scope.position:get() * height / 1080

            local condition = entity.get_prop(lp, 'm_bIsScoped') == 1 and entity.get_prop(lp, 'm_bResumeZoom') == 0
            alpha = motion.interp(alpha, condition, 0.045)
            if alpha < 0.001 then
                return
            end

            local clr = { custom_scope.color:rawget() }

            local clr1 = { clr[1], clr[2], clr[3], 0 }
            local clr2 = { clr[1], clr[2], clr[3], clr[4] * alpha }
            local mode = custom_scope.mode:get()

            if mode ~= 'T' then
                renderer.gradient(
                    width / 2, height / 2 - position + 2,
                    1, position - offset,
                    clr1[1], clr1[2], clr1[3], clr1[4],
                    clr2[1], clr2[2], clr2[3], clr2[4],
                    false
                )
            end

            renderer.gradient(
                width / 2, height / 2 + offset,
                1, position - offset,
                clr2[1], clr2[2], clr2[3], clr2[4],
                clr1[1], clr1[2], clr1[3], clr1[4],
                false
            )

            renderer.gradient(
                width / 2 - position + 2, height / 2,
                position - offset, 1,
                clr1[1], clr1[2], clr1[3], clr1[4],
                clr2[1], clr2[2], clr2[3], clr2[4],
                true
            )

            renderer.gradient(
                width / 2 + offset, height / 2,
                position - offset, 1,
                clr2[1], clr2[2], clr2[3], clr2[4],
                clr1[1], clr1[2], clr1[3], clr1[4],
                true
            )
        end)

        defer(function ()
            ui.set_visible(software.visuals.scope_overlay, true)
        end)
    end
end)()

do

    defer(function ()
    end)
end

do
    anim_breakers.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Animation Breakers")
    : record("aa", "anim_breakers::enabled")
    : save()

    anim_breakers.ground = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", '- Leg Movement', { "Default", 'Static', 'Walking' })
    : record("aa", "anim_breakers::ground")
    : save()

    anim_breakers.air = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", '- In Air', { "Default", 'Static', 'Walking' })
    : record("aa", "anim_breakers::air")
    : save()

    local native_GetClientEntity = vtable_bind('client.dll', 'VClientEntityList003', 3, 'void*(__thiscall*)(void*, int)')

    local char_ptr = ffi.typeof('char*')
    local nullptr = ffi.new('void*')
    local class_ptr = ffi.typeof('void***')

    local animation_layer_t = ffi.typeof([[
        struct {										char pad0[0x18];
            uint32_t	sequence;
            float		prev_cycle;
            float		weight;
            float		weight_delta_rate;
            float		playback_rate;
            float		cycle;
            void		*entity;						char pad1[0x4];
        } **
    ]])

    client.set_event_callback('net_update_end', function ()
        if not anim_breakers.enabled:get() then
            override.unset(software.aa.other.leg_movement)
            return
        end

        local lp = entity.get_local_player()
        if lp == nil then
            return
        end

        local player_ptr = ffi.cast(class_ptr, native_GetClientEntity(lp))
        if player_ptr == nullptr then
            return
        end

        local anim_layers = ffi.cast(animation_layer_t, ffi.cast(char_ptr, player_ptr) + 0x2990)[0]

        do
            local mode = anim_breakers.ground:get()
            if mode ~= 'Disabled' then
                if mode == 'Static' then
                    entity.set_prop(lp, 'm_flPoseParameter', 1, 0)
                    override.set(software.aa.other.leg_movement, 'Always slide')
                elseif mode == 'Walking' then
                    entity.set_prop(lp, 'm_flPoseParameter', 0.5, 7)
                    override.set(software.aa.other.leg_movement, 'Never slide')
                end
            else
                override.unset(software.aa.other.leg_movement)
            end
        end

        do
            local mode = anim_breakers.air:get()
            if mode ~= 'Disabled' and ctx_bebra.condition() == 'AIR' then
                if mode == 'Static' then
                    entity.set_prop(lp, 'm_flPoseParameter', 1, 6)
                elseif mode == 'Walking' then
                    anim_layers[6]['weight'] = 1
                end
            end
        end
    end)
end

do
    local function set_custom_list(ctx, list)
        if list.pitch ~= nil then
            ctx.pitch = list.pitch:get()
            ctx.pitch_offset = list.pitch_offset:get()
        end

        if list.yaw_base ~= nil then
            ctx.yaw_base = list.yaw_base:get()
        end

        ctx.yaw = list.yaw:get()
        ctx.yaw_offset = list.yaw_offset:get()

        if ctx.yaw == "180 LR" then
            ctx.yaw_offset = 0
        end

        ctx.yaw_180lr_mode = list.yaw_180lr_mode:get()
        ctx.yaw_delay = list.yaw_delay:get()
        ctx.yaw_left = list.yaw_left:get()
        ctx.yaw_right = list.yaw_right:get()

        ctx.yaw_jitter = list.yaw_jitter:get()
        ctx.jitter_mode = list.jitter_mode:get()
        ctx.zenith_cycle = list.zenith_cycle:get()
        ctx.zenith_delay = list.zenith_delay:get()
        ctx.zenith_safe = list.zenith_safe:get()
        ctx.jitter_offset = list.jitter_offset:get()
        ctx.jitter_randomization = list.jitter_randomization:get()

        ctx.body_yaw = list.body_yaw:get()
        ctx.body_yaw_offset = list.body_yaw_offset:get()
        ctx.freestanding_body_yaw = list.freestanding_body_yaw:get()
    end

    angles.type = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "Anti Aim Builder", {
        "Off",
        "Custom",
        "Recommended"
    })
    : record("aa", "angles::type")
    : save()

    local conds = { 'Standing', 'Moving', 'Slow Walk', 'Crouched', 'Move Crouched', 'Air', 'Air Crouched', 'Fake Lag'}

    local function reset_delay()
        for _, condition in next, conds do
            delay_data_all[condition] = {
                ticks = 0,
                is_active = false,
                current = 0,
                previous_angle = 0
            }
        end
    end

    reset_delay()

    angles.custom = { } do
        angles.custom.state = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "State", { unpack(e_statement, 0) })
        : record("aa", "custom::state")

        for i = 0, #e_statement do
            local list = { }
            local state = e_statement[i]

            if i ~= 0 then
                list.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", merge { "Enable", "\x20", state })
                : record("aa", merge { "custom", "::", state, "::", "enabled" })
                : save()
            end

            if i ~= 10 then
                local pitch_list = { "Off", "Default", "Up", "Down", "Minimal", "Random", "Custom" }

                list.pitch = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "Pitch", "\n", "custom_", "pitch_", state }, pitch_list)
                : record("aa", merge { "custom", "::", state, "::", "pitch" })
                : save()

                list.pitch_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "\n", "custom_", "pitch_offset_", state }, -89, 89, 0, true, "°")
                : record("aa", merge { "custom", "::", state, "::", "pitch_offset" })
                : save()

                list.yaw_base = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "Yaw base", "\n", "custom_", "yaw_base_", state }, { "Local view", "At targets" })
                : record("aa", merge { "custom", "::", state, "::", "yaw_base" })
                : save()
            end

            list.yaw = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "Yaw", "\n", "custom_", "yaw_", state }, { "Off", "180", "Spin", "Static", "180 Z", "Crosshair", "180 LR" })
            : record("aa", merge { "custom", "::", state, "::", "yaw" })
            : save()

            list.yaw_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "\n", "custom_", "yaw_offset_", state }, -180, 180, 0, true, "°")
            : record("aa", merge { "custom", "::", state, "::", "yaw_offset" })
            : save()

            list.yaw_180lr_mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "\n", "custom_", "yaw_180lr_mode_", state }, { "Side based", "Switch delay" })
            : record("aa", merge { "custom", "::", state, "::", "yaw_180lr_mode" })
            : save()

            list.yaw_left = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "Left offset", "\n", "custom_", "yaw_left_", state }, -180, 180, 0, true, "°")
            : record("aa", merge { "custom", "::", state, "::", "yaw_left" })
            : save()

            list.yaw_right = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "Right offset", "\n", "custom_", "yaw_right_", state }, -180, 180, 0, true, "°")
            : record("aa", merge { "custom", "::", state, "::", "yaw_right" })
            : save()

            list.yaw_delay = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "Delay", "\n", "custom_", "Delay_", state }, 2, 10, 5, true, "t")
            : record("aa", merge { "custom", "::", state, "::", "yaw_delay" })
            : save()

            list.yaw_jitter = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "Yaw jitter", "\n", "custom_", "yaw_jitter_", state }, { "Off", "Offset", "Center", "Random", "Skitter", "Zenith" })
            : record("aa", merge { "custom", "::", state, "::", "yaw_jitter" })
            : save()

            list.jitter_mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "\n", "custom_", "jitter_mode_", state }, { "2-Way", "3-Way", "5-Way", "7-Way", "Chaos" })
            : record("aa", merge { "custom", "::", state, "::", "jitter_mode" })
            : save()

            list.jitter_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "\nJitter offset", "\n", "custom_", "jitter_offset_", state }, -180, 180, 0, true, "°")
            : record("aa", merge { "custom", "::", state, "::", "jitter_offset" })
            : save()

            list.jitter_randomization = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "Randomization", "\n", "custom_", "jitter_randomization_", state }, 0, 180, 0, true, "°", 1, { [0] = "Off" })
            : record("aa", merge { "custom", "::", state, "::", "jitter_randomization" })
            : save()

            list.zenith_cycle = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "Delay Cycle", "\n", "custom_", "delay_cycle_", state }, 5, 200, 50, true, '', 1, { [5] = "Off" })
            : record("aa", merge { "custom", "::", state, "::", "zenith_cycle" })
            : save()

            list.zenith_delay = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "Delay Time", "\n", "custom_", "zenith_delay", state }, 5, 30, 15)
            : record("aa", merge { "custom", "::", state, "::", "zenith_delay" })
            : save()

            list.zenith_safe = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", merge { "Safe Yaw", "\n", "custom_", "safe_yaw_", state })
            : record("aa", merge { "custom", "::", state, "::", "zenith_safe" })
            : save()

            list.body_yaw = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", merge { "Body yaw", "\n", "custom_", "body_yaw_", state }, { "Off", "Opposite", "Jitter", "Static", "Randomize Jitter", "Ghost", "Ghost" })
            : record("aa", merge { "custom", "::", state, "::", "body_yaw" })
            : save()

            list.body_yaw_offset = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", merge { "\n", "custom_", "body_yaw_offset_", state }, -180, 180, 0, true, "°")
            : record("aa", merge { "custom", "::", state, "::", "body_yaw_offset" })
            : save()

            list.freestanding_body_yaw = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", merge { "Freestanding body yaw", "\n", "custom_", "freestanding_body_yaw_", state })
            : record("aa", merge { "custom", "::", state, "::", "freestanding_body_yaw" })
            : save()

            list.zenith_safe:set_callback(reset_delay)
            list.zenith_delay:set_callback(reset_delay)
            list.zenith_cycle:set_callback(reset_delay)

            angles.custom[state] = list
        end
    end

    angles.recommended = {
        ['Standing'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180'
            ctx.yaw_offset = 14
            ctx.yaw_jitter = 'Zenith'
            ctx.jitter_mode = '7-Way'  -- 7-way is harder to resolve than 3-way
            ctx.jitter_offset = 48
            ctx.jitter_randomization = 32
            ctx.zenith_cycle = 20
            ctx.zenith_delay = 14
            ctx.zenith_safe = true
            ctx.body_yaw = 'Ghost'  -- body yaw lies about real side
            ctx.body_yaw_offset = -180
            ctx.freestanding_body_yaw = true
        end,

        ['Moving'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180 LR'
            ctx.yaw_180lr_mode = 'Switch delay'
            ctx.yaw_offset = 8
            ctx.yaw_jitter = 'Zenith'
            ctx.jitter_mode = '2-Way'
            ctx.jitter_offset = 55
            ctx.jitter_randomization = 22
            ctx.zenith_cycle = 18
            ctx.zenith_delay = 12
            ctx.zenith_safe = true
            ctx.body_yaw = 'Randomize Jitter'
            ctx.body_yaw_offset = -45
        end,

        ['Slow Walk'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180'
            ctx.yaw_offset = 5
            ctx.yaw_jitter = 'Zenith'
            ctx.jitter_mode = 'Chaos'  -- Chaos = non-repeating pattern
            ctx.jitter_offset = 72
            ctx.jitter_randomization = 38
            ctx.zenith_cycle = 12
            ctx.zenith_delay = 8
            ctx.zenith_safe = true
            ctx.body_yaw = 'Ghost'
            ctx.body_yaw_offset = -180
            ctx.freestanding_body_yaw = true
        end,

        ['Crouched'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180'
            ctx.yaw_offset = 10
            ctx.yaw_jitter = 'Zenith'
            ctx.jitter_mode = '7-Way'
            ctx.jitter_offset = 68
            ctx.jitter_randomization = 34
            ctx.zenith_cycle = 18
            ctx.zenith_delay = 14
            ctx.zenith_safe = true
            ctx.body_yaw = 'Ghost'
            ctx.body_yaw_offset = -180
            ctx.freestanding_body_yaw = true
        end,

        ['Move Crouched'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180'
            ctx.yaw_offset = 6
            ctx.yaw_jitter = 'Zenith'
            ctx.jitter_mode = 'Chaos'
            ctx.jitter_offset = 60
            ctx.jitter_randomization = 28
            ctx.zenith_cycle = 14
            ctx.zenith_delay = 10
            ctx.zenith_safe = true
            ctx.body_yaw = 'Ghost'
            ctx.body_yaw_offset = -180
        end,

        ['Air'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180 LR'
            ctx.yaw_180lr_mode = 'Switch delay'
            ctx.yaw_offset = 4
            ctx.yaw_jitter = 'Skitter'
            ctx.jitter_mode = '5-Way'
            ctx.jitter_offset = 44
            ctx.jitter_randomization = 24
            ctx.body_yaw = 'Ghost'
            ctx.body_yaw_offset = -180
            ctx.freestanding_body_yaw = true
        end,

        ['Air Crouched'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180 LR'
            ctx.yaw_180lr_mode = 'Switch delay'
            ctx.yaw_offset = 4
            ctx.yaw_jitter = 'Skitter'
            ctx.jitter_mode = '5-Way'
            ctx.jitter_offset = 44
            ctx.jitter_randomization = 24
            ctx.body_yaw = 'Ghost'
            ctx.body_yaw_offset = -180
            ctx.freestanding_body_yaw = true
        end,

        ['Fake Lag'] = function (ctx)
            ctx.pitch = 'Default'
            ctx.yaw_base = 'At targets'
            ctx.yaw = '180'
            ctx.yaw_offset = 0
            ctx.yaw_jitter = 'Zenith'
            ctx.jitter_mode = '7-Way'
            ctx.jitter_offset = 38
            ctx.jitter_randomization = 22
            ctx.zenith_cycle = 10
            ctx.zenith_delay = 8
            ctx.zenith_safe = false
            ctx.body_yaw = 'Ghost'
            ctx.body_yaw_offset = -180
            ctx.freestanding_body_yaw = true
        end
    }

    function angles.set(ctx, state)
        if angles.type:get() == "Custom" then
            local list = angles.custom[state]

            if list ~= nil then
                -- if not enabled in menu
                if list.enabled ~= nil then
                    if not list.enabled:get() then
                        return false
                    end
                end

                set_custom_list(ctx, list)
                return true
            end

            return false
        end

        if angles.type:get() == "Recommended" then
            local fn = angles.recommended[state]

            if fn ~= nil then
                fn(ctx)
                return true
            end

            return false
        end

        return false
    end

    function angles.update(ctx)
        local list = statement.get()

        for i = #list, 1, -1 do
            local state = list[i]

            if angles.set(ctx, state) then
                return
            end
        end

        angles.set(ctx, "Main")
    end
end

do

    yaw_direction.edge_yaw = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", merge { "Edge Yaw", "\n", "yaw_direction::edge_yaw" })
    : record("aa", "yaw_direction::edge_yaw")

    yaw_direction.freestanding = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", merge { "Freestanding", "\n", "yaw_direction::freestanding" })
    : record("aa", "yaw_direction::freestanding")

    fs_disablers.states = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- Disable On", "\n", "fs_disablers::states" }, {"Standing", "Moving", "Slow Walk", "Crouched", "Air" })
    : record("aa", "fs_disablers::states")
    : save()

    function yaw_direction.update(ctx)
        if not aa_tweaks.enable:get() then
            return
        end

        if aa_tweaks.items:have_key('Edge Yaw on FD') and software.is_duck_peek_assist() then
            ctx.edge_yaw = true, 1
        else
            ctx.edge_yaw = yaw_direction.edge_yaw:rawget()
        end

        ctx.freestanding = yaw_direction.freestanding:rawget()
    end
end

do
    local function get_statement()
        if localplayer.is_airborne then
            return "Air"
        end

        if localplayer.is_crouched then
            return "Crouched"
        end

        if localplayer.is_moving then
            if software.is_slow_motion() then
                return "Slow Walk"
            end

            return "Moving"
        end

        return "Standing"
    end

    function fs_disablers.update(ctx)
        local state = get_statement()
        if state == nil then
            return
        end

        if not fs_disablers.states:have_key(state) then
            return
        end

        ctx.freestanding = false
    end
end

--- clientside nickname
do
    clientside_nickname.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Client-Side Nickname")
    : record("visuals", "clientside_nickname::enabled")
    : save()

    clientside_nickname.nickname = menu.new_item(ui.new_textbox, "AA", "Anti-aimbot angles", "Nickname")
    : record("visuals", "clientside_nickname::nickname")
    : save()

    local panorama = panorama.open()

    local native_BaseLocalClient_base = ffi.cast("uintptr_t**", memory.pattern_scan("engine.dll", "A1 ? ? ? ? 0F 28 C1 F3 0F 5C 80 ? ? ? ? F3 0F 11 45 ? A1 ? ? ? ? 56 85 C0 75 04 33 F6 EB 26 80 78 14 00 74 F6 8B 4D 08 33 D2 E8 ? ? ? ? 8B F0 85 F6", 1))

    local player_info_t = ffi.typeof([[
        struct {
            int64_t         unknown;
            int64_t         steamID64;
            char            szName[128];
            int             userId;
            char            szSteamID[20];
            char            pad_0x00A8[0x10];
            unsigned long   iSteamID;
            char            szFriendsName[128];
            bool            fakeplayer;
            bool            ishltv;
            unsigned int    customfiles[4];
            unsigned char   filesdownloaded;
        }
    ]])

    local native_GetStringUserData = vtable_thunk(11, ffi.typeof("$*(__thiscall*)(void*, int, int*)", player_info_t))

    local previous_name
    local function apply_nickname(name)
        local local_player = entity.get_local_player()
        if not local_player then
            return
        end

        local native_BaseLocalClient = native_BaseLocalClient_base[0][0]
        if not native_BaseLocalClient then
            return
        end

        local native_UserInfoTable = ffi.cast("void***", native_BaseLocalClient + 0x52C0)[0]
        if not native_UserInfoTable then
            return
        end

        local data = native_GetStringUserData(native_UserInfoTable, local_player - 1, nil)
        if not data then
            return
        end

        local this_name = ffi.string(data[0].szName)
        if name ~= this_name and previous_name == nil then
            previous_name = this_name
        end

        data[0].szName = ffi.new("char[128]", name)
    end

    local was_applied = false
    local function callback()
        local chosen_nick = ui.get(clientside_nickname.nickname:get_ref()):sub(0, 32)
        clientside_nickname.nickname:set(chosen_nick)

        if not clientside_nickname.enabled:get() or #chosen_nick == 0 then
            if was_applied then
                was_applied = false
                apply_nickname(previous_name or panorama["MyPersonaAPI"]["GetName"]())
                previous_name = nil
            end

            return
        end

        was_applied = true

        apply_nickname(chosen_nick)
    end

    clientside_nickname.apply = menu.new_item(ui.new_button, "AA", "Anti-aimbot angles", "Apply", callback)
    : record("visuals", "clientside_nickname::apply")

    clientside_nickname.enabled:set_callback(callback)

    client.set_event_callback('round_prestart', callback)
    client.set_event_callback('player_connect_full', callback)

    callback()
end

-- --- tab to game
-- do
--     tab_to_game.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Tab to Game")
--     : record("visuals", "tab_to_game::enabled")
--     : save()

--     local api_ShowWindow          = memory.get_export("user32.dll", "ShowWindow", "int(__fastcall*)(unsigned int, unsigned int, void*, int)")
--     local api_GetForegroundWindow = memory.get_export("user32.dll", "GetForegroundWindow", "int(__fastcall*)(unsigned int, unsigned int)")
--     local api_SetForegroundWindow = memory.get_export("user32.dll", "SetForegroundWindow", "int(__fastcall*)(unsigned int, unsigned int, void*)")

--     local csgo_hwnd_raw = memory.pattern_scan("engine.dll", "8B 0D ? ? ? ? 85 C9 74 16 8B 01 8B")
--     local hwnd = ffi.cast("void*", ((ffi.cast("uintptr_t***", ffi.cast("uintptr_t", csgo_hwnd_raw) + 2)[0])[0] + 2)[0])

--     local function show_window()
--         api_ShowWindow(hwnd, 3)
--         api_SetForegroundWindow(hwnd)
--     end

--     function tab_to_game.round_prestart()
--         if tab_to_game.enabled:get() then
--             show_window()
--         end
--     end
-- end

--- hit marker zenith [fancy]
do
    -- ── tunables ────────────────────────────────────────────────────────────
    local MARKER_LIFETIME    = 3.2   -- seconds on screen
    local FLOAT_TOTAL        = 68    -- total px drifted upward over lifetime
    local SLIDE_AMOUNT       = 9     -- px of horizontal slide-in on spawn
    local POP_DURATION       = 0.28  -- seconds of scale-pop on spawn
    local POP_SCALE          = 2.0   -- peak scale multiplier at spawn
    local GLOW_PASSES        = 4     -- concentric glow layers
    local GLOW_MAX_SPREAD    = 4     -- px radius of outermost glow layer
    local OUTLINE_OFFSETS    = { {1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,-1},{1,-1},{-1,1} }

    -- ── helpers ─────────────────────────────────────────────────────────────
    local function ease_out_cubic(t)
        local u = 1 - t
        return 1 - u * u * u
    end

    -- damage → colour tier
    local function damage_color(dmg, is_head, accent_r, accent_g, accent_b)
        if is_head then
            return accent_r, accent_g, accent_b   -- accent colour for headshots
        elseif dmg >= 90 then
            return 255, 60,  60    -- near-lethal: vivid red
        elseif dmg >= 60 then
            return 255, 140, 40    -- high: orange
        elseif dmg >= 30 then
            return 255, 220, 80    -- medium: yellow
        else
            return 220, 220, 220   -- low: grey-white
        end
    end

    -- hitgroup prefix icon
    local function hitgroup_prefix(hg)
        if hg == 1 then return "[HS] " end
        if hg == 8 then return "[NK] " end
        return ""   -- no prefix for body shots
    end

    -- ── state ───────────────────────────────────────────────────────────────
    local ctx = { target = 0, pos = vector(), hitgroup = 0 }
    local pending_markers = {}

    -- marker table layout:
    --  [1] = world pos (vector)
    --  [2] = display string
    --  [3] = expiry time
    --  [4] = r, g, b (colour)
    --  [5] = spawn_x offset (for slide-in)
    --  [6] = spawn_time

    -- ── frame ───────────────────────────────────────────────────────────────
    function hit_marker.frame()
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Damage Marker') then return end

        local realtime = globals.realtime()
        local ar, ag, ab = widgets.color_picker:rawget()

        local i = 1
        while i <= #pending_markers do
            local m    = pending_markers[i]
            local diff = m[3] - realtime

            if diff <= 0 then
                table.remove(pending_markers, i)
            else
                local age      = MARKER_LIFETIME - diff          -- seconds since spawn
                local t        = age / MARKER_LIFETIME           -- 0→1 normalised
                local ease_t   = ease_out_cubic(t)

                -- ── position ──────────────────────────────────────────────
                local wx, wy = renderer.world_to_screen(m[1].x, m[1].y, m[1].z)
                if wx then
                    local y_off   = ease_t * FLOAT_TOTAL
                    local x_slide = m[5] * (1 - ease_out_cubic(math.min(age / 0.12, 1)))
                    local px      = wx + x_slide
                    local py      = wy - y_off

                    -- ── alpha ─────────────────────────────────────────────
                    local fade_start = 0.72   -- fade begins at 72% of lifetime
                    local alpha
                    if t < fade_start then
                        alpha = 1.0
                    else
                        alpha = 1.0 - (t - fade_start) / (1.0 - fade_start)
                        alpha = math.max(0, alpha)
                    end

                    -- ── scale pop ─────────────────────────────────────────
                    -- simulated by choosing font flag "d" (larger) vs "" (normal)
                    -- and adjusting the y slightly so it feels like it shrinks in
                    local pop_t    = math.min(age / POP_DURATION, 1)
                    local pop_ease = ease_out_cubic(pop_t)
                    local scale_v  = POP_SCALE - (POP_SCALE - 1) * pop_ease   -- POP_SCALE→1
                    -- offset upward so it appears to shrink toward centre
                    local pop_y_nudge = -(scale_v - 1) * 6
                    py = py + pop_y_nudge

                    local ia   = math.floor(255 * alpha)
                    local r, g, b = m[4][1], m[4][2], m[4][3]
                    local txt  = m[2]

                    -- ── glow passes ───────────────────────────────────────
                    for pass = GLOW_PASSES, 1, -1 do
                        local spread   = math.floor(GLOW_MAX_SPREAD * (pass / GLOW_PASSES))
                        local glow_a   = math.floor(ia * 0.18 * (1 - (pass - 1) / GLOW_PASSES))
                        if spread > 0 and glow_a > 0 then
                            for _, off in ipairs(OUTLINE_OFFSETS) do
                                renderer.text(
                                    px + off[1] * spread,
                                    py + off[2] * spread,
                                    r, g, b, glow_a, "c", nil, txt
                                )
                            end
                        end
                    end

                    -- ── hard outline (1px, 8-direction) ──────────────────
                    local outline_a = math.floor(ia * 0.75)
                    for _, off in ipairs(OUTLINE_OFFSETS) do
                        renderer.text(px + off[1], py + off[2], 0, 0, 0, outline_a, "c", nil, txt)
                    end

                    -- ── main text ─────────────────────────────────────────
                    renderer.text(px, py, r, g, b, ia, "c", nil, txt)

                    -- ── accent bar under headshot numbers ─────────────────
                    if m[4][4] then   -- flag: is headshot
                        local bar_a = math.floor(ia * 0.7 * (1 - t * t))
                        local bar_w = 18
                        renderer.rectangle(math.floor(px - bar_w*0.5), py + 12,
                            bar_w, 2, ar, ag, ab, bar_a)
                    end
                end

                i = i + 1
            end
        end
    end

    -- ── aim_fire ────────────────────────────────────────────────────────────
    function hit_marker.aim_fire(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Damage Marker') then return end
        ctx.target   = e.target
        ctx.pos      = vector(e.x, e.y, e.z)
        ctx.hitgroup = e.hitgroup or 0
    end

    -- ── aim_hit ─────────────────────────────────────────────────────────────
    function hit_marker.aim_hit(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Damage Marker') then return end

        if ctx.target ~= e.target then return end

        local dmg     = e.damage or 0
        local hg      = e.hitgroup or ctx.hitgroup or 0
        local is_head = (hg == 1)
        local ar, ag, ab = widgets.color_picker:rawget()
        local r, g, b = damage_color(dmg, is_head, ar, ag, ab)

        local prefix = hitgroup_prefix(hg)
        local label  = prefix .. tostring(dmg)

        -- small random horizontal slide direction so stacked markers separate
        local slide_dir = (math.random(0, 1) == 0) and -SLIDE_AMOUNT or SLIDE_AMOUNT

        local MAX_MARKERS = 12
        if #pending_markers >= MAX_MARKERS then
            table.remove(pending_markers, 1)
        end

        table.insert(pending_markers, {
            ctx.pos,
            label,
            globals.realtime() + MARKER_LIFETIME,
            { r, g, b, is_head },   -- [4] colour + headshot flag
            slide_dir,              -- [5] slide offset
            globals.realtime(),     -- [6] spawn time
        })
    end

    -- ── round reset ─────────────────────────────────────────────────────────
    function hit_marker.round_prestart()
        table.clear(pending_markers)
    end
end

do
    -- ── default line pool ─────────────────────────────────────────────
    local _ks_default = {
        'ez', 'L', 'ratio', 'skill issue', 'get recked',
        'not even close', 'uninstall', 'LOL', 'ggez', 'trash',
        'outplayed', 'cry about it', 'too easy', 'go next',
        'rekt', 'kys', 'mad?', 'sit', 'done', 'bye',
        'no shot', 'clean', 'diff', 'pack it up',
        'u good?', 'next', 'lmao', 'terrible', 'W',
        'bro really tried', 'stay down', 'touch grass',
    }

    local _ks_awp = {
        'awp diff', 'big green W', 'one shot wonder',
        'did u even see that coming', 'click click dead',
        'scoped in on ur soul', 'bolt action diff',
    }

    local _ks_multi = {
        'double', 'two for one', 'double tap diff',
        'cluttered', 'they came in pairs', 'buy better positions',
        'RAMPAGE', 'stop feeding', 'ace incoming',
    }

    local _ks_rapid_kills = 0
    local _ks_last_kill_t = 0

    -- ── headshot-specific pool ────────────────────────────────────────
    local _ks_headshot = {
        'headshot :)', 'one tap', 'clean hs', 'aim diff',
        'right in the head', 'nailed it', 'boom headshot',
    }

    -- ── knife-specific pool ───────────────────────────────────────────
    local _ks_knife = {
        'knifed lol', 'put the gun away', 'knife diff',
        'too close for bullets', 'get baited',
    }

    -- ── menu items ────────────────────────────────────────────────────
    local ks_enabled = menu.new_item(ui.new_checkbox, 'AA', 'Anti-aimbot angles', 'Killsay')
        :record('misc', 'killsay::enabled'):save()

    local ks_mode = menu.new_item(ui.new_combobox, 'AA', 'Anti-aimbot angles',
        merge { 'Killsay Mode', '\n', 'killsay::mode' },
        { 'Default', 'Headshot Aware', 'Knife Aware', 'All Aware' })
        :record('misc', 'killsay::mode'):save()

    local ks_custom_en = menu.new_item(ui.new_checkbox, 'AA', 'Anti-aimbot angles', 'Custom Lines')
        :record('misc', 'killsay::custom_en'):save()

    local ks_custom = menu.new_item(ui.new_textbox, 'AA', 'Anti-aimbot angles', 'Custom Line')
        :record('misc', 'killsay::custom'):save()

    local ks_cooldown = menu.new_item(ui.new_slider, 'AA', 'Anti-aimbot angles',
        merge { 'Cooldown', '\n', 'killsay::cooldown' },
        1, 30, 4, true, 's')
        :record('misc', 'killsay::cooldown'):save()

    local ks_chance = menu.new_item(ui.new_slider, 'AA', 'Anti-aimbot angles',
        merge { 'Send Chance', '\n', 'killsay::chance' },
        1, 100, 75, true, '%')
        :record('misc', 'killsay::chance'):save()

    -- ── state ─────────────────────────────────────────────────────────
    local _ks_last_time  = 0
    local _ks_kill_queue = {}   -- { is_headshot, is_knife }

    -- ── pick a line ───────────────────────────────────────────────────
    local function _ks_pick(is_headshot, is_knife, is_awp, mode)
        -- custom line overrides everything if enabled
        local custom_en = ks_custom_en and ks_custom_en:get()
        if custom_en then
            local ok, txt = pcall(ui.get, ks_custom.ref)
            if ok and txt and txt ~= '' then return txt end
        end

        -- multi-kill pool: 3+ kills in 8 seconds
        local now = globals.realtime()
        if now - _ks_last_kill_t < 8 then
            _ks_rapid_kills = _ks_rapid_kills + 1
        else
            _ks_rapid_kills = 1
        end
        _ks_last_kill_t = now
        if _ks_rapid_kills >= 3 then
            return _ks_multi[math.random(#_ks_multi)]
        end

        local pool = _ks_default
        if mode == 'Headshot Aware' and is_headshot then
            pool = _ks_headshot
        elseif mode == 'Knife Aware' and is_knife then
            pool = _ks_knife
        elseif mode == 'All Aware' then
            if is_headshot      then pool = _ks_headshot
            elseif is_knife     then pool = _ks_knife
            elseif is_awp       then pool = _ks_awp
            end
        end

        return pool[math.random(#pool)]
    end

    -- ── player_death: queue the kill ─────────────────────────────────
    client.set_event_callback('player_death', function(e)
        if not ks_enabled:get() then return end

        local me = entity.get_local_player()
        if not me then return end
        if client.userid_to_entindex(e.attacker) ~= me then return end

        -- don't say on own team
        local victim = client.userid_to_entindex(e.userid)
        if victim and not entity.is_enemy(victim) then return end

        -- weapon check
        local wpn     = entity.get_player_weapon(me)
        local wpn_id  = wpn and bit.band(entity.get_prop(wpn,'m_iItemDefinitionIndex') or 0, 0xFFFF) or 0
        local cls     = wpn and entity.get_classname(wpn) or ''
        local is_knife = cls:find('knife') ~= nil
        local is_awp   = wpn_id == 9 or wpn_id == 11 or wpn_id == 38  -- awp/auto

        table.insert(_ks_kill_queue, {
            is_headshot = e.headshot == true,
            is_knife    = is_knife,
            is_awp      = is_awp,
        })
    end)

    -- ── paint_ui: flush queue with cooldown + chance ─────────────────
    client.set_event_callback('paint_ui', function()
        if not ks_enabled:get() then
            _ks_kill_queue = {}
            return
        end
        if #_ks_kill_queue == 0 then return end

        local now = globals.realtime()
        if now - _ks_last_time < ks_cooldown:get() then return end

        -- chance roll
        if math.random(100) > ks_chance:get() then
            table.remove(_ks_kill_queue, 1)
            return
        end

        local kill  = table.remove(_ks_kill_queue, 1)
        local mode  = ks_mode:get()
        local line  = _ks_pick(kill.is_headshot, kill.is_knife, kill.is_awp, mode)

        if line and line ~= '' then
            client.exec('say ' .. line)
            _ks_last_time = now
        end
    end)

    -- ── expose show helper for Misc page ─────────────────────────────
    _G.__killsay = {
        enabled      = ks_enabled,
        mode         = ks_mode,
        custom_en    = ks_custom_en,
        custom       = ks_custom,
        cooldown     = ks_cooldown,
        chance       = ks_chance,
    }
end

do
    shared.enabled = menu.new_item(ui.new_checkbox, 'AA', 'Anti-aimbot angles', 'Shared Logo')
    :record('settings', 'shared::enabled')
    :save()

    shared.socket = nil
    shared.data = { }
    shared.icon_data = { }
    shared.link = "wss://zenith.dev/ws"
    shared.failed_connections = 0

    local scoreboard = panorama.loadstring([[
        let _get_xuid = function(entity_index) {
            let xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex(entity_index);
            return xuid;
        }

        let _set_icon = function(entity_index, icon) {
            let xuid = GameStateAPI.GetPlayerXuidStringFromEntIndex(entity_index);
            let context_panel = $.GetContextPanel();
            let ctx = context_panel.FindChildTraverse('ScoreboardContainer').FindChildTraverse('Scoreboard') || context_panel.FindChildTraverse('id-eom-scoreboard-container').FindChildTraverse('Scoreboard')
            if (ctx == null)
                return;

            ctx.FindChildrenWithClassTraverse('sb-row').forEach(function(e) {
                if (e.m_xuid != xuid)
                    return false;

                e.Children().forEach(function(child) {
                    let attribute = child.GetAttributeString('data-stat', '');
                    if (attribute != 'rank')
                        return false;

                    var image = child.FindChildTraverse('image');
                    if (!image || !image.IsValid())
                        return false;

                    image.SetImage(icon === null ? '' : icon)
                    return true;
                })
            })

            return xuid;
        }

        return {
            xuid: _get_xuid,
            set_icon: _set_icon
        }
    ]], 'CSGOHud')()

    local panorama = panorama.open()

    shared.retrieve = function ()
        local info = json.stringify({
            steam = tostring(panorama.MyPersonaAPI.GetXuid()),
            logo = 'bebra'
        })

        return base64.encode(info)
    end

    shared.callbacks = {
        open = function(ws)
            ws:send(shared.retrieve())

            shared.socket = ws
        end,

        message = function(ws, data)
            local success, data = pcall(base64.decode, data)
            if not success or type(data) ~= 'string' then
                return
            end

            local success, data = pcall(json.parse, data)
            if not success then
                return
            end

            local online = 0

            for _, object in next, data do
                if type(object) == 'string' then
                    online = online + 1
                end
            end

            shared.online_label:set(string.format('👤Current Online: %d', online))
            if shared.fl_online then
                shared.fl_online:set(string.format('👤Online: \affd700ff%d', online))
            end
            -- leaderboard from data if available
            if shared.fl_leaderboard and shared.data then
                local rank, pts = 1, 0
                for i, obj in next, shared.data do
                    if type(obj) == 'table' and obj.username == USERNAME then
                        rank = i; pts = obj.points or 0
                    end
                end
                shared.fl_leaderboard:set(string.format('\a444444ffonline  \affd700ff%d\affffffff players', online))
            end

            shared.data = data
        end,

        close = function (ws)
            shared.socket = nil
            client.delay_call(10, websockets.connect, shared.link, shared.callbacks)
        end
    }

    shared.send = function ()
        if not shared.socket then
            return
        end

        shared.socket:send(shared.retrieve())
    end

    shared.attach = function (condition)
        local enabled = shared.enabled:get() and not condition

        for i = 1, globals.maxplayers() do
            if entity.get_classname(i) ~= 'CCSPlayer' then
                goto skip
            end

            local steam_id = scoreboard.xuid(i)

            if not enabled then
                if not shared.icon_data[ steam_id ] then
                    scoreboard.set_icon(i)
                    shared.icon_data[ steam_id ] = true
                end

                goto skip
            end

            local logo_id = shared.data[ steam_id ]

            if logo_id then
                scoreboard.set_icon(i, string.format("https://zenith.dev/icons/%s.png", logo_id))
                shared.icon_data[ steam_id ] = false
            else
                if not shared.icon_data[ steam_id ] then
                    scoreboard.set_icon(i)
                    shared.icon_data[ steam_id ] = true
                end
            end

            ::skip::
        end
    end

    shared.init = function ()
        websockets.connect(shared.link, shared.callbacks)

        shared.send()
        shared.enabled:set_callback(shared.send)
        client.delay_call(2, shared.send)

        client.set_event_callback('paint', function ()
            shared.attach()
        end)

        client.set_event_callback('shutdown', function ()
            shared.attach(true)
        end)
    end

    shared.init()
end

do
    local primary_console = {
        ["Autosnipers"] = "scar20",
        ["Scout"] = "ssg08",
        ["AWP"] = "awp",
        ["AK-47 / M4"]  = "ak47",
        ["AUG / SG553"] = "sg556",
        ['Famas'] = 'famas',
        ["Negev"] = "negev",
        ['M249'] = 'm249',
        ['MP7 / MP5'] = 'mp7',
        ['MP9 / Mac-10'] = 'mp9',
        ['UMP-45'] = 'ump45',
        ['P90'] = 'p90',
        ['Bizon'] = 'bizon',
        ['Nova'] = 'nova',
        ['XM1014'] = 'XM1014',
        ['Mag7 / Sawed-Off'] = 'mag7'
    }

    local secondary_console = {
        ["R8 / Deagle"] = "deagle",
        ["Tec-9 / Five-S / CZ-75"] = "tec9",
        ["P-250"] = "p250",
        ["Duals"] = "elite"
    }

    local utility_console = {
        ["Kevlar"] = "vest",
        ['Helmet'] = 'vesthelm',
        ["Defuser"] = "defuser",
        ["Taser"] = "taser",
        ["HE"] = "hegrenade",
        ["Molotov"] = "molotov",
        ["Smoke"] = "smokegrenade",
        ["Flashbang"] = "flashbang",
        ["Decoy"] = "decoy"
    }

    buy_bot.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Buy Bot")
    : record("settings", "buy_bot::enabled")
    : save()

    buy_bot.primary = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", 'Primary weapon', { 'None', 'Autosnipers', 'Scout', 'AWP', 'AK-47 / M4',  'AUG / SG553', 'Famas', 'Negev', 'M249', 'MP7 / MP5', 'MP9 / Mac-10', 'UMP-45', 'P90', 'Bizon', 'Nova', 'XM1014', 'Mag7 / Sawed-Off' })
    : record("settings", "buy_bot::primary")
    : save()

    buy_bot.secondary = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", 'Secondary weapon', { 'None', 'R8 / Deagle', 'Tec-9 / Five-S / CZ-75', 'P-250', 'Duals' })
    : record("settings", "buy_bot::secondary")
    : save()

    buy_bot.utility = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", 'Utility weapon', { 'Kevlar', 'Helmet', 'Defuser', 'Taser', 'HE', 'Molotov', 'Smoke', 'Flashbang', 'Decoy' })
    : record("settings", "buy_bot::utility")
    : save()

    local function _do_buy()
        local lp = entity.get_local_player()
        if not lp then return end
        local money = entity.get_prop(lp, "m_iAccount") or 0

        if not buy_bot.enabled:get() or money <= 800 then return end

        local primary   = buy_bot.primary:get()
        local secondary = buy_bot.secondary:get()
        local util      = buy_bot.utility:get()
        local armor     = entity.get_prop(lp, "m_ArmorValue") or 0
        local has_helm  = entity.get_prop(lp, "m_bHasHelmet") == 1
        local buy = ""

        buy = primary   == 'None' and buy or buy .. 'buy ' .. (primary_console[primary]   or '') .. '; '
        buy = secondary == 'None' and buy or buy .. 'buy ' .. (secondary_console[secondary] or '') .. '; '

        for i = 1, #util do
            local item_key = util[i]
            local item_cmd = utility_console[item_key]
            if item_cmd then
                -- skip vesthelm if already have helmet
                if item_key == "Helmet" and has_helm then
                    -- already have helmet, buy vest instead if no armor
                    if armor < 50 then buy = buy .. "buy vest; " end
                -- skip vest/helmet if already have enough armor
                elseif (item_key == "Kevlar") and armor >= 95 then
                    -- already full armor, skip
                else
                    buy = buy .. "buy " .. item_cmd .. "; "
                end
            end
        end

        if buy == "" then return end
        client.exec(buy)
    end

    -- fire on both events for reliability
    client.set_event_callback("round_end_upload_stats", _do_buy)
    client.set_event_callback("round_poststart", function()
        -- small delay so buy menu is available
        client.delay_call(0.5, _do_buy)
    end)

end

do
    local kills = 0

    client.set_event_callback('player_death', function (e)
        if client.userid_to_entindex(e.attacker) ~= entity.get_local_player() then
            return
        end

        kills = kills + 1
    end)

    local x, y = client.screen_size()

    client.set_event_callback('paint', function ()
        local enabled = widgets.enabled:get() and (widgets.items:have_key('Watermark') or widgets.items:have_key('Crosshair Indicator'))
        if enabled then
            return
        end

        if kills < 2 then
            return
        end

        local r, g, b, a = widgets.color_picker:rawget()

        local str = decorations.wave('Zenith', globals.realtime(), r, g, b, 200, 255, 255, 255, 200)

        renderer.text(x * .5, y - 15, 255, 255, 255, a, 'cd', nil, str)
    end)

    client.set_event_callback('round_end', function (e)
        kills = 0
    end)
end

--  PREDICT (shoot enemies earlier via Kalman yaw prediction)
do
    local predict = {}
    predict.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "☠Predict")
    : record("aa", "predict::enabled") : save()
    predict.mode = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "- Predict Mode",
        {"Normal", "Extreme"})
    : record("aa", "predict::mode") : save()

    client.set_event_callback("setup_command", function()
        -- predict mode noted but simple resolver handles this automatically
    end)

    _G.__predict = predict
end

--  UNSAFE CHARGE (allow shooting during doubletap even on low HC)
do
    local unsafe_charge = {}
    unsafe_charge.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Unsafe Charge")
    : record("aa", "unsafe_charge::enabled") : save()

    client.set_event_callback("setup_command", function(cmd)
        if not unsafe_charge.enabled:get() then return end
        if not software.is_double_tap() then return end
        -- override minimum damage to 1 so DT fires regardless
        plist.set(entity.get_local_player(), "Minimum damage override", 1)
    end)

    _G.__unsafe_charge = unsafe_charge
end

--  FAKE DUCK IN AIR (air exploit — rapid duck spam to shift tickbase)
do
    local fd_air = {}

    fd_air.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Fake Duck In Air")
        :record("aa", "fd_air::enabled"):save()

    fd_air.key = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles",
        merge { "FD Air Key", "\n", "fd_air::key" })
        :record("aa", "fd_air::key"):save()

    -- ── how it works ──────────────────────────────────────────────────
    -- Rapidly alternates in_duck ON/OFF every tick while airborne.
    -- The constant duck/unduck cycle forces the server to process
    -- extra simulation steps per frame, shifting the tickbase forward
    -- much faster than normal — effectively the same as spamming duck
    -- manually at 64hz but automatic and frame-perfect every tick.
    --
    -- Does NOT require DT to be on — it works standalone.
    -- The key acts as a toggle hold: release to stop.
    -- ──────────────────────────────────────────────────────────────────

    local _fd_flip = false  -- alternates each tick

    client.set_event_callback("setup_command", function(cmd)
        if not fd_air.enabled:get() then
            _fd_flip = false
            return
        end

        -- rawget() reads live key state — :get() is cached and won't work here
        if not fd_air.key:rawget() then
            _fd_flip = false
            cmd.in_duck = 0
            return
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            _fd_flip = false
            return
        end

        -- only while airborne
        local flags = entity.get_prop(me, "m_fFlags") or 0
        if bit.band(flags, 1) ~= 0 then
            -- on ground — reset and clear duck
            _fd_flip = false
            cmd.in_duck = 0
            return
        end

        -- alternate duck every single tick: ON → OFF → ON → OFF ...
        -- this is the actual fake duck spam that shifts the tickbase
        _fd_flip = not _fd_flip
        cmd.in_duck = _fd_flip and 1 or 0
    end)

    _G.__fd_air = fd_air
end

--  AUTO OS (auto switch DT -> HideShot in bad conditions)
do
    -- ── Auto OS ──────────────────────────────────────────────────────────
    -- Suppresses DT shots when not in a valid state (prevents wasted DT)
    local auto_os = {}
    auto_os.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Auto OS")
        :record("aa", "auto_os::enabled"):save()

    auto_os.states = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles",
        merge { "- Enable On", "\n", "auto_os::states" },
        { "Stand", "Crouch", "Air", "Move" })
        :record("aa", "auto_os::states"):save()

    auto_os.avoid_weapons = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles",
        merge { "- Avoid On", "\n", "auto_os::avoid" },
        { "Deagle + Crouch", "Knife + Air", "Pistol + Move" })
        :record("aa", "auto_os::avoid"):save()

    local function _os_state()
        local me = entity.get_local_player()
        if not me then return "Stand" end
        local vx = entity.get_prop(me, "m_vecVelocity[0]") or 0
        local vy = entity.get_prop(me, "m_vecVelocity[1]") or 0
        local spd = math.sqrt(vx*vx + vy*vy)
        local flags = entity.get_prop(me, "m_fFlags") or 0
        local on_ground = bit.band(flags, 1) ~= 0
        local ducked = (entity.get_prop(me, "m_flDuckAmount") or 0) > 0.5
        if not on_ground then return "Air" end
        if ducked then return "Crouch" end
        if spd > 10 then return "Move" end
        return "Stand"
    end

    local function _os_weapon_class(me)
        local wpn = entity.get_player_weapon(me)
        if not wpn then return "other" end
        local wid = bit.band(entity.get_prop(wpn, "m_iItemDefinitionIndex") or 0, 0xFFFF)
        -- deagle = 1, r8 = 64
        if wid == 1 or wid == 64 then return "deagle" end
        -- knives: 42,59,41 + butterfly/other
        if wid == 42 or wid == 59 or wid == 41 or (wid >= 500 and wid <= 520) then return "knife" end
        -- pistols
        local pistols = {2,3,4,30,32,36,61,63}
        for _, p in ipairs(pistols) do if wid == p then return "pistol" end end
        return "other"
    end

    client.set_event_callback("setup_command", function(cmd)
        if not auto_os.enabled:get() then return end
        if not software.is_double_tap() then return end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end

        local state  = _os_state()
        local wclass = _os_weapon_class(me)

        -- check avoid conditions first
        local avoid = auto_os.avoid_weapons:get()
        for _, av in ipairs(avoid) do
            if (av == "Deagle + Crouch" and wclass == "deagle" and state == "Crouch") or
               (av == "Knife + Air"     and wclass == "knife"  and state == "Air")    or
               (av == "Pistol + Move"   and wclass == "pistol" and state == "Move")   then
                cmd.in_attack = 0
                return
            end
        end

        -- check allowed states
        local states = auto_os.states:get()
        local allowed = (#states == 0)
        for _, s in ipairs(states) do
            if s == state then allowed = true; break end
        end

        if not allowed then
            cmd.in_attack = 0
        end
    end)

    _G.__auto_os = auto_os
end

--  AIR TELEPORT
--  When DT is on and an enemy is VISIBLE (not behind wall):
--    1. Disable DT so the server sees us on ground
--    2. Jump to snap position to ground
--    3. Re-enable DT on next ground tick
--  This lets you peek from air, land, and immediately DT shoot.
do
    local air_tel = {}

    air_tel.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Air Teleport")
        :record("aa", "air_tel::enabled"):save()

    air_tel.weapons = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles",
        merge { "- Weapons", "\n", "air_tel::weapons" },
        { "AWP", "Scout", "Taser", "Pistol", "Rifle" })
        :record("aa", "air_tel::weapons"):save()

    air_tel.allow_cross = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles",
        merge { "- Allow on crosshair", "\n", "air_tel::cross" },
        { "No", "Yes" })
        :record("aa", "air_tel::cross"):save()

    -- ── internal state ───────────────────────────────────────────────
    local _at_state       = "idle"  -- "idle" | "triggered" | "restoring"
    local _at_dt_was_on   = false
    local _at_land_tick   = 0
    local _at_restore_in  = 0       -- ticks until we re-enable DT

    -- check if any enemy is visible from our eye position
    local function _at_has_visible_enemy(me)
        local ex, ey, ez = client.eye_position()
        if not ex then return false end
        local enemies = entity.get_players(true)
        for _, ent in ipairs(enemies) do
            if entity.is_alive(ent) and not entity.is_dormant(ent) then
                -- check chest hitbox (1) and head hitbox (0)
                for _, hg in ipairs({0, 1}) do
                    local hx, hy, hz = entity.hitbox_position(ent, hg)
                    if hx then
                        local frac, hit = client.trace_line(me, ex, ey, ez, hx, hy, hz)
                        if frac > 0.97 or (hit == ent) then
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- weapon filter
    local function _at_weapon_allowed(me)
        local wpn = entity.get_player_weapon(me)
        if not wpn then return false end
        local cls = entity.get_classname(wpn) or ""
        local sel = air_tel.weapons:get()
        if #sel == 0 then return true end
        for _, w in ipairs(sel) do
            if (w == "AWP"    and cls:find("awp"))    or
               (w == "Scout"  and cls:find("ssg"))    or
               (w == "Taser"  and cls:find("taser"))  or
               (w == "Pistol" and cls:find("pistol")) or
               (w == "Rifle"  and (cls:find("ak47") or cls:find("m4"))) then
                return true
            end
        end
        return false
    end

    local _dt_ref = software.rage.aimbot.double_tap[1]

    client.set_event_callback("setup_command", function(cmd)
        if not air_tel.enabled:get() then
            _at_state = "idle"
            return
        end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then
            _at_state = "idle"
            return
        end

        if not _at_weapon_allowed(me) then
            _at_state = "idle"
            return
        end

        local flags     = entity.get_prop(me, "m_fFlags") or 0
        local on_ground = bit.band(flags, 1) ~= 0
        local in_air    = not on_ground
        local dt_active = software.is_double_tap()

        if _at_state == "idle" then
            -- waiting: in air + DT on + visible enemy → trigger
            if in_air and dt_active and _at_has_visible_enemy(me) then
                _at_dt_was_on  = true
                _at_state      = "triggered"
                -- disable DT so server registers us on the ground tick
                pcall(ui.set, _dt_ref, false)
            end

        elseif _at_state == "triggered" then
            -- DT is off — press jump this tick to snap to ground position
            if on_ground then
                cmd.in_jump = 1
                _at_state   = "restoring"
                _at_restore_in = 2   -- wait 2 ticks then re-enable DT
            elseif in_air then
                -- still in air — keep waiting, keep DT off
                cmd.in_jump = 1   -- push down
            end

        elseif _at_state == "restoring" then
            -- landed, counting down before re-enabling DT
            _at_restore_in = _at_restore_in - 1
            if _at_restore_in <= 0 then
                if _at_dt_was_on then
                    pcall(ui.set, _dt_ref, true)
                end
                _at_state = "idle"
            end
        end
    end)

    _G.__air_tel = air_tel
end

--  JUMP SCOUT (SSG08 jump shot)
do
    local jump_scout = {}
    jump_scout.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Jump Scout")
    : record("aa", "jump_scout::enabled") : save()

    jump_scout.key = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "- Jump Scout Key")
    : record("aa", "jump_scout::key") : save()

    local _js_prev = false

    client.set_event_callback("setup_command", function(cmd)
        if not jump_scout.enabled:get() then return end
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end
        local wpn = entity.get_player_weapon(me)
        if not wpn then return end
        local wpn_info = csgo_weapons and csgo_weapons(wpn)
        local is_scout = wpn_info and (wpn_info.name == "weapon_ssg08")
        if not is_scout then return end
        local kdown = jump_scout.key:get()
        if kdown and not _js_prev then
            cmd.in_jump = true
            cmd.in_attack = true
        end
        _js_prev = kdown
    end)

    _G.__jump_scout = jump_scout
end

--  DORMANT AIMBOT (fire at dormant/gray ESP enemies)
do
    local dormant_ab = {}
    dormant_ab.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Dormant Aimbot")
    : record("aa", "dormant_ab::enabled") : save()

    dormant_ab.damage = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles", "- Damage", 1, 100, 20, true, "hp")
    : record("aa", "dormant_ab::damage") : save()

    client.set_event_callback("setup_command", function(cmd)
        if not dormant_ab.enabled:get() then return end
        local me = entity.get_local_player()
        if not me then return end
        local min_dmg = dormant_ab.damage:get()
        for i = 1, globals.maxplayers() do
            if entity.get_classname(i) == "CCSPlayer" and entity.is_dormant(i) then
                local team_me = entity.get_prop(me, "m_iTeamNum") or 0
                local team_ent = entity.get_prop(i, "m_iTeamNum") or 0
                if team_me ~= team_ent then
                    plist.set(i, "Minimum damage override", min_dmg)
                    plist.set(i, "Force body aim", true)
                end
            end
        end
    end)

    _G.__dormant_ab = dormant_ab
end

--  DROP NADES (drop grenades to teammates)
do
    local drop_nades = {}
    drop_nades.key = menu.new_item(ui.new_hotkey, "AA", "Anti-aimbot angles", "Drop Nades Key")
    : record("settings", "drop_nades::key") : save()

    local _dn_prev = false

    client.set_event_callback("setup_command", function(cmd)
        local kdown = drop_nades.key:get()
        if kdown and not _dn_prev then
            client.exec("drop")
        end
        _dn_prev = kdown
    end)

    _G.__drop_nades = drop_nades
end

--  ENEMY CHAT REVEALER (show enemy chat in console)
do
    local chat_reveal = {}
    chat_reveal.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Enemy Chat Revealer")
    : record("settings", "chat_reveal::enabled") : save()

    client.set_event_callback("player_chat", function(e)
        if not chat_reveal.enabled:get() then return end
        local me = entity.get_local_player()
        if not me then return end
        local text = e.text or ""
        if text == "" then return end  -- skip empty messages
        local my_team = entity.get_prop(me, "m_iTeamNum") or 0
        local sender_team = entity.get_prop(e.entityid, "m_iTeamNum") or 0
        if sender_team ~= my_team then
            local name = entity.get_player_name(e.entityid) or ""
            if name == "" or name == "unknown" then return end  -- skip unresolved players
            client.color_log(255, 80, 80, "[Enemy] " .. name .. ": " .. text)
        end
    end)

    _G.__chat_reveal = chat_reveal
end

--  SESSION STATISTICS (shown on Home page)
do
    local _stats = {
        session_start = globals.realtime and globals.realtime() or 0,
        kills         = 0,
        headshots     = 0,
        misses_on_me  = 0,
    }
    _G.__session_stats = _stats

    -- track kills & headshots
    client.set_event_callback("player_death", function(e)
        local me = entity.get_local_player()
        if not me then return end
        if client.userid_to_entindex(e.attacker) == me then
            _stats.kills = _stats.kills + 1
            if e.headshot then _stats.headshots = _stats.headshots + 1 end
        end
    end)

    -- track misses on us
    client.set_event_callback("aim_miss", function()
        _stats.misses_on_me = _stats.misses_on_me + 1
    end)
end

--  ZENITH LEADERBOARD  (database kill tracking)
do
    local _LB_KEY   = 'zenith_leaderboard_v1'
    local _TOT_KEY  = 'zenith_total_users_v1'
    local _my_user  = _auth_user or 'unknown'

    local function _lb_read()
        local ok, v = pcall(function() return database.read(_LB_KEY) end)
        return ok and type(v) == 'table' and v or {}
    end
    local function _lb_write(t) pcall(function() database.write(_LB_KEY, t) end) end
    local function _tot_read()
        local ok, v = pcall(function() return database.read(_TOT_KEY) end)
        return ok and type(v) == 'number' and v or 0
    end
    local function _tot_write(n) pcall(function() database.write(_TOT_KEY, n) end) end

    -- register user on first load
    local lb = _lb_read()
    if not lb[_my_user] then
        lb[_my_user] = 0
        _lb_write(lb)
        _tot_write(_tot_read() + 1)
    end

    local function _update_lb_label()
        if not shared or not shared.fl_leaderboard then return end
        local lb2   = _lb_read()
        local total = _tot_read()
        local my_k  = lb2[_my_user] or 0
        local entries = {}
        for u, k in pairs(lb2) do entries[#entries + 1] = { u = u, k = k } end
        table.sort(entries, function(a, b) return a.k > b.k end)
        local rank = 1
        for i, e in ipairs(entries) do
            if e.u == _my_user then rank = i; break end
        end
        shared.fl_leaderboard:set(string.format(
            '\a444444ffkills  \affd700ff#%d\a666666ff/%d  \affffffff%d kills',
            rank, total, my_k))
    end

    -- track kills via player_death
    client.set_event_callback('player_death', function(e)
        if not _auth_alive then return end
        local me = entity.get_local_player()
        if not me then return end
        if client.userid_to_entindex(e.attacker) ~= me then return end
        if client.userid_to_entindex(e.userid) == me then return end  -- no suicides
        local lb2 = _lb_read()
        lb2[_my_user] = (lb2[_my_user] or 0) + 1
        _lb_write(lb2)
        _update_lb_label()
    end)

    -- initial label update
    _update_lb_label()
end
client.set_event_callback("net_update_end", exploit.handle_defensive)
client.set_event_callback("net_update_end", exploit.net_update)
client.set_event_callback("net_update_end", localplayer.net_update)
client.set_event_callback("shutdown", function() if gui and gui.shutdown then gui.shutdown() end end)
client.set_event_callback("shutdown", antiaim.shutdown)

client.set_event_callback("paint_ui", function() if gui and gui.frame then gui.frame() end end)
client.set_event_callback("paint_ui", windows.frame)

client.set_event_callback("paint_ui", manual_direction.frame)

client.set_event_callback("paint_ui", watermark.frame)
client.set_event_callback("paint_ui", keybinds.frame)
client.set_event_callback("paint_ui", indicators.frame)
client.set_event_callback("paint_ui", arrows.frame)
client.set_event_callback("paint_ui", velocity_warning.frame)
client.set_event_callback("paint_ui", hit_marker.frame)

client.set_event_callback("paint_ui", eventlogs.pre_frame)
client.set_event_callback("paint_ui", log_aimbot_shots.frame)
client.set_event_callback("paint_ui", eventlogs.post_frame)

client.set_event_callback("pre_predict_command", localplayer.pre_predict_command)
client.set_event_callback("predict_command", localplayer.predict_command)

client.set_event_callback("setup_command", exploit.setup_command)
client.set_event_callback("setup_command", statement.setup_command)
client.set_event_callback("setup_command", antiaim.setup_command)

client.set_event_callback("aim_miss", log_aimbot_shots.aim_miss)

client.set_event_callback("aim_hit", hit_marker.aim_hit)
client.set_event_callback("aim_fire", hit_marker.aim_fire)

client.set_event_callback("player_hurt", log_aimbot_shots.player_hurt)
--client.set_event_callback("round_prestart", tab_to_game.round_prestart)
client.set_event_callback("round_prestart", hit_marker.round_prestart)
cvar.developer:set_raw_int(0)

local resolver_show_tab  -- defined after resolver is created

menu.set_callback(function()

    _safe_display(shared.online_label)
    -- display fake lag info panel every frame
    if shared.fl_whatsup     then _safe_display(shared.fl_whatsup)     end
    if shared.fl_build       then _safe_display(shared.fl_build)       end
    if shared.fl_online      then _safe_display(shared.fl_online)      end
    if shared.fl_leaderboard then _safe_display(shared.fl_leaderboard) end

    -- display Lua tab fake lag overrides
    if shared.lua_fl_enabled then
        _safe_display(shared.lua_fl_enabled)
        if shared.lua_fl_enabled:get() then
            _safe_display(shared.lua_fl_amount)
            _safe_display(shared.lua_fl_variance)
            _safe_display(shared.lua_fl_limit)
        end
        -- sync to native controls
        local fl = software and software.aa and software.aa.fakelag
        if fl then
            local en = shared.lua_fl_enabled:get()
            ui.set(fl.enabled[1], en)
            if en then
                local amount_str = shared.lua_fl_amount:get()
                local ticks = shared.lua_fl_map and shared.lua_fl_map[amount_str] or 14
                ui.set(fl.limit,    shared.lua_fl_limit:get())
                ui.set(fl.variance, shared.lua_fl_variance:get())
            end
        end
    end

    _safe_display(gui.selection)

    local page = gui.selection:get()

    -- ── AIMBOT ──────────────────────────────────────────────────────
    if page == "◎  Aimbot" then
        -- ── Rage Settings ───────────────────────────────────────────
        local rg = _G.__zn_rage
        if rg then
            _safe_display(rg.enabled)
            if rg.enabled:get() then
                _safe_display(rg.weapon_picker)
                local picker = rg.weapon_picker:get()
                local wcfg   = rg.weapons[picker] or rg.weapons["Global"]
                if wcfg then
                    _safe_display(wcfg.aim_mode)
                    _safe_display(wcfg.auto_hc)
                    _safe_display(wcfg.auto_dmg)

                    -- body aim
                    _safe_display(wcfg.baim_enabled)
                    if wcfg.baim_enabled:get() then
                        _safe_display(wcfg.baim_mode)
                        local bm = wcfg.baim_mode:get()
                        local has_hp   = false
                        local has_miss = false
                        for _, v in ipairs(bm) do
                            if v == "HP Threshold"  then has_hp   = true end
                            if v == "After N Misses" then has_miss = true end
                        end
                        if has_hp   then _safe_display(wcfg.baim_hp)   end
                        if has_miss then _safe_display(wcfg.baim_miss)  end
                    end

                    -- safepoint
                    _safe_display(wcfg.sp_enabled)
                    if wcfg.sp_enabled:get() then
                        _safe_display(wcfg.sp_mode)
                        local sm = wcfg.sp_mode:get()
                        local has_hp   = false
                        local has_miss = false
                        for _, v in ipairs(sm) do
                            if v == "HP Threshold"  then has_hp   = true end
                            if v == "After N Misses" then has_miss = true end
                        end
                        if has_hp   then _safe_display(wcfg.sp_hp)   end
                        if has_miss then _safe_display(wcfg.sp_miss)  end
                    end
                end
            end
        end

        -- ── Other aimbot features ────────────────────────────────────
        local p = _G.__predict
        if p then
            _safe_display(p.enabled)
            if p.enabled:get() then _safe_display(p.mode) end
        end

        _safe_display(shared.enabled)

        local uc = _G.__unsafe_charge
        if uc then _safe_display(uc.enabled) end

        local fda = _G.__fd_air
        if fda then
            _safe_display(fda.enabled)
            if fda.enabled:get() then
                _safe_display(fda.key)
            end
        end

        local aos = _G.__auto_os
        if aos then
            _safe_display(aos.enabled)
            if aos.enabled:get() then
                _safe_display(aos.states)
                _safe_display(aos.avoid_weapons)
            end
        end

        local at = _G.__air_tel
        if at then
            _safe_display(at.enabled)
            if at.enabled:get() then
                _safe_display(at.weapons)
                _safe_display(at.allow_cross)
            end
        end

        local js = _G.__jump_scout
        if js then
            _safe_display(js.enabled)
            if js.enabled:get() then _safe_display(js.key) end
        end

        local da = _G.__dormant_ab
        if da then
            _safe_display(da.enabled)
            if da.enabled:get() then _safe_display(da.damage) end
        end

        -- Lag Peak
        if _G.__lagpeak_show then _G.__lagpeak_show() end
    end

    -- ── BUILDER ──────────────────────────────────────────────────────
    -- AA builder + Manual Yaw + Edge Yaw + Freestanding
    if page == "◆  Builder" then
        -- Manual Yaw
        _safe_display(manual_direction.enabled)
        if manual_direction.enabled:get() then
            _safe_display(manual_direction.options)
            _safe_display(manual_direction.arrows)
            if manual_direction.arrows:get() then
                _safe_display(manual_direction.color)
            end
            _safe_display(manual_direction.left_manual)
            _safe_display(manual_direction.right_manual)
            _safe_display(manual_direction.forward_manual)
            _safe_display(manual_direction.disabled_manual)
        end

        -- Edge Yaw / Freestanding
        _safe_display(yaw_direction.edge_yaw)
        _safe_display(yaw_direction.freestanding)
        _safe_display(fs_disablers.states)

        -- Animation Breakers
        _safe_display(anim_breakers.enabled)
        if anim_breakers.enabled:get() then
            _safe_display(anim_breakers.ground)
            _safe_display(anim_breakers.air)
        end

        _safe_display(angles.type)

        if angles.type:get() == "Custom" then
            _safe_display(angles.custom.state)

            local state = angles.custom.state:get()
            local list = angles.custom[state]

            if list.enabled ~= nil then
                _safe_display(list.enabled)

                if not list.enabled:get() then
                    goto continue
                end
            end

            if list.pitch ~= nil then
                local pitch = list.pitch:get()
                _safe_display(list.pitch)

                if pitch == "Custom" then
                    _safe_display(list.pitch_offset)
                end
            end

            if list.yaw_base ~= nil then
                _safe_display(list.yaw_base)
            end

            local yaw_value = list.yaw:get()
            _safe_display(list.yaw)

            if yaw_value ~= "Off" then

                if yaw_value == '180 LR' then
                    _safe_display(list.yaw_180lr_mode)
                    _safe_display(list.yaw_left)
                    _safe_display(list.yaw_right)

                    if list.yaw_180lr_mode:get() == 'Switch delay' then
                        _safe_display(list.yaw_delay)
                    end
                else
                    _safe_display(list.yaw_offset)
                end

                _safe_display(list.yaw_jitter)

                if list.yaw_jitter:get() ~= "Off" then
                    _safe_display(list.jitter_offset)
                    _safe_display(list.jitter_randomization)

                    if list.yaw_jitter:get() == "Zenith" then
                        _safe_display(list.jitter_mode)
                        _safe_display(list.zenith_safe)
                        _safe_display(list.zenith_cycle)
                        _safe_display(list.zenith_delay)

                        ui.set_enabled(list.zenith_delay.ref, list.zenith_cycle:get() ~= 5)
                    end
                end
            end

            local body_yaw = list.body_yaw:get()
            _safe_display(list.body_yaw)

            if body_yaw ~= "Off" then
                if body_yaw ~= "Opposite" then
                    _safe_display(list.body_yaw_offset)
                end

                _safe_display(list.freestanding_body_yaw)
            end

            ::continue::
        end
    end

    -- ── DEFENSIVE ────────────────────────────────────────────────────
    if page == "❈  Defensive" then
        _safe_display(defensive.enabled)
        if defensive.enabled:get() then
            _safe_display(defensive.mode)
            _safe_display(defensive.state)
            _safe_display(defensive.pitch)
            _safe_display(defensive.yaw)
        if defensive.yaw and (defensive.yaw:get() == "Snap" or defensive.yaw:get() == "Snap Jitter") then
            _safe_display(defensive.snap_range)
            _safe_display(defensive.snap_offset)
        end
        if defensive.yaw and (defensive.yaw:get() == "Snap" or defensive.yaw:get() == "Snap Jitter") then
            _safe_display(defensive.snap_range)
            _safe_display(defensive.snap_offset)
        end
        end
    end

    -- ── RESOLVER ─────────────────────────────────────────────────────
    if page == "↻  Resolver" then
        if resolver_show_tab then resolver_show_tab() end
    end

    -- ── VISUAL ───────────────────────────────────────────────────────
    -- Widgets, Custom scope, Clientside nickname
    if page == "◉  Visual" then
        _safe_display(widgets.enabled)
        if widgets.enabled:get() then
            _safe_display(widgets.items)
            if widgets.items:have_key("Watermark") then
                _safe_display(widgets.display)
                _safe_display(widgets.custom_name)
                if widgets.custom_name:get() then
                    _safe_display(widgets.custom_name_value)
                end
            end
            if #widgets.items:get() > 0 then
                _safe_display(widgets.color_picker)
            end
        end

        _safe_display(custom_scope.enabled)
        if custom_scope.enabled:get() then
            _safe_display(custom_scope.color)
            _safe_display(custom_scope.mode)
            _safe_display(custom_scope.position)
            _safe_display(custom_scope.offset)
        end

        _safe_display(clientside_nickname.enabled)
        if clientside_nickname.enabled:get() then
            _safe_display(clientside_nickname.nickname)
            _safe_display(clientside_nickname.apply)
        end
    end

    -- ── MISC ─────────────────────────────────────────────────────────
    -- Features/tweaks, AA tweaks, Safe Head, Buy Bot, Clantag, extras
    if page == "☰  Misc" then
        -- Features toggle
        _safe_display(settings.tweaks_enable)
        if settings.tweaks_enable:get() then
            _safe_display(settings.tweaks)
        end

        -- AA tweaks
        _safe_display(aa_tweaks.enable)
        if aa_tweaks.enable:get() then
            _safe_display(aa_tweaks.items)
        end

        -- Safe Head
        _safe_display(safe_head.enabled)
        if safe_head.enabled:get() then
            _safe_display(safe_head.states)
        end

        -- Buy Bot
        _safe_display(buy_bot.enabled)
        if buy_bot.enabled:get() then
            _safe_display(buy_bot.primary)
            _safe_display(buy_bot.secondary)
            _safe_display(buy_bot.utility)
        end

        -- Clantag
        if _G.__misc_page and _G.__misc_page.show_clantag then
            _G.__misc_page.show_clantag()
        end

        -- Killsay
        local ks = _G.__killsay
        if ks then
            _safe_display(ks.enabled)
            if ks.enabled:get() then
                _safe_display(ks.mode)
                _safe_display(ks.chance)
                _safe_display(ks.cooldown)
                _safe_display(ks.custom_en)
                if ks.custom_en:get() then
                    _safe_display(ks.custom)
                end
            end
        end

        -- Drop Nades / Chat Reveal
        local dn = _G.__drop_nades
        if dn then _safe_display(dn.key) end
        local cr = _G.__chat_reveal
        if cr then _safe_display(cr.enabled) end

        -- Smart Features (bullet impact ESP)
        if _show_impacts ~= nil then
            _safe_display(_show_impacts)
        end

    end

    -- HOME PAGE
    if page == "⌂  Home" then
        if _G.__home then _G.__home.show() end
    end

    if page == "⚙  Configs" then
        if _G.__configs_show then _G.__configs_show() end
    end
end)

if _HAS_AIMBOT then
--  ZENITH RAGE SETTINGS  v2
--  Auto HC / Min-Dmg / Body-Aim / Safepoint with per-weapon presets
--  Improved: better distance curve, armor detection, prediction quality,
--  lethal-shot detection, miss-driven dmg escalation, smooth HC,
--  my-vel penalty, scoped modifier, true Dynamic blending
local _zn_rage = {}
do
    -- ── weapon categories ───────────────────────────────────────────────────
    local WEAPON_CLASS = {
        -- Snipers
        [9]  = "AWP",   [40] = "Scout",
        [11] = "Auto",  [38] = "Auto",
        -- Rifles
        [7]  = "Rifle", [60] = "Rifle", [16] = "Rifle",
        [39] = "Rifle", [33] = "Rifle", [10] = "Rifle",
        [13] = "Rifle", [19] = "Rifle", [24] = "Rifle",
        -- Heavy Pistol (Deagle, R8)
        [64] = "Heavy Pistol", [63] = "Heavy Pistol",
        -- Pistols
        [2]  = "Pistol", [3]  = "Pistol", [4]  = "Pistol",
        [30] = "Pistol", [32] = "Pistol", [36] = "Pistol",
        [61] = "Pistol", [1]  = "Pistol",
        -- SMGs
        [17] = "SMG", [25] = "SMG", [26] = "SMG",
        [34] = "SMG", [35] = "SMG", [23] = "SMG",
        -- Shotguns
        [27] = "Shotgun", [29] = "Shotgun",
        [41] = "Shotgun", [43] = "Shotgun",
        -- Knife/Other
        [42] = "Other", [59] = "Other",
    }

    -- ── base presets ───────────────────────────────────────────────────
    -- hc  = base hitchance %
    -- dmg = minimum damage gamesense must be able to deal
    -- dmgMax = highest dmg we'll ever require (cap)
    local PRESETS = {
        ["AWP"]          = { Safe={hc=90,dmg=100}, Aggressive={hc=72,dmg=100}, dmgMax=115 },
        ["Scout"]        = { Safe={hc=84,dmg=82},  Aggressive={hc=65,dmg=82},  dmgMax=92  },
        ["Auto"]         = { Safe={hc=72,dmg=95},  Aggressive={hc=54,dmg=85},  dmgMax=110 },
        ["Rifle"]        = { Safe={hc=70,dmg=90},  Aggressive={hc=52,dmg=80},  dmgMax=100 },
        ["Heavy Pistol"] = { Safe={hc=68,dmg=82},  Aggressive={hc=50,dmg=72},  dmgMax=97  },
        ["Pistol"]       = { Safe={hc=65,dmg=68},  Aggressive={hc=48,dmg=58},  dmgMax=85  },
        ["SMG"]          = { Safe={hc=62,dmg=60},  Aggressive={hc=45,dmg=50},  dmgMax=80  },
        ["Shotgun"]      = { Safe={hc=72,dmg=75},  Aggressive={hc=55,dmg=60},  dmgMax=100 },
        ["Other"]        = { Safe={hc=65,dmg=78},  Aggressive={hc=48,dmg=68},  dmgMax=95  },
    }

    -- ── helpers ───────────────────────────────────────────────────
    local function get_dist(a, b)
        local ok1, ax, ay, az = pcall(entity.get_origin, a)
        local ok2, bx, by, bz = pcall(entity.get_origin, b)
        if ok1 and ok2 and ax and bx then
            local dx, dy, dz = bx-ax, by-ay, bz-az
            return math.sqrt(dx*dx + dy*dy + dz*dz)
        end
        return 800
    end

    local function clamp(v, lo, hi)
        return math.max(lo, math.min(hi, math.floor(v + 0.5)))
    end

    -- smooth lerp for HC (prevent jumpy overrides that cause GS to re-resolve)
    local _smooth_hc  = -1
    local _smooth_dmg = -1
    local function smooth_toward(cur, tgt, rate)
        if cur < 0 then return tgt end
        local diff = tgt - cur
        return cur + diff * rate
    end

    -- ── per-target tracking ──────────────────────────────────────────────────
    -- misses, hits, shots, last_origin (for teleport detection)
    local hit_tracker  = {}
    local plist_cache  = {}
    local rage_ticks   = 0
    local last_weapon  = nil
    local rage_prev    = { hc = -1, dmg = -1 }

    -- ── backup/restore ──────────────────────────────────────────────────
    local rage_backup  = { saved = false }
    local function backup_rage()
        if rage_backup.saved then return end
        pcall(function()
            rage_backup.hc  = ui.get(software.rage.aimbot.hitchance)
            rage_backup.dmg = ui.get(software.rage.aimbot.minimum_damage)
            rage_backup.saved = true
        end)
    end
    local function restore_rage()
        if not rage_backup.saved then return end
        pcall(ui.set, software.rage.aimbot.hitchance,      rage_backup.hc)
        pcall(ui.set, software.rage.aimbot.minimum_damage, rage_backup.dmg)
        rage_backup.saved = false
        rage_prev  = { hc = -1, dmg = -1 }
        _smooth_hc  = -1
        _smooth_dmg = -1
    end

    -- ── menu items ──────────────────────────────────────────────────
    local WEAPONS = { "Global", "AWP", "Scout", "Auto", "Rifle", "Heavy Pistol", "Pistol", "SMG", "Shotgun", "Other" }

    _zn_rage.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Rage Settings")
        :record("aa", "zn_rage::enabled"):save()

    _zn_rage.weapon_picker = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles",
        merge { "Weapon\n", "zn_rage::weapon_picker" }, WEAPONS)
        :record("aa", "zn_rage::weapon_picker"):save()

    _zn_rage.weapons = {}
    for _, w in ipairs(WEAPONS) do
        local ws = {
            aim_mode   = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Aim Mode\n", "zn_rage::aim_mode_", w },
                { "Safe", "Aggressive", "Dynamic" }):record("aa", "zn_rage::aim_mode_"..w):save(),

            auto_hc    = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Auto Hit Chance\n", "zn_rage::auto_hc_", w })
                :record("aa", "zn_rage::auto_hc_"..w):save(),

            auto_dmg   = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Auto Min Damage\n", "zn_rage::auto_dmg_", w })
                :record("aa", "zn_rage::auto_dmg_"..w):save(),

            -- ── Body Aim ──
            baim_enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Auto Body Aim\n", "zn_rage::baim_en_", w })
                :record("aa", "zn_rage::baim_en_"..w):save(),

            baim_mode  = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Baim Trigger\n", "zn_rage::baim_mode_", w },
                { "Always", "HP Threshold", "After N Misses", "Airborne", "Low Ammo", "Low HP Moving" })
                :record("aa", "zn_rage::baim_mode_"..w):save(),

            baim_hp    = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Baim HP\n", "zn_rage::baim_hp_", w },
                1, 100, 40, true, "hp"):record("aa", "zn_rage::baim_hp_"..w):save(),

            baim_miss  = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Baim Misses\n", "zn_rage::baim_miss_", w },
                1, 10, 3, true, "x"):record("aa", "zn_rage::baim_miss_"..w):save(),

            -- ── Safepoint ──
            sp_enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] Auto Safepoint\n", "zn_rage::sp_en_", w })
                :record("aa", "zn_rage::sp_en_"..w):save(),

            sp_mode    = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] SP Trigger\n", "zn_rage::sp_mode_", w },
                { "Always", "HP Threshold", "After N Misses", "Airborne" })
                :record("aa", "zn_rage::sp_mode_"..w):save(),

            sp_hp      = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] SP HP\n", "zn_rage::sp_hp_", w },
                1, 100, 40, true, "hp"):record("aa", "zn_rage::sp_hp_"..w):save(),

            sp_miss    = menu.new_item(ui.new_slider, "AA", "Anti-aimbot angles",
                merge { "[" .. w .. "] SP Misses\n", "zn_rage::sp_miss_", w },
                1, 10, 2, true, "x"):record("aa", "zn_rage::sp_miss_"..w):save(),
        }
        _zn_rage.weapons[w] = ws
    end

    _zn_rage.enabled:set_callback(function()
        if not _zn_rage.enabled:get() then restore_rage() else rage_backup.saved = false end
    end)

    -- ── per-target trackers ───────────────────────────────────────────────
    client.set_event_callback("aim_miss", function(e)
        if not _zn_rage.enabled:get() then return end
        local t = e and e.target; if not t or t <= 0 then return end
        hit_tracker[t] = hit_tracker[t] or { misses=0, hits=0, shots=0, consec_miss=0 }
        local tk = hit_tracker[t]
        tk.misses      = tk.misses + 1
        tk.shots       = tk.shots  + 1
        tk.consec_miss = (tk.consec_miss or 0) + 1
    end)

    client.set_event_callback("aim_hit", function(e)
        if not _zn_rage.enabled:get() then return end
        local t = e and e.target; if not t or t <= 0 then return end
        hit_tracker[t] = hit_tracker[t] or { misses=0, hits=0, shots=0, consec_miss=0 }
        local tk = hit_tracker[t]
        local hs = e.hitgroup == 1
        tk.hits        = tk.hits  + 1
        tk.shots       = tk.shots + 1
        tk.consec_miss = 0
        -- decay misses faster on headshots
        if hs then tk.misses = math.max(0, tk.misses - 2)
        elseif tk.misses > 0 then tk.misses = tk.misses - 1 end
    end)

    client.set_event_callback("round_start", function()
        hit_tracker = {}; plist_cache = {}
        _smooth_hc = -1; _smooth_dmg = -1
    end)

    client.set_event_callback("player_death", function(e)
        local ent = client.userid_to_entindex(e.userid)
        if ent then hit_tracker[ent] = nil; plist_cache[ent] = nil end
    end)

    -- ── main setup_command tick ────────────────────────────────────────────────
    client.set_event_callback("setup_command", function()
        if not _zn_rage.enabled:get() then restore_rage(); return end

        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end

        backup_rage()

        -- detect weapon class
        local active_w = "Other"
        local wpn_ent  = entity.get_player_weapon(me)
        local wpn_id   = 0
        if wpn_ent then
            wpn_id  = bit.band(entity.get_prop(wpn_ent, "m_iItemDefinitionIndex") or 0, 0xFFFF)
            active_w = WEAPON_CLASS[wpn_id] or "Other"
        end

        -- pick config
        local picker  = _zn_rage.weapon_picker:get()
        local cfg_key = (picker == "Global") and "Global" or active_w
        local wcfg    = _zn_rage.weapons[cfg_key] or _zn_rage.weapons["Global"]

        local mode   = wcfg.aim_mode:get()
        local do_hc  = wcfg.auto_hc:get()
        local do_dmg = wcfg.auto_dmg:get()

        if not do_hc and not do_dmg then restore_rage(); return end

        local wp_table = PRESETS[active_w] or PRESETS["Other"]
        local safe_p   = wp_table.Safe
        local agg_p    = wp_table.Aggressive
        local dmgMax   = wp_table.dmgMax

        -- Dynamic: true blend between Safe/Aggressive based on real-time factors
        -- computed after modifiers, so we start with the midpoint
        local hc_base  = (safe_p.hc  + agg_p.hc)  * 0.5
        local dmg_base = (safe_p.dmg + agg_p.dmg) * 0.5

        if mode == "Safe" then
            hc_base  = safe_p.hc
            dmg_base = safe_p.dmg
        elseif mode == "Aggressive" then
            hc_base  = agg_p.hc
            dmg_base = agg_p.dmg
        end

        local hc  = hc_base
        local dmg = dmg_base

        -- ── find current target ───────────────────────────────────────────────
        local target_ent   = nil
        local target_dist  = 99999
        local target_hp    = 100
        local target_flags = 0
        local target_vel   = 0
        local target_armor = 0
        local target_helmet= false

        local ok, threat = pcall(client.current_threat)
        if ok and threat and threat > 0 and entity.is_alive(threat) then
            target_ent = threat
        end

        if target_ent then
            target_dist   = get_dist(me, target_ent)
            target_hp     = entity.get_prop(target_ent, "m_iHealth")   or 100
            target_flags  = entity.get_prop(target_ent, "m_fFlags")    or 0
            target_armor  = entity.get_prop(target_ent, "m_ArmorValue") or 0
            target_helmet = entity.get_prop(target_ent, "m_bHasHelmet") == 1
            local vx = entity.get_prop(target_ent, "m_vecVelocity[0]") or 0
            local vy = entity.get_prop(target_ent, "m_vecVelocity[1]") or 0
            target_vel = math.sqrt(vx*vx + vy*vy)
        else
            for _, ent in ipairs(entity.get_players(true)) do
                if entity.is_alive(ent) and not entity.is_dormant(ent) then
                    local d = get_dist(me, ent)
                    if d < target_dist then
                        target_dist   = d
                        target_ent    = ent
                        target_hp     = entity.get_prop(ent,"m_iHealth")    or 100
                        target_flags  = entity.get_prop(ent,"m_fFlags")     or 0
                        target_armor  = entity.get_prop(ent,"m_ArmorValue") or 0
                        target_helmet = entity.get_prop(ent,"m_bHasHelmet") == 1
                        local vx = entity.get_prop(ent,"m_vecVelocity[0]") or 0
                        local vy = entity.get_prop(ent,"m_vecVelocity[1]") or 0
                        target_vel = math.sqrt(vx*vx + vy*vy)
                    end
                end
            end
        end

        local is_airborne = target_ent and (bit.band(target_flags,1) == 0) or false

        -- ── my own velocity penalty ──────────────────────────────────────────────
        -- if I'm also moving, prediction error goes up on both sides
        local my_vx = entity.get_prop(me, "m_vecVelocity[0]") or 0
        local my_vy = entity.get_prop(me, "m_vecVelocity[1]") or 0
        local my_vel = math.sqrt(my_vx*my_vx + my_vy*my_vy)

        if my_vel > 220 then
            hc = hc + 8   -- both moving fast = high prediction error
        elseif my_vel > 80 then
            hc = hc + 4
        end

        -- ── distance modifier (smooth curve, not hard brackets) ──────────────────────────
        -- close (<300): easier to hit, relax HC slightly
        -- mid (300-900): sweet spot, no change
        -- long (900-1800): harder, tighten HC
        -- very long (>1800): very hard, max tighten
        if target_dist < 200 then
            hc = hc - 12
        elseif target_dist < 300 then
            hc = hc - 8
        elseif target_dist < 500 then
            hc = hc - 4
        elseif target_dist < 900 then
            -- sweet spot, no change
        elseif target_dist < 1400 then
            hc = hc + 5
        elseif target_dist < 2000 then
            hc = hc + 10
        else
            hc = hc + 16
        end

        -- ── target movement modifier ──────────────────────────────────────────────
        if is_airborne then
            hc = hc + 12
        elseif target_vel > 260 then
            hc = hc + 9
        elseif target_vel > 160 then
            hc = hc + 5
        elseif target_vel > 80 then
            hc = hc + 2
        elseif target_vel < 8 then
            hc = hc - 6   -- standing still = easy to hit
        end

        -- ── scoped modifier ──────────────────────────────────────────────────
        -- unscoped sniper = very inaccurate, jack HC way up
        if active_w == "AWP" or active_w == "Scout" or active_w == "Auto" then
            local is_scoped = entity.get_prop(me, "m_bIsScoped") == 1
            if not is_scoped then
                hc = hc + 35  -- unscoped sniper = basically never shoot
            end
        end

        -- ── armor modifier ──────────────────────────────────────────────────
        -- heavily armored target = need higher dmg to break through reliably
        -- pistols/SMGs especially affected since armor eats their damage
        if target_armor > 80 and target_helmet then
            if active_w == "Pistol" or active_w == "SMG" then
                dmg = dmg + 10  -- need more to pen
                hc  = hc  + 4   -- harder to do enough damage
            end
        elseif target_armor == 0 then
            -- no armor: easy to do damage, relax dmg requirement slightly
            dmg = math.max(dmg - 8, 30)
        end

        -- ── HP-based modifiers ─────────────────────────────────────────────────
        if target_ent then
            if target_hp <= 8 then
                -- basically dead: fire anything
                dmg = 1
                hc  = math.max(hc - 20, 25)
            elseif target_hp <= 20 then
                -- low HP: set dmg just below their HP (body shots work)
                dmg = math.max(target_hp - 3, 1)
                hc  = math.max(hc - 10, 30)
            elseif target_hp <= 40 then
                dmg = math.max(target_hp - 8, 1)
                hc  = math.max(hc - 5, 35)
            end
            -- lethal shot detection: if we can 1-shot from here, lower dmg gate
            -- so GS fires faster rather than waiting for a "perfect" shot
            local can_one_shot = (active_w == "AWP" or active_w == "Auto") and target_hp <= 100
            if can_one_shot then
                dmg = math.min(dmg, target_hp)
                hc  = math.max(hc - 5, 40)
            end
        end

        -- ── miss streak escalation ────────────────────────────────────────────────
        if target_ent then
            local tk = hit_tracker[target_ent] or { misses=0, hits=0, shots=0, consec_miss=0 }
            local consec = tk.consec_miss or 0

            -- escalate HC on consecutive misses (they're hard to hit)
            if consec >= 5 then
                hc  = math.min(hc  + 25, 97)
                dmg = math.max(dmg - 12, 1)  -- lower dmg to allow body shots through
            elseif consec >= 3 then
                hc  = math.min(hc  + 15, 93)
                dmg = math.max(dmg - 6, 1)
            elseif consec >= 2 then
                hc  = math.min(hc  + 8,  90)
            end

            -- hitting well: relax slightly so we shoot more
            local shots = tk.shots or 0; local hits = tk.hits or 0
            if shots >= 4 and hits / shots >= 0.75 then
                hc = math.max(hc - 4, agg_p.hc - 5)
            end
        end

        -- ── Dynamic mode: true blend toward safer/more aggressive based on situation ──
        if mode == "Dynamic" then
            -- factors that make us want to be aggressive: low HP, close range, standing target
            local aggr_score = 0
            local me_hp = entity.get_prop(me, "m_iHealth") or 100
            if me_hp < 40       then aggr_score = aggr_score + 2 end  -- low HP = take the shot
            if target_dist < 350 then aggr_score = aggr_score + 2 end  -- close = easier
            if target_vel < 5    then aggr_score = aggr_score + 1 end  -- standing = easy
            if target_hp  < 50   then aggr_score = aggr_score + 1 end  -- low target HP = finish
            -- factors that push toward safe
            if is_airborne          then aggr_score = aggr_score - 2 end
            if target_dist > 1200   then aggr_score = aggr_score - 2 end
            if target_vel  > 200    then aggr_score = aggr_score - 1 end
            -- blend: 0=full safe, 4+=full aggressive
            local t = math.max(0, math.min(1, aggr_score / 4))
            hc  = safe_p.hc  + (agg_p.hc  - safe_p.hc)  * t
            dmg = safe_p.dmg + (agg_p.dmg - safe_p.dmg) * t
            -- re-apply the situation modifiers on top of blend
            -- (they were applied to hc_base which was overwritten, so just re-add)
        end

        -- ── our HP panic: take the shot when low ─────────────────────────────
        local my_hp = entity.get_prop(me, "m_iHealth") or 100
        if my_hp <= 12 then
            hc  = math.max(hc  - 22, 22)
            dmg = math.max(dmg - 15, 1)
        elseif my_hp <= 30 then
            hc  = math.max(hc  - 12, 28)
            dmg = math.max(dmg - 8,  1)
        elseif my_hp <= 55 then
            hc  = math.max(hc  - 5,  35)
        end

        -- ── smooth + clamp ──────────────────────────────────────────────────
        hc  = clamp(hc,  1, 100)
        dmg = clamp(dmg, 1, dmgMax)

        -- smooth HC to prevent rapid flipping that confuses GS resolver
        -- (smooth toward target at 60% per tick so it tracks fast but doesn't jump)
        _smooth_hc  = smooth_toward(_smooth_hc,  hc,  0.60)
        _smooth_dmg = smooth_toward(_smooth_dmg, dmg, 0.55)
        local final_hc  = clamp(_smooth_hc,  1, 100)
        local final_dmg = clamp(_smooth_dmg, 1, dmgMax)

        -- ── apply (every 2 ticks or on weapon change) ─────────────────────────────────
        rage_ticks = rage_ticks + 1
        local should_apply = (rage_ticks % 2 == 0)
        if active_w ~= last_weapon then
            last_weapon = active_w
            rage_prev   = { hc = -1, dmg = -1 }
            _smooth_hc  = hc
            _smooth_dmg = dmg
            should_apply = true
        end

        if should_apply then
            if do_hc  and final_hc  ~= rage_prev.hc  then
                pcall(ui.set, software.rage.aimbot.hitchance,      final_hc)
                rage_prev.hc = final_hc
            end
            if do_dmg and final_dmg ~= rage_prev.dmg then
                pcall(ui.set, software.rage.aimbot.minimum_damage, final_dmg)
                rage_prev.dmg = final_dmg
            end
        end

        -- ── body aim / safepoint per-target ──────────────────────────────────────────────
        if target_ent then
            local tk = hit_tracker[target_ent] or { misses=0 }
            local wpn = entity.get_player_weapon(me)
            local ammo = wpn and (entity.get_prop(wpn, "m_iClip1") or 99) or 99

            local force_baim = false
            if wcfg.baim_enabled:get() then
                for _, m in ipairs(wcfg.baim_mode:get()) do
                    if m == "Always" then force_baim = true; break
                    elseif m == "HP Threshold" and target_hp <= wcfg.baim_hp:get() then force_baim = true; break
                    elseif m == "After N Misses" and tk.misses >= wcfg.baim_miss:get() then force_baim = true; break
                    elseif m == "Airborne" and is_airborne then force_baim = true; break
                    elseif m == "Low Ammo" and ammo <= 3 then force_baim = true; break
                    elseif m == "Low HP Moving" and target_hp <= 45
                        and target_vel > 80 then force_baim = true; break
                    end
                end
            end

            -- Disable in air: when target is airborne, use plist to disable
            -- safe point (air targets are easier, safe point wastes time)
            if is_airborne then
                pcall(plist.set, target_ent, "Disable in air", false)
            end

            local force_sp = false
            if wcfg.sp_enabled:get() then
                for _, m in ipairs(wcfg.sp_mode:get()) do
                    if m == "Always" then force_sp = true; break
                    elseif m == "HP Threshold" and target_hp <= wcfg.sp_hp:get() then force_sp = true; break
                    elseif m == "After N Misses" and tk.misses >= wcfg.sp_miss:get() then force_sp = true; break
                    elseif m == "Airborne" and is_airborne then force_sp = true; break
                    end
                end
            end

            local cached = plist_cache[target_ent] or {}
            if cached.baim ~= force_baim then
                pcall(plist.set, target_ent, "Override prefer body aim", force_baim and "On" or "Off")
                cached.baim = force_baim
            end
            if cached.sp ~= force_sp then
                pcall(plist.set, target_ent, "Override safe point", force_sp and "On" or "Off")
                cached.sp = force_sp
            end
            plist_cache[target_ent] = cached
        end
    end)

    _G.__zn_rage = _zn_rage
end
end -- _HAS_AIMBOT

if _HAS_AIMBOT then
--  ZENITH SMART FEATURES
--  Multipoint / Head Scale / Target Priority / Bullet Impact ESP
--  Bomb awareness / Smoke/Flash reactive AA / Weapon-reload awareness
do

-- ── per-target multipoint + head scale control ───────────────────────────
-- Uses plist to dynamically set multipoint and head scale per enemy
-- based on their HP, distance, and miss streak
-- This gives GS more or fewer hitboxes to choose from per target

local _mp_cache = {}   -- [ent] = { mp, hs }
local _mp_ticks = 0

local function _mp_update()
    _mp_ticks = _mp_ticks + 1
    if _mp_ticks % 3 ~= 0 then return end  -- every 3 ticks

    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end

    local my_x, my_y, my_z = entity.get_origin(me)
    if not my_x then return end

    local rage_data = _G.__zn_rage
    local hit_tr    = rage_data and rawget(rage_data, '_ht') or nil

    for _, ent in ipairs(entity.get_players(true)) do
        if not entity.is_alive(ent) or entity.is_dormant(ent) then
            _mp_cache[ent] = nil
            goto _mp_skip
        end

        local ex, ey, ez = entity.get_origin(ent)
        if not ex then goto _mp_skip end

        local dx, dy, dz = ex-my_x, ey-my_y, ez-my_z
        local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
        local hp   = entity.get_prop(ent, 'm_iHealth') or 100
        local flags= entity.get_prop(ent, 'm_fFlags')  or 0
        local air  = bit.band(flags, 1) == 0

        -- multipoint: On when close or target has high HP and we need damage
        -- Off when target is low HP (any hit kills, don't waste on multipoint)
        local want_mp
        if hp <= 25 then
            want_mp = 'Off'   -- near dead: any hit point works
        elseif dist < 400 then
            want_mp = 'On'    -- close: multipoint helps guarantee damage
        elseif dist > 1600 then
            want_mp = 'Off'   -- far: multipoint hurts accuracy
        else
            want_mp = 'On'
        end

        -- head scale: larger when standing still (gives GS bigger target)
        -- smaller when airborne (tighter = safer point)
        local vx = entity.get_prop(ent,'m_vecVelocity[0]') or 0
        local vy = entity.get_prop(ent,'m_vecVelocity[1]') or 0
        local spd = math.sqrt(vx*vx + vy*vy)

        local want_hs  -- head scale: 1-13 in GS (1=smallest, 13=default full)
        if air then
            want_hs = 3    -- airborne: tight head hitbox only
        elseif spd < 5 then
            want_hs = 13   -- standing still: full head scale
        elseif spd < 100 then
            want_hs = 9
        else
            want_hs = 5    -- running: moderate
        end

        local cached = _mp_cache[ent] or {}
        if cached.mp ~= want_mp then
            pcall(plist.set, ent, 'Multipoint', want_mp)
            cached.mp = want_mp
        end
        if cached.hs ~= want_hs then
            pcall(plist.set, ent, 'Head scale', want_hs)
            cached.hs = want_hs
        end
        _mp_cache[ent] = cached

        ::_mp_skip::
    end
end

-- ── target priority override ─────────────────────────────────────────────
-- Sets plist Target selection priority based on:
-- who is lowest HP (easiest kill), who is shooting at us, who is closest
-- Priority 0 = normal, higher = prefer this target

local _prio_cache = {}
local _last_attacker = nil
local _last_attacker_tick = -999

client.set_event_callback('player_hurt', function(e)
    local me = entity.get_local_player()
    if not me then return end
    local my_uid = entity.get_prop(me, 'm_iUserId')
    if e.userid == my_uid then
        -- we got hurt - track who shot us
        local attacker = client.userid_to_entindex(e.attacker)
        if attacker and attacker ~= me then
            _last_attacker      = attacker
            _last_attacker_tick = globals.tickcount()
        end
    end
end)

local function _prio_update()
    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end
    local my_x, my_y, my_z = entity.get_origin(me)
    if not my_x then return end

    -- attacker priority expires after 3 seconds
    local attacker_valid = _last_attacker and
        (globals.tickcount() - _last_attacker_tick) < (3 / globals.tickinterval())

    for _, ent in ipairs(entity.get_players(true)) do
        if not entity.is_alive(ent) or entity.is_dormant(ent) then
            _prio_cache[ent] = nil
            goto _prio_skip
        end

        local hp   = entity.get_prop(ent,'m_iHealth') or 100
        local ex,ey,ez = entity.get_origin(ent)
        if not ex then goto _prio_skip end
        local dx,dy = ex-my_x, ey-my_y
        local dist  = math.sqrt(dx*dx + dy*dy)

        local prio = 0
        -- shooter gets top priority
        if attacker_valid and ent == _last_attacker then prio = prio + 4 end
        -- low HP = easy kill
        if hp <= 30  then prio = prio + 3
        elseif hp <= 60 then prio = prio + 1 end
        -- close range
        if dist < 300 then prio = prio + 2
        elseif dist < 700 then prio = prio + 1 end

        -- clamp to valid range (0-7 typically)
        prio = math.min(prio, 7)

        if _prio_cache[ent] ~= prio then
            pcall(plist.set, ent, 'Target selection priority', prio)
            _prio_cache[ent] = prio
        end

        ::_prio_skip::
    end
end

-- ── bullet impact tracking ───────────────────────────────────────────────
-- Draws where our shots actually landed vs where we aimed
-- Helps debug prediction errors

local _impacts = {}
local _impact_lifetime = 3.0  -- seconds

client.set_event_callback('bullet_impact', function(e)
    local me = entity.get_local_player()
    if not me then return end
    -- only track our own bullets
    local shooter = client.userid_to_entindex(e.userid)
    if shooter ~= me then return end

    table.insert(_impacts, {
        x = e.x, y = e.y, z = e.z,
        t = globals.curtime()
    })
    -- keep max 12
    while #_impacts > 12 do table.remove(_impacts, 1) end
end)

local _show_impacts = menu.new_item(ui.new_checkbox, 'AA', 'Anti-aimbot angles', 'Bullet Impact ESP')
    :record('aa', 'smart::bullet_impact'):save()

-- ── bomb awareness ───────────────────────────────────────────────────────
local _bomb_planted    = false
local _bomb_plant_time = 0
local _bomb_site       = '?'
local _defuse_started  = false
local _BOMB_TIMER      = 40  -- c4 fuse default

client.set_event_callback('bomb_planted', function(e)
    _bomb_planted    = true
    _bomb_plant_time = globals.curtime()
    -- site: 0=A, 1=B
    _bomb_site       = (e.site == 0) and 'A' or 'B'
    _defuse_started  = false
end)

client.set_event_callback('bomb_defused', function()
    _bomb_planted   = false
    _defuse_started = false
end)

client.set_event_callback('bomb_begindefuse', function(e)
    _defuse_started = true
end)

client.set_event_callback('round_start', function()
    _bomb_planted   = false
    _defuse_started = false
end)

-- ── smoke/flash reactive AA ──────────────────────────────────────────────
-- When a smoke or flash detonates, temporarily relax HC
-- because prediction in smoke is harder for enemy too

local _smoke_active   = false
local _smoke_tick     = -999
local _SMOKE_DURATION = 18  -- seconds smoke lasts

local _flash_active   = false
local _flash_tick     = -999

client.set_event_callback('smokegrenade_detonate', function(e)
    -- check if near us
    local me = entity.get_local_player()
    if not me then return end
    local mx, my, mz = entity.get_origin(me)
    if not mx then return end
    local dx = (e.x or 0) - mx
    local dy = (e.y or 0) - my
    local dz = (e.z or 0) - mz
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    if dist < 800 then
        _smoke_active = true
        _smoke_tick   = globals.tickcount()
    end
end)

client.set_event_callback('flashbang_detonate', function(e)
    local me = entity.get_local_player()
    if not me then return end
    local mx, my, mz = entity.get_origin(me)
    if not mx then return end
    local dx = (e.x or 0) - mx
    local dy = (e.y or 0) - my
    local dz = (e.z or 0) - mz
    local dist = math.sqrt(dx*dx + dy*dy + dz*dz)
    if dist < 1000 then
        _flash_active = true
        _flash_tick   = globals.tickcount()
    end
end)

-- ── weapon reload awareness ──────────────────────────────────────────────
-- During reload: force body aim on all targets (if clip is 0, don't head-seek)
-- After reload: reset to normal

local _reloading = false
local _reload_tick = -999

client.set_event_callback('weapon_reload', function(e)
    local me = entity.get_local_player()
    if not me then return end
    if client.userid_to_entindex(e.userid) ~= me then return end
    _reloading   = true
    _reload_tick = globals.tickcount()
end)

-- ── setup_command: apply smoke/flash HC modifier and reload baim ─────────
client.set_event_callback('setup_command', function()
    local me = entity.get_local_player()
    if not me or not entity.is_alive(me) then return end

    -- decay smoke
    local tc = globals.tickcount()
    local ti = globals.tickinterval()
    if _smoke_active and (tc - _smoke_tick) > (_SMOKE_DURATION / ti) then
        _smoke_active = false
    end
    -- decay flash (1.5s)
    if _flash_active and (tc - _flash_tick) > (1.5 / ti) then
        _flash_active = false
    end
    -- decay reload (3s max)
    if _reloading and (tc - _reload_tick) > (3.0 / ti) then
        _reloading = false
    end

    -- during reload: force body aim on all enemies (safer while vulnerable)
    if _reloading then
        for _, ent in ipairs(entity.get_players(true)) do
            if entity.is_alive(ent) then
                pcall(plist.set, ent, 'Force body aim', true)
            end
        end
    end

    -- smoke/flash: if near smoke, bump HC slightly through rage system
    -- we set it via the existing rage prev cache by invalidating it
    if _smoke_active or _flash_active then
        local zr = _G.__zn_rage
        if zr then
            -- signal smoke via a global flag the rage system can read
            rawset(zr, '_near_smoke', true)
        end
    else
        local zr = _G.__zn_rage
        if zr then rawset(zr, '_near_smoke', false) end
    end
end)

-- ── paint: multipoint/priority updates + impact ESP + bomb timer ─────────
client.set_event_callback('paint', function()
    -- multipoint + head scale update
    _mp_update()
    -- target priority
    _prio_update()

    -- bullet impact ESP
    if _show_impacts:get() then
        local now = globals.curtime()
        for i = #_impacts, 1, -1 do
            local imp = _impacts[i]
            local age = now - imp.t
            if age > _impact_lifetime then
                table.remove(_impacts, i)
            else
                local fade = 1 - (age / _impact_lifetime)
                local a    = math.floor(255 * fade)
                local sx, sy = renderer.world_to_screen(imp.x, imp.y, imp.z)
                if sx then
                    -- red dot with age-based fade
                    renderer.circle(sx, sy, 255, 80, 80, a, 4, 0, 1)
                    renderer.circle_outline(sx, sy, 255, 255, 255, math.floor(a*0.4), 4, 0, 1, 1)
                end
            end
        end
    end

    -- bomb timer overlay
    if _bomb_planted then
        local elapsed  = globals.curtime() - _bomb_plant_time
        local remaining= _BOMB_TIMER - elapsed
        if remaining < 0 then remaining = 0 end

        local sw, sh   = client.screen_size()
        local cx       = sw * 0.5
        local cy       = sh * 0.12

        local r = remaining > 10 and 255 or 255
        local g = remaining > 10 and math.floor(remaining / _BOMB_TIMER * 255) or 60
        local b = 60

        local bar_w  = 220
        local bar_h  = 8
        local filled = math.floor(bar_w * (remaining / _BOMB_TIMER))

        -- background
        renderer.rectangle(cx - bar_w*0.5 - 2, cy - 2, bar_w + 4, bar_h + 4, 10, 10, 10, 200)
        -- fill
        renderer.rectangle(cx - bar_w*0.5, cy, filled, bar_h, r, g, b, 220)
        -- text
        local txt = string.format('C4 [%s]  %.1fs%s',
            _bomb_site, remaining,
            _defuse_started and '  [DEFUSING]' or '')
        renderer.text(cx, cy - 14, r, g, b, 220, 'c', 0, txt)
    end
end)

-- ── round_prestart cleanup ────────────────────────────────────────────────
client.set_event_callback('round_prestart', function()
    _mp_cache   = {}
    _prio_cache = {}
    _impacts    = {}
    _last_attacker = nil
end)

end -- do
end -- _HAS_AIMBOT

menu.update()

--  CONFIG SYSTEM (Zenith)
do
    local _db_key  = 'zenith_cfgs_v3'
    local _remote  = 'https://raw.githubusercontent.com/Matehun111/idk/main/zenith_presets.json'
    local live     = {}
    local cur_sel  = 1
    local MAX_ROWS = 8

    local m_header  = menu.new_item(ui.new_label,   'AA','Anti-aimbot angles','Cloud Configs ─────────────────')
    local m_rows    = {}
    for i=1,MAX_ROWS do
        m_rows[i] = menu.new_item(ui.new_label, 'AA','Anti-aimbot angles',' ')
    end
    local m_scroll  = menu.new_item(ui.new_label,   'AA','Anti-aimbot angles',' ')
    local m_author  = menu.new_item(ui.new_label,   'AA','Anti-aimbot angles',' ')
    local m_sel_up  = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles','▲ Previous',    function() end)
    local m_sel_dn  = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles','▼ Next',         function() end)
    local m_load    = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles','Load',            function() end)
    local m_loadaa  = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles',"Load Anti-Aim's", function() end)
    local m_savename= menu.new_item(ui.new_textbox, 'AA','Anti-aimbot angles','Save Name')
    local m_save    = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles','Save',            function() end)
    local m_delete  = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles','Delete Mine',     function() end)
    local m_status  = menu.new_item(ui.new_label,   'AA','Anti-aimbot angles',' ')

    local offset = 0

    local function db_read()
        local ok,v = pcall(database.read, _db_key)
        if ok and type(v)=='string' then
            local ok2,t = pcall(json.parse, v)
            if ok2 and type(t)=='table' then return t end
        end
        return {}
    end
    local function db_write(t) pcall(database.write, _db_key, json.stringify(t)) end
    local function set_status(s) pcall(ui.set, m_status.ref, s or ' ') end
    local function strip(s) return (s or ''):match('^%s*(.-)%s*$') end

    -- Export: walk records[tab][name] = item, read live UI value
    local function export_data()
        local out = {}
        local ok_r, recs = pcall(menu.get_records)
        if not ok_r or type(recs) ~= 'table' then return '{}' end
        for tab, names in pairs(recs) do
            for name, item in pairs(names) do
                if item and item.ref then
                    local ok2, val = pcall(ui.get, item.ref)
                    if ok2 then
                        local key = tab .. '::' .. name
                        -- store as array so unpack works on apply
                        if type(val) == 'table' then
                            out[key] = val
                        else
                            out[key] = {val}
                        end
                    end
                end
            end
        end
        local ok3, str = pcall(json.stringify, out)
        return ok3 and str or '{}'
    end

    -- Apply: set each recorded item from stored data
    local function apply_data(str, aa_only)
        local ok, data = pcall(json.parse, str or '{}')
        if not ok or type(data) ~= 'table' then return false end

        local ok_r, recs = pcall(menu.get_records)
        if not ok_r or type(recs) ~= 'table' then return false end

        local applied = 0
        for tab, names in pairs(recs) do
            for name, item in pairs(names) do
                if item and item.ref then
                    local key = tab .. '::' .. name
                    local v = data[key]
                    if v ~= nil then
                        local should = true
                        if aa_only then
                            should = tab == 'aa' or tab == 'angles' or tab == 'defensive'
                        end
                        if should then
                            pcall(function()
                                if type(v) == 'table' then
                                    ui.set(item.ref, unpack(v))
                                else
                                    ui.set(item.ref, v)
                                end
                                applied = applied + 1
                            end)
                        end
                    end
                end
            end
        end
        return applied > 0
    end

    local function refresh_rows()
        local total = #live
        cur_sel = math.max(1, math.min(cur_sel, math.max(1, total)))
        if cur_sel - 1 < offset then offset = cur_sel - 1 end
        if cur_sel - 1 >= offset + MAX_ROWS then offset = cur_sel - MAX_ROWS end
        offset = math.max(0, math.min(offset, math.max(0, total - MAX_ROWS)))

        for i = 1, MAX_ROWS do
            local idx = offset + i
            local cfg = live[idx]
            if cfg then
                local marker  = (idx == cur_sel) and '\a71bc78ff► ' or '  '
                local src_col = cfg.source=='cloud' and '\aff9955ff' or '\a71bc78ff'
                local tag     = cfg.source=='cloud' and '[C]' or '[M]'
                pcall(ui.set, m_rows[i].ref,
                    marker..'\affffffff'..src_col..tag..' \affffffff'..cfg.name)
            else
                pcall(ui.set, m_rows[i].ref, '  ')
            end
        end

        if total > MAX_ROWS then
            pcall(ui.set, m_scroll.ref,
                string.format('\ac8c8c8ff%d / %d  [scroll: ▲▼]', cur_sel, total))
        else
            pcall(ui.set, m_scroll.ref,
                string.format('\ac8c8c8ff%d / %d', cur_sel, total))
        end

        local sel = live[cur_sel]
        if sel then
            local src = sel.source=='cloud' and '\aff9955ff[Cloud]' or '\a71bc78ff[Mine]'
            pcall(ui.set, m_author.ref,
                'by \aff9955ff'..(sel.author or '???')..'  '..src)
        else
            pcall(ui.set, m_author.ref, '  ')
        end
    end

    local function save_locals()
        local t = {}
        for _, cfg in ipairs(live) do
            if cfg.source == 'local' then t[#t+1] = cfg end
        end
        db_write(t)
    end

    local function reload()
        live = {}
        for _, cfg in ipairs(db_read()) do
            cfg.source = 'local'; live[#live+1] = cfg
        end
        refresh_rows()
        pcall(function()
            http.get(_remote, function(ok, res)
                local body = type(res)=='table' and res.body or res
                if ok and body and #body > 2 then
                    local ok2, arr = pcall(json.parse, body)
                    if ok2 and type(arr)=='table' then
                        for _, cfg in ipairs(arr) do
                            local dup = false
                            for _, lc in ipairs(live) do
                                if lc.name == cfg.name and lc.source == 'local' then
                                    dup = true; break
                                end
                            end
                            if not dup then cfg.source='cloud'; live[#live+1]=cfg end
                        end
                    end
                end
                refresh_rows()
            end)
        end)
    end

    -- Config string format: "zenith:gs <name>"
    -- Import from string  
    local function parse_config_string(s)
        if type(s) ~= 'string' then return nil end
        local payload = s:match('^zenith:gs%s+(.+)$')
        if payload then return payload end
        return nil
    end

    local function export_config_string(name)
        return 'zenith:gs ' .. export_data()
    end

    m_sel_up:set_callback(function()
        cur_sel = math.max(1, cur_sel - 1); refresh_rows()
    end)
    m_sel_dn:set_callback(function()
        cur_sel = math.min(math.max(1, #live), cur_sel + 1); refresh_rows()
    end)

    m_load:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('No config selected.'); return end
        local data_str = sel.data
        -- support "zenith:gs <json>" format
        local inner = parse_config_string(data_str)
        if inner then data_str = inner end
        if apply_data(data_str, false) then
            set_status('Loaded: ' .. sel.name)
        else
            set_status('Load failed - no matching items found.')
        end
    end)

    m_loadaa:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('No config selected.'); return end
        local data_str = sel.data
        local inner = parse_config_string(data_str)
        if inner then data_str = inner end
        if apply_data(data_str, true) then
            set_status("Loaded AA's: " .. sel.name)
        else
            set_status('Load failed.')
        end
    end)

    m_save:set_callback(function()
        local ok, name = pcall(ui.get, m_savename.ref)
        name = strip(ok and name or '')
        local sel = live[cur_sel]
        -- overwrite selected Mine config if no name given
        if name == '' and sel and sel.source == 'local' then
            sel.data = export_data()
            save_locals()
            set_status('Saved: ' .. sel.name)
            return
        end
        if name == '' then set_status('Enter a name to save.'); return end
        -- update existing
        for _, cfg in ipairs(live) do
            if cfg.name == name and cfg.source == 'local' then
                cfg.data = export_data()
                save_locals(); refresh_rows()
                set_status('Updated: ' .. name)
                return
            end
        end
        -- new config
        live[#live+1] = {
            name   = name,
            author = USERNAME or 'user',
            source = 'local',
            data   = export_data()
        }
        cur_sel = #live
        save_locals(); refresh_rows()
        set_status('Saved: ' .. name)
    end)

    m_delete:set_callback(function()
        local sel = live[cur_sel]
        if not sel or sel.source == 'cloud' then
            set_status("Can't delete cloud configs."); return
        end
        local name = sel.name
        table.remove(live, cur_sel)
        cur_sel = math.max(1, cur_sel - 1)
        save_locals(); refresh_rows()
        set_status('Deleted: ' .. name)
    end)

    function _G.__configs_show()
        _safe_display(m_header)
        for i = 1, MAX_ROWS do _safe_display(m_rows[i]) end
        _safe_display(m_scroll)
        _safe_display(m_author)
        _safe_display(m_sel_up)
        _safe_display(m_sel_dn)
        _safe_display(m_load)
        _safe_display(m_loadaa)
        _safe_display(m_savename)
        _safe_display(m_save)
        _safe_display(m_delete)
        _safe_display(m_status)
    end

    -- expose for external use
    _G._zenith_export_cfg = export_data
    _G._zenith_import_cfg = apply_data

    client.delay_call(1, reload)
end

--  HOME PAGE  (Statistics + User Info Panel in Fake lag column)
do
    local home = {}
    _G.__home = home

    home.lbl_stats   = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', '\a71bc78ff\xe2\x96\xb6 Statistics')
    home.lbl_total   = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', '\xe2\x96\xb6 Total time: \a71bc78ff0.0 Hours')
    home.lbl_session = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', '\xe2\x8f\xb8 This session time: \a71bc78ff0 Minutes')
    home.lbl_hs      = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', 'Headshots: \a71bc78ff0%')
    home.lbl_kills   = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', 'Enemy killed: \a71bc78ff0')
    home.lbl_misses  = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', 'Misses: \a71bc78ff0')

    local _s_start  = globals.realtime and globals.realtime() or 0
    local _s_kills  = 0
    local _s_hs     = 0
    local _s_misses = 0
    local _last_sv  = 0

    local function _get_total()
        local ok,v = pcall(function() return database.read('zenith_total_time_v1') end)
        return (ok and type(v)=='number') and v or 0
    end
    local function _save_total(h)
        pcall(function() database.write('zenith_total_time_v1', h) end)
    end

    client.set_event_callback('player_death', function(e)
        local me = entity.get_local_player()
        if not me then return end
        if client.userid_to_entindex(e.attacker) == me then
            _s_kills = _s_kills + 1
            if e.headshot then _s_hs = _s_hs + 1 end
        end
    end)
    client.set_event_callback('aim_miss', function()
        _s_misses = _s_misses + 1
    end)

    function home.update()
        local rt = globals.realtime and globals.realtime() or 0
        local secs = rt - _s_start
        local mins = math.floor(secs / 60)
        if rt - _last_sv > 60 then
            _save_total(_get_total() + secs/3600)
            _last_sv = rt
        end
        local tot = _get_total()
        local hs_pct = _s_kills > 0 and math.floor(_s_hs/_s_kills*100) or 0
        home.lbl_total:set(string.format('\xe2\x96\xb6 Total time: \a71bc78ff%.1f Hours', tot))
        home.lbl_session:set(string.format('\xe2\x8f\xb8 This session time: \a71bc78ff%d Minutes', mins))
        home.lbl_hs:set(string.format('Headshots: \a71bc78ff%d%%', hs_pct))
        home.lbl_kills:set(string.format('Enemy killed: \a71bc78ff%d', _s_kills))
        home.lbl_misses:set(string.format('X Misses at me: \a71bc78ff%d', _s_misses))
    end

    function home.show()
        home.update()
        _safe_display(home.lbl_stats)
        _safe_display(home.lbl_total)
        _safe_display(home.lbl_session)
        _safe_display(home.lbl_hs)
        _safe_display(home.lbl_kills)
        _safe_display(home.lbl_misses)
    end
end

--  CLANTAG SYSTEM (zenith.gs)
do
    local mp = {}
    _G.__misc_page = mp

    -- ── animated frame tables ─────────────────────────────────────────
    local _write_tag = {
        '','','',
        'z','ze','zen','zeni','zenit','zenith',
        'zenith.','zenith.g','zenith.gs',
        'zenith.gs','zenith.gs','zenith.gs',
        'zenith.g','zenith.','zenith',
        'zenit','zeni','zen','ze','z',''
    }
    local _bounce_tag = {
        'z','ze','zen','zeni','zenit','zenith',
        'zenith.','zenith.g','zenith.gs',
        'zenith.g','zenith.','zenith',
        'zenit','zeni','zen','ze','z'
    }
    local _scroll_tag = {
        'zenith.gs       ','enith.gs z      ','nith.gs ze      ',
        'ith.gs zen      ','th.gs zeni      ','h.gs zenit      ',
        '.gs zenith      ','gs zenith.      ','s zenith.g      ',
        ' zenith.gs      ','zenith.gs       '
    }
    local _flicker_tags = {'zenith.gs','ZENITH.GS','Zenith.Gs','zEnItH.gS'}

    -- ── menu items ────────────────────────────────────────────────────
    mp.lbl_ct   = menu.new_item(ui.new_label,    'AA','Anti-aimbot angles', '\a71bc78ff\xe2\x9a\xa1 Clantag')
    mp.ct_en    = menu.new_item(ui.new_checkbox, 'AA','Anti-aimbot angles', 'Custom Clantag')
        :record('misc','misc::ct_en'):save()
    mp.ct_mode  = menu.new_item(ui.new_combobox, 'AA','Anti-aimbot angles', 'Animation',
        {'Static','Write','Scroll','Bounce','Flicker'})
        :record('misc','misc::ct_mode'):save()
    mp.ct_text  = menu.new_item(ui.new_textbox,  'AA','Anti-aimbot angles', 'Custom Text')
        :record('misc','misc::ct_text'):save()
    mp.ct_speed = menu.new_item(ui.new_slider,   'AA','Anti-aimbot angles', 'Speed', 1, 20, 5)
        :record('misc','misc::ct_speed'):save()

    -- ── defaults on load ─────────────────────────────────────────────
    client.delay_call(0.1, function()
        if not mp.ct_en:get() then mp.ct_en:set(true) end
        local txt = mp.ct_text:get()
        if not txt or txt == '' then mp.ct_text:set('zenith.gs') end
    end)

    -- ── helpers ───────────────────────────────────────────────────────
    local function _get_text()
        local txt = mp.ct_text:get()
        return (txt and txt ~= '') and txt or 'zenith.gs'
    end

    local function _play(frames, spd, count)
        -- use realtime so animation runs smoothly even outside a game
        local idx = math.floor(globals.realtime() * spd % count) + 1
        client.set_clan_tag(frames[idx] or '')
    end

    local function _apply()
        if not mp.ct_en:get() then
            client.set_clan_tag('')
            return
        end
        local mode = mp.ct_mode:get()
        local spd  = mp.ct_speed:get()
        if mode == 'Static' then
            client.set_clan_tag(_get_text())
        elseif mode == 'Write' then
            _play(_write_tag,  spd * 0.5, #_write_tag)
        elseif mode == 'Scroll' then
            _play(_scroll_tag, spd * 0.3, #_scroll_tag)
        elseif mode == 'Bounce' then
            _play(_bounce_tag, spd * 0.5, #_bounce_tag)
        elseif mode == 'Flicker' then
            _play(_flicker_tags, spd * 0.8, #_flicker_tags)
        end
    end

    -- ── show in Misc page ─────────────────────────────────────────────
    function mp.show_clantag()
        _safe_display(mp.lbl_ct)
        _safe_display(mp.ct_en)
        if mp.ct_en:get() then
            _safe_display(mp.ct_mode)
            if mp.ct_mode:get() == 'Static' then
                _safe_display(mp.ct_text)
            else
                _safe_display(mp.ct_speed)
            end
        end
    end
    function mp.show() end

    -- ── net_update_end: the ONLY place client.set_clan_tag works ────────
    -- Reset _force_apply on round events so the tag is pushed immediately
    -- on the next net_update_end tick without waiting for the interval.
    local _last_rt     = 0
    local _force_apply = false
    local _ANIM_INTERVAL = 0.065  -- throttle animated modes (~4 ticks)

    client.set_event_callback('round_start', function()
        _force_apply = true   -- bypass throttle next tick
    end)
    client.set_event_callback('round_poststart', function()
        _force_apply = true
    end)
    client.set_event_callback('round_prestart', function()
        _force_apply = true
    end)
    client.set_event_callback('cs_win_panel_match', function()
        _force_apply = true
    end)

    client.set_event_callback('net_update_end', function()
        -- don't fight native clantag spammer if it's on
        local ok, gs_ct = pcall(ui.get, ui.reference('Misc','Miscellaneous','Clan tag spammer'))
        if ok and gs_ct then return end

        local mode = mp.ct_en:get() and mp.ct_mode:get() or 'off'
        local now  = globals.realtime()

        -- Static: always apply (cheap, and must show on scoreboard immediately)
        -- Animated: throttle so frames progress smoothly
        local is_anim = (mode == 'Write' or mode == 'Scroll' or mode == 'Bounce' or mode == 'Flicker')
        if is_anim and not _force_apply then
            if now - _last_rt < _ANIM_INTERVAL then return end
        end
        _last_rt     = now
        _force_apply = false

        _apply()
    end)
end

local math_abs = math.abs
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_ceil = math.ceil
local math_max = math.max
local math_min = math.min
local math_sin = math.sin
local math_cos = math.cos
local math_tan = math.tan
local math_exp = math.exp
local math_log = math.log
local math_pi = math.pi
local math_huge = math.huge
local math_random = math.random
local math_randomseed = math.randomseed
local math_atan2 = math.atan2
local table_insert  = table.insert
local table_remove  = table.remove
local table_sort    = table.sort
local string_format = string.format
local string_rep    = string.rep
local bit = require('bit')

local NN3 = {
    cfg  = { inp=20, hid=48, out=3, lr=0.038, mom=0.87 },
    wh={}, wo={}, vh={}, vo={}, mem={},
    trained_samples = 0,
}
local function _nn3_xavier(a,b) return (math.random()*2-1)*math.sqrt(6/(a+b)) end
for i=1,20 do NN3.wh[i]={}; NN3.vh[i]={}
    for j=1,48 do NN3.wh[i][j]=_nn3_xavier(20,48); NN3.vh[i][j]=0 end
end
for i=1,48 do NN3.wo[i]={}; NN3.vo[i]={}
    for j=1,3 do NN3.wo[i][j]=_nn3_xavier(48,3); NN3.vo[i][j]=0 end
end

--  ZENITH RESOLVER  v3  (nightly only)
if not (_HAS_RESOLVER and _auth_alive) then goto _resolver_end end

-- module table: holds all persistent state to stay under LuaJIT 200-local limit
local _M = {}
_M.DB   = {}
_M.NN3  = NN3   -- NN3 declared at file scope above

;(function()

-- ── math helpers ────────────────────────────────────────────────────────
local _f   = string.format
local _abs = math.abs; local _min = math.min; local _max = math.max
local _fl  = math.floor; local _sqrt= math.sqrt; local _exp = math.exp
local _sin = math.sin;   local _cos = math.cos
local _pi  = math.pi

local function _nrm(y)    return ((y+180)%360)-180 end
local function _ydelta(a,b)  return _nrm(a-b) end
local function _lerp(a,b,t)  return a+(b-a)*t end
local function _clamp(v,lo,hi) return v<lo and lo or v>hi and hi or v end
local function _sign(v)      return v>=0 and 1 or -1 end
local function _rad2deg(r)   return r*180/_pi end

local function _exp_weights(n, decay)
    local w={} for i=1,n do w[i]=decay^(n-i) end return w
end

local function _dominant_freq(sig)
    local n=#sig; if n<8 then return 0,0 end
    local bm,bk=0,0
    for k=1,_fl(n/2) do
        local re,im=0,0
        for j=1,n do
            local a=2*_pi*k*(j-1)/n
            re=re+sig[j]*_cos(a); im=im+sig[j]*_sin(a)
        end
        local mag=_sqrt(re*re+im*im)/n
        if mag>bm then bm=mag; bk=k end
    end
    return bk,bm
end

-- ── FFI ─────────────────────────────────────────────────────────────────
local ffi = require 'ffi'
pcall(ffi.cdef,[[
    struct zn3_animstate {
        char pad[3]; char m_bForceWeaponUpdate; char pad1[91];
        void* m_pBaseEntity; void* m_pActiveWeapon; void* m_pLastActiveWeapon;
        float m_flLastClientSideAnimationUpdateTime;
        int   m_iLastClientSideAnimationUpdateFramecount;
        float m_flAnimUpdateDelta; float m_flEyeYaw; float m_flPitch;
        float m_flSpeedNormalized; float m_flGoalFeetYaw;
        float m_flAffectedFraction; float m_flDuckAmount;
        float m_flCurrentFeetYaw; float m_flCurrentTorsoYaw;
        float m_flUnknownVelocityLean; float m_flLeanAmount;
        char pad2[4]; float m_flFeetCycle; float m_flFeetYawRate;
        char pad3[4]; float m_fDuckAmount; float m_fLandingDuckAdditiveSomething;
        char pad4[4]; float m_vOriginX; float m_vOriginY; float m_vOriginZ;
        float m_vLastOriginX; float m_vLastOriginY; float m_vLastOriginZ;
        float m_vVelocityX; float m_vVelocityY;
        char pad5[4]; float m_flUnknownFloat1; char pad6[8];
        float m_flUnknownFloat2; float m_flUnknownFloat3; float m_flUnknown;
        float m_flSpeed2D; float m_flUpVelocity; float m_flSpeedNormalized2;
        float m_flFeetSpeedForwardsOrSideWays;
        float m_flFeetSpeedUnknownForwardOrSideways;
        float m_flTimeSinceStartedMoving; float m_flTimeSinceStoppedMoving;
        bool m_bOnGround; bool m_bInHitGroundAnimation;
        float m_flTimeSinceInAir; float m_flLastOriginZ;
        float m_flHeadHeightOrOffsetFromHittingGroundAnimation;
        float m_flStopToFullRunningFraction;
        char pad7[4]; float m_flMagicFraction;
        char pad8[60]; float m_flWorldForce; char pad9[462];
        float m_flPlaybackRate; float m_flMaxYaw;
    };
    typedef struct {
        float m_anim_time; float m_fade_out_time;
        int m_flags; int m_activity; int m_priority; int m_order;
        int m_sequence; float m_prev_cycle;
        float m_weight; float m_weight_delta_rate;
        float m_playback_rate; float m_cycle;
        void* m_owner; int m_bits;
    } zn3_anim_layer_t;
    typedef void* (__thiscall* zn3_get_entity_t)(void*, int);
]])
local _elist3 = (function()
    local ok,r=pcall(function()
        return ffi.cast('void***',client.create_interface('client_panorama.dll','VClientEntityList003'))
    end); return ok and r or nil
end)()
local _get_ent3 = _elist3 and ffi.cast('zn3_get_entity_t',_elist3[0][3]) or nil

local function _ea(idx)
    if not _get_ent3 then return nil end
    local ok,r=pcall(_get_ent3,_elist3,idx); return ok and r or nil
end
local function _astate(idx)
    local a=_ea(idx); if not a then return nil end
    local ok,p=pcall(function()
        return ffi.cast('struct zn3_animstate**',ffi.cast('char*',a)+39264)[0]
    end); return ok and p or nil
end
local function _layers(idx)
    local a=_ea(idx); if not a then return nil end
    local ok,t=pcall(function()
        local lp=ffi.cast('zn3_anim_layer_t*',ffi.cast('char*',a)+39264+0xC98)
        local o={}
        for i=0,12 do
            local l=lp[i]
            o[i+1]={weight=l.m_weight,cycle=l.m_cycle,
                    playback_rate=l.m_playback_rate,sequence=l.m_sequence,
                    anim_time=l.m_anim_time,prev_cycle=l.m_prev_cycle}
        end; return o
    end); return ok and t or nil
end

-- ── state enum ──────────────────────────────────────────────────────────
local ST={STAND=1,MOVE=2,CROUCH=3,AIR=4,SLOWWALK=5,AIR_CROUCH=6,SNAKING=7}
local ST_STR={[1]='Stand',[2]='Move',[3]='Crouch',[4]='Air',
              [5]='SlowWalk',[6]='AirCrouch',[7]='Snaking'}

local function _gstate(ent)
    local ast=_astate(ent)
    local vx=entity.get_prop(ent,'m_vecVelocity[0]') or 0
    local vy=entity.get_prop(ent,'m_vecVelocity[1]') or 0
    local spd=_sqrt(vx*vx+vy*vy)
    local duck=entity.get_prop(ent,'m_flDuckAmount') or 0
    local flags=entity.get_prop(ent,'m_fFlags') or 0
    local gnd=bit.band(flags,1)~=0
    local slow=ast and ast.m_flSpeedNormalized>0.05 and ast.m_flSpeedNormalized<0.34 or false
    if not gnd then return duck>0.15 and ST.AIR_CROUCH or ST.AIR end
    if duck>0.5  then return spd>3 and ST.SNAKING or ST.CROUCH end
    if slow      then return ST.SLOWWALK end
    if spd>5     then return ST.MOVE end
    return ST.STAND
end

local function _gld(ent)
    local L=_layers(ent)
    local r={move_w=0,aim_w=0,lean_w=0,jump_w=0,walk_w=0,
             desync_cycle=0,aim_cycle=0,anim_delta=0,
             is_moving=false,is_airborne=false}
    if not L then return r end
    local aim=L[2];local wpn=L[3];local lean=L[4]
    local jump=L[6];local move=L[7]
    if aim  then r.aim_w=aim.weight or 0; r.aim_cycle=aim.cycle or 0 end
    if wpn  then r.desync_cycle=_abs(r.aim_cycle-(wpn.cycle or 0)) end
    if lean then r.lean_w=lean.weight or 0 end
    if jump then r.jump_w=jump.weight or 0; r.is_airborne=r.jump_w>0.45 end
    if move then r.move_w=move.weight or 0; r.is_moving=r.move_w>0.08 end
    if aim and wpn then r.anim_delta=_abs((aim.anim_time or 0)-(wpn.anim_time or 0)) end
    return r
end

local function _fingerprint(ld)
    local s={}
    if ld.desync_cycle>0.12 and ld.desync_cycle<0.95 then s[#s+1]='jitter_body' end
    if ld.desync_cycle<0.06 then s[#s+1]='static_real' end
    if ld.anim_delta>0.05   then s[#s+1]='exploit_anim' end
    if ld.lean_w>0.35       then s[#s+1]='lean_aa' end
    return s
end

-- ── UI ──────────────────────────────────────────────────────────────────
local G='AA'; local GR='Anti-aimbot angles'
_M.ui_en      = menu.new_item(ui.new_checkbox,G,GR,'Enable Resolver'):record('aa','resolver::enabled'):save(); _M.ui_en:set(true)
_M.ui_mode    = menu.new_item(ui.new_combobox,G,GR,merge{'Resolver Engine','\n','resolver::mode'},'Pattern Core','Hybrid Engine','Bruteforce Only'):record('aa','resolver::mode'):save()
_M.ui_verbose = menu.new_item(ui.new_checkbox,G,GR,'Verbose Logging'):record('aa','resolver::verbose'):save()
_M.ui_debug   = menu.new_item(ui.new_checkbox,G,GR,'Resolver Debug'):record('aa','resolver::debug'):save()
_M.ui_pitch   = menu.new_item(ui.new_checkbox,G,GR,'Resolve Pitch'):record('aa','resolver::pitch'):save(); _M.ui_pitch:set(true)
_M.ui_exploits= menu.new_item(ui.new_checkbox,G,GR,'Resolve Exploits'):record('aa','resolver::exploits'):save(); _M.ui_exploits:set(true)
_M.ui_multipt = menu.new_item(ui.new_checkbox,G,GR,'Multi-Point Sampling'):record('aa','resolver::multipoint'):save(); _M.ui_multipt:set(true)
_M.ui_log_scr = menu.new_item(ui.new_checkbox,G,GR,'Resolver Log (Screen)'):record('aa','resolver::log_screen'):save()
_M.ui_log_con = menu.new_item(ui.new_checkbox,G,GR,'Resolver Log (Console)'):record('aa','resolver::log_console'):save(); _M.ui_log_con:set(true)
_M.ui_suppress= menu.new_item(ui.new_checkbox,G,GR,'Shot Suppression'):record('aa','resolver::suppress'):save(); _M.ui_suppress:set(true)
_M.ui_sup_rng = menu.new_item(ui.new_slider,G,GR,merge{'Suppress Close Range','\n','resolver::suppress_range'},0,800,350,true,'u',1):record('aa','resolver::suppress_range'):save()
_M.ui_jt      = menu.new_item(ui.new_slider,G,GR,merge{'Jitter Threshold','\n','resolver::jitter_thresh'},5,60,29,true,'deg',1):record('aa','resolver::jitter_thresh'):save()
_M.ui_conf_w  = menu.new_item(ui.new_slider,G,GR,merge{'Min Confidence','\n','resolver::min_conf'},0,80,35,true,'%',1):record('aa','resolver::min_conf'):save()
_M.ui_hist_w  = menu.new_item(ui.new_slider,G,GR,merge{'History Weight Decay','\n','resolver::hist_decay'},50,99,88,true,'%',1):record('aa','resolver::hist_decay'):save()
_M.lbl_method = menu.new_item(ui.new_label,G,GR,'Method: -')
_M.lbl_aa     = menu.new_item(ui.new_label,G,GR,'AA Type: -')
_M.lbl_desync = menu.new_item(ui.new_label,G,GR,'Desync: -')
_M.lbl_lby    = menu.new_item(ui.new_label,G,GR,'LBY: -')
_M.lbl_streak = menu.new_item(ui.new_label,G,GR,'Streak: 0 miss | 0 hit')
_M.lbl_conf   = menu.new_item(ui.new_label,G,GR,'Confidence: -')
_M.lbl_state  = menu.new_item(ui.new_label,G,GR,'State: -')
_M.lbl_layers = menu.new_item(ui.new_label,G,GR,'Layers: -')
_M.lbl_exploit= menu.new_item(ui.new_label,G,GR,'Exploit: -')

-- ── per-player DB ────────────────────────────────────────────────────────
local function _db(ent)
    if not _M.DB[ent] then
        _M.DB[ent]={
            deltas={},feet_hist={},eye_hist={},vel_hist={},pitch_hist={},bt_hist={},
            state_stats={},side_hits={[1]=0,[2]=0},miss_pattern={},adaptive_desync=nil,
            lby_timer=0,lby_updating=false,lby_last_feet=0,lby_snap_cnt=0,
            lby_2nd_deriv=0,lby_feet_rate=0,
            def_snap_cnt=0,def_flick_cnt=0,def_last_feet=0,def_active=false,
            def_side=1,def_timer=0,
            lean_side=0,lean_magnitude=0,
            fd_count=0,fd_active=false,fd_last_duck=0,
            os_last_shot=0,os_side_hist={},
            dt_active=false,tb_shift=0,tb_hist={},exploit_type='none',
            jitter_freq=0,jitter_phase=0,jitter_mag=0,
            side=1,desync=0,confidence=0.5,method='none',aa_type='Gathering',aa_swing=0,
            last_nn_inp=nil,
            hit_count=0,miss_count=0,fail_streak=0,hit_streak=0,
            brute_stage=0,brute_locked=false,
            pitch_res=0,last_sim=0,last_tick=0,conf_last_update=0,layer_sigs={},
        }
        for _,st in pairs(ST) do
            _M.DB[ent].state_stats[st]={hits=0,misses=0,best_side=1,best_desync=40}
        end
    end
    return _M.DB[ent]
end

local function _vlog(msg) if _M.ui_verbose:get() then client.color_log(180,130,255,'[ZRes] '..msg..'\0') end end
local function _dlog(msg) if _M.ui_debug:get()   then client.color_log(140,200,255,'[ZDbg] '..msg..'\0') end end

-- ── trackers ────────────────────────────────────────────────────────────
local function _track_lby(ent,d)
    local ast=_astate(ent)
    local vx=entity.get_prop(ent,'m_vecVelocity[0]') or 0
    local vy=entity.get_prop(ent,'m_vecVelocity[1]') or 0
    local spd=_sqrt(vx*vx+vy*vy); local now=globals.curtime()
    if spd>1.5 then d.lby_timer=now+0.22; d.lby_updating=true
    elseif now>=d.lby_timer then d.lby_updating=true; d.lby_timer=now+1.1
    else d.lby_updating=false end
    if not ast then return end
    local feet=ast.m_flCurrentFeetYaw; local eye=ast.m_flEyeYaw
    local delta=_ydelta(eye,feet)
    table.insert(d.deltas,delta); if #d.deltas>128 then table.remove(d.deltas,1) end
    table.insert(d.feet_hist,feet); if #d.feet_hist>64 then table.remove(d.feet_hist,1) end
    table.insert(d.eye_hist,eye);   if #d.eye_hist>64  then table.remove(d.eye_hist,1)  end
    table.insert(d.pitch_hist,ast.m_flPitch or 0); if #d.pitch_hist>32 then table.remove(d.pitch_hist,1) end
    local fd=_ydelta(feet,d.lby_last_feet)
    d.lby_2nd_deriv=fd-d.lby_feet_rate; d.lby_feet_rate=fd
    if _abs(fd)>25 and spd<3 then d.lby_snap_cnt=d.lby_snap_cnt+1 end
    d.lby_last_feet=feet
    table.insert(d.vel_hist,{vx=vx,vy=vy,spd=spd,t=now}); if #d.vel_hist>32 then table.remove(d.vel_hist,1) end
end

local function _track_bt(ent,d)
    local ox,oy,oz=entity.get_origin(ent); if not ox then return end
    local sim=entity.get_prop(ent,'m_flSimulationTime') or 0
    table.insert(d.bt_hist,{tick=globals.tickcount(),ox=ox,oy=oy,oz=oz,sim=sim})
    if #d.bt_hist>64 then table.remove(d.bt_hist,1) end
end

local function _track_def(ent,d)
    local ast=_astate(ent); if not ast then return end
    local feet=ast.m_flCurrentFeetYaw; local torso=ast.m_flCurrentTorsoYaw
    local eye=ast.m_flEyeYaw; local now=globals.curtime()
    local fd=_abs(_ydelta(feet,d.def_last_feet))
    if fd>80 and fd<200 then d.def_snap_cnt=d.def_snap_cnt+2; d.def_active=true; d.def_timer=now+0.4 end
    local td=_abs(_ydelta(torso,feet))
    if td>45 then d.def_flick_cnt=d.def_flick_cnt+1.5 end
    d.def_snap_cnt=d.def_snap_cnt*0.95; d.def_flick_cnt=d.def_flick_cnt*0.95
    d.def_active=now<d.def_timer or d.def_snap_cnt>1.2 or d.def_flick_cnt>1.8
    if d.def_active then d.def_side=_ydelta(eye,feet)>0 and 2 or 1 end
    d.def_last_feet=feet
end

local function _track_lean(ent,d)
    local ast=_astate(ent); if not ast then return end
    local lean=ast.m_flLeanAmount or 0
    d.lean_magnitude=_abs(lean)
    d.lean_side=lean>0.15 and 1 or lean<-0.15 and -1 or 0
end

local function _track_fd(ent,d)
    local duck=entity.get_prop(ent,'m_flDuckAmount') or 0
    local flags=entity.get_prop(ent,'m_fFlags') or 0
    local air=bit.band(flags,1)==0
    if not air then
        local dd=_abs(duck-d.fd_last_duck)
        if dd>0.2 and duck<0.85 then d.fd_count=d.fd_count+1
        else d.fd_count=_max(0,d.fd_count-0.2) end
        d.fd_active=d.fd_count>3
    else d.fd_count=_max(0,d.fd_count-0.5); d.fd_active=false end
    d.fd_last_duck=duck
end

local function _track_exploit(ent,d)
    local sim=entity.get_prop(ent,'m_flSimulationTime') or 0
    local tc=globals.tickcount(); local ti=globals.tickinterval()
    local st=math.floor(sim/ti+0.5)
    table.insert(d.tb_hist,{tc=tc,sim_tick=st}); if #d.tb_hist>32 then table.remove(d.tb_hist,1) end
    if #d.tb_hist>=2 then
        local prev=d.tb_hist[#d.tb_hist-1]; local curr=d.tb_hist[#d.tb_hist]
        local exp=prev.sim_tick+(curr.tc-prev.tc); local shift=exp-curr.sim_tick
        if shift>1 and shift<=16 then d.tb_shift=shift; d.dt_active=true; d.exploit_type=_f('DT(%d)',_fl(shift))
        elseif shift<=0 then d.dt_active=false; if d.tb_shift>0 then d.tb_shift=d.tb_shift-1 end end
    end
    if d.fd_active then d.exploit_type='FakeDuck' end
end

local function _conf_decay(d)
    if globals.curtime()-d.conf_last_update>2 then d.confidence=_max(0.2,d.confidence*0.92) end
end

-- ── classifier (improved) ───────────────────────────────────────────────
local function _classify(d, jt, decay)
    if #d.deltas < 8 then return 'Gathering', 0, 0.5 end
    local n   = #d.deltas
    local w   = _exp_weights(n, decay)
    local wsum = 0; for _,v in ipairs(w) do wsum = wsum + v end

    local flip_w = 0; local static_w = 0; local swing = 0
    local pos_w  = 0; local neg_w    = 0; local sum_w = 0
    local consec_same = 0; local max_consec = 0; local prev_sign = 0

    for i = 2, n do
        local c  = d.deltas[i]; local p = d.deltas[i-1]
        local wi = w[i]
        local diff = _abs(_ydelta(c, p))
        if diff > swing then swing = diff end
        if diff > jt    then flip_w  = flip_w  + wi end
        if diff < 5     then static_w = static_w + wi end
        sum_w = sum_w + c * wi
        if c > 0 then pos_w = pos_w + wi else neg_w = neg_w + wi end
        -- consecutive same-sign streak
        local cs = c > 0 and 1 or -1
        if cs == prev_sign then consec_same = consec_same + 1
        else consec_same = 0 end
        if consec_same > max_consec then max_consec = consec_same end
        prev_sign = cs
    end

    local fr   = flip_w  / wsum
    local sr   = static_w / wsum
    local bias = pos_w    / (pos_w + neg_w + 0.001)
    local prev = d.aa_type
    local at

    -- jitter: rapid flipping
    if fr > 0.35 then
        at = 'Jitter'
    -- static: small deltas, consistent
    elseif sr > 0.68 and swing < 25 then
        at = 'Static'
    -- LBY: we're in an LBY update window
    elseif d.lby_updating and swing < 80 then
        at = 'LBY'
    -- swing: single large direction
    elseif swing > 80 and fr < 0.10 and max_consec > 4 then
        at = 'Swing'
    -- sway: medium oscillation
    elseif swing > 22 and swing <= 80 and fr < 0.25 then
        at = 'Sway'
    else
        at = 'Chaotic'
    end

    -- hysteresis: don't flip away from confident types on borderline
    if prev == 'Jitter' and at ~= 'Jitter' and fr > 0.22 then at = 'Jitter' end
    if prev == 'Static' and at ~= 'Static' and sr > 0.50  then at = 'Static' end
    if prev == 'LBY'    and at ~= 'LBY'    and d.lby_updating then at = 'LBY' end

    return at, swing, bias
end

-- ── jitter side predictor ───────────────────────────────────────────────
-- Track actual flip ticks to predict which side is "up" right now
local function _jitter_predict(d)
    if #d.deltas < 6 then return d.side, 0.55 end

    -- find the actual flip period by detecting sign changes
    local flips = {}
    for i = 2, #d.deltas do
        local c, p = d.deltas[i], d.deltas[i-1]
        if (c > 0) ~= (p > 0) and _abs(c) > 5 and _abs(p) > 5 then
            flips[#flips+1] = i
        end
    end

    if #flips < 3 then
        -- not enough flips to detect period, use last delta sign
        local last = d.deltas[#d.deltas] or 0
        return last > 0 and 2 or 1, 0.62
    end

    -- measure average period between flips
    local period_sum = 0
    for i = 2, #flips do
        period_sum = period_sum + (flips[i] - flips[i-1])
    end
    local avg_period = period_sum / (#flips - 1)

    -- how many ticks since last flip?
    local last_flip_idx = flips[#flips]
    local ticks_since   = #d.deltas - last_flip_idx
    local phase         = (ticks_since % _max(1, _fl(avg_period))) / _max(1, avg_period)

    -- what side were they on after the last flip?
    local last_delta = d.deltas[last_flip_idx] or 0
    local side_after_flip = last_delta > 0 and 2 or 1

    -- if we're in the first half of the period, same side; second half, other side
    local current_side
    if phase < 0.5 then
        current_side = side_after_flip
    else
        current_side = side_after_flip == 1 and 2 or 1
    end

    -- confidence based on how consistent the period is
    local period_variance = 0
    for i = 2, #flips do
        local p2 = flips[i] - flips[i-1]
        period_variance = period_variance + (p2 - avg_period)^2
    end
    period_variance = period_variance / (#flips - 1)
    local consistency = _clamp(1 - period_variance / (_max(1, avg_period)^2), 0.55, 0.92)

    return current_side, consistency
end

-- ── LBY resolver (proper) ───────────────────────────────────────────────
local function _resolve_lby(ent, d, ast)
    -- When LBY is NOT updating (standing still), real body yaw = feet yaw
    -- When LBY IS updating, feet chase eye yaw
    -- The real side to target is the one the LBY is snapping TO
    if not ast then return d.side, 35, 0.72 end

    local feet = ast.m_flCurrentFeetYaw
    local eye  = ast.m_flEyeYaw
    local goal = ast.m_flGoalFeetYaw  -- GS exposes this in animstate
    local delta = _ydelta(eye, feet)

    -- If LBY is snapping, goal feet yaw tells us the real direction
    if goal and _abs(_ydelta(goal, feet)) > 10 then
        local snap_side = _ydelta(goal, eye) > 0 and 2 or 1
        return snap_side, 0, 0.94
    end

    -- LBY stable (not updating): real yaw = feet yaw, minimal desync
    if not d.lby_updating then
        local real_side = delta > 8 and 2 or delta < -8 and 1 or d.side
        return real_side, _fl(_abs(delta) * 0.3), 0.90
    end

    -- LBY actively updating: use rate of change to predict snap direction
    local snap_dir = d.lby_2nd_deriv > 0 and 2 or 1
    return snap_dir, 15, 0.82
end

-- ── body yaw real side from pose parameter ──────────────────────────────
-- m_flPoseParameter index 11 = body yaw blend (-60 to +60 degrees mapped to 0-1)
local function _pose_side(ent)
    local raw = entity.get_prop(ent, 'm_flPoseParameter', 11) or 0.5
    -- 0.5 = centered, <0.5 = left, >0.5 = right
    -- the actual offset in degrees = (raw - 0.5) * 120
    local offset = (raw - 0.5) * 120
    if     offset >  15 then return 2, _abs(offset)  -- leaning right
    elseif offset < -15 then return 1, _abs(offset)  -- leaning left
    else                      return nil, 0
    end
end

-- ── desync from animstate directly ─────────────────────────────────────
local function _real_desync(ast)
    if not ast then return 0 end
    -- true desync = eye_yaw - current_feet_yaw
    local d = _ydelta(ast.m_flEyeYaw, ast.m_flCurrentFeetYaw)
    return d
end

-- air velocity resolver
local function _air_vel(ent, d, ast)
    local vx = entity.get_prop(ent,'m_vecVelocity[0]') or 0
    local vy = entity.get_prop(ent,'m_vecVelocity[1]') or 0
    local spd = _sqrt(vx*vx + vy*vy)
    if spd < 5 then return nil, 0, 0.35 end
    local vel_yaw = math.deg(math.atan2(vy, vx))
    local eye_yaw = ast and ast.m_flEyeYaw or 0
    local vd = _ydelta(vel_yaw, eye_yaw)
    local side = vd > 18 and 2 or vd < -18 and 1 or d.side
    local conf  = _clamp(spd / 220, 0.32, 0.76)
    local desync = _fl(_clamp(spd * 0.17, 8, 48))
    return side, desync, conf
end

-- lean-based resolver
local function _lean_resolve(d, ld)
    if d.lean_side == 0 or ld.lean_w < 0.25 then return nil end
    local side = d.lean_side > 0 and 2 or 1
    local conf = _clamp(d.lean_magnitude * 1.6, 0.55, 0.86)
    return side, _fl(ld.lean_w * 40), conf
end

-- pitch resolver
local function _pitch(d)
    if not _M.ui_pitch:get() or #d.pitch_hist < 8 then return end
    local w = _exp_weights(#d.pitch_hist, 0.85)
    local sw, wt = 0, 0
    for i, v in ipairs(d.pitch_hist) do sw = sw + v*w[i]; wt = wt + w[i] end
    local avg = wt > 0 and sw/wt or 0
    d.pitch_res = avg < -55 and 89 or avg > 55 and -89 or 0
end

-- ── main pattern resolver ────────────────────────────────────────────────
local function _pattern(ent, d, state, ld, jt, decay)
    local at, swing, bias = _classify(d, jt, decay)
    d.aa_type = at; d.aa_swing = swing
    local ast  = _astate(ent)
    local sigs = _fingerprint(ld); d.layer_sigs = sigs
    local rd   = ast and _real_desync(ast) or 0
    local side, desync, conf

    if at == 'Static' then
        -- body pose is most reliable for static
        local ps, pd2 = _pose_side(ent)
        if ps then
            side   = ps
            desync = _clamp(_fl(pd2 * 0.85), 30, 58)
            conf   = 0.91
        else
            -- fall back to last delta sign
            side   = rd > 0 and 2 or 1
            desync = _clamp(_fl(_abs(rd) * 0.80), 20, 58)
            conf   = 0.87
        end
        d.method = 'static'

    elseif at == 'Jitter' then
        side, conf = _jitter_predict(d)
        -- desync from current real delta
        desync = _clamp(_fl(_abs(rd) * 0.75), 15, 50)
        if desync < 10 then desync = _max(18, _fl(swing * 0.65)) end
        d.method = 'jitter'

    elseif at == 'LBY' then
        side, desync, conf = _resolve_lby(ent, d, ast)
        d.method = 'lby'

    elseif at == 'Swing' then
        -- swing: use real delta sign, high desync
        side   = rd > 0 and 2 or 1
        desync = _clamp(_fl(_abs(rd) * 0.88), 35, 58)
        conf   = 0.74
        d.method = 'swing'

    elseif at == 'Sway' then
        -- exponentially weighted average direction
        local w = _exp_weights(#d.deltas, decay)
        local ws, wt = 0, 0
        for i, v in ipairs(d.deltas) do ws = ws + v * w[i]; wt = wt + w[i] end
        local wavg = wt > 0 and ws / wt or 0
        side   = wavg > 0 and 2 or 1
        desync = _clamp(_fl(_abs(rd) * 0.72), 18, 48)
        if desync < 10 then desync = _fl(_clamp(swing * 0.55, 18, 48)) end
        conf   = 0.66
        d.method = 'sway'

    else  -- Chaotic / Gathering
        -- use current real delta as best guess
        side   = rd > 5 and 2 or rd < -5 and 1 or d.side
        desync = _clamp(_fl(_abs(rd) * 0.6), 10, 38)
        conf   = 0.42
        d.method = 'chaotic'
    end

    -- ── layer correction ────────────────────────────────────────────────
    -- if lean layer is heavy, trust lean side
    if ld.lean_w > 0.30 and d.lean_side ~= 0 then
        local ls = d.lean_side > 0 and 2 or 1
        local lc = _clamp(d.lean_magnitude * 1.6, 0.55, 0.86)
        if lc > conf then
            side = ls; desync = _fl(ld.lean_w * 40); conf = lc
            d.method = d.method .. '+lean'
        end
    end

    -- ── defensive override ──────────────────────────────────────────────
    if d.def_active and _M.ui_exploits:get() then
        side   = d.def_side
        desync = _max(desync, d.def_snap_cnt > d.def_flick_cnt and 50 or 54)
        conf   = _max(conf, 0.80)
        d.method = d.method .. (d.def_snap_cnt > d.def_flick_cnt and '+def_snap' or '+def_flick')
    end

    -- ── exploit overrides ───────────────────────────────────────────────
    if d.dt_active and _M.ui_exploits:get() then
        desync = _max(desync, 52); conf = _max(conf, 0.74)
        d.method = d.method .. '+dt'
    end
    if d.fd_active and _M.ui_exploits:get() then
        desync = _min(desync, 18); conf = _max(conf, 0.70)
        d.method = d.method .. '+fd'
    end

    -- ── per-state memory ────────────────────────────────────────────────
    local ss = d.state_stats[state]
    if ss and ss.hits >= 2 and ss.hits > ss.misses * 0.6 then
        side   = ss.best_side
        desync = ss.best_desync
        conf   = _max(conf, 0.88)
        d.method = d.method .. '+mem'
    end

    -- ── on-shot side history ─────────────────────────────────────────────
    if #d.os_side_hist >= 4 then
        local cnt = {[1]=0,[2]=0}
        for _, s in ipairs(d.os_side_hist) do cnt[s] = cnt[s] + 1 end
        local os = cnt[2] >= cnt[1] and 2 or 1
        if cnt[os] > cnt[3 - os] * 1.4 and os ~= side then
            side = os; conf = _max(conf, 0.70)
            d.method = d.method .. '+os'
        end
    end

    -- ── adaptive desync correction ───────────────────────────────────────
    if d.adaptive_desync and d.fail_streak >= 2 then
        desync = _fl(_lerp(desync, d.adaptive_desync, 0.50))
        d.method = d.method .. '+adapt'
    end

    -- ── confirmed side bias ──────────────────────────────────────────────
    local sh = d.side_hits
    if sh[1] + sh[2] >= 3 then
        local confirmed = sh[2] > sh[1] and 2 or 1
        if confirmed == side then
            conf = _min(1.0, conf + 0.06)
        elseif sh[confirmed] > sh[3 - confirmed] * 1.6 then
            side = confirmed; conf = _max(conf, 0.72)
            d.method = d.method .. '+confirm'
        end
    end

    -- ── state-based desync tuning ────────────────────────────────────────
    if state == ST.AIR or state == ST.AIR_CROUCH then
        -- air: try velocity-based first
        local av_s, av_d, av_c = _air_vel(ent, d, ast)
        if av_s and av_c and av_c > conf then
            side = av_s; desync = av_d; conf = av_c
            d.method = 'air_vel'
        else
            -- in air desync is less reliable, reduce slightly
            desync = _fl(desync * 0.70)
            conf   = conf * 0.85
            d.method = d.method .. '+air'
        end
    elseif state == ST.MOVE then
        -- moving: they can desync less
        desync = _fl(desync * 0.82)
    elseif state == ST.SNAKING then
        -- snaking = fast jitter, use jitter predictor
        local js, jc = _jitter_predict(d)
        side = js; conf = jc * 0.80
        desync = _fl(desync * 0.65)
        d.method = 'snaking'
    elseif state == ST.SLOWWALK then
        desync = _fl(desync * 0.90)
    elseif state == ST.CROUCH then
        desync = _fl(desync * 0.88)
    end

    return side, _clamp(_fl(desync), 0, 62), _clamp(conf, 0.0, 1.0)
end

-- ── adaptive desync estimator ────────────────────────────────────────────
local function _upd_adapt(d, missed_side, missed_desync)
    table.insert(d.miss_pattern, {side=missed_side, desync=missed_desync})
    if #d.miss_pattern > 24 then table.remove(d.miss_pattern, 1) end
    if #d.miss_pattern >= 4 then
        local sum = 0
        for _, mp in ipairs(d.miss_pattern) do sum = sum + mp.desync end
        local avg = sum / #d.miss_pattern
        -- if missing at avg desync, try the mirror value
        d.adaptive_desync = avg > 35 and _max(0, 62 - avg) or _min(62, avg + 28)
    end
end

-- ── brute force (smarter ordering) ───────────────────────────────────────
local _BRUTE = {58,-58,48,-48,38,-38,28,-28,18,-18,10,-10,0}
local function _brute(d)
    -- if we have a locked winning offset, use it
    if d.brute_locked and d.brute_best_off then
        d.method = 'brute_locked'
        local v = d.brute_best_off
        return v >= 0 and 2 or 1, _abs(v), 1.0
    end

    local idx = (d.brute_stage % #_BRUTE) + 1
    local v   = _BRUTE[idx]

    -- adaptive: jump toward estimated real desync
    if d.adaptive_desync and d.fail_streak >= 3 then
        local tgt = d.adaptive_desync
        local best_v = v; local best_d = _abs(_abs(v) - tgt)
        for _, bv in ipairs(_BRUTE) do
            local dist = _abs(_abs(bv) - tgt)
            if dist < best_d then best_d = dist; best_v = bv end
        end
        v = best_v
        d.method = _f('brute@%+d(adapt)', v)
    else
        d.method = _f('brute@%+d', v)
    end

    return v >= 0 and 2 or 1, _abs(v), 1.0
end

-- ── NN forward pass ───────────────────────────────────────────────────────
local function _nn_fwd(inp)
    local NN = _M.NN3
    local h  = {}
    for i = 1, 48 do
        local s = 0
        for j = 1, 20 do s = s + (inp[j] or 0) * NN.wh[j][i] end
        h[i] = s > 0 and s or 0.02 * s  -- leaky relu
    end
    local o = {}
    for i = 1, 3 do
        local s = 0
        for j = 1, 48 do s = s + h[j] * NN.wo[j][i] end
        o[i] = 1 / (1 + _exp(-_clamp(s, -12, 12)))
    end
    return o, h
end

local function _nn_inp(ent, d, state, ld)
    local ast  = _astate(ent)
    local vx   = entity.get_prop(ent,'m_vecVelocity[0]') or 0
    local vy   = entity.get_prop(ent,'m_vecVelocity[1]') or 0
    local spd  = _sqrt(vx*vx + vy*vy)
    local duck = entity.get_prop(ent,'m_flDuckAmount') or 0
    local rd   = ast and _real_desync(ast) or 0
    local d1   = d.deltas[#d.deltas]     or 0
    local d2   = d.deltas[#d.deltas-1]   or 0
    local d3   = d.deltas[#d.deltas-2]   or 0
    return {
        state==ST.STAND     and 1 or 0,
        state==ST.MOVE      and 1 or 0,
        state==ST.AIR       and 1 or 0,
        state==ST.CROUCH    and 1 or 0,
        state==ST.SLOWWALK  and 1 or 0,
        state==ST.AIR_CROUCH and 1 or 0,
        state==ST.SNAKING   and 1 or 0,
        _clamp(spd/260, 0, 1),
        duck,
        d1/180, d2/180, d3/180,
        rd/180,             -- real-time desync signal
        ld.aim_w,
        ld.desync_cycle,
        ld.lean_w,
        d.lby_updating and 1 or 0,
        _clamp(d.fail_streak/12, 0, 1),
        d.def_active and 1 or 0,
        d.dt_active  and 1 or 0,
    }
end

local function _hybrid(ent, d, state, ld, jt, decay)
    local ps, pd, pc = _pattern(ent, d, state, ld, jt, decay)
    local inp = _nn_inp(ent, d, state, ld)
    local nout, _ = _nn_fwd(inp)
    local ns = nout[1] > 0.52 and 2 or 1
    local nd = _fl(nout[2] * 62)
    local nc = nout[3]
    d.last_nn_inp = inp

    local trust = _clamp(((_M.NN3.trained_samples or 0)) / 15, 0, 1)

    -- always trust pattern for LBY or very high confidence
    if d.lby_updating or pc > 0.88 or trust < 0.25 then
        return ps, pd, pc
    end

    -- NN takes over for jitter/chaotic when well trained
    if (d.aa_type == 'Jitter' or d.aa_type == 'Chaotic') and trust > 0.5 then
        local eff_nc = nc * trust
        if eff_nc > pc then
            d.method = 'neural+' .. d.method
            return ns, nd, _min(eff_nc, 0.93)
        end
    end

    -- weighted blend
    local pw = pc; local nw = nc * trust; local tot = pw + nw
    if tot <= 0 then return ps, pd, pc end
    local bd  = _fl((pd*pw + nd*nw) / tot)
    local fs  = pw >= nw and ps or ns
    d.method  = 'hybrid+' .. d.method
    return fs, bd, _max(pc, nc * trust)
end

-- ── NN training ────────────────────────────────────────────────────────
local function _nn_train()
    local NN = _M.NN3
    if #NN.mem < 24 then return end
    for _ = 1, 14 do
        local s = NN.mem[math.random(1, #NN.mem)]
        local o, h = _nn_fwd(s.inp)
        local sw = s.w or 1
        -- output deltas
        local do3 = {}
        for i = 1, 3 do
            do3[i] = (s.tgt[i] - o[i]) * o[i] * (1 - o[i]) * sw
        end
        -- output weights
        for i = 1, 3 do
            for j = 1, 48 do
                local g = NN.cfg.lr * do3[i] * h[j]
                NN.vo[j][i] = NN.cfg.mom * NN.vo[j][i] + g
                NN.wo[j][i] = NN.wo[j][i] + NN.vo[j][i]
            end
        end
        -- hidden deltas
        for j = 1, 48 do
            local dh = 0
            for i = 1, 3 do dh = dh + do3[i] * NN.wo[j][i] end
            dh = dh * (h[j] > 0 and 1 or 0.02)
            for k = 1, 20 do
                local g = NN.cfg.lr * dh * (s.inp[k] or 0)
                NN.vh[k][j] = NN.cfg.mom * NN.vh[k][j] + g
                NN.wh[k][j] = NN.wh[k][j] + NN.vh[k][j]
            end
        end
    end
    NN.trained_samples = (NN.trained_samples or 0) + 1
end

local function _nn_add(d, hit, hs)
    local NN = _M.NN3
    if not d.last_nn_inp then return end
    local w = hs and 3.0 or hit and 1.2 or 1.8
    table.insert(NN.mem, {
        inp = d.last_nn_inp,
        tgt = { d.side==2 and 1.0 or 0.0, _min(d.desync/62,1), hit and 1.0 or 0.0 },
        w   = w
    })
    if #NN.mem > 2000 then table.remove(NN.mem, 1) end
end

-- ── state stats ─────────────────────────────────────────────────────────
local function _upd_ss(d, state, hit, side, desync)
    local ss = d.state_stats[state]
    if not ss then
        d.state_stats[state] = {hits=0,misses=0,best_side=side,best_desync=desync}
        ss = d.state_stats[state]
    end
    if hit then
        ss.hits = ss.hits + 1
        -- update best with exponential decay toward new value
        ss.best_side   = side
        ss.best_desync = _fl(ss.best_desync * 0.7 + desync * 0.3)
    else
        ss.misses = ss.misses + 1
    end
end

local function _suppress(ent)
    if not _M.ui_suppress:get() then return false end
    local me=entity.get_local_player(); if not me then return false end
    local mx,my=entity.get_origin(me); local ex,ey=entity.get_origin(ent)
    if not mx or not ex then return false end
    return math.sqrt((ex-mx)^2+(ey-my)^2) < _M.ui_sup_rng:get()
end

-- ── screen log ──────────────────────────────────────────────────────────
_M.log_entries={}
local function _log_add(text,r,g,b,sub)
    table.insert(_M.log_entries,1,{text=text,sub=sub or '',r=r,g=g,b=b,t=globals.curtime(),frac=0})
    while #_M.log_entries>12 do table.remove(_M.log_entries) end
end
local function _log_draw()
    if not _M.ui_log_scr:get() then return end
    local sw,sh=client.screen_size(); local W=350; local bx=sw-20; local by=sh-80; local cy=by; local rm={}
    for i,e in ipairs(_M.log_entries) do
        local age=globals.curtime()-e.t
        if age<7 then e.frac=e.frac+(1-e.frac)*0.16
        else e.frac=e.frac+(0-e.frac)*0.07; if e.frac<0.01 then rm[#rm+1]=i end end
        local fr=e.frac; if fr<0.02 then goto _ls end
        do
            local a=_fl(255*fr); local x=bx-W+_fl(28*(1-fr)); local y=cy
            local hs=e.sub~=''; local ch=hs and 36 or 21
            renderer.rectangle(x,y,W,ch,12,12,16,_fl(195*fr))
            renderer.rectangle(x,y,3,ch,e.r,e.g,e.b,a)
            renderer.text(x+10,y+7,e.r,e.g,e.b,a,'b',0,e.text)
            if hs then
                renderer.rectangle(x+10,y+20,W-13,1,255,255,255,_fl(16*fr))
                renderer.text(x+10,y+22,200,200,200,_fl(a*0.86),'d',0,e.sub)
            end
            cy=cy-(ch+5)*fr
        end
        ::_ls::
    end
    for i=#rm,1,-1 do table.remove(_M.log_entries,rm[i]) end
end

local function _ms(m)
    if not m or m=='' then return 'none' end
    local map={lby='lby',jitter='jitter',air_vel='air_vel',def_snap='def_snap',
               def_flick='def_flick',brute='brute',neural='neural',hybrid='neural',
               static='static',swing='swing',sway='sway',snaking='snaking',lean='lean'}
    for k,v in pairs(map) do if m:find(k) then return v end end
    return m:sub(1,12)
end

-- ── adaptive desync update ───────────────────────────────────────────────
local function _upd_adapt(d,ms2,md)
    table.insert(d.miss_pattern,{side=ms2,desync=md,tick=globals.tickcount()})
    if #d.miss_pattern>20 then table.remove(d.miss_pattern,1) end
    if #d.miss_pattern>=4 then
        local sum=0; for _,mp in ipairs(d.miss_pattern) do sum=sum+mp.desync end
        local avg=sum/#d.miss_pattern
        d.adaptive_desync=avg>30 and _max(0,60-avg) or _min(60,avg+30)
    end
end

local function _upd_ss(d,state,hit,side,desync)
    local ss=d.state_stats[state]
    if not ss then d.state_stats[state]={hits=0,misses=0,best_side=1,best_desync=40}; ss=d.state_stats[state] end
    if hit then ss.hits=ss.hits+1; ss.best_side=side; ss.best_desync=desync
    else ss.misses=ss.misses+1 end
end

-- ── main paint: resolve all enemies ─────────────────────────────────────
client.set_event_callback('paint',function()
    if not _auth_alive or not _M.ui_en:get() then return end
    _log_draw()
    local mode=_M.ui_mode:get(); local jt=_M.ui_jt:get(); local decay=_M.ui_hist_w:get()/100
    local me=entity.get_local_player(); local enemies=entity.get_players(true)
    for _,ent in ipairs(enemies) do
        if not entity.is_alive(ent) then goto _rsk end
        local sim=entity.get_prop(ent,'m_flSimulationTime') or 0
        local d=_db(ent); if d.last_sim==sim then goto _rsk end; d.last_sim=sim
        _track_lby(ent,d); _track_bt(ent,d); _track_def(ent,d)
        _track_lean(ent,d); _track_fd(ent,d); _track_exploit(ent,d)
        _conf_decay(d); d.conf_last_update=globals.curtime()
        local state=_gstate(ent); local ld=_gld(ent)
        local side,desync,conf
        if d.fail_streak>=5 or mode=='Bruteforce Only' then side,desync,conf=_brute(d)
        elseif mode=='Hybrid Engine' then side,desync,conf=_hybrid(ent,d,state,ld,jt,decay)
        else side,desync,conf=_pattern(ent,d,state,ld,jt,decay) end
        if conf<_M.ui_conf_w:get()/100 then side=d.side; desync=d.desync end
        -- multi-point
        if _M.ui_multipt:get() and me and entity.is_alive(me) then
            local ex,ey,ez=client.eye_position()
            if ex then
                local ast=_astate(ent); local base_yaw=ast and ast.m_flEyeYaw or 0
                local best_off=desync*(side==2 and 1 or -1); local best=-1
                for _,off in ipairs({-60,-40,-20,0,20,40,60}) do
                    local tx=ex+math.cos(math.rad(base_yaw+off))*2
                    local ty=ey+math.sin(math.rad(base_yaw+off))*2
                    local frac=client.trace_line(me,ex,ey,ez,tx,ty,ez+68)
                    if (frac or 0)>best then best=frac or 0; best_off=off end
                end
                side=best_off>=0 and 2 or 1; desync=_abs(best_off)
            end
        end
        _pitch(d); d.side=side; d.desync=desync; d.confidence=conf
        pcall(plist.set,ent,'Y offset',_suppress(ent) and 0 or desync*(side==2 and 1 or -1))
        if _M.ui_pitch:get() and d.pitch_res~=0 then pcall(plist.set,ent,'Pitch override',d.pitch_res) end
        ::_rsk::
    end
    if mode=='Hybrid Engine' then _nn_train() end
    if globals.tickcount()%10==0 then
        local ok,thr=pcall(client.current_threat)
        if ok and thr and thr>0 and _M.DB[thr] then
            local d=_M.DB[thr]; local st=_gstate(thr); local ld=_gld(thr)
            local sigs=table.concat(d.layer_sigs or {},' ')
            local expl=(d.exploit_type~='none' and d.exploit_type or '-')..(d.dt_active and ' DT' or '')..(d.fd_active and ' FD' or '')
            _M.lbl_method:set(_f('Method: %s (%.0f%%)',_ms(d.method or 'none'),(d.confidence or 0)*100))
            _M.lbl_aa:set(_f('AA Type: %s  swing:%.0f  freq:%d',d.aa_type or '-',d.aa_swing or 0,d.jitter_freq or 0))
            _M.lbl_desync:set(_f('Desync: %ddeg  %s  adapt:%s',d.desync or 0,d.side==2 and 'R' or 'L',d.adaptive_desync and _f('%.0f',d.adaptive_desync) or '-'))
            _M.lbl_lby:set(_f('LBY: %s  snaps:%d  d2:%.2f',d.lby_updating and 'updating' or 'stable',d.lby_snap_cnt or 0,d.lby_2nd_deriv or 0))
            _M.lbl_streak:set(_f('Streak: %d miss | %d hit',d.fail_streak or 0,d.hit_streak or 0))
            _M.lbl_conf:set(_f('Confidence: %.0f%%  NN:%d',( d.confidence or 0)*100,(_M.NN3.trained_samples or 0)))
            _M.lbl_state:set(_f('State: %s  lean:%s(%.2f)  def:%s',ST_STR[st] or '?',d.lean_side==1 and 'R' or d.lean_side==-1 and 'L' or '-',d.lean_magnitude or 0,d.def_active and 'active' or 'off'))
            _M.lbl_layers:set(_f('Layers: aim=%.2f lean=%.2f dc=%.3f [%s]',ld.aim_w,ld.lean_w,ld.desync_cycle,sigs))
            _M.lbl_exploit:set(_f('Exploit: %s  tb:%d  fd:%.1f',expl,d.tb_shift or 0,d.fd_count or 0))
        end
    end
end)

-- ── aim_hit ──────────────────────────────────────────────────────────────
client.set_event_callback('aim_hit',function(e)
    if not _auth_alive or not _M.ui_en:get() then return end
    local ent=e.target; if not ent then return end
    local d=_db(ent); local hs=e.hitgroup==1; local dmg=e.damage or 0
    local bt=e.tick and _clamp(globals.tickcount()-e.tick,0,64) or 0
    local name=entity.get_player_name(ent) or '?'
    local hgn={[0]='body',[1]='head',[2]='chest',[3]='stomach',[4]='l.arm',[5]='r.arm',[6]='l.leg',[7]='r.leg'}
    local hg=hgn[e.hitgroup] or 'body'; local ms=_ms(d.method or 'none'); local conf=_fl((d.confidence or 0)*100)
    local state=_gstate(ent)
    if hs then d.fail_streak=0; d.brute_stage=0; d.brute_locked=false; d.miss_pattern={}
    else d.fail_streak=_max(0,d.fail_streak-1); if d.brute_stage>0 then d.brute_stage=_max(0,d.brute_stage-1) end end
    d.hit_count=d.hit_count+1; d.hit_streak=d.hit_streak+1
    d.side_hits[d.side]=(d.side_hits[d.side] or 0)+(hs and 2 or 1)
    _upd_ss(d,state,true,d.side,d.desync)
    -- NN training on hit
    if _M.ui_mode:get()=='Hybrid Engine' then _nn_add(d, true, hs) end
    -- lock brute on headshot
    if hs and d.brute_stage > 0 then
        d.brute_locked = true
        d.brute_best_off = d.desync * (d.side==2 and 1 or -1)
    end
    local main=hs and _f('Killed %s with a head shot for %d damage',name,dmg) or _f('Hit %s in the %s for %d damage',name,hg,dmg)
    local sub=_f('reso: %s @ %d%%  \xc2\xb7  bt:%dt',ms,conf,bt)
    if _M.ui_log_scr:get() then local r,g,b=hs and 110 or 170,hs and 215 or 175,hs and 85 or 85; _log_add(main,r,g,b,sub) end
    if _M.ui_log_con:get() then local cr,cg,cb=hs and 100 or 180,hs and 255 or 220,100; client.color_log(cr,cg,cb,main..'  \xc2\xb7  '..sub..'\0') end
end)

-- ── aim_miss ─────────────────────────────────────────────────────────────
client.set_event_callback('aim_miss',function(e)
    if not _auth_alive or not _M.ui_en:get() then return end
    local ent=e.target; if not ent then return end
    if e.reason=='spread' then return end
    local d=_db(ent); local name=entity.get_player_name(ent) or '?'; local ms=_ms(d.method or 'none')
    local state=_gstate(ent)
    d.miss_count=d.miss_count+1; d.fail_streak=d.fail_streak+1; d.hit_streak=0
    d.brute_stage=(d.brute_stage+1)%13; d.side=d.side==1 and 2 or 1
    _upd_adapt(d,d.side,d.desync); _upd_ss(d,state,false,d.side,d.desync)
    if d.aa_type=='Jitter' then d.jitter_phase=(d.jitter_phase+0.5)%1.0 end
    -- NN training on miss
    if _M.ui_mode:get()=='Hybrid Engine' then _nn_add(d, false, false) end
    -- unlock brute on miss so it can search again
    d.brute_locked = false
    local reason=e.reason or '?'
    if _M.ui_log_scr:get() then _log_add(_f('Missed %s (%s)',name,reason),205,75,75,_f('reso: %s  streak:%d  next:%s',ms,d.fail_streak,d.side==2 and 'R' or 'L')) end
    if _M.ui_log_con:get() then client.color_log(255,100,100,_f('[ZRes] MISS %s  reason:%s  streak:%d  next:%s\0',name,reason,d.fail_streak,d.side==2 and 'R' or 'L')) end
end)

-- ── round_start ──────────────────────────────────────────────────────────
client.set_event_callback('round_start',function()
    for _,d in pairs(_M.DB) do
        d.fail_streak=0; d.hit_streak=0; d.brute_stage=0; d.brute_locked=false
        d.def_snap_cnt=0; d.def_flick_cnt=0; d.def_active=false
        d.miss_pattern={}; d.adaptive_desync=nil
    end
end)
client.set_event_callback('player_disconnect',function(e)
    local idx=e and client.userid_to_entindex(e.userid); if idx then _M.DB[idx]=nil end
end)

_G.ZenithResolver_GetData=_db

resolver_show_tab=function()
    _safe_display(_M.ui_en)
    if not _M.ui_en:get() then return end
    _safe_display(_M.ui_mode);    _safe_display(_M.ui_verbose); _safe_display(_M.ui_debug)
    _safe_display(_M.ui_pitch);   _safe_display(_M.ui_exploits);_safe_display(_M.ui_multipt)
    _safe_display(_M.ui_log_scr); _safe_display(_M.ui_log_con)
    _safe_display(_M.ui_suppress); if _M.ui_suppress:get() then _safe_display(_M.ui_sup_rng) end
    _safe_display(_M.ui_jt);      _safe_display(_M.ui_conf_w); _safe_display(_M.ui_hist_w)
    _safe_display(_M.lbl_method); _safe_display(_M.lbl_aa);    _safe_display(_M.lbl_desync)
    _safe_display(_M.lbl_lby);    _safe_display(_M.lbl_streak);_safe_display(_M.lbl_conf)
    _safe_display(_M.lbl_state);  _safe_display(_M.lbl_layers);_safe_display(_M.lbl_exploit)
end

end)()
::_resolver_end::
