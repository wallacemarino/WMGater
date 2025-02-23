-- WMGater
-- v1.2.0 @username
-- llllllll.co/t/wmgater
--
-- Trance gate effect with
-- triplet divisions, 32-step pattern
-- and synchronized delay
--
-- IMPORTANT: Set MONITOR level 
-- to -inf in LEVELS menu before 
-- using to prevent feedback
--
-- E1: select parameter
-- E2: adjust value
-- E3: select step
-- K2: toggle step
-- K3: start/stop

-- Ensure proper module loading order
local musicutil = require 'musicutil'
local lattice = require 'lattice'
local util = require 'util'

engine.name = 'WMGater'

-- State variables
local steps = 32
local current_step = 1
local playing = false
local selected_step = 1
local selected_param = 1
local pattern = {}
local my_lattice
local gating_pattern
local last_gate_state = 0

-- Musical division display values
local division_labels = {
  [2] = "2/1", [1] = "1", [3/4] = "1T",
  [1/2] = "1/2", [3/8] = "1/2T", [1/4] = "1/4",
  [3/16] = "1/4T", [1/8] = "1/8", [3/32] = "1/8T",
  [1/16] = "1/16", [3/64] = "1/16T", [1/32] = "1/32",
  [3/128] = "1/32T", [1/64] = "1/64", [1/128] = "1/128"
}

local function get_division_display(div)
  return division_labels[div] or string.format("1/%d", math.floor(1/div + 0.5))
end

function init()
  -- Initialize pattern
  for i=1,steps do
    pattern[i] = 0
  end
  
  params:add_separator("WMGater")
  
  params:add{
    type = "option",
    id = "gate_mode",
    name = "Gate Mode",
    options = {"Retrig", "Legato"},
    default = 1
  }
  
  params:add{
    type = "option",
    id = "division",
    name = "Step Division",
    options = {"2/1", "1", "1T", "1/2", "1/2T", "1/4", "1/4T", "1/8", "1/8T", 
              "1/16", "1/16T", "1/32", "1/32T", "1/64", "1/128"},
    default = 6,
    action = function(val)
      local divs = {2, 1, 3/4, 1/2, 3/8, 1/4, 3/16, 1/8, 3/32, 
                   1/16, 3/64, 1/32, 3/128, 1/64, 1/128}
      if gating_pattern then
        gating_pattern.division = divs[val]
      end
    end
  }
  
  params:add{
    type = "control",
    id = "level",
    name = "Output Level",
    controlspec = controlspec.new(0, 1.0, 'lin', 0, 1.0, ""),
    action = function(x) engine.level(x) end
  }
  
  params:add{
    type = "control",
    id = "attack",
    name = "Attack Time",
    controlspec = controlspec.new(0.0, 5.0, 'lin', 0.01, 0.01, 's'),
    action = function(x) engine.attack(x) end
  }
  
  params:add{
    type = "control",
    id = "release",
    name = "Release Time",
    controlspec = controlspec.new(0.0, 5.0, 'lin', 0.01, 0.01, 's'),
    action = function(x) engine.release(x) end
  }
  
  params:add_separator("Delay")
  
  params:add{
    type = "control",
    id = "delaytime",
    name = "Delay Time",
    controlspec = controlspec.new(0.00, 2.0, 'lin', 0.01, 0.2, 's'),
    action = function(x) engine.delaytime(x) end
  }
  
  params:add{
    type = "control",
    id = "delayfb",
    name = "Delay Feedback",
    controlspec = controlspec.new(0.0, 0.95, 'lin', 0.01, 0.3, ''),
    action = function(x) engine.delayfeedback(x) end
  }
  
  params:add{
    type = "control",
    id = "delaymix",
    name = "Delay Mix",
    controlspec = controlspec.new(0.0, 1.0, 'lin', 0.01, 0.2, ''),
    action = function(x) engine.delaymix(x) end
  }
  
  my_lattice = lattice:new{
    auto = true,
    ppqn = 96
  }
  
  gating_pattern = my_lattice:new_pattern{
    action = function(t)
      local new_gate_state = pattern[current_step]
      
      if params:get("gate_mode") == 1 then
        -- Retrig mode
        if new_gate_state ~= last_gate_state then
          engine.gate(new_gate_state)
          last_gate_state = new_gate_state
        end
      else
        -- Legato mode
        if new_gate_state == 1 then
          if last_gate_state == 0 then
            engine.gate(1)
          end
          last_gate_state = 1
        else
          if last_gate_state == 1 then
            engine.gate(0)
          end
          last_gate_state = 0
        end
      end
      
      current_step = current_step % steps + 1
      redraw()
    end,
    division = 1/4
  }
  
  params:bang()
end

function enc(n,d)
  if n == 1 then
    selected_param = util.clamp(selected_param + d, 1, 8)
  elseif n == 2 then
    if selected_param == 1 then
      params:delta("gate_mode", d)
    elseif selected_param == 2 then
      params:delta("division", d)
    elseif selected_param == 3 then
      params:delta("level", d)
    elseif selected_param == 4 then
      params:delta("attack", d)
    elseif selected_param == 5 then
      params:delta("release", d)
    elseif selected_param == 6 then
      params:delta("delaytime", d)
    elseif selected_param == 7 then
      params:delta("delayfb", d)
    elseif selected_param == 8 then
      params:delta("delaymix", d)
    end
  elseif n == 3 then
    selected_step = util.clamp(selected_step + d, 1, steps)
  end
  redraw()
end

function key(n,z)
  if z == 1 then
    if n == 2 then
      pattern[selected_step] = 1 - pattern[selected_step]
      redraw()
    elseif n == 3 then
      if not playing then
        current_step = 1
        last_gate_state = 0
        my_lattice:start()
        playing = true
      else
        my_lattice:stop()
        playing = false
        engine.gate(0)
        last_gate_state = 0
      end
      redraw()
    end
  end
end

function redraw()
  screen.clear()
  
  -- Draw parameters
  screen.move(0, 8)
  screen.level(selected_param == 1 and 15 or 3)
  screen.text("Mode: " .. params:string("gate_mode"))
  
  screen.move(64, 8)
  screen.level(selected_param == 2 and 15 or 3)
  screen.text("Div: " .. params:string("division"))
  
  screen.move(0, 16)
  screen.level(selected_param == 3 and 15 or 3)
  screen.text("Level: " .. string.format("%.2f", params:get("level")))
  
  screen.move(64, 16)
  screen.level(selected_param == 4 and 15 or 3)
  screen.text("Atk: " .. string.format("%.2f", params:get("attack")))
  
  screen.move(0, 24)
  screen.level(selected_param == 5 and 15 or 3)
  screen.text("Rel: " .. string.format("%.2f", params:get("release")))
  
  screen.move(64, 24)
  screen.level(selected_param == 6 and 15 or 3)
  screen.text("DTime: " .. string.format("%.2f", params:get("delaytime")))
  
  screen.move(0, 32)
  screen.level(selected_param == 7 and 15 or 3)
  screen.text("DFb: " .. string.format("%.2f", params:get("delayfb")))
  
  screen.move(64, 32)
  screen.level(selected_param == 8 and 15 or 3)
  screen.text("DMix: " .. string.format("%.2f", params:get("delaymix")))
  
  -- Draw sequence steps
  for i=1,32 do
    local row = i > 16 and 1 or 0
    local x = ((i-1)%16)*8
    local y = 44 + (row * 12)
    
    screen.level(i == current_step and playing and 15 or 3)
    screen.rect(x, y, 6, 6)
    if pattern[i] == 1 then
      screen.fill()
    else
      screen.stroke()
    end
    
    if i == selected_step then
      screen.level(15)
      screen.rect(x-1, y-1, 8, 8)
      screen.stroke()
    end
  end
  
  screen.update()
end

function cleanup()
  if my_lattice then
    my_lattice:stop()
  end
  engine.gate(0)
end