  
local fullmap = true      -- Change this value to False if you only want the unflowed out of bounds
local xextend = true      -- Get extended X unit data

local filename = "TileMap.txt"
local filename2 = "HeightMap.txt"
local filename3 = "EventMap.txt"
local tileValue = 0

function dump()

    -- Tilemap code
    local file = io.open(filename,"w+")
    io.output(file)
    for j=0,88 do
    if xextend == true then
        for i=-70,-1 do
        tileValue = compress(0x02005000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
        end
        io.write("- ")
        io.flush()
    end
    for i=0,70 do
        tileValue = compress(0x02005000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
    end
    io.write("\n")
    io.flush()
    end
    if fullmap == true then
    if xextend == true then
        for i=-70,-1 do
        io.write("- ")
        end
        io.flush()
    end
    for i=0,70 do
        io.write("- ")
    end
    io.write("\n")
    io.flush()
    for j=1,128 do
        if xextend == true then
        for i=-70,-1 do
            tileValue = compress(0x02010000+j*0x200+0x4*i)
            io.write(tileValue .. " ")
        end
        io.write("- ")
        io.flush()
        end
        for i=0,70 do
        tileValue = compress(0x02010000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
        end
        io.write("\n")
        io.flush()
    end
    end
    print("Tile values written to: " .. filename)
    io.close(file)

    -- Heightmap code
    file = io.open(filename2,"w+")
    io.output(file)
    for j=0,88 do
    if xextend == true then
        for i=-70,-1 do
        tileValue = extract_height(0x02005000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
        end
        io.write("- ")
        io.flush()
    end
    for i=0,70 do
        tileValue = extract_height(0x02005000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
    end
    io.write("\n")
    io.flush()
    end
    if fullmap == true then
    for i=0,70 do
        io.write("- ")
    end
    io.write("\n")
    io.flush()
    for j=1,128 do
        if xextend == true then
        for i=-70,-1 do
            tileValue = extract_height(0x02010000+j*0x200+0x4*i)
            io.write(tileValue .. " ")
        end
        io.write("- ")
        io.flush()
        end
        for i=0,70 do
        tileValue = extract_height(0x02010000+j*0x200+0x4*i)
        io.write(tileValue .. " ")
        end
        io.write("\n")
        io.flush()
    end
    end
    print("Height map written to: " .. filename2)
    io.close(file)

    --Eventmap code
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
    io.flush()
    io.write("\nObjects ")
    for i=1,objectlength do
        io.write(objectlist[i] .. " \n")
    end
    io.flush()
    io.write("\nEvents ")
    for i=1,eventlength do
        io.write(eventlist[i] .. " \n")
    end
    io.flush()
    io.close(file)
    print("Doors, objects, events written to: " .. filename3)
    
end