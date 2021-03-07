-------------------------------------------------------
-- SETS THE VELOCITY OF INSERTED NOTES TO A PRESET VALUE IN A JSFX 
-- THIS SCRIPT MANAGES THE LOADING AND MOVING AROUND OF THE NOTE PREVIEW JSFX
-- THIS SCRIPT SHOULD BE LOADED INTO THE MAIN SECTION
-- THE VELOCITY SLIDER IS NOT REMOVED WHEN SCRIPT IS CANCELLED.
-- SO THAT YOU CAN KEEP YOUR MIDI LEARN SETTINGS 
-- RECOMMENDED SETTINGS -->PREFERENCES -> EDITING BEHAVOIR -> MIDI EDITOR
-- ACTIVE MIDI ITEM FOLLOw SELECTON CHANGES IN ARRANGE VIEW [X] 
-- SELECTION IS LINKED TO EDITABILITY [X]
-------------------------------------------------------------------- 

-----------USER SETTINGS-----------------------
apply_to = {"MIDI editor: Insert note","MIDI editor: Insert notes"} -- look in the UNDO history
dont_apply_to = {"MIDI editor: Paste events"} 
change_preset_when_adjusting_velocity = true
change_preset_when_selecting_note = true
----------------------------------------------------

local name = "ddddddddddddddddddsgd334f3e_____________________gh" 
reaper.gmem_attach(name)  
fxname = "Note Preview" 
fxname2 = "Velocity Slider" 
sectionID = 0
-- Script generated by Lokasenna's GUI Builder 
 
local lib_path = reaper.GetExtState("Lokasenna_GUI", "lib_path_v2")
if not lib_path or lib_path == "" then
    reaper.MB("Couldn't load the Lokasenna_GUI library. Please install 'Lokasenna's GUI library v2 for Lua', available on ReaPack, then run the 'Set Lokasenna_GUI v2 library path.lua' script in your Action List.", "Whoops!", 0)
    return
end 

loadfile(lib_path .. "Core.lua")()
GUI.req("Classes/Class - Options.lua")()
GUI.req("Classes/Class - Slider.lua")()
-- If any of the requested libraries weren't found, abort the script.
if missing_lib then return 0 end

GUI.name = "Preset Velocity"
GUI.x, GUI.y, GUI.w, GUI.h = 0, 0, 145,160
GUI.anchor, GUI.corner = "screen",   "TR" 
GUI.escape_bypass = true 

GUI.New("Settings", "Checklist", {
    z = 11,
    x = 14.0,
    y = 71.0,
    w = 96,
    h = 50,
    caption = "Change preset when",
    optarray = {"Selecting note", "Adjusting velocity" },
    dir = "v",
    pad = 4,
    font_a = 3,
    font_b = 3,
    col_txt = "txt",
    col_fill = "red",
    bg = "wnd_bg",
    frame = false,
    shadow = true,
    swap = nil,
    opt_size = 20
})

GUI.New("Preset_Velocity", "Slider", {
    z = 11,
    x = 23.0,
    y = 34.0,
    w = 96,
    caption = "Preset Velocity",
    min = 1,
    max = 127,
    defaults = {1},
    inc = 1,
    dir = "h",
    font_a = 3,
    font_b = 3,
    col_txt = "txt",
    col_fill = "red",
    bg = "wnd_bg",
    show_handles = true,
    show_values = true,
    cap_x = 0,
    cap_y = 0
})

GUI.func = function()  
    GUI.Val("Preset_Velocity", reaper.gmem_read(0)-1)  
    local table = GUI.Val("Settings")
    change_preset_when_selecting_note = table[1]
    change_preset_when_adjusting_velocity = table[2] 
end  

function GUI.elms.Preset_Velocity:onmousedown()
   GUI.Slider.onmousedown(self)
   reaper.gmem_write(0,GUI.Val("Preset_Velocity")) 
   reaper.gmem_write(9,1) --tell jsfx slider to update
end 

function GUI.elms.Preset_Velocity:ondrag() 
   GUI.Slider.ondrag(self)
   reaper.gmem_write(0,GUI.Val("Preset_Velocity")) 
   reaper.gmem_write(9,1)
end 

function GUI.elms.Preset_Velocity:onwheel(inc) 
   local nv = GUI.Val("Preset_Velocity")+inc*5 
   if nv<1 then nv=1 end 
   if nv>127 then nv=127 end
   reaper.gmem_write(0,nv) 
   reaper.gmem_write(9,1)   
end 

local bs = reaper.SetToggleCommandState(sectionID ,({reaper.get_action_context()})[4],1) 

function ins(trk) --add previewnote FX 
  if trk==nil then 
     trk=reaper.GetMediaItemTake_Track(take)
  end
  local n = reaper.TrackFX_AddByName(trk,fxname,false ,  -1)
  reaper.TrackFX_CopyToTrack( trk, n, trk, 0, true ) --reorder
  return trk
end 

function del(tr) -- delete the preview fx
if tr==nil then 
  if take==nil then return end
  tr=reaper.GetMediaItemTake_Track(take)
end
  for i=0 , reaper.TrackFX_GetCount(tr)  do 
      local buf=""
      _,buf = reaper.TrackFX_GetFXName(tr,i, buf)  
      if buf=="JS: Note Preview" then   --try   buf:find(fxname)
        local b = reaper.TrackFX_Delete(tr,i) 
      end
  end
end 

function detect() -- Look for velocity slider or create one at lastclicked or 1st track
  local track
  for i=0, reaper.CountTracks(0)-1 do 
     track = reaper.GetTrack(0,i) 
     if track==nil then end 
     for j=0,reaper.TrackFX_GetCount( track)-1 do
         retval, buf = reaper.TrackFX_GetFXName( track,j,"") 
         if buf:find(fxname2) then 
            reaper.TrackFX_Show( track, j, 3)
            return track
         end
     end
  end 
  -- ADD the velocity slider 
  local track = reaper.GetLastTouchedTrack()
  if track == nil then
    track = reaper.GetTrack(0,0)
  end

  local number = reaper.TrackFX_AddByName( track, fxname2,0,-1)    
  if number==-1 then 
    return  
  else 
    reaper.TrackFX_Show( track, number, 3)
    return track
  end
end 

function updatetable() 
   gotAllOK, MIDIstring = reaper.MIDI_GetAllEvts(take, "") 
   MIDIlen = MIDIstring:len()  
   tableEvents = {}  
   local _tablePos={} 
   local _tableNoteon ={} 
   stringPos = 1  
   pos=0
   local a=1 
   selected_notes = 0
   while stringPos < MIDIlen do 
      offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) 
      pos=pos+offset 
      if ms:len() == 3 and ms:byte(1)>>4 == 9 then 
        _tableNoteon[a]=ms 
        _tablePos[a]=pos 
        a=a+1 
        if flags&1==1 then
          selected_notes = selected_notes + 1 
          last_velocity = ms:byte(3)
        end
      end 
     
   end 
   tablePos=_tablePos 
   tableNoteon=_tableNoteon 
end 

function SetVelocityUnselected(tV) 
   local gotAllOK
   local MIDIstring 
   gotAllOK, MIDIstring = reaper.MIDI_GetAllEvts(take, "") 
   MIDIlen = MIDIstring:len()  
   tableEvents = {}  
   local _tablePos={} 
   local _tableNoteon ={} 
  -- tNoteons={}
   stringPos = 1  
   pos=0 
   local countVC = 0
   local a=1 
   local b=1
   while stringPos < MIDIlen do 
      offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos) 
      pos=pos+offset
      if ms:len() == 3 and ms:byte(1)>>4 == 9 then 
         if tV~=nil then 
            if tableNoteon[b]~=nil then 
              if tableNoteon[b]:byte(2)==ms:byte(2) and tablePos[b]==pos then 
                  b=b+1
               else 
                   if countVC <= notes_added then --blocks a potential chain reaction of unexplainable velocity changes
                      ms = ms:sub(1,2)..string.char(tV) -- change velocity  
                      countVC = countVC + 1
                   else end    
               end 
            else 
               if countVC <= notes_added then 
                  ms = ms:sub(1,2)..string.char(tV) 
                  countVC = countVC + 1
               else  end 
            end
          end
          _tableNoteon[a]=ms 
          _tablePos[a]=pos 
          a=a+1 
      end 
      table.insert(tableEvents, string.pack("i4Bs4", offset, flags, ms))  
   end 
   tablePos=_tablePos 
   tableNoteon=_tableNoteon 
   reaper.MIDI_SetAllEvts(take, table.concat(tableEvents)) 
end 

_debounce = false -- prevent multiple calls
function update() 
  if not _debounce then 
    _debounce = true
    _trk=trk
    trk=reaper.GetMediaItemTake_Track(take) 
    if  _trk~=trk then 
       del(_trk)
       ins(trk)        
       color_ = reaper.GetTrackColor(trk)
    end
    updatetable() 
    _, cnt = reaper.MIDI_CountEvts(take)
    _, newhash  = reaper.MIDI_GetHash( take, true, "" )  
    _debounce=false
    return main()
  else 
  end
end 

function main()  
  if not _debounce then 
    if GUI.char ==-1 then return end -- close script when GUI closes
    _take=take 
    _item=item
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive() ) 
    --ret = reaper.ValidatePtr(take,"MediaItem_Take*") 

    retval_ = pcall(function()  --prevent crash when gluing midiitems
      item=reaper.GetMediaItemTake_Item(take)
    end) 
    if not retval_ then 
       take=nil
    end 
    if take ~= nil then 
      if take~=_take or item~=_item then 
        return update()
      end
       ----------------- Hash section -------------------------     
       oldhash=newhash
       _, newhash  = reaper.MIDI_GetHash( take, true, "" ) -- notesonly    
       if newhash~=oldhash then  
           return track_mouse()
       end 
    end 
    
    return reaper.defer(main) 
  else end
end

function track_mouse() -- give the user time to drag and extend note
   --get_left_mousebutton_state = reaper.JS_Mouse_GetState(0000001)  
   get_left_mousebutton_state = reaper.JS_Mouse_GetState(1)  
   if get_left_mousebutton_state==1 then 
       return reaper.defer(track_mouse)    
   end 
   if get_left_mousebutton_state==0 then
      return checkMIDI()
   end
end 

function checkMIDI() 
    _cnt = cnt
    _, cnt = reaper.MIDI_CountEvts(take) 
    notes_added = cnt - _cnt 
    undo = reaper.Undo_CanUndo2(0) 
    if cnt>_cnt then -- DOnt use ctrl-z to delete notes
      for h=1 , #apply_to do 
         if undo==apply_to[h] then 
            SetVelocityUnselected(reaper.gmem_read(0)) 
            return update()
         end 
      end 
       for h=1,#dont_apply_to do 
         if undo==dont_apply_to[h] then 
           return update()
         end 
       end
    end 
    if _cnt==cnt then 
       updatetable()
       if undo=="MIDI editor: Move events" then   
          return update()
       end 
       if selected_notes==1 then 
           if undo=="MIDI editor: Select events" then 
               if change_preset_when_selecting_note  then 
                  if last_velocity then
                     reaper.gmem_write(1,reaper.gmem_read(0))
                     reaper.gmem_write(0,last_velocity) 
                  end 
               else 
               return update()
           end 
        end 
        if change_preset_when_adjusting_velocity then -- the GUI slider will move with any velocity adjustments of note
           reaper.gmem_write(0,last_velocity) 
        end
      end
    end 
    if cnt<_cnt then 
       if undo == "MIDI editor: Cut events" then 
          return update()
       end 
       if undo == "MIDI editor: Delete events" then 
       end 
    end
    return update()
end 

reaper.atexit( function() 
   local s1 
   local s2 
   if change_preset_when_selecting_note==true then s1="1"  else s1="0" end 
   if change_preset_when_adjusting_velocity==true then s2="1" else s2="0" end 
   reaper.SetExtState("Preset Velocity","change_preset_when_adjusting_velocity",s2,true)
   reaper.SetExtState("Preset Velocity","change_preset_when_selecting_note",s1,true)
   for i=0 , reaper.CountTracks(0) do
      trk=reaper.GetTrack(0,i)
      del(trk) 
   end
   reaper.SetToggleCommandState(sectionID ,({reaper.get_action_context()})[4],0) 
   reaper.gmem_attach("")
end) 

local s={}

local _val_ = reaper.GetExtState("Preset Velocity","change_preset_when_selecting_note") 
if _val_=="1" then s[1] = true end 
if _val_=="0" then s[1] = false end 

local _val_ = reaper.GetExtState("Preset Velocity","change_preset_when_adjusting_velocity") 
if _val_=="1" then s[2] = true end 
if _val_=="0" then s[2] = false end
 
GUI.Val("Settings",s)
GUI.freq = 0.2 
GUI.Init()
GUI.Main() 

tableNoteon = {} 
tablePos = {}
detect()
reaper.defer(main)