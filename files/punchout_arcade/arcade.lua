local BASE = "mods/recocards_birthday/files/punchout_arcade/"

local ARCADE_X = -683
local ARCADE_Y = 5003

local RAT_X = 142
local RAT_Y = 36
local RAT_SCALE = 0.648
local DUNK_X = 164
local DUNK_Y = 106
local DUNK_SCALE = 0.72

dofile_once("data/scripts/debug/keycodes.lua")
local AUDIO_GUIDS=BASE.."files/audio/GUIDs.txt"
local function play_sfx(name)
 local x,y=ARCADE_X,ARCADE_Y
 if S and S.player and S.player~=0 and EntityGetIsAlive(S.player) then
  x,y=EntityGetTransform(S.player)
 end
 local ok,err=pcall(GamePlaySound,BASE.."files/audio/PunchOut.snd","PunchOut/"..tostring(name),x,y)
 if not ok then print("[Punch-Out v0.11.2] sound "..tostring(name)..": "..tostring(err)) end
end
local MUSIC_TAG="punchout_match_music"
local function stop_match_music()
 local es=EntityGetWithTag(MUSIC_TAG) or {}
 for _,e in ipairs(es) do if EntityGetIsAlive(e) then EntityKill(e) end end
end
local function start_match_music()
 stop_match_music()
 local e=EntityCreateNew("punchout_match_music")
 EntityAddTag(e,MUSIC_TAG)
 local x,y=ARCADE_X,ARCADE_Y
 if S and S.player and S.player~=0 and EntityGetIsAlive(S.player) then x,y=EntityGetTransform(S.player) end
 EntitySetTransform(e,x,y)
 EntityAddComponent2(e,"AudioComponent",{
  file=BASE.."files/audio/PunchOut.snd",
  event_root="PunchOut",
  set_latest_event_position=false,
  remove_latest_event_on_destroyed=true,
  send_message_on_event_dead=false,
  play_only_if_visible=false,
 })
end
local RESULT_TAG="punchout_result_jingle"
local function stop_result_jingle()
 local es=EntityGetWithTag(RESULT_TAG) or {}
 for _,e in ipairs(es) do if EntityGetIsAlive(e) then EntityKill(e) end end
end
local function start_result_jingle(kind)
 stop_result_jingle()
 local root=(kind=="win") and "PunchOut/Win" or "PunchOut/Lose"
 local e=EntityCreateNew("punchout_result_jingle")
 EntityAddTag(e,RESULT_TAG)
 local x,y=ARCADE_X,ARCADE_Y
 if S and S.player and S.player~=0 and EntityGetIsAlive(S.player) then x,y=EntityGetTransform(S.player) end
 EntitySetTransform(e,x,y)
 EntityAddComponent2(e,"AudioComponent",{
  file=BASE.."files/audio/PunchOut.snd",
  event_root=root,
  set_latest_event_position=false,
  remove_latest_event_on_destroyed=true,
  send_message_on_event_dead=false,
  play_only_if_visible=false,
 })
end
local WIN_KEY="punchout_arcade_win_counter"
local HP_KEY="punchout_arcade_carry_hp"
local function get_wins()
 local n=tonumber(GlobalsGetValue(WIN_KEY,"0")) or 0
 return math.max(0,math.min(5,math.floor(n)))
end
local function set_wins(n) GlobalsSetValue(WIN_KEY,tostring(math.max(0,math.min(5,math.floor(n or 0))))) end
local function reset_wins() set_wins(0)
GlobalsSetValue(HP_KEY,"100") end
local function get_round_hp()
 if get_wins()<=0 then return 100 end
 return math.max(1,math.min(100,tonumber(GlobalsGetValue(HP_KEY,"100")) or 100))
end
local function set_round_hp(n) GlobalsSetValue(HP_KEY,tostring(math.max(1,math.min(100,math.floor(n or 100))))) end
local gui=nil
local S={active=false,phase="idle",machine=0,player=0,lock_x=0,lock_y=0,p_hp=100,t_hp=100,timer=99,
 p_state="idle",p_until=0,t_state="idle",t_until=0,next_attack=0,attack=nil,result="",last_frame=0,
 feedback="",feedback_until=0,shake_until=0,shake_power=0,hitstop_until=0,flash_until=0,punch_side=0,
 t_anim_start=0,t_anim_name="idle",hurt_variant="left",invuln_until=0,counter_until=0,dodged_attack=false,dodge_dir="",dodge_start=-9999,countin_start=0,reward_given=false,reward_line="",reward_level=0}
local function get_player() local p=EntityGetWithTag("player_unit")
return (p and #p>0) and p[1] or 0 end
local function destroy_gui() if gui then GuiDestroy(gui)
gui=nil end end
local function key(code) if not InputIsKeyJustDown or not code then return false end
local ok,v=pcall(InputIsKeyJustDown,code)
return ok and v==true end
local function controls(p) return EntityGetFirstComponentIncludingDisabled(p,"ControlsComponent") end
local function interact(c) return c and ComponentGetValue2(c,"mButtonFrameInteract")==GameGetFrameNum() end
local function set_text(e,t) if e==0 or not EntityGetIsAlive(e) then return end
for _,c in ipairs(EntityGetComponentIncludingDisabled(e,"InteractableComponent") or {}) do ComponentSetValue2(c,"ui_text",t) end end
local function ensure_machine() local p=get_player()
if p==0 then return end
local x,y=EntityGetTransform(p)
if math.abs(x-ARCADE_X)>750 or math.abs(y-ARCADE_Y)>750 then return end
if #(EntityGetInRadiusWithTag(ARCADE_X,ARCADE_Y,80,"punchout_arcade_machine") or {})==0 then EntityLoad(BASE.."files/arcade_machine.xml",ARCADE_X,ARCADE_Y) end end
local function reset_fight()
 stop_result_jingle()
 local f=GameGetFrameNum()
S.phase="countin"
S.countin_start=f
S.p_hp=get_round_hp()
S.t_hp=100
S.timer=99
S.p_state="idle"
S.p_until=0
 S.t_state="idle"
S.t_until=0
S.next_attack=0
S.attack=nil
S.result=""
S.last_frame=f
S.feedback=""
S.feedback_until=0
 S.shake_until=0
S.hitstop_until=0
S.flash_until=0
S.t_anim_start=f
S.t_anim_name="idle"
S.hurt_variant="left"
S.invuln_until=0
S.counter_until=0
S.dodged_attack=false
S.dodge_dir=""
S.dodge_start=-9999
S.reward_given=false
S.reward_line=""
S.reward_level=0
end
local function start_game(p,m) destroy_gui()
S.active=true
S.player=p
S.machine=m
S.lock_x,S.lock_y=EntityGetTransform(p)
set_text(m,"$punchout_arcade_quit")
reset_fight() end
local function stop_game() stop_match_music()
stop_result_jingle()
destroy_gui()
if S.machine~=0 then set_text(S.machine,"$punchout_arcade_play") end
if S.player~=0 and EntityGetIsAlive(S.player) then EntitySetTransform(S.player,S.lock_x,S.lock_y) end
S.active=false
S.phase="idle"
S.machine=0
S.player=0 end
local ATTACKS={
 {name="left",kind="punch",wind=26,strike=7,recover=30,dmg=16},
 {name="right",kind="punch",wind=26,strike=7,recover=30,dmg=16},
 {name="upper",kind="upper",wind=43,strike=8,recover=36,dmg=38},
}
local function fx(text,frames,shake,hitstop) local f=GameGetFrameNum()
S.feedback=text or ""
S.feedback_until=f+(frames or 16)
S.shake_until=f+(frames or 10)
S.shake_power=shake or 0
S.hitstop_until=f+(hitstop or 0)
S.flash_until=0 end
local function hurt_player(d) play_sfx("hit_dunk")
S.p_hp=math.max(0,S.p_hp-d)
S.p_state="hurt"
S.p_until=GameGetFrameNum()+25
fx("WHAM!  -"..d,20,4,4)
if S.p_hp<=0 then S.phase="lost"
reset_wins()
S.result="K.O. - RAT WINS"
S.p_state="ko"
stop_match_music()
start_result_jingle("lose") end end
local function hurt_tyson(d,variant) play_sfx("hit_tyson")
S.t_hp=math.max(0,S.t_hp-d)
S.t_state="hurt"
S.t_anim_start=GameGetFrameNum()
S.t_until=GameGetFrameNum()+22
S.hurt_variant=variant or "left"
fx("COUNTER!  -"..d,20,3,4)
if S.t_hp<=0 then S.phase="won"
S.result="K.O. - DUNK WINS"
S.t_state="down"
S.t_anim_start=GameGetFrameNum()
stop_match_music()
start_result_jingle("win") end end
local function player_action(k)
 local f=GameGetFrameNum()
if S.phase~="fight" then return end
 local live_counter=(k=="punch" and (S.t_state=="recover" or (S.t_state=="strike" and S.dodged_attack)) and S.counter_until>0 and f<=S.counter_until)
 if S.p_until>f and not live_counter then
  if (S.p_state=="dodge_l" or S.p_state=="dodge_r" or S.p_state=="duck") and
     (k=="left" or k=="right" or k=="duck") then
   S.invuln_until=math.min(S.invuln_until or f,f+2)
   S.feedback="COMMITTED!"
S.feedback_until=f+10
  end
  return
 end
 if k=="left" or k=="right" or k=="duck" then
  if S.t_state=="windup" and S.attack then
   local remaining=S.t_until-f
   local preferred_input=(S.attack.kind=="punch") and
     ((S.attack.name=="right" and k=="right") or (S.attack.name=="left" and k=="left"))
   local cutoff
   if S.attack.kind=="upper" then cutoff=10
   else cutoff=5 end
   if remaining<=cutoff then
    S.feedback="TOO LATE!"
S.feedback_until=f+12
    return
   end
  end
  S.p_state=(k=="left" and "dodge_l") or (k=="right" and "dodge_r") or "duck"
  S.dodge_dir=k
  S.dodge_start=f
  S.p_until=f+24
  if k=="left" or k=="right" then S.invuln_until=f+18 end
  return
 end
 S.punch_side=1-S.punch_side
S.p_state=(S.punch_side==0) and "jab_l" or "jab_r"
S.p_until=f+13
 play_sfx("dunk_punch")
 if (S.t_state=="recover" or (S.t_state=="strike" and S.dodged_attack)) and S.counter_until>=f then
  S.counter_until=0
hurt_tyson(20,(S.punch_side==0) and "right" or "left")
 else
  play_sfx("block")
  fx("BLOCKED!",10,0,0)
  if S.t_state=="idle" then S.t_state="block"
S.t_anim_start=f
S.t_until=f+10 end
 end
end
local function drop_gold_value(x,y,total)
 local values={200000,10000,1000,200,50,10}
 local paths={
  [200000]="data/entities/items/pickup/goldnugget_200000.xml",
  [10000]="data/entities/items/pickup/goldnugget_10000.xml",
  [1000]="data/entities/items/pickup/goldnugget_1000.xml",
  [200]="data/entities/items/pickup/goldnugget_200.xml",
  [50]="data/entities/items/pickup/goldnugget_50.xml",
  [10]="data/entities/items/pickup/goldnugget_10.xml"
 }
 local left=total
 local n=0
 for _,v in ipairs(values) do
  while left>=v do
   n=n+1
   EntityLoad(paths[v],x+18+(n%5)*5,y-12-(n%3)*4)
   left=left-v
  end
 end
end
local function give_win_reward()
 if S.reward_given then return end
 local p=S.player
 if p==0 or not EntityGetIsAlive(p) then p=get_player() end
 if p==0 then return end
 local level=get_wins()+1
 local x,y=EntityGetTransform(p)
 local gold=({1000,5000,10000,25000,50000,250000})[level]
 local ok_gold,gold_err=pcall(drop_gold_value,x,y,gold)
 if not ok_gold then GamePrint("PUNCH-OUT reward: gold drop failed")
print("[Punch-Out] gold: "..tostring(gold_err))
return end
 if level==2 then
  local ok,e=pcall(EntityLoad,"data/entities/items/pickup/random_card.xml",x+46,y-8)
  if not ok then print("[Punch-Out] random spell: "..tostring(e)) end
 elseif level>=3 and level<=5 then
  local count=({[3]=1,[4]=2,[5]=4})[level]
  for i=1,count do EntityLoad("data/entities/items/pickup/chest_random.xml",x+38+i*12,y-8) end
 elseif level==6 then
  EntityLoad("data/entities/items/pickup/chest_random_super.xml",x+46,y-8)
 end
 local lines={
  "1000 GOLD",
  "RANDOM SPELL + 5000 GOLD",
  "TREASURE + 10000 GOLD",
  "2X TREASURE + 25000 GOLD",
  "4X TREASURE + 50000 GOLD",
  "GREAT TREASURE + 250000 GOLD"
 }
 S.reward_given=true
S.reward_level=level
S.result="DUNK WINS!"
S.reward_line=lines[level]
 if level>=6 then
  reset_wins()
 else
  set_round_hp(math.min(100,S.p_hp+30))
  set_wins(level)
 end
 GamePrint("PUNCH-OUT: WIN "..level.." reward dropped!")
end
local function update_fight()
 local f=GameGetFrameNum()
 if S.miss_sound_at and S.miss_sound_at>0 and f>=S.miss_sound_at then
  play_sfx("punch_miss")
S.miss_sound_at=0
 end
 if S.phase=="countin" then
  local e=f-S.countin_start
  if e>=210 then
   S.phase="fight"
S.last_frame=f
S.next_attack=f+75
stop_result_jingle()
play_sfx("bell")
start_match_music()
   S.feedback=""
S.feedback_until=0
  end
  return
 end
 if S.hitstop_until>f then return end
 local dt=math.max(1,f-S.last_frame)
S.last_frame=f
S.timer=math.max(0,S.timer-dt/60)
 if S.timer<=0 then
  S.phase=(S.p_hp>=S.t_hp) and "won" or "lost"
  S.result=(S.phase=="won") and "TIME - DUNK WINS" or "TIME - RAT WINS"
  if S.phase=="lost" then reset_wins() end
  stop_match_music()
play_sfx("bell_end")
start_result_jingle((S.phase=="won") and "win" or "lose")
 end
 if S.p_until<=f and S.p_state~="ko" then S.p_state="idle" end
 if S.t_state=="hurt" and S.t_until<=f then S.t_state="recover"
S.t_anim_start=f
S.t_until=f+24 end
 if S.t_state=="block" and S.t_until<=f then S.t_state="idle"
S.t_anim_start=f
S.next_attack=f+28 end
 if S.counter_until>0 and f>S.counter_until then
  S.counter_until=0
  fx("TOO LATE!",18,0,0)
 end
 if S.t_state=="recover" and S.t_until<=f then S.t_state="idle"
S.counter_until=0
S.t_anim_start=f
S.next_attack=f+math.random(34,58) end
 if S.t_state=="idle" and f>=S.next_attack then S.attack=ATTACKS[math.random(1,#ATTACKS)]
S.t_state="windup"
S.t_anim_start=f
S.t_anim_name=S.attack.name
S.t_until=f+S.attack.wind
 elseif S.t_state=="windup" and f>=S.t_until then
  S.t_state="strike"
S.t_anim_start=f
S.t_until=f+S.attack.strike
play_sfx("tyson_punch")
  local safe=false
  if S.attack.kind=="punch" then
   local age=f-(S.dodge_start or -9999)
   local preferred=(S.attack.name=="right" and S.dodge_dir=="right") or (S.attack.name=="left" and S.dodge_dir=="left")
   local window=preferred and 25 or 10
   safe=((S.dodge_dir=="left" or S.dodge_dir=="right") and age>=0 and age<=window)
  else
   local duck_age=f-(S.dodge_start or -9999)
   safe=(S.dodge_dir=="duck" and duck_age>=0 and duck_age<=24)
  end
  S.dodged_attack=safe
  if safe then S.counter_until=f+30 end
  if not safe then
   S.counter_until=0
hurt_player(S.attack.dmg)
  else
   play_sfx("dodge")
S.miss_sound_at=f+4
fx("DODGE!",14,1,0)
S.feedback_until=f+14
  end
 elseif S.t_state=="strike" and f>=S.t_until then
  S.t_state="recover"
S.t_anim_start=f
S.t_until=f+S.attack.recover
  if S.dodged_attack then
   S.counter_until=f+22
   S.p_until=f
   if S.p_state=="duck" or S.p_state=="dodge_l" or S.p_state=="dodge_r" then S.p_state="idle" end
   S.feedback="COUNTER!"
S.feedback_until=f+22
  else
   S.counter_until=0
  end
  S.dodged_attack=false
 end
 if key(Key_LEFT) then player_action("left") end
if key(Key_RIGHT) then player_action("right") end
if key(Key_DOWN) then player_action("duck") end
if key(Key_UP) then player_action("punch") end
end
local function image(id,x,y,path,a,sx,sy) GuiImage(gui,id,x,y,BASE..path,a or 1,sx or 1,sy or 1) end
local function tframe()
 local f=GameGetFrameNum()
 local e=math.max(0,f-S.t_anim_start)
 local function cycle(prefix,n,step)
  return prefix..tostring((math.floor(e/step)%n)+1)..".png"
 end
 local function progress(prefix,n,total)
  local idx=math.min(n,1+math.floor((math.min(e,math.max(1,total)-1)/math.max(1,total))*n))
  return prefix..tostring(idx)..".png"
 end
 if S.t_state=="idle" or S.t_state=="recover" then return cycle("rat_idle_",4,10) end
 if S.t_state=="block" then return progress("rat_block_",3,10) end
 if S.t_state=="hurt" then return progress("rat_hurt_",5,22) end
 if S.t_state=="down" then return progress("rat_down_",9,72) end
 local name=(S.attack and S.attack.name) or S.t_anim_name
 local total=(S.attack and (S.attack.wind+S.attack.strike)) or 40
 if name=="left" then return progress("rat_left_",9,total) end
 if name=="right" then return progress("rat_right_",9,total) end
 if name=="upper" then return progress("rat_upper_",7,total) end
 return "rat_idle_1.png"
end
local function ring_frame()
 local n=(math.floor(GameGetFrameNum()/8)%8)+1
 return "files/gfx/ring/ring_blue_"..tostring(n)..".png"
end

local function draw_gui()
 if not gui then gui=GuiCreate() end
GuiStartFrame(gui)
local sw,sh=GuiGetScreenDimensions(gui)
local vw,vh=410,230
 local scale=math.min((sw-48)/vw,(sh-48)/vh,0.68)
local ox=(sw-vw*scale)/2
local oy=(sh-vh*scale)/2
local f=GameGetFrameNum()
local dx,dy=0,0
 if S.shake_until>f and S.shake_power>0 then dx=((f%3)-1)*S.shake_power
dy=(((f+1)%3)-1)*S.shake_power end
ox=ox+dx
oy=oy+dy
 local table_scale=(vh*scale)/949
 local table_w=820*table_scale
 GuiZSetForNextWidget(gui,121)
GuiImage(gui,899,ox-table_w-20,oy,BASE.."files/gfx/ui/reward_table.png",1,table_scale,table_scale)
 GuiZSetForNextWidget(gui,120)
GuiColorSetForNextWidget(gui,.035,.035,.045,.98)
GuiImage(gui,900,ox-14,oy-14,BASE.."files/gfx/ui/pixel.png",1,vw*scale+28,vh*scale+28)
 GuiZSetForNextWidget(gui,119)
GuiColorSetForNextWidget(gui,.32,.30,.27,1)
GuiImage(gui,901,ox-9,oy-9,BASE.."files/gfx/ui/pixel.png",1,vw*scale+18,vh*scale+18)
 GuiZSetForNextWidget(gui,118)
GuiColorSetForNextWidget(gui,.015,.015,.02,1)
GuiImage(gui,902,ox-4,oy-4,BASE.."files/gfx/ui/pixel.png",1,vw*scale+8,vh*scale+8)
 GuiZSetForNextWidget(gui,100)
image(1,ox,oy+35*scale,ring_frame(),1,scale,scale)
 local pe=math.max(0,f-(S.p_until-((S.p_state=="hurt" and 25) or (S.p_state=="ko" and 60) or 18)))
 local ppath="files/gfx/player/frames/r1c"..tostring((math.floor(f/12)%2)+1)..".png"
 if S.p_state=="dodge_l" then
  local q=math.min(3,1+math.floor(pe/6))
ppath="files/gfx/player/frames/r2c"..q..".png"
 elseif S.p_state=="dodge_r" then
  local q=math.min(3,1+math.floor(pe/6))
ppath="files/gfx/player/frames/r2c"..q.."_mirror.png"
 elseif S.p_state=="duck" then
  ppath="files/gfx/player/duck_normalized.png"
 elseif S.p_state=="hurt" then
  local q=math.min(3,1+math.floor(pe/8))
ppath="files/gfx/player/frames/r3c"..q..".png"
 elseif S.p_state=="jab_l" or S.p_state=="jab_r" then
  local q=math.min(3,1+math.floor(pe/4))
ppath="files/gfx/player/frames/r4c"..q..".png"
 elseif S.p_state=="ko" then
  local q=math.min(3,1+math.floor(math.max(0,f-S.p_until+60)/12))
ppath="files/gfx/player/frames/r8c"..q..".png"
 elseif S.phase=="won" then
  ppath="files/gfx/player/frames/r9c"..tostring((math.floor(f/14)%2)+1)..".png"
 end
 GuiZSetForNextWidget(gui, 50)
 image(10, ox + RAT_X * scale, oy + RAT_Y * scale, "files/gfx/tyson/frames/" .. tframe(), 1, scale * RAT_SCALE, scale * RAT_SCALE)
 GuiZSetForNextWidget(gui, 40)
 image(11, ox + DUNK_X * scale, oy + DUNK_Y * scale, ppath, 1, scale * DUNK_SCALE, scale * DUNK_SCALE)
 GuiZSetForNextWidget(gui,0)
GuiText(gui,ox+10*scale,oy+8*scale,"DUNK HP "..math.floor(S.p_hp))
GuiText(gui,ox+292*scale,oy+8*scale,"RAT HP "..math.floor(S.t_hp))
GuiText(gui,ox+190*scale,oy+2*scale,string.format("%02d",math.ceil(S.timer)))
 local shown_wins=(S.phase=="won" and S.reward_level>0) and S.reward_level or get_wins()
 GuiText(gui,ox+177*scale,oy+14*scale,"WINS "..shown_wins.."/6")
 local controls_text="LEFT/RIGHT dodge   DOWN duck   UP counter"
 local controls_x=math.max(8,(410-(#controls_text*6))/2)
 GuiText(gui,ox+controls_x*scale,oy+211*scale,controls_text)
 if S.phase=="countin" then
  local ce=f-S.countin_start
  local ct=(ce<50 and "3") or (ce<100 and "2") or (ce<150 and "1") or "FIGHT!"
  local cx=(ct=="FIGHT!") and 181 or 199
  GuiZSetForNextWidget(gui,-10)
GuiText(gui,ox+cx*scale,oy+78*scale,ct)
 end
 if S.feedback_until>f and S.feedback~="" then
  if string.find(S.feedback,"DODGE") then GuiColorSetForNextWidget(gui,0.25,1.0,0.30,1.0)
  elseif string.find(S.feedback,"COUNTER") then GuiColorSetForNextWidget(gui,1.0,0.85,0.15,1.0)
  elseif string.find(S.feedback,"TOO LATE") or string.find(S.feedback,"BLOCKED") or string.find(S.feedback,"COMMITTED") then GuiColorSetForNextWidget(gui,1.0,0.55,0.12,1.0)
  elseif string.find(S.feedback,"WHAM") then GuiColorSetForNextWidget(gui,1.0,0.20,0.20,1.0)
  end
  local fw=#S.feedback*6
  GuiText(gui,ox+((410-fw)/2)*scale,oy+29*scale,S.feedback)
 end
 if S.phase=="won" or S.phase=="lost" then
  local panel_x=42
  local has_reward=(S.phase=="won" and S.reward_line and S.reward_line~="")
  local panel_w=326
  local panel_h=has_reward and 66 or 52
  local panel_y=82-panel_h/2
  GuiColorSetForNextWidget(gui,0.16,0.16,0.16,1.0)
  GuiZSetForNextWidget(gui,-8)
  GuiImage(gui,9001,ox+panel_x*scale,oy+panel_y*scale,BASE.."files/gfx/ui/pixel.png",0.96,panel_w*scale,panel_h*scale)
  local function card_text(line,row)
   local est=#line*5.75
   local tx=205-est/2
   GuiColorSetForNextWidget(gui,1,1,1,1)
   GuiZSetForNextWidget(gui,-10)
   GuiText(gui,ox+tx*scale,oy+(panel_y+10+row*15)*scale,line)
  end
  card_text(S.result or "",0)
  local menu_row=1
  if S.phase=="won" and S.reward_line and S.reward_line~="" then
   card_text(S.reward_line,1)
   menu_row=2
  end
  card_text("SPACE: REMATCH    E: EXIT",menu_row)
  if key(Key_SPACE) then reset_fight() end
 end
end
local function update_idle() ensure_machine()
local p=get_player()
if p==0 then return end
local x,y=EntityGetTransform(p)
local m=EntityGetInRadiusWithTag(x,y,40,"punchout_arcade_machine") or {}
if #m>0 and interact(controls(p)) then start_game(p,m[1]) end end
local function update_active()
 local p=S.player
 if p==0 or not EntityGetIsAlive(p) then stop_game()
return end
 EntitySetTransform(p,S.lock_x,S.lock_y)
 local v=EntityGetFirstComponentIncludingDisabled(p,"VelocityComponent")
 if v then ComponentSetValue2(v,"mVelocity",0,0) end
 if interact(controls(p)) then stop_game()
return end
 if S.phase=="fight" or S.phase=="countin" then update_fight() end
 if S.phase=="won" and not S.reward_given then give_win_reward() end
 draw_gui()
end
function PunchOutArcade_OnModInit()
 if ModRegisterAudioEventMappings~=nil then
  if ModDoesFileExist==nil or ModDoesFileExist(AUDIO_GUIDS) then
   local ok,err=pcall(ModRegisterAudioEventMappings,AUDIO_GUIDS)
   if not ok then print("[Punch-Out v0.11.2] audio mapping: "..tostring(err)) end
  end
 end
 local path="data/translations/common.csv"
 local csv=ModTextFileGetContent(path)
 csv=csv.."\npunchout_arcade_play,Play PUNCH-OUT!!,PUNCH-OUT!! spielen,,,,,,,,,,,,,\n"
 csv=csv.."punchout_arcade_quit,Exit PUNCH-OUT!!,PUNCH-OUT!! verlassen,,,,,,,,,,,,,\n"
 ModTextFileSetContent(path,csv)
end
function PunchOutArcade_OnWorldPreUpdate() local ok,err=pcall(function() if S.active then update_active() else update_idle() end end)
if not ok then GamePrint("Punch-Out v0.11.2 error - see logger")
print("[Punch-Out v0.11.2] "..tostring(err))
stop_game() end end
function PunchOutArcade_OnPlayerDied() stop_match_music()
stop_result_jingle()
destroy_gui() end
