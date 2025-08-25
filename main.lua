-- name: Taunt Wheel
-- description: A customizable taunt wheel that supports the addition of more taunts.

--[[
    TODO:
    taunt list

    DONE:
    get sprite space rendering working
      - swap space
      - queued rendering
      - temp queue
    network current taunt
      - network_send_bytestring(false, "tauntname") if it changes
      - get_current_taunt
    rework states
  ]]

_G.ACT_TAUNT = allocate_mario_action(ACT_GROUP_STATIONARY | ACT_FLAG_STATIONARY | ACT_FLAG_IDLE)

--- @param string string
function mod_storage_make_valid(string)
    local s = ''
    for i = 1, #string do
        local c = string:sub(i,i)
        if c:byte() >= 32 then
            s = s .. c
        end
    end
    return s
end

--- @class Taunt
--- @field public name      string
--- @field public saveName  string
--- @field public func      function

--- @param name string
--- @param func function
--- @return Taunt
local function Taunt(name, func)
    return {
        name = name,
        saveName = mod_storage_make_valid(name),
        func = func
    }
end

--- @class SpriteSpace
--- @field public x number
--- @field public y number
--- @field public xv number
--- @field public yv number
--- @field public sprites Sprite[]

--- @return SpriteSpace
local function SpriteSpace()
    return {
        x  = 0, y  = 0,
        xv = 0, yv = 0,
        sprites = {}
    }
end

--- @param sprite Sprite
local function get_sprite_global_pos(sprite)
    local spaceX = sprite.space and sprite.space.x or 0
    local spaceY = sprite.space and sprite.space.y or 0
    return sprite.x + spaceX, sprite.y + spaceY
end

--- @param sprite Sprite
--- @param space SpriteSpace
local function get_sprite_pos_in_space(sprite, space)
    local spaceX = sprite.space and sprite.space.x or 0
    local spaceY = sprite.space and sprite.space.y or 0
    return sprite.x + spaceX - space.x, sprite.y + spaceY - space.y
end

--- @param sprite Sprite
--- @param space SpriteSpace
local function transfer_to_sprite_space(sprite, space)
    local prevSpace = sprite.space
    if prevSpace then
        prevSpace = prevSpace.sprites
        for i, same in ipairs(prevSpace) do
            if sprite == same then
                table.remove(prevSpace, i)
                sprite.space = nil
            end
        end
    end
    sprite.x, sprite.y = get_sprite_pos_in_space(sprite, space)
    table.insert(space.sprites, sprite)
    sprite.space = space
end

--- @class Sprite
--- @field public space SpriteSpace
--- @field public label string
--- @field public x  number
--- @field public y  number
--- @field public z  number
--- @field public xv number
--- @field public yv number
--- @field public zv number

--- @param label string|TextureInfo
--- @param x number?
--- @param y number?
--- @param z number?
--- @return Sprite
local function Sprite(label, x, y, z)
    return {
        label = label,
        x  = x or 0, y  = y or 0, z  = z or 0,
        xv =      0, yv =      0, zv =      0
    }
end

local spriteQueue = {}

--- @param space SpriteSpace
local function queue_sprite_space(space)
    for _, sprite in ipairs(space.sprites) do
        table.insert(spriteQueue, sprite)
    end
end

--- @param sprite Sprite
local function queue_sprite(sprite)
    table.insert(spriteQueue, sprite)
end

local function render_text_centered(t, x, y, z)
    djui_hud_print_text(t, x - djui_hud_measure_text(t) * z/2,  y - 32*z, z)
end

local function render_text_centered_interpolated(t, px, py, pz, x, y, z)
    djui_hud_print_text_interpolated(t, px - djui_hud_measure_text(t) * pz/2, py - 32*pz, pz,
                                         x - djui_hud_measure_text(t) *  z/2,  y - 32* z,  z)
end

--- @param s Sprite
function render_sprite_label(s)
    if not s then return end
    render_text_centered_interpolated(s.label, s.x - s.xv, s.y - s.yv, s.z - s.zv,
                                               s.x,        s.y,        s.z       )
end

local function render_sprite(sprite)
    local space = sprite.space
    if space then sprite.x, sprite.y = sprite.x + space.x, sprite.y + space.y end
    local t = type(sprite.label)
    if t == "string" then
        render_sprite_label(sprite)
    -- elseif t == "userdata" then
    --     render_sprite_texture(sprite)
    end
    if space then sprite.x, sprite.y = sprite.x - space.x, sprite.y - space.y end
end

local function render_sprite_queue()
    for i, sprite in ipairs(spriteQueue) do
        render_sprite(sprite)
    end
    spriteQueue = {}
end

local STATE_IDLE  = 0
local STATE_OPEN  = 1
local STATE_CLOSE = 2

--- @class MenuState
--- @field public inited boolean
--- @field public state integer
--- @field public states MenuSubState[]
--- @field public openCond function
--- @field public closeCond function

--- @param open MenuSubState
--- @param close MenuSubState
--- @param openCond function
--- @param closeCond function
--- @return MenuState
local function MenuState(open, close, openCond, closeCond)
    return {
        state = 0,
        states = { open, close },
        openCond = openCond,
        closeCond = closeCond
    }
end

--- @param ms MenuState
local function process_menu_state(ms)
    if ms.state == STATE_IDLE and ms.openCond() then
        ms.state = STATE_OPEN; ms.inited = false
    elseif ms.state == STATE_OPEN and ms.closeCond() then
        ms.state = STATE_CLOSE; ms.inited = false
    end

    local state = ms.states[ms.state]
    if state then
        if not ms.inited then state.init(); ms.inited = true end
        state.loop()
    end
end

--- @class MenuSubState
--- @field public init function
--- @field public loop function

--- @param init function
--- @param loop function
--- @return MenuSubState
local function MenuSubState(init, loop)
    return {
        init = init,
        loop = loop
    }
end

local selectedTaunt
local playerTaunts = {}

local TWApi = {} -- needs work.,
local TWHelpers = {}

-- -------- Helpers -------- --

--- @param m MarioState
--- @param anim CharacterAnimID|string
local function taunt_anim(m, anim)
    local isString = type(anim) == "string"
    set_character_animation(m, isString and 0 or anim)
    if isString then
       smlua_anim_util_set_animation(m.marioObj, anim)
    end
end

--- @param m MarioState
--- @param anim CharacterAnimID|string
--- @param loopEnd integer?
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

--- @param anim CharacterAnimID|string
local function ANIM(anim)
    return function (m) taunt_anim(m, anim) end
end
TWHelpers.ANIM = ANIM

--- @param anim CharacterAnimID|string
--- @param loopEnd integer?
local function LOOPING_ANIM(anim, loopEnd)
    return function (m) taunt_looping_anim(m, anim, loopEnd) end
end
TWHelpers.LOOPING_ANIM = LOOPING_ANIM

-- Extras --
local function do_extras(...)
    local extras = {...}
    return function (m)
        for _, extra in ipairs(extras) do
            extra(m)
        end
    end
end

--- @param anim CharacterAnimID|string
--- @param ... function
local function ANIM_EXTRA(anim, ...)
    local extra = do_extras(...)
    return function (m) taunt_anim(m, anim); extra(m) end
end
TWHelpers.ANIM_EXTRA = ANIM_EXTRA

--- @param anim CharacterAnimID|string
--- @param loopEnd integer?
--- @param ... function
local function LOOPING_ANIM_EXTRA(anim, loopEnd, ...)
    local extra = do_extras(...)
    return function (m) taunt_looping_anim(m, anim, loopEnd); extra(m) end
end
TWHelpers.LOOPING_ANIM_EXTRA = LOOPING_ANIM_EXTRA

local function HAND_STATE(state) return function (m) m.marioBodyState.handState = state end end
local function  EYE_STATE(state) return function (m) m.marioBodyState. eyeState = state end end
TWHelpers.HAND_STATE = HAND_STATE
TWHelpers. EYE_STATE =  EYE_STATE

_G.TWHelpers = TWHelpers

-- -------- API -------- --
local tauntPool = {}     --- @type Taunt[]
local tauntPoolSave = {} --- @type Taunt[]

--- @param name string
--- @param func function
--- @return Taunt
local function register_taunt(name, func)
    if tauntPool[name] then
        log_to_console("A taunt named'"..name.."' already exists")
        return tauntPool[name]
    end
    local taunt = Taunt(name, func)
    tauntPool[name] = taunt
    tauntPoolSave[taunt.saveName] = taunt
    return taunt
end
TWApi.register_taunt = register_taunt

--- @param m MarioState
--- @return Taunt|false?
local function get_current_taunt(m)
    return m.action == ACT_TAUNT and playerTaunts[m.playerIndex]
end
TWApi.get_current_taunt = get_current_taunt

--- @return integer
local function get_taunt_count()
    local c = 0
    for _, _ in pairs(tauntPool) do
        c = c + 1
    end
    return c
end
TWApi.get_taunt_count = get_taunt_count

--- @param name string
--- @return Taunt?
local function get_taunt_from_name(name)
    return tauntPool[name]
end
TWApi.get_taunt_from_name = get_taunt_from_name

--- @param saveName string
--- @return Taunt?
local function get_taunt_from_save_name(saveName)
    return tauntPoolSave[saveName]
end
TWApi.get_taunt_from_save_name = get_taunt_from_save_name

_G.TWApi = TWApi

-- -------- Built-in taunts-------- --
local function ANIMFRAME(o) return o.header.gfx.animInfo.animFrame end

--- @param m MarioState
local function star_dance_update(m)
    local taunt = get_current_taunt(m)
    if not taunt then return end
    local frame = ANIMFRAME(m.marioObj)
    local bodyState = m.marioBodyState
    if frame == 1 then
        spawn_non_sync_object(id_bhvCelebrationStar, E_MODEL_STAR, 0, 0, 0, function (o)
            o.parentObj = m.marioObj
        end)
    elseif frame == 42 then
        play_character_sound(m, CHAR_SOUND_HERE_WE_GO)
    end

    if (taunt.name ==       "Star Dance" and frame > 38)
    or (taunt.name == "Water Star Dance" and frame > 61) then
        bodyState.handState = MARIO_HAND_PEACE_SIGN
    end
end

local function death_update(m)
    m.marioBodyState.eyeState = MARIO_EYES_DEAD

    play_character_sound_if_no_flag(m, CHAR_SOUND_DYING, MARIO_ACTION_SOUND_PLAYED)
    if ANIMFRAME(m.marioObj) == 77 then
        play_mario_landing_sound(m, SOUND_ACTION_TERRAIN_BODY_HIT_GROUND)
    end
end

register_taunt("Shock", ANIM_EXTRA(CHAR_ANIM_SHOCKED,
    function (m)
        m.marioBodyState.eyeState = math.random(8)
        if m.marioObj.oTimer % 2 == 0 then
            m.flags = m.flags | MARIO_METAL_SHOCK
        else
            m.flags = m.flags & ~MARIO_METAL_SHOCK
        end

        play_sound(SOUND_MOVING_SHOCKED, m.marioObj.header.gfx.cameraToObject)
    end
))
register_taunt("T-Pose", ANIM_EXTRA(CHAR_ANIM_TWIRL, HAND_STATE(MARIO_HAND_OPEN)))
register_taunt("Wave", ANIM_EXTRA(CHAR_ANIM_CREDITS_WAVING, HAND_STATE(MARIO_HAND_RIGHT_OPEN)))
register_taunt("Star Dance", ANIM_EXTRA(CHAR_ANIM_STAR_DANCE, star_dance_update))
register_taunt("Water Star Dance", ANIM_EXTRA(CHAR_ANIM_WATER_STAR_DANCE, star_dance_update))
register_taunt("Death", ANIM_EXTRA(CHAR_ANIM_DYING_FALL_OVER, death_update))
register_taunt("Stuck", LOOPING_ANIM_EXTRA(CHAR_ANIM_BOTTOM_STUCK_IN_GROUND, 127,
    function (m)
        if ANIMFRAME(m.marioObj) > 88 then m.marioBodyState.eyeState = MARIO_EYES_CLOSED end
    end
))
register_taunt("Death 2", ANIM_EXTRA(CHAR_ANIM_ELECTROCUTION, death_update))

--------------------------------------------------

local function unit()
    return math.min(djui_hud_get_screen_width(),djui_hud_get_screen_height())
end

--- @type Taunt[]
local loadout = {}
local loadoutLen = mod_storage_load_number("loadout_len")

-- -------- Loadout Storage -------- --
local function save_loadout()
    mod_storage_save_number("loadout_len", loadoutLen)
    for i = 1, loadoutLen do
        log_to_console(loadout[i].saveName)
        mod_storage_save("slot"..i, loadout[i].saveName)
    end
end

hook_event(HOOK_ON_MODS_LOADED, function ()
    if loadoutLen ~= 0 then
        -- attempt loading
        for i = 1, loadoutLen do
            loadout[i] = get_taunt_from_save_name(mod_storage_load("slot"..i))
        end
    else
        -- load defaults
        loadoutLen = 8
        for i, taunt in pairs(tauntPool) do
            print("taunt "..(#loadout+1)..": "..taunt.name)
            table.insert(loadout, taunt)
        end
        save_loadout()
    end
end)

local c = gControllers[0] -- Find a better place
local wheelBind = U_JPAD
local listBind = R_JPAD
local wheelMenu
local listMenu

local wheel = SpriteSpace()
wheelMenu = MenuState(
    MenuSubState(
        function ()
            for i, taunt in ipairs(loadout) do
                local sprite = Sprite(taunt.name)
                transfer_to_sprite_space(sprite, wheel)
                sprite.x  = 0
                sprite.y  = 0
                sprite.z  = 0.00000001
                sprite.xv = (math.sin(math.rad((i-1) * 360/#wheel.sprites + (math.random()*10))) - math.random()* 10) * unit()/50
                sprite.yv = (math.cos(math.rad((i-1) * 360/#wheel.sprites + (math.random()*10))) - math.random()*-10) * unit()/50
                sprite.zv = math.random()*6
            end
        end,
        function ()
            local tauntDist = unit()/7
            selectedTaunt = nil
            for i, sprite in ipairs(wheel.sprites) do
                sprite.xv = (sprite.xv + (( unit()*0.3 * math.sin((i-1) * 2*math.pi/#wheel.sprites)) - sprite.x) * 0.3) * 0.8
                sprite.yv = (sprite.yv + ((-unit()*0.3 * math.cos((i-1) * 2*math.pi/#wheel.sprites)) - sprite.y) * 0.3) * 0.8
                if not selectedTaunt
                and math.hypot((wheel.x + sprite.x - djui_hud_get_mouse_x()), (wheel.y + sprite.y - djui_hud_get_mouse_y())) <= tauntDist then
                    selectedTaunt = get_taunt_from_name(sprite.label)
                    sprite.xv = sprite.xv + (djui_hud_get_mouse_x() - sprite.x - wheel.x) * 0.02
                    sprite.yv = sprite.yv + (djui_hud_get_mouse_y() - sprite.y - wheel.y) * 0.02
                    sprite.zv = sprite.zv + unit()*0.001
                end
                sprite.zv = (sprite.zv + (unit()/800 - sprite.z) * 0.9) * 0.5
            end
            for i, sprite in ipairs(wheel.sprites) do
                if math.hypot((sprite.x - (wheel.x + (c.extStickX/128 * unit()*0.3))), (sprite.y - (wheel.y - (c.extStickY/128 * unit()*0.3)))) <= tauntDist then
                    selectedTaunt = get_taunt_from_name(sprite.label)
                    sprite.zv = sprite.zv + unit()*0.001
                end
            end
        end
    ),
    MenuSubState(
        function ()
            local m = gMarioStates[0]
            for i, sprite in ipairs(wheel.sprites) do
                sprite.xv = sprite.xv +(math.sin(math.rad((i-1) * 360/#wheel.sprites + math.random()*10-5))) * unit()/10
                sprite.yv = sprite.yv -(math.cos(math.rad((i-1) * 360/#wheel.sprites + math.random()*10-5))) * unit()/10
                sprite.zv = sprite.zv + math.random()
            end
            if selectedTaunt   then
                if m.action == ACT_IDLE
                or m.action == ACT_TAUNT then
                    select_taunt(selectedTaunt)
                    set_mario_action(m, ACT_TAUNT, 0)
                end
            elseif m.action == ACT_TAUNT then
                set_mario_action(m, ACT_IDLE, 0)
            end
        end,
        function ()
            for _, sprite in ipairs(wheel.sprites) do
                if sprite.z > 0 then
                    sprite.xv,                   sprite.yv,                   sprite.zv =
                    sprite.xv - sprite.x * 0.05, sprite.yv - sprite.y * 0.05, sprite.zv - sprite.z * 0.07
                end
            end
        end
    ),
    function ()
        return c.buttonDown & wheelBind == wheelBind and gMarioStates[0].action & ACT_FLAG_IDLE ~= 0
    end,
    function ()
        return ((c.buttonDown & wheelBind == 0) or gMarioStates[0].action & ACT_FLAG_IDLE == 0) and listMenu.state ~= STATE_OPEN
    end
)


local list = SpriteSpace()
listMenu = MenuState(
    MenuSubState(
        function ()
            
        end,
        function ()
            
        end
    ),
    MenuSubState(
        function ()
            
        end,
        function ()
            
        end
    ),
    function ()
        return c.buttonPressed & listBind ~= 0 and wheelMenu.state == STATE_OPEN
    end,
    function ()
        return c.buttonPressed & listBind ~= 0
    end
)
-- List

local function render_list()
    process_menu_state(listMenu)
    if listMenu.state == STATE_CLOSE then
        listMenu.state = STATE_IDLE
    end
end

-- Wheel
local function render_wheel()
    djui_hud_set_resolution(RESOLUTION_DJUI)
    djui_hud_set_font(FONT_MENU)
    djui_hud_set_color(255, 255, 255, 255)
    local w = djui_hud_get_screen_width()
    local h = djui_hud_get_screen_height()

    local cx = (listMenu.state == STATE_OPEN) and (w - h/2) or w/2
    local cy = h/2
    wheel.x, wheel.y = cx, cy

    process_menu_state(wheelMenu)
    if wheelMenu.state ~= STATE_IDLE then
        local done = true
        render_text_centered("Taunts", cx, h*0.93, unit()/700)

        for _, sprite in ipairs(wheel.sprites) do
            if sprite.z + sprite.zv > 0 then
                done = false
                sprite.x,             sprite.y,             sprite.z =
                sprite.x + sprite.xv, sprite.y + sprite.yv, sprite.z + sprite.zv
                queue_sprite(sprite)
            end
        end
        if done then
            wheelMenu.state = STATE_IDLE
            wheel.sprites = {}
        end
    end
end

hook_event(HOOK_ON_HUD_RENDER, function ()
    render_list()
    render_wheel()
    render_sprite_queue()
end)

function act_taunt(m)
    local taunt = get_current_taunt(m)
    if taunt then taunt.func(m) end

    check_common_action_exits(m)
end
hook_mario_action(ACT_TAUNT, act_taunt)

local globalIndex = gNetworkPlayers[0].globalIndex
function select_taunt(taunt)
    if playerTaunts[0] == taunt then return end
    playerTaunts[0] = taunt

    local i = globalIndex
    taunt = taunt and taunt.name or ""
    network_send_bytestring(false,
        string.pack("<B", i)
     .. string.pack("z", taunt)
    )
end

hook_event(HOOK_ON_PACKET_BYTESTRING_RECEIVE, function (str)
    local offset = 1

    local function unpack(fmt)
        local value
        value, offset = string.unpack(fmt, str, offset)
        return value
    end

    local i = network_local_index_from_global(unpack("<B"))
    local taunt = unpack("z")

    playerTaunts[i] = get_taunt_from_name(taunt)
end)