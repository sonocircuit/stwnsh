-- stwnsh v0.1.0 @sonocircuit
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

g = grid.connect()
m = midi.connect()

lattice = require 'lattice'
mirror = include ("lib/stwnsh_reflection")

--------- variables ----------
load_pset = false
rand_at_lauch = true

shift = false
alt = false
mash_focus = 1
mash_edit = false
mash_param = 1
is_running = false
coin = 0
view_message = ""

-- patterns
eMASH = 1
eREST = 2
quantize_event = {}
quantize_rate = 1/4

pattern_focus = 1
pattern_edit = false
pattern_clear = false
pattern_is_rec = false
pattern_overdub = false
pattern_param = 1

-- viz
pulse_bar = false
pulse_beat = false
pulse_key_fast = 1
pulse_key_mid = 1
pulse_key_slow = 1
font_size_off = 0
screen_level_off = 0

-- constants
NUM_TRACKS = 3
NUM_SLOTS = 9
FADE_TIME = 0.1
REC_SLEW = 0.01
MAX_TAPELENGTH = 110
DEFAULT_TRACK_LEN = 16


--------- tables ----------
options = {}
options.key_quant = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16","1/32"}
options.quant_value = {1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16, 1/32}
options.pattern_rec_mode = {"free", "onset", "synced"}
options.pattern_play = {"loop", "oneshot"}
options.pattern_launch = {"manual", "beat", "bar"}
options.pattern_quantize = {"1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16", "3/64", "1/24", "1/32", "3/128", "1/48", "1/64"}
options.pattern_quantize_value = {1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4, 3/16, 1/6, 1/8, 3/32, 1/12, 1/16}
options.pattern_meter = {"2/4", "3/4", "4/4", "5/4", "6/4", "7/4", "9/4", "11/4"}
options.meter_val = {2/4, 3/4, 4/4, 5/4, 6/4, 7/4, 9/4, 11/4}
options.rate_names = {"-400%", "-200%", "-100%", "-50%", "-25%", "-12.5&", "STOP", "12.5%", "25%", "50%", "100%", "200%", "400%"}
options.rate_values = {-4, -2, -1, -0.5, -0.25, -0.125, 0, 0.125, 0.25, 0.5, 1, 2, 4}

mash_l_params = {"mash_start_l_", "mash_length_l_", "mash_pan_l_", "mash_rate_l_", "mash_rate_slew_l_"}
mash_r_params = {"mash_start_r_", "mash_length_r_", "mash_pan_r_", "mash_rate_r_", "mash_rate_slew_r_"}
mash_names = {"START", "LENGTH", "PAN", "RATE", "RATE SLEW"}

pattern_l_params = {"pattern_rec_mode_", "pattern_meter_", "pattern_launch_"}
pattern_r_params = {"pattern_playback_", "pattern_beatnum_", "pattern_quantize_"}
pattern_l_names = {"REC MODE", "METER", "LAUNCH"}
pattern_r_names = {"PLAYBACK", "LENGTH", "QUANTIZE"}

track = {}
for i = 1, NUM_TRACKS do
  track[i] = {}

  track[i].rec = false
  track[i].prev_rec = false
  track[i].oneshot = false
  track[i].monitor = true
  track[i].mash = false
  track[i].hold = false
  track[i].active_mash = 0

  track[i].level = 1
  track[i].rec_level = 1
  track[i].dub_level = 0
  track[i].cutoff = 18000
  track[i].rq = 4

  track[i].step = 0
  track[i].pos_abs = 0
  track[i].pos_rel = 0
  track[i].pos_grid = 1

  track[i].beat_num = DEFAULT_TRACK_LEN
  track[i].beat_num_new = DEFAULT_TRACK_LEN
  track[i].startpoint = 1 + (i - 1) * (MAX_TAPELENGTH + 1)
  track[i].endpoint = track[i].startpoint + clock.get_beat_sec() * track[i].beat_num
  track[i].loop_len = track[i].endpoint - track[i].startpoint
end

playhead = {}
for i = 1, 6 do
  playhead[i] = {}
  playhead[i].pos_abs = 0
  playhead[i].pos_rel = 0
  playhead[i].pos_grid = 0
  playhead[i].startpoint = 1 + (i - 1) * (MAX_TAPELENGTH + 1)
  playhead[i].loop_len = clock.get_beat_sec() * DEFAULT_TRACK_LEN
end

mash = {}
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

-- clock ids
tracksync = {}
trackstep = {}
for i = 1, NUM_TRACKS do
  tracksync[i] = nil
  trackstep[i] = nil
end

heldkey = {}
for i = 1, 3 do
  heldkey[i] = 0
end

--------- functions ----------
function make_mash(i, slot)
  local slot = slot or 1
  -- do homework
  local lstart_l = track[i].startpoint + (mash[slot].srt_l - 1) / 16 * track[i].loop_len
  local lstart_r = track[i].startpoint + (mash[slot].srt_r - 1) / 16 * track[i].loop_len
  local lend_l = lstart_l + (track[i].loop_len / 16) * mash[slot].len_l
  local lend_r = lstart_r + (track[i].loop_len / 16) * mash[slot].len_r
  local pos_l = mash[slot].rate_l > 0 and lstart_l or lend_l
  local pos_r = mash[slot].rate_r > 0 and lstart_r or lend_r
  -- playtime
  softcut.pan(i, mash[slot].pan_l)
  softcut.pan(i + 3, mash[slot].pan_r)
  softcut.rate_slew_time(i, mash[slot].rate_slew_l)
  softcut.rate_slew_time(i + 3, mash[slot].rate_slew_r)
  softcut.rate(i, mash[slot].rate_l)
  softcut.rate(i + 3, mash[slot].rate_r)
  softcut.loop_start(i, lstart_l)
  softcut.loop_start(i + 3, lstart_r)
  softcut.loop_end(i, lend_l)
  softcut.loop_end(i + 3, lend_r)
  softcut.position(i, pos_l)
  softcut.position(i + 3, pos_r)
  softcut.level(i, track[i].level)
  softcut.level(i + 3, track[i].level)
end

function reset_track(i)
  if not track[i].monitor then
    softcut.level(i, 0)
    softcut.level(i + 3, 0)
  end
  local pos = track[i].startpoint + (track[i].step - 1) / 16 * track[i].loop_len
  softcut.loop_start(i, track[i].startpoint)
  softcut.loop_start(i + 3, track[i].startpoint)
  softcut.loop_end(i, track[i].endpoint)
  softcut.loop_end(i + 3, track[i].endpoint)
  softcut.position(i, pos)
  softcut.position(i + 3, pos)
  softcut.pan(i, -1)
  softcut.pan(i + 3, 1)
  softcut.rate_slew_time(i, 0)
  softcut.rate_slew_time(i + 3, 0)
  softcut.rate(i, 1)
  softcut.rate(i + 3, 1)
  track[i].active_mash = 0
end

function randomize_mash(i, ch)
  if ch == "l" then
    params:set("mash_pan_l_"..i, (math.random() * 20 - 10) / 10)
    params:set("mash_start_l_"..i, math.random(1, 16))
    params:set("mash_length_l_"..i, math.random(1, 17 - mash[i].srt_l))
    params:set("mash_rate_l_"..i, math.pow(2, math.random(-2, 2)) * (math.random(0, 1) > 0.5 and 1 or -1))
    params:set("mash_rate_slew_l_"..i, math.random())
  elseif ch == "r" then
    params:set("mash_pan_r_"..i, (math.random() * 20 - 10) / 10)
    params:set("mash_start_r_"..i, math.random(1, 16))
    params:set("mash_length_r_"..i, math.random(1, 17 - mash[i].srt_l))
    params:set("mash_rate_r_"..i, math.pow(2, math.random(-2, 2)) * (math.random(0, 1) > 0.5 and 1 or -1))
    params:set("mash_rate_slew_r_"..i, math.random())
  end
end

function set_track_len(i, beats)
  local beat_sec = 60/params:get("clock_tempo")
  track[i].beat_num = beats or track[i].beat_num
  track[i].endpoint = track[i].startpoint + beat_sec * track[i].beat_num
  track[i].loop_len = beat_sec * track[i].beat_num

  playhead[i].startpoint = track[i].startpoint
  playhead[i + 3].startpoint = track[i].startpoint
  playhead[i].loop_len = track[i].loop_len
  playhead[i + 3].loop_len = track[i].loop_len

  softcut.loop_start(i, track[i].startpoint)
  softcut.loop_start(i + 3, track[i].startpoint)
  softcut.loop_end(i, track[i].endpoint)
  softcut.loop_end(i + 3, track[i].endpoint)
  softcut.phase_quant(i, track[i].loop_len / 16)
  softcut.phase_quant(i + 3, track[i].loop_len / 16)
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

function clamp_mash_start(i, ch)
  local start = params:get("mash_start_"..ch.."_"..i)
  local length = params:get("mash_length_"..ch.."_"..i)
  local max_start = 17 - length
  if start + length >= 17 then
    params:set("mash_start_"..ch.."_"..i, max_start)
  end
end

function clamp_mash_length(i, ch)
  local start = params:get("mash_start_"..ch.."_"..i)
  local length = params:get("mash_length_"..ch.."_"..i)
  local max_len = 17 - start
  if length >= max_len then
    params:set("mash_length_"..ch.."_"..i, max_len)
  end
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
  set_levels(i)
end

function set_levels(i)
  if track[i].monitor or track[i].mash then
    softcut.level(i, track[i].level)
    softcut.level(i + 3, track[i].level)
  else
    softcut.level(i, 0)
    softcut.level(i + 3, 0)
  end
end

function reset_pos_callback(i)
  -- oneshot recording
  if not track[i].mash then
    softcut.position(i, track[i].startpoint)
    softcut.position(i + 3, track[i].startpoint)
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
  -- set track length
  if track[i].beat_num ~= track[i].beat_num_new then
    set_track_len(i, track[i].beat_num_new)
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
  playhead[i].pos_abs = pos
  if playhead[i].pos_grid ~= pos_lo_res then
    playhead[i].pos_grid = pos_lo_res
  end
  if playhead[i].pos_rel ~= pp then
    playhead[i].pos_rel = pp
  end
end

--------- clock functions --------
function clock.tempo_change_handler(bpm)
  for i = 1, NUM_TRACKS do
    set_track_len(i)
  end
end

function ledpulse_fast()
  pulse_key_fast = pulse_key_fast == 8 and 12 or 8
end

function ledpulse_mid()
  pulse_key_mid = util.wrap(pulse_key_mid + 1, 4, 12)
end

function ledpulse_slow()
  pulse_key_slow = util.wrap(pulse_key_slow + 1, 4, 12)
end

function ledpulse_bar()
  while true do
    clock.sync(4)
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

function reset_pos(i)
  while true do
    clock.sync(track[i].beat_num)
    reset_pos_callback(i)
    track[i].step = 0
  end
end

function step_track(i)
  while true do
    clock.sync(track[i].beat_num / 16)
    track[i].step = track[i].step + 1
    if track[i].step >= 16 then
      track[i].step = 0
    end
    if track[i].mash then
      dirtyscreen = true
    end
  end
end

-------- pattern recording --------
function event_exec(e)
  if e.t == eMASH then
    make_mash(e.i, e.slot)
    mash_active = true
    track[e.i].mash = true
    track[e.i].active_mash = e.slot
    pattern[e.p].active_mash[e.i] = e.slot
    if track[e.i].rec then
      track[e.i].prev_rec = true
      toggle_rec(e.i)
    end
  elseif e.t == eREST then
    if not track[e.i].hold then
      reset_track(e.i)
      mash_active = get_global_mash_state()
      track[e.i].mash = false
      pattern[e.p].active_mash[e.i] = 0
      if track[e.i].prev_rec and not track[e.i].rec then
        track[e.i].prev_rec = false
        toggle_rec(e.i)
      end
      coin = 0
      dirtyscreen = true
    end
  end
end

pattern = {}
for i = 1, 4 do
  pattern[i] = mirror.new("pattern "..i)
  pattern[i].process = event_exec
  pattern[i].start_callback = function() step_one_indicator(i) set_pattern_length(i) end
  pattern[i].end_of_loop_callback = function() check_mash_state(i) end
  pattern[i].end_of_rec_callback = function()  end
  pattern[i].end_callback = function() check_mash_state(i) end
  pattern[i].active_mash = {}
  for track = 1, NUM_TRACKS + 1 do
    pattern[i].active_mash[track] = 0
  end
end

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

function check_mash_state(n)
  for i = 1, NUM_TRACKS do
    if pattern[n].active_mash[i] == track[i].active_mash then
      if heldkey[i] < 1 and not track[i].hold then
        reset_track(i)
        mash_active = get_global_mash_state()
        track[i].mash = false
        if track[i].prev_rec and not track[i].rec then
          track[i].prev_rec = false
          toggle_rec(i)
        end
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
  clock.run(function()
    clock.sleep(0.1)
    pattern[i].key_flash = false
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
  -- init softcut
  audio.level_adc_cut(1)
  audio.level_tape_cut(1)

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

    softcut.phase_quant(i, 0.1)
    softcut.phase_offset(i, 0)
  end

  -- params
  local name = {"[ONE]", "[TWO]", "[TRI]"}
  params:add_separator("track_params", "s t w n s h")
  for i = 1, NUM_TRACKS do
    params:add_group("track_"..i, "track "..name[i], 12)
    
    params:add_separator("track_settings_"..i, "track "..name[i].." settings")
    -- track length
    params:add_number("track_length_"..i, "track length", 1, 64, 4, function(param) return param:get()..(param:get() > 1 and "beats" or "beat") end)
    params:set_action("track_length_"..i, function(x) track[i].beat_num_new = x end)
    -- track level
    params:add_control("track_level_"..i, "track level", controlspec.new(0, 1, "lin", 0, 1), function(param) return (round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%")) end)
    params:set_action("track_level_"..i, function(x) track[i].level = x set_levels(i) end)
    -- rec level
    params:add_control("rec_level_"..i, "rec level", controlspec.new(0, 1, "lin", 0, 1), function(param) return (round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%")) end)
    params:set_action("rec_level_"..i, function(x) track[i].rec_level = x set_rec(i) end)
    -- overdub level
    params:add_control("dub_level_"..i, "overdub level", controlspec.new(0, 1, "lin", 0, 0), function(param) return (round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%")) end)
    params:set_action("dub_level_"..i, function(x) track[i].dub_level = x set_rec(i) end)
    
    params:add_control("track_cutoff_"..i, "filter cutoff", controlspec.new(20, 18000, "exp", 0, 18000), function(param) return (round_form(param:get(), 1, " hz")) end)
    params:set_action("track_cutoff_"..i, function(x) track[i].cutoff = x softcut.post_filter_fc(i, x) softcut.post_filter_fc(i + 3, x) end)

    params:add_control("track_rq_"..i, "filter q", controlspec.new(0.01, 4, "exp", 0, 4), function(param) return (round_form(util.linlin(0.01, 4, 1, 100, param:get()), 1, "%")) end)
    params:set_action("track_rq_"..i, function(x) track[i].rq = x  softcut.post_filter_rq(i, x) softcut.post_filter_rq(i + 3, x) end)

    params:add_option("track_fliter_type_"..i, "filter type", {"low pass", "high pass", "band pass", "band reject"}, 1)
    params:set_action("track_fliter_type_"..i, function(option) set_filter_type(i, option) end)

    params:add_separator("track_control_"..i, "track "..name[i].." control")

    params:add_binary("track_toggle_rec_"..i, "> toggle rec", "trigger", 0)
    params:set_action("track_toggle_rec_"..i, function() toggle_rec(i) end)

    params:add_binary("track_toggle_oneshot_"..i, "> toggle oneshot", "trigger", 0)
    params:set_action("track_toggle_oneshot_"..i, function() track[i].oneshot = not track[i].oneshot end)

    params:add_binary("track_toggle_monitor_"..i, "> toggle monitor", "trigger", 0)
    params:set_action("track_toggle_monitor_"..i, function() toggle_monitor(i) end)
  end

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
    params:set_action("mash_start_l_"..i, function(x) mash[i].srt_l = x clamp_mash_start(i, "l") end)

    params:add_number("mash_start_r_"..i, "startpoint right", 1, 16, 1)
    params:set_action("mash_start_r_"..i, function(x) mash[i].srt_r = x clamp_mash_start(i, "r") end)

    params:add_number("mash_length_l_"..i, "length left", 1, 16, 1)
    params:set_action("mash_length_l_"..i, function(x) mash[i].len_l = x clamp_mash_length(i, "l") end)

    params:add_number("mash_length_r_"..i, "length right", 1, 16, 1)
    params:set_action("mash_length_r_"..i, function(x) mash[i].len_r = x clamp_mash_length(i, "r") end)

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

    params:add_option("pattern_rec_mode_"..i, "rec mode", options.pattern_rec_mode, 1)

    params:add_option("pattern_playback_"..i, "playback", options.pattern_play, 1)
    params:set_action("pattern_playback_"..i, function(mode) pattern[i].loop = mode == 1 and 1 or 0 end)
    
    params:add_option("pattern_quantize_"..i, "quantize", options.pattern_quantize, 7)
    params:set_action("pattern_quantize_"..i, function(idx) pattern[i].quantize = options.pattern_quantize_value[idx] end)
    
    params:add_option("pattern_launch_"..i, "count in", options.pattern_launch, 3)
    
    params:add_option("pattern_meter_"..i, "meter", options.pattern_meter, 3)
    params:set_action("pattern_meter_"..i, function(idx) pattern[i].meter = options.meter_val[idx] update_pattern_length(i) end)
    
    params:add_number("pattern_beatnum_"..i, "length", 1, 16, 4, function(param) return param:get()..(param:get() == 1 and " bar" or " bars") end)
    params:set_action("pattern_beatnum_"..i, function(num) pattern[i].beatnum = num * 4 update_pattern_length(i) dirtygrid = true end)
  end

  -- pset callbacks
  params.action_write = function(filename, name, number)
    os.execute("mkdir -p "..norns.state.data.."patterns/"..number.."/")
    local pattern_data = {}
    clock.run(function() 
      clock.sleep(0.5)
      for i = 1, 4 do
        pattern_data[i] = {}
        pattern_data[i].count = pattern[i].count
        pattern_data[i].event = deep_copy(pattern[i].event)
        pattern_data[i].endpoint = pattern[i].endpoint
      end
      tab.save(pattern_data, norns.state.data.."patterns/"..number.."/"..name.."_pattern.data")
      print("finished writing pset:'"..name.."'")
    end)
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      local pattern_data = tab.load(norns.state.data.."patterns/"..number.."/"..pset_id.."_pattern.data")
      for i = 1, 4 do
        pattern[i].count = pattern_data[i].count
        pattern[i].event = deep_copy(pattern_data[i].event)
        pattern[i].endpoint = pattern_data[i].endpoint
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
  end

  -- set defaults
  for i = 1, NUM_TRACKS do
    toggle_monitor(i)
    set_rec(i)
  end

  params:set("track_length_1", 2)
  params:set("track_length_2", 4)
  params:set("track_length_3", 8)

  set_track_len(1, 2)
  set_track_len(2, 4)
  set_track_len(3, 8)

  if rand_at_lauch then
    for i = 1, NUM_SLOTS do
      randomize_mash(i, "l")
      randomize_mash(i, "r")
    end
  end

  -- metros
  screenredrawtimer = metro.init(function() screen_redraw() end, 1/15, -1) -- // metro for screen redraw
  screenredrawtimer:start()
  dirtyscreen = true

  hardwareredrawtimer = metro.init(function() hardware_redraw() end, 1/30, -1) -- // metro for gridredraw
  hardwareredrawtimer:start()

  -- clocks
  key_quantizer = clock.run(event_q_clock)
  barpulse = clock.run(ledpulse_bar)
  beatpulse = clock.run(ledpulse_beat)
  clock.run(function()
    clock.sync(4)
    for i = 1, NUM_TRACKS do
      tracksync[i] = clock.run(reset_pos, i)
      trackstep[i] = clock.run(step_track, i)
      track[i].step = 0
    end
    is_running = true
  end)

  -- lattice
  vizclock = lattice:new()

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
  if mash_edit then
    if n == 2 and z == 1 then
      if shift then
        randomize_mash(mash_focus, "l")
      else
        mash_param = util.wrap(mash_param - 1, 1, #mash_names)
      end
    elseif n == 3 and z == 1 then
      if shift then
        randomize_mash(mash_focus, "r")
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
  else
    if n == 2 and z == 1 then
      if not shift then
        dirtyscreen = true
      end
    elseif n == 3 and z == 1 then
      if not shift then
        dirtyscreen = true
      end
    end
  end
end

function enc(n, d)
  if n == 1 then
    -- do nothing
  end
  if mash_edit then
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
  else
    if n == 2 then
      font_size_off = util.clamp(font_size_off + d, -6, 30)
    elseif n == 3 then
      screen_level_off = util.clamp(screen_level_off + d, -14, 0)
    end
    dirtyscreen = true
  end
end

function redraw()
  screen.clear()
  if mash_edit then
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
    screen.font_size(math.random(8, 32) + font_size_off)
    screen.move(14, math.random(32, 48) + math.floor(font_size_off / 2))
    screen.text_center("S")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(8, 32) + font_size_off)
    screen.move(34, math.random(32, 48))
    screen.text_center("T")
    
    screen.level(coin == 1 and 0 or math.random(4, 15) + math.floor(screen_level_off / 3))
    screen.font_face(math.random(1, 24))
    screen.font_size(math.random(8, 32) + font_size_off)
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
    screen.font_size(math.random(8, 32) + font_size_off)
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
      local beat_sync = params:get("pattern_launch_"..i) == 2 and 1 or (params:get("pattern_launch_"..i) == 3 and 4 or nil)
      if pattern[i].count == 0 then
        if pattern[i].rec_enabled == 0 then
          if num_rec_enabled() == 0 then 
            local mode = params:get("pattern_rec_mode_"..i) == 3 and 1 or 2
            local dur = params:get("pattern_rec_mode_"..i) ~= 1 and pattern[i].length or nil
            pattern[i]:set_rec(mode, dur, beat_sync)
          end
        else
          pattern[i]:set_rec(0)
          pattern[i]:stop()
        end
      else
        pattern[i]:start(beat_sync)
      end
    else
      if pattern_overdub then
        if pattern[i].rec == 1 then
          pattern[i]:set_rec(0)
          pattern[i]:undo()
          check_mash_state()
        else
          pattern[i]:set_rec(1)               
        end
      else
        if pattern[i].rec == 1 then
          pattern[i]:set_rec(0)
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
  local i = math.floor(x / 4) + 1
  if y == 5 and x < 12 then
    if x == (1 + (i - 1) * 4) and z == 1 then
      toggle_rec(i)
    elseif x == (2 + (i - 1) * 4) and z == 1 then
      track[i].oneshot = not track[i].oneshot
      if track[i].rec and track[i].oneshot then
        track[i].rec = false
        set_rec(i)
      end
    elseif x == (3 + (i - 1) * 4) and z == 1 then
      track[i].hold = not track[i].hold
      if not track[i].hold and heldkey[i] < 1 then
        track[i].mash = false
        mash_active = get_global_mash_state()
        reset_track(i)
      end
    end
  elseif y == 5 and x > 12 then
    if x == 13 then
      pattern_overdub = z == 1 and true or false
      if z == 0 then
        pattern_clear = false
      end
    elseif x == 14 then
      mod_key = z == 1 and true or false
      if pattern_overdub and mod_key then
        pattern_clear = true
        pattern_overdub = false
      end
    elseif x == 16 and z == 1 then
      toggle_monitor(1)
    end
  elseif y > 5 then
    if (x < 4 or (x > 4 and x < 8) or (x > 8 and x < 12)) then
      local slot = (x - ((i - 1) * 4)) + (y - 6) * 3
      heldkey[i] = heldkey[i] + (z * 2 - 1)
      if mash_edit and z == 1 then
        mash_focus = slot
        dirtyscreen = true
      else
        track[i].mash = (z == 1 or track[i].hold or heldkey[i] > 0) and true or false
        if track[i].mash then
          if z == 1 then
            local e = {t = eMASH, i = i, slot = slot, p = pattern_focus}
            table.insert(quantize_event, e)
          end
        else
          local e = {t = eREST, i = i, p = pattern_focus}
          table.insert(quantize_event, e)
        end
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
    elseif y < 8 and x == 16 and z == 1 then
      local track = y - 4
      toggle_monitor(track)
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
    end
  end
end

function gridredraw()
  g:all(0)
  -- view track lanes
  for i = 1, NUM_TRACKS do
    if track[i].mash then
      g:led(playhead[i].pos_grid, i, 15)
      g:led(playhead[i + 3].pos_grid, i, 8)
    else
      g:led(track[i].step, i, is_running and (track[i].rec and 15 or 4) or 0)
    end
  end
  -- view track actions
  for x = 1, 3 do
    for y = 6, 8 do
      g:led(x, y, 2)
      g:led(x + 4, y, 2)
      g:led(x + 8, y, 2)
    end
  end
  for i = 1, 3 do
    local slot = track[i].active_mash
    if mash_edit then slot = mash_focus end
    if slot > 0 and slot < 4 then
      g:led((slot - 4) + 4 * i, 6, 15)
    elseif slot > 3 and slot < 7 then
      g:led((slot - 7) + 4 * i, 7, 15)
    elseif slot > 6 then
      g:led((slot - 10) + 4 * i, 8, 15)
    end
  end
  -- rec
  for i = 1, 3 do
    g:led((i - 1) * 4 + 1, 5, track[i].rec and pulse_key_mid or 8)
  end
  -- oneshot
  for i = 1, 3 do
    g:led((i - 1) * 4 + 2, 5, track[i].oneshot and pulse_key_slow or 4)
  end
  -- hold
  for i = 1, 3 do
    g:led((i - 1) * 4 + 3, 5, track[i].hold and 15 or 6)
  end
  g:led(13, 5, pattern_overdub and 15 or (pattern_clear and pulse_key_slow or 8))
  g:led(14, 5, pattern_clear and pulse_key_slow or 6)
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
  -- mash edit
    g:led(13, 8, mash_edit and pulse_key_slow or 1)
  -- pattern edit
    g:led(14, 8, pattern_edit and pulse_key_slow or 1)
  -- monitor
  for i = 1, 3 do
    g:led(16, i + 4, track[i].monitor and 10 or 2)
  end
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
  gridredraw()
end

--------- util functions ----------
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

function build_menu()
  --
  _menu.rebuild_params()
  dirtyscreen = true
end

--------- cleanup ----------
function cleanup()
  print("all nice and tidy here")
end