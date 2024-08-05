--[[
  delay_sequencer.lua
  Combined sequencer and delay for Cells DS providing configurable delay with looping
  version 1.2

  copyright 2008 john saylor
  This software is licensed under the CC-GNU LGPL version 2.1 or later.
  http://creativecommons.org/licenses/LGPL/2.1/
--]]

delay = {}

function on_load()
  -- CONFIGURE START [change these if you want]
  delay.max_echoes = nil -- to silence [no max] if nil
  delay.display_info = nil -- set to 1 to avoid displaying info
  -- CONFIGURE END [don't mess with anything else ...]

  -- data structures
  delay.main_count = 0
  delay.msg_line = 1  
  delay.notes = {}
  delay.note_count = 0
  delay.pan = {1, 16, 2, 15, 3, 14, 4, 13, 5, 12, 6, 11, 7, 10, 8, 9}
  delay.version = '1.2'

  -- initialize sound
  load_sound(1)

  -- Initialize sequencer grid
  grid = {}
  for block_count = 1, 8 do
    grid[block_count] = {}
    for i = 1, 16 do
      grid[block_count][i] = {}
      for j = 1, 16 do
        grid[block_count][i][j] = 4 -- WHITE
      end
    end
  end

  -- set globals
  old_column = 1
  selected_sound = 1
  drag_color = 4 -- WHITE
  display_instructions()
end

function compute_delay(n)
  local random_echo = math.random(1, 10) -- Random echo count
  local random_volume = math.random(1, 16) -- Random volume adjustment
  local random_pitch = math.random(-2, 2) -- Random pitch adjustment
  local random_pan = math.random(1, 16) -- Random panning adjustment

  n.echo = random_echo
  n.volume = math.max(n.volume - random_echo, 0) -- Ensure volume does not go below 0
  n.count = n.count + random_echo

  -- Update display_x and display_y with randomness for visual feedback
  n.display_x = math.random(1, 16)
  n.display_y = math.random(1, 16)
  n.scale = math.max(math.min(n.scale + random_pitch, 16), 1) -- Ensure scale stays within bounds
  n.pan = random_pan
end

function display_msg(m)
  if delay.msg_line > 191 then
    delay.msg_line = 1 
    clear_top_screen()
  end
  display_text(m, 1, delay.msg_line)
  delay.msg_line = delay.msg_line + 12
end

function display_instructions()
  display_text("Change Sound: Hold [LEFT] and touch a cell", 1, 1)
  display_text("Clear all cells: Press [Y]", 1, 12)
end

function pad_released_left()
  set_all_cells(4) -- Clear screen
end

function stylus_newpress()
  if PAD_HELD_LEFT == 1 then
    set_all_cells(3) -- light_gray
    set_cell(X, Y, 1) -- dark_gray
    local sound_number = (17 - Y) + ((X - 1) * 16)
    display_msg('sound number: ' .. sound_number)
    load_sound(sound_number)
    set_pan(8)
    play_note(8, 16)
  else
    local idx = X .. '_' .. Y
    if delay.notes[idx] then
      local v = delay.notes[idx].volume
      local e = delay.notes[idx].echo
      if v < 16 then v = v + 1 end
      if e > 0 then e = e - 1 end
      delay.notes[idx].volume = v
      delay.notes[idx].echo = e
    else
      delay.notes[idx] = {
        x = X,
        y = Y,
        scale = 17 - Y,
        volume = 17 - X,
        echo = 0,
        count = delay.main_count + 1,
        display_x = X,
        display_y = Y,
        pan = 8
      }
      delay.note_count = delay.note_count + 1
    end
    grid[BLOCK][X][Y] = MEDIUM_GRAY
    set_cell(X, Y, grid[BLOCK][X][Y])
  end
end

function add_note_to_delay(x, y)
  local idx = x .. '_' .. y
  if delay.notes[idx] then
    local v = delay.notes[idx].volume
    local e = delay.notes[idx].echo
    if v < 16 then v = v + 1 end
    if e > 0 then e = e - 1 end
    delay.notes[idx].volume = v
    delay.notes[idx].echo = e
  else
    delay.notes[idx] = {
      x = x,
      y = y,
      scale = 17 - y,
      volume = 17 - x,
      echo = 0,
      count = delay.main_count + 1,
      display_x = x,
      display_y = y,
      pan = math.random(1, 16)
    }
    delay.note_count = delay.note_count + 1
  end
end

function clock()
  if not delay.display_info then
    display_msg('delay_sequencer.lua version: ' .. delay.version)
    display_msg('  hold left pad and touch screen to change sound')
    delay.display_info = 1
  end

  if delay.note_count > 0 then
    local idx_play = {}
    local idx_count = 0
    for idx, n in pairs(delay.notes) do
      if n.count == delay.main_count then
        table.insert(idx_play, idx)
        idx_count = idx_count + 1
      end
    end

    if idx_count > 0 then
      set_all_cells(4) -- white
      for c, i in pairs(idx_play) do
        if ((not delay.max_echoes) or (delay.notes[i].echo < delay.max_echoes)) and (delay.notes[i].volume > 0) then
          set_pan(delay.notes[i].pan)
          play_note(delay.notes[i].scale, delay.notes[i].volume)
          if delay.notes[i].display_x < 17 and delay.notes[i].display_y < 17 then
            local color_int = delay.notes[i].volume
            if color_int == 4 then color_int = 12 end
            if color_int == 5 then color_int = 11 end
            set_cell(delay.notes[i].display_x, delay.notes[i].display_y, color_int)
          end
          compute_delay(delay.notes[i])
        else
          delay.notes[i] = nil
          delay.note_count = delay.note_count - 1
        end
      end
    end

    delay.main_count = delay.main_count + 1
  else
    delay.main_count = 0
  end

  if ACTIVE and PAD_HELD_LEFT == 0 and PAD_HELD_RIGHT == 0 then
    for i = 1, 16 do
      set_cell(old_column, i, grid[BLOCK][old_column][i])
    end
    set_column(SEQUENCER_STEP_16, LIGHT_GRAY)
    old_column = SEQUENCER_STEP_16
    for i = 1, 16 do
      if grid[BLOCK][SEQUENCER_STEP_16][i] == MEDIUM_GRAY then
        local j = 17 - i
        play_note(j, 16)
        midi_note(j, 16, 2)
        if ACTIVE then set_cell(SEQUENCER_STEP_16, i, LIGHT_BLUE) end
        add_note_to_delay(SEQUENCER_STEP_16, i)  -- Add the note to the delay system
      end
    end
  end
end

function pad_newpress_y()
  -- Clear the sequencer grid
  for block_count = 1, 8 do
    for i = 1, 16 do
      for j = 1, 16 do
        grid[block_count][i][j] = 4 -- WHITE
      end
    end
  end

  -- Clear the delay notes
  delay.notes = {}
  delay.note_count = 0
  delay.main_count = 0

  -- Clear the display
  set_all_cells(4) -- WHITE
end
