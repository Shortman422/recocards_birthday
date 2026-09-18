local BASE="mods/recocards_birthday/files/mortal_kombat/"
local ARCADE_X,ARCADE_Y=-683,8583

dofile_once("data/scripts/debug/keycodes.lua")

local AUDIO_BANK=BASE.."files/MortalKombat.bank"
local current_bgm=""
local S
local function audio_pos()
 local x,y=ARCADE_X,ARCADE_Y
 if S and S.player and S.player~=0 then x,y=EntityGetTransform(S.player) end
 return x or ARCADE_X,y or ARCADE_Y
end
local function sfx(event)
 local x,y=audio_pos()
 GamePlaySound(AUDIO_BANK,"MortalKombat/"..event,x,y)
end
local BGM_EVENTS={
 level="MortalKombat/BGM/create",
 finish="MortalKombat/FinishHimBGM/create",
 fatality="MortalKombat/FatalityBGM/create",
 matchover="MortalKombat/MatchOverBGM/create",
}
local bgm_entity=0
local BGM_TAG="mk_arcade_bgm"

local function kill_one_bgm_entity(e)
 if e==0 or not EntityGetIsAlive(e) then return end
 for _,c in ipairs(EntityGetComponentIncludingDisabled(e,"AudioLoopComponent") or {}) do
  EntitySetComponentIsEnabled(e,c,false)
 end
 EntityKill(e)
end
local function kill_bgm_entity()
 if bgm_entity~=0 then kill_one_bgm_entity(bgm_entity) end
 for _,e in ipairs(EntityGetWithTag(BGM_TAG) or {}) do
  if e~=bgm_entity then kill_one_bgm_entity(e) end
 end
 bgm_entity=0
end
local function silence_noita_music()
 if GameTriggerMusicFadeOutAndDequeueAll then GameTriggerMusicFadeOutAndDequeueAll(100.0) end
end
local function stop_bgm()
 kill_bgm_entity()
 current_bgm=""
 silence_noita_music()
end
local function set_bgm(which)
 if current_bgm==which and bgm_entity~=0 and EntityGetIsAlive(bgm_entity) then return end
 kill_bgm_entity()
 silence_noita_music()
 current_bgm=which or ""
 local event=which and BGM_EVENTS[which]
 if not event then return end
 local x,y=audio_pos()
 bgm_entity=EntityCreateNew("mk_arcade_bgm_"..which)
 EntityAddTag(bgm_entity,BGM_TAG)
 EntitySetTransform(bgm_entity,x,y)
 EntityAddComponent2(bgm_entity,"AudioLoopComponent",{
  file=AUDIO_BANK,
  event_name=event,
  auto_play=true,
  auto_play_if_enabled=true,
  play_on_component_enable=true,
  calculate_material_lowpass=false,
  volume_autofade_speed=0.0,
 })
end

local gui=nil
S={active=false,phase="idle",machine=0,player=0,lock_x=0,lock_y=0,p_hp=100,e_hp=100,timer=99,p_x=125,e_x=275,p_y=0,e_y=0,p_jump_v=0,p_jump_dx=0,p_air_attack_used=false,p_jump_cooldown_until=0,p_jump_chain=0,p_last_jump_attack=0,e_jump_spam_until=0,e_jump_v=0,e_jump_dx=0,e_jump_attack_at=0,e_crouch_read_until=0,p_punch_chain=0,p_last_punch=0,e_anti_spam_until=0,e_jump_counter_ready=0,e_spear_cooldown_until=0,e_spear_hit_at=0,e_spear_pull_end=0,e_spear_target_x=0,e_spear_after_backjump=false,e_spear_connected=false,p_stun_until=0,p_uppercut_slide_until=0,p_uppercut_slide_dir=0,p_uppercut_v=0,p_state="idle",e_state="idle",p_state_start=0,e_state_start=0,p_until=0,e_until=0,p_hit_done=false,e_hit_done=false,next_ai=0,last_frame=0,countin_start=0,result="",shake_until=0,hitstop_until=0,p_rounds=0,e_rounds=0,round=1,round_end_until=0,round_end_ready=0,finish_winner="",finish_ready=0,finish_hit_at=0,finish_end=0,combo_step=0,combo_deadline=0,fatality_start=0,fatality_react=0,scorp_fatality_start=0,scorp_fire_start=0,scorp_victim_start=0,match_end_ready=0,toasty_start=0,p_flawless_rounds=0,reward_claimed=false}

local function player() local p=EntityGetWithTag("player_unit"); return (p and #p>0) and p[1] or 0 end
local function controls(p) return EntityGetFirstComponentIncludingDisabled(p,"ControlsComponent") end
local function interact(c) return c and ComponentGetValue2(c,"mButtonFrameInteract")==GameGetFrameNum() end
local function just(k) if not InputIsKeyJustDown then return false end local ok,v=pcall(InputIsKeyJustDown,k); return ok and v==true end
local function held(k) if not InputIsKeyDown then return false end local ok,v=pcall(InputIsKeyDown,k); return ok and v==true end
local function clamp(v,a,b) return math.max(a,math.min(b,v)) end
local function distance() return math.abs(S.e_x-S.p_x) end
local function set_text(e,t) if e==0 or not EntityGetIsAlive(e) then return end for _,c in ipairs(EntityGetComponentIncludingDisabled(e,"InteractableComponent") or {}) do ComponentSetValue2(c,"ui_text",t) end end
local function destroy_gui() if gui then GuiDestroy(gui); gui=nil end end

local function set_p_state(st,dur) local f=GameGetFrameNum(); S.p_state=st; S.p_state_start=f; S.p_until=f+(dur or 0); S.p_hit_done=false end
local function set_e_state(st,dur) local f=GameGetFrameNum(); S.e_state=st; S.e_state_start=f; S.e_until=f+(dur or 0); S.e_hit_done=false end

local P_ATTACK={
 punch={dur=22,active_a=8,active_b=12,range=48,dmg=7,push=6,high=true},
 sweep={dur=34,active_a=17,active_b=23,range=62,dmg=13,push=12,low=true},
 jump_attack={dur=28,active_a=8,active_b=17,range=58,dmg=12,push=10,high=true}
}
local E_ATTACK={
 punch={dur=24,active_a=9,active_b=13,range=48,dmg=8,push=7,high=true},
 kick={dur=30,active_a=12,active_b=18,range=60,dmg=12,push=12,high=true},
 sweep={dur=34,active_a=17,active_b=23,range=62,dmg=13,push=12,low=true},
 jump_attack={dur=30,active_a=8,active_b=18,range=60,dmg=12,push=10,high=true},
 uppercut={dur=30,active_a=13,active_b=18,range=54,dmg=24,push=18,high=true}
}

local function ensure_machine()
 local p=player(); if p==0 then return end
 local x,y=EntityGetTransform(p); if math.abs(x-ARCADE_X)>750 or math.abs(y-ARCADE_Y)>750 then return end
 if #(EntityGetInRadiusWithTag(ARCADE_X,ARCADE_Y,80,"mk_arcade_machine") or {})==0 then EntityLoad(BASE.."files/arcade_machine.xml",ARCADE_X,ARCADE_Y) end
end
local function reset_round()
 local f=GameGetFrameNum(); S.phase="countin"; S.countin_start=f; S.p_hp=100; S.e_hp=100; S.timer=99; S.p_x=125; S.e_x=275; S.p_y=0; S.e_y=0; S.p_jump_v=0; S.p_jump_dx=0; S.p_air_attack_used=false; S.p_jump_cooldown_until=0; S.p_jump_chain=0; S.p_last_jump_attack=0; S.e_jump_spam_until=0; S.e_jump_v=0; S.e_jump_dx=0; S.e_jump_attack_at=0; S.e_crouch_read_until=0; S.p_punch_chain=0; S.p_last_punch=0; S.e_anti_spam_until=0; S.e_jump_counter_ready=0; S.e_spear_cooldown_until=0; S.e_spear_hit_at=0; S.e_spear_pull_end=0; S.e_spear_target_x=0; S.e_spear_after_backjump=false; S.e_spear_connected=false; S.p_stun_until=0; S.p_uppercut_slide_until=0; S.p_uppercut_slide_dir=0; S.p_uppercut_v=0; S.toasty_start=0
 set_p_state("idle",0); set_e_state("idle",0); S.next_ai=f+90; S.last_frame=f; S.result=""; S.shake_until=0; S.hitstop_until=0; S.round_end_until=0
end
local function reset_match()
 set_bgm("level"); S.p_rounds=0; S.e_rounds=0; S.p_flawless_rounds=0; S.reward_claimed=false; S.round=1; reset_round() end
local function start_game(p,m) destroy_gui(); S.active=true; S.player=p; S.machine=m; set_bgm("level"); S.lock_x,S.lock_y=EntityGetTransform(p); set_text(m,"$mk_arcade_quit"); reset_match() end
local function stop_game()
 stop_bgm(); destroy_gui(); if S.machine~=0 then set_text(S.machine,"$mk_arcade_play") end; if S.player~=0 and EntityGetIsAlive(S.player) then EntitySetTransform(S.player,S.lock_x,S.lock_y) end; S.active=false; S.phase="idle"; S.machine=0; S.player=0 end
local function impact(blocked) local f=GameGetFrameNum(); S.hitstop_until=f+(blocked and 3 or 5); S.shake_until=f+(blocked and 4 or 8) end

local function round_over(winner)
 local f=GameGetFrameNum(); if S.phase~="fight" then return end
 if winner=="p" then S.p_rounds=S.p_rounds+1; if S.p_hp>=100 then S.p_flawless_rounds=S.p_flawless_rounds+1 end else S.e_rounds=S.e_rounds+1 end
 local match_point=(S.p_rounds>=2 or S.e_rounds>=2)
 if match_point then
  S.phase="finish_intro"; S.finish_winner=winner; S.finish_ready=f+60; S.finish_hit_at=0; S.finish_end=0; S.combo_step=0; S.combo_deadline=0; S.result="FINISH HIM!"; set_bgm("finish"); sfx("finish_him")
  if winner=="p" then
   S.e_y=0
   set_p_state("idle",0); set_e_state("finish_idle",0)
  else
   S.p_y=0; S.p_jump_v=0; S.p_jump_dx=0
   set_e_state("idle",0); set_p_state("finish_idle",0)
  end
 else
  S.phase="round_end"; S.round_end_until=f; S.round_end_ready=f+60
  if winner=="p" then S.result="DUNKORSLAM WINS ROUND"; set_p_state("idle",0); set_e_state("hurt",999)
  else S.result="SCORPION WINS ROUND"; set_e_state("idle",0); set_p_state("hurt",999) end
 end
end
local function start_finish_attack(f)
 S.phase="finish_attack"; S.finish_hit_at=f+10
 if S.finish_winner=="p" then set_p_state("punch",22) else set_e_state("punch",24) end
end
local function land_finish(f)
 impact(false); S.phase="finish_fall"; S.finish_end=f+42
 if S.finish_winner=="p" then set_e_state("finish_fall",42) else set_p_state("finish_fall",42) end
end
local function spawn_reward_entity(path,x,y)
 local e=EntityLoad(path,x,y)
 return e
end
local function drop_gold(amount,x,y)
 local values={10000,1000,200,50,10}
 local paths={
  [10000]="data/entities/items/pickup/goldnugget_10000.xml",
  [1000]="data/entities/items/pickup/goldnugget_1000.xml",
  [200]="data/entities/items/pickup/goldnugget_200.xml",
  [50]="data/entities/items/pickup/goldnugget_50.xml",
  [10]="data/entities/items/pickup/goldnugget.xml"
 }
 local n=0
 for _,v in ipairs(values) do
  while amount>=v do
   n=n+1; spawn_reward_entity(paths[v],x+((n%5)-2)*5,y-8-math.floor(n/5)*3); amount=amount-v
  end
 end
end
local function reward_text(fatality)
 if S.finish_winner~="p" then return "REWARD: NOTHING" end
 if fatality then
  if S.e_rounds==0 and S.p_flawless_rounds>=2 then return "REWARD: GREAT TREASURE CHEST + 50,000 GOLD" end
  if S.e_rounds==0 then return "REWARD: 2x TREASURE CHEST + 10,000 GOLD" end
  return "REWARD: TREASURE CHEST + 2,500 GOLD"
 end
 return (S.e_rounds==0) and "REWARD: 2,500 GOLD" or "REWARD: 500 GOLD"
end
local function drop_match_reward(fatality)
 if S.reward_claimed or S.finish_winner~="p" then return end
 S.reward_claimed=true
 local x,y=S.lock_x,S.lock_y
 if S.player~=0 and EntityGetIsAlive(S.player) then x,y=EntityGetTransform(S.player) end
 local gold,chests,great=0,0,false
 if fatality then
  if S.e_rounds==0 and S.p_flawless_rounds>=2 then great=true; gold=50000
  elseif S.e_rounds==0 then chests=2; gold=10000
  else chests=1; gold=2500 end
 else
  gold=(S.e_rounds==0) and 2500 or 500
 end
 local seed=GameGetFrameNum()+S.round*97+S.p_rounds*193+S.e_rounds*389
 for i=1,chests do
  local cx=x-22+(i-1)*24+((seed+i*7)%9)-4
  local cy=y-20-((seed+i*11)%7)
  spawn_reward_entity("data/entities/items/pickup/chest_random.xml",cx,cy)
 end
 if great then
  local cx=x-12+(seed%17)-8
  local cy=y-20-(seed%7)
  spawn_reward_entity("data/entities/items/pickup/chest_random_super.xml",cx,cy)
 end
 drop_gold(gold,x+16,y-12)
end
local function complete_finish()
 local f=GameGetFrameNum()
 if S.finish_winner=="p" and S.p_y<0 then S.phase="victory_wait"; return end
 S.phase="match_end"; S.match_end_ready=f+180; set_bgm("matchover")
 if S.finish_winner=="p" then drop_match_reward(false) end
 if S.finish_winner=="p" then S.result="VICTORY"; set_p_state("victory",0) else S.result="LOSE"; set_e_state("victory",0) end
end
local function start_fatality(f)
 set_bgm("fatality")
 S.phase="fatality"; S.fatality_start=f; S.fatality_react=f+36; S.result=""
 S.p_y=0; S.p_jump_v=0; S.p_jump_dx=0
 set_p_state("fatality",86); set_e_state("finish_idle",0)
end
local function finish_combo_input(f)
 if S.finish_winner~="p" or distance()>62 or S.p_y<0 then S.combo_step=0; return false,false end
 if S.combo_deadline>0 and f>S.combo_deadline then S.combo_step=0 end
 local expected={Key_LEFT,Key_RIGHT,Key_LEFT,Key_UP,Key_DOWN,Key_RIGHT,Key_LEFT,Key_DOWN,Key_SPACE}
 local consume_up=false; local consume_space=false
 local k=expected[S.combo_step+1]
 if k and just(k) then
  S.combo_step=S.combo_step+1; S.combo_deadline=f+45
  if k==Key_UP then consume_up=true end
  if k==Key_SPACE then consume_space=true end
  if S.combo_step>=9 then S.combo_step=0; start_fatality(f); return true,true end
 elseif just(Key_LEFT) or just(Key_RIGHT) or just(Key_UP) or just(Key_DOWN) or just(Key_SPACE) then
  if just(Key_LEFT) then S.combo_step=1; S.combo_deadline=f+45 else S.combo_step=0 end
 end
 return consume_up,consume_space
end
local function hit_enemy(a)
 local blocked=a.low and (S.e_state=="crouch_block") or ((not a.low) and (S.e_state=="block" or S.e_state=="crouch_block"))
 local dmg=a.dmg; local push=a.push
 if blocked then dmg=math.max(1,math.floor(dmg*.25)); push=push*.3; sfx("blocked_hit") else if a.low then set_e_state("knockdown",30); sfx("sweep_hit") else set_e_state("hurt",20); sfx((S.p_state=="jump_attack") and "kick_hit" or "punch_hit") end end
 S.e_hp=clamp(S.e_hp-dmg,0,100); S.e_x=clamp(S.e_x+push,70,330); impact(blocked); if S.e_hp<=0 then round_over("p") end
end
local function hit_player(a)
 S.p_stun_until=0
 if S.p_state=="knockdown" or S.p_state=="getup" then return end
 if a.high and S.p_state=="crouch" then return end
 local blocked=a.low and (S.p_state=="crouch_block") or ((not a.low) and (S.p_state=="block" or S.p_state=="crouch_block"))
 local dmg=a.dmg; local push=a.push
 if blocked then dmg=math.max(1,math.floor(dmg*.25)); push=push*.3; sfx("blocked_hit") else if a.low then set_p_state("knockdown",30); sfx("sweep_hit") else set_p_state("hurt",20); sfx((S.e_state=="kick" or S.e_state=="jump_attack") and "kick_hit" or "punch_hit") end end
 S.p_hp=clamp(S.p_hp-dmg,0,100); S.p_x=clamp(S.p_x-push,70,330); impact(blocked); if S.p_hp<=0 then round_over("e") end
end
local function separate_fighters()
 local minsep=39
 if S.e_x-S.p_x<minsep then local mid=(S.p_x+S.e_x)*.5; S.p_x=clamp(mid-minsep*.5,60,340); S.e_x=clamp(mid+minsep*.5,60,340) end
end
local function p_attack(kind)
 local f=GameGetFrameNum(); if (S.phase~="fight" and not (S.phase=="finish_ready" and S.finish_winner=="p")) or S.p_until>f or S.p_state=="hurt" or S.p_state=="hurt_low" then return end
 local a=P_ATTACK[kind]
 if kind=="punch" then
  if f-S.p_last_punch<=38 then S.p_punch_chain=S.p_punch_chain+1 else S.p_punch_chain=1 end
  S.p_last_punch=f
  if S.p_punch_chain>=2 then S.e_anti_spam_until=f+110 end
  S.p_jump_chain=0
 elseif kind=="jump_attack" then
  if f<S.p_jump_cooldown_until then return end
  if f-S.p_last_jump_attack<=125 then S.p_jump_chain=S.p_jump_chain+1 else S.p_jump_chain=1 end
  S.p_last_jump_attack=f
  if S.p_jump_chain>=2 then S.e_jump_spam_until=f+180 end
  S.p_punch_chain=0
 else
  S.p_punch_chain=0
 end
 set_p_state(kind,a.dur); sfx((kind=="punch") and "woosh_punch" or "woosh_kick")
end
local function update_p_attack(f)
 local a=P_ATTACK[S.p_state]; if not a or S.p_hit_done then return end
 local t=f-S.p_state_start
 if t>=a.active_a and t<=a.active_b then S.p_hit_done=true; if distance()<=a.range then if S.phase=="finish_ready" and S.finish_winner=="p" then land_finish(f) else hit_enemy(a) end end end
end
local function update_e_attack(f)
 local a=E_ATTACK[S.e_state]; if not a or S.e_hit_done then return end
 local t=f-S.e_state_start
 if t>=a.active_a and t<=a.active_b then
  S.e_hit_done=true
  if distance()<=a.range then
   if S.e_state=="uppercut" then
    local toasty=math.random()<0.20
    local hit_dmg=toasty and 30 or a.dmg
    local air_time=toasty and 54 or 42
    S.p_stun_until=f+air_time; S.p_uppercut_slide_until=f+air_time; S.p_uppercut_slide_dir=(S.p_x<S.e_x) and -1 or 1; S.p_uppercut_v=toasty and -10.75 or -6.2; S.p_y=-2; set_p_state("uppercut_hit",air_time); S.p_hp=clamp(S.p_hp-hit_dmg,0,100); sfx("kick_hit"); if toasty then S.toasty_start=f+15; sfx("TOASTY SOUND EFFECT (MORTAL KOMBAT)") end; impact(false); if S.p_hp<=0 then round_over("e") end
   elseif a.high and S.p_state=="crouch" then S.e_crouch_read_until=f+120 else hit_player(a) end
  end
 end
end
local function update_player(f,suppress_up,suppress_space)
 if S.p_y<0 or S.p_jump_v~=0 then
  S.p_y=S.p_y+S.p_jump_v; S.p_jump_v=S.p_jump_v+.7
  S.p_x=clamp(S.p_x+S.p_jump_dx,60,340)
  if S.p_y>=0 then
   S.p_y=0; S.p_jump_v=0; S.p_jump_dx=0
   if S.p_air_attack_used then S.p_jump_cooldown_until=f+20 end
   S.p_air_attack_used=false
   if S.p_until<=f then set_p_state("idle",0) end
  end
 end
 if S.p_state=="knockdown" then
  if S.p_until<=f then set_p_state("getup",30) end
  return
 end
 if S.p_state=="getup" then
  if S.p_until<=f then set_p_state("idle",0) end
  return
 end
 if S.p_state=="uppercut_hit" then
  if f<S.p_uppercut_slide_until then
   S.p_x=clamp(S.p_x+S.p_uppercut_slide_dir*1.35,60,340)
   S.p_y=S.p_y+S.p_uppercut_v
   S.p_uppercut_v=S.p_uppercut_v+.48
   if S.p_y>0 then S.p_y=0; S.p_uppercut_v=0 end
  end
  if S.p_until<=f then S.p_y=0; S.p_uppercut_v=0; S.p_stun_until=0; set_p_state("idle",0) end
  return
 end
 if f<S.p_stun_until then
  S.p_y=0; S.p_jump_v=0; S.p_jump_dx=0
  if S.p_state~="finish_idle" then set_p_state("finish_idle",0) end
  return
 elseif S.p_state=="finish_idle" and S.phase=="fight" then
  set_p_state("idle",0)
 end
 update_p_attack(f)
 if S.p_until>f and P_ATTACK[S.p_state] then return end
 if S.p_until<=f and (S.p_state=="hurt" or S.p_state=="hurt_low") then set_p_state("idle",0) end
 local enemy_right=S.e_x>S.p_x
 local back=(enemy_right and held(Key_LEFT)) or ((not enemy_right) and held(Key_RIGHT))
 local forward=(enemy_right and held(Key_RIGHT)) or ((not enemy_right) and held(Key_LEFT))
 local down=held(Key_DOWN); local moving=false
 if S.p_y==0 and not down and not back and forward then S.p_x=S.p_x+(enemy_right and 2 or -2); moving=true end
 S.p_x=clamp(S.p_x,60,340); separate_fighters()
 if (not suppress_up) and just(Key_UP) and S.p_y==0 and not down then
  S.p_air_attack_used=false; S.p_jump_v=-6.4; S.p_y=-1
  if forward then S.p_jump_dx=(enemy_right and 2.15 or -2.15); set_p_state("jump_forward",0)
  elseif back then S.p_jump_dx=(enemy_right and -2.15 or 2.15); set_p_state("jump_backward",0)
  else S.p_jump_dx=0; set_p_state("jump",0) end
 end
 if (not suppress_space) and just(Key_SPACE) then
  if S.p_y<0 or held(Key_UP) then
   if S.p_y==0 then S.p_air_attack_used=false; S.p_jump_v=-6.4; S.p_y=-1; S.p_jump_dx=0 end
   if not S.p_air_attack_used then
    p_attack("jump_attack")
    if S.p_state=="jump_attack" then S.p_air_attack_used=true end
   end
  elseif down then
   p_attack("sweep")
  else
   p_attack("punch")
  end
  return
 end
 if S.p_y==0 and S.p_until<=f then
  if down and back then set_p_state("crouch_block",0) elseif down then set_p_state("crouch",0) elseif back then set_p_state("block",0) elseif moving then if S.p_state~="walk" then set_p_state("walk",0) end else if S.p_state~="idle" then set_p_state("idle",0) end end
 end
end
local function enemy_attack(kind) local a=E_ATTACK[kind]; set_e_state(kind,a.dur); sfx((kind=="punch") and "woosh_punch" or "woosh_kick") end
local function start_spear(f)
 set_e_state("spear",68); S.e_spear_hit_at=f+30; sfx("Efeito sonoro Mortal Kombat (Get over here) - Mortal Kombat sound effect (Get over here)"); S.e_spear_pull_end=0; S.e_spear_target_x=S.p_x; S.e_spear_connected=false; S.e_spear_after_backjump=false; S.e_spear_cooldown_until=f+165; S.next_ai=f+58
end
local function update_spear(f)
 local t=f-S.e_state_start
 if S.e_spear_hit_at>0 and f>=S.e_spear_hit_at then
  S.e_spear_hit_at=0
  if distance()<=190 then
   S.p_y=0; S.p_jump_v=0; S.p_jump_dx=0; S.p_hp=math.max(1,S.p_hp-3); S.p_stun_until=f+120; set_p_state("finish_idle",0); S.e_spear_pull_end=f+30; S.e_spear_connected=true; sfx("kick_hit"); impact(false)
  end
 end
 if S.e_spear_pull_end>0 and f<=S.e_spear_pull_end then
  local target=S.e_x+((S.p_x<S.e_x) and -46 or 46)
  S.p_x=S.p_x+(target-S.p_x)*.18
  if math.abs(target-S.p_x)<1.5 then S.p_x=target end
 elseif S.e_spear_pull_end>0 then
  S.e_spear_pull_end=0
  if S.e_spear_connected then
   S.e_spear_connected=false; S.p_stun_until=f+60; enemy_attack("uppercut"); S.next_ai=f+62
  else
   S.p_stun_until=math.max(S.p_stun_until,f+60)
  end
 end
end
local function update_ai(f)
 if S.e_y<0 or S.e_jump_v~=0 then
  S.e_y=S.e_y+S.e_jump_v; S.e_jump_v=S.e_jump_v+.7
  S.e_x=clamp(S.e_x+S.e_jump_dx,60,340)
  if S.e_jump_attack_at>0 and f>=S.e_jump_attack_at and S.e_state=="jump" then
   set_e_state("jump_attack",30); S.e_jump_attack_at=0
  end
  update_e_attack(f)
  if S.e_y>=0 then
   S.e_y=0; S.e_jump_v=0; S.e_jump_dx=0; S.e_jump_attack_at=0
   if S.e_spear_after_backjump and f>=S.e_spear_cooldown_until then
    start_spear(f); return
   end
   if S.e_until<=f or S.e_state=="jump" or S.e_state=="jump_attack" then set_e_state("idle",0) end
  end
  return
 end
 if S.e_state=="spear" then
  update_spear(f)
  if S.e_until<=f then set_e_state("idle",0) end
  return
 end
 update_e_attack(f)
 if S.e_until<=f and S.e_state=="knockdown" then set_e_state("getup",30); return end
 if S.e_until<=f and S.e_state=="getup" then set_e_state("idle",0) end
 if S.e_until<=f and (S.e_state=="hurt" or S.e_state=="hurt_low" or S.e_state=="block" or S.e_state=="crouch_block" or E_ATTACK[S.e_state]) then set_e_state("idle",0) end
 if S.e_until>f or S.e_state=="knockdown" or S.e_state=="getup" then return end
 local d=distance(); local moving=false
 if f<=S.e_jump_spam_until and f>=S.next_ai then
  local away=(S.p_x<S.e_x) and 1 or -1
  if d<96 and f>=S.e_jump_counter_ready then
   S.e_jump_v=-6.4; S.e_y=-1; S.e_jump_dx=away*2.25; S.e_jump_attack_at=0; S.e_spear_after_backjump=true
   set_e_state("jump",0); S.next_ai=f+58; S.e_jump_counter_ready=f+70; return
  end
  if f>=S.e_spear_cooldown_until and d>=88 and d<=190 then
   start_spear(f); S.e_jump_counter_ready=f+110; return
  end
  if S.p_y<0 and f>=S.e_jump_counter_ready and d<=145 and math.random()<.72 then
   S.e_jump_v=-6.4; S.e_y=-1; S.e_jump_dx=away*2.2; S.e_jump_attack_at=f+8
   set_e_state("jump",0); S.next_ai=f+92; S.e_jump_counter_ready=f+105; return
  end
  S.next_ai=f+18
 end
 if S.p_state=="jump_attack" and S.p_y<0 and f>=S.next_ai and f>=S.e_jump_counter_ready then
  local r=math.random()
  if d>=52 and d<=118 and r<.48 then
   local dir=(S.p_x<S.e_x) and -1 or 1
   S.e_jump_v=-6.4; S.e_y=-1; S.e_jump_dx=dir*2.1; S.e_jump_attack_at=f+6
   set_e_state("jump",0); S.next_ai=f+90; S.e_jump_counter_ready=f+125; return
  elseif d<=62 and r<.78 then
   set_e_state("block",20); S.next_ai=f+30; S.e_jump_counter_ready=f+70; return
  end
 end
 if f<=S.e_anti_spam_until and S.p_state=="punch" then
  if d>=58 and d<=112 and f>=S.next_ai then
   local dir=(S.p_x<S.e_x) and -1 or 1
   S.e_jump_v=-6.4; S.e_y=-1; S.e_jump_dx=dir*2.15; S.e_jump_attack_at=f+8
   set_e_state("jump",0); S.next_ai=f+95; S.e_anti_spam_until=0; return
  elseif d<=64 and f>=S.next_ai then
   if math.random()<.68 then enemy_attack("sweep"); S.next_ai=f+70
   else set_e_state("crouch_block",24); S.next_ai=f+34 end
   S.e_anti_spam_until=0; return
  elseif d<=70 then
   set_e_state("crouch_block",18); return
  end
 end
 if f>=S.next_ai and P_ATTACK[S.p_state] and d<72 and math.random()<.24 then
  set_e_state((S.p_state=="sweep") and "crouch_block" or "block",18); S.next_ai=f+26; return
 end
 if f>=S.next_ai and f<=S.e_crouch_read_until and S.p_state=="crouch" and d<=64 then
  enemy_attack((math.random()<.75) and "sweep" or "punch")
  S.e_crouch_read_until=0; S.next_ai=f+math.random(46,68); return
 end
 if f>=S.next_ai and d>=62 and d<=178 and math.random()<.62 then
  local dir=(S.p_x<S.e_x) and -1 or 1
  S.e_jump_v=-6.4; S.e_y=-1; S.e_jump_dx=dir*((d>125) and 2.85 or 2.55); S.e_jump_attack_at=f+6
  set_e_state("jump",0); S.next_ai=f+58; return
 end
 if f>=S.next_ai and f>=S.e_spear_cooldown_until and d>=105 and d<=205 and math.random()<.22 then
  start_spear(f); return
 end
 if d>44 then S.e_x=S.e_x+((S.p_x<S.e_x) and -2.0 or 2.0); moving=true elseif d<36 then S.e_x=S.e_x+((S.p_x<S.e_x) and .75 or -.75); moving=true end
 S.e_x=clamp(S.e_x,60,340); separate_fighters()
 if moving then if S.e_state~="walk" then set_e_state("walk",0) end else if S.e_state~="idle" then set_e_state("idle",0) end end
 d=distance()
 if f>=S.next_ai and d<=60 then
  local r=math.random()
  if S.p_state=="crouch" then enemy_attack((r<.78) and "sweep" or "punch")
  elseif S.p_state=="block" then enemy_attack((r<.58) and "sweep" or ((r<.82) and "kick" or "punch"))
  else enemy_attack((r<.32) and "sweep" or ((r<.67) and "kick" or "punch")) end
  S.next_ai=f+math.random(25,44)
 elseif f>=S.next_ai then S.next_ai=f+8 end
end
local function update_fight()
 local f=GameGetFrameNum()
 if S.phase=="countin" then if f-S.countin_start>=150 then S.phase="fight"; S.last_frame=f; S.next_ai=f+50; sfx("fight") end; return end
 if S.phase=="round_end" then if f>=S.round_end_ready and just(Key_SPACE) then S.round=S.round+1; reset_round() end; return end
 if S.phase=="finish_intro" then
  if f>=S.finish_ready then
   if S.finish_winner=="p" then S.phase="finish_ready"; S.result=""
   else S.phase="scorp_finish_move"; S.result=""; set_p_state("finish_idle",0); set_e_state("walk",0) end
  end
  return
 end
 if S.phase=="finish_ready" then
  local sup_up,sup_space=finish_combo_input(f)
  if S.phase=="fatality" then return end
  update_player(f,sup_up,sup_space)
  return
 end
 if S.phase=="scorp_finish_move" then
  local target=clamp(S.p_x+46,70,330)
  if math.abs(S.e_x-target)>2 then S.e_x=S.e_x+((target>S.e_x) and 1.5 or -1.5); set_e_state("walk",0)
  else S.e_x=target; S.phase="scorp_fatality"; set_bgm("fatality"); S.scorp_fatality_start=f; S.scorp_fire_start=0; S.scorp_victim_start=0; set_e_state("scorp_fatality",0); set_p_state("finish_idle",0) end
  return
 end
 if S.phase=="scorp_fatality" then
  local t=f-S.scorp_fatality_start
  if t>=48 and S.scorp_fire_start==0 then S.scorp_fire_start=f; sfx("scorpions_fataliy_projectile") end
  if S.scorp_fire_start>0 and f-S.scorp_fire_start>=32 and S.scorp_victim_start==0 then S.scorp_victim_start=f; set_p_state("scorp_fatality_victim",0); sfx("jonny_got_fatalitied"); impact(false) end
  if S.scorp_victim_start>0 and f-S.scorp_victim_start>=54 then S.phase="fatality_result_enemy"; S.result="FATALITY"; sfx("fatality"); set_bgm("matchover"); set_e_state("victory",0); S.p_until=f+9999; S.match_end_ready=f+180 end
  return
 end
 if S.phase=="finish_attack" then if f>=S.finish_hit_at then land_finish(f) end; return end
 if S.phase=="finish_fall" then if f>=S.finish_end then complete_finish() end; return end
 if S.phase=="victory_wait" then
  update_player(f,true,true)
  if S.p_y==0 then complete_finish() end
  return
 end
 if S.phase=="fatality" then
  if f>=S.fatality_react and S.e_state=="finish_idle" then set_e_state("fatality_hurt",18); sfx("kick_hit"); sfx("scorpion_got_fatalitied") end
  if f>=S.fatality_react+18 and S.e_state=="fatality_hurt" then set_e_state("fatality_hit",54) end
  if f-S.fatality_start>=86 then
   S.phase="fatality_result"; S.result="FATALITY"; sfx("fatality"); set_bgm("matchover"); drop_match_reward(true); set_p_state("victory",0); S.e_until=f+9999; S.match_end_ready=f+180
  end
  return
 end
 if S.phase=="fatality_result" or S.phase=="fatality_result_enemy" then
  if f>=S.match_end_ready and just(Key_SPACE) then reset_match() end
  return
 end
 if S.phase~="fight" then return end
 if f<S.hitstop_until then S.last_frame=f; return end
 local dt=math.max(1,f-S.last_frame); S.last_frame=f; S.timer=math.max(0,S.timer-dt/60); update_player(f); update_ai(f)
 if S.timer<=0 then if S.p_hp>S.e_hp then round_over("p") elseif S.e_hp>S.p_hp then round_over("e") else S.timer=10 end end
end

local ANIM={
 johnny={
  idle={"idle1.png","idle2.png","idle3.png",step=14}, walk={"walk1.png","walk2.png","walk3.png",step=7}, block={"block.png",step=99}, crouch_block={"crouch_block.png",step=99}, crouch={"crouch.png",step=99},
  punch={"punch1.png","punch2.png","punch3.png",step=7}, sweep={"sweep1.png","sweep2.png","sweep3.png",step=10}, jump={"jump.png",step=99}, jump_forward={"jump_forward1.png","jump_forward2.png","jump_forward3.png",step=5}, jump_backward={"jump_backward1.png","jump_backward2.png","jump_backward3.png",step=5}, jump_attack={"jump_attack.png",step=99}, uppercut_hit={"hurt.png","finish_fall1.png","finish_fall2.png",step=11}, hurt={"hurt.png",step=99}, hurt_low={"hurt.png",step=99}, knockdown={"fall1.png","fall2.png","fall3.png",step=9}, getup={"getup1.png","getup2.png","getup3.png",step=9}, finish_idle={"finish_idle1.png","finish_idle2.png","finish_idle3.png",step=14}, finish_fall={"finish_fall1.png","finish_fall2.png",step=16}, scorp_fatality_victim={"scorp_fatality_victim1.png","scorp_fatality_victim2.png","scorp_fatality_victim3.png",step=18}, fatality={"fatality1.png","fatality2.png","fatality3.png","fatality4.png","fatality5.png","fatality6.png","fatality7.png",step=12}, victory={"victory1.png","victory2.png","victory3.png","victory4.png","victory5.png","victory6.png",step=10}
 },
 scorpion={
  idle={"idle1.png","idle2.png","idle3.png",step=14}, walk={"walk1.png","walk2.png","walk3.png",step=7}, block={"block.png",step=99}, crouch_block={"crouch_block.png",step=99}, crouch={"crouch.png",step=99},
  punch={"punch1.png","punch2.png","punch3.png",step=8}, kick={"highkick1.png","highkick2.png","highkick3.png",step=10}, sweep={"sweep1.png","sweep2.png","sweep3.png",step=10}, spear={"spear1.png","spear2.png","spear3.png",step=14}, uppercut={"uppercut1.png","uppercut2.png","uppercut3.png",step=9}, jump={"jump.png",step=99}, jump_forward={"jump_forward1.png","jump_forward2.png","jump_forward3.png",step=5}, jump_backward={"jump_backward1.png","jump_backward2.png","jump_backward3.png",step=5}, jump_attack={"jump_attack.png",step=99}, uppercut_hit={"hurt.png","finish_fall1.png","finish_fall2.png",step=11}, hurt={"hurt.png",step=99}, hurt_low={"hurt_low.png",step=99}, knockdown={"fall1.png","fall2.png","fall3.png",step=9}, getup={"getup1.png","getup2.png","getup3.png",step=9}, finish_idle={"finish_idle1.png","finish_idle2.png","finish_idle3.png",step=14}, finish_fall={"finish_fall1.png","finish_fall2.png",step=16}, fatality_hurt={"fatality_hurt.png",step=99}, fatality_hit={"fatality_hit1.png","fatality_hit2.png","fatality_hit3.png",step=18}, scorp_fatality={"scorp_fatality1.png","scorp_fatality2.png","scorp_fatality3.png","scorp_fatality4.png","scorp_fatality5.png",step=12}, victory={"victory1.png","victory2.png",step=14}
 }
}
local function anim_path(who,state,start,f)
 local a=ANIM[who][state] or ANIM[who].idle; local count=#a; local idx=math.floor(math.max(0,f-start)/(a.step or 8))+1
 if state=="idle" or state=="walk" or state=="victory" or state=="finish_idle" then idx=((idx-1)%count)+1 else idx=math.min(idx,count) end
 return "files/gfx/"..who.."/"..a[idx]
end
local function z(v) if GuiZSetForNextWidget then GuiZSetForNextWidget(gui,v) end end
local function img(id,x,y,path,a,sx,sy,zv) if zv then z(zv) end; GuiImage(gui,id,x,y,BASE..path,a or 1,sx or 1,sy or 1) end
local function rect(id,x,y,w,h,r,g,b,zv) z(zv or 0); GuiColorSetForNextWidget(gui,r,g,b,1); GuiImage(gui,id,x,y,BASE.."files/gfx/ui/pixel.png",1,w,h) end
local function dim_rect(id,x,y,w,h,zv) z(zv or 65); GuiColorSetForNextWidget(gui,0,0,0,1); GuiImage(gui,id,x,y,BASE.."files/gfx/ui/pixel.png",0.62,w,h) end
local function centered_text(cx,y,text,zv)
 local w=#text*5
 if GuiGetTextDimensions then
  local ok,tw=pcall(GuiGetTextDimensions,gui,text)
  if ok and type(tw)=="number" then w=tw end
 end
 z(zv or 0)
 GuiText(gui,cx-w*0.5,y,text)
end
local function draw_gui()
 if not gui then gui=GuiCreate() end; GuiStartFrame(gui)
 local sw,sh=GuiGetScreenDimensions(gui); local vw,vh=400,225; local rw,gap=194,10; local total_w=rw+gap+vw; local scale=math.min((sw-24)/total_w,(sh-24)/vh,.9); local group_x=(sw-total_w*scale)/2; local ox=group_x+(rw+gap)*scale; local oy=(sh-vh*scale)/2; local f=GameGetFrameNum(); local shake=(f<S.shake_until) and ((f%2==0) and 2 or -2) or 0; local sx=shake*scale
 img(899,group_x,oy,"files/gfx/ui/reward_table.png",1,scale,scale,90)
 rect(900,ox-7,oy-7,vw*scale+14,vh*scale+14,.02,.02,.02,100)
 img(1,ox+sx,oy+42*scale,"files/gfx/stage/the_pit.png",1,(400/647)*scale,(400/647)*scale,80)
 local floor_y=143
 if S.e_state=="spear" then
  local st=f-S.e_state_start
  if st>=4 and st<62 then
   local hand=S.e_x-34
   local target=S.e_spear_target_x+20
   local tip=hand
   if S.e_spear_pull_end>0 then
    tip=S.p_x+20
   elseif st<=30 then
    local q=math.min(1,(st-4)/26)
    tip=hand+(target-hand)*q
   else
    local q=math.min(1,(st-30)/30)
    tip=target+(hand-target)*q
   end
   local len=math.abs(tip-hand)
   if len<10 then len=0; tip=hand end
   local rope_y=floor_y-54
   if len>3 then
    local spear_w=25
    local spear_x=tip
    local rope_left=spear_x+spear_w-1
    local rope_right=hand
    local rope_len=rope_right-rope_left
    if rope_len>1 then
     local tile=48
     local n=math.floor(rope_len/tile)
     for i=0,n-1 do
      local x=rope_right-(i+1)*tile
      img(1100+i,ox+x*scale+sx,oy+rope_y*scale,"files/gfx/scorpion/spear_rope_mid.png",1,(48/50)*scale,scale,45)
     end
     local rem=rope_len-n*tile
     if rem>1 then
      local x=rope_left
      img(1160,ox+x*scale+sx,oy+rope_y*scale,"files/gfx/scorpion/spear_rope_mid.png",1,(rem/50)*scale,scale,45)
     end
    end
    img(1161,ox+spear_x*scale+sx,oy+(rope_y+4)*scale,"files/gfx/scorpion/spear_tip.png",1,scale,scale,44)
   end
  end
 end
 img(10,ox+(S.p_x-50)*scale+sx,oy+(floor_y-96+S.p_y)*scale,anim_path("johnny",S.p_state,S.p_state_start,f),1,scale,scale,50)
 img(11,ox+(S.e_x-50)*scale+sx,oy+(floor_y-96+S.e_y)*scale,anim_path("scorpion",S.e_state,S.e_state_start,f),1,scale,scale,50)
 if S.toasty_start and S.toasty_start>0 then
  local tt=f-S.toasty_start
  if tt>=0 and tt<30 then
   local rise
   if tt<10 then rise=tt/10 elseif tt<16 then rise=1 else rise=1-((tt-16)/14) end
   rise=clamp(rise,0,1)
   local ts=.27
   local tw=230*ts
   local level=math.max(1,math.min(10,math.ceil(rise*10)))
   local crop_h=math.max(1,math.floor(229*level/10+.5))
   local game_bottom=198
   local tx=vw-tw-2
   local ty=game_bottom-crop_h*ts
   img(1180,ox+tx*scale,oy+ty*scale,"files/gfx/ui/toasty_peek_"..tostring(level)..".png",1,ts*scale,ts*scale,25)
  elseif tt>=30 then S.toasty_start=0 end
 end
 rect(20,ox+10*scale,oy+8*scale,145*scale,10*scale,.16,.16,.16,20); rect(21,ox+245*scale,oy+8*scale,145*scale,10*scale,.16,.16,.16,20)
 rect(22,ox+10*scale,oy+8*scale,145*scale*(S.p_hp/100),10*scale,.9,.8,.1,10); rect(23,ox+(390-145*(S.e_hp/100))*scale,oy+8*scale,145*scale*(S.e_hp/100),10*scale,.9,.8,.1,10)
 z(0); GuiText(gui,ox+10*scale,oy+20*scale,"DUNKORSLAM  "..tostring(math.floor(S.p_hp)).." HP"); z(0); GuiText(gui,ox+276*scale,oy+20*scale,tostring(math.floor(S.e_hp)).." HP  SCORPION")
 z(0); GuiText(gui,ox+192*scale,oy+7*scale,string.format("%02d",math.ceil(S.timer))); z(0); GuiText(gui,ox+169*scale,oy+21*scale,"ROUND "..tostring(S.round).."   "..tostring(S.p_rounds).." - "..tostring(S.e_rounds))
 centered_text(ox+(vw*scale)*0.5,oy+202*scale,"TOWARD move   BACK block   DOWN crouch   SPACE punch",0); centered_text(ox+(vw*scale)*0.5,oy+213*scale,"UP+TOWARD forward jump   UP+BACK back jump   DOWN+SPACE sweep   E exit",0)
 if S.phase=="countin" then local e=f-S.countin_start; local t=(e<70 and ("ROUND "..tostring(S.round))) or (e<125 and "READY") or "FIGHT!"; z(-5); GuiText(gui,ox+190*scale,oy+75*scale,t) end
 if S.phase=="round_end" then z(-11); GuiText(gui,ox+135*scale,oy+82*scale,S.result); if f>=S.round_end_ready then z(-11); GuiText(gui,ox+145*scale,oy+96*scale,"SPACE: NEXT ROUND") end end
 if S.phase=="finish_intro" then z(-11); GuiText(gui,ox+166*scale,oy+78*scale,"FINISH HIM!") end
 if S.phase=="fatality" or S.phase=="scorp_fatality" then dim_rect(1001,ox,oy,vw*scale,vh*scale,65) end
 if S.phase=="scorp_fatality" and S.scorp_fire_start>0 then local ft=f-S.scorp_fire_start; if ft>=0 and ft<48 then local fi=math.min(6,math.floor(ft/8)+1); img(1010,ox+(S.e_x-92)*scale+sx,oy+(floor_y-96)*scale,"files/gfx/scorpion/fire"..tostring(fi)..".png",1,scale,scale,40) end end
 if S.phase=="fatality_result" or S.phase=="fatality_result_enemy" then
  centered_text(ox+(vw*scale)*0.5,oy+77*scale,"FATALITY",-11)
  centered_text(ox+(vw*scale)*0.5,oy+89*scale,reward_text(S.phase=="fatality_result"),-11)
  if f>=S.match_end_ready then centered_text(ox+(vw*scale)*0.5,oy+104*scale,"SPACE: REMATCH     E: EXIT",-11) end
 end
 if S.phase=="match_end" then
  centered_text(ox+(vw*scale)*0.5,oy+82*scale,S.result,-11)
  centered_text(ox+(vw*scale)*0.5,oy+94*scale,reward_text(false),-11)
  if f>=S.match_end_ready then centered_text(ox+(vw*scale)*0.5,oy+107*scale,"SPACE: REMATCH     E: EXIT",-11); if just(Key_SPACE) then reset_match() end end
 end
end
local function update_idle() ensure_machine(); local p=player(); if p==0 then return end; local x,y=EntityGetTransform(p); local m=EntityGetInRadiusWithTag(x,y,20,"mk_arcade_machine") or {}; if #m>0 and interact(controls(p)) then start_game(p,m[1]) end end
local function update_active() silence_noita_music(); local p=S.player; if p==0 or not EntityGetIsAlive(p) then stop_game(); return end; EntitySetTransform(p,S.lock_x,S.lock_y); local v=EntityGetFirstComponentIncludingDisabled(p,"VelocityComponent"); if v then ComponentSetValue2(v,"mVelocity",0,0) end; if interact(controls(p)) then stop_game(); return end; update_fight(); draw_gui() end
function MortalKombatArcade_OnModInit() ModRegisterAudioEventMappings(BASE.."files/GUIDs.txt"); local path="data/translations/common.csv"; local csv=ModTextFileGetContent(path); csv=csv.."\nmk_arcade_play,Play MORTAL KOMBAT,MORTAL KOMBAT spielen,,,,,,,,,,,,,\n"; csv=csv.."mk_arcade_quit,Exit MORTAL KOMBAT,MORTAL KOMBAT verlassen,,,,,,,,,,,,,\n"; ModTextFileSetContent(path,csv) end
function MortalKombatArcade_OnWorldPreUpdate() local ok,err=pcall(function() if S.active then update_active() else update_idle() end end); if not ok then GamePrint("MK Arcade error - see logger"); print("[MK Arcade] "..tostring(err)); stop_game() end end
function MortalKombatArcade_OnPlayerDied() stop_bgm(); destroy_gui(); S.active=false end
