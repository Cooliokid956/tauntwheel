-- name: Taunt Wheel (WIP)
-- description: A customizable taunt wheel that supports the addition of more taunts.

_G.ACT_TAUNT = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_STATIONARY | ACT_FLAG_IDLE)

--- @class Taunt
--- @field public name string
--- @field public func function

local wheelState = 0
local selectedTaunt = 0

local TWApi -- needs work.,

-- Helpers
---@param m MarioState
---@param anim CharacterAnimID|string
---@param loopEnd integer
local function taunt_looping_anim(m, anim, loopEnd)
    if type(anim) == "string" then
       smlua_anim_util_set_animation(m.marioObj, anim)
       anim = 0
       djui_chat_message_create("custom anim")
    end
    set_character_animation(m, anim)
    if loopEnd and is_anim_past_frame(m, loopEnd) ~= 0 or is_anim_past_end(m) ~= 0 then
        set_anim_to_frame(m, 0)
    end
end
---@param anim CharacterAnimID|string
---@param loopEnd integer
local function LOOPING_ANIM(anim, loopEnd)
    return function (m) taunt_looping_anim(m, anim, loopEnd) end
end

---@param m MarioState
---@param anim CharacterAnimID|string
local function taunt_anim(m, anim)
    if type(anim) == "string" then
       smlua_anim_util_set_animation(m.marioObj, anim)
       anim = 0
       djui_chat_message_create("custom anim")
    end
    set_character_animation(m, anim)
end
---@param anim CharacterAnimID|string
local function ANIM(anim)
    return function (m) taunt_anim(m, anim) end
end

local tauntPool = {}
---@param name string
---@param func function
---@return Taunt
local function register_taunt(name, func)
    table.insert(tauntPool, {
        name = name,
        func = func
    })
    return tauntPool[-1]
end
TWApi.register_taunt = register_taunt

---@param m MarioState
---@return Taunt
local function get_current_taunt(m)
    return m.action == ACT_TAUNT and tauntPool[m.actionArg]
end
TWApi.register_taunt = register_taunt

_G.TWApi = TWApi

-- Built-in taunts
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
------------------

function unit()
    return math.min(djui_hud_get_screen_width(),djui_hud_get_screen_height())
end

local NONE = 0

local sprites = {
--  1                    2-7
--  label,               physics,
    {"Shock",            0,0,0,0,0,0},
    {"T-Pose",           0,0,0,0,0,0},
    {"Wave",             0,0,0,0,0,0},
    {"Star Dance",       0,0,0,0,0,0},
    {"Water Star Dance", 0,0,0,0,0,0},
    {"Death",            0,0,0,0,0,0},
    {"Stuck",            0,0,0,0,0,0},
    {"Death 2",          0,0,0,0,0,0}
}

-- 2: x position
-- 3: y position
-- 4: z position
-- 5: x velocity
-- 6: y velocity
-- 7: z velocity

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
    djui_hud_print_text(t, x - djui_hud_measure_text(t)* z/2,  y-32* z,  z)
end
function render_text_centered_interpolated(t, px, py, pz, x, y, z)
    djui_hud_print_text_interpolated(t, px - djui_hud_measure_text(t)*pz/2, py-32*pz, pz,
                                         x - djui_hud_measure_text(t)* z/2,  y-32* z,  z)
end

function rendertext(s)
    render_text_centered_interpolated(s[1], s[2]-s[5], s[3]-s[6], s[4]-s[7],
                                            s[2],      s[3],      s[4]     )
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
            sprite[2] = w/2
            sprite[3] = h/2
            sprite[4] = 0.00000001
            sprite[5] = (math.sin(math.rad((i-1)*360/#sprites+(math.random()*10)))-math.random()*10)*unit()/50
            sprite[6] = (math.cos(math.rad((i-1)*360/#sprites+(math.random()*10)))-math.random()*-10)*unit()/50
            sprite[7] = math.random()*6
        end
    end
    if wheelState == 1 or wheelState == 2 then
        selectedTaunt = NONE
        for i, sprite in ipairs(sprites) do
            sprite[5] = (sprite[5] + ((w/2+unit()*0.3*math.sin((i-1)*2*math.pi/#sprites))-sprite[2])*0.3)*0.8
            sprite[6] = (sprite[6] + ((h/2-unit()*0.3*math.cos((i-1)*2*math.pi/#sprites))-sprite[3])*0.3)*0.8
            if math.sqrt((sprite[2]-djui_hud_get_mouse_x())^2+(sprite[3]-djui_hud_get_mouse_y())^2) <= tauntDist and selectedTaunt == NONE then
                selectedTaunt = i
                sprite[5] = (sprite[5] + (djui_hud_get_mouse_x()-sprite[2])*0.02)
                sprite[6] = (sprite[6] + (djui_hud_get_mouse_y()-sprite[3])*0.02)
                sprite[7] = sprite[7] + unit()*0.001
            end
            sprite[7] = (sprite[7] + ((unit()/800)-(sprite[4]))*0.9)*0.5
        end
        for i, sprite in ipairs(sprites) do
            if math.sqrt((sprite[2]-(w/2+(m.controller.extStickX/128*unit()*0.3)))^2+(sprite[3]-(h/2-(m.controller.extStickY/128*unit()*0.3)))^2) <= tauntDist then
                selectedTaunt = i
                sprite[7] = sprite[7] + unit()*0.001
            end
        end
    end
    if wheelState == 3 then
        for i, sprite in ipairs(sprites) do
            sprite[5] = sprite[5] +(math.sin(math.rad((i-1)*360/#sprites+(math.random()*10)-5)))*unit()/10
            sprite[6] = sprite[6] -(math.cos(math.rad((i-1)*360/#sprites+(math.random()*10)-5)))*unit()/10
            sprite[7] = sprite[7] + math.random()
        end
        if selectedTaunt ~= NONE then
            if m.action == ACT_IDLE or m.action == ACT_TAUNT then
                set_mario_action(m, ACT_TAUNT, selectedTaunt)
            end
        elseif m.action == ACT_TAUNT then
            set_mario_action(m, ACT_IDLE, 0)
        end
    end
    if wheelState == 3 or wheelState == 4 then
        for i, sprite in ipairs(sprites) do
            if sprite[4] > 0 then
                sprite[5] = sprite[5] + (w/2-sprite[2])*0.05
                sprite[6] = sprite[6] + (h/2-sprite[3])*0.05
                sprite[7] = sprite[7] - sprite[4]*0.07
            end
        end
    end
    if wheelState ~= 0 then
        local done = true
        render_text_centered("Taunts", w/2, h*0.93, unit()/700)

        for i, sprite in ipairs(sprites) do
            if sprite[4]+sprite[7] > 0 then
                done = false
                sprite[2] = sprite[2] + sprite[5]
                sprite[3] = sprite[3] + sprite[6]
                sprite[4] = sprite[4] + sprite[7]
                rendertext(sprite)
            end
        end
        if done then
            wheelState = 0
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