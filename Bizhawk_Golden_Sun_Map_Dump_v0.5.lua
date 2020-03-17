local fullmap = true      -- Change this value to False if you only want the unflowed out of bounds
local xextend = true      -- Get extended X unit data

local filename = "test.txt"
local filename2 = "testheight.txt"
local filename3 = "testevents.txt"
local tileValue = 0

--Dump control variables
local dump = false
local dumpstate = false
-- Old GS script functions
local pplock = false
local ppstate = false
local encounterlock = false
local encounterstate = false
local debugmode = false
local debugmodestate = false


-- Begin Script Functions

function compress(S)
    R = bit.rshift(memory.read_u32_le(S),16)
    R = bit.band(R,0xFF)
    return R
    end

function tile_height(X)
  	X = bit.rshift(X,24)
  	X = 0x202C000+X*4
  	X = memory.read_u32_le(X)
  	return X
  	end

function signed(X)
		if X >= 0x80 then
  		Y = X - 0x100
  	else Y=X
	     end
		return Y
	end

function extract_height(U)
    S = tile_height(memory.read_u32_le(U))
		if bit.band(S,0xF)==0 then
			height = bit.band(bit.rshift(S,8),0xFF)
			height = signed(height)
		elseif bit.band(S,0xF)==1 or bit.band(S,0xF)==2 or bit.band(S,0xF)==3 or bit.band(S,0xF)==4 or bit.band(S,0xF)==8 or bit.band(S,0xF)==9 then
			ha = bit.band(bit.rshift(S,8),0xFF)
			ha = signed(ha)
			hb = bit.band(bit.rshift(S,16),0xFF)
			hb = signed(hb)
			height = (ha+hb)/2
		else
			 height = bit.band(bit.rshift(S,8),0xFF)
			 height = signed(height)
	  end
		return height
	end

--if memory.read_u16_le(0x08000000) == 0x108 then
--  print("ROM: Golden Sun: The Lost Age")
--elseif memory.read_u8(0x08000000) == 0xEE then
--  print("ROM: Golden Sun")
--else
--  print("Oh no, something is wrong")
--end


-- Start of the script proper

while true do

keypress = input.get()

--Initiate Dump
if dumpstate == false and keypress["D"]==true and keypress["Shift"]==true and dump == false then
	dump = true
	dumpstate = true
	print("OOB Map Dumped")
end
if dumpstate == true and keypress["D"]==nil then
	dumpstate = false
end

--
if dump == true then

-- this bit prints out the tile value
  file = io.open(filename,"w+")
  io.output(file)
  for j=0,88 do
    if xextend == true then
      for i=-70,-1 do
        tileValue = compress(0x02005000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
      end
      io.write("- ")
    end
    for i=0,70 do
      tileValue = compress(0x02005000+j*0x200+0x4*i)
      io.write(tileValue .. " ")
    end
    io.write("\n")
  end
  if fullmap == true then
    if xextend == true then
      for i=-70,-1 do
        io.write("- ")
      end
    end
    for i=0,70 do
      io.write("- ")
    end
    io.write("\n")
    for j=1,128 do
      if xextend == true then
        for i=-70,-1 do
          tileValue = compress(0x02010000+j*0x200+0x4*i)
          io.write(tileValue .. " ")
        end
        io.write("- ")
      end
      for i=0,70 do
        tileValue = compress(0x02010000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
      end
      io.write("\n")
    end
  end
  print("Tile values written to " .. filename)
  io.close(file)

--This bit prints out the height map
  file = io.open(filename2,"w+")
  io.output(file)
  for j=0,88 do
    if xextend == true then
      for i=-70,-1 do
        tileValue = extract_height(0x02005000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
      end
      io.write("- ")
    end
    for i=0,70 do
      tileValue = extract_height(0x02005000+j*0x200+0x4*i)
      io.write(tileValue .. " ")
    end
    io.write("\n")
  end
  if fullmap == true then
    for i=0,70 do
      io.write("- ")
    end
    io.write("\n")
    for j=1,128 do
      if xextend == true then
        for i=-70,-1 do
          tileValue = extract_height(0x02010000+j*0x200+0x4*i)
          io.write(tileValue .. " ")
        end
        io.write("- ")
      end
      for i=0,70 do
        tileValue = extract_height(0x02010000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
      end
      io.write("\n")
    end
  end
  print("Height map written to " .. filename2)
  io.close(file)

--This writes out the event list for the Area
  file = io.open(filename3,"w+")
  io.output(file)
    eventtable = memory.read_u32_le(0x2030010)
    doorlist = {}
    objectlist = {}
    eventlist = {}
    doorlength = 0
    objectlength = 0
    eventlength = 0
    E = eventtable
    while memory.read_u32_le(E) ~= 0xFFFFFFFF do
      if memory.read_u8(E+0x4) > 0 then
        if bit.band(memory.read_u32_le(E),0xF) == 1 then
          table.insert(doorlist, memory.read_u8(E+0x4))
          doorlength = doorlength+1
        elseif bit.band(memory.read_u32_le(E),0xF) == 3 then
          table.insert(objectlist, memory.read_u8(E+0x4))
          objectlength = objectlength+1
        else
          table.insert(eventlist, memory.read_u8(E+0x4))
          eventlength = eventlength+1
        end
      end
      E = E+0xC
    end
    io.write("Doors ")
    for i=1,doorlength do
      io.write(doorlist[i] .. " \n")
    end
    io.write("\nObjects ")
    for i=1,objectlength do
      io.write(objectlist[i] .. " \n")
    end
    io.write("\nEvents ")
    for i=1,eventlength do
      io.write(eventlist[i] .. " \n")
    end
    io.close(file)
    print("Doors, objects, events writtent to " .. filename3)
  dump = false
end

function interesting_event()
    E = memory.read_u32_le(0x2030010)
    while memory.read_u32_le(E) ~= 0xFFFFFFFF do
      if memory.read_u8(E+0x4) > 0 then
        if bit.band(memory.read_u32_le(E),0xF) == 1 then
          table.insert(doorlist, memory.read_u8(E+0x4))
        elseif bit.band(memory.read_u32_le(E),0xF) == 3 then
          table.insert(objectlist, memory.read_u8(E+0x4))
        else
          table.insert(eventlist, memory.read_u8(E+0x4))
        end
      end
      E = E+0xC
    end
end

--tile+0x200*i+0x4*j


--- turn on debug mode
if debugmodestate == false and keypress["U"]==true and keypress["Shift"]==true and debugmode == false then
	debugmode = true
	debugmodestate = true
	print("Debug Mode Activated")
end
if debugmodestate == false and keypress["U"]==true and keypress["Shift"]==true and debugmode == true then
	debugmode = false
  debugmodestate = true
  print("Debug Mode Deactivated")
end
if debugmodestate == true and keypress["U"]==nil then
	debugmodestate = false
end
if debugmode == true then
  memory.writebyte(0x03001F54,1)
else
  memory.writebyte(0x03001F54,0)
end
-- This code is for locking Isaac's pp
if ppstate == false and keypress["P"]==true and keypress["Shift"]==true and pplock == false then
	pplock = true
	ppstate = true
	print("Isaac PP lock enabled")
end
if ppstate == false and keypress["P"]==true and keypress["Shift"]==true and pplock == true then
	pplock = false
	ppstate = true
	print("Isaac PP lock disabled")
end
if ppstate == true and keypress["P"]==nil then
	ppstate = false
end
if pplock == true then
	memory.writeword(0x0200053a,0x5)
end

-- This code is for toggling encounters
if encounterstate == false and keypress["E"]==true and keypress["Shift"]==true and encounterlock == false then
	encounterlock = true
	encounterstate = true
	print("Encounters disabled")
end
if encounterstate == false and keypress["E"]==true and keypress["Shift"]==true and encounterlock == true then
	encounterlock = false
	encounterstate = true
	print("Encounters enabled")
end
if encounterstate == true and keypress["E"]==nil then
	encounterstate = false
end
if encounterlock == true then
	memory.writeword(0x0200047A,0x1)
end

emu.frameadvance();
end



-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------


--tile = memory.read_u32_le(0x020301B8)
--tile_value = memory.read_u16_le(tile)



--function tile_height(X)
--    X = bit.rshift(X,24)
--    X = 0x202C000+X*4
--    X = memory.read_u32_le(X)
--    return X
--    end
--
--function signed(X)
--  if X >= 0x80 then
--    Y = X - 0x100
--  else Y=X
--  end
--  return Y
--end

--function extract_height(S)
--    if bit.band(S,0xF)==0 then
--      height = bit.band(bit.rshift(S,8),0xFF)
--      height = signed(height)
--    elseif bit.band(S,0xF)==1 or bit.band(S,0xF)==2 or bit.band(S,0xF)==3 or bit.band(S,0xF)==4 or bit.band(S,0xF)==8 or bit.band(S,0xF)==9 then
--      ha = bit.band(bit.rshift(S,8),0xFF)
--      ha = signed(ha)
--      hb = bit.band(bit.rshift(S,16),0xFF)
--      hb = signed(hb)
--      height = (ha+hb)/2
--    else
--       height = bit.band(bit.rshift(S,8),0xFF)
--       height = signed(height)
--    end

--    return height
--  end


--eventtable = memory.read_u32_le(0x2030010)
--function interesting_event()
--    E = eventtable
--    while memory.read_u32_le(E) ~= 0xFFFFFFFF do
--      if memory.read_u8(E+0x4) > 0 then
--        if bit.band(memory.read_u32_le(E),0xF) == 1 then
--          table.insert(doorlist, memory.read_u8(E+0x4))
--        elseif bit.band(memory.read_u32_le(E),0xF) == 3 then
--          table.insert(objectlist, memory.read_u8(E+0x4))
--        else
--          table.insert(eventlist, memory.read_u8(E+0x4))
--        end
--      end
--      E = E+0xC
--    end
--end

--if area ~= memory.read_u16_le(0x2000408) and eventtable > 0 and memory.read_u32_le(0x020301B8) > 0x02000000 and memory.read_u16_le(0x2000400)~=0 then
--  eventlist = {}
--  objectlist = {}
--  doorlist = {}
--  interesting_event()
--  area = memory.read_u16_le(0x2000408)
--  print("Area " .. area .. " door list: (green)")
--  print(doorlist)
--  print("Area " .. area .. " interaction list: (yellow)")
--  print(objectlist)
--  print("Area " .. area .. " event list: (pink)")
--  print(eventlist)
--end

--function eventcheck(element,tablu)
--  for _, value in pairs(tablu) do
--    if value == element then
--      return true
--    end
--  end
--  return false
--end

--function color(S)
--    T = tile_height(memory.read_u32_le(memory.read_u32_le(0x020301B8)))
--    U = tile_height(memory.read_u32_le(S))
--    if extract_height(T) == extract_height(U) then
--      C = "white"
--    elseif extract_height(T) < extract_height(U) then
--      shade = math.min((extract_height(U) - extract_height(T))/4*255,255)
--      C = { 255, 255-shade, 255-shade}
--    elseif extract_height(T) > extract_height(U) then
--      shade = math.min((extract_height(T) - extract_height(U))/4*255,255)
---      C = { 255-shade, 255, 255}
--    end
--    return C
--    end
--
--
--for i=-4,4 do
--  for j=-4,4 do
--    gui.text(110+j*15,100+i*15, compress(tile+0x200*i+0x4*j), color(tile+0x200*i+0x4*j))
--    if eventcheck(compress(tile+0x200*i+0x4*j),objectlist) == true then
--
--    elseif eventcheck(compress(tile+0x200*i+0x4*j),doorlist) == true then
--
--    elseif eventcheck(compress(tile+0x200*i+0x4*j),eventlist) == true then
--
--    end
--  end
