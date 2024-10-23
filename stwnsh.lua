-- stwnsh v1.0.1 @sonocircuit
-- llllllll.co/t/stwnsh
--
-- mash recordings at 
-- the press of a key
--
-- for docs go to:
-- >> github.com/sonocircuit
--    /stwnsh
--
-- or smb into:
-- >> code/stwnsh/doc
--

local g = grid.connect()
local m = midi.connect()

local _l = require 'lattice'
local _r = require 'reflection'

--------- variables ----------
local load_pset = false

local shift = false
local alt = false

local track_edit = false
local track_focus = 1
local track_param = 1
local editkey = 0
local modkey = false

local mash_active = false
local mash_edit = false
local mash_param = 1
local mash_focus = 1
local amsh_step_edit = 0
local amsh_rate_edit = false

local is_running = false
local beat_sec = 60 / params:get("clock_tempo")
local prev_beat_sec = beat_sec
local midi_ch = 1
local midi_trns = 1

-- patterns
local eMASH = 1
local eRSET = 2
local quantize_event = {}
local quantize_rate = 1/4
local quantize_edit = false

local pattern_focus = 1
local pattern_edit = false
local pattern_clear = false
local pattern_is_rec = false
local pattern_overdub = false
local pattern_param = 1

-- viz
local pulse_bar = false
local pulse_beat = false
local pulse_key_fast = 1
local pulse_key_mid = 1
local pulse_key_slow = 1
local font_size_off = 0
local screen_level_off = 0
local coin = 0
local screen_message = 0


-- constants
local NUM_TRACKS = 3
local NUM_SLOTS = 9
local NUM_PATTERNS = 4
local FADE_TIME = 0.02
local REC_SLEW = 0.01
local MAX_TAPELENGTH = 110
local DEFAULT_TRACK_LEN = 16


--------- tables ----------
local options = {}
options.key_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_rec_mode = {"free", "onset", "synced"}
options.pattern_play = {"loop", "oneshot"}
options.pattern_launch = {"manual", "beat", "bar"}
options.pattern_quantize = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
options.pattern_quantize_value = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
options.pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
options.meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}
options.rate_names = {"-400%", "-200%", "-100%", "-50%", "-25%", "-12.5%", "STOP", "12.5%", "25%", "50%", "100%", "200%", "400%"}
options.rate_values = {-4, -2, -1, -0.5, -0.25, -0.125, 0, 0.125, 0.25, 0.5, 1, 2, 4}
options.key_quant_names = {"1/32", "1/16", "1/8", "1/4", "1/2", "1/1"}
options.key_quant_values = {1/8, 1/4, 1/2, 1, 2, 4}
options.mash_length_names = {"1/16", "1/8", "3/16", "1/4", "5/16", "3/8", "7/16", "1/2", "9/16", "5/8", "11/16", "3/4", "13/16", "7/8", "15/16", "1"}
options.mash_length_values = {1/16, 1/8, 3/16, 1/4, 5/16, 3/8, 7/16, 1/2, 9/16, 5/8, 11/16, 3/4, 13/16, 7/8, 15/16, 1}
options.amsh_rate_names = {"32/4", "16/4", "8/4", "4/4", "3/4", "2/3", "1/2", "3/8", "1/3", "1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16"}
options.amsh_rate_values = {8, 4, 2, 1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}

-- track params
local track_l_params = {"track_length_", "input_src_", "track_cutoff_"}
local track_r_params = {"track_level_", "dub_level_", "track_rq_"}
local track_l_names = {"LENGTH", "INPUT", "CUTOFF"}
local track_r_names = {"LEVEL", "OVERDUB", "FILTER Q"}

-- mash params
local mash_l_params = {"mash_start_l_", "mash_length_l_", "mash_pan_l_", "mash_rate_l_", "mash_rate_slew_l_"}
local mash_r_params = {"mash_start_r_", "mash_length_r_", "mash_pan_r_", "mash_rate_r_", "mash_rate_slew_r_"}
local mash_names = {"START", "LENGTH", "PAN", "RATE", "RATE  SLEW"}

-- pattern params
local pattern_l_params = {"pattern_rec_mode_", "pattern_meter_", "pattern_launch_"}
local pattern_r_params = {"pattern_playback_", "pattern_beatnum_", "pattern_quantize_"}
local pattern_l_names = {"REC  MODE", "METER", "LAUNCH"}
local pattern_r_names = {"PLAYBACK", "LENGTH", "QUANTIZE"}

-- screen messages
local msg = {
  {"S", "T", "A", "R", "T"},
  {"R", "E", "S", "E", "T"},
  {"S", "T", "O", "P", "!"},
  {"C", "L", "E", "A", "R"}
}

-- track variables
local track = {}
for i = 1, NUM_TRACKS do
  track[i] = {}
  track[i].rec = false
  track[i].prev_rec = false
  track[i].oneshot = false
  track[i].monitor = false
  track[i].mash = false
  track[i].hold = false
  track[i].active_mash = 0
  track[i].level = 1
  track[i].rec_level = 1
  track[i].dub_level = 0
  track[i].cutoff = 18000
  track[i].rq = 4
  track[i].step = 0
  track[i].beat_num = DEFAULT_TRACK_LEN
  track[i].beat_num_new = DEFAULT_TRACK_LEN
  track[i].startpoint = 1 + (i - 1) * (MAX_TAPELENGTH + 1)
  track[i].endpoint = track[i].startpoint + beat_sec * track[i].beat_num
  track[i].loop_len = track[i].endpoint - track[i].startpoint
  -- automash section
  track[i].amsh_queued = false
  track[i].amsh_active = false
  track[i].amsh_edit = false
  track[i].amsh_rate = 4
  track[i].amsh_step = 0
  track[i].amsh_step_max = 16
  track[i].amsh_pattern = {}
  for s = 1, 16 do
    track[i].amsh_pattern[s] = {}
    track[i].amsh_pattern[s].step = false
    track[i].amsh_pattern[s].prob = 50
    track[i].amsh_pattern[s].pool = {}
  end
end

-- display softcut playheads
local playhead = {}
for i = 1, 6 do
  playhead[i] = {}
  playhead[i].pos_grid = 0
  playhead[i].startpoint = 1 + (i - 1) * (MAX_TAPELENGTH + 1)
  playhead[i].loop_len = beat_sec * DEFAULT_TRACK_LEN
end

-- mash variables
local mash = {}
for i = 1, NUM_SLOTS do
  mash[i] = {}
  mash[i].pan_l = -1
  mash[i].pan_r = 1
  mash[i].srt_l = 2
  mash[i].srt_r = 10
  mash[i].len_l = 6
  mash[i].len_r = 4
  mash[i].rate_l = 1
  mash[i].rate_r = -1
  mash[i].rate_slew_l = 0
  mash[i].rate_slew_r = 0
end

-- store all start- and endpoints
local mashpoint = {}
for i = 1, NUM_TRACKS do
  mashpoint[i] = {}
  for slot = 1, NUM_SLOTS do
    mashpoint[i][slot] = {}
    mashpoint[i][slot].s_l = track[i].startpoint
    mashpoint[i][slot].s_r = track[i].startpoint
    mashpoint[i][slot].e_l = track[i].startpoint + track[i].loop_len
    mashpoint[i][slot].e_r = track[i].startpoint + track[i].loop_len
  end
end

-- clock ids
local trackstep = {}
local amshstep = {}
for i = 1, NUM_TRACKS do
  trackstep[i] = nil
  amshstep[i] = nil
end

-- track held mash keys
local heldkey = {}
for i = 1, 3 do
  heldkey[i] = 0
end


--------- functions ----------
function make_mash(i, slot)
  mash_active = true
  track[i].mash = true
  track[i].active_mash = slot
  track[i].rec = false
  set_rec(i)
  local pos_l = mash[slot].rate_l >= 0 and mashpoint[i][slot].s_l or mashpoint[i][slot].e_l
  local pos_r = mash[slot].rate_r >= 0 and mashpoint[i][slot].s_r or mashpoint[i][slot].e_r
  softcut.pan(i, mash[slot].pan_l)
  softcut.pan(i + 3, mash[slot].pan_r)
  softcut.rate_slew_time(i, mash[slot].rate_slew_l)
  softcut.rate_slew_time(i + 3, mash[slot].rate_slew_r)
  softcut.rate(i, mash[slot].rate_l)
  softcut.rate(i + 3, mash[slot].rate_r)
  softcut.loop_start(i, mashpoint[i][slot].s_l)
  softcut.loop_start(i + 3, mashpoint[i][slot].s_r)
  softcut.loop_end(i, mashpoint[i][slot].e_l)
  softcut.loop_end(i + 3, mashpoint[i][slot].e_r)
  softcut.position(i, pos_l)
  softcut.position(i + 3, pos_r)
  softcut.level(i, track[i].level)
  softcut.level(i + 3, track[i].level)
end

-- revert to position
function reset_track(i)
  track[i].mash = false
  mash_active = get_global_mash_state()
  if not track[i].monitor then
    softcut.level(i, 0)
    softcut.level(i + 3, 0)
  end
  track[i].rec = track[i].prev_rec and true or false
  track[i].prev_rec = false
  set_rec(i)
  local pos = track[i].startpoint + (track[i].step - 1) / 16 * track[i].loop_len -- TODO: position granularity is too low.
  softcut.loop_start(i, track[i].startpoint)
  softcut.loop_start(i + 3, track[i].startpoint)
  softcut.loop_end(i, track[i].endpoint)
  softcut.loop_end(i + 3, track[i].endpoint)
  softcut.pan(i, -1)
  softcut.pan(i + 3, 1)
  softcut.rate_slew_time(i, 0)
  softcut.rate_slew_time(i + 3, 0)
  softcut.rate(i, 1)
  softcut.rate(i + 3, 1)
  softcut.position(i, pos)
  softcut.position(i + 3, pos)
  track[i].active_mash = 0
  dirtyscreen = true
end

-- set track length and softcut loop
function set_track_len(i, beats)
  -- set track length
  track[i].beat_num = beats or track[i].beat_num
  track[i].endpoint = track[i].startpoint + beat_sec * track[i].beat_num
  track[i].loop_len = beat_sec * track[i].beat_num
  -- set playheads
  playhead[i].startpoint = track[i].startpoint
  playhead[i + 3].startpoint = track[i].startpoint
  playhead[i].loop_len = track[i].loop_len
  playhead[i + 3].loop_len = track[i].loop_len
  -- set softcut
  softcut.loop_start(i, track[i].startpoint)
  softcut.loop_start(i + 3, track[i].startpoint)
  softcut.loop_end(i, track[i].endpoint)
  softcut.loop_end(i + 3, track[i].endpoint)
  softcut.phase_quant(i, track[i].loop_len / 16)
  softcut.phase_quant(i + 3, track[i].loop_len / 16)
  -- update mash points for all slots
  for slot = 1, NUM_SLOTS do
    set_mash_points(i, slot)
  end
end

-- calc start and endpoints for playheads
function set_mash_points(i, slot)
  mashpoint[i][slot].s_l = track[i].startpoint + (mash[slot].srt_l - 1) / 16 * track[i].loop_len
  mashpoint[i][slot].s_r = track[i].startpoint + (mash[slot].srt_r - 1) / 16 * track[i].loop_len
  mashpoint[i][slot].e_l = mashpoint[i][slot].s_l + track[i].loop_len * mash[slot].len_l
  mashpoint[i][slot].e_r = mashpoint[i][slot].s_r + track[i].loop_len * mash[slot].len_r
end

-- updtate slot for all tracks
function update_mash_slot(slot) 
  for i = 1, NUM_TRACKS do
    set_mash_points(i, slot)
  end
end

-- limit startpoint according to length
function clamp_mash_start(i, ch)
  local start = params:get("mash_start_"..ch.."_"..i)
  local length = params:get("mash_length_"..ch.."_"..i)
  local max_start = 17 - length
  if start + length >= 17 then
    params:set("mash_start_"..ch.."_"..i, max_start)
  end
end

-- limit length according to startpoint
function clamp_mash_length(i, ch)
  local start = params:get("mash_start_"..ch.."_"..i)
  local length = params:get("mash_length_"..ch.."_"..i)
  local max_len = 17 - start
  if length >= max_len then
    params:set("mash_length_"..ch.."_"..i, max_len)
  end
end

-- randomize mash parameters
function randomize_mash(i, channel)
  local c = channel == 1 and "l" or "r"
  local s = channel == 1 and mash[i].srt_l or mash[i].srt_r
  params:set("mash_pan_"..c.."_"..i, (math.random() * 20 - 10) / 10)
  params:set("mash_start_"..c.."_"..i, math.random(1, 16))
  params:set("mash_length_"..c.."_"..i, math.random(1, 17 - s))
  params:set("mash_rate_"..c.."_"..i, math.random(1, 13))
  params:set("mash_rate_slew_"..c.."_"..i, math.random())
end

function set_filter_type(i, option)
  softcut.post_filter_lp(i, option == 1 and 1 or 0) 
  softcut.post_filter_hp(i, option == 2 and 1 or 0) 
  softcut.post_filter_bp(i, option == 3 and 1 or 0) 
  softcut.post_filter_br(i, option == 4 and 1 or 0)
  softcut.post_filter_lp(i + 3, option == 1 and 1 or 0) 
  softcut.post_filter_hp(i + 3, option == 2 and 1 or 0) 
  softcut.post_filter_bp(i + 3, option == 3 and 1 or 0) 
  softcut.post_filter_br(i + 3, option == 4 and 1 or 0)
end

function set_softcut_input(i, option)
  -- set source
  audio.level_adc_cut(option < 4 and 1 or 0)
  audio.level_eng_cut(option == 4 and 1 or 0)
  audio.level_tape_cut(option == 5 and 1 or 0)
  -- set softcut inputs
  if option == 1 or option > 3 then -- L&R
    softcut.level_input_cut(1, i, 0.707)
    softcut.level_input_cut(2, i, 0)
    softcut.level_input_cut(1, i + 3, 0)
    softcut.level_input_cut(2, i + 3, 0.707)
  elseif option == 2 then -- L IN
    softcut.level_input_cut(1, i, 1)
    softcut.level_input_cut(2, i, 0)
    softcut.level_input_cut(1, i + 3, 1)
    softcut.level_input_cut(2, i + 3, 0)
 elseif option == 3 then -- R IN
    softcut.level_input_cut(1, i, 0)
    softcut.level_input_cut(2, i, 1)
    softcut.level_input_cut(1, i + 3, 0)
    softcut.level_input_cut(2, i + 3, 1)
  end
end

function clear_track_buffer(i)
  softcut.buffer_clear_region_channel(1, track[i].startpoint - 0.2, MAX_TAPELENGTH + 0.2)
  softcut.buffer_clear_region_channel(2, track[i].startpoint, MAX_TAPELENGTH)
end

function toggle_rec(i)
  track[i].rec = not track[i].rec
  set_rec(i)
end

function set_rec(i)
  if track[i].rec then
    softcut.pre_level(i, track[i].dub_level)
    softcut.pre_level(i + 3, track[i].dub_level)
    softcut.rec_level(i, track[i].rec_level)
    softcut.rec_level(i + 3, track[i].rec_level)
  else
    softcut.pre_level(i, 1)
    softcut.pre_level(i + 3, 1)
    softcut.rec_level(i, 0)
    softcut.rec_level(i + 3, 0)
  end
end

function toggle_monitor(i)
  track[i].monitor = not track[i].monitor
  set_level(i)
end

function set_level(i)
  if track[i].monitor or track[i].mash then
    softcut.level(i, track[i].level)
    softcut.level(i + 3, track[i].level)
  else
    softcut.level(i, 0)
    softcut.level(i + 3, 0)
  end
end

function reset_track_pos(i)
  softcut.position(i, track[i].startpoint)
  softcut.voice_sync(i + 3, i, 0)
end

function one_shot_rec(i)
  if track[i].oneshot then
    if track[i].rec then
      track[i].rec = false
      set_rec(i)
      track[i].oneshot = false
    else
      track[i].rec = true
      set_rec(i)
    end
  end
end

function toggle_amsh(i)
  if track[i].amsh_active then
    track[i].prev_rec = false
    track[i].amsh_active = false
    reset_track(i)
  elseif track[i].amsh_queued then
    track[i].amsh_queued = false
  else
    track[i].amsh_queued = true
  end
end

function set_amsh_mode(i)
  if track[i].amsh_queued then
    track[i].amsh_active = true
    track[i].amsh_step = 0
    track[i].amsh_queued = false
    track[i].prev_rec = false
    track[i].rec = true
    set_rec(i)
  end
end

function get_global_mash_state()
  local active = 0
  for i = 1, 3 do
    if track[i].mash then
      active = active + 1
    end
  end
  if active > 0 then
    return true
  else
    return false
  end
end

function phase_poll(i, pos)
  local pp = ((pos - playhead[i].startpoint) / playhead[i].loop_len)
  local pos_lo_res = util.clamp(math.floor(pp * 16) + 1 % 16, 1, 16)
  if playhead[i].pos_grid ~= pos_lo_res then
    playhead[i].pos_grid = pos_lo_res
  end
end

function start_all()
  for i = 1, NUM_TRACKS do
    track[i].step = 0
    track[i].amsh_step = 0
    reset_track_pos(i)
  end
  screen_message = 0
  is_running = true
  dirtyscreen = true
end

function stop_all()
  is_running = false
  for i = 1, NUM_TRACKS do
    track[i].monitor = false
    track[i].prev_rec = false
    track[i].amsh_active = false
    track[i].amsh_queued = false
    reset_track(i)
  end
  for i = 1, NUM_PATTERNS do
    pattern[i]:stop()
  end
  screen_message = 3
  dirtyscreen = true
  clock.run(function()
    clock.sleep(0.8)
    screen_message = 0
    dirtyscreen = true
  end)
end


--------- clock functions --------
function clock.tempo_change_handler(bpm)
  beat_sec = 60 / params:get("clock_tempo")
  if prev_beat_sec ~= beat_sec then
    for i = 1, NUM_TRACKS do
      set_track_len(i)
    end
    prev_beat_sec = beat_sec
  end
end

function clock.transport.start()
  if midi_trns == 3 then
    start_all()
  end
end

function clock.transport.stop()
  if midi_trns == 3 then
    stop_all()
  end
end

function step_track(i)
  while true do
    clock.sync(track[i].beat_num / 16)
    if track[i].step >= 16 then
      track[i].step = 0
      if not track[i].mash then
        reset_track_pos(i)
        one_shot_rec(i) 
      end
      if track[i].beat_num ~= track[i].beat_num_new then
        set_track_len(i, track[i].beat_num_new)
      end
      set_amsh_mode(i)
    end
    track[i].step = track[i].step + 1
    if track[i].mash then
      dirtyscreen = true
    end
    if not track[i].amsh_edit then dirtygrid = true end
  end
end

function step_amsh(i)
  while true do
    clock.sync(options.amsh_rate_values[track[i].amsh_rate])
    if track[i].amsh_step >= track[i].amsh_step_max then
      track[i].amsh_step = 0
    end
    track[i].amsh_step = track[i].amsh_step + 1
    if track[i].amsh_pattern[track[i].amsh_step].step and track[i].amsh_active then
      if track[i].mash then
        track[i].prev_rec = true
        reset_track(i)
      end
      if math.random(100) <= track[i].amsh_pattern[track[i].amsh_step].prob then
        local collection = track[i].amsh_pattern[track[i].amsh_step].pool
        local idx = math.random(1, #collection)
        local slot = collection[idx]
        make_mash(i, slot)
      end
    end
    if track[i].amsh_edit then dirtygrid = true end
  end
end

-- key viz stuff
function ledpulse_fast()
  pulse_key_fast = pulse_key_fast == 8 and 12 or 8
  if pattern_is_rec then dirtygrid = true end
end

function ledpulse_mid()
  pulse_key_mid = util.wrap(pulse_key_mid + 1, 4, 12)
end

function ledpulse_slow()
  pulse_key_slow = util.wrap(pulse_key_slow + 1, 4, 12)
end

function ledpulse_bar()
  while true do
    clock.sync(bar_val)
    pulse_bar = true
    clock.run(function()
      clock.sleep(1/30)
      pulse_bar = false
    end)
  end
end

function ledpulse_beat()
  while true do
    clock.sync(1)
    pulse_beat = true
    clock.run(function()
      clock.sleep(1/30)
      pulse_beat = false
    end)
  end
end


-------- midi --------
function build_midi_device_list()
  midi_devices = {}
  for i = 1, #midi.vports do
    local long_name = midi.vports[i].name
    local short_name = string.len(long_name) > 15 and util.acronym(long_name) or long_name
    table.insert(midi_devices, i..": "..short_name)
  end
end

function midi.add()
  build_midi_device_list()
end

function midi.remove()
  clock.run(function()
    clock.sleep(0.2)
    build_midi_device_list()
  end)
end


-------- pattern recording --------
function event_exec(e)
  if not track[e.i].amsh_active then
    if e.t == eMASH then
      if not track[e.i].prev_rec then
        track[e.i].prev_rec = track[e.i].rec and true or false
      end
      make_mash(e.i, e.slot)
      pattern[e.p].active_mash[e.i] = e.slot
    elseif e.t == eRSET and not track[e.i].hold then
      reset_track(e.i)
      pattern[e.p].active_mash[e.i] = 0
      coin = 0
      dirtyscreen = true
    end
  end
end

pattern = {}
for i = 1, NUM_PATTERNS do
  pattern[i] = _r.new("pattern "..i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() step_one_indicator(i) set_pattern_length(i) end
  pattern[i].end_of_loop_callback = function() check_mash_state(i) end
  pattern[i].end_of_rec_callback = function()  end
  pattern[i].end_callback = function() check_mash_state(i) end
  pattern[i].key_flash = false
  pattern[i].meter = 4/4
  pattern[i].beatnum = 16
  pattern[i].length = 16
  pattern[i].active_mash = {}
  for track = 1, NUM_TRACKS do
    pattern[i].active_mash[track] = 0
  end
end

function check_mash_state(n)
  for i = 1, NUM_TRACKS do
    if pattern[n].active_mash[i] == track[i].active_mash and track[i].active_mash > 0 then
      if heldkey[i] < 1 and not track[i].hold then
        reset_track(i)
        coin = 0
        dirtyscreen = true
      end
    end
  end
end

function num_rec_enabled()
  local num_enabled = 0
  for i = 1, 4 do
    if pattern[i].rec_enabled > 0 then
      num_enabled = num_enabled + 1
    end
  end
  return num_enabled
end

function step_one_indicator(i)
  pattern[i].key_flash = true
  dirtygrid = true
  clock.run(function()
    clock.sleep(0.1)
    pattern[i].key_flash = false
    dirtygrid = true
  end) 
end

function set_pattern_length(i)
  local prev_length = pattern[i].length
  pattern[i].length = pattern[i].meter * pattern[i].beatnum
  if prev_length ~= pattern[i].length then
    pattern[i]:set_length(pattern[i].length)
  end
end

function update_pattern_length(i)
  if pattern[i].play == 0 then
    pattern[i].length = pattern[i].meter * pattern[i].beatnum
    pattern[i]:set_length(pattern[i].length)
  end
end

function event_q_clock()
  while true do
    clock.sync(quantize_rate)
    if #quantize_event > 0 then
      for k, e in pairs(quantize_event) do
        pattern[pattern_focus]:watch(e)
        event_exec(e)
      end
      quantize_event = {}
    end
  end
end


--------- init function ----------
function init()
  -- get beat sec (clock.get_beat_sec() ain't workin')
  beat_sec = 60 / params:get("clock_tempo")
  -- init softcut
  audio.level_adc_cut(1)
  audio.level_tape_cut(1)
  -- get midi devices
  build_midi_device_list()

  for i = 1, 6 do
    softcut.enable(i, 1)
    softcut.buffer(i, i > 3 and 2 or 1)
    softcut.level_input_cut(i > 3 and 2 or 1, i, 1)

    softcut.play(i, 1)
    softcut.rec(i, 1)

    softcut.level(i, 0)
    softcut.pan(i, i > 3 and 1 or -1)

    softcut.post_filter_lp(i, 1) 
    softcut.post_filter_dry(i, 0)

    softcut.post_filter_fc(i, 18000)
    softcut.post_filter_rq(i, 4)

    softcut.pre_level(i, 1)
    softcut.rec_level(i, 0)
    softcut.recpre_slew_time(i, REC_SLEW)

    softcut.fade_time(i, FADE_TIME)
    softcut.level_slew_time(i, 0.1)
    softcut.pan_slew_time(i, 0.1)
    softcut.rate_slew_time(i, 0)
    softcut.rate(i, 1)

    softcut.loop_start(i, 1)
    softcut.loop_end(i, 16)
    softcut.loop(i, 1)
    softcut.position(i, 1)

    softcut.phase_quant(i, 0.01)
    softcut.phase_offset(i, 0)
  end

  -- params
  local name = {"[ONE]", "[TWO]", "[TRI]"}
  params:add_separator("track_params", "s t w n s h")
  for i = 1, NUM_TRACKS do
    params:add_group("track_"..i, "track "..name[i], 14)
    
    params:add_separator("track_settings_"..i, name[i].." settings")
    -- track length
    params:add_number("track_length_"..i, "track length", 1, 64, 4, function(param) return param:get()..(param:get() > 1 and " beats" or " beat") end)
    params:set_action("track_length_"..i, function(x)
      track[i].beat_num_new = x
      if not is_running then
        set_track_len(i, track[i].beat_num_new)
      end
    end)
    -- track input source
    params:add_option("input_src_"..i, "input source", {"stereo", "mono l", "mono r", "eng", "tape"}, 1)
    params:set_action("input_src_"..i, function(option) set_softcut_input(i, option) end)
    -- track level
    params:add_control("track_level_"..i, "track level", controlspec.new(0, 1, "lin", 0, 1), function(param) return (round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%")) end)
    params:set_action("track_level_"..i, function(x) track[i].level = x set_level(i) end)
    -- rec level
    params:add_control("rec_level_"..i, "rec level", controlspec.new(0, 1, "lin", 0, 1), function(param) return (round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%")) end)
    params:set_action("rec_level_"..i, function(x) track[i].rec_level = x set_rec(i) end)
    -- overdub level
    params:add_control("dub_level_"..i, "overdub level", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%")) end)
    params:set_action("dub_level_"..i, function(x) track[i].dub_level = x set_rec(i) end)
    -- track filter type
    params:add_option("track_fliter_type_"..i, "filter type", {"low pass", "high pass", "band pass", "band reject"}, 1)
    params:set_action("track_fliter_type_"..i, function(option) set_filter_type(i, option) end)
    -- track cutoff
    params:add_control("track_cutoff_"..i, "filter cutoff", controlspec.new(20, 18000, "exp", 0, 18000), function(param) return (round_form(param:get(), 1, " hz")) end)
    params:set_action("track_cutoff_"..i, function(x) track[i].cutoff = x softcut.post_filter_fc(i, x) softcut.post_filter_fc(i + 3, x) end)
    -- track filter q
    params:add_control("track_rq_"..i, "filter q", controlspec.new(0.01, 4, "exp", 0, 4), function(param) return (round_form(util.linlin(0.01, 4, 1, 100, param:get()), 1, "%")) end)
    params:set_action("track_rq_"..i, function(x) track[i].rq = x  softcut.post_filter_rq(i, x) softcut.post_filter_rq(i + 3, x) end)
    

    params:add_separator("track_control_"..i, name[i].." control")

    params:add_binary("track_toggle_amsh_"..i, "> toggle auto mash", "trigger", 0)
    params:set_action("track_toggle_amsh_"..i, function() toggle_amsh(i) end)

    params:add_binary("track_toggle_rec_"..i, "> toggle rec", "trigger", 0)
    params:set_action("track_toggle_rec_"..i, function() toggle_rec(i) end)

    params:add_binary("track_toggle_oneshot_"..i, "> toggle oneshot", "trigger", 0)
    params:set_action("track_toggle_oneshot_"..i, function() track[i].oneshot = not track[i].oneshot end)

    params:add_binary("track_toggle_monitor_"..i, "> toggle monitor", "trigger", 0)
    params:set_action("track_toggle_monitor_"..i, function() toggle_monitor(i) end)
  end

  params:add_group("midi_settings", "midi settings", 3)
  params:add_option("midi_transport", "midi transport", {"off", "send", "recieve"}, 1)
  params:set_action("midi_transport", function(mode) midi_trns = mode end)

  params:add_option("midi_device", "midi device", midi_devices, 1)
  params:set_action("midi_device", function(val) m = midi.connect(val) end)

  params:add_number("midi_channel", "midi channel", 1, 16, 1)
  params:set_action("midi_channel", function(val) midi_ch = val end)

  params:add_number("time_signature", "time signature", 2, 9, 4, function(param) return param:get().."/4" end)
  params:set_action("time_signature", function(val) bar_val = val end)
  params:hide("time_signature")

  -- mash slots
  for i = 1, NUM_SLOTS do
    params:add_group("mash_"..i, "mash "..i, 12)
    params:hide("mash_"..i)

    params:add_separator("mash_levels_"..i, "mash "..i.." levels")

    params:add_control("mash_pan_l_"..i, "pan left", controlspec.new(-1, 1, "lin", 0, -1), function(param) return pan_display(param:get()) end)
    params:set_action("mash_pan_l_"..i, function(x) mash[i].pan_l = x end)

    params:add_control("mash_pan_r_"..i, "pan right", controlspec.new(-1, 1, "lin", 0, 1), function(param) return pan_display(param:get()) end)
    params:set_action("mash_pan_r_"..i, function(x) mash[i].pan_r = x end)

    params:add_separator("mash_playhead_"..i, "mash "..i.." play head")

    params:add_number("mash_start_l_"..i, "startpoint left", 1, 16, 1)
    params:set_action("mash_start_l_"..i, function(x) mash[i].srt_l = x clamp_mash_start(i, "l") update_mash_slot(i) end)

    params:add_number("mash_start_r_"..i, "startpoint right", 1, 16, 1)
    params:set_action("mash_start_r_"..i, function(x) mash[i].srt_r = x clamp_mash_start(i, "r") update_mash_slot(i) end)

    params:add_option("mash_length_l_"..i, "length left", options.mash_length_names, 1)
    params:set_action("mash_length_l_"..i, function(x) mash[i].len_l = options.mash_length_values[x] clamp_mash_length(i, "l") update_mash_slot(i) end)

    params:add_option("mash_length_r_"..i, "length right", options.mash_length_names, 1)
    params:set_action("mash_length_r_"..i, function(x) mash[i].len_r = options.mash_length_values[x] clamp_mash_length(i, "r") update_mash_slot(i) end)

    params:add_option("mash_rate_l_"..i, "rate left", options.rate_names, 11)
    params:set_action("mash_rate_l_"..i, function(x) mash[i].rate_l = options.rate_values[x] end)

    params:add_option("mash_rate_r_"..i, "rate right", options.rate_names, 11)
    params:set_action("mash_rate_r_"..i, function(x) mash[i].rate_r = options.rate_values[x] end)

    params:add_control("mash_rate_slew_l_"..i, "rate slew left", controlspec.new(0, 1, "lin", 0, 0))
    params:set_action("mash_rate_slew_l_"..i, function(x) mash[i].rate_slew_l = x end)

    params:add_control("mash_rate_slew_r_"..i, "rate slew right", controlspec.new(0, 1, "lin", 0, 0))
    params:set_action("mash_rate_slew_r_"..i, function(x) mash[i].rate_slew_r = x end)
  end
  

  -- patterns params
  params:add_group("patterns", "patterns", 28)
  params:hide("patterns")

  for i = 1, 4 do
    params:add_separator("patterns_params"..i, "pattern "..i)

    params:add_option("pattern_rec_mode_"..i, "rec mode", options.pattern_rec_mode, 2)

    params:add_option("pattern_playback_"..i, "playback", options.pattern_play, 1)
    params:set_action("pattern_playback_"..i, function(mode) pattern[i].loop = mode == 1 and 1 or 0 end)
    
    params:add_option("pattern_quantize_"..i, "quantize", options.pattern_quantize, 13)
    params:set_action("pattern_quantize_"..i, function(idx) pattern[i].quantize = options.pattern_quantize_value[idx] end)
    
    params:add_option("pattern_launch_"..i, "count in", options.pattern_launch, 3)
    
    params:add_option("pattern_meter_"..i, "meter", options.pattern_meter, 3)
    params:set_action("pattern_meter_"..i, function(idx) pattern[i].meter = options.meter_val[idx] update_pattern_length(i) end)
    
    params:add_number("pattern_beatnum_"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("pattern_beatnum_"..i, function(num) pattern[i].beatnum = num * 4 update_pattern_length(i) dirtygrid = true end)
  end


  params:add_option("key_quantization", "key quantization", options.key_quant_names, 2)
  params:set_action("key_quantization", function(idx) quantize_rate = options.key_quant_values[idx] end)
  params:hide("key_quantization")

  -- pset callbacks
  params.action_write = function(filename, name, number)
    os.execute("mkdir -p "..norns.state.data.."presets/"..number.."/")
    local pset_data = {}
    pset_data.pattern = {}
    pset_data.amsh = {}
    for i = 1, 4 do
      pset_data.pattern[i] = {}
      pset_data.pattern[i].count = pattern[i].count
      pset_data.pattern[i].event = deep_copy(pattern[i].event)
      pset_data.pattern[i].endpoint = pattern[i].endpoint
    end
    for i = 1, NUM_TRACKS do
      pset_data.amsh[i] = {}
      pset_data.amsh[i].rate = track[i].amsh_rate
      pset_data.amsh[i].step_max = track[i].amsh_step_max
      pset_data.amsh[i].pattern = {}
      for s = 1, 16 do
        pset_data.amsh[i].pattern[s] = {}
        pset_data.amsh[i].pattern[s].step = track[i].amsh_pattern[s].step
        pset_data.amsh[i].pattern[s].prob = track[i].amsh_pattern[s].prob
        pset_data.amsh[i].pattern[s].pool = {table.unpack(track[i].amsh_pattern[s].pool)}
      end
    end
    clock.run(function() 
      clock.sleep(0.5)
      tab.save(pset_data, norns.state.data.."presets/"..number.."/"..name.."_preset.data")
      print("finished writing pset:'"..name.."'")
    end)
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      local pset_data = tab.load(norns.state.data.."presets/"..number.."/"..pset_id.."_preset.data")
      for i = 1, 4 do
        pattern[i].count = pset_data.pattern[i].count
        pattern[i].event = deep_copy(pset_data.pattern[i].event)
        pattern[i].endpoint = pset_data.pattern[i].endpoint
      end
      for i = 1, NUM_TRACKS do
        track[i].amsh_rate = pset_data.amsh[i].rate
        track[i].amsh_step_max = pset_data.amsh[i].step_max
        for s = 1, 16 do
          track[i].amsh_pattern[s].step = pset_data.amsh[i].pattern[s].step
          track[i].amsh_pattern[s].prob = pset_data.amsh[i].pattern[s].prob
          track[i].amsh_pattern[s].pool = {table.unpack(pset_data.amsh[i].pattern[s].pool)}
        end
      end
      dirtygrid = true
      print("finished reading pset:'"..pset_id.."'")
    end
  end

  params.action_delete = function(filename, name, number)
    norns.system_cmd("rm -r "..norns.state.data.."patterns/"..number.."/")
    print("finished deleting pset:'"..name.."'")
  end

  -- bang params
  if load_pset then
    params:default()
  else
    params:bang()
    for i = 1, NUM_SLOTS do
      for channel = 1, 2 do
        randomize_mash(i, channel)
      end
    end
    local len_val = {2, 4, 8}
    for i = 1, NUM_TRACKS do
      params:set("track_length_"..i, len_val[i])
      set_track_len(i, len_val[i])
    end
  end

  -- set levels
  for i = 1, NUM_TRACKS do
    set_level(i)
    set_rec(i)
  end

  -- metros
  screenredrawtimer = metro.init(function() screen_redraw() end, 1/15, -1)
  screenredrawtimer:start()
  dirtyscreen = true

  hardwareredrawtimer = metro.init(function() hardware_redraw() end, 1/30, -1)
  hardwareredrawtimer:start()
  dirtygrid = true

  -- clocks
  key_quantizer = clock.run(event_q_clock)
  barpulse = clock.run(ledpulse_bar)
  beatpulse = clock.run(ledpulse_beat)
  clock.run(function()
    clock.sync(4)
    for i = 1, NUM_TRACKS do
      trackstep[i] = clock.run(step_track, i)
      amshstep[i] = clock.run(step_amsh, i)
      track[i].step = 0
      track[i].amsh_step = 0
    end
    is_running = true
  end)

  -- lattice
  vizclock = _l:new()

  fastpulse = vizclock:new_sprocket{
    action = function(t) ledpulse_fast() end,
    division = 1/32,
    enabled = true
  }

  midpulse = vizclock:new_sprocket{
    action = function() ledpulse_mid() end,
    division = 1/24,
    enabled = true
  }

  slowpulse = vizclock:new_sprocket{
    action = function() ledpulse_slow() end,
    division = 1/12,
    enabled = true
  }

  vizclock:start()

  -- callbacks
  softcut.event_phase(phase_poll)
  softcut.poll_start_phase()

  -- start on the downbeat
  print("stwnsh up and running. mash away.")
end


--------- norns UI ----------
function key(n, z)
  if n == 1 then
    shift = z == 1 and true or false
  end
  if quantize_edit then
    -- do nothing
  elseif mash_edit then
    if n == 2 and z == 1 then
      if shift then
        randomize_mash(mash_focus, 1)
      else
        mash_param = util.wrap(mash_param - 1, 1, #mash_names)
      end
    elseif n == 3 and z == 1 then
      if shift then
        randomize_mash(mash_focus, 2)
      else
        mash_param = util.wrap(mash_param + 1, 1, #mash_names)
      end
    end
    dirtyscreen = true
  elseif pattern_edit then
    if n == 2 and z == 1 then
      pattern_param = util.wrap(pattern_param - 1, 1, #pattern_r_names)
    elseif n == 3 and z == 1 then
      pattern_param = util.wrap(pattern_param + 1, 1, #pattern_r_names)
    end
    dirtyscreen = true
  elseif track_edit then
   -- do nothing
  else
    if n == 2 and z == 1 then
      if transport_clock == nil then
        transport_clock = clock.run(function()
          screen_message = is_running and 2 or 1
          dirtyscreen = true
          clock.sync(bar_val)
          start_all()
          if midi_trns == 2 then
            m:start()
          end
          transport_clock = nil
        end)
      end
      dirtyscreen = true
    elseif n == 3 and z == 1 then
      stop_all()
      if midi_trns == 2 then
        m:stop()
      end
      dirtyscreen = true
    end
  end
end

function enc(n, d)
  if n == 1 then
    -- do nothing
  end
  if quantize_edit then
    if n == 2 then
      params:delta("time_signature", d)
    elseif n == 3 then
      params:delta("key_quantization", d)
    end
    dirtyscreen = true
  elseif mash_edit then
    if n == 2 then
      params:delta(mash_l_params[mash_param]..mash_focus, d)
    elseif n == 3 then
      params:delta(mash_r_params[mash_param]..mash_focus, d)
    end
    dirtyscreen = true
  elseif pattern_edit then
    if not (params:get("pattern_rec_mode_"..pattern_focus) == 1 and pattern_param == 2) then
      if n == 2 then
        params:delta(pattern_l_params[pattern_param]..pattern_focus, d)
      elseif n == 3 then
        params:delta(pattern_r_params[pattern_param]..pattern_focus, d)
      end
      dirtyscreen = true
    end
  elseif track_edit then
    if n == 2 then
      params:delta(track_l_params[track_param]..track_focus, d)
    elseif n == 3 then
      params:delta(track_r_params[track_param]..track_focus, d)
    end
    dirtyscreen = true
  elseif amsh_step_edit > 0 then
    if n == 2 or n == 3 then
      local step_prob = track[track_focus].amsh_pattern[amsh_step_edit].prob
      track[track_focus].amsh_pattern[amsh_step_edit].prob = util.clamp(step_prob + d, 0, 100)
    end
    dirtyscreen = true
  else
    if n == 2 then
      font_size_off = util.clamp(font_size_off + d, -7, 32)
      dirtyscreen = true
    elseif n == 3 then
      screen_level_off = util.clamp(screen_level_off + d, -15, 0)
      dirtyscreen = true
    end
  end
end

function redraw()
  screen.clear()
  if screen_message > 0 then
    for i = 1, #msg[screen_message] do
      screen.level(math.random(2, 15))
      screen.font_face(math.random(1, 24))
      screen.font_size(math.random(14, 48))
      screen.move(32 + (i - 1) * 16, math.random(32, 48))
      screen.text_center(msg[screen_message][i])
    end
  elseif quantize_edit and not modkey then
    -- mash edit params
    screen.font_face(2)
    screen.font_size(8)
    screen.level(8)
    screen.font_size(24)
    screen.move(32, 40)
    screen.text_center(params:string("time_signature"))
    screen.move(96, 40)
    screen.text_center(params:string("key_quantization"))
    screen.font_size(8)
    screen.level(8)
    screen.move(32, 60)
    screen.text_center("time  signature")
    screen.move(96, 60)
    screen.text_center("key  quantization")

  elseif mash_edit then
    -- mash edit params
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("EDIT  MASH  SLOT  "..mash_focus)
    -- param list
    screen.level(8)
    screen.move(64, 60)
    screen.text_center(mash_names[mash_param])
    screen.level(4)
    screen.move(30, 60)
    screen.text_center("L")
    screen.move(98, 60)
    screen.text_center("R")

    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    screen.text_center(params:string(mash_l_params[mash_param]..mash_focus))
    screen.move(98, 39)
    screen.text_center(params:string(mash_r_params[mash_param]..mash_focus))

  elseif pattern_edit then
    -- patterm params
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("EDIT  PATTERN  "..pattern_focus)
    -- param list
    screen.level(4)
    screen.move(30, 60)
    screen.text_center(pattern_l_names[pattern_param])
    screen.move(98, 60)
    screen.text_center(pattern_r_names[pattern_param])

    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    if (params:get("pattern_rec_mode_"..pattern_focus) == 1 and pattern_param == 2) then
      screen.text_center("-")
    else
      screen.text_center(params:string(pattern_l_params[pattern_param]..pattern_focus))
    end
    screen.move(98, 39)
    if (params:get("pattern_rec_mode_"..pattern_focus) == 1 and pattern_param == 2) then
      screen.text_center("-")
    else
      screen.text_center(params:string(pattern_r_params[pattern_param]..pattern_focus))
    end
  elseif track_edit then
    -- track params
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("EDIT  TRACK  "..track_focus)
    -- param list
    screen.level(4)
    screen.move(30, 60)
    screen.text_center(track_l_names[track_param])
    screen.move(98, 60)
    screen.text_center(track_r_names[track_param])

    screen.level(15)
    screen.font_size(16)
    screen.move(30, 39)
    screen.text_center(params:string(track_l_params[track_param]..track_focus))
    screen.move(98, 39)
    screen.text_center(params:string(track_r_params[track_param]..track_focus))
  elseif amsh_step_edit > 0 then
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("STEP  PROBABILITY")
    screen.font_size(32)
    screen.move(64, 48)
    screen.text_center(track[track_focus].amsh_pattern[amsh_step_edit].prob.."%")
  elseif amsh_rate_edit then
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("STEP  RATE")
    screen.font_size(32)
    screen.move(64, 48)
    screen.text_center(options.amsh_rate_names[track[track_focus].amsh_rate])
  else
    coin = 0
    if mash_active then
      coin = math.random() > 0.65 and 1 or 0
    end
    screen.level(mash_active and coin * 15 + screen_level_off or 0)
    screen.rect(1, 1, 128, 64)
    screen.fill()

    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(10, 44) + font_size_off)
    screen.move(14, math.random(32, 48) + math.floor(font_size_off / 2))
    screen.text_center("S")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(8, 32) + font_size_off)
    screen.move(34, math.random(32, 48))
    screen.text_center("T")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(12, 40) + font_size_off)
    screen.move(54, math.random(32, 48)+ math.floor(font_size_off / 2))
    screen.text_center("W")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(8, 32) + font_size_off)
    screen.move(74, math.random(32, 48))
    screen.text_center("N")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(8, 32) + font_size_off)
    screen.move(94, math.random(32, 48)+ math.floor(font_size_off / 2))
    screen.text_center("S")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(10, 36) + font_size_off)
    screen.move(114, math.random(32, 48))
    screen.text_center("H")
  end
  screen.update()
end


--------- grid UI ----------
function gridkey_patterns(i)
  if pattern_clear and pattern[i].count > 0 then
    pattern[i]:clear()
  else
    if pattern[i].play == 0 then
      local beat_sync = params:get("pattern_launch_"..i) == 2 and 1 or (params:get("pattern_launch_"..i) == 3 and bar_val or nil)
      if pattern[i].count == 0 then
        if pattern[i].rec_enabled == 0 then
          if num_rec_enabled() == 0 then 
            local mode = params:get("pattern_rec_mode_"..i) == 3 and 1 or 2
            local dur = params:get("pattern_rec_mode_"..i) ~= 1 and pattern[i].length or nil
            pattern[i]:set_rec(mode, dur, beat_sync)
            pattern_is_rec = true
          end
        else
          pattern[i]:set_rec(0)
          pattern[i]:stop()
          pattern_is_rec = false
        end
      else
        pattern[i]:start(beat_sync)
      end
    else
      if pattern_overdub then
        if pattern[i].rec == 1 then
          pattern[i]:set_rec(0)
          pattern[i]:undo()
          check_mash_state(i)
          pattern_is_rec = false
        else
          pattern[i]:set_rec(1)
          pattern_is_rec = true               
        end
      else
        if pattern[i].rec == 1 then
          pattern[i]:set_rec(0)
          pattern_is_rec = false
          if pattern[i].count == 0 then
            pattern[i]:stop()
          end
        else
          pattern[i]:stop()
        end
      end
    end
  end
end

function g.key(x, y, z)
  local i = x > 8 and 3 or (x > 4 and 2 or 1)
  if y < 4 then
    if track[y].amsh_edit then
      if z == 1 then
        if modkey then
          clock.run(function()
            clock.sync(1)
            track[y].amsh_step = 0
          end)
        else
          amsh_step_edit = x
          -- doublepress
          if track[y].endpoint_clock == nil then
            track[y].endpoint_clock = clock.run(function()
              clock.sleep(0.2)
              track[y].endpoint_clock = nil
            end)
          else
            track[y].amsh_step_max = x -- if clock still running then set endpoint
          end
        end
      elseif z == 0 then
        local state = #track[y].amsh_pattern[x].pool > 0 and true or false
        track[y].amsh_pattern[x].step = state
        amsh_step_edit = 0
      end
      dirtyscreen = true
    else
      if modkey and not quantize_edit and z == 1 then
        screen_message = 2
        dirtyscreen = true
        clock.run(function()
          clock.sync(1)
          track[y].step = 0
          reset_track_pos(i)
          screen_message = 0
          dirtyscreen = true
        end)
      elseif quantize_edit and modkey and z == 1 then
        screen_message = 4
        dirtyscreen = true
        clear_track_buffer(y)
        clock.run(function()
          clock.sleep(1)
          screen_message = 0
          dirtyscreen = true
        end)
      end
    end
  elseif y == 4 then
    amsh_rate_edit = z == 1 and true or false
    if z == 1 then
      if track[track_focus].amsh_edit then
        track[track_focus].amsh_rate = x
      end
    end
    dirtyscreen = true
  elseif y == 5 and x < 13 then
    if (x == 1 or x == 5 or x == 9) and z == 1 and not (track[i].amsh_active or track[i].mash) then
      toggle_rec(i)
    elseif (x == 2 or x == 6 or x == 10) and z == 1 and not (track[i].amsh_active or track[i].mash) then
      track[i].oneshot = not track[i].oneshot
      if track[i].rec and track[i].oneshot then
        track[i].rec = false
        set_rec(i)
      end
    elseif (x == 3 or x == 7 or x == 11) and z == 1 and not track[i].amsh_active then
      track[i].hold = not track[i].hold
      if not track[i].hold and heldkey[i] < 1 then
        reset_track(i)
      end
    elseif (x == 4 or x == 8 or x == 12) then
      editkey = editkey + (z * 2 - 1)
      track_focus = i
      if z == 1 then
        for n = 1, 3 do
          if n == i then
            track[n].amsh_edit = not track[n].amsh_edit
          else
            track[n].amsh_edit = false
          end
        end
      end
      dirtyscreen = true
    end
  elseif y == 5 and x > 12 then
    if x == 13 then
      pattern_overdub = z == 1 and true or false
      if pattern_overdub then
        pattern_clear = false
      end
    elseif x == 14 then
      pattern_clear = z == 1 and true or false
      if pattern_clear then
        pattern_overdub = false
      end
    elseif x == 15 and z == 1 then
      toggle_amsh(1)
    elseif x == 16 and z == 1 then
      toggle_monitor(1)
    end
  elseif y > 5 then
    if (x < 4 or (x > 4 and x < 8) or (x > 8 and x < 12)) then
      local slot = (x - ((i - 1) * 4)) + (y - 6) * 3
      heldkey[i] = heldkey[i] + (z * 2 - 1)
      if amsh_step_edit > 0 then
        local collection = track[i].amsh_pattern[amsh_step_edit].pool
        if z == 1 then
          if tab.contains(collection, slot) then
            table.remove(collection, tab.key(collection, slot))
          else
            table.insert(collection, slot)
          end
        end
      else
        if modkey and z == 1 then
          for channel = 1, 2 do
            randomize_mash(slot, channel)
          end
        end
        track[i].mash = (z == 1 or track[i].hold or heldkey[i] > 0) and true or false
        if track[i].mash then
          if z == 1 then
            local e = {t = eMASH, i = i, slot = slot, p = pattern_focus}
            table.insert(quantize_event, e)
          end
        else
          local e = {t = eRSET, i = i, p = pattern_focus}
          table.insert(quantize_event, e)
        end
        if mash_edit and z == 1 then
          mash_focus = slot
          dirtyscreen = true
        end
      end
    elseif (x == 4 or x == 8 or x == 12) then
      if not (mash_edit or pattern_edit) then
        editkey = editkey + (z * 2 - 1)
        if z == 1 then
          track_edit = true
          track_focus = i
          track_param = y - 5
        elseif z == 0 and editkey < 1 then
          track_edit = false
        end
        dirtyscreen = true
      end
    elseif y < 8 and (x == 13 or x == 14) and z == 1 then
      if num_rec_enabled() == 0 then
        pattern_focus = (x - 12) + (y - 6) * 2
      end
      if pattern_edit then
        dirtyscreen = true
      else
        gridkey_patterns(pattern_focus)
      end
    elseif y < 8 and x == 15 and z == 1 then
      local n = y - 4
      toggle_amsh(n)
    elseif y < 8 and x == 16 and z == 1 then
      local n = y - 4
      toggle_monitor(n)
    elseif y == 8 and x == 13 and z == 1 then
      mash_edit = not mash_edit 
      if mash_edit and pattern_edit then
        pattern_edit = false
      end
      dirtyscreen = true
    elseif y == 8 and x == 14 and z == 1 then
      pattern_edit = not pattern_edit
      if pattern_edit and mash_edit then
        mash_edit = false
      end
      dirtyscreen = true
    elseif y == 8 and x == 15 then
      modkey = z == 1 and true or false
      dirtyscreen = true
    elseif y == 8 and x == 16 then
      quantize_edit = z == 1 and true or false
      dirtyscreen = true
    end
  end
end

function gridredraw()
  g:all(0)
  -- view track lanes
  for i = 1, NUM_TRACKS do
    if track[i].amsh_edit then
      for x = 1, 16 do
        if x <= track[i].amsh_step_max then
          g:led(x, i, track[i].amsh_step == x and 10 or (track[i].amsh_pattern[x].step and 6 or 2))
        end
        g:led(x, 4, track[i].amsh_rate == x and 10 or ((x == 1 or x == 4 or x == 7 or x == 10 or x == 13 or x == 16) and 2 or 0))
      end
    else
      if track[i].mash then
        g:led(playhead[i].pos_grid, i, 15)
        g:led(playhead[i + 3].pos_grid, i, 8)
      else
        g:led(track[i].step, i, is_running and (track[i].rec and 15 or 4) or 0)
      end
    end
  end
  -- view track mash slots
  for x = 1, 3 do
    for y = 6, 8 do
      g:led(x, y, 2)
      g:led(x + 4, y, 2)
      g:led(x + 8, y, 2)
    end
  end
  for i = 1, 3 do
    if track[i].amsh_edit and amsh_step_edit > 0 then
      for _, v in ipairs(track[i].amsh_pattern[amsh_step_edit].pool) do
        if v > 0 and v < 4 then
          g:led((v - 4) + 4 * i, 6, 8)
        elseif v > 3 and v < 7 then
          g:led((v - 7) + 4 * i, 7, 8)
        elseif v > 6 then
          g:led((v - 10) + 4 * i, 8, 8)
        end
      end
    else
      local slot = mash_edit and mash_focus or track[i].active_mash
      if slot > 0 and slot < 4 then
        g:led((slot - 4) + 4 * i, 6, 15)
      elseif slot > 3 and slot < 7 then
        g:led((slot - 7) + 4 * i, 7, 15)
      elseif slot > 6 then
        g:led((slot - 10) + 4 * i, 8, 15)
      end
    end
  end
  -- top keys
  for i = 1, 3 do
    -- rec
    g:led((i - 1) * 4 + 1, 5, track[i].amsh_active and 1 or (track[i].rec and pulse_key_mid or 8))
    -- oneshot
    g:led((i - 1) * 4 + 2, 5, track[i].amsh_active and 1 or (track[i].oneshot and pulse_key_slow or 4))
    -- hold
    g:led((i - 1) * 4 + 3, 5, track[i].amsh_active and 1 or (track[i].hold and 15 or 6))
  end
  g:led(13, 5, pattern_overdub and 15 or (pattern_clear and pulse_key_slow or 8))
  g:led(14, 5, pattern_clear and pulse_key_slow or 5)
  -- pattern keys
  for x = 13, 14 do
    for y = 6, 7 do
      local i = (x - 12) + (y - 6) * 2
      if pattern_edit then
        g:led(x, y, pattern_focus == i and 4 or 0)
      else
        if pattern[i].rec == 1 and pattern[i].play == 1 then
          g:led(x, y, pulse_key_fast)
        elseif pattern[i].rec_enabled == 1 then
          g:led(x, y, 15)
        elseif pattern[i].play == 1 then
          g:led(x, y, pattern[i].key_flash and 15 or 12)
        elseif pattern[i].count > 0 then
          g:led(x, y, 6)
        else
          g:led(x, y, 2)
        end
      end
    end
  end
  -- track edit
  for i = 1, 3 do
    local x = track_focus * 4
    g:led(x, 5, track[track_focus].amsh_edit and pulse_key_slow or (track_edit and 4 or 0))
    g:led(x, i + 5, (track_edit and track_param == i) and 8 or 0)
  end
  -- mash edit
  g:led(13, 8, mash_edit and pulse_key_slow or 1)
  -- pattern edit
  g:led(14, 8, pattern_edit and pulse_key_slow or 1)
  -- trig mode
  for i = 1, 3 do
    g:led(15, i + 4, track[i].amsh_queued and 6 or (track[i].amsh_active and pulse_key_mid or 0))
  end
  -- monitor
  for i = 1, 3 do
    g:led(16, i + 4, track[i].monitor and 10 or 2)
  end
  -- rnd key
  g:led(15, 8, modkey and 15 or 0)
  -- view metronome
  g:led(16, 8, is_running and (pulse_bar and 15 or (pulse_beat and 8 or 3)) or 3)
  g:refresh()
end


--------- redraw functions ----------
function screen_redraw()
  if dirtyscreen then
    redraw()
    dirtyscreen = false
  end
end

function hardware_redraw()
  if dirtygrid then
    gridredraw()
    dirtygrid = false
  end
end


--------- util functions ----------
function deep_copy(tbl)
  local ret = {}
  if type(tbl) ~= 'table' then return tbl end
  for key, value in pairs(tbl) do
    ret[key] = deep_copy(value)
  end
  return ret
end

function round_form(param, quant, form)
  return(util.round(param, quant)..form)
end

function pan_display(param)
  local pos_right = ""
  local pos_left = ""
  if param == 0 then
    pos_right = ""
    pos_left = ""
  elseif param < -0.01 then
    pos_right = ""
    pos_left = "< "
  elseif param > 0.01 then
    pos_right = " >"
    pos_left = ""
  end
  return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
end

function build_menu(i)
  _menu.rebuild_params()
  dirtyscreen = true
end


--------- cleanup ----------
function cleanup()
  print("cleaned up the mash")
end
