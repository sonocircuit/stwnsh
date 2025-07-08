-- stwnsh v1.1.0 @sonocircuit
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


local a = arc.connect()
local g = grid.connect()
local m = midi.connect()

local _l = require 'lattice'
local _t = require 'textentry'
local _m = require 'core/mods'
local _r = require 'reflection'

--------- variables ----------
local load_pset = false
local default_audio = _path.audio.."stwnsh/"

local shift = false
local alt = false

local track_edit = false
local track_focus = 1
local track_param = 1
local editkey = 0
local modkey = false
local te_track = 1

local mash_active = false
local mash_edit = false
local mash_src = {}
local mash_dst = {}
local mash_init_clk = nil
local mash_param = 1
local mash_focus = 1
local amsh_step_edit = 0
local amsh_rate_edit = false

local is_running = false
local beat_sec = 60 / params:get("clock_tempo")
local prev_beat_sec = beat_sec
local midi_trns = 1

local arc_conncted = false
local arc_track_mode = false
local arc_mode_clk = nil
local arc_focus = 1
local arc_param = 1
local arc_params = {"track_level_", "dub_level_", "track_cutoff_", "track_rq_"}
local arc_vars = {"level", "dub_level", "cutoff", "filter_q"}
local arc_inc = 0

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
local MAX_TRACK_LEN = 110
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
options.amsh_rate_names = {"16/4", "12/4", "8/4", "4/4", "3/4", "2/3", "1/2", "3/8", "1/3", "1/4", "3/16", "1/6", "1/8", "3/32", "1/12", "1/16"}
options.amsh_rate_values = {16, 12, 8, 4, 3, 8/3, 2, 3/2, 4/3, 1, 3/4, 2/3, 1/2, 3/8, 1/3, 1/4}

-- track params
local track_l_params = {"track_length_", "track_level_", "track_cutoff_"}
local track_r_params = {"input_src_", "dub_level_", "track_rq_"}
local track_l_names = {"LENGTH", "LEVEL", "CUTOFF"}
local track_r_names = {"INPUT", "OVERDUB", "FILTER Q"}

-- mash params
local mash_params = {"start", "length", "pan", "rate", "rate_slew"}
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
  track[i].filter_mode = 5
  track[i].cutoff = 1
  track[i].cutoff_hz = 12000
  track[i].filter_q = 4
  track[i].step = 0
  track[i].beat_num = DEFAULT_TRACK_LEN
  track[i].beat_num_new = DEFAULT_TRACK_LEN
  track[i].startpoint = 1 + (i - 1) * (MAX_TRACK_LEN + 1)
  track[i].loop_len = beat_sec * track[i].beat_num
  track[i].endpoint = track[i].startpoint + track[i].loop_len
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
  playhead[i].startpoint = 1 + (i - 1) * (MAX_TRACK_LEN + 1)
  playhead[i].loop_len = beat_sec * DEFAULT_TRACK_LEN
end

-- mash variables
local mash = {}
for i = 1, NUM_TRACKS do
  mash[i] = {}
  for s = 1, NUM_SLOTS do
    mash[i][s] = {}
    mash[i][s].pan_l = -1
    mash[i][s].pan_r = 1
    mash[i][s].srt_l = 1
    mash[i][s].srt_r = 10
    mash[i][s].len_l = 6
    mash[i][s].len_r = 4
    mash[i][s].rate_l = 1
    mash[i][s].rate_r = -1
    mash[i][s].rate_slew_l = 0
    mash[i][s].rate_slew_r = 0
  end
end

-- store all start- and endpoints
local mashpoint = {}
for i = 1, NUM_TRACKS do
  mashpoint[i] = {}
  for s = 1, NUM_SLOTS do
    mashpoint[i][s] = {}
    mashpoint[i][s].s_l = track[i].startpoint
    mashpoint[i][s].s_r = track[i].startpoint
    mashpoint[i][s].e_l = track[i].startpoint + track[i].loop_len
    mashpoint[i][s].e_r = track[i].startpoint + track[i].loop_len
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
function import_track(i, path)
  if path ~= "cancel" and path ~= "" then
    local ch, samples = audio.file_info(path)
    if ch > 0 and samples > 0 then
      local l = math.min(samples / 48000, MAX_TRACK_LEN)
      softcut.buffer_clear_region(track[i].startpoint - 0.1, MAX_TRACK_LEN + 0.1, FADE_TIME, 0)
      softcut.buffer_read_stereo(path, 0, track[i].startpoint, l, 0, 1)
      print("file loaded: "..path.." is "..l.."s")
    else
      print("not a sound file")
    end
    params:set("track_import_"..i, "", true)
  end
end

function export_track(txt)
  if txt then
    softcut.buffer_write_stereo(default_audio..txt..".wav", track[te_track].startpoint, track[te_track].loop_len)
    print("track saved: "..default_audio..txt..".wav")
  else
    print("save cancel")
  end
end

function make_mash(i, s)
  mash_active = true
  track[i].mash = true
  track[i].active_mash = s
  track[i].rec = false
  set_rec(i)
  local pos_l = mash[i][s].rate_l >= 0 and mashpoint[i][s].s_l or mashpoint[i][s].e_l
  local pos_r = mash[i][s].rate_r >= 0 and mashpoint[i][s].s_r or mashpoint[i][s].e_r
  softcut.pan(i, mash[i][s].pan_l)
  softcut.pan(i + 3, mash[i][s].pan_r)
  softcut.rate_slew_time(i, mash[i][s].rate_slew_l)
  softcut.rate_slew_time(i + 3, mash[i][s].rate_slew_r)
  softcut.rate(i, mash[i][s].rate_l)
  softcut.rate(i + 3, mash[i][s].rate_r)
  softcut.loop_start(i, mashpoint[i][s].s_l)
  softcut.loop_start(i + 3, mashpoint[i][s].s_r)
  softcut.loop_end(i, mashpoint[i][s].e_l)
  softcut.loop_end(i + 3, mashpoint[i][s].e_r)
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
  for s = 1, NUM_SLOTS do
    set_mash_points(i, s)
  end
end

-- update softcut params duing mash
function update_playhead(i, param, channel, value)
  if track[i].mash then
    local voice = channel == "l" and i or i + 3
    softcut[param](voice, value)
  end
end

-- calc start and endpoints for playheads
function set_mash_points(i, s)
  mashpoint[i][s].s_l = track[i].startpoint + (mash[i][s].srt_l - 1) / 16 * track[i].loop_len
  mashpoint[i][s].s_r = track[i].startpoint + (mash[i][s].srt_r - 1) / 16 * track[i].loop_len
  mashpoint[i][s].e_l = mashpoint[i][s].s_l + track[i].loop_len * mash[i][s].len_l
  mashpoint[i][s].e_r = mashpoint[i][s].s_r + track[i].loop_len * mash[i][s].len_r
  -- if mashing update loop points
  if track[i].mash and track[i].active_mash == s then
    softcut.loop_start(i, mashpoint[i][s].s_l)
    softcut.loop_start(i + 3, mashpoint[i][s].s_r)
    softcut.loop_end(i, mashpoint[i][s].e_l)
    softcut.loop_end(i + 3, mashpoint[i][s].e_r)
  end
end

function clamp_mash_start(i, s, ch)
  local start = params:get("mash_"..i.."_start_"..ch.."_"..s)
  local length = params:get("mash_"..i.."_length_"..ch.."_"..s)
  local max_start = 17 - length
  if start + length >= 17 then
    params:set("mash_"..i.."_start_"..ch.."_"..s, max_start)
  end
end

function clamp_mash_length(i, s, ch)
  local start = params:get("mash_"..i.."_start_"..ch.."_"..s)
  local length = params:get("mash_"..i.."_length_"..ch.."_"..s)
  local max_len = 17 - start
  if length >= max_len then
    params:set("mash_"..i.."_length_"..ch.."_"..s, max_len)
  end
end

function init_mash(i, s)
  local ch = {"l", "r"}
  for n = 1, 2 do
    params:set("mash_"..i.."_pan_"..ch[n].."_"..s, n == 1 and -1 or 1)
    params:set("mash_"..i.."_start_"..ch[n].."_"..s, 1)
    params:set("mash_"..i.."_length_"..ch[n].."_"..s, 16)
    params:set("mash_"..i.."_rate_"..ch[n].."_"..s, 11)
    params:set("mash_"..i.."_rate_slew_"..ch[n].."_"..s, 0)
  end
  dirtyscreen = true
end

function copy_mash(src, dst)
  local ch = {"l", "r"}
  for n = 1, 2 do
    params:set("mash_"..dst.i.."_pan_"..ch[n].."_"..dst.s, params:get("mash_"..src.i.."_pan_"..ch[n].."_"..src.s))
    params:set("mash_"..dst.i.."_start_"..ch[n].."_"..dst.s, params:get("mash_"..src.i.."_start_"..ch[n].."_"..src.s))
    params:set("mash_"..dst.i.."_length_"..ch[n].."_"..dst.s, params:get("mash_"..src.i.."_length_"..ch[n].."_"..src.s))
    params:set("mash_"..dst.i.."_rate_"..ch[n].."_"..dst.s, params:get("mash_"..src.i.."_rate_"..ch[n].."_"..src.s))
    params:set("mash_"..dst.i.."_rate_slew_"..ch[n].."_"..dst.s, params:get("mash_"..src.i.."_rate_slew_"..ch[n].."_"..src.s))
  end
  dirtyscreen = true
end

function randomize_mash(i, s, ch)
  local c = ch == 1 and "l" or "r"
  local start = ch == 1 and mash[i][s].srt_l or mash[i][s].srt_r
  params:set("mash_"..i.."_pan_"..c.."_"..s, (math.random() * 20 - 10) / 10)
  params:set("mash_"..i.."_start_"..c.."_"..s, math.random(1, 16))
  params:set("mash_"..i.."_length_"..c.."_"..s, math.random(1, 17 - start))
  params:set("mash_"..i.."_rate_"..c.."_"..s, math.random(1, 13))
  params:set("mash_"..i.."_rate_slew_"..c.."_"..s, math.random())
end

function set_filter_type(i, option)
  track[i].filter_mode = option
  local v = {i, i + 3}
  for n = 1, 2 do
    softcut.post_filter_lp(v[n], (option == 1 or option == 5) and 1 or 0) 
    softcut.post_filter_hp(v[n], option == 2 and 1 or 0) 
    softcut.post_filter_bp(v[n], option == 3 and 1 or 0) 
    softcut.post_filter_br(v[n], option == 4 and 1 or 0)
  end
  if option == 5 then
    params:set("track_cutoff_"..i, 0)
    set_djf(i, 0)
  elseif option < 5 then
    local val = util.explin(20, 12000, 0, 2, track[i].cutoff_hz) - 1
    params:set("track_cutoff_"..i, val)
  end
end

function set_cutoff(i, val)
  track[i].cutoff = val
  if track[i].filter_mode == 5 then
    set_djf(i, val)
  elseif track[i].filter_mode < 5 then
    local f = util.linexp(0, 2, 20, 12000, val + 1)
    softcut.post_filter_fc(i, f)
    softcut.post_filter_fc(i + 3, f)
    track[i].cutoff_hz = f
  end
end

function set_djf(i, val)
  local v = {i, i + 3}
  for n = 1, 2 do
    if val < -0.1 then -- lp
      local val = -val
      freq = util.linexp(0.1, 1, 12000, 80, val)
      softcut.post_filter_fc(v[n], freq)
      softcut.post_filter_lp(v[n], 1)
      softcut.post_filter_hp(v[n], 0)
    elseif val > 0.1 then -- hp
      freq = util.linexp(0.1, 1, 20, 8000, val)
      softcut.post_filter_fc(v[n], freq)
      softcut.post_filter_hp(v[n], 1)
      softcut.post_filter_lp(v[n], 0)
    else
      softcut.post_filter_fc(v[n], val > 0 and 20 or 12000)
      softcut.post_filter_lp(v[n], val > 0 and 0 or 1)
      softcut.post_filter_hp(v[n], val > 0 and 1 or 0)
    end
  end
end

function set_filter_q(i, val) -- from ezra's softcut eq class (thank you!)
  track[i].filter_q = val 
  local x = 1 - val
  local rq = 2.15821131e-01 + (x * 2.29231176e-09) + (x * x * 3.41072934)
  softcut.post_filter_rq(i, rq)
  softcut.post_filter_rq(i + 3, rq)
end

function set_softcut_input(i, option)
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
  softcut.buffer_clear_region_channel(1, track[i].startpoint - 0.2, MAX_TRACK_LEN + 0.2)
  softcut.buffer_clear_region_channel(2, track[i].startpoint - 0.2, MAX_TRACK_LEN + 0.2)
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
    if track[i].mash then
      local s = track[i].active_mash
      local pos_l = mash[i][s].rate_l >= 0 and mashpoint[i][s].s_l or mashpoint[i][s].e_l
      local pos_r = mash[i][s].rate_r >= 0 and mashpoint[i][s].s_r or mashpoint[i][s].e_r
      softcut.position(i, pos_l)
      softcut.position(i + 3, pos_r)
    else
      reset_track_pos(i)
    end
  end
  is_running = true
end

function stop_all()
  for i = 1, NUM_TRACKS do
    track[i].monitor = false
    track[i].prev_rec = false
    track[i].amsh_active = false
    track[i].amsh_queued = false
    track[i].hold = false
    reset_track(i)
  end
  for i = 1, NUM_PATTERNS do
    pattern[i]:stop()
  end
  if is_running then
    screen_message = 3
    dirtyscreen = true
    clock.run(function()
      clock.sleep(0.8)
      screen_message = 0
      dirtyscreen = true
    end)
  end
  is_running = false
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
    if track[i].amsh_active then
      if track[i].amsh_pattern[track[i].amsh_step].prob == 0 and track[i].mash then
        track[i].prev_rec = true
        reset_track(i)
      elseif track[i].amsh_pattern[track[i].amsh_step].step then
        if math.random(100) <= track[i].amsh_pattern[track[i].amsh_step].prob then
          local collection = track[i].amsh_pattern[track[i].amsh_step].pool
          local idx = math.random(1, #collection)
          local slot = collection[idx]
          make_mash(i, slot)
        elseif track[i].mash then
          track[i].prev_rec = true
          reset_track(i)
        end
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
      make_mash(e.i, e.s)
      pattern[e.p].active_mash[e.i] = e.s
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
  pattern[i].end_of_rec_callback = function() end
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
    clock.sleep(1/30)
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
  -- make folder
  if util.file_exists(default_audio) == false then
    util.make_dir(default_audio)
  end

  -- check for arc
  if a.device then
    arc_conncted = true
  end

  -- get beat sec (clock.get_beat_sec() ain't workin')
  beat_sec = 60 / params:get("clock_tempo")

  -- get midi devices
  build_midi_device_list()

  -- init softcut
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

  -- add params
  params:add_separator("script_params", "s t w n s h")

  params:add_group("global_params", "global settings", 10)

  params:add_separator("timing_params", "timing")
    
  params:add_number("time_signature", "time signature", 2, 9, 4, function(param) return param:get().."/4" end)
  params:set_action("time_signature", function(val) bar_val = val end)

  params:add_option("key_quantization", "key quantization", options.key_quant_names, 2)
  params:set_action("key_quantization", function(idx) quantize_rate = options.key_quant_values[idx] end)

  params:add_separator("source_params", "audio source")

  params:add_option("adc_source", "adc", {"off", "on"}, 2)
  params:set_action("adc_source", function(mode) audio.level_adc_cut(mode - 1) end)

  params:add_option("eng_source", "engine", {"off", "on"}, 1)
  params:set_action("eng_source", function(mode) audio.level_eng_cut(mode - 1) end)

  params:add_option("tape_source", "tape", {"off", "on"}, 1)
  params:set_action("tape_source", function(mode) audio.level_tape_cut(mode - 1) end)

  params:add_separator("midi_params", "midi")

  params:add_option("midi_transport", "midi transport", {"off", "send", "recieve"}, 1)
  params:set_action("midi_transport", function(mode) midi_trns = mode end)

  params:add_option("midi_device", "midi device", midi_devices, 1)
  params:set_action("midi_device", function(val) m = midi.connect(val) end)


  local name = {"[ONE]", "[TWO]", "[TRI]"}
  for i = 1, NUM_TRACKS do
    params:add_group("track_"..i, "track "..name[i], 17)
    -- load and save
    params:add_separator("track_audio_"..i, "track "..name[i].." audio")

    params:add_file("track_import_"..i, "> import", "")
    params:set_action("track_import_"..i, function(path) import_track(i, path) end)

    params:add_trigger("track_export_"..i, "< export")
    params:set_action("track_export_"..i, function() te_track = i _t.enter(export_track) end)
    
    -- track settings
    params:add_separator("track_settings_"..i, "track "..name[i].." settings")
    
    params:add_number("track_length_"..i, "track length", 1, 64, 4, function(param) return param:get()..(param:get() > 1 and " beats" or " beat") end)
    params:set_action("track_length_"..i, function(x)
      track[i].beat_num_new = x
      if not is_running then
        set_track_len(i, track[i].beat_num_new)
      end
    end)
    
    params:add_option("input_src_"..i, "input source", {"stereo", "mono l", "mono r"}, 1)
    params:set_action("input_src_"..i, function(option) set_softcut_input(i, option) end)
    
    params:add_control("track_level_"..i, "track level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end)
    params:set_action("track_level_"..i, function(x) track[i].level = x set_level(i) if track_edit then dirtyscreen = true end end)
   
    params:add_control("rec_level_"..i, "rec level", controlspec.new(0, 1, "lin", 0, 1), function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end)
    params:set_action("rec_level_"..i, function(x) track[i].rec_level = x set_rec(i) end)
    
    params:add_control("dub_level_"..i, "overdub level", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(util.linlin(0, 1, 0, 100, param:get()), 1, "%") end)
    params:set_action("dub_level_"..i, function(x) track[i].dub_level = x set_rec(i) if track_edit then dirtyscreen = true end end)
    
    params:add_option("track_fliter_type_"..i, "filter type", {"low pass", "high pass", "band pass", "band reject", "dj"}, 1)
    params:set_action("track_fliter_type_"..i, function(option) set_filter_type(i, option) end)
    
    params:add_control("track_cutoff_"..i, "filter cutoff", controlspec.new(-1, 1, "lin", 0, 1), function(param) return cutoff_display(i, param:get()) end)
    params:set_action("track_cutoff_"..i, function(x) set_cutoff(i, x) if track_edit then dirtyscreen = true end end)
   
    params:add_control("track_rq_"..i, "filter q", controlspec.new(0, 1, "lin", 0, 0.2), function(param) return (round_form(param:get() * 100, 1, "%")) end)
    params:set_action("track_rq_"..i, function(x) set_filter_q(i, x) if track_edit then dirtyscreen = true end end)

    -- track remote control
    params:add_separator("track_control_"..i, "track "..name[i].." control")

    params:add_binary("track_toggle_amsh_"..i, "> toggle auto mash", "trigger", 0)
    params:set_action("track_toggle_amsh_"..i, function() toggle_amsh(i) end)

    params:add_binary("track_toggle_rec_"..i, "> toggle rec", "trigger", 0)
    params:set_action("track_toggle_rec_"..i, function() track[i].rec = not track[i].rec set_rec(i) end)

    params:add_binary("track_toggle_oneshot_"..i, "> toggle oneshot", "trigger", 0)
    params:set_action("track_toggle_oneshot_"..i, function() track[i].oneshot = not track[i].oneshot end)

    params:add_binary("track_toggle_monitor_"..i, "> toggle monitor", "trigger", 0)
    params:set_action("track_toggle_monitor_"..i, function() toggle_monitor(i) end)
  end

  -- mash slots
  for i = 1, NUM_TRACKS do
    params:add_group("track_"..i.."_slots", "track "..i.." slots"..i, 90)
    params:hide("track_"..i.."_slots")
    for s = 1, NUM_SLOTS do
      params:add_control("mash_"..i.."_pan_l_"..s, "pan left", controlspec.new(-1, 1, "lin", 0, -1), function(param) return pan_display(param:get()) end)
      params:set_action("mash_"..i.."_pan_l_"..s, function(x) mash[i][s].pan_l = x update_playhead(i, "pan", "l", x) end)

      params:add_control("mash_"..i.."_pan_r_"..s, "pan right", controlspec.new(-1, 1, "lin", 0, 1), function(param) return pan_display(param:get()) end)
      params:set_action("mash_"..i.."_pan_r_"..s, function(x) mash[i][s].pan_r = x update_playhead(i, "pan", "r", x) end)

      params:add_number("mash_"..i.."_start_l_"..s, "startpoint left", 1, 16, 1)
      params:set_action("mash_"..i.."_start_l_"..s, function(x) mash[i][s].srt_l = x clamp_mash_start(i, s, "l") set_mash_points(i, s) end)

      params:add_number("mash_"..i.."_start_r_"..s, "startpoint right", 1, 16, 1)
      params:set_action("mash_"..i.."_start_r_"..s, function(x) mash[i][s].srt_r = x clamp_mash_start(i, s, "r") set_mash_points(i, s) end)

      params:add_option("mash_"..i.."_length_l_"..s, "length left", options.mash_length_names, 1)
      params:set_action("mash_"..i.."_length_l_"..s, function(x) mash[i][s].len_l = options.mash_length_values[x] clamp_mash_length(i, s, "l") set_mash_points(i, s) end)

      params:add_option("mash_"..i.."_length_r_"..s, "length right", options.mash_length_names, 1)
      params:set_action("mash_"..i.."_length_r_"..s, function(x) mash[i][s].len_r = options.mash_length_values[x] clamp_mash_length(i, s, "r") set_mash_points(i, s) end)

      params:add_option("mash_"..i.."_rate_l_"..s, "rate left", options.rate_names, 11)
      params:set_action("mash_"..i.."_rate_l_"..s, function(x) mash[i][s].rate_l = options.rate_values[x] update_playhead(i, "rate", "l", mash[i][s].rate_l) end)

      params:add_option("mash_"..i.."_rate_r_"..s, "rate right", options.rate_names, 11)
      params:set_action("mash_"..i.."_rate_r_"..s, function(x) mash[i][s].rate_r = options.rate_values[x] update_playhead(i, "rate", "r", mash[i][s].rate_r) end)

      params:add_control("mash_"..i.."_rate_slew_l_"..s, "rate slew left", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get(), 0.01, "s") end)
      params:set_action("mash_"..i.."_rate_slew_l_"..s, function(x) mash[i][s].rate_slew_l = x update_playhead(i, "rate_slew_time", "l", x) end)

      params:add_control("mash_"..i.."_rate_slew_r_"..s, "rate slew right", controlspec.new(0, 1, "lin", 0, 0), function(param) return round_form(param:get(), 0.01, "s") end)
      params:set_action("mash_"..i.."_rate_slew_r_"..s, function(x) mash[i][s].rate_slew_r = x update_playhead(i, "rate_slew_time", "r", x) end)
    end
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

  -- fx separator
  if _m.is_loaded("fx") then
    params:add_separator("fx_params", "fx")
  end

  -- pset callbacks
  params.action_write = function(filename, name, number)
    os.execute("mkdir -p "..norns.state.data.."presets/"..number.."/")
    local pset_data = {}
    pset_data.pattern = {}
    pset_data.audio = {}
    pset_data.amsh = {}
    for i = 1, 4 do
      pset_data.pattern[i] = {}
      pset_data.pattern[i].count = pattern[i].count
      pset_data.pattern[i].event = deep_copy(pattern[i].event)
      pset_data.pattern[i].endpoint = pattern[i].endpoint
    end
    for i = 1, NUM_TRACKS do
      -- save audio
      local path_audio = norns.state.data.."presets/"..number.."/"..name.."_"..i..".wav"
      softcut.buffer_write_stereo(path_audio, track[i].startpoint - 0.1, track[i].loop_len + 0.2)
      pset_data.audio[i] = path_audio
      -- save automash data
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
      tab.save(pset_data, norns.state.data.."presets/"..number.."/"..name..".data")
      print("finished writing pset:'"..name.."'")
    end)
  end

  params.action_read = function(filename, silent, number)
    local loaded_file = io.open(filename, "r")
    if loaded_file then
      io.input(loaded_file)
      local pset_id = string.sub(io.read(), 4, -1)
      io.close(loaded_file)
      local pset_data = tab.load(norns.state.data.."presets/"..number.."/"..pset_id..".data")
      -- load patterns
      for i = 1, 4 do
        pattern[i].count = pset_data.pattern[i].count
        pattern[i].event = deep_copy(pset_data.pattern[i].event)
        pattern[i].endpoint = pset_data.pattern[i].endpoint
      end
      for i = 1, NUM_TRACKS do
        -- load audio
        if util.file_exists(pset_data.audio[i]) then
          softcut.buffer_read_stereo(pset_data.audio[i], 0, track[i].startpoint - 0.1, -1, 0, 1)
        else
          print("no audio file")
        end
        -- load automash data
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
    for i = 1, NUM_TRACKS do
      for s = 1, NUM_SLOTS do
        for ch = 1, 2 do
          randomize_mash(i, s, ch)
        end
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
        randomize_mash(track_focus, mash_focus, 1)
      else
        mash_param = util.wrap(mash_param - 1, 1, #mash_names)
      end
    elseif n == 3 and z == 1 then
      if shift then
        randomize_mash(track_focus, mash_focus, 2)
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
          screen_message = 0
          dirtyscreen = true
          if midi_trns == 2 then
            m:start()
          end
          transport_clock = nil
        end)
      end
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
    if shift then
      arc_track_mode = d > 0 and true or false
    else
      if arc_track_mode then
        arc_focus = util.clamp(arc_focus + d, 1, 3)
      else
        arc_all = d > 0 and true or false
      end
    end
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
      params:delta("mash_"..track_focus.."_"..mash_params[mash_param].."_l_"..mash_focus, d) 
    elseif n == 3 then
      params:delta("mash_"..track_focus.."_"..mash_params[mash_param].."_r_"..mash_focus, d) 
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
    screen.text_center("EDIT   MASH   SLOT   "..mash_focus)
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
    screen.text_center(params:string("mash_"..track_focus.."_"..mash_params[mash_param].."_l_"..mash_focus))
    screen.move(98, 39)
    screen.text_center(params:string("mash_"..track_focus.."_"..mash_params[mash_param].."_r_"..mash_focus))

  elseif pattern_edit then
    -- patterm params
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("EDIT   PATTERN   "..pattern_focus)
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
    screen.text_center("STEP  "..amsh_step_edit.."    PROBABILITY")
    screen.font_size(32)
    screen.move(64, 48)
    screen.text_center(track[track_focus].amsh_pattern[amsh_step_edit].prob.."%")
  elseif amsh_rate_edit then
    screen.font_face(2)
    screen.font_size(8)
    screen.level(15)
    screen.move(64, 12)
    screen.text_center("STEP   RATE")
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

function reset_mash_copy()
  if not (modkey or quantize_edit) then
    mash_src = {}
    if mash_init_clk ~= nil then
      clock.cancel(mash_init_clk)
    end
  end
end

function g.key(x, y, z)
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
            track[y].amsh_step_max = x
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
          reset_track_pos(y)
          screen_message = 0
          dirtyscreen = true
        end)
      elseif modkey and quantize_edit and z == 1 then
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
  else
    if x < 13 then
      local i = x > 8 and 3 or (x > 4 and 2 or 1)
      if y == 5 then
        if (x == 1 or x == 5 or x == 9) and z == 1 and not track[i].amsh_active then
          track[i].rec = not track[i].rec
          if not track[i].mash then
            set_rec(i)
          end
        elseif (x == 2 or x == 6 or x == 10) and z == 1 and not track[i].amsh_active then
          track[i].oneshot = not track[i].oneshot      
          if track[i].rec and track[i].oneshot and not track[i].mash then
            track[i].rec = false
            set_rec(i)
          end
        elseif (x == 3 or x == 7 or x == 11) and z == 1 and not track[i].amsh_active then
          track[i].hold = not track[i].hold
          if not track[i].hold and heldkey[i] < 1 then
            track[i].prev_rec = (track[i].rec or track[i].oneshot) and true or false
            reset_track(i)
          end
        elseif (x == 4 or x == 8 or x == 12) then
          if z == 1 and not mash_edit then
            track_focus = i
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
      elseif y > 5 and y < 9 then
        if (x < 4 or (x > 4 and x < 8) or (x > 8 and x < 12)) then
          local s = (x - ((i - 1) * 4)) + (y - 6) * 3
          heldkey[i] = heldkey[i] + (z * 2 - 1)
          track_focus = i
          mash_focus = s
          if amsh_step_edit > 0 then
            local collection = track[i].amsh_pattern[amsh_step_edit].pool
            if z == 1 then
              if tab.contains(collection, s) then
                table.remove(collection, tab.key(collection, s))
              else
                table.insert(collection, s)
              end
            end
          else
            if modkey and quantize_edit and mash_edit then
              if z == 1 then
                if next(mash_src) then
                  mash_dst.i = i
                  mash_dst.s = s
                  copy_mash(mash_src, mash_dst)
                  mash_src = {}
                else
                  mash_src.i = i
                  mash_src.s = s
                end
                if mash_init_clk ~= nil then
                  clock.cancel(mash_init_clk)
                end
                mash_init_clk = clock.run(function()
                  clock.sleep(1)
                  init_mash(i, s)
                end)
              else
                if mash_init_clk ~= nil then
                  clock.cancel(mash_init_clk)
                end
              end
            else
              if mash_edit then
                if modkey and z == 1 then
                  for ch = 1, 2 do
                    randomize_mash(i, s, ch)
                  end
                  mash_focus = s
                  dirtyscreen = true
                end
              end
              track[i].mash = (z == 1 or track[i].hold or heldkey[i] > 0) and true or false
              if track[i].mash then
                if z == 1 then
                  local e = {t = eMASH, i = i, s = s, p = pattern_focus}
                  table.insert(quantize_event, e)
                end
              else
                local e = {t = eRSET, i = i, p = pattern_focus}
                table.insert(quantize_event, e)
              end
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
        end
      end
    elseif x > 12 then
      if x == 13 and y == 5 then
        pattern_overdub = z == 1 and true or false
        if pattern_overdub then
          pattern_clear = false
        end
      elseif x == 14 and y == 5 then
        pattern_clear = z == 1 and true or false
        if pattern_clear then
          pattern_overdub = false
        end
      end
      if (x == 13 or x == 14) and (y > 5 and y < 8) and z == 1 then
        if num_rec_enabled() == 0 then
          pattern_focus = (x - 12) + (y - 6) * 2
        end
        if pattern_edit then
          dirtyscreen = true
        else
          gridkey_patterns(pattern_focus)
        end
      end
      if y < 8 and x == 15 and z == 1 then
        local n = y - 4
        toggle_amsh(n)
      elseif y < 8 and x == 16 and z == 1 then
        local n = y - 4
        toggle_monitor(n)
      end
      if y == 8 and x == 13 and z == 1 then
        mash_edit = not mash_edit 
        if mash_edit then
          if pattern_edit then pattern_edit = false end
          for n = 1, 3 do
            track[n].amsh_edit = false
          end
        end
        dirtyscreen = true
      elseif y == 8 and x == 14 and z == 1 then
        pattern_edit = not pattern_edit
        if pattern_edit and mash_edit then
          mash_edit = false
        end
        dirtyscreen = true
      end
      if y == 8 and x == 15 then
        modkey = z == 1 and true or false
        reset_mash_copy()
        dirtyscreen = true
      elseif y == 8 and x == 16 then
        quantize_edit = z == 1 and true or false
        reset_mash_copy()
        dirtyscreen = true
      end
    end
  end
  dirtygrid = true
end

function gridredraw()
  g:all(0)
  -- view track lanes
  for i = 1, NUM_TRACKS do
    if track[i].amsh_edit then
      for x = 1, 16 do
        if x <= track[i].amsh_step_max then
          g:led(x, i, track[i].amsh_step == x and 12 or (track[i].amsh_pattern[x].prob == 0 and 1 or (track[i].amsh_pattern[x].step and 8 or 4)))
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
      local src = next(mash_src) and (mash_src.s == slot) or false
      if (mash_edit and track_focus == i) or not mash_edit then
        if slot > 0 and slot < 4 then
          g:led((slot - 4) + 4 * i, 6, src and pulse_key_slow or 15)
        elseif slot > 3 and slot < 7 then
          g:led((slot - 7) + 4 * i, 7, src and pulse_key_slow or 15)
        elseif slot > 6 then
          g:led((slot - 10) + 4 * i, 8, src and pulse_key_slow or 15)
        end
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
    g:led(i * 4, 5, track[i].amsh_edit and pulse_key_slow or 0)
    g:led(track_focus * 4, i + 5, (track_edit and track_param == i) and 8 or 0)
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

--------- arc UI ----------

function a.key(n, z)
  if n == 1 then
    if z == 1 then
      if arc_track_mode then
        arc_focus = util.wrap(arc_focus + 1, 1, 3)
      else
        arc_all = not arc_all
      end
      if arc_mode_clk ~= nil then
        clock.cancel(arc_mode_clk)
      end
      arc_mode_clk = clock.run(function()
        clock.sleep(1)
        arc_track_mode = not arc_track_mode
      end)
    else
      if arc_mode_clk ~= nil then
        clock.cancel(arc_mode_clk)
      end
    end
  end
end

function a.delta(n, d)
  if arc_track_mode then
    params:delta(arc_params[n]..arc_focus, d / 20)
  else
    if n == 4 then
      if arc_all then
        for i = 1, 3 do
          params:delta(arc_params[arc_param]..i, d / 20)
        end
      else
        arc_inc = (arc_inc + 1) % 20
        if arc_inc == 0 then
          local inc = d > 0 and -1 or 1
          arc_param = util.clamp(arc_param + inc, 1, 4)
        end
      end
    else
      params:delta(arc_params[arc_param]..n, d / 20)
    end
  end
end

local function arc_draw_dj(n, val)
  a:led(n, 1, 7)
  a:led(n, 25, 5)
  a:led(n, -23, 5)
  if val > 0 then
    for i = 2, val do
      a:led(n, i, 4)
    end
  elseif val < 0 then
    for i = val + 2, 0 do
      a:led(n, i, 4)
    end
  end
  a:led(n, val + 1, 15)
end

local function arc_draw_param(n, val)
  a:led(n, 25, 5)
  a:led(n, -23, 5)
  for i = -22, 24 do
    if i < val - 64 then
      a:led(n, i, 3)
    end
  end
  a:led(n, val, 15)
end

function arc_redraw()
  a:all(0)
  if arc_track_mode then
    arc_draw_param(1, math.floor(track[arc_focus].level * 48) + 41)
    arc_draw_param(2, math.floor(track[arc_focus].dub_level * 48) + 41)
    if track[arc_focus].filter_mode == 5 then
      arc_draw_dj(3, math.floor(track[arc_focus].cutoff * 24))
    else
      arc_draw_param(3, math.floor(util.explin(20, 12000, 0, 1, track[arc_focus].cutoff_hz) * 48) + 41)
    end
    arc_draw_param(4, math.floor(track[arc_focus].filter_q * 48) + 41)
    for n = 1, 4 do
      a:led(n, 32, arc_focus == 3 and 15 or 4)
      a:led(n, 33, arc_focus == 2 and 15 or 4)
      a:led(n, 34, arc_focus == 1 and 15 or 4)
    end
  else
    if arc_vars[arc_param] == "cutoff" then
      for n = 1, 3 do
        if track[n].filter_mode == 5 then
          local val = math.floor(track[n].cutoff * 24)
          arc_draw_dj(n, val)
        else
          local val = math.floor(util.explin(20, 12000, 0, 1, track[n].cutoff_hz) * 48) + 41
          arc_draw_param(n, val)
        end
      end
    else
      for n = 1, 3 do
        local val = math.floor(track[n][arc_vars[arc_param]] * 48) + 41
        arc_draw_param(n, val)
      end
    end
    if arc_all then
      -- delta all
    else
      -- view modes
      for n = 1, 4 do
        local off = (n - 1) * 5
        a:led(4, 25 + off + 1, arc_param == (5 - n) and 8 or 3)
        a:led(4, 25 + off, arc_param == (5 - n) and 15 or 5)
        a:led(4, 25 + off - 1, arc_param == (5 - n) and 8 or 3)
      end
    end
  end
  a:refresh()
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
  if arc_conncted then
    arc_redraw()
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
  if param < -0.01 then
    pos_right = ""
    pos_left = "< "
  elseif param > 0.01 then
    pos_right = " >"
    pos_left = ""
  end
  return (pos_left..math.abs(util.round(util.linlin(-1, 1, -100, 100, param), 1))..pos_right)
end

function cutoff_display(i, param)
  if track[i].filter_mode == 5 then
    if param < -0.1 then
      local p = math.abs(util.round(util.linlin(-1, -0.1, -100, -1, param), 1))
      return "lp < " ..p
    elseif param > 0.1 then
      local p = math.abs(util.round(util.linlin(0.1, 1, 1, 100, param), 1))
      return p.." > hp"
    else
      return "|"
    end
  else
    return (round_form(track[i].cutoff_hz, 1, " hz"))
  end
end

function build_menu(i)
  _menu.rebuild_params()
  dirtyscreen = true
end

function show_banner()
  local banner = {
    {0, 0, 1, 1, 1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0},
    {1, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 1},
    {1, 0, 0, 1, 0, 0, 1, 1, 1, 0, 1, 0, 0, 1, 0, 1},
    {0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 1, 1},
    {0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1},
    {1, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 1, 0, 1},
    {0, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 0},
    {0, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0}
  }
  g:all(0)
  for x = 1, 16 do
    for y = 1, 8 do
      g:led(x, y, banner[y][x] * math.random(4, 8))
    end
  end
  g:refresh()
end

--------- cleanup ----------
function cleanup()
  show_banner()
  print("cleaned up the mash")
end
