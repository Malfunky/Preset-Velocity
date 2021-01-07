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
change_velocity_when_selecting_note = true 
change_velocity_when_adjusting_velocity = true
change_velocity_with_slider  = true   -- possible when more than 2 notes are selected
change_velocity_on_last_selected_note = true 
go_back_to_slider_value_when_deleting_notes = false
set_slider_velocity_when_switching_take=true 
----------------------------------------------------

local name = "ddddddddddddddddddsgd334f3e_____________________gh" 

reaper.gmem_attach(name)  
fxname = "Note Preview" 
fxname2 = "Velocity Slider" 
sectionID = 0

local debug=true
function msg(g)
  if debug then 
     reaper.ShowConsoleMsg(tostring(g).."\n")
  end
end 
 
local bs = reaper.SetToggleCommandState(sectionID ,({reaper.get_action_context()})[4],1) 

function update()
  _trk=trk
  trk=reaper.GetMediaItemTake_Track(take) 
  if  _trk~=trk then msg("newtrack") 
     return reaper.defer( function() 
                            del(_trk)
                            ins(trk) 
                            return reaper.defer(update)
                          end)           
  end
   _,cnt,_,_ = reaper.MIDI_CountEvts(take)  
   _, newhash  = reaper.MIDI_GetHash( take, true, "" ) -- notesonly = true
  return reaper.defer( function()
                          selnotes=count_selected_notes() 
                          return reaper.defer(main)
  end)
end 

function main() 
     _take=take
    take = reaper.MIDIEditor_GetTake(reaper.MIDIEditor_GetActive() ) 
    if take == nil then return reaper.defer(main) end
    if take~=_take then msg("new take selected") 
       return reaper.defer(update)
    end
     ----------- This isnt really neccesery task ----
     if reaper.gmem_read(12) ==1 then -- test
        reaper.gmem_write(12,0) 
        reaper.gmem_write(13,1) 
        if selnotes>1 then 
          if change_velocity_with_slider then 
             return reaper.defer( function() 
                                chv(reaper.gmem_read(0)) 
                                update()
                              end) 
          end 
        end
     end
    ----------------- Hash section -------------------------     
      oldhash=newhash
      _, newhash  = reaper.MIDI_GetHash( take, true, "" ) -- notesonly
      if newhash~=oldhash then 
        return reaper.defer(track_mouse)  
      end 
   reaper.defer(main)
end

function track_mouse()
  get_left_mousebutton_state = reaper.JS_Mouse_GetState(0000001) 
  if get_left_mousebutton_state==1 then
       reaper.defer(track_mouse)    
  else  
      reaper.defer(checkMIDI)
  end
end 

function chv(targetVelocity) -- based on the Julian saders script
  gotAllOK, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  MIDIlen = MIDIstring:len()  
  tableEvents = {}  
  stringPos = 1  
  local a=0
  while stringPos < MIDIlen do
    offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)   
    if flags&1==1 then 
      a=a+1
      if ms:len() == 3
      and ms:byte(1)>>4 == 9 -- Note-on MIDI event type   
      then
        ms = ms:sub(1,2) .. string.char(targetVelocity) -- Replace velocity 
      end
    end
    table.insert(tableEvents, string.pack("i4Bs4", offset, flags, ms))
  end
  reaper.MIDI_SetAllEvts(take, table.concat(tableEvents))
end 

function count_selected_notes() 
  gotAllOK, MIDIstring = reaper.MIDI_GetAllEvts(take, "")
  MIDIlen = MIDIstring:len()  
  tableEvents = {}
  stringPos = 1  
  local count=0
  while stringPos < MIDIlen do
    offset, flags, ms, stringPos = string.unpack("i4Bs4", MIDIstring, stringPos)   
    if flags&1==1 then 
      if ms:len() == 3 and ms:byte(1)>>4 == 9     
      then
         count=count+1 
         vel = ms:byte(3)
      end
    end
  end
  return count,vel
end
 
function checkMIDI()
     _,cnt2,_,_ = reaper.MIDI_CountEvts(take)  
     if cnt2>cnt then 
        reaper.defer(function() 
                         chv(reaper.gmem_read(0))
                         return reaper.defer(update)
                    end)
     elseif cnt2==cnt then
        reaper.gmem_write(15,1) -- shut the preview [FAILED]
        selnotes,vel = count_selected_notes() 
        msg("Notes selected : "..selnotes) 
        if change_velocity_when_selecting_note then 
          local df = reaper.MIDIEditor_GetSetting_int(hwnd,"default_note_vel") 
        end    
        if change_velocity_when_adjusting_velocity then 
            if selnotes==1 then 
                reaper.gmem_write(0,vel) 
            end
       end 
     elseif cnt2<cnt then 
        msg("note deleted") 
        --if go_back_to_slider_value_when_deleting_notes then reaper.gmem_write(9,1) end
     end   
     return reaper.defer(update)
end 

reaper.atexit( function() 
  for i=0 , reaper.CountTracks(0) do
     trk=reaper.GetTrack(0,i)
     del(trk) 
  end
  msg("Atexit")
  reaper.SetToggleCommandState(sectionID ,({reaper.get_action_context()})[4],0) 
  reaper.gmem_attach("")
end) 

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

function detect() 
  local track
   for i=0, reaper.CountTracks(0)-1 do 
       track = reaper.GetTrack(0,i) 
       if track==nil then msg("track = nil") end 
       for j=0,reaper.TrackFX_GetCount( track)-1 do
           retval, buf = reaper.TrackFX_GetFXName( track,j,"") 
           msg("buf = "..buf)
           if buf:find(fxname2) then 
              return track
           end
       end
   end 
   -- ADD the velocity slider 
   local track = reaper.GetLastTouchedTrack()
   if track == nil then
      msg("no touched track, choose track 1") 
      track = reaper.GetTrack(0,0)
   end

   local number = reaper.TrackFX_AddByName( track, fxname2,0,-1)    
   if number==-1 then 
     msg("Unable to find an fx with name : "..fxname)
     return  
   else
      return track
   end
end 

detect()
msg("Starting preset velocity")
reaper.defer(main)