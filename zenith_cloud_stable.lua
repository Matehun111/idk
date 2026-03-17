-- ZENITH | STABLE | Cloud Build

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

-- version gates
local _HAS_AIMBOT   = (BUILD == 'beta' or BUILD == 'nightly')
local _HAS_RESOLVER = (BUILD == 'nightly')

--- declarations
local f = string.format
local merge = table.concat

--- modules
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

--- defines
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

--- region utils
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

--- region software


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

--- region override
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

--- region iengineclient
do
    local native_GetNetChannelInfo = vtable_bind("engine.dll", "VEngineClient014", 78, "void*(__thiscall*)(void*)")

    function iengineclient.get_net_channel_info()
        return native_GetNetChannelInfo()
    end
end

--- region inetchannel
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

--- region ceaser
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

--- region menu

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


-- ======================================================================
--  ZENITH UI  -  Zenith pui tabs
--  Tabs: Anti Aim | Visuals | Misc | Configs
--  (replaces the original gui.selection combobox approach)
-- ======================================================================

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

-- ═══════════════════════════════════════════════════════════════════════════
-- ZENITH PREMIUM MENU ICONS & STYLING
-- ═══════════════════════════════════════════════════════════════════════════
pui.macros.dot = '\v\xE2\x96\xB8  \r'  -- Right-pointing triangle

-- Menu Icons (UTF-8 encoded)
local ICONS = {
    diamond     = '\xE2\x97\x86',  -- ◆
    user        = '\xE2\x96\xB8',  -- ▸
    branch      = '\xE2\x94\x94',  -- └
    version     = '\xE2\x96\xA3',  -- ▣
    online      = '\xE2\x97\x89',  -- ◉
    info        = '\xE2\x93\x98',  -- ⓘ
    clock       = '\xE2\x97\x8B',  -- ○
    stats       = '\xE2\x96\xA0',  -- ■
    check       = '\xE2\x9C\x93',  -- ✓
    arrow_r     = '\xE2\x96\xB6',  -- ▶
    bullet      = '\xE2\x80\xA2',  -- •
    line_v      = '\xE2\x94\x82',  -- │
    line_h      = '\xE2\x94\x80',  -- ─
    corner      = '\xE2\x94\x8C',  -- ┌
}

-- ── TAB SELECTOR ───────────────────────────────────────────────────────
local vars = {}

do -- selection
    vars.selection = {}
    vars.selection.label = group_fakelag:label('\a7ec8e3ffZenith  \a888888ff' .. ICONS.diamond .. '  \a666666ffElegance in Execution.')
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
shared.fl_whatsup = group_fakelag:label(string.format('\a888888ff %s \affffffffUser   \a888888ff> \a71bc78ff%s', ICONS.user, USERNAME))
shared.fl_build = group_fakelag:label(string.format('\a888888ff %s \affffffffBranch  \a888888ff> \a71bc78ffStable', ICONS.branch))
shared.fl_version = group_fakelag:label(string.format('\a888888ff %s \affffffffVersion  \a888888ff> \a71bc78ff3.0', ICONS.version))
shared.fl_online = group_fakelag:label(string.format('\a888888ff %s \affffffffOnline  \a888888ff> \affd700ff...', ICONS.online))

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

    -- Online users: heartbeat-based, self-healing
    -- Each user writes a timestamp every 30s; count entries < 90s old = online
    local _HB_KEY = 'zenith_online_hb_v1'
    local _my_hb_user = (_auth_user or 'unknown') .. '_' .. tostring(math.random(10000,99999))

    local function _set_online(n)
        if shared.fl_online then
            local col = n > 0 and '\affd700ff' or '\aff6666ff'
            shared.fl_online:set(string.format('\a888888ff \xE2\x97\x89 \affffffffOnline  \a888888ff> %s%d', col, n))
        end
    end

    local function _hb_tick()
        local ok_r, tbl = pcall(database.read, _HB_KEY)
        tbl = (ok_r and type(tbl) == 'table') and tbl or {}
        local now = math.floor(globals.realtime())
        tbl[_my_hb_user] = now
        -- prune entries older than 120s
        for k, t in pairs(tbl) do
            if (now - t) > 120 then tbl[k] = nil end
        end
        pcall(database.write, _HB_KEY, tbl)
        -- count entries seen within last 90s
        local cnt = 0
        for _, t in pairs(tbl) do
            if (now - t) <= 90 then cnt = cnt + 1 end
        end
        _set_online(cnt)
        client.delay_call(30, _hb_tick)
    end

    client.set_event_callback('shutdown', function()
        local ok_r, tbl = pcall(database.read, _HB_KEY)
        if ok_r and type(tbl) == 'table' then
            tbl[_my_hb_user] = nil
            pcall(database.write, _HB_KEY, tbl)
        end
    end)

    client.delay_call(2, _hb_tick)
end







-- ── STATISTICS (Misc sidebar) ──────────────────────────────────────────
do
    vars.statistics = {}

    vars.statistics.label_info  = group_other:label('\a7ec8e3ff\xE2\x93\x98 \affffffffInformation')
    vars.statistics.user        = group_other:label('\a888888ff\xE2\x96\xB8 \affffffffUser: \a71bc78ff'..USERNAME)
    vars.statistics.loaded      = group_other:label(string.format('\a888888ff\xE2\x96\xA0 \affffffffTimes Loaded: \affd700ff%d', _G._zenith_load_count or 0))
    vars.statistics.time_in_game= group_other:label('\a888888ff\xE2\x97\x8B \affffffffSession: \a71bc78ff')
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
-- gui.selection: real combobox for sub-page navigation inside Anti Aim
gui = gui or {}
-- gui.enabled stub (checkbox removed, always on)
gui.enabled = gui.enabled or { get=function() return true end, set=function() end, set_callback=function() end }

if not gui.selection or not gui.selection.ref then
    -- Build the page list based on version
    local pages = {"Home", "Setup", "Builder", "Visual", "Configs"}
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
--- region motion
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
    --- region windows
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

--- region graphics
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

--- region decorations
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

--- region exploit
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

--- region localplayer
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

--- region statement
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

--- region antiaim
do
    local ctx = { }

    local zenithyaw_ways = {
        ["2-Way"] = { -0.5, 0.5 },
        ["3-Way"] = { -0.5, 0, 0.5 },
        ["5-Way"] = { -0.75, 1, 0, 0.4, -0.25 }
    }

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
            local way = ways[(localplayer.packets % #ways) + 1]

            -- god ( qhose ) forgive me for the piece of code below
            --- region lulz diagnostics disable@

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
        if ctx.enabled ~= nil then
            override.set(software.aa.angles.enabled, ctx.enabled)
        else
            override.set(software.aa.angles.enabled, true)
        end

        if ctx.pitch ~= nil then
            override.set(software.aa.angles.pitch[1], ctx.pitch)
            -- apply custom offset immediately, don't rely on ui.get to see the override
            if ctx.pitch_offset ~= nil then
                override.set(software.aa.angles.pitch[2], utils.clamp(ctx.pitch_offset, -89, 89))
            else
                override.unset(software.aa.angles.pitch[2])
            end
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
            override.set(software.aa.angles.freestanding[1], ctx.freestanding)
            override.set(software.aa.angles.freestanding[2], ctx.freestanding and
                "Always on" or "On hotkey")
        end

        if ctx.roll ~= nil then
            override.set(software.aa.angles.roll, ctx.roll)
        end

        local yaw_value = ui.get(software.aa.angles.yaw[1])
        local body_yaw_value = ui.get(software.aa.angles.body_yaw[1])

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
        
        -- DEBUG: print ctx values once per second
        if globals.tickcount() % 64 == 0 then
            print("[ZENITH DEBUG] ctx.yaw=" .. tostring(ctx.yaw) .. " ctx.yaw_offset=" .. tostring(ctx.yaw_offset) .. " ctx.yaw_jitter=" .. tostring(ctx.yaw_jitter) .. " ctx.body_yaw=" .. tostring(ctx.body_yaw))
        end
    end
end

---region settings tweaks
do
    settings.tweaks_enable = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Features")
    : record("settings", "settings::tweaks_enable")
    : save()

    settings.tweaks = menu.new_item(ui.new_multiselect, 'AA', 'Anti-aimbot angles', merge { "- Functions", "\n", "settings::tweaks" }, { 'Log Aimbot Shots', 'Damage Marker', 'Trashtalk' })
    : record("settings", "settings::tweaks")
    : save()
end

--- region widgets
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

    widgets.display = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", merge { "- Display", "\n", "widgets::display" }, { "Username", "Latency", "Time", "FPS", "Server frametime", "Game Mode" })
    : record("visuals", "widgets::display")
    : save()

    widgets.custom_name = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Custom Name", { "Username", "Latency", "Time", "FPS", "Server frametime" })
    : record("visuals", "widgets::custom_name")
    : save()

    widgets.custom_name_value = menu.new_item(ui.new_textbox, "AA", "Anti-aimbot angles", "Nickname")
    : record("visuals", "widgets::custom_name_value")
    : save()
end

--- region fast ladder
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


--- region defensive
-- Valkyrie AA System (ported to Zenith ctx API)
do
    local G  = "AA"
    local GR = "Anti-aimbot angles"

    -- helpers
    local function norm_yaw(a) return ((a + 180) % 360) - 180 end
    local function has(list, val)
        if not list then return false end
        for _,v in ipairs(list) do if v == val then return true end end
        return false
    end

    -- state definitions (8 states matching Valkyrie)
    local AA_STATES = {"Global","Standing","Moving","Slowwalking","Crouching","Air","Air-Crouching","Snaking"}
    local AA_STATE_SHORT = {"G","S","M","SW","C","A","AC","SN"}

    -- ── UI: team picker + copy ────────────────────────────────────────
    local ui_team = menu.new_item(ui.new_combobox, G, GR,
        merge{"Team", "\n", "hd::team"}, "CT", "T")
        :record("aa","hd::team"):save()
    local ui_copy = menu.new_item(ui.new_button, G, GR,
        merge{"Copy to other team", "\n", "hd::copy"}, function() end)

    -- ── UI: state selector ────────────────────────────────────────────
    local ui_state = menu.new_item(ui.new_combobox, G, GR,
        merge{"State", "\n", "hd::state"}, table.unpack(AA_STATES))
        :record("aa","hd::state"):save()

    -- ── UI: per-state AA items (all 8 states) ─────────────────────────
    local ab = {}   -- ab[state_idx] = { all ui items }
    for i = 1, #AA_STATES do
        local sfx = "_s"..i
        ab[i] = {
            enableState  = menu.new_item(ui.new_checkbox,    G,GR, merge{"Enable "..AA_STATES[i].."\n","hd::en"..sfx}):record("aa","hd::en"..sfx):save(),
            pitch        = menu.new_item(ui.new_combobox,    G,GR, merge{"Pitch\n","hd::pitch"..sfx},  "Off","Default","Up","Down","Minimal","Random","Custom"):record("aa","hd::pitch"..sfx):save(),
            pitchSlider  = menu.new_item(ui.new_slider,      G,GR, merge{"Pitch add\n","hd::pitchs"..sfx}, -89,89,0,true,"deg",1):record("aa","hd::pitchs"..sfx):save(),
            yawBase      = menu.new_item(ui.new_combobox,    G,GR, merge{"Yaw base\n","hd::yb"..sfx}, "Local view","At targets"):record("aa","hd::yb"..sfx):save(),
            yaw          = menu.new_item(ui.new_combobox,    G,GR, merge{"Yaw\n","hd::yaw"..sfx}, "Off","180","Spin","Slow Yaw","L&R"):record("aa","hd::yaw"..sfx):save(),
            yawStatic    = menu.new_item(ui.new_slider,      G,GR, merge{"Yaw offset\n","hd::ys"..sfx}, -180,180,0,true,"deg",1):record("aa","hd::ys"..sfx):save(),
            yawLeft      = menu.new_item(ui.new_slider,      G,GR, merge{"Left\n","hd::yl"..sfx}, -180,180,-19,true,"deg",1):record("aa","hd::yl"..sfx):save(),
            yawRight     = menu.new_item(ui.new_slider,      G,GR, merge{"Right\n","hd::yr"..sfx}, -180,180,36,true,"deg",1):record("aa","hd::yr"..sfx):save(),
            yawDelay     = menu.new_item(ui.new_slider,      G,GR, merge{"Yaw delay\n","hd::yd"..sfx}, 1,128,16,true,"t",1):record("aa","hd::yd"..sfx):save(),
            yawJitter    = menu.new_item(ui.new_combobox,    G,GR, merge{"Yaw jitter\n","hd::yj"..sfx}, "Off","Offset","Center","L&R","3-Way"):record("aa","hd::yj"..sfx):save(),
            yawJitterStatic = menu.new_item(ui.new_slider,   G,GR, merge{"Jitter offset\n","hd::yjs"..sfx}, -180,180,0,true,"deg",1):record("aa","hd::yjs"..sfx):save(),
            yawJitterLeft  = menu.new_item(ui.new_slider,    G,GR, merge{"Jitter L\n","hd::yjl"..sfx}, -180,180,-14,true,"deg",1):record("aa","hd::yjl"..sfx):save(),
            yawJitterRight = menu.new_item(ui.new_slider,    G,GR, merge{"Jitter R\n","hd::yjr"..sfx}, -180,180,14,true,"deg",1):record("aa","hd::yjr"..sfx):save(),
            wayFirst     = menu.new_item(ui.new_slider,      G,GR, merge{"Way 1\n","hd::w1"..sfx}, -180,180,21,true,"deg",1):record("aa","hd::w1"..sfx):save(),
            waySecond    = menu.new_item(ui.new_slider,      G,GR, merge{"Way 2\n","hd::w2"..sfx}, -180,180,-18,true,"deg",1):record("aa","hd::w2"..sfx):save(),
            wayThird     = menu.new_item(ui.new_slider,      G,GR, merge{"Way 3\n","hd::w3"..sfx}, -180,180,0,true,"deg",1):record("aa","hd::w3"..sfx):save(),
            bodyYaw      = menu.new_item(ui.new_combobox,    G,GR, merge{"Body yaw\n","hd::by"..sfx}, "Off","Opposite","Jitter","Static"):record("aa","hd::by"..sfx):save(),
            bodyYawStatic= menu.new_item(ui.new_slider,      G,GR, merge{"Body yaw offset\n","hd::bys"..sfx}, -180,180,180,true,"deg",1):record("aa","hd::bys"..sfx):save(),
            -- Defensive AA
            defensiveAA     = menu.new_item(ui.new_checkbox,    G,GR, merge{"Defensive AA\n","hd::daa"..sfx}):record("aa","hd::daa"..sfx):save(),
            defensiveTriggers=menu.new_item(ui.new_multiselect, G,GR, merge{"Def triggers\n","hd::dtr"..sfx}, "Always","Tick","Weapon switch"):record("aa","hd::dtr"..sfx):save(),
            defensiveTickTrigger=menu.new_item(ui.new_slider,   G,GR, merge{"Trigger tick\n","hd::dtt"..sfx}, 1,13,1,true,"t",1):record("aa","hd::dtt"..sfx):save(),
            defensivePitch  = menu.new_item(ui.new_combobox,    G,GR, merge{"Def pitch\n","hd::dp"..sfx}, "Static","Random","Spin","Jitter","Sine Wave","Random Logic"):record("aa","hd::dp"..sfx):save(),
            defensivePitchMin=menu.new_item(ui.new_slider,      G,GR, merge{"Def pitch min\n","hd::dpm"..sfx}, -89,89,-89,true,"deg",1):record("aa","hd::dpm"..sfx):save(),
            defensivePitchMax=menu.new_item(ui.new_slider,      G,GR, merge{"Def pitch max\n","hd::dpM"..sfx}, -89,89,89,true,"deg",1):record("aa","hd::dpM"..sfx):save(),
            defensivePitchSpeed=menu.new_item(ui.new_slider,    G,GR, merge{"Def pitch spd\n","hd::dps"..sfx}, 1,18,6,true,"t",1):record("aa","hd::dps"..sfx):save(),
            defensiveYaw    = menu.new_item(ui.new_combobox,    G,GR, merge{"Def yaw\n","hd::dy"..sfx}, "Off","Static","Random","Spin","Jitter","Logic Shift","Zenith Bypass"):record("aa","hd::dy"..sfx):save(),
            defensiveYawStatic=menu.new_item(ui.new_slider,     G,GR, merge{"Def yaw offset\n","hd::dys"..sfx}, -180,180,0,true,"deg",1):record("aa","hd::dys"..sfx):save(),
            defensiveYawSpinLeft=menu.new_item(ui.new_slider,   G,GR, merge{"Spin L\n","hd::dysl"..sfx}, -180,180,-120,true,"deg",1):record("aa","hd::dysl"..sfx):save(),
            defensiveYawSpinRight=menu.new_item(ui.new_slider,  G,GR, merge{"Spin R\n","hd::dysr"..sfx}, -180,180,120,true,"deg",1):record("aa","hd::dysr"..sfx):save(),
            defensiveYawSpinSpeed=menu.new_item(ui.new_slider,  G,GR, merge{"Spin spd\n","hd::dyss"..sfx}, 1,16,6,true,"t",1):record("aa","hd::dyss"..sfx):save(),
            defensiveYawJitterRange=menu.new_item(ui.new_slider,G,GR, merge{"Jitter range\n","hd::dyjr"..sfx}, 0,180,90,true,"deg",1):record("aa","hd::dyjr"..sfx):save(),
            defensiveYawJitterDelay=menu.new_item(ui.new_slider,G,GR, merge{"Jitter delay\n","hd::dyjd"..sfx}, 1,16,1,true,"t",1):record("aa","hd::dyjd"..sfx):save(),
        }
        -- Global state (index 1) always enabled with sane defaults
        if i == 1 then
            ab[i].enableState:set(true)
            client.delay_call(0, function()
                -- only set defaults if config hasn't loaded custom values
                if ab[1].pitch:get() == "Off" then ab[1].pitch:set("Down") end
                if ab[1].yaw:get() == "Off"   then ab[1].yaw:set("L&R")   end
            end)
        end
    end

    -- ── Extra controls (from old Zenith hd) ───────────────────────────
    local ui_freestand   = menu.new_item(ui.new_hotkey, G,GR, merge{"Freestanding","\n","hd::freestand"}):record("aa","hd::freestand"):save()
    local ui_inverter    = menu.new_item(ui.new_hotkey, G,GR, merge{"Inverter","\n","hd::inverter"}):record("aa","hd::inverter"):save()
    local ui_man_en      = menu.new_item(ui.new_checkbox, G,GR, "Manual Yaw"):record("aa","hd::man_en"):save()
    local ui_man_left    = menu.new_item(ui.new_hotkey, G,GR, merge{"  Left","\n","hd::man_l"}):record("aa","hd::man_l"):save()
    local ui_man_right   = menu.new_item(ui.new_hotkey, G,GR, merge{"  Right","\n","hd::man_r"}):record("aa","hd::man_r"):save()
    local ui_man_reset   = menu.new_item(ui.new_hotkey, G,GR, merge{"  Reset","\n","hd::man_rs"}):record("aa","hd::man_rs"):save()
    local ui_vulnlc      = menu.new_item(ui.new_multiselect, G,GR,
        merge{"LC Breaker","\n","hd::vulnlc"}, "Charged","Shifting","Uncharged")
        :record("aa","hd::vulnlc"):save()
    local ui_safehead    = menu.new_item(ui.new_multiselect, G,GR,
        merge{"Safe head","\n","hd::safehead"}, "Always","Low HP","Knife","Zeus")
        :record("aa","hd::safehead"):save()
    -- Fake lag
    local ui_fl_on       = menu.new_item(ui.new_checkbox, G,GR, merge{"Fake Lag","\n","hd::fl_on"}):record("aa","hd::fl_on"):save()
    local ui_fl_mode     = menu.new_item(ui.new_combobox, G,GR, merge{"Amount","\n","hd::fl_mode"}, "Dynamic","Maximum","Fluctuate"):record("aa","hd::fl_mode"):save()
    local ui_fl_variance = menu.new_item(ui.new_slider, G,GR, merge{"Variance","\n","hd::fl_var"}, 0,100,59,true,"%"):record("aa","hd::fl_var"):save()
    local ui_fl_limit    = menu.new_item(ui.new_slider, G,GR, merge{"Limit","\n","hd::fl_lim"}, 1,14,14,true,"t"):record("aa","hd::fl_lim"):save()
    local ui_fl_settings = menu.new_item(ui.new_combobox, G,GR, merge{"Settings","\n","hd::fl_settings"}, "Custom","Minimum","Maximum"):record("aa","hd::fl_settings"):save()

    -- ── Runtime state ─────────────────────────────────────────────────
    local pState         = 1
    local last_state_raw = 1
    local aa_inverter    = false
    local aa_inverter_tick = 0
    local manual_side    = nil
    local def_persistent = { yaw_spin=0, pitch_spin=0, last_weapon_switch=0 }

    -- Tickbase shift tracker (detects DT/hideshot = defensive active)
    local def_tracker = {
        max_tb=0, is_def=false, last_valid=0, record_count=0,
        smoothing=3, ticks_count=0, invalid={}, history={}
    }
    local function reset_def_tracker()
        def_tracker.max_tb=0; def_tracker.is_def=false; def_tracker.last_valid=0
        def_tracker.record_count=0; def_tracker.ticks_count=0
        def_tracker.invalid={}; def_tracker.history={}
    end
    local function update_def_tracker(lp)
        if not lp or not entity.is_alive(lp) then reset_def_tracker(); return end
        local tc = globals.tickcount()
        local tb = entity.get_prop(lp,"m_nTickBase") or 0
        local shifted = tb < tc
        if math.abs(tb - def_tracker.max_tb) > 64 and shifted then reset_def_tracker() end
        if tb > def_tracker.max_tb then
            def_tracker.max_tb = tb
            if not def_tracker.invalid[tb] then
                def_tracker.record_count = def_tracker.record_count + 1
                def_tracker.last_valid = tb
            end
        elseif tb < def_tracker.max_tb then
            local diff = def_tracker.max_tb - tb
            if shifted and diff >= 1 and diff <= 14 then
                table.insert(def_tracker.history, diff)
                if #def_tracker.history > def_tracker.smoothing then
                    table.remove(def_tracker.history, 1)
                end
            else
                def_tracker.history = {}
            end
            local total = 0
            for _,v in ipairs(def_tracker.history) do total=total+v end
            def_tracker.ticks_count = #def_tracker.history>0 and total/#def_tracker.history or 0
        end
        def_tracker.is_def = def_tracker.ticks_count >= 1 and def_tracker.ticks_count <= 14
        if def_tracker.record_count >= 2 then
            def_tracker.invalid[def_tracker.last_valid] = true
            def_tracker.record_count=0; def_tracker.last_valid=0; def_tracker.history={}
        end
    end
    client.set_event_callback("round_start", reset_def_tracker)

    -- CT/T persistence
    local aa_persistence = { CT={}, T={} }
    local aa_last_team   = "CT"

    local function get_team_state()
        local data = {}
        for i = 1, #AA_STATES do
            data[i] = {}
            for k,v in pairs(ab[i]) do
                local ok, val = pcall(function() return v:get() end)
                if ok then data[i][k] = val end
            end
        end
        return data
    end
    local function set_team_state(data)
        if not data then return end
        for i = 1, #AA_STATES do
            if data[i] then
                for k,v in pairs(ab[i]) do
                    if data[i][k] ~= nil then
                        pcall(function() v:set(data[i][k]) end)
                    end
                end
            end
        end
    end

    ui.set_callback(ui_team.ref, function()
        local new_team = ui_team:get()
        if new_team == aa_last_team then return end
        aa_persistence[aa_last_team] = get_team_state()
        if not aa_persistence[new_team] then
            aa_persistence[new_team] = get_team_state()
        end
        set_team_state(aa_persistence[new_team])
        aa_last_team = new_team
    end)
    ui.set_callback(ui_copy.ref, function()
        local cur   = ui_team:get()
        local other = cur == "CT" and "T" or "CT"
        aa_persistence[other] = get_team_state()
        client.color_log(150,200,60,"[Zenith] Copied "..cur.." AA to "..other)
    end)

    client.set_event_callback("item_equip", function(e)
        if client.userid_to_entindex(e.userid) == entity.get_local_player() then
            def_persistent.last_weapon_switch = globals.curtime()
        end
    end)

    -- ── Fake lag ──────────────────────────────────────────────────────
    local function apply_fakelag()
        local fl = software.aa and software.aa.fakelag
        if not fl then return end
        if not ui_fl_on:get() then
            pcall(ui.set, fl.enabled[1], false)
            return
        end
        local mode = ui_fl_mode:get()
        local lim  = ui_fl_limit:get()
        local var  = ui_fl_variance:get() / 100
        pcall(ui.set, fl.enabled[1], true)
        pcall(ui.set, fl.limit,    lim)
        pcall(ui.set, fl.variance, math.floor(var * 100))
        if mode == "Dynamic" then
            pcall(ui.set, fl.amount, math.random(1, math.max(1, lim)))
        elseif mode == "Maximum" then
            pcall(ui.set, fl.amount, lim)
        elseif mode == "Fluctuate" then
            pcall(ui.set, fl.amount, math.random(1, math.max(1, math.floor(lim*(1-var*0.5)))))
        end
    end

    -- ── LC breaker ────────────────────────────────────────────────────
    local function apply_vulnlc(cmd, ctx)
        local modes = ui_vulnlc:get()
        if not modes or #modes == 0 then return end
        local exp_data = exploit.get and pcall(exploit.get) and exploit.get() or nil
        local charge = exp_data and exp_data.charge or 0
        local should_break = false
        if has(modes,"Charged")   and charge >= 1.0 then should_break = true end
        if has(modes,"Shifting")  and charge > 0 and charge < 1.0 then should_break = true end
        if has(modes,"Uncharged") and charge == 0 then should_break = true end
        if should_break and ctx then ctx.defensive_ticks = 1 end
    end

    -- ── Builder page show function ────────────────────────────────────
    local function show_state_items(s)
        local p = ab[s]
        _safe_display(p.enableState)
        local en = (s == 1) or p.enableState:rawget()
        if not en then return end

        _safe_display(p.pitch)
        if p.pitch:rawget() == "Custom" then _safe_display(p.pitchSlider) end
        _safe_display(p.yawBase)
        _safe_display(p.yaw)
        local ym = p.yaw:rawget()
        if ym == "Slow Yaw" or ym == "L&R" then
            _safe_display(p.yawLeft); _safe_display(p.yawRight); _safe_display(p.yawDelay)
        elseif ym ~= "Off" then
            _safe_display(p.yawStatic)
        end
        _safe_display(p.yawJitter)
        local jm = p.yawJitter:rawget()
        if jm == "L&R" then
            _safe_display(p.yawJitterLeft); _safe_display(p.yawJitterRight); _safe_display(p.yawDelay)
        elseif jm == "3-Way" then
            _safe_display(p.wayFirst); _safe_display(p.waySecond); _safe_display(p.wayThird)
        elseif jm ~= "Off" then
            _safe_display(p.yawJitterStatic)
        end
        _safe_display(p.bodyYaw)
        if p.bodyYaw:rawget() ~= "Off" and p.bodyYaw:rawget() ~= "Opposite" then
            _safe_display(p.bodyYawStatic)
        end
        -- Defensive AA
        _safe_display(p.defensiveAA)
        if p.defensiveAA:rawget() then
            _safe_display(p.defensiveTriggers)
            if has(p.defensiveTriggers:rawget(), "Tick") then
                _safe_display(p.defensiveTickTrigger)
            end
            _safe_display(p.defensivePitch)
            local dpm = p.defensivePitch:rawget()
            if dpm ~= "Random Logic" then
                _safe_display(p.defensivePitchMin)
                if dpm == "Random" or dpm == "Spin" or dpm == "Jitter" or dpm == "Sine Wave" then
                    _safe_display(p.defensivePitchMax)
                end
            end
            if dpm == "Spin" or dpm == "Sine Wave" then _safe_display(p.defensivePitchSpeed) end
            _safe_display(p.defensiveYaw)
            local dym = p.defensiveYaw:rawget()
            if dym == "Static" or dym == "Random" then
                _safe_display(p.defensiveYawStatic)
            elseif dym == "Spin" then
                _safe_display(p.defensiveYawSpinLeft); _safe_display(p.defensiveYawSpinRight)
                _safe_display(p.defensiveYawSpinSpeed)
            elseif dym == "Jitter" or dym == "Logic Shift" then
                _safe_display(p.defensiveYawJitterRange); _safe_display(p.defensiveYawJitterDelay)
            end
        end
    end

    -- This is called by the Builder page renderer
    function defensive.show_builder()
        _safe_display(ui_team); _safe_display(ui_copy)
        _safe_display(ui_state)
        local s = ui_state:get()
        -- find state index
        local si = 1
        for i,nm in ipairs(AA_STATES) do if nm == s then si = i; break end end
        show_state_items(si)
        -- Controls section
        _safe_display(ui_fl_settings)
        _safe_display(ui_vulnlc)
        _safe_display(ui_edge_yaw); _safe_display(ui_freestand)
        _safe_display(ui_inverter)
        _safe_display(ui_man_en)
        if ui_man_en:get() then
            _safe_display(ui_man_left); _safe_display(ui_man_right); _safe_display(ui_man_reset)
        end
        _safe_display(ui_safehead)
        _safe_display(ui_fl_on)
        if ui_fl_on:get() then
            _safe_display(ui_fl_mode); _safe_display(ui_fl_variance); _safe_display(ui_fl_limit)
        end
    end

    -- ── Main AA logic (called by defensive.handle each tick) ──────────
    local function hd_apply(cmd, ctx)
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end

        -- inverter tick
        if cmd.chokedcommands == 0 then
            aa_inverter = not aa_inverter
            aa_inverter_tick = aa_inverter_tick + 1
        end

        -- auto-switch team
        local my_team_num = entity.get_prop(lp, "m_iTeamNum")
        local my_team = (my_team_num == 3) and "CT" or (my_team_num == 2 and "T" or nil)
        if not ui.is_menu_open() and my_team and ui_team:get() ~= my_team then
            ui_team:set(my_team)
        end

        -- state detection
        local flags    = entity.get_prop(lp, "m_fFlags") or 0
        local onground = bit.band(flags,1) ~= 0
        local vx = entity.get_prop(lp, "m_vecVelocity[0]") or 0
        local vy = entity.get_prop(lp, "m_vecVelocity[1]") or 0
        local spd2    = math.sqrt(vx*vx + vy*vy)
        local pStill  = spd2 < 5
        local duck    = entity.get_prop(lp,"m_flDuckAmount") or 0
        local isSlow  = (function() local ok,v=pcall(software.is_slow_motion); return ok and v or false end)()

        local raw = 1
        if pStill         then raw = 2 end
        if not pStill     then raw = 3 end
        if isSlow         then raw = 4 end
        if duck > 0.1 then
            if pStill then raw = 5 else raw = 8 end
        end
        if not onground   then raw = 6 end
        if not onground and duck > 0.1 then raw = 7 end

        if raw ~= last_state_raw then last_state_raw = raw end
        pState = raw
        -- keep original state index for defensive check even when falling back to Global
        local pState_orig = pState
        if ab[pState] and not ab[pState].enableState:get() and pState ~= 1 then
            pState = 1
        end

        local p      = ab[pState]
        local p_orig = ab[pState_orig] or p  -- for defensive: use original state
        if not p then 
            print("[ZENITH DEBUG] No preset for pState: " .. tostring(pState))
            return 
        end

        pcall(apply_fakelag)
        pcall(apply_vulnlc, cmd, ctx)

        -- manual yaw
        if ui_man_en:get() then
            if ui_man_reset:rawget() then manual_side = nil
            elseif ui_man_left:rawget() then manual_side = -1
            elseif ui_man_right:rawget() then manual_side = 1
            end
        else
            manual_side = nil
        end

        if manual_side then
            ctx.yaw_base   = "Local view"
            ctx.yaw        = "180"
            ctx.yaw_offset = manual_side * 90
            ctx.yaw_jitter = "Off"
            ctx.body_yaw   = "Static"
            ctx.body_yaw_offset = -180
            if yaw_direction.edge_yaw and yaw_direction.edge_yaw:rawget() then ctx.edge_yaw = true end
            if ui_freestand:rawget() then ctx.freestanding = true end
            return
        end

        -- update tickbase tracker
        update_def_tracker(lp)

        -- check defensive activation
        local is_def = false
        -- DT/OS always trigger defensive regardless of checkbox
        if software.is_double_tap and software.is_double_tap() then is_def = true end
        if software.is_on_shot_antiaim and software.is_on_shot_antiaim() then is_def = true end
        if def_tracker.is_def then is_def = true end
        -- per-state manual triggers (only when defensive checkbox is on)
        if p_orig.defensiveAA:rawget() then
            local trigs = p_orig.defensiveTriggers:rawget() or {}
            if has(trigs,"Always") then is_def = true end
            if has(trigs,"Tick") then
                local tm = p_orig.defensiveTickTrigger:rawget()
                if globals.tickcount() % 16 < tm then is_def = true end
            end
            if has(trigs,"Weapon switch") then
                if globals.curtime() - def_persistent.last_weapon_switch < 1.0 then is_def = true end
            end
        end
        -- when defensive fires, use original state if it has def settings, else Global
        local def_src = (p_orig.defensiveAA:rawget() and p_orig) or (ab[1].defensiveAA:rawget() and ab[1]) or p_orig
        local pd = is_def and def_src or p

        -- yaw base
        ctx.yaw_base = p.yawBase:rawget()

        if is_def then
            -- ── Defensive pitch ───────────────────────────────────────
            local dpm   = pd.defensivePitch:rawget()
            local dmin  = pd.defensivePitchMin:rawget()
            local dmax  = pd.defensivePitchMax:rawget()
            local dspd  = pd.defensivePitchSpeed:rawget()
            local rmin  = math.min(dmin,dmax); local rmax = math.max(dmin,dmax)
            
            -- Ensure pitch is applied - use Down/Up for extreme values, Custom for specific offsets
            if dpm == "Static" then
                if dmin == -89 then
                    ctx.pitch = "Up"
                elseif dmin == 89 then
                    ctx.pitch = "Down"
                else
                    ctx.pitch = "Custom"
                    ctx.pitch_offset = dmin
                end
            elseif dpm == "Random" then
                ctx.pitch = "Custom"
                ctx.pitch_offset = math.random(rmin, rmax)
            elseif dpm == "Spin" then
                -- Improved spin: smooth continuous rotation
                def_persistent.pitch_spin = def_persistent.pitch_spin + (dspd * 0.5)
                if def_persistent.pitch_spin > rmax then
                    def_persistent.pitch_spin = rmin
                elseif def_persistent.pitch_spin < rmin then
                    def_persistent.pitch_spin = rmax
                end
                ctx.pitch = "Custom"
                ctx.pitch_offset = math.floor(def_persistent.pitch_spin)
            elseif dpm == "Jitter" then
                local t = globals.tickcount() % (dspd * 2) < dspd
                ctx.pitch = "Custom"
                ctx.pitch_offset = t and dmin or dmax
            elseif dpm == "Sine Wave" then
                local wave = math.sin(globals.curtime() * dspd * 0.5) * (rmax - rmin) / 2 + (rmax + rmin) / 2
                ctx.pitch = "Custom"
                ctx.pitch_offset = math.floor(wave)
            elseif dpm == "Random Logic" then
                local r = math.random(0, 100)
                ctx.pitch = "Custom"
                ctx.pitch_offset = r > 80 and 0 or (math.random(0, 1) == 0 and 89 or -89)
            end

            -- ── Defensive yaw ─────────────────────────────────────────
            local dym  = pd.defensiveYaw:rawget()
            local dys  = pd.defensiveYawStatic:rawget()
            ctx.yaw = "180"
            if dym == "Static" then
                ctx.yaw_offset = dys
            elseif dym == "Random" then
                ctx.yaw_offset = math.random(-180,180)
            elseif dym == "Spin" then
                local sl = pd.defensiveYawSpinLeft:rawget()
                local sr = pd.defensiveYawSpinRight:rawget()
                local ss = pd.defensiveYawSpinSpeed:rawget()
                -- Improved spin: continuous smooth rotation through full range
                def_persistent.yaw_spin = def_persistent.yaw_spin + (ss * 2)
                local spin_min = math.min(sl, sr)
                local spin_max = math.max(sl, sr)
                if def_persistent.yaw_spin > spin_max then 
                    def_persistent.yaw_spin = spin_min 
                elseif def_persistent.yaw_spin < spin_min then
                    def_persistent.yaw_spin = spin_max
                end
                ctx.yaw_offset = norm_yaw(def_persistent.yaw_spin)
            elseif dym == "Jitter" then
                local range = pd.defensiveYawJitterRange:rawget()
                local delay = pd.defensiveYawJitterDelay:rawget()
                ctx.yaw_offset = globals.tickcount() % (delay*2) < delay and range or -range
            elseif dym == "Logic Shift" then
                local range = pd.defensiveYawJitterRange:rawget()
                local delay = pd.defensiveYawJitterDelay:rawget()
                local shift = (globals.tickcount()%32 < 16) and 0 or (globals.tickcount()%64 < 32 and 90 or -90)
                local jitter = globals.tickcount() % (delay*2) < delay and range or -range
                ctx.yaw_offset = norm_yaw(shift + jitter)
            elseif dym == "Zenith Bypass" then
                local t = aa_inverter_tick % 32
                local fl = aa_inverter
                if t == 31 then
                    ctx.yaw_offset = (aa_inverter_tick%64 < 32) and 180 or 0
                elseif t < 16 then
                    ctx.yaw_offset = norm_yaw(110 + (fl and 2 or -2))
                else
                    ctx.yaw_offset = norm_yaw(-110 + (fl and 2 or -2))
                end
                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = fl and 60 or -60
            else
                -- defensive yaw "Off" = fall through to normal yaw below
                ctx.yaw = nil  -- will be set by normal yaw block
            end
            -- body yaw from current state (if not set by Zenith Bypass)
            if not ctx.body_yaw then
                local bm = pd.bodyYaw:rawget()
                if bm ~= "Off" then
                    ctx.body_yaw = bm
                    if bm ~= "Opposite" then ctx.body_yaw_offset = pd.bodyYawStatic:rawget() end
                end
            end
        else
            -- ── Normal pitch ──────────────────────────────────────────
            local pm = p.pitch:rawget()
            if pm == "Custom" then
                ctx.pitch = "Custom"; ctx.pitch_offset = p.pitchSlider:rawget()
            elseif pm ~= "Off" then
                ctx.pitch = pm
            end
            -- "Off" = don't override pitch

            -- ── Normal yaw ────────────────────────────────────────────
            local ym     = p.yaw:rawget()
            local yd     = p.yawDelay:rawget()
            local ysw    = globals.tickcount() % (yd*2) < yd
            -- DEBUG: print yaw mode once per second
            if globals.tickcount() % 64 == 0 then
                print("[ZENITH DEBUG] Yaw mode: " .. tostring(ym) .. " | State: " .. tostring(pState))
            end
            if ym ~= "Off" then
                ctx.yaw = "180"
                if ym == "Slow Yaw" or ym == "L&R" then
                    ctx.yaw_offset = ysw and p.yawLeft:rawget() or p.yawRight:rawget()
                else
                    ctx.yaw_offset = p.yawStatic:rawget()
                end
            end
            -- "Off" = don't override yaw, let GS native handle it

            -- ── Jitter ────────────────────────────────────────────────
            local jm = p.yawJitter:rawget()
            -- DEBUG: print jitter mode once per second
            if globals.tickcount() % 64 == 0 then
                print("[ZENITH DEBUG] Jitter mode: " .. tostring(jm) .. " | Body yaw: " .. tostring(p.bodyYaw:rawget()))
            end
            if jm == "L&R" then
                local jsw = globals.tickcount() % (yd*2) < yd
                ctx.yaw_jitter  = "Center"
                ctx.jitter_offset = jsw and p.yawJitterLeft:rawget() or p.yawJitterRight:rawget()
            elseif jm == "3-Way" then
                ctx.yaw_jitter  = "Center"
                local ways = {p.wayFirst:rawget(), p.waySecond:rawget(), p.wayThird:rawget()}
                ctx.jitter_offset = ways[(globals.tickcount()%3)+1]
            elseif jm ~= "Off" then
                ctx.yaw_jitter  = jm
                ctx.jitter_offset = p.yawJitterStatic:rawget()
            end

            -- ── Body yaw ──────────────────────────────────────────────
            local bm = p.bodyYaw:rawget()
            if bm ~= "Off" then
                ctx.body_yaw = bm
                if bm ~= "Opposite" then
                    ctx.body_yaw_offset = p.bodyYawStatic:rawget()
                end
            end
        end

        -- inverter
        if ui_inverter:rawget() and ctx.yaw_offset then
            ctx.yaw_offset = norm_yaw(ctx.yaw_offset + 180)
        end

        -- safe head
        local sh = ui_safehead:get() or {}
        local lp_hp = entity.get_prop(lp, "m_iHealth") or 100
        local should_sh = has(sh,"Always")
            or (has(sh,"Low HP") and lp_hp <= 40)
            or (has(sh,"Knife")  and (function()
                local wpn = entity.get_player_weapon(lp)
                return wpn and (entity.get_classname(wpn) == "CKnife")
            end)())
        if should_sh then
            ctx.pitch="Custom"; ctx.pitch_offset=89
            ctx.yaw_offset=20; ctx.body_yaw="Static"; ctx.body_yaw_offset=1
        end

        -- edge yaw / freestanding
        if yaw_direction.edge_yaw and yaw_direction.edge_yaw:rawget() then ctx.edge_yaw = true end
        if ui_freestand:rawget() then ctx.freestanding = true end

        -- export current state
        rawset(_G, "_G._hd_pstate", pState)
        rawset(_G, "_hd_state", {
            -- keep old references so Builder page still works with _G._hd_state
            ui_enable    = {get=function() return true end},
            ui_state     = ui_state,
            lbl_pitch    = nil, lbl_yaw=nil, lbl_body=nil, lbl_delay=nil, lbl_fl=nil, lbl_ctrl=nil,
        })
    end

    function defensive.handle(cmd, ctx)
        hd_apply(cmd, ctx)
    end

    -- boot: deferred so config is loaded first
    local _boot_done = false
    client.set_event_callback('setup_command', function()
        if _boot_done then return end
        _boot_done = true
        -- auto-set team on first tick
        local lp = entity.get_local_player()
        if lp then
            local tn = entity.get_prop(lp,"m_iTeamNum")
            local t  = (tn==3) and "CT" or (tn==2 and "T" or nil)
            if t then ui_team:set(t) end
        end
    end)

    -- expose to Builder page renderer
    rawset(_G, "_valk_ab",     ab)
    rawset(_G, "_valk_states", AA_STATES)
    rawset(_G, "_valk_show",   function() defensive.show_builder() end)

end




---region disable on warmup
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

--- region avoid_backstab
do
    local is_active = false
    local AVOID_BACKSTAB_MAX_DISTANCE_SQR = 220 * 220

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

            if wpn_class == "CKnife" then
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

--- region safe_head
do
    local is_active = false

    local presets = {
        ["Standing"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = -6

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 0
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 8

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 0
            end
        },

        ["Crouched"] = {
            [2] = function(e, ctx, me)
                ctx.yaw_offset = 0

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 0
            end,

            [3] = function(e, ctx, me)
                ctx.yaw_offset = 40

                ctx.body_yaw = "Static"
                ctx.body_yaw_offset = 180
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

--- region manual_yaw
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

-- ======================================================================
--  ZENITH | REWORKED ON-SCREEN EVENT LOG
--  • Pill/card per entry with rounded accent background
--  • Slide-in animation (from right)
--  • Smooth alpha fade-out
--  • Icons per event type  (✦ hit │ ✖ miss │ ✸ burn │ ↯ unreg)
--  • Color-coded by category
--  • Draggable position anchor
-- ======================================================================

--- region log_aimbot_shots  (REWORKED)
do
    local DURATION    = 6.0
    local MAX_ENTRIES = 10

    -- ── Kind definitions ──────────────────────────────────────────────
    local KIND = {
        hit      = { icon = '\xe2\x9c\xa6', r=120, g=220, b=120 },
        headshot = { icon = '\xe2\x9c\xa6', r=255, g=200, b=60  },
        knife    = { icon = '\xe2\x9c\x82', r=255, g=120, b=60  },
        nade     = { icon = '\xe2\x9c\xb8', r=255, g=180, b=60  },
        burn     = { icon = '\xe2\x9c\xb8', r=255, g=100, b=40  },
        miss     = { icon = '\xe2\x9c\x96', r=220, g=80,  b=80  },
        spread   = { icon = '\xe2\x9c\x96', r=255, g=200, b=60  },
        unreg    = { icon = '\xe2\x86\xaf', r=100, g=140, b=255 },
    }

    local function resolve_kind(weapon, hitgroup, reason)
        if reason then
            if reason == 'spread'                                  then return KIND.spread end
            if reason == 'death' or reason == 'player death'
               or reason == 'unregistered shot'                    then return KIND.unreg  end
            return KIND.miss
        end
        if weapon == 'inferno'   then return KIND.burn     end
        if weapon == 'knife'     then return KIND.knife    end
        if weapon == 'hegrenade' then return KIND.nade     end
        if hitgroup == 1         then return KIND.headshot end
        return KIND.hit
    end

    local HG_NAMES = { [2]='chest',[3]='stomach',[4]='l.arm',[5]='r.arm',[6]='l.leg',[7]='r.leg',[8]='neck' }

    local inferno = {}
    local regular = {}

    local function push_entry(kind, text)
        if #regular >= MAX_ENTRIES then table.remove(regular, 1) end
        regular[#regular + 1] = {
            kind = kind, text = text,
            lifetime = DURATION, alpha = 0.0, slide = 0.0,
        }
    end

    local function find_inferno(ent)
        for i = 1, #inferno do
            if inferno[i].entity == ent then return inferno[i] end
        end
    end

    function log_aimbot_shots.player_hurt(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Log Aimbot Shots') then return end
        local me       = entity.get_local_player()
        local userid   = client.userid_to_entindex(e.userid)
        local attacker = client.userid_to_entindex(e.attacker)
        if userid == me or attacker ~= me then return end

        local weapon = e['weapon']
        local damage = e['dmg_health']
        local hg     = e['hitgroup']
        local name   = entity.get_player_name(userid)
        local kind   = resolve_kind(weapon, hg, nil)

        if weapon == 'inferno' then
            local d = find_inferno(userid)
            if d then d.damage = d.damage + damage; d.lifetime = DURATION; return end
            inferno[#inferno + 1] = {
                entity = userid, damage = damage, kind = KIND.burn,
                lifetime = DURATION, alpha = 0.0, slide = 0.0,
            }
            return
        end

        local text
        if weapon == 'knife' then
            text = f('Knifed \a[nick]%s\aFFFFFFFF for \a[dmg]%d\aFFFFFFFF dmg', name, damage)
        elseif weapon == 'hegrenade' then
            text = f('Naded \a[nick]%s\aFFFFFFFF for \a[dmg]%d\aFFFFFFFF dmg', name, damage)
        elseif hg == 1 then
            text = f('\a[hs]HEADSHOT\aFFFFFFFF \a[nick]%s\aFFFFFFFF \a[dmg]%d\aFFFFFFFF dmg', name, damage)
        else
            text = f('Hit \a[nick]%s\aFFFFFFFF (%s) \a[dmg]%d\aFFFFFFFF dmg', name, HG_NAMES[hg] or 'body', damage)
        end
        push_entry(kind, text)
    end

    function log_aimbot_shots.aim_miss(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Log Aimbot Shots') then return end
        local reason = e.reason or '?'
        if reason == '?' then reason = 'correction' end
        push_entry(resolve_kind(nil, nil, reason), f('Miss  \a[reason]%s', reason))
    end

    function log_aimbot_shots.frame()
        local dt = globals.frametime()
        for i = #inferno, 1, -1 do
            local d = inferno[i]
            d.lifetime = math.max(0, d.lifetime - dt)
            d.alpha    = motion.interp(d.alpha, d.lifetime > 0 and 1 or 0, 0.06)
            d.slide    = motion.interp(d.slide, 1.0, 0.10)
            if d.alpha <= 0.01 and d.lifetime <= 0 then table.remove(inferno, i) end
        end
        for i = #regular, 1, -1 do
            local d = regular[i]
            d.lifetime = math.max(0, d.lifetime - dt)
            d.alpha    = motion.interp(d.alpha, d.lifetime > 0 and 1 or 0, 0.06)
            d.slide    = motion.interp(d.slide, 1.0, 0.10)
            if d.alpha <= 0.01 and d.lifetime <= 0 then table.remove(regular, i) end
        end
    end

    rawset(_G, '_zn_inferno', inferno)
    rawset(_G, '_zn_regular', regular)

    -- -- Console hitlog -----------------------------------------------
    -- Detailed per-shot log to console: hit/miss reason, HC, hitgroup, yaw
    local _fire_data = {}  -- { damage, hitgroup, tick, target }

    local HG_FULL = {
        [0]='generic',[1]='head',[2]='chest',[3]='stomach',
        [4]='l.arm',[5]='r.arm',[6]='l.leg',[7]='r.leg',[8]='neck'
    }

    local function get_yaw_info()
        local lp = entity.get_local_player()
        if not lp then return '?' end
        local y = entity.get_prop(lp, 'm_angEyeAngles[1]')
        return y and f('%.0f', y) or '?'
    end

    client.set_event_callback('aim_fire', function(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Log Aimbot Shots') then return end
        _fire_data.damage   = e.damage
        _fire_data.hitgroup = e.hitgroup
        _fire_data.tick     = e.tick
        _fire_data.target   = e.target
        _fire_data.yaw      = get_yaw_info()
    end)

    client.set_event_callback('aim_hit', function(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Log Aimbot Shots') then return end
        local name = (e.target and entity.get_player_name(e.target)) or '?'
        local hg   = HG_FULL[e.hitgroup] or 'body'
        local hc   = e.hit_chance or 0
        local dmg  = e.damage or 0
        local bt   = globals.tickcount() - (_fire_data.tick or globals.tickcount())
        local yaw  = _fire_data.yaw or '?'
        client.color_log(120, 220, 120, '[Zenith] \0')
        client.color_log(255, 255, 255, f('HIT %s ', name))
        client.color_log(255, 220, 60,  f('[%s] \0', hg))
        client.color_log(255, 255, 255, f('%d dmg  \0', dmg))
        client.color_log(160, 200, 255, f('HC %d%%  bt %dt  yaw %s', hc, bt, yaw))
    end)

    client.set_event_callback('aim_miss', function(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Log Aimbot Shots') then return end
        local name   = (e.target and entity.get_player_name(e.target)) or '?'
        local reason = e.reason or 'correction'
        local hg     = HG_FULL[e.hitgroup] or 'body'
        local hc     = e.hit_chance or 0
        local bt     = globals.tickcount() - (_fire_data.tick or globals.tickcount())
        local yaw    = _fire_data.yaw or '?'
        client.color_log(220, 80,  80,  '[Zenith] \0')
        client.color_log(255, 255, 255, f('MISS %s ', name))
        client.color_log(255, 160, 80,  f('[%s -> %s]  \0', hg, reason))
        client.color_log(160, 200, 255, f('HC %d%%  bt %dt  yaw %s', hc, bt, yaw))
    end)
end

--- region evaded_shot_log
do
    -- Detect when an enemy bullet passes NEAR but does NOT HIT the local player.
    -- We suppress the evade log if the local player was hurt by that same shooter
    -- in the same server tick (meaning the bullet DID land).

    local EVADE_RADIUS   = 72
    local EVADE_DURATION = 4.0
    local KIND_EVADE     = { icon = '\xe2\x9c\x93', r = 90, g = 200, b = 255 }

    -- table of { tick, shooter_entindex } for every time we were hurt
    local hurt_log = {}

    client.set_event_callback('player_hurt', function(e)
        local lp = entity.get_local_player()
        if not lp then return end
        -- e.userid = victim, e.attacker = shooter
        local victim_id = e['userid']
        if not victim_id then return end
        local victim = client.userid_to_entindex(victim_id)
        if victim ~= lp then return end
        local attacker_id = e['attacker']
        if not attacker_id then return end
        local attacker = client.userid_to_entindex(attacker_id)
        if not attacker then return end
        -- record this hit so bullet_impact can check against it
        hurt_log[#hurt_log + 1] = { tick = globals.tickcount(), shooter = attacker }
        -- prune old entries
        local cur = globals.tickcount()
        for i = #hurt_log, 1, -1 do
            if cur - hurt_log[i].tick > 2 then table.remove(hurt_log, i) end
        end
    end)

    local function was_hit_by(shooter_ent)
        local cur = globals.tickcount()
        for _, h in ipairs(hurt_log) do
            if h.shooter == shooter_ent and cur - h.tick <= 1 then
                return true
            end
        end
        return false
    end

    local function push_evade(shooter)
        local reg = _G._zn_regular
        if not reg then return end
        local name = entity.get_player_name(shooter) or '?'
        local MAX = 10
        if #reg >= MAX then table.remove(reg, 1) end
        reg[#reg + 1] = {
            kind     = KIND_EVADE,
            text     = 'Evaded  \a[nick]' .. name .. '\aFFFFFFFF',
            lifetime = EVADE_DURATION,
            alpha    = 0.0,
            slide    = 0.0,
        }
        client.color_log(90, 200, 255, '[Zenith]\0')
        client.color_log(180, 180, 180, ' Evaded shot from \0')
        client.color_log(255, 180, 80, name)
    end

    client.set_event_callback('bullet_impact', function(e)
        if not settings.tweaks_enable:get() then return end
        if not settings.tweaks:have_key('Log Aimbot Shots') then return end

        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end

        -- if shooter actually hit us (within 1 tick) this is not an evade
        if was_hit_by(shooter) then return end

        local shooter_id = e['userid']
        if not shooter_id then return end
        local shooter = client.userid_to_entindex(shooter_id)
        if not shooter or shooter == lp then return end
        if not entity.is_enemy(shooter) then return end

        local ix, iy, iz = e['x'], e['y'], e['z']
        if not (ix and iy and iz) then return end

        local ox, oy, oz = entity.get_prop(lp, 'm_vecOrigin')
        if not (ox and oy and oz) then return end
        oz = oz + 54  -- approximate center-mass height

        local dx, dy, dz = ix-ox, iy-oy, iz-oz
        if (dx*dx + dy*dy + dz*dz) > EVADE_RADIUS * EVADE_RADIUS then return end

        push_evade(shooter)
    end)
end

--- region eventlogs  (REWORKED)
do
    local CARD_PAD_X  = 8
    local CARD_PAD_Y  = 4
    local CARD_GAP    = 3
    local CARD_RADIUS = 4
    local ICON_GAP    = 5
    local SLIDE_RANGE = 140

    local inferno = _G._zn_inferno
    local regular = _G._zn_regular

    local MACROS = {
        nick   = '\aFF9955FF',
        dmg    = '\aFFD700FF',
        hs     = '\aFFD700FF',
        reason = '\aFF6666FF',
    }
    local function resolve(s)
        return (s:gsub('\a%[(.-)%]', function(k) return MACROS[k] or '\aFFFFFFFF' end))
    end

    local PREVIEW = {
        { kind={ icon='\xe2\x9c\xa6', r=120,g=220,b=120 }, text='Hit \a[nick]vladislav\aFFFFFFFF (chest) \a[dmg]42\aFFFFFFFF dmg',            alpha=1, slide=1 },
        { kind={ icon='\xe2\x9c\xa6', r=255,g=200,b=60  }, text='\a[hs]HEADSHOT\aFFFFFFFF \a[nick]monster\aFFFFFFFF \a[dmg]103\aFFFFFFFF dmg', alpha=1, slide=1 },
        { kind={ icon='\xe2\x9c\x96', r=220,g=80, b=80  }, text='Miss  \a[reason]correction',                                                  alpha=1, slide=1 },
        { kind={ icon='\xe2\x9c\x96', r=100,g=140,b=255 }, text='Miss  \a[reason]unregistered shot',                                           alpha=1, slide=1 },
        { kind={ icon='\xe2\x9c\x96', r=255,g=200,b=60  }, text='Miss  \a[reason]spread',                                                      alpha=1, slide=1 },
        { kind={ icon='\xe2\x9c\x93', r=90, g=200,b=255 }, text='Evaded  \a[nick]xXsniper420Xx\aFFFFFFFF',                                    alpha=1, slide=1 },
    }

    -- Persistent position sliders (hidden, saved via config system)
    local _pos_x_item = menu.new_item(ui.new_slider, 'AA', 'Anti-aimbot angles',
        merge{'\n','eventlog::pos_x'}, 0, 10000, 7800)
        :record('visuals','eventlog::pos_x'):save()
    local _pos_y_item = menu.new_item(ui.new_slider, 'AA', 'Anti-aimbot angles',
        merge{'\n','eventlog::pos_y'}, 0, 10000, 7000)
        :record('visuals','eventlog::pos_y'):save()

    local widget = windows.new('##EventLogsV2', _pos_x_item:get() / 10000, _pos_y_item:get() / 10000)
    widget:set_size(vector(220, 20))

    -- save position when dragged
    local _save_timer = 0
    local function maybe_save_pos()
        _save_timer = _save_timer - globals.frametime()
        if _save_timer > 0 then return end
        if not widget:is_dragging() then return end
        _save_timer = 0.5
        local screen = vector(client.screen_size())
        local pos = widget.pos
        _pos_x_item:set(math.floor(pos.x / screen.x * 10000 + 0.5))
        _pos_y_item:set(math.floor(pos.y / screen.y * 10000 + 0.5))
    end

    local hovered_alpha = 0.0

    local function draw_card(ox, oy, entry, a_mult)
        if a_mult < 0.01 then return 0 end
        local kind    = entry.kind
        local alpha   = (entry.alpha or 1) * a_mult
        local slide_t = entry.slide or 1
        local display = resolve(entry.text or '')
        local flags   = 'd'

        local icon_w, icon_h = renderer.measure_text(flags, kind.icon)
        local text_w, text_h = renderer.measure_text(flags, display)
        local card_w = CARD_PAD_X * 2 + icon_w + ICON_GAP + text_w
        local card_h = CARD_PAD_Y * 2 + math.max(icon_h, text_h)

        local sx = ox + SLIDE_RANGE * (1.0 - slide_t)

        local br = math.floor(kind.r * 0.10)
        local bg = math.floor(kind.g * 0.10)
        local bb = math.floor(kind.b * 0.10)
        graphics.rectangle(sx, oy, card_w, card_h, br, bg, bb, math.floor(185 * alpha), CARD_RADIUS)
        renderer.rectangle(sx, oy + CARD_RADIUS, 2, card_h - CARD_RADIUS * 2,
            kind.r, kind.g, kind.b, math.floor(230 * alpha))
        renderer.text(sx + CARD_PAD_X, oy + (card_h - icon_h) * 0.5,
            kind.r, kind.g, kind.b, math.floor(255 * alpha), flags, 0, kind.icon)
        renderer.text(sx + CARD_PAD_X + icon_w + ICON_GAP, oy + (card_h - text_h) * 0.5,
            255, 255, 255, math.floor(255 * alpha), flags, 0, display)

        return card_h + CARD_GAP
    end

    local function draw_eventlogs()
        if not widgets.enabled:get() or not widgets.items:have_key('On-Screen Logs') then return end

        local is_menu    = ui.is_menu_open()
        local live_count = #regular + #inferno

        local source, a_mult
        if is_menu and live_count == 0 then
            source = PREVIEW; a_mult = 0.55
        else
            source = {}
            for i = #inferno, 1, -1 do
                local d  = inferno[i]
                local nm = entity.get_player_name(d.entity) or '?'
                source[#source + 1] = {
                    kind = d.kind, alpha = d.alpha, slide = d.slide,
                    text = f('Burning \a[nick]%s\aFFFFFFFF \a[dmg]%d\aFFFFFFFF dmg', nm, d.damage)
                }
            end
            for i = #regular, 1, -1 do
                source[#source + 1] = regular[i]
            end
            a_mult = 1.0
        end

        if #source == 0 then return end

        local pos = widget.pos:clone()
        hovered_alpha = motion.interp(hovered_alpha, is_menu and widget:is_hovering() and 1 or 0, 0.08)
        if hovered_alpha > 0.01 then
            renderer.text(pos.x, pos.y - 14, 255, 255, 255, math.floor(160 * hovered_alpha), 'd', nil, 'Drag to reposition')
        end

        local total_h = 0
        for i = 1, #source do
            total_h = total_h + draw_card(pos.x, pos.y + total_h, source[i], a_mult)
        end

        widget:set_size(vector(240, math.max(20, total_h)))
        widget:update()
        maybe_save_pos()
    end

    eventlogs.add        = function() end
    eventlogs.pre_frame  = function() end
    eventlogs.post_frame = function() draw_eventlogs() end

    local function col(r,g,b) return { r=r,g=g,b=b, rawget=function(self) return self.r,self.g,self.b end } end
    eventlogs.hit_color_picker          = col(120,220,120)
    eventlogs.spread_color_picker       = col(255,200,60)
    eventlogs.miss_color_picker         = col(220,80,80)
    eventlogs.unregistered_color_picker = col(100,140,255)
end

---region неопознан  (hit-rate counter - kept intact)
do
    local shots do
        shots = { total = 0, hits = 0 }
        client.set_event_callback('aim_fire', function() shots.total = shots.total + 1 end)
        client.set_event_callback('aim_hit',  function() shots.hits  = shots.hits  + 1 end)
        client.set_event_callback('player_connect_full', function(e)
            if client.userid_to_entindex(e['userid']) ~= entity.get_local_player() then return end
            shots.hits = 0; shots.total = 0
        end)
    end

    client.set_event_callback('paint_ui', function()
        local lp = entity.get_local_player()
        if lp == nil then return end
        if not widgets.enabled:get() or not widgets.items:have_key('Hit Rate') then return end
        local hit_rate = shots.total ~= 0 and (shots.hits / shots.total * 100) or 100
        renderer.indicator(255, 255, 255, 200, f('%s%d%%', hit_rate <= 50 and '◣_◢ ' or '', hit_rate))
    end)
end



---region autopeek
do
    function auto_peek.perform(ctx)
        if not aa_tweaks.enable:get() then
            return
        end

        if not aa_tweaks.items:have_key('Auto Peek Improvements')  then
            return
        end

        if not software.is_quick_peek_assist() then
            return
        end

        ctx.yaw_offset = 0
        ctx.yaw_jitter = 'Off'
        ctx.body_yaw = 'Off'
        ctx.freestanding = true
    end
end

LPH_NO_VIRTUALIZE(function ()
        --- region watermark
    do
        local FRAMERATE_AVG_FRAC = 0.9
        local cl_updaterate = cvar["cl_updaterate"]
        local game_type_cvar = cvar["game_type"]
        local game_mode_cvar = cvar["game_mode"]

        local GAME_MODE_NAMES = {
            [0] = { [0] = "Casual", [1] = "Competitive", [2] = "Wingman" },
            [1] = { [0] = "Arms Race", [1] = "Demolition", [2] = "Deathmatch" },
            [2] = { [0] = "Training", [1] = "Custom", [2] = "Cooperative" },
        }

        local function get_game_mode_name()
            local gt = game_type_cvar and game_type_cvar:get_int() or 0
            local gm = game_mode_cvar and game_mode_cvar:get_int() or 0
            local modes = GAME_MODE_NAMES[gt]
            return modes and modes[gm] or nil
        end

        local alpha     = 0.0
        local framerate = 0.0
        local timer     = 0.0
        local last_ping = 0.0
        local last_framerate        = 1 / globals.absoluteframetime()
        local last_server_framerate = 0.0
        local last_server_var       = 0.0
        local glow_t    = 0.0

        local texture do
            local _b64 = "iVBORw0KGgoAAAANSUhEUgAAABYAAAAWCAYAAADEtGw7AAAC/UlEQVR4nO1USUxTURQ99w+dPh1oSxWI1gGVCKiBqMQqRWMMJBhXf6NRYyIYCWp0r+BaN+7UhQtduPimiRpt4kaJEUIUp6SoGJAmVaAMMraF9ve6KAGNRRcS48KTvLd4991zzrv35gH/AGhuLS0p0dwGCEtFKs75XAbAQwTA75f+lJQEQQAAT03jlbaapmvdAEoyIVX8VeKvlAlEbDabPUZP5TPnuooiRXFg9bYjTyg5faL3lRYAmgXgYjpb8mL1IjQ3E5jNcbsvuP3wmaItBVJq7xpTquFcvXtSl69bXWUbmFsYizR0EWJV4JYWlhxbzu47ero8HOpKdjxvl0KRXun2zfvJuuNNrhRZjxER4PdnLUl2YhUQBGKSjAcK88wsxMeE1MoqBJ72IJljF3JsVhYMYhmIGKhe5MnZ1AhYnw9X93D+i7z1Pu+2A2d5KhUXktMR2GyWdGfwnhB9EwxweuQQERLMvyemiooGqbPzuhd23w1lbfmumYFu3WKR4ch1iyOjCcjiLMYGBllZs5l4ItwW6+1o8npL3oXDrTMA+GdiVRVJ03SXt7bWt7cqUFq5yyR5y7j/5ROajH7B+9BH5Be44XS7Ubi2GLK3hG9dvkQrbHqypzuyvz90+xFUVYCm6cD346ZlZIbDwb6pWImpYJmujwy0i7496zAS9WB73Q7YHQ50PAjCIn/F0Ov7dPLUnrTR4JTPN14wAWBEo/NGpQXDKjRNQ1HFwRpPVX3y4ZtPrI8PoS0iYbSni4c+96F0Zy2eBx4jx+kCpXUq/ropYnZ7c8sqd29t73t4119djdbW1h9KQUTEy8vrLVaj+MWct8o+OTEIWcmFQTZBNhigOAvBuo7Y2GfMxsYRS8xiOPwBNnseZJlCn9qvloKZMpOy4JiZmZRxo94ff9WE8Ns6KdejyJODEFMzSCXiccloSYCQSiamrKIoWmBUBLPNhOnRXn1meuIOQAAt+ef3M7JIqCJUQIU6f6JBA6IbM3c9XQwsxDVomcYjMw3/8ffwDeRqFtr3d6CrAAAAAElFTkSuQmCC"
            local function _b64decode(s)
                local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
                s = s:gsub('[^'..b..'=]', '')
                return (s:gsub('.', function(x)
                    if x == '=' then return '' end
                    local r,f = '', (b:find(x)-1)
                    for i=6,1,-1 do r=r..(f%2^i-f%2^(i-1)>0 and '1' or '0') end
                    return r
                end):gsub('%d%d%d%d%d%d%d%d', function(x)
                    local n = 0
                    x:gsub('.', function(c) n = n*2+(c=='1' and 1 or 0) end)
                    return string.char(n)
                end))
            end
            local ok, bytes = pcall(_b64decode, _b64)
            if ok and bytes and #bytes > 10 then
                texture = renderer.load_png(bytes, 22, 22)
            end
        end

        local function get_ping(nci)
            if inetchannel.is_loopback(nci) then return nil end
            return f("%dms", math.floor(math.max(0, last_ping * 1000)))
        end

        local function get_framerate()
            framerate = FRAMERATE_AVG_FRAC * framerate + (1.0 - FRAMERATE_AVG_FRAC) * globals.absoluteframetime()
            return last_framerate
        end

        local function update_timer(nci, dt)
            timer = timer - dt
            if timer > 0 then return end
            local latency = inetchannel.get_latency(nci, 0)
            local update_rate = cl_updaterate:get_float()
            if update_rate > 0.001 then latency = latency - 0.5 / update_rate end
            last_ping = latency
            last_server_framerate, last_server_var = inetchannel.get_remote_framerate(nci)
            last_framerate = framerate > 0 and framerate or 1
            timer = timer + 1.0
        end

        -- draw a single stat chip: [label value]
        local function draw_chip(x, y, label, value, r, g, b, a, flags)
            local lw, lh = renderer.measure_text(flags, label)
            local vw, vh = renderer.measure_text(flags, value)
            local PAD = 5
            local IGAP = 3
            local chip_w = PAD*2 + lw + IGAP + vw
            local chip_h = math.max(lh, vh) + PAD

            -- chip background
            graphics.rectangle(x, y, chip_w, chip_h, 14, 14, 18, math.floor(160 * a), 3)
            -- label (dim)
            renderer.text(x + PAD, y + (chip_h - lh)*0.5,
                140, 140, 155, math.floor(220 * a), flags, 0, label)
            -- value (accent)
            renderer.text(x + PAD + lw + IGAP, y + (chip_h - vh)*0.5,
                r, g, b, math.floor(255 * a), flags, 0, value)

            return chip_w + 4  -- advance
        end

        function watermark.frame()
            local can_show = widgets.enabled:get() and widgets.items:have_key("Watermark")
            alpha = motion.interp(alpha, can_show, 0.045)
            if alpha <= 0 then return end

            local lp = entity.get_local_player()
            if lp == nil then return end

            local nci = iengineclient.get_net_channel_info()
            update_timer(nci, globals.frametime())
            if nci == nil then return end

            local flags = "d"
            local r, g, b = widgets.color_picker:rawget()
            local a  = alpha
            local ia = math.floor(255 * a)
            local screen = vector(client.screen_size())

            -- ── Collect info tokens ────────────────────────────────────────────
            local tokens = {}
            if widgets.display:have_key("Username") then
                local nick = USERNAME
                if widgets.custom_name:get() then
                    local cn = ui.get(widgets.custom_name_value:get_ref())
                    if #cn ~= 0 then nick = cn end
                end
                tokens[#tokens+1] = { label = nick,  icon = "\xE2\x96\xB8", accent = true }
            end
            if widgets.display:have_key("Latency") then
                local p = get_ping(nci)
                if p then tokens[#tokens+1] = { label = p, icon = "\xE2\x97\x8B" } end
            end
            if widgets.display:have_key("FPS") then
                tokens[#tokens+1] = { label = f("%d fps", math.floor(1 / get_framerate())), icon = "\xE2\x96\xA0" }
            end
            if widgets.display:have_key("Time") then
                tokens[#tokens+1] = { label = f("%02d:%02d", client.system_time()), icon = "\xE2\x97\x8F" }
            end
            if widgets.display:have_key("Game Mode") then
                local gm = get_game_mode_name()
                if gm then tokens[#tokens+1] = { label = gm, icon = "\xE2\x97\x87" } end
            end

            -- ── Layout constants ───────────────────────────────────────────────
            local LOGO_W  = texture ~= nil and 26 or 0
            local PAD_X   = 11
            local PAD_Y   = 6
            local SEP_W   = 8   -- gap each side of the divider line

            -- Brand text: "ZENITH  3.0" with a tiny separator
            local brand_core  = "ZENITH"
            local brand_ver   = "  3.0"
            local bw_core, bh = renderer.measure_text(flags, brand_core)
            local bw_ver,  _  = renderer.measure_text(flags, brand_ver)
            local brand_w     = bw_core + bw_ver

            -- Token widths
            local sep_char = "  \xE2\x94\x82  "
            local sep_cw   = renderer.measure_text(flags, sep_char)
            local tok_total = 0
            local tok_items = {}
            for _, t in ipairs(tokens) do
                local display = t.icon .. " " .. t.label
                local dw = renderer.measure_text(flags, display)
                tok_items[#tok_items+1] = { display = display, dw = dw, accent = t.accent }
                tok_total = tok_total + dw
            end
            if #tok_items > 1 then tok_total = tok_total + (#tok_items - 1) * sep_cw end

            local has_tok  = #tok_items > 0
            local divider_blk = has_tok and (SEP_W * 2 + 1) or 0

            local box_w = 4 + LOGO_W + PAD_X * 2 + brand_w + divider_blk + tok_total + PAD_X
            local box_h = bh + PAD_Y * 2 + 2
            local px    = screen.x - 12 - box_w
            local py    = 10

            -- ── Animated glow ─────────────────────────────────────────────────
            glow_t = glow_t + globals.frametime() * 1.2
            local pulse = 0.55 + 0.45 * math.sin(glow_t)

            -- Diffuse outer glow (5 layers, very soft)
            for i = 5, 1, -1 do
                local ga = math.floor(9 * pulse * a * (6 - i) / 5)
                renderer.rectangle(px - i, py - i, box_w + i*2, box_h + i*2, r, g, b, ga)
            end

            -- ── Panel body ────────────────────────────────────────────────────
            -- Dark glass background
            renderer.rectangle(px, py, box_w, box_h, 6, 6, 9, math.floor(248 * a))
            -- Inner top-edge highlight
            renderer.rectangle(px + 4, py + 1, box_w - 8, 1, 255, 255, 255, math.floor(8 * a))

            -- Left accent bar (3-layer fade for smooth look)
            renderer.rectangle(px,     py, 4, box_h, r, g, b, ia)
            renderer.rectangle(px,     py, 2, box_h,
                math.min(255, r + 70), math.min(255, g + 70), math.min(255, b + 70),
                math.floor(140 * a))
            renderer.rectangle(px,     py, 1, box_h, 255, 255, 255, math.floor(35 * a))

            -- Bottom accent hairline
            renderer.rectangle(px + 4, py + box_h - 1, box_w - 4, 1, r, g, b, math.floor(110 * a))

            -- ── Logo texture ──────────────────────────────────────────────────
            if texture ~= nil then
                renderer.texture(texture, px + 4 + PAD_X, py + math.floor((box_h - 22) * 0.5),
                    22, 22, 255, 255, 255, math.floor(235 * a), "f")
            end

            -- ── Brand name ────────────────────────────────────────────────────
            local tx = px + 4 + LOGO_W + PAD_X
            local ty = py + math.floor((box_h - bh) * 0.5)

            -- "ZENITH" in accent colour
            renderer.text(tx + 1, ty + 1, 0, 0, 0, math.floor(70 * a), flags, 0, brand_core)
            renderer.text(tx,     ty,     r, g, b, ia,                  flags, 0, brand_core)
            tx = tx + bw_core

            -- "  3.0" in a dimmed accent (version tag)
            local vr = math.floor(r * 0.65 + 0.5)
            local vg = math.floor(g * 0.65 + 0.5)
            local vb = math.floor(b * 0.65 + 0.5)
            renderer.text(tx, ty, vr, vg, vb, math.floor(200 * a), flags, 0, brand_ver)
            tx = tx + bw_ver

            -- ── Token divider ─────────────────────────────────────────────────
            if has_tok then
                tx = tx + SEP_W
                -- hairline divider
                renderer.rectangle(tx, py + 5, 1, box_h - 10, 55, 55, 65, math.floor(210 * a))
                -- soft glow around divider
                renderer.rectangle(tx - 1, py + 5, 3, box_h - 10, r, g, b, math.floor(22 * a))
                tx = tx + 1 + SEP_W

                -- ── Tokens ────────────────────────────────────────────────────
                for i, t in ipairs(tok_items) do
                    local cr = t.accent and r   or 185
                    local cg = t.accent and g   or 185
                    local cb = t.accent and b   or 192
                    local ca = math.floor((t.accent and 255 or 225) * a)

                    -- subtle shadow for username
                    if t.accent then
                        renderer.text(tx + 1, ty + 1, 0, 0, 0, math.floor(45 * a), flags, 0, t.display)
                    end
                    renderer.text(tx, ty, cr, cg, cb, ca, flags, 0, t.display)
                    tx = tx + t.dw

                    if i < #tok_items then
                        renderer.text(tx, ty, 48, 48, 58, math.floor(170 * a), flags, 0, sep_char)
                        tx = tx + sep_cw
                    end
                end
            end
        end
    end

        --- region keybinds
    do
        local alpha   = 0.0
        local width   = 0.0
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
    			name = "On Shot AA",
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
    			name = "Last Sec Defuse",
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
    			name = "Nade Release",
    			offset = 2
    		},

    		{
    			ref = { ui.reference("Visuals", "Player ESP", "Activation type") },
    			name = "Visuals",
    			offset = 1
    		}
        }

        local active_keys   = {}
        local hotkey_modes  = { "holding", "toggled", "disabled" }
        local flags         = "d"

        -- mode label -> short badge text + colour modifier
        local function get_handle()
            local existent_keys = {}
            local all_active    = false
            local name_width, badge_width = 0, 0

            for i = 1, #all_hotkeys do
                local hotkey    = all_hotkeys[i]
                local unique_id = hotkey.ref[1]
                local name      = hotkey.name
                local offset    = hotkey.offset or 1
                local active    = true
                local collected = {}

                for j = 1, offset do collected[j] = hotkey.ref[j] end
                for j = 1, offset do
                    if not ui.get(collected[j]) then active = false; break end
                end

                if active then existent_keys[unique_id] = true; all_active = true end

                local _, mode = ui.get(collected[#collected])
                if mode == 0 then goto continue end

                mode = hotkey_modes[mode] or "~"
                mode = "[" .. mode .. "]"

                if active_keys[unique_id] == nil then
                    active_keys[unique_id] = {
                        alpha=0, height=0,
                        name_width=0, mode_width=0,
                        name=name, mode=mode
                    }
                end

                local value = active_keys[unique_id]
                local nw, nh = renderer.measure_text(flags, name)
                local mw, mh = renderer.measure_text(flags, mode)
                value.name        = name
                value.mode        = mode
                value.height      = math.max(nh, mh)
                value.name_width  = nw
                value.mode_width  = mw

                ::continue::
            end

            for k, v in pairs(active_keys) do
                local active = existent_keys[k] ~= nil
                v.alpha = motion.interp(v.alpha, active, 0.045)
                if v.alpha <= 0 then
                    active_keys[k] = nil
                elseif active or v.alpha >= 0.25 then
                    if name_width  < v.name_width  then name_width  = v.name_width  end
                    if badge_width < v.mode_width  then badge_width = v.mode_width  end
                end
            end

            return active_keys, all_active, name_width, badge_width
        end

        keybinds.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Keybinds")
        : record("visuals", "keybinds::enabled")
        : save()

        keybinds.window = windows.new("##keybinds", 0.025, 0.415)
        keybinds.window:set_size(vector(130, 24))

        function keybinds.frame()
            local me = entity.get_local_player()
            if me == nil then return end

            local window   = keybinds.window
            local hotkeys, all_active, name_width, badge_width = get_handle()

            local menu_check = ui.is_menu_open() or (next(hotkeys) ~= nil and all_active)
            local can_show   = widgets.enabled:get()
                               and widgets.items:have_key("Keybinds")
                               and menu_check

            alpha   = motion.interp(alpha,   can_show, 0.045)
            holding = motion.interp(holding, (can_show and window:is_dragging()) and 0.6 or 1.0, 0.045)

            if alpha <= 0 then return end

            local r, g, b = widgets.color_picker:get()
            local ROW_H = 16

            -- Measure content width
            local row_w = name_width + 12 + badge_width
            width = motion.interp(width, math.max(row_w, 80), 0.045)

            local box_w = math.floor(width + 0.85)
            local ab    = alpha * holding
            local pos   = window.pos

            -- ── Clean text rows (no header, no boxes) ─────────────────────────
            local row_y = pos.y

            for _, v in pairs(active_keys) do
                local fade_a = math.min(1.0, alpha * v.alpha * 1.25)
                local row_ab = fade_a * holding
                local row_a  = math.floor(255 * row_ab)
                if row_a < 4 then goto skip end

                local rh = utils.round(ROW_H * fade_a)
                if rh < 2 then goto skip end

                local ty2 = row_y + math.floor((rh - v.height) * 0.5)

                -- Feature name with shadow (white/grey)
                renderer.text(pos.x + 1, ty2 + 1, 0, 0, 0, math.floor(90 * row_ab), flags, 0, v.name)
                renderer.text(pos.x, ty2, 200, 200, 210, row_a, flags, 0, v.name)

                -- Mode badge with shadow (accent color)
                local badge_x = pos.x + box_w - v.mode_width
                renderer.text(badge_x + 1, ty2 + 1, 0, 0, 0, math.floor(80 * row_ab), flags, 0, v.mode)
                renderer.text(badge_x, ty2, r, g, b, math.floor(row_a * 0.95), flags, 0, v.mode)

                row_y = row_y + rh
                ::skip::
            end

            window:set_size(vector(box_w, 16))
            window:update()
        end
    end

        --- region indicators
    do
        local alpha        = 0.0
        local align        = 0.0
        local damage_alpha = 0.0
        local damage_value = 0.0
        local damage_moving   = 0.0
        local damage_holding  = 0.0

        local screen = vector(client.screen_size())
        local window = windows.new("##damage", 0.5 + 15 / screen.x, 0.5 - 15 / screen.y)
        window:set_anchor(vector(0.0, 1.0))
        window:set_size(vector(22, 22))

        local features = {
            { get = software.is_double_tap,              text = "DT",  alpha = 0, hold_a = 0 },
            { get = software.is_on_shot_antiaim,         text = "OS",  alpha = 0, hold_a = 0 },
            { get = software.is_duck_peek_assist,        text = "FD",  alpha = 0, hold_a = 0 },
            { get = software.is_minimum_damage_override, text = "DMG", alpha = 0, hold_a = 0 },
        }

        local function get_statement()
            if software.is_edge()      then return "EDGE"   end
            if safe_head.get()         then return "SAFE"   end
            if localplayer.is_airborne then return "AIR"    end
            if localplayer.is_crouched then return "CROUCH" end
            if localplayer.is_moving   then
                return software.is_slow_motion() and "WALK" or "RUN"
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

            local clock        = globals.realtime()
            local alive_check  = entity.is_alive(me)
            local scoped_check = entity.get_prop(me, "m_bIsScoped")
            local grenade_check= wpn_info.weapon_type_int == 9
            local menu_check   = ui.is_menu_open()
            local damage       = software.get_minimum_damage()

            local can_show_ind = widgets.enabled:get()
                                 and widgets.items:have_key("Crosshair Indicator")
                                 and alive_check
            local can_show_dmg = (widgets.enabled:get()
                                 and widgets.items:have_key("Damage Indicator")
                                 and not (wpn_info.weapon_type_int == 0 or grenade_check))
                                 or menu_check
            local can_move_dmg = can_show_dmg and menu_check

            alpha         = motion.interp(alpha,         can_show_ind and (grenade_check and 0.4 or 1.0) or 0.0, 0.045)
            align         = motion.interp(align,         can_show_ind and scoped_check == 1 or false, 0.045)
            damage_alpha  = motion.interp(damage_alpha,  can_show_dmg, 0.045)
            damage_value  = motion.interp(damage_value,  damage, 0.045)
            damage_moving = motion.interp(damage_moving, can_move_dmg, 0.045)
            damage_holding= motion.interp(damage_holding,(can_move_dmg and window:is_dragging()) and 0.6 or 1.0, 0.045)

            local flags  = "-d"
            local screen = vector(client.screen_size())
            local center = screen * 0.5

            local r1, g1, b1 = widgets.color_picker:rawget()
            local r, g, b, a = utils.color_lerp(
                r1, g1, b1, 255,
                255, 255, 255, 255,
                utils.breathe(clock + 0.5 - 0.5 * align)
            )

            -- -- damage indicator (clean text, no background) ----------
            if damage_alpha > 0 then
                local val   = utils.round(damage_value)
                local text  = f("%d", val)
                if damage == 0 then text = "AUTO" end
                if val > 100   then text = f("HP +%d", val - 100) end

                local dflags   = "d"
                local mw, mh   = renderer.measure_text(dflags, text)
                mw = mw + 1
                local pos      = window.pos:clone()
                local PAD      = 6
                local rect_sz  = vector(mw + PAD*2, mh + 8)
                local tx       = pos.x + (rect_sz.x - mw) * 0.5
                local ty       = pos.y + (rect_sz.y - mh) * 0.5
                local da       = damage_alpha * damage_holding

                local dr, dg, db = can_show_ind and r or r1, can_show_ind and g or g1, can_show_ind and b or b1
                local ta = math.floor(a * damage_alpha * damage_holding)

                -- Text shadow for readability
                renderer.text(tx + 1, ty + 1, 0, 0, 0, math.floor(ta * 0.55), dflags, 0, text)
                -- Main text
                renderer.text(tx, ty, dr, dg, db, ta, dflags, 0, text)
                -- Thin accent underline
                renderer.rectangle(tx - 1, ty + mh + 2, mw + 2, 1,
                    dr, dg, db, math.floor(da * 140))

                window:set_size(rect_sz)
                window:update()
            end

            if alpha <= 0 then return end

            -- ── Clean crosshair indicator (Valkyrie style) ───────────────────
            local cx = center.x + utils.round(10 * align)
            local cy = center.y + 18
            local dflags = "d"

            -- "ZENITH" brand - clean centered text with shadow
            local brand = "ZENITH"
            local bw, bh = renderer.measure_text(dflags, brand)
            local bx = cx - utils.round(bw * 0.5 * (1 - align * 0.5))

            -- Shadow
            renderer.text(bx + 1, cy + 1, 0, 0, 0, math.floor(120 * alpha), dflags, 0, brand)
            -- Main text
            renderer.text(bx, cy, r, g, b, math.floor(255 * alpha), dflags, 0, brand)

            -- Subtle horizontal separators flanking the brand text
            local line_y   = cy + math.floor(bh * 0.5)
            local line_len = 14
            renderer.rectangle(bx - line_len - 4, line_y, line_len, 1,
                r, g, b, math.floor(70 * alpha))
            renderer.rectangle(bx + bw + 4, line_y, line_len, 1,
                r, g, b, math.floor(70 * alpha))

            cy = cy + bh + 4

            -- Feature tags - clean text only, no boxes
            for i = 1, #features do
                local feat = features[i]
                feat.alpha  = motion.interp(feat.alpha,  can_show_ind and feat.get() or false, 0.045)
                feat.hold_a = motion.interp(feat.hold_a, feat.alpha > 0.5 and 1 or 0, 0.08)
                if feat.alpha <= 0.02 then goto cont end

                do
                    local fa = feat.alpha * alpha
                    local tw, th = renderer.measure_text(dflags, feat.text)
                    local tx = cx - utils.round(tw * 0.5 * (1 - align * 0.5))
                    local ty = cy

                    -- Shadow
                    renderer.text(tx + 1, ty + 1, 0, 0, 0, math.floor(100 * fa), dflags, 0, feat.text)
                    -- Main text
                    renderer.text(tx, ty, r, g, b, math.floor(255 * fa), dflags, 0, feat.text)

                    cy = cy + utils.round((th + 3) * feat.alpha)
                end
                ::cont::
            end
        end
    end

        ---region arrows
    do
        local alpha       = 0
        local left_alpha  = 0
        local right_alpha = 0
        local screen      = vector(client.screen_size()) * .5

        function arrows.frame()
            local lp = entity.get_local_player()
            if lp == nil then return end

            local wpn = entity.get_player_weapon(lp)
            if wpn == nil then return end
            local wpn_info = csgo_weapons(wpn)
            if wpn_info == nil then return end

            local can_show = manual_direction.enabled:get() and manual_direction.arrows:get() and entity.is_alive(lp)
            alpha = motion.interp(alpha, can_show and (wpn_info.weapon_type_int == 9 and 0.4 or 1.0) or 0.0, 0.045)
            if alpha <= 0 then return end

            local r, g, b, av = manual_direction.color:rawget()
            av = 255 * alpha

            local dir = manual_direction.get()

            left_alpha  = motion.interp(left_alpha,  dir == 0 and 1 or 0, 0.045)
            right_alpha = motion.interp(right_alpha, dir == 1 and 1 or 0, 0.045)

            if left_alpha  > 0 then renderer.text(screen.x - 50, screen.y - 16, r, g, b, av * left_alpha,  '+', nil, '<') end
            if right_alpha > 0 then renderer.text(screen.x + 39, screen.y - 16, r, g, b, av * right_alpha, '+', nil, '>') end
        end
    end

        --- region velocity_warning
    do
        local alpha   = 0.0
        local holding = 0.0
        local hovering= 0.0

        velocity_warning.window = windows.new("##velocity_warning", 0.5, 0.3)
        velocity_warning.window:set_anchor(vector(0.5, 0.0))
        velocity_warning.window:set_size(vector(180, 4))

        function velocity_warning.frame()
            local me = entity.get_local_player()
            if me == nil then return end

            local window    = velocity_warning.window
            local modifier  = entity.get_prop(me, "m_flVelocityModifier")
            local menu_check  = ui.is_menu_open()
            local alive_check = entity.is_alive(me)
            local vel_check   = modifier < 1.0
            local is_drag     = window:is_dragging()
            local is_hover    = window:is_hovering()

            local can_show = widgets.enabled:get() and widgets.items:have_key("Velocity Warning")
                             and ((alive_check and vel_check) or menu_check)

            alpha   = motion.interp(alpha,   can_show, 0.045)
            holding = motion.interp(holding, (can_show and is_drag)  and 0.6 or 1.0, 0.045)
            hovering= motion.interp(hovering,(can_show and is_hover and not is_drag) and 1.0 or 0.0, 0.045)

            if alpha <= 0 then return end

            if menu_check and (not vel_check or not alive_check) then
                modifier = math.min(1, globals.tickcount() % 200 / 150)
            end

            local flags   = "d"
            local percent = (1 - modifier) * 100
            local r, g, b = widgets.color_picker:get()

            -- lerp to warm red when slowed
            if modifier < 1.0 then
                r = utils.lerp(255, r, modifier)
                g = utils.lerp(75,  g, modifier)
                b = utils.lerp(75,  b, modifier)
            end

            local pos  = window.pos:clone()
            local size = window.size:clone()

            local text        = f("velocity reduced by %d%%", percent)
            local tw, th      = renderer.measure_text(flags, text)

            renderer.text(
                pos.x + (size.x - tw) * 0.5,
                pos.y,
                255, 255, 255, math.floor(255 * alpha * holding),
                flags, 0, text
            )

            pos.y = pos.y + th + 5

            -- slim accent bar
            local bar_w = tw + 28
            local bar_x = pos.x + (size.x - bar_w) * 0.5

            renderer.rectangle(bar_x, pos.y, bar_w, 2, 30, 30, 35, math.floor(200 * alpha * holding))
            renderer.rectangle(bar_x + 1, pos.y, math.floor((bar_w - 2) * (1 - modifier)), 2,
                r, g, b, math.floor(255 * alpha * holding))

            if hovering > 0 or is_hover then
                renderer.text(bar_x + (bar_w - tw) * 0.5, pos.y + 5,
                    200, 200, 200, math.floor(255 * alpha * hovering), flags, 0,
                    f("%.0f%%", (1 - modifier) * 100))
            end

            window:set_size(vector(math.max(size.x, bar_w), th + 16))
            window:update()
        end
    end

        --- region custom scope
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

--- hit marker zenith
do
    local MARKER_LIFETIME   = 3     -- seconds a damage number stays on screen
    local MARKER_FLOAT_SPEED = 22   -- pixels per second floating upward

    local ctx = {
        target = 0,
        pos = vector()
    }

    local pending_markers = { }

    function hit_marker.frame()
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Damage Marker') then
            return
        end

        local realtime = globals.realtime()
        local i = 1
        while i <= #pending_markers do
            local data = pending_markers[i]
            local diff = data[3] - realtime

            if data[3] < realtime then
                table.remove(pending_markers, i)
            else
                local age   = MARKER_LIFETIME - diff   -- elapsed seconds since creation
                local alpha = diff < 1 and math.max(0, diff) or 1
                local y_off = age * MARKER_FLOAT_SPEED  -- float upward

                local x, y = renderer.world_to_screen(data[1].x, data[1].y, data[1].z)
                y = y - y_off

                local r, g, b = unpack(data[4])
                -- Shadow for readability
                renderer.text(x + 1, y + 1, 0, 0, 0, math.floor(180 * alpha), "c", nil, data[2])
                -- Main text
                renderer.text(x, y, r, g, b, math.floor(255 * alpha), "c", nil, data[2])
                i = i + 1
            end
        end
    end

    function hit_marker.aim_fire(e)
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Damage Marker') then
            return
        end

        ctx.target = e.target
        ctx.pos = vector(e.x, e.y, e.z)
    end

    function hit_marker.aim_hit(e)
        if not settings.tweaks_enable:get() then
            return
        end

        if not settings.tweaks:have_key('Damage Marker') then
            return
        end

        if ctx.target == e.target then
            table.insert(
                pending_markers,
                {
                    ctx.pos, tostring(e.damage),
                    globals.realtime() + MARKER_LIFETIME,
                    e.hitgroup == 1 and { widgets.color_picker:rawget() } or { 240, 240, 240 }
                }
            )
        end
    end

    function hit_marker.round_prestart()
        table.clear(pending_markers)
    end
end


--- region yaw_direction
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

--- region freestqand disaskdfkskd
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

--- region shared
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

            shared.online_label:set(string.format('\\aaaaaaaffâ¢ \\affffffff Online \\aaaaaaaff~ \\affd700ff%d', online))
            if shared.fl_online then
                shared.fl_online:set(string.format('\a888888ff | \affffffffOnline  \a888888ff> \affd700ff%d', online))
            end
            -- leaderboard from data if available
            if shared.fl_leaderboard and shared.data then
                local rank, pts = 1, 0
                for i, obj in next, shared.data do
                    if type(obj) == 'table' and obj.username == USERNAME then
                        rank = i; pts = obj.points or 0
                    end
                end
                shared.fl_leaderboard:set(string.format('Leaderboard: \affd700ff%d\affffffff place, \affd700ff%d\affffffff pts', rank, pts))
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

            -- check if this player has Zenith loaded via global flag
            local has_zenith = false
            for j = 1, globals.maxplayers() do
                if entity.get_steam64(j) == steam_id then
                    -- same machine: check _G flag
                    if j == entity.get_local_player() then
                        has_zenith = (_G._auth_ok == true)
                    end
                    break
                end
            end
            -- also always show for local player if authenticated
            if i == entity.get_local_player() and _auth_alive then
                has_zenith = true
            end

            if has_zenith then
                if not shared.icon_data[ steam_id ] then
                    scoreboard.set_icon(i, _ZENITH_ICON)
                    shared.icon_data[ steam_id ] = true
                end
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

--- region buy bot
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

    client.set_event_callback("round_end_upload_stats", function ()
        local money = entity.get_prop(entity.get_local_player(), "m_iAccount")

        if not buy_bot.enabled:get() or money <= 800 then
            return
        end

        local buy = ''
        local primary = buy_bot.primary:get()
        local secondary = buy_bot.secondary:get()
        local util = buy_bot.utility:get()

        buy = primary == 'None' and buy or buy .. 'buy ' .. primary_console[primary] .. '; '
        buy = secondary == 'None' and buy or buy .. 'buy ' .. secondary_console[secondary] .. '; '

        for i = 1, #util do
            local item = utility_console[ util[i] ]
            buy = buy .. "buy " .. item .. "; "
        end

        if buy == '' then
            return
        end

        client.exec(buy)
    end)
end

---region reatdfdfsd
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


-- ======================================================================
--  PREDICT (shoot enemies earlier via Kalman yaw prediction)
-- ======================================================================
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

-- ======================================================================
--  UNSAFE CHARGE (allow shooting during doubletap even on low HC)
-- ======================================================================
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

-- ======================================================================
--  AUTO OS (auto switch DT -> HideShot in bad conditions)
-- ======================================================================
do
    local auto_os = {}
    auto_os.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Auto OS")
    : record("aa", "auto_os::enabled") : save()

    auto_os.states = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "- States",
        {"Stand", "Crouch", "Air", "Move"})
    : record("aa", "auto_os::states") : save()

    auto_os.avoid_weapons = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "- Avoid States",
        {"Desert Eagle & Crouch", "Knife & Air", "Pistol & Move"})
    : record("aa", "auto_os::avoid") : save()

    local function os_get_state()
        local me = entity.get_local_player()
        if not me then return "Stand" end
        local vel = {entity.get_prop(me, "m_vecVelocity[0]"), entity.get_prop(me, "m_vecVelocity[1]")}
        local spd = math.sqrt((vel[1] or 0)^2 + (vel[2] or 0)^2)
        local flags = entity.get_prop(me, "m_fFlags") or 0
        local on_ground = bit.band(flags, 1) ~= 0
        local crouched = entity.get_prop(me, "m_bDucked") == 1
        if not on_ground then return "Air" end
        if crouched then return "Crouch" end
        if spd > 10 then return "Move" end
        return "Stand"
    end

    client.set_event_callback("setup_command", function(cmd)
        if not auto_os.enabled:get() then return end
        if not software.is_double_tap() then return end

        local me  = entity.get_local_player()
        local wpn = me and entity.get_player_weapon(me)
        local cls = wpn and entity.get_classname(wpn) or ""

        -- only suppress on actual guns - let everything else through (knife, nades, zeus, c4)
        local is_gun = cls:find("rifle") or cls:find("pistol") or cls:find("sniper") or
                       cls:find("machinegun") or cls:find("shotgun") or cls:find("smg") or
                       cls:find("ak47") or cls:find("m4a") or cls:find("awp") or
                       cls:find("aug") or cls:find("sg5") or cls:find("famas") or
                       cls:find("galil") or cls:find("scar") or cls:find("g3sg") or
                       cls:find("ssg") or cls:find("deagle") or cls:find("elite") or
                       cls:find("fiveseven") or cls:find("glock") or cls:find("hkp") or
                       cls:find("p250") or cls:find("revolver") or cls:find("tec9") or
                       cls:find("usp") or cls:find("cz75") or cls:find("mp5") or
                       cls:find("mp7") or cls:find("mp9") or cls:find("mac10") or
                       cls:find("p90") or cls:find("bizon") or cls:find("ump") or
                       cls:find("m249") or cls:find("negev") or cls:find("nova") or
                       cls:find("xm1014") or cls:find("mag7") or cls:find("sawedoff") or
                       cls:find("scout")
        if not is_gun then return end

        local state  = os_get_state()
        local states = auto_os.states:get()
        for _, s in ipairs(states) do
            if s == state then
                cmd.in_attack = false
                return
            end
        end
    end)

    _G.__auto_os = auto_os
end

-- ======================================================================
--  AIR TELEPORT (peek from air using DT + jump timing)
-- ======================================================================
do
    local air_tel = {}
    air_tel.enabled = menu.new_item(ui.new_checkbox, "AA", "Anti-aimbot angles", "Air Teleport")
    : record("aa", "air_tel::enabled") : save()

    air_tel.weapons = menu.new_item(ui.new_multiselect, "AA", "Anti-aimbot angles", "- Weapons",
        {"AWP", "Scout", "Taser", "Pistol", "Rifle"})
    : record("aa", "air_tel::weapons") : save()

    air_tel.allow_cross = menu.new_item(ui.new_combobox, "AA", "Anti-aimbot angles", "- Allow on cross",
        {"No", "Yes"})
    : record("aa", "air_tel::cross") : save()

    local _at_was_air    = false
    local _at_charge     = false
    local _at_dt_suppressed = false  -- true while we force DT off mid-air
    local _at_restore_time  = 0      -- tick to re-enable DT

    -- helper: is any visible enemy able to shoot us (has LOS, is alive, not dormant)
    local function _at_enemy_can_shoot(me)
        local my_pos = entity.get_origin(me)
        if not my_pos then return false end
        for _, ent in ipairs(entity.get_players(true)) do
            if entity.is_alive(ent) and not entity.is_dormant(ent) then
                local epos = entity.get_origin(ent)
                if epos then
                    -- simple distance + LOS check via trace
                    local dist = (my_pos - epos):length()
                    if dist < 3000 then
                        -- trace from enemy eye to our position
                        local eye = entity.get_prop(ent, 'm_vecOrigin')
                        if eye then
                            local trace = engine.trace_line(epos, my_pos, ent)
                            if trace and trace > 0.97 then
                                return true  -- clear LOS within range
                            end
                        end
                    end
                end
            end
        end
        return false
    end

    -- helper: weapon allowed
    local function _at_weapon_ok(me)
        local wpn = entity.get_player_weapon(me)
        local wpn_class = wpn and entity.get_classname(wpn) or ''
        local sel = air_tel.weapons:get()
        if #sel == 0 then return true end
        for _, w in ipairs(sel) do
            if (w == 'AWP'    and wpn_class:find('awp'))    or
               (w == 'Scout'  and wpn_class:find('ssg'))    or
               (w == 'Taser'  and wpn_class:find('taser'))  or
               (w == 'Pistol' and wpn_class:find('pistol')) or
               (w == 'Rifle'  and (wpn_class:find('ak47') or wpn_class:find('m4'))) then
                return true
            end
        end
        return false
    end

    client.set_event_callback('setup_command', function(cmd)
        if not air_tel.enabled:get() then
            -- clean up if disabled mid-flight
            if _at_dt_suppressed then
                ui.set(unpack(settings.rage.double_tap))
                _at_dt_suppressed = false
            end
            return
        end
        local me = entity.get_local_player()
        if not me or not entity.is_alive(me) then return end
        if not _at_weapon_ok(me) then _at_was_air = false; return end

        local flags     = entity.get_prop(me, 'm_fFlags') or 0
        local on_ground = bit.band(flags, 1) ~= 0
        local in_air    = not on_ground
        local now       = globals.tickcount()

        -- ── Restore DT after suppression timeout ──────────────────────────
        if _at_dt_suppressed and now >= _at_restore_time then
            ui.set(unpack(settings.rage.double_tap))  -- re-enable DT
            _at_dt_suppressed = false
        end

        if in_air then
            _at_charge = software.is_double_tap()

            -- If enemy can shoot us while airborne → suppress DT immediately
            if _at_charge and not _at_dt_suppressed then
                local enemy_visible = _at_enemy_can_shoot(me)
                if enemy_visible then
                    -- disable DT so we don't shoot mid-air
                    local dt_ref = settings.rage.double_tap
                    if dt_ref then
                        ui.set(dt_ref[1], false)
                    end
                    _at_dt_suppressed = true
                    _at_restore_time  = now + math.floor((1/globals.tickinterval()) * 2)  -- 2 seconds
                end
            end

            -- block shooting while airborne (only if air_tel enabled)
            if air_tel.enabled:get() then
                cmd.in_attack = false
            end
        end

        -- ── Landed after being airborne → teleport tick ───────────────────
        if _at_was_air and on_ground then
            if _at_charge then
                cmd.in_jump = true   -- ground-snap teleport
                _at_charge  = false
            end
            -- if DT was suppressed, set restore timer from landing moment
            if _at_dt_suppressed then
                _at_restore_time = now + math.floor((1/globals.tickinterval()) * 2)
            end
        end

        _at_was_air = in_air
    end)

    _G.__air_tel = air_tel
end

-- ======================================================================
--  JUMP SCOUT (SSG08 jump shot)
-- ======================================================================
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

-- ======================================================================
--  DORMANT AIMBOT (fire at dormant/gray ESP enemies)
-- ======================================================================
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

-- ======================================================================
--  DROP NADES (drop grenades to teammates)
-- ======================================================================
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

-- ======================================================================
--  ENEMY CHAT REVEALER (show enemy chat in console)
-- ======================================================================
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


-- ======================================================================
--  SESSION STATISTICS (shown on Home page)
-- ======================================================================
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


-- ======================================================================
--  ZENITH LEADERBOARD  (database kill tracking)
-- ======================================================================
do
    local _LB_KEY   = 'zenith_leaderboard_v2'
    local _TOT_KEY  = 'zenith_total_users_v2'
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
            '★Leaderboard: \affd700ff#%d\affffffff of %d (\affd700ff%d kills\affffffff)',
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
-- ======================================================================
client.set_event_callback("net_update_end", exploit.handle_defensive)
client.set_event_callback("net_update_end", exploit.net_update)
client.set_event_callback("net_update_end", localplayer.net_update)
client.set_event_callback("shutdown", function() if gui and gui.shutdown then gui.shutdown() end end)
client.set_event_callback("shutdown", antiaim.shutdown)


-- ======================================================================
--  BRAND HEADER -- Premium animated Zenith branding with icons
-- ======================================================================
do
    local _bh_alpha = 0.0
    local _bh_t     = 0.0

    client.set_event_callback('paint_ui', function()
        local is_open = ui.is_menu_open()
        _bh_alpha = motion.interp(_bh_alpha, is_open and 1 or 0, 0.055)
        if _bh_alpha <= 0.01 then return end

        _bh_t = _bh_t + globals.frametime()

        local r, g, b = widgets.color_picker:rawget()
        local a       = math.floor(255 * _bh_alpha)
        local flags   = "d"

        local sx, sy  = client.screen_size()
        local px      = math.floor(sx * 0.012)
        local py      = math.floor(sy * 0.048)

        -- Premium icons
        local diamond_icon = "\xE2\x97\x86"  -- ◆
        local brand   = diamond_icon .. " Zenith"
        local tagline = "  \xE2\x94\x82  Elegance in Execution."

        local bw, bh  = renderer.measure_text(flags, brand)
        local tw, _   = renderer.measure_text(flags, tagline)
        local sep_w   = bw + tw

        -- animated shimmer: a bright vertical band scrolls across the brand text
        local shimmer  = (_bh_t * 0.8) % 1.0
        local shimmer_x = px + shimmer * sep_w
        local shimmer_a = math.floor(28 * _bh_alpha * (1 - math.abs(shimmer - 0.5) * 2))

        -- glow bar behind separator line
        renderer.rectangle(px, py + bh + 2, sep_w, 2, r, g, b, math.floor(18 * _bh_alpha))

        -- separator line  (1px, accent)
        renderer.rectangle(px, py + bh + 3, sep_w, 1, r, g, b, math.floor(90 * _bh_alpha))

        -- shimmer band (bright white vertical slice)
        if shimmer_a > 0 then
            renderer.rectangle(math.floor(shimmer_x - 2), py, 4, bh,
                255, 255, 255, shimmer_a)
        end

        -- brand name with icon (accent)
        renderer.text(px, py, r, g, b, a, flags, 0, brand)

        -- tagline with separator (dim grey, fades in slightly delayed)
        renderer.text(px + bw, py,
            155, 155, 165, math.floor(190 * _bh_alpha), flags, 0, tagline)
    end)
end


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








--- region valk_features
-- Viewmodel / Third Person / Aspect Ratio / Netgraph / Logs / Autobuy / Ladder / Legs
do
    local G  = "AA"
    local GR = "Anti-aimbot angles"
    local M  = "Misc"
    local MO = "Movement"

    -- UI items: Viewmodel
    local vm_enabled  = menu.new_item(ui.new_checkbox, G,GR, merge{"\n","vf::vm_en"}, "Viewmodel"):record("visuals","vf::vm_en"):save()
    local vm_fov      = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::vm_fov"}, 54, 90, 68, true, "fov", 1):record("visuals","vf::vm_fov"):save()
    local vm_ox       = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::vm_ox"},  0, 50, 25, true, "x", 1):record("visuals","vf::vm_ox"):save()
    local vm_oy       = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::vm_oy"},  0, 40, 20, true, "y", 1):record("visuals","vf::vm_oy"):save()
    local vm_oz       = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::vm_oz"},  0, 40, 20, true, "z", 1):record("visuals","vf::vm_oz"):save()
    local vm_rh       = menu.new_item(ui.new_checkbox, G,GR, merge{"\n","vf::vm_rh"}, "Right Hand"):record("visuals","vf::vm_rh"):save()

    -- Third Person
    local tp_enabled  = menu.new_item(ui.new_checkbox, G,GR, merge{"\n","vf::tp_en"},   "Third Person"):record("visuals","vf::tp_en"):save()
    local tp_dist     = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::tp_dist"}, 10, 300, 80, true, "u", 1):record("visuals","vf::tp_dist"):save()

    -- Aspect Ratio
    local ar_enabled  = menu.new_item(ui.new_checkbox, G,GR, merge{"\n","vf::ar_en"},    "Aspect Ratio"):record("visuals","vf::ar_en"):save()
    local ar_ratio    = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::ar_ratio"}, 50, 200, 100, true, "%", 1):record("visuals","vf::ar_ratio"):save()

    -- Netgraph
    local ng_enabled  = menu.new_item(ui.new_checkbox, G,GR, merge{"\n","vf::ng_en"},  "Netgraph"):record("visuals","vf::ng_en"):save()
    local ng_x        = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::ng_x"}, 0, 3840, 300, true, "px", 1):record("visuals","vf::ng_x"):save()
    local ng_y        = menu.new_item(ui.new_slider,   G,GR, merge{"\n","vf::ng_y"}, 0, 2160, 800, true, "px", 1):record("visuals","vf::ng_y"):save()

    -- Hit/Miss Logs
    local logs_en     = menu.new_item(ui.new_checkbox,      G,GR, merge{"\n","vf::logs_en"}, "Hit/Miss Logs"):record("visuals","vf::logs_en"):save()
    local logs_x      = menu.new_item(ui.new_slider,        G,GR, merge{"\n","vf::logs_x"}, 0, 3840, 970, true, "px", 1):record("visuals","vf::logs_x"):save()
    local logs_y_pos  = menu.new_item(ui.new_slider,        G,GR, merge{"\n","vf::logs_y"}, 0, 2160, 832, true, "px", 1):record("visuals","vf::logs_y"):save()
    local logs_dur    = menu.new_item(ui.new_slider,        G,GR, merge{"\n","vf::logs_dur"}, 1, 10, 5, true, "s", 1):record("visuals","vf::logs_dur"):save()
    local logs_hit_c  = menu.new_item(ui.new_color_picker,  G,GR, merge{"\n","vf::logs_hc"}, 100, 220, 100, 255):record("visuals","vf::logs_hc"):save()
    local logs_miss_c = menu.new_item(ui.new_color_picker,  G,GR, merge{"\n","vf::logs_mc"}, 220, 80, 80, 255):record("visuals","vf::logs_mc"):save()

    -- Misc items
    local fix_hs   = menu.new_item(ui.new_checkbox,    M,MO, merge{"\n","vf::fix_hs"},   "Fix Hideshots"):record("aa","vf::fix_hs"):save()
    local dt_disc  = menu.new_item(ui.new_checkbox,    M,MO, merge{"\n","vf::dt_disc"},  "Auto DT Discharge"):record("aa","vf::dt_disc"):save()
    local fl_en    = menu.new_item(ui.new_checkbox,    M,MO, merge{"\n","vf::fl_en"},    "Fast Ladder"):record("aa","vf::fl_en"):save()
    local fl_modes = menu.new_item(ui.new_multiselect, M,MO, merge{"\n","vf::fl_modes"}, "Ascending", "Descending"):record("aa","vf::fl_modes"):save()
    local ab_en    = menu.new_item(ui.new_checkbox,    M,MO, merge{"\n","vf::ab_en"},    "Autobuy"):record("aa","vf::ab_en"):save()
    local ab_mode  = menu.new_item(ui.new_combobox,    M,MO, merge{"\n","vf::ab_mode"},  "Default", "Intelligent"):record("aa","vf::ab_mode"):save()
    local ab_wpn   = menu.new_item(ui.new_combobox,    M,MO, merge{"\n","vf::ab_wpn"},   "AK-47 / M4A4", "AK-47 / M4A1-S", "Galil / SG553", "FAMAS / AUG", "AWP", "Scout"):record("aa","vf::ab_wpn"):save()
    local ab_pis   = menu.new_item(ui.new_combobox,    M,MO, merge{"\n","vf::ab_pis"},   "P250", "Five-SeveN / Tec-9", "CZ75", "Desert Eagle"):record("aa","vf::ab_pis"):save()
    local ab_oth   = menu.new_item(ui.new_multiselect, M,MO, merge{"\n","vf::ab_oth"},   "Smoke", "Flash", "HE Grenade", "Molotov", "Zeus", "Half Armor", "Full Armor"):record("aa","vf::ab_oth"):save()

    -- Leg animations
    local legs_air  = menu.new_item(ui.new_combobox,    M,MO, merge{"\n","vf::legs_air"},  "Off", "Static", "Moonwalk", "Kangaroo"):record("aa","vf::legs_air"):save()
    local legs_airw = menu.new_item(ui.new_slider,      M,MO, merge{"\n","vf::legs_airw"}, 0, 100, 100, true, "%", 1):record("aa","vf::legs_airw"):save()
    local legs_gnd  = menu.new_item(ui.new_combobox,    M,MO, merge{"\n","vf::legs_gnd"},  "Off", "Static", "Jitter", "Moonwalk", "Kangaroo", "Pacan4ik"):record("aa","vf::legs_gnd"):save()
    local legs_o1   = menu.new_item(ui.new_slider,      M,MO, merge{"\n","vf::legs_o1"},   0, 100, 100, true, "%", 1):record("aa","vf::legs_o1"):save()
    local legs_o2   = menu.new_item(ui.new_slider,      M,MO, merge{"\n","vf::legs_o2"},   0, 100, 100, true, "%", 1):record("aa","vf::legs_o2"):save()
    local legs_jt   = menu.new_item(ui.new_slider,      M,MO, merge{"\n","vf::legs_jt"},   1, 8, 2, true, "t", 1):record("aa","vf::legs_jt"):save()
    local legs_opts = menu.new_item(ui.new_multiselect, M,MO, merge{"\n","vf::legs_opts"}, "Move lean", "Pitch zero on land"):record("aa","vf::legs_opts"):save()
    local legs_lean = menu.new_item(ui.new_slider,      M,MO, merge{"\n","vf::legs_lean"}, 0, 100, 50, true, "%", 1):record("aa","vf::legs_lean"):save()

    -- Page show helpers (called from Visual/Misc page renders)
    _G._vf_show_visual = function()
        _safe_display(vm_enabled)
        if vm_enabled:get() then
            _safe_display(vm_fov); _safe_display(vm_ox)
            _safe_display(vm_oy);  _safe_display(vm_oz); _safe_display(vm_rh)
        end
        _safe_display(tp_enabled)
        if tp_enabled:get() then _safe_display(tp_dist) end
        _safe_display(ar_enabled)
        if ar_enabled:get() then _safe_display(ar_ratio) end
        _safe_display(ng_enabled)
        if ng_enabled:get() then _safe_display(ng_x); _safe_display(ng_y) end
        _safe_display(logs_en)
        if logs_en:get() then
            _safe_display(logs_x); _safe_display(logs_y_pos)
            _safe_display(logs_dur); _safe_display(logs_hit_c); _safe_display(logs_miss_c)
        end
    end

    _G._vf_show_misc = function()
        _safe_display(fix_hs); _safe_display(dt_disc)
        _safe_display(fl_en)
        if fl_en:get() then _safe_display(fl_modes) end
        _safe_display(ab_en)
        if ab_en:get() then
            _safe_display(ab_mode); _safe_display(ab_wpn)
            _safe_display(ab_pis);  _safe_display(ab_oth)
        end
        _safe_display(legs_air)
        if legs_air:get() ~= "Off" then _safe_display(legs_airw) end
        _safe_display(legs_gnd)
        if legs_gnd:get() ~= "Off" then
            _safe_display(legs_o1); _safe_display(legs_o2); _safe_display(legs_jt)
        end
        _safe_display(legs_opts)
        if legs_opts:have_key("Move lean") then _safe_display(legs_lean) end
    end

    -- Hit/miss log data
    local vf_logs = { entries = {} }
    local function vf_add_log(text, is_hit, extra)
        local r, g, b = logs_hit_c:rawget()
        if not is_hit then r, g, b = logs_miss_c:rawget() end
        table.insert(vf_logs.entries, 1, {
            text=text, is_hit=is_hit, r=r, g=g, b=b,
            time=globals.curtime(), frac=0, extra=extra or ""
        })
        while #vf_logs.entries > 8 do table.remove(vf_logs.entries) end
    end

    local function vf_lerp(a, b, t) return a + (b - a) * t end

    local function vf_draw_logs()
        if not logs_en:get() then return end
        local lp = entity.get_local_player()
        if not lp then return end
        local dur = logs_dur:get()
        local bx  = logs_x:get()
        local by  = logs_y_pos:get()
        local PAD = 7; local AW = 3; local LH = 13
        local to_rm = {}
        local cy = by
        for i, log in ipairs(vf_logs.entries) do
            local age = globals.curtime() - log.time
            if age < dur then
                log.frac = vf_lerp(log.frac, 1.0, 0.15)
            else
                log.frac = vf_lerp(log.frac, 0.0, 0.08)
                if log.frac < 0.01 then table.insert(to_rm, i) end
            end
            local fr = log.frac
            if fr < 0.02 then goto vf_skip end
            do
                local a   = math.floor(255 * fr)
                local slx = math.floor(28 * (1 - fr))
                local x   = bx + slx
                local has_extra = log.extra ~= ""
                local ch  = has_extra and (PAD*2 + LH*2 + 2) or (PAD*2 + LH)
                renderer.rectangle(x, cy, 220, ch, 14, 14, 18, math.floor(210 * fr))
                renderer.rectangle(x, cy, AW, ch, log.r, log.g, log.b, a)
                local icon = log.is_hit and "+" or "-"
                renderer.text(x+AW+PAD, cy+PAD, log.r, log.g, log.b, a, "d", 0, icon.." "..(log.text or ""))
                if has_extra then
                    renderer.rectangle(x+AW+PAD, cy+PAD+LH+1, 220-AW-PAD*2, 1, 255,255,255, math.floor(20*fr))
                    renderer.text(x+AW+PAD, cy+PAD+LH+3, 200,200,200, math.floor(a*0.85), "d", 0, log.extra)
                end
                cy = cy + (ch + 4) * fr
            end
            ::vf_skip::
        end
        for i = #to_rm, 1, -1 do table.remove(vf_logs.entries, to_rm[i]) end
    end

    -- aim callbacks for logs
    client.set_event_callback("aim_hit", function(e)
        if not logs_en:get() then return end
        local hg_names = {[0]="body",[1]="head",[2]="chest",[3]="stomach",[4]="l.arm",[5]="r.arm",[6]="l.leg",[7]="r.leg"}
        local name = entity.get_player_name(e.target) or "?"
        local hg   = hg_names[e.hitgroup] or "body"
        local dmg  = e.damage or 0
        vf_add_log(name.." ("..hg..")", true, dmg.."dmg")
    end)
    client.set_event_callback("aim_miss", function(e)
        if not logs_en:get() then return end
        local name   = entity.get_player_name(e.target) or "?"
        local reason = e.reason or "?"
        if reason == "?" then reason = "resolver" end
        vf_add_log(name, false, reason)
    end)

    -- Netgraph
    local ng_fps, ng_ping, ng_last = 0, 0, 0
    local function vf_draw_ng()
        if not ng_enabled:get() then return end
        local now = globals.curtime()
        if now - ng_last > 0.1 then
            ng_fps  = math.floor(1 / math.max(globals.frametime(), 0.001) + 0.5)
            ng_ping = math.floor((client.real_latency() or 0) * 1000 + 0.5)
            ng_last = now
        end
        local x = ng_x:get(); local y = ng_y:get()
        renderer.text(x, y,    200,200,200,200, "d", 0, string.format("fps: %d   ping: %dms", ng_fps, ng_ping))
        renderer.text(x, y+12, 200,200,200,200, "d", 0, "loss: 0%  choke: 0%")
    end

    client.set_event_callback("paint", function()
        vf_draw_logs()
        vf_draw_ng()
    end)

    -- Viewmodel/TP/AR
    local function vf_apply_vm()
        if not vm_enabled:get() then return end
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end
        client.set_cvar("viewmodel_fov",      vm_fov:get())
        client.set_cvar("viewmodel_offset_x", (vm_ox:get()-25)/10)
        client.set_cvar("viewmodel_offset_y", (vm_oy:get()-20)/10)
        client.set_cvar("viewmodel_offset_z", (vm_oz:get()-20)/10)
        client.set_cvar("cl_righthand",       vm_rh:get() and 1 or 0)
    end
    local _tp_ok, _tp_ref1, _tp_ref2 = pcall(function()
        return ui.reference("Visuals","Effects","Force third person (alive)")
    end)
    local function vf_apply_tp()
        if tp_enabled:get() then
            local d = tp_dist:get()
            if _tp_ref1 then pcall(ui.set,_tp_ref1,true) end
            if _tp_ref2 then pcall(ui.set,_tp_ref2,true) end
            client.set_cvar("c_mindistance",d); client.set_cvar("c_maxdistance",d)
        else
            client.set_cvar("c_mindistance",30); client.set_cvar("c_maxdistance",30)
        end
    end
    local function vf_apply_ar()
        if not ar_enabled:get() then client.set_cvar("r_aspectratio",0); return end
        local sw,sh = client.screen_size()
        client.set_cvar("r_aspectratio", (sw*(ar_ratio:get()/100))/sh)
    end
    ui.set_callback(vm_enabled.ref, vf_apply_vm); ui.set_callback(vm_fov.ref, vf_apply_vm)
    ui.set_callback(vm_ox.ref, vf_apply_vm);      ui.set_callback(vm_oy.ref, vf_apply_vm)
    ui.set_callback(vm_oz.ref, vf_apply_vm);      ui.set_callback(vm_rh.ref, vf_apply_vm)
    ui.set_callback(tp_enabled.ref, vf_apply_tp); ui.set_callback(tp_dist.ref, vf_apply_tp)
    ui.set_callback(ar_enabled.ref, vf_apply_ar); ui.set_callback(ar_ratio.ref, vf_apply_ar)

    -- Fast ladder / fix hideshots / DT discharge
    local _vf_hs_saved, _vf_hs_val = false, 14
    local _fl_limit_ref; pcall(function() _fl_limit_ref = ui.reference("AA","Fake lag","Limit") end)
    local _dt_ref;        pcall(function() _dt_ref = ui.reference("Rage","Aimbot","Double tap") end)

    client.set_event_callback("setup_command", function(cmd)
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end

        if fl_en:get() and entity.get_prop(lp,"m_MoveType") == 9 then
            local pitch = select(1, client.camera_angles())
            cmd.yaw = math.floor(cmd.yaw+0.5); cmd.roll = 0
            if fl_modes:have_key("Ascending") and cmd.forwardmove>0 and pitch<45 then
                cmd.pitch=89; cmd.in_moveright=1; cmd.in_moveleft=0; cmd.in_forward=0; cmd.in_back=1
                if cmd.sidemove==0 then cmd.yaw=cmd.yaw+90
                elseif cmd.sidemove<0 then cmd.yaw=cmd.yaw+150
                else cmd.yaw=cmd.yaw+30 end
            end
            if fl_modes:have_key("Descending") and cmd.forwardmove<0 then
                cmd.pitch=89; cmd.in_moveleft=1; cmd.in_moveright=0; cmd.in_forward=1; cmd.in_back=0
                if cmd.sidemove==0 then cmd.yaw=cmd.yaw+90
                elseif cmd.sidemove>0 then cmd.yaw=cmd.yaw+150
                else cmd.yaw=cmd.yaw+30 end
            end
        end

        if fix_hs:get() and _fl_limit_ref then
            local isOs = software.is_on_shot_antiaim()
            local isDt = software.is_double_tap()
            local isFd = software.is_duck_peek_assist()
            if isOs and not isDt and not isFd then
                if not _vf_hs_saved then _vf_hs_val=ui.get(_fl_limit_ref); _vf_hs_saved=true end
                ui.set(_fl_limit_ref, 1)
            elseif _vf_hs_saved then
                ui.set(_fl_limit_ref, _vf_hs_val); _vf_hs_saved=false
            end
        end

        if dt_disc:get() and _dt_ref then
            local enemies = entity.get_players(true)
            local vis = false
            for _,ent in ipairs(enemies) do
                local bx,by,bz = entity.hitbox_position(ent,1)
                if bx and client.visible(bx,by,bz+20) then vis=true; break end
            end
            if vis then
                ui.set(_dt_ref,false)
                client.delay_call(0.01,function() ui.set(_dt_ref,true) end)
            end
        end

        vf_apply_vm()
    end)

    -- Autobuy
    local ab_pt = {["AK-47 / M4A4"]="ak47",["AK-47 / M4A1-S"]="ak47",["Galil / SG553"]="sg556",["FAMAS / AUG"]="sg556",["AWP"]="awp",["Scout"]="ssg08"}
    local ab_pc = {["AK-47 / M4A4"]="m4a1",["AK-47 / M4A1-S"]="m4a1_silencer",["Galil / SG553"]="galilar",["FAMAS / AUG"]="aug",["AWP"]="awp",["Scout"]="ssg08"}
    local ab_pcs= {["P250"]="p250",["Five-SeveN / Tec-9"]="fiveseven",["CZ75"]="cz75a",["Desert Eagle"]="deagle"}
    local ab_streak = 0
    client.set_event_callback("round_start", function()
        if not ab_en:get() then return end
        local lp=entity.get_local_player(); if not lp then return end
        local money=entity.get_prop(lp,"m_iAccount") or 0
        local is_ct=(entity.get_prop(lp,"m_iTeamNum") or 2)==3
        local mode=ab_mode:get(); local sel_w=ab_wpn:get(); local sel_p=ab_pis:get()
        local oth=ab_oth:get() or {}
        local function has(v) for _,x in ipairs(oth) do if x==v then return true end end return false end
        local pri=is_ct and (ab_pc[sel_w] or "m4a1") or (ab_pt[sel_w] or "ak47")
        local pis=ab_pcs[sel_p] or "p250"
        local arm=has("Full Armor") and "vesthelm" or has("Half Armor") and "vest" or nil
        local mol=is_ct and "incgrenade" or "molotov"
        local q={}; local function bq(c) q[#q+1]=c end
        if mode=="Default" then
            if money>=800 then
                if money>=2700 then bq("buy "..pri) end
                bq("buy "..pis)
                if arm then bq("buy "..arm) end
                if has("Smoke") then bq("buy smokegrenade") end; if has("Flash") then bq("buy flashbang") end
                if has("HE Grenade") then bq("buy hegrenade") end; if has("Molotov") then bq("buy "..mol) end
                if has("Zeus") then bq("buy taser") end
            end
        else
            local full=is_ct and 4000 or 3700; local eco=is_ct and 1200 or 1000; local force=is_ct and 2000 or 1800
            if ab_streak>=3 then full=full+1000 end
            if money>=full then bq("buy "..pri); bq("buy "..pis); if arm then bq("buy "..arm) end
                if has("Smoke") then bq("buy smokegrenade") end; if has("HE Grenade") then bq("buy hegrenade") end
            elseif money>=force then bq("buy "..pri); bq("buy "..pis); if arm then bq("buy "..arm) end
            elseif money>=eco then bq("buy "..pis) end
        end
        if #q>0 then client.exec(table.concat(q,";")) end
    end)
    client.set_event_callback("round_end", function(e)
        local lp=entity.get_local_player(); if not lp then return end
        local mt=entity.get_prop(lp,"m_iTeamNum") or 2
        if e and e.winner==mt then ab_streak=0 else ab_streak=ab_streak+1 end
    end)

    -- Leg animations
    local _leg_mv_ref; pcall(function() _leg_mv_ref=ui.reference("AA","Other","Leg movement") end)
    local function set_lm(v) if _leg_mv_ref then pcall(ui.set,_leg_mv_ref,v) end end

    client.set_event_callback("pre_render", function()
        local lp=entity.get_local_player()
        if not lp or not entity.is_alive(lp) then return end
        local flags=entity.get_prop(lp,"m_fFlags") or 0
        local on_ground=bit.band(flags,1)==1
        local tc=globals.tickcount()
        if on_ground then
            local v=legs_gnd:get(); local o1=legs_o1:get(); local o2=legs_o2:get(); local spd=legs_jt:get()
            if v=="Static" then entity.set_prop(lp,"m_flPoseParameter",1.0,0); set_lm("Always slide")
            elseif v=="Jitter" then
                local mul=1.0/(tc%(spd*4)>=(spd*2) and 200 or 400)
                entity.set_prop(lp,"m_flPoseParameter",(tc%(spd*2)>=spd and o1 or o2)*mul,0); set_lm("Always slide")
            elseif v=="Moonwalk" then entity.set_prop(lp,"m_flPoseParameter",0.0,7); set_lm("Never slide")
            elseif v=="Kangaroo" then
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(0,1),3)
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(0,1),7)
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(0,1),6); set_lm("Off")
            elseif v=="Pacan4ik" then
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(o1*0.01,o2*0.01),0)
                set_lm(client.random_int(0,1)==0 and "Off" or "Always slide")
            else set_lm("Off") end
        else
            local v=legs_air:get()
            if v=="Static" then entity.set_prop(lp,"m_flPoseParameter",legs_airw:get()*0.01,6)
            elseif v=="Moonwalk" then entity.set_prop(lp,"m_flPoseParameter",(globals.curtime()*0.55)%1,6)
            elseif v=="Kangaroo" then
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(0,1),3)
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(0,1),7)
                entity.set_prop(lp,"m_flPoseParameter",client.random_float(0,1),6)
            end
        end
        local opts=legs_opts:get() or {}
        local has_lean=false; for _,v in ipairs(opts) do if v=="Move lean" then has_lean=true; break end end
        if has_lean then
            local vx=entity.get_prop(lp,"m_vecVelocity[0]") or 0; local vy=entity.get_prop(lp,"m_vecVelocity[1]") or 0
            if math.sqrt(vx*vx+vy*vy)>1 then end -- layer access requires ent lib, skip for now
        end
        local has_land=false; for _,v in ipairs(opts) do if v=="Pitch zero on land" then has_land=true; break end end
        if has_land and on_ground then
            entity.set_prop(lp,"m_flPoseParameter",0.5,12)
        end
    end)
    client.set_event_callback("shutdown", function() set_lm("Off") end)

end -- end region valk_features

menu.set_callback(function()

    _safe_display(shared.online_label)
    -- display fake lag info panel every frame
    if shared.fl_whatsup     then _safe_display(shared.fl_whatsup)     end
    if shared.fl_build       then _safe_display(shared.fl_build)       end
    if shared.fl_version     then _safe_display(shared.fl_version)     end
    if shared.fl_online      then _safe_display(shared.fl_online)      end

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

    -- ── SETUP ────────────────────────────────────────────────────────
    -- Features, Safe Head, Manual, Edge Yaw, Freestand, AA tweaks
    if page == "Setup" then
        _safe_display(settings.tweaks_enable)
        if settings.tweaks_enable:get() then
            _safe_display(settings.tweaks)
        end

        _safe_display(aa_tweaks.enable)
        if aa_tweaks.enable:get() then
            _safe_display(aa_tweaks.items)
        end

        _safe_display(safe_head.enabled)
        if safe_head.enabled:get() then
            _safe_display(safe_head.states)
        end

        _safe_display(fs_disablers.states)

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

        -- Valkyrie misc features
        if _G._vf_show_misc then _G._vf_show_misc() end

    end

    -- ── AIMBOT ──────────────────────────────────────────────────────
    -- Predict, Resolver, Unsafe Charge, Auto OS, Air Teleport, Jump Scout, Dormant

    -- ── BUILDER ──────────────────────────────────────────────────────
    -- Custom AA angles builder (offset, modifier, desync, limitation)
    -- ── DEFENSIVE ────────────────────────────────────────────────────
        if page == "Builder" then
        if _G._valk_show then _G._valk_show() end
    end


    -- ── VISUAL ─────────────────────��─────────────────────────────────
    -- Widgets, Custom scope, Buy bot, Clientside nickname
    if page == "Visual" then
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

        _safe_display(buy_bot.enabled)
        if buy_bot.enabled:get() then
            _safe_display(buy_bot.primary)
            _safe_display(buy_bot.secondary)
            _safe_display(buy_bot.utility)
        end

        if _G._vf_show_visual then _G._vf_show_visual() end

        _safe_display(clientside_nickname.enabled)
        if clientside_nickname.enabled:get() then
            _safe_display(clientside_nickname.nickname)
            _safe_display(clientside_nickname.apply)
        end

        -- Clantag on Visual page
        if _G.__misc_page and _G.__misc_page.show_clantag then
            _G.__misc_page.show_clantag()
        end
    end

    -- HOME PAGE
    if page == "Home" then
        if _G.__home then _G.__home.show() end
    end



    if page == "Configs" then
        if _G.__configs_show then _G.__configs_show() end
    end
end)

menu.update()








-- ======================================================================
--  CONFIG SYSTEM (Zenith)
-- ======================================================================
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
    local m_export  = menu.new_item(ui.new_button,  'AA','Anti-aimbot angles','Export to Clipboard', function() end)
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

    m_export:set_callback(function()
        local sel = live[cur_sel]
        if not sel then set_status('No config selected.'); return end
        -- build export string: zenith:gs <json>
        local data_str
        if sel.source == 'local' then
            -- re-export current settings live
            data_str = 'zenith:gs ' .. export_data()
        else
            -- cloud config: export as-is
            data_str = sel.data
        end
        -- copy to clipboard via panorama
        pcall(function()
            local panorama_api = panorama.open()
            panorama_api.SteamOverlayAPI.SetClipboardText(data_str)
        end)
        -- fallback: client.exec paste trick won't work, so just show the string in status
        -- and also try the vtable clipboard method
        pcall(function()
            local ffi = require 'ffi'
            local char_array = ffi.typeof 'char[?]'
            local SetClipboardText = vtable_bind('vgui2.dll','VGUI_System010',9,'void(__thiscall*)(void*, const char*, int)')
            SetClipboardText(data_str, #data_str)
        end)
        set_status('\a71bc78ffCopied! Paste in Discord to share.')
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
        _safe_display(m_export)
        _safe_display(m_status)
    end

    -- expose for external use
    _G._zenith_export_cfg = export_data
    _G._zenith_import_cfg = apply_data

    client.delay_call(1, reload)
end


-- ======================================================================
--  HOME PAGE  — Umbrella-inspired: brand header + bullet info rows
-- ======================================================================
do
    local home = {}
    _G.__home = home

    -- ── static labels ────────────────────────────────────────────────
    -- brand header (drawn via paint_ui, not pui labels)
    -- stat labels
    home.lbl_stats   = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', '\a71bc78ff\xe2\x96\xb6 Statistics')
    home.lbl_total   = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', '\xe2\x96\xb6 Total time: \a71bc78ff0.0 Hours')
    home.lbl_session = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', '\xe2\x8f\xb8 This session: \a71bc78ff0 Minutes')
    home.lbl_hs      = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', 'Headshots: \a71bc78ff0%')
    home.lbl_kills   = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', 'Killed: \a71bc78ff0')
    home.lbl_misses  = menu.new_item(ui.new_label, 'AA', 'Anti-aimbot angles', 'Misses: \a71bc78ff0')

    local _s_start  = globals.realtime and globals.realtime() or 0
    local _s_kills  = 0
    local _s_hs     = 0
    local _s_misses = 0
    local _last_sv  = 0

    local function _get_total()
        local ok, v = pcall(function() return database.read('zenith_total_time_v1') end)
        return (ok and type(v) == 'number') and v or 0
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
        local rt   = globals.realtime and globals.realtime() or 0
        local secs = rt - _s_start
        local mins = math.floor(secs / 60)
        if rt - _last_sv > 60 then
            _save_total(_get_total() + secs / 3600)
            _last_sv = rt
        end
        local tot    = _get_total()
        local hs_pct = _s_kills > 0 and math.floor(_s_hs / _s_kills * 100) or 0

        home.lbl_total:set(string.format('\xe2\x96\xb6 Total time: \a71bc78ff%.1f Hours', tot))
        home.lbl_session:set(string.format('\xe2\x8f\xb8 This session: \a71bc78ff%d Minutes', mins))
        home.lbl_hs:set(string.format('Headshots: \a71bc78ff%d%%', hs_pct))
        home.lbl_kills:set(string.format('Killed: \a71bc78ff%d', _s_kills))
        home.lbl_misses:set(string.format('Misses: \a71bc78ff%d', _s_misses))
    end

    -- ── painted header (drawn on paint_ui when menu open + Home page) ─
    local _header_alpha = 0.0

    client.set_event_callback('paint_ui', function()
        if not ui.is_menu_open() then
            _header_alpha = motion.interp(_header_alpha, 0, 0.08)
            if _header_alpha <= 0 then return end
        end

        -- only render on Home page
        local sel_ok, sel = pcall(ui.get, gui.selection:get_ref())
        if not (sel_ok and sel == 'Home') then
            _header_alpha = motion.interp(_header_alpha, 0, 0.08)
            return
        end
        _header_alpha = motion.interp(_header_alpha, 1, 0.06)
        if _header_alpha <= 0.01 then return end

        local r, g, b = widgets.color_picker:rawget()
        local a       = math.floor(255 * _header_alpha)
        local flags   = "d"

        -- position: top of the fakelag group panel
        -- approximate fixed position; adjust if needed
        local sx, sy  = client.screen_size()
        local px = math.floor(sx * 0.012)
        local py = math.floor(sy * 0.045)

        -- "Zenith" in accent colour
        local brand       = "Zenith"
        local tagline     = "\xc2\xb7 Powered by Zenith"
        local bw, bh      = renderer.measure_text(flags, brand)
        local tw, _       = renderer.measure_text(flags, tagline)

        renderer.text(px, py, r, g, b, a, flags, 0, brand)
        renderer.text(px + bw + 6, py, 170, 170, 170, math.floor(200 * _header_alpha), flags, 0, tagline)

        -- thin separator line under brand
        py = py + bh + 4
        renderer.rectangle(px, py, bw + 6 + tw, 1, r, g, b, math.floor(120 * _header_alpha))
    end)

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
-- ======================================================================
do
    local mp = {}
    _G.__misc_page = mp   -- keep reference so Visual page show_clantag() still works

    -- Tags
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

    -- Menu items
    mp.lbl_ct   = menu.new_item(ui.new_label,    'AA','Anti-aimbot angles', '\a71bc78ff⚡ Clantag')
    mp.ct_en    = menu.new_item(ui.new_checkbox, 'AA','Anti-aimbot angles', 'Custom Clantag'):record('misc','misc::ct_en'):save()
    mp.ct_en:set_callback(function() menu.update() end)
    mp.ct_mode  = menu.new_item(ui.new_combobox, 'AA','Anti-aimbot angles', 'Animation',
                    {'Static','Write','Scroll','Bounce','Flicker'}):record('misc','misc::ct_mode'):save()
    mp.ct_mode:set_callback(function() menu.update() end)
    mp.ct_text  = menu.new_item(ui.new_textbox,  'AA','Anti-aimbot angles', 'Custom Text'):record('misc','misc::ct_text'):save()
    mp.ct_speed = menu.new_item(ui.new_slider,   'AA','Anti-aimbot angles', 'Speed', 1, 20, 5):record('misc','misc::ct_speed'):save()

    -- Defaults
    client.delay_call(0.1, function()
        if not mp.ct_en:get() then mp.ct_en:set(true) end
        local ok,v = pcall(ui.get, mp.ct_text.ref)
        if not ok or not v or v=='' then pcall(ui.set, mp.ct_text.ref, 'zenith.gs') end
    end)

    -- Show on Visual page
    function mp.show_clantag()
        _safe_display(mp.lbl_ct)
        _safe_display(mp.ct_en)
        local ok_en, en = pcall(ui.get, mp.ct_en.ref)
        if ok_en and en then
            _safe_display(mp.ct_mode)
            local ok_m, mode = pcall(ui.get, mp.ct_mode.ref)
            mode = (ok_m and mode) or 'Static'
            if mode == 'Static' then
                _safe_display(mp.ct_text)
            else
                _safe_display(mp.ct_speed)
            end
        end
    end

    -- No misc tab needed - show() is empty
    function mp.show() end

    -- Engine
    local _old_tick = 0
    local _win_panel = false

    client.set_event_callback('cs_win_panel_match', function()
        _win_panel = true
        client.set_clan_tag('zenith.gs')
    end)
    client.set_event_callback('round_poststart', function()
        _win_panel = false
        -- force-apply clantag on round start for immediate scoreboard visibility
        if mp.ct_en and mp.ct_en:get() then
            local ok2, txt = pcall(ui.get, mp.ct_text.ref)
            client.set_clan_tag((ok2 and txt and txt ~= '') and txt or 'zenith.gs')
        end
    end)
    client.set_event_callback('round_start', function()
        _old_tick = -999  -- force update on next net_update_end
    end)

    local function play_tag(frames, speed, count)
        local idx = math.floor(globals.curtime() * speed % count) + 1
        client.set_clan_tag(frames[idx])
    end

    client.set_event_callback('net_update_end', function()
        if _win_panel then return end
        -- check gamesense native clantag spammer
        local ok, gs_ct = pcall(ui.get, ui.reference('Misc','Miscellaneous','Clan tag spammer'))
        if ok and gs_ct then return end

        if not mp.ct_en or not mp.ct_en:get() then
            client.set_clan_tag('')
            return
        end

        if globals.tickcount() - _old_tick < 4 then return end
        _old_tick = globals.tickcount()

        local mode = mp.ct_mode:get()
        local spd  = mp.ct_speed:get()

        if mode == 'Static' then
            local ok2, txt = pcall(ui.get, mp.ct_text.ref)
            client.set_clan_tag(ok2 and txt or 'zenith.gs')
        elseif mode == 'Write' then
            play_tag(_write_tag, spd * 0.5, #_write_tag)
        elseif mode == 'Scroll' then
            play_tag(_scroll_tag, spd * 0.3, #_scroll_tag)
        elseif mode == 'Bounce' then
            play_tag(_bounce_tag, spd * 0.5, #_bounce_tag)
        elseif mode == 'Flicker' then
            play_tag(_flicker_tags, spd * 0.8, #_flicker_tags)
        end
    end)
end



---region trashtalk
do
    local _tt_lines = {
        'L', 'ez', 'ratio', 'skill issue', 'get recked',
        'not even close', 'uninstall', 'LOL', 'ggez', 'trash',
        'outplayed', 'cry about it', 'too easy', 'go next',
    }
    local _tt_last = 0

    client.set_event_callback('player_death', function(e)
        if not _auth_alive then return end
        if not settings.tweaks_enable or not settings.tweaks_enable:get() then return end
        local ok, has = pcall(function() return settings.tweaks:have_key('Trashtalk') end)
        if not ok or not has then return end

        local me = entity.get_local_player()
        if not me then return end
        local attacker = client.userid_to_entindex(e.attacker)
        if attacker ~= me then return end  -- only on our kills

        -- one message per kill, cooldown 3s
        local now = globals.realtime()
        if now - _tt_last < 3 then return end
        _tt_last = now

        local line = _tt_lines[math.random(#_tt_lines)]
        client.exec('say ' .. line)
    end)
end
---endregion trashtalk
client.color_log(113, 152, 255, '[Zenith] Clantag system loaded.')



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

