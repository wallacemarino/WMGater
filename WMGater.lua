-- WMGater
-- v2.7.0 @wallacemarino
--
-- Audio gate with chorus
-- and delay effects
--
-- E1: Select page (1-3)
-- E2: Navigate settings
-- E3: Adjust selected setting
--     (In step seq: select step)
-- K2: Toggle selected step
--     (in step sequencer)
-- K3: Start/Stop sequence
--
-- Regulating the monitor
-- input level is key to this
-- effect as it controls
-- the mix between the 
-- incoming and gated
-- signals. Enjoy

engine.name = 'WMGater'

local controlspec = require 'controlspec'
local formatters = require 'formatters'
local UI = require 'ui'
local musicutil = require 'musicutil'
local lattice = require 'lattice'
local util = require 'util'

-- State variables
local steps = 32
local current_step = 1
local playing = false
local selected_step = 1
local selected_param = 1
local pattern = {}
local my_lattice
local gating_pattern
local current_page = 1

-- Parameter formatters
local function format_percent(param)
    return string.format("%.1f%%", param:get() * 100)
end

local function format_hz(param)
    return string.format("%.2f Hz", param:get())
end

function init()
    -- Initialize pattern
    for i=1,steps do pattern[i] = 0 end
    
    params:add_separator("WMGater")
    
    params:add{
        type = "option",
        id = "division",
        name = "Division",
        options = {"2/1", "1/1", "1/2", "1/4", "1/8", "1/16", "1/32", "1/64", "1/128"},
        default = 4,
        action = function(val)
            local divs = {0.5, 1, 2, 4, 8, 16, 32, 64, 128}
            if gating_pattern then
                gating_pattern.division = 1/divs[val]
            end
        end
    }
    
    params:add{
        type = "control",
        id = "level",
        name = "Level",
        controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 1.0, ""),
        formatter = format_percent,
        action = function(x) engine.level(x) end
    }
    
    params:add{
        type = "control",
        id = "attack",
        name = "Attack",
        controlspec = controlspec.new(0.00, 5.00, 'lin', 0.01, 0.01, 's'),
        action = function(x) engine.attack(x) end
    }
    
    params:add{
        type = "control",
        id = "decay",
        name = "Decay",
        controlspec = controlspec.new(0.00, 3.00, 'lin', 0.01, 0.10, 's'),
        action = function(x) engine.decay(x) end
    }
    
    params:add{
        type = "control",
        id = "sustain",
        name = "Sustain",
        controlspec = controlspec.new(0, 1.0, 'lin', 0.01, 0.5, ""),
        formatter = format_percent,
        action = function(x) engine.sustain(x) end
    }
    
    params:add{
        type = "control",
        id = "release",
        name = "Release",
        controlspec = controlspec.new(0.0, 5.0, 'lin', 0.01, 0.01, 's'),
        action = function(x) engine.release(x) end
    }
    
    params:add_separator("Wobbler")
    
    params:add{
        type = "control",
        id = "wobbleRate",
        name = "Rate",
        controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0, "Hz"),
        formatter = format_hz,
        action = function(x) engine.wobbleRate(x) end
    }
    
    params:add{
        type = "control",
        id = "wobbleDepth",
        name = "Depth",
        controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.5, ""),
        formatter = format_percent,
        action = function(x) engine.wobbleDepth(x) end
    }
    
    params:add{
        type = "control",
        id = "wobbleMix",
        name = "Mix",
        controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0, ""),
        formatter = format_percent,
        action = function(x) engine.wobbleMix(x) end
    }
    
    params:add_separator("Delay")
    
    params:add{
        type = "option",
        id = "delayMode",
        name = "Mode",
        options = {"Mono", "Ping-pong"},
        default = 1,
        action = function(x) engine.delayMode(x-1) end
    }
    
    params:add{
      type = "control",
      id = "delaytime",
      name = "Time",
      controlspec = controlspec.new(0.0, 2.0, 'lin', 0.01, 0.2, "s"),
      action = function(x) engine.delaytime(x) end
    }
    
    params:add{
        type = "control",
        id = "delayfeedback",
        name = "Feedback",
        controlspec = controlspec.new(0.0, 0.95, 'lin', 0.01, 0.3, ""),
        formatter = format_percent,
        action = function(x) engine.delayfeedback(x) end
    }
    
    params:add{
        type = "control",
        id = "delaymix",
        name = "Mix",
        controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.0, ""),
        formatter = format_percent,
        action = function(x) engine.delaymix(x) end
    }
    
    my_lattice = lattice:new{
        auto = true,
        ppqn = 96
    }
    
    gating_pattern = my_lattice:new_pattern{
        action = function(t)
            engine.gate(pattern[current_step])
            current_step = current_step % steps + 1
            redraw()
        end,
        division = 1/4
    }
    
    params:bang()
    redraw()
end

function get_current_param_id()
    if current_page == 1 then
        local params = {"division", "level", "attack", "decay", "sustain", "release"}
        return params[selected_param]
    elseif current_page == 2 then
        local params = {"wobbleRate", "wobbleDepth", "wobbleMix"}
        return params[selected_param]
    else
        local params = {"delayMode", "delaytime", "delayfeedback", "delaymix"}
        return params[selected_param]
    end
end

function enc(n,d)
    if n == 1 then
        current_page = util.clamp(current_page + d, 1, 3)
        selected_param = 1
    elseif n == 2 then
        local max_params = current_page == 1 and 7 or
                          current_page == 2 and 3 or 4
        selected_param = util.clamp(selected_param + d, 1, max_params)
    elseif n == 3 then
        if current_page == 1 and selected_param == 7 then
            selected_step = util.clamp(selected_step + d, 1, steps)
        else
            local param_id = get_current_param_id()
            if param_id then params:delta(param_id, d) end
        end
    end
    redraw()
end

function key(n,z)
    if n == 2 and z == 1 then
        if current_page == 1 and selected_param == 7 then
            pattern[selected_step] = 1 - pattern[selected_step]
        end
    elseif n == 3 and z == 1 then
        if not playing then
            current_step = 1
            my_lattice:start()
        else
            my_lattice:stop()
            engine.gate(0)
        end
        playing = not playing
    end
    redraw()
end

function redraw()
    screen.clear()
    screen.aa(1)
    
    screen.level(15)
    screen.move(2, 8)
    screen.text(current_page == 1 and "GATE 1/3" or 
               current_page == 2 and "CHORUS 2/3" or "DELAY 3/3")
    
    if current_page == 1 then
        local col1 = {"Division", "Level", "Attack"}
        local col2 = {"Decay", "Sustain", "Release"}
        local col1_params = {"division", "level", "attack"}
        local col2_params = {"decay", "sustain", "release"}
        
        for i, name in ipairs(col1) do
            screen.move(2, 16 + i * 8)
            screen.level(selected_param == i and 15 or 4)
            screen.text(name .. ": " .. params:string(col1_params[i]))
        end
        
        for i, name in ipairs(col2) do
            screen.move(64, 16 + i * 8)
            screen.level(selected_param == i + 3 and 15 or 4)
            screen.text(name .. ": " .. params:string(col2_params[i]))
        end
        
        screen.level(selected_param == 7 and 15 or 4)
        for i=1,32 do
            local x = ((i-1)%16)*8
            local y = 44 + (math.floor((i-1)/16) * 12)
            
            screen.level(i == current_step and playing and 15 or 3)
            screen.rect(x, y, 6, 6)
            if pattern[i] == 1 then
                screen.fill()
            else
                screen.stroke()
            end
            
            if i == selected_step and selected_param == 7 then
                screen.level(15)
                screen.rect(x-1, y-1, 8, 8)
                screen.stroke()
            end
        end
    else
        local param_names, param_ids
        
        if current_page == 2 then
            param_names = {"Rate", "Depth", "Mix"}
            param_ids = {"wobbleRate", "wobbleDepth", "wobbleMix"}
        else
            param_names = {"Mode", "Time", "Feedback", "Mix"}
            param_ids = {"delayMode", "delaytime", "delayfeedback", "delaymix"}
        end
        
        for i, name in ipairs(param_names) do
            screen.move(2, 20 + i * 10)
            screen.level(selected_param == i and 15 or 4)
            screen.text(name .. ": " .. params:string(param_ids[i]))
        end
    end
    
    screen.update()
end

function cleanup()
    if my_lattice then my_lattice:stop() end
    engine.gate(0)
end
