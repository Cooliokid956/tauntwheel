-- name: Taunt Wheel
-- description: A customizable taunt wheel that supports the addition of more taunts.

_G.ACT_TAUNT = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_STATIONARY | ACT_FLAG_IDLE)

-- from Character Select (thanks squishy)
local saveableCharacters = {
    ["1"] = 1,
    ["2"] = 1,
    ["3"] = 1,
    ["4"] = 1,
    ["5"] = 1,
    ["6"] = 1,
    ["7"] = 1,
    ["8"] = 1,
    ["9"] = 1,
    ["0"] = 1,
    ["a"] = 1,
    ["b"] = 1,
    ["c"] = 1,
    ["d"] = 1,
    ["e"] = 1,
    ["f"] = 1,
    ["g"] = 1,
    ["h"] = 1,
    ["i"] = 1,
    ["j"] = 1,
    ["k"] = 1,
    ["l"] = 1,
    ["m"] = 1,
    ["n"] = 1,
    ["o"] = 1,
    ["p"] = 1,
    ["q"] = 1,
    ["r"] = 1,
    ["s"] = 1,
    ["t"] = 1,
    ["u"] = 1,
    ["v"] = 1,
    ["w"] = 1,
    ["x"] = 1,
    ["y"] = 1,
    ["z"] = 1,
    ["_"] = 1,
    ["-"] = 1,
    ["."] = 1,
}

--- @param string string
--- Constructs a new string but only with characters from `saveableCharacters`
--- * Spaces are the notable character that gets turned into an underscore
function string_space_to_underscore(string)
    local s = ''
    for i = 1, #string do
        local c = string:sub(i,i)
        if saveableCharacters[c:lower()] then
            s = s .. c
        elseif c == " " then
            s = s .. "_"
        end
    end
    return s
end

--- @class Taunt
--- @field public name      string
--- @field public shortName string
--- @field public func      function

--- @class Sprite
--- @field public label string
--- @field public x number
--- @field public y number
--- @field public z number
--- @field public xv number
--- @field public yv number
--- @field public zv number

--- @return Sprite
local function Sprite(label)
    return {
        label = label,
        x  = 0,
        y  = 0,
        z  = 0,
        xv = 0,
        yv = 0,
        zv = 0
    }
end

-- local function split(s)
--     local result = {}
--     for match in (s):gmatch(string.format("[^%s]+", ",")) do
--         table.insert(result, match)
--     end
--     return result
-- end

local wheelState = 0
local selectedTaunt

local TWApi = {} -- needs work.,
local TWHelpers = {}

-- -------- Helpers -------- --
---@param m MarioState
---@param anim CharacterAnimID|string
---@param loopEnd integer?
local function taunt_looping_anim(m, anim, loopEnd)
    local isString = type(anim) == "string"
    set_character_animation(m, isString and 0 or anim)
    if isString then
       smlua_anim_util_set_animation(m.marioObj, anim)
    end
    if loopEnd and is_anim_past_frame(m, loopEnd) ~= 0 or is_anim_past_end(m) ~= 0 then
        set_anim_to_frame(m, 0)
    end
end
---@param anim CharacterAnimID|string
---@param loopEnd integer?
local function LOOPING_ANIM(anim, loopEnd)
    return function (m) taunt_looping_anim(m, anim, loopEnd) end
end
TWHelpers.LOOPING_ANIM = LOOPING_ANIM

---@param m MarioState
---@param anim CharacterAnimID|string
local function taunt_anim(m, anim)
    local isString = type(anim) == "string"
    set_character_animation(m, isString and 0 or anim)
    if isString then
       smlua_anim_util_set_animation(m.marioObj, anim)
    end
end
---@param anim CharacterAnimID|string
local function ANIM(anim)
    return function (m) taunt_anim(m, anim) end
end
TWHelpers.ANIM = ANIM

_G.TWHelpers = TWHelpers

-- -------- API -------- --
---@type Taunt[]
local tauntPool = {}

---@param name string
---@param func function
---@return Taunt
local function register_taunt(name, func)
    table.insert(tauntPool, {
        name = name,
        shortName = string_space_to_underscore(name),
        func = func
    })
    return tauntPool[-1]
end
TWApi.register_taunt = register_taunt

---@param m MarioState
---@return Taunt|false
local function get_current_taunt(m)
    return m.action == ACT_TAUNT and tauntPool[m.actionArg]
end
TWApi.get_current_taunt = get_current_taunt

---@return integer
local function get_taunt_count() return #tauntPool end
TWApi.get_taunt_count = get_taunt_count

---@param name string
---@return Taunt|nil
local function get_taunt_from_name(name)
    for _, taunt in ipairs(tauntPool) do
        if taunt.name == name then return taunt end
    end
end
TWApi.get_taunt_from_name = get_taunt_from_name

---@param shortName string
---@return Taunt|nil
local function get_taunt_from_short_name(shortName)
    for _, taunt in ipairs(tauntPool) do
        if taunt.shortName == shortName then return taunt end
    end
end
TWApi.get_taunt_from_short_name = get_taunt_from_short_name

_G.TWApi = TWApi

-- -------- Built-in taunts-------- --
local function ANIMFRAME(o) return o.header.gfx.animInfo.animFrame end

---@param m MarioState
local function star_dance_update(m)
    local taunt = get_current_taunt(m)
    if not taunt then return end
    local frame = ANIMFRAME(m.marioObj)
    local bodyState = m.marioBodyState
    if frame == 1 then
        spawn_non_sync_object(id_bhvCelebrationStar, E_MODEL_STAR, 0,0,0, function (o)
            o.parentObj = m.marioObj
        end)
    elseif frame == 42 then
        play_character_sound(m, CHAR_SOUND_HERE_WE_GO)
    end

    if taunt.name == "Star Dance" then
        if frame > 38 then
            bodyState.handState = MARIO_HAND_PEACE_SIGN
        end
    elseif taunt.name == "Water Star Dance" then
        if frame > 61 then
            bodyState.handState = MARIO_HAND_PEACE_SIGN
        end
    end
end

local function death_update(m)
    m.marioBodyState.eyeState = MARIO_EYES_DEAD

    play_character_sound_if_no_flag(m, CHAR_SOUND_DYING, MARIO_ACTION_SOUND_PLAYED)
    if ANIMFRAME(m.marioObj) == 77 then
        play_mario_landing_sound(m, SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
    end
end

register_taunt("Shock",
function (m)
    taunt_looping_anim(m, CHAR_ANIM_SHOCKED)

    m.marioBodyState.eyeState = math.random(8)
    if m.marioObj.oTimer % 2 == 0 then
        m.flags = m.flags | MARIO_METAL_SHOCK
    else
        m.flags = m.flags & ~MARIO_METAL_SHOCK
    end

    play_sound(SOUND_MOVING_SHOCKED, m.marioObj.header.gfx.cameraToObject)
end)
register_taunt("T-Pose", ANIM(CHAR_ANIM_TWIRL))
register_taunt("Wave",
function (m)
    taunt_looping_anim(m, CHAR_ANIM_CREDITS_WAVING)
    m.marioBodyState.handState = MARIO_HAND_OPEN
end)
register_taunt("Star Dance",
function (m)
    taunt_anim(m, CHAR_ANIM_STAR_DANCE)
    star_dance_update(m)
end)
register_taunt("Water Star Dance",
function (m)
    taunt_anim(m, CHAR_ANIM_WATER_STAR_DANCE)
    star_dance_update(m)
end)
register_taunt("Death",
function (m)
    taunt_anim(m, CHAR_ANIM_DYING_FALL_OVER)
    death_update(m)
end)
register_taunt("Stuck",
function (m)
    taunt_looping_anim(m, CHAR_ANIM_BOTTOM_STUCK_IN_GROUND, 127)

    if ANIMFRAME(m.marioObj) > 88 then
        m.marioBodyState.eyeState = MARIO_EYES_CLOSED
    end
end)
register_taunt("Death 2",
function (m)
    taunt_anim(m, CHAR_ANIM_ELECTROCUTION)
    death_update(m)
end)

--------------------------------------------------

local function unit()
    return math.min(djui_hud_get_screen_width(),djui_hud_get_screen_height())
end

local sprites = {}

-- -------- Loadout Storage -------- --
local loadoutLen = mod_storage_load_number("loadout_len")
---@type Taunt[]
local loadout = {}

local function save_loadout()
    mod_storage_save_number("loadout_len", loadoutLen)
    for i = 1, loadoutLen do
        log_to_console(loadout[i].shortName)
        mod_storage_save("slot"..i, loadout[i].shortName)
    end
end

hook_event(HOOK_ON_MODS_LOADED, function ()
    if loadoutLen ~= 0 then
        -- attempt loading
        for i = 1, loadoutLen do
            loadout[i] = get_taunt_from_short_name(mod_storage_load("slot"..i))
        end
    else
        -- load defaults
        djui_chat_message_create("loading defs..")
        loadoutLen = 8
        for i = 1, loadoutLen do
            djui_chat_message_create("taunt "..i..": "..tauntPool[i].name)
            loadout[i] = tauntPool[i]
        end
        save_loadout()
    end

    --printloadout
    for i = 1, loadoutLen do
        djui_chat_message_create("taunt "..i..": "..loadout[i].name)
    end
end)

-- ! will create sprites on wheel open, no pregen
-- for i, name in ipairs(loadout) do
--     table.insert(sprites, Sprite(name))
-- end

function checkwheel(m)
if m.playerIndex ~= 0 then return end
    if wheelState == 0 and m.controller.buttonDown & U_JPAD ~= 0 and m.action & ACT_FLAG_IDLE ~= 0 then
        wheelState = 1
    elseif wheelState == 1 then
        wheelState = 2
    elseif wheelState == 2 and (m.controller.buttonDown & U_JPAD == 0 or m.action & ACT_FLAG_IDLE == 0) then
        wheelState = 3
    elseif wheelState == 3 then
        wheelState = 4
    end
end

function render_text_centered(t, x, y, z)
    djui_hud_print_text(t, x - djui_hud_measure_text(t) * z/2,  y - 32*z,  z)
end
function render_text_centered_interpolated(t, px, py, pz, x, y, z)
    djui_hud_print_text_interpolated(t, px - djui_hud_measure_text(t) * pz/2, py - 32*pz, pz,
                                         x - djui_hud_measure_text(t) *  z/2,  y - 32* z,  z)
end

---@param s Sprite
function rendertext(s)
    if not s then return end
    render_text_centered_interpolated(s.label, s.x - s.xv, s.y - s.yv, s.z - s.zv,
                                               s.x,        s.y,        s.z       )
end

function renderwheel()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)
    djui_hud_set_color(255, 255, 255, 255)
    local w = djui_hud_get_screen_width()
    local h = djui_hud_get_screen_height()
    local tauntDist = unit()/7
    local m = gMarioStates[0]

    if wheelState == 1 then
        for i, sprite in ipairs(sprites) do
            sprite.x  = w/2
            sprite.y  = h/2
            sprite.z  = 0.00000001
            sprite.xv = (math.sin(math.rad((i-1) * 360/#sprites + (math.random()*10))) - math.random()* 10) * unit()/50
            sprite.yv = (math.cos(math.rad((i-1) * 360/#sprites + (math.random()*10))) - math.random()*-10) * unit()/50
            sprite.zv = math.random()*6
        end
    end
    if wheelState == 1 or wheelState == 2 then
        selectedTaunt = nil
        for i, sprite in ipairs(sprites) do
            sprite.xv = (sprite.xv + ((w/2 + unit()*0.3 * math.sin((i-1) * 2*math.pi/#sprites)) - sprite.x) * 0.3) * 0.8
            sprite.yv = (sprite.yv + ((h/2 - unit()*0.3 * math.cos((i-1) * 2*math.pi/#sprites)) - sprite.y) * 0.3) * 0.8
            if not selectedTaunt
               and math.sqrt((sprite.x - djui_hud_get_mouse_x())^2 + (sprite.y - djui_hud_get_mouse_y())^2) <= tauntDist then
                selectedTaunt = i
                sprite.xv = sprite.xv + (djui_hud_get_mouse_x() - sprite.x) * 0.02
                sprite.yv = sprite.yv + (djui_hud_get_mouse_y() - sprite.y) * 0.02
                sprite.zv = sprite.zv + unit()*0.001
            end
            sprite.zv = (sprite.zv + (unit()/800 - sprite.z) * 0.9) * 0.5
        end
        for i, sprite in ipairs(sprites) do
            if math.sqrt((sprite.x - (w/2 + (m.controller.extStickX/128 * unit()*0.3)))^2 + (sprite.y - (h/2 - (m.controller.extStickY/128 * unit()*0.3)))^2) <= tauntDist then
                selectedTaunt = i
                sprite.zv = sprite.zv + unit()*0.001
            end
        end
    end
    if wheelState == 3 then
        for i, sprite in ipairs(sprites) do
            sprite.xv = sprite.xv +(math.sin(math.rad((i-1) * 360/#sprites + math.random()*10-5))) * unit()/10
            sprite.yv = sprite.yv -(math.cos(math.rad((i-1) * 360/#sprites + math.random()*10-5))) * unit()/10
            sprite.zv = sprite.zv + math.random()
        end
        if selectedTaunt then
            if m.action == ACT_IDLE or m.action == ACT_TAUNT then
                set_mario_action(m, ACT_TAUNT, selectedTaunt)
            end
        elseif m.action == ACT_TAUNT then
            set_mario_action(m, ACT_IDLE, 0)
        end
    end
    if wheelState == 3 or wheelState == 4 then
        for i, sprite in ipairs(sprites) do
            if sprite.z > 0 then
                sprite.xv = sprite.xv + (w/2 - sprite.x) * 0.05
                sprite.yv = sprite.yv + (h/2 - sprite.y) * 0.05
                sprite.zv = sprite.zv - sprite.z * 0.07
            end
        end
    end
    if wheelState ~= 0 then
        local done = true
        render_text_centered("Taunts", w/2, h*0.93, unit()/700)

        for i, sprite in ipairs(sprites) do
            if sprite.z + sprite.zv > 0 then
                done = false
                sprite.x = sprite.x + sprite.xv
                sprite.y = sprite.y + sprite.yv
                sprite.z = sprite.z + sprite.zv
                rendertext(sprite)
            end
        end
        if done then
            wheelState = 0
            save_loadout()
        end
    end
end

hook_event(HOOK_BEFORE_MARIO_UPDATE,checkwheel)
hook_event(HOOK_ON_HUD_RENDER,renderwheel)

function act_taunt(m)
    local taunt = tauntPool[m.actionArg]
    taunt.func(m)

    check_common_action_exits(m)
end
hook_mario_action(ACT_TAUNT, act_taunt)