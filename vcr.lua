-- vcr
--
-- voltage collection
-- recall
--
-- crow + grid required
--

local g = grid.connect()
local pt = require 'pattern_time'

local number_of_voltage_sets = 8
local g_alt = false

local names = {
  "one",
  "two",
  "three",
  "four",
  "five",
  "six",
  "seven",
  "eight"
}

local slew_styles = {}
for i = 1, 8 do
  slew_styles[i] = 1
end

local slew_style_names = {
  'linear',
  'sine',
  'logarithmic',
  'exponential',
  'now',
  'wait',
  'over',
  'under',
  'rebound'
}

-- for indexing shit ----------
local current_voltage_set = 1

-- tables for our voltage sets and slew times ----------
local voltages = {}
local slews = {}
for i = 1, number_of_voltage_sets do
  voltages[i] = {0, 0, 0, 0}
  slews[i] = 0
end

-- screen/grid redraw flags ----------
local screen_dirty = true
local grid_dirty = true
local start_time = util.time()
local splash_index = 0
local blink = false

-- for grid "scope" ----------
local grid_scope = {0,0,0,0}


function outs(i,v)
  grid_scope[i] = v
end

-- helpers ---------
local function set_single_voltage(v_set, id, volts)
  -- you can use this from the maiden repl
  -- to set precise voltages... maybe to
  -- use vcr as a weird chord machine...
  voltages[v_set][id] = volts
end


local function send_slew_time(id, s_time)
  -- set crow output slew time
  slews[id] = s_time
  for i = 1, 4 do
    crow.output[i].slew = slews[id]
  end
end


local function send_slew_style(style)
  for i = 1, 4 do
    crow.output[i].shape = slew_style_names[style]
  end
end


local function send_collection(collection)
  current_voltage_set = collection
  send_slew_time(collection, slews[collection])
  send_slew_style(params:get(collection .. "slew_style"))
  for i = 1, 4 do
    crow.output[i].volts = voltages[collection][i]
  end
  screen_dirty = true
end


local function send_single_voltage(collection, id)
  -- id is the output number
  crow.output[id].volts = voltages[collection][id]
end

-- for pattern recorder
local function parse_pattern(data)
  local v = data.value
  if v > 0 then
    send_collection(v)
  end
end

-- script init ----------
function init()
  print("howdy! let's get vcr-ing")

  press_pattern = pt.new()
  press_pattern.process = parse_pattern

  params:add_separator("voltage sets")
  -- params for keeping our voltage sets and slews updated
  for i = 1, number_of_voltage_sets  do
    params:add_group("volts_" .. i, "volts " .. i, 6)
    params:add_control(i .. "volts1", "voltage 1", controlspec.new(-5.00, 10.00, "lin", 0.01, 0))
    params:set_action(i .. "volts1", function(v) voltages[i][1] = v end)

    params:add_control(i .. "volts2", "voltage 2", controlspec.new(-5.00, 10.00, "lin", 0.01, 0))
    params:set_action(i .. "volts2", function(v) voltages[i][2] = v end)

    params:add_control(i .. "volts3", "voltage 3", controlspec.new(-5.00, 10.00, "lin", 0.01, 0))
    params:set_action(i .. "volts3", function(v) voltages[i][3] = v end)

    params:add_control(i .. "volts4", "voltage 4", controlspec.new(-5.00, 10.00, "lin", 0.01, 0))
    params:set_action(i .. "volts4", function(v) voltages[i][4] = v end)
    
    params:add_control(i .. "slew", "slew", controlspec.new(0, 10.0, "lin", 0.1, 2))
    params:set_action(i .. "slew", function(v) slews[i] = v end)
    
    params:add_option(i .. "slew_style", "slew style", slew_style_names, 1)
    params:set_action(i .. "slew_style", function(v) slew_styles[i] = v end)
  end
  params:bang()
  send_collection(1)
  -- blink metro ----------
  blink_metro = metro.init()
  blink_metro.time = 1/3
  blink_metro.event = function() blink = not blink end
  blink_metro:start()

  -- for grid "scope"
  for i = 1,4 do
    crow.output[i].receive = function(v) outs(i,v) end
  end

  crow_output_volts_query = metro.init()
  crow_output_volts_query.time = 1/15
  crow_output_volts_query.event = function()
    for i = 1,4 do
      crow.output[i].query()
    end
  end
  crow_output_volts_query:start()
  
  -- redraw timer ----------
  redraw_clock = clock.run(
    function()
      while true do
        clock.sleep(1/15)
        -- norns screen
        if screen_dirty then
          redraw()
        end
        -- grid
        grid_redraw()
      end
    end
  )
end


-- for pattern_time ----------

local function record_press(v)
  press_pattern:watch(
    {
      ["value"] = v
    }
  )
end


-- norns hardware, keys/encs/screen ----------
function key(n, z)
  -- key 1 is alt
  if n == 1 then alt = z == 1 and true or false end
  -- keys 2/3 switch between voltage sets
  if not alt and z == 1 then
    if n == 2 then
      current_voltage_set = util.clamp(current_voltage_set - 1, 1, number_of_voltage_sets)
    elseif n == 3 then
      current_voltage_set = util.clamp(current_voltage_set + 1, 1, number_of_voltage_sets)
    end
  elseif alt and n == 3 and z == 1 then
    -- alt + key3 = send current volatage set
    send_collection(current_voltage_set)
  end
  screen_dirty = true
end


function enc(n, d)
  if not alt then
    -- set volts for outs 1-3
    params:delta(current_voltage_set .. "volts" .. n, d * 0.1)
  elseif alt and n == 1 then
    params:delta(current_voltage_set .. "slew_style", d * 0.1)
  elseif alt and n == 2 then
    -- set volts for out 4
    params:delta(current_voltage_set .. "volts4", d * 0.1)
  elseif alt and n == 3 then
    -- set slew time
    params:delta(current_voltage_set .. "slew", d)
  end
  screen_dirty = true 
end


function redraw()
  screen.clear()
  
  if util.time() - start_time < 3.06 then
    screen.display_png("/home/we/dust/code/runic/assets/splash/" .. splash_index .. ".png", 0, 0)
    splash_index = (splash_index + 1) % 23
    screen_dirty = true
  else
    -- left side shows which voltage set you are looking at and its slew style
    screen.level(12)
    screen.font_size(20)
    screen.text_center_rotate(30, 32, names[current_voltage_set], 90)
    screen.font_size(8)
    screen.level(alt and 16 or 2)
    screen.text_center_rotate(18, 32, slew_style_names[params:get(current_voltage_set .. "slew_style")], 90)
    -- right side shows the voltages that make up the set
    -- i put it in a box
    screen.level(12)
    screen.rect(70, 5, 60, 55)
    screen.fill()
    screen.stroke()
    -- draw the values
    screen.level(0)
    screen.font_size(8)
    screen.move(75, 15)
    screen.text("one: ")
    screen.move(123, 15)
    screen.text_right(string.format("%.2f", voltages[current_voltage_set][1]))
    screen.move(75, 25)
    screen.text("two: ")
    screen.move(123, 25)
    screen.text_right(string.format("%.2f", voltages[current_voltage_set][2]))
    screen.move(75, 35)
    screen.text("three:")
    screen.move(123, 35)
    screen.text_right(string.format("%.2f", voltages[current_voltage_set][3]))
    screen.move(75, 45)
    screen.text("four:")
    screen.move(123, 45)
    screen.text_right(string.format("%.2f", voltages[current_voltage_set][4]))
    -- draw slew time
    screen.move(75, 55)
    screen.text("slew:")
    screen.move(123, 55)
    screen.text_right(string.format("%.2f", params:get(current_voltage_set .. "slew")))
    -- draw the control indicators
    screen.level(alt and 2 or 16)
    screen.move(65, 14)
    screen.circle(65, 13, 2, 2)
    screen.fill()
    screen.stroke()
    screen.circle(65, 23, 2, 2)
    screen.fill()
    screen.stroke()
    screen.circle(65, 33, 2, 2)
    screen.fill()
    screen.stroke()
    screen.level(alt and 16 or 2)
    screen.circle(65, 43, 2, 2)
    screen.fill()
    screen.stroke()
    screen.circle(65, 53, 2, 2)
    screen.fill()
    screen.stroke()
    screen_dirty = false
  end
  screen.update()
end

-- grid stuff ----------

function g.key(x, y, z)
  -- grid alt button
  if x == 16 and y == 1 then g_alt = z == 1 and true or false end
  -- grid pattern recorder. taken from one of the norns studies
  if x == 1 and y == 1 and z == 1 then
    if press_pattern.rec == 1 then
      press_pattern:rec_stop()
      press_pattern:start()
      print("playing pattern...")
    elseif press_pattern.count == 0 then
      press_pattern:rec_start()
      --record_press_count()
      print("recording pattern...")
    elseif press_pattern.play == 1 then
      press_pattern:stop()
      print("stopping pattern...")
    else
      press_pattern:start()
      print("playing pattern...")
    end
  elseif x == 1 and y == 3 and z == 1 then
    press_pattern:rec_stop()
    press_pattern:stop()
    press_pattern:clear()
    print("pattern cleared...")
  elseif x > 4 and x <= 12 and y == 2 and z == 1 then
    -- set/send current voltage set
    if g_alt then
      current_voltage_set = x - 4
    else
      current_voltage_set = x - 4
      record_press(current_voltage_set)
      send_collection(current_voltage_set)
    end
  elseif y > 4 and y <= 8 and z == 1 then
    -- set single voltages, don't send them to crow
    local v = math.floor(util.linlin(1, 16, -5, 10, x))
    set_single_voltage(current_voltage_set, y - 4, v)
    -- if grid alt is held, send the single voltage
    if g_alt then send_single_voltage(current_voltage_set, y - 4) end
  end

  screen_dirty = true
end


function grid_redraw()
  g:all(0)
  -- grid alt button
  g:led(16, 1, g_alt and 15 or 6)
  -- record/play/stop button
  -- blink while recording and/or while a pattern is recorded and playback is stopped
  -- solid bright while playing a pattern back
  -- solid dim while pattern is empty and stopped
  if press_pattern.count > 0 and press_pattern.play == 1 then
    g:led(1, 1, 15)
  elseif press_pattern.count > 0 then
    g:led(1, 1, blink == true and 15 or 6)
  else
    g:led(1, 1, 6)
  end
  -- pattern clear button
  g:led(1, 3, 6)

  for i = 5, 12 do
    -- set/send current voltage set
    g:led(i, 2, 6)
    g:led(4 + current_voltage_set, 2, 15)
  end

  for i = 1, 4 do
    -- grid scope thing
    -- bright keys are current voltages at crow outputs
    -- dim keys are destination voltages
    g:led(6, 4 + i, 4)
    g:led(math.floor(util.linlin(-5, 10, 1, 16, voltages[current_voltage_set][i])), 4 + i, 6)
    g:led(math.floor(util.linlin(-5, 10, 1, 16, grid_scope[i])), 4 + i, 15)
  end

  g:refresh()
end
