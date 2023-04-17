function unpack_decorator(f) -- redefine unpack to include 0th key in arrays
    local function inner(array)
        if array == nil then return end
        if array[0] ~= nil then
            return array[0], f(array)
        else
            return f(array)
        end
    end
    return inner
end
table.unpack = unpack_decorator(table.unpack)

local version = (memory.read_u8(0x080000A0) == 0x4F) and "J" or "U" -- check version and set global
    JPN = nil
    if version == "J" then JPN = 1 else JPN = 0 
    end

local AD1 = 0x0200053a -- Isaac PP
local AD3 = 0x02000479 -- Next Encounter
local AD4 = 0x020023A8 -- Battle RN
local AD5 = 0x03001CB4 -- General RN
local AD6 = (0x020301A8) -- Encounter Step Counter
local EncounterRate = memory.read_u32_le(0x02000478)
local gcount = 0
local bcounter = 0
local store = memory.read_u32_le(0x03001CB4)
local bstore = memory.read_u32_le(0x020023A8)
local brncount=0
local fleestore = 0
local fleepercent = 0
local mem = 0x2010000
local memcount = 0
local keypress = {}
local state = false
local brnadvancecounter = 0
local brnreducecounter = 0
local grnadvancecounter = 0
local grnreducecounter = 0
local timerstate = false
local timeron = false
local fighttimer = 0
local infight = false
local fighttimertext = 0
local fightlength = 0

local pplock = false
local ppstate = false

local encounterlock = false
local encounterstate = false

local minorhudlock = true
local minorhudstate = false

local overlaystate = false
local overlay = false

local randomisercounter = 0
local    randomiserstate = false
local grnrandomisercounter = 0
local    grnrandomiserstate = false

local nosq = false
local nosqstate = false

local debugmode = false
local debugmodestate = false

local DialID

local BRN_temp = 0
local BRN_temps = 0
local BRN_tempss = 0
local BRN_tempsss = 0
local BRN_tempssss = 0

local RatePredictionRNGStore = 0
local RatePredictionVectorStore = {{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0},{0,0}}
local tableVariableStore = 0

local globaltimerstate = false
local globaltimeron = false
local globaltimerpause = false
local globaltimer = 0
local globaltimertext = 0
local globallength = 0
local globaltimerstore = {0,0,0}
local globaltimerstoretimer = 0

local BaseHP = 0x02000510
local BasePP = 0x02000512
local BaseAtk = 0x02000518
local BaseDef = 0x0200051A
local BaseAgi = 0x0200051C
local BaseLuc = 0x0200051E -- read_u8 for this entry
local Cursor = (0x050003CA) -- alternatively, 0x03007DE4 which gives slot in part, not character
--local CursorGaret = (0x020333F0) -- as above
--local CursorIvan = (0x02033428)
--local CursorMia = (0x02033460)
local CharMemDiff = 0x14C -- gap between character memory values
local CurrentChar = 0
local CurrentName = ""
local CharEXP = 0
local IsaacLevels = {0,24,67,144,283,519,873,1369,2039,2910,3999,5306,6861,8696,10843,13334,16224,19548,23371,27767,32778,38491,45004,52429,60893,70457}--26 levels
local GaretLevels = {0,30,84,176,332,582,957,1482,2191,3113,4265,5647,7292,9233,11504,14138,17193,20706,24746,29271,34339,40015,46372,53492,61894,71808}
local IvanLevels =  {0,32,90,194,350,568,895,1418,2150,3102,4292,5720,7419,9424,11770,14491,17647,21276,25449,30248,35719,41956,49066,57171,66411,76852}
local MiaLevels =   {0,31,87,188,350,609,997,1540,2273,3226,4341,5657,7197,8999,11107,13594,16529,19992,24078,28899,34395,40660,47802,55944,65226,75715}
local levelstore = 1
local statstate = false
local StatColor = {0xFF00FF00,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF,0xFFFFFFFF}
local SelectedStat = 0
local StatToChange = 0
local IsaacGoals = {{30,182},{20,80},{13,86},{6,38},{8,86}}
local GaretGoals = {{33,191},{18,76},{11,83},{8,41},{6,76}}
local IvanGoals = {{28,166},{24,92},{8,76},{4,35},{11,91}}
local MiaGoals = {{29,173},{23,90},{9,79},{5,37},{7,80}}
local CurrentGoals = {{0,0},{0,0},{0,0},{0,0},{0,0}}

local StatusMenuOpen = false

local RNmultipliers = {0x41C64E6D}
local RNintervals = {0x3039}

function multMod (A,B,C) -- Multiplies big numbers, and takes mod 2^32
  local a1 = (A >> 16)
  local a2 = (A >> 0xFFFF)
  local b1 = (B >> 16)
  local b2 = (B & 0xFFFF)
  local p = ((((a1*b2 + a2*b1) << 16) + a2*b2 + C) & -1)
  if p<0 then return p + 2^32 
  else return p end
end

for i=1,31 do -- Constructs the effective multipliers and increments for each power of 2
  RNmultipliers[i+1] = multMod(RNmultipliers[i],RNmultipliers[i],0)
  RNintervals[i+1] = multMod(RNintervals[i],RNmultipliers[i],RNintervals[i])
end

function PluginDetect(arg) -- detect which plugin scripts are installed
    local out = {}
    for i=1,#arg do
    local FileName = arg[i]
      if string.find(FileName, "%.%a+$") == nil then FileName = FileName + ".lua"
      end
    local File = io.open(arg[i], "r")
      if File ~= nil then io.close(File); table.insert(out, true)
      else table.insert(out, false)
      end
    end
    return table.unpack(out)
end

function gui.scaledtext (x, y, ...)  -- scales gui elements to emulator screen ratio
    local borderX = client.borderwidth()
    local borderY = client.borderheight()
    local width = client.screenwidth() - 2*borderX
    local height = client.screenheight() - 2*borderY
    gui.text(x/240 * width + borderX, y/160 * height + borderY, table.unpack(arg))
end

function LevelCalculator(CurrentCharacter)
  CharEXP = memory.read_u32_le(0x02000624+CharMemDiff*CurrentCharacter)
  levelstore = 1
  if CurrentCharacter == 0 then
    CharLevels = IsaacLevels
  elseif CurrentCharacter == 1 then
    CharLevels = GaretLevels
  elseif CurrentCharacter == 2 then
    CharLevels = IvanLevels
  elseif CurrentCharacter == 3 then
    CharLevels = MiaLevels
  end
  while CharEXP - CharLevels[levelstore+1] > 0 do
    levelstore = levelstore + 1
  end
  return levelstore
end

function WhichStat(S,C) -- SelectedStat, CurrentChar
  if S == 0 then
    return BaseHP+CharMemDiff*C
  elseif S == 1 then
    return BasePP+CharMemDiff*C
  elseif S == 2 then
    return BaseAtk+CharMemDiff*C
  elseif S == 3 then
    return BaseDef+CharMemDiff*C
  elseif S == 4 then
    return BaseAgi+CharMemDiff*C
  end
end
--@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
-- New things from TLA Utility Script 2.2

-- Good Rate analysis
local GoodRateThreshold = 0xC00 -- Hex value between 0x100 and 0x16000
local CurrentRate = 0
local encounteranalysisstate = false
local encounteranalysis = false

local encounterColor = {0,0,0}
local encounterValue = memory.read_u32_le(0x02000478)
local encounterPreviousvalue = memory.read_u32_le(0x02000478)

-- Exploratory Rate analysis
local OldRate = 0
local NewRate = 0
local RateRate = 0
local WorldMapOffset = 0
local StepGRNOffset = 0
local moveList = {"Base", "Move", "Frost", "Growth", "Douse / Halt", "Lift / Carry", "Mind Read"}
local grnAdvanceList = {0, 295, 96, 63, 80, 72, 0}
local tableVariable = 1
local tableVairabletemp = 1
local tableState = false


function NormalisedRate(IN) -- takes the encounter rate value returns a number between 0-100, 0 being low enc and 100 being high enc
    NormRate = memory.read_u32_le(IN)
    --IsNegative = 0
    if NormRate == 0 then
        NormRate = ""
        return NormRate
    else
        if NormRate >= 0xFFFF0000 then
            NormRate = NormRate - 0xFFFFFFFF
            --IsNegative = 1
        end
        NormRate = math.floor((0xFFFF - NormRate)/0xFF0)
        return NormRate
    end
end

function NormalisedRate2(IN) -- takes the encounter rate value returns a number between 0-100, 0 being low enc and 100 being high enc
    NormRate = IN
    --IsNegative = 0
    if NormRate == 0 then
        NormRate = ""
        return NormRate
        else
        NormRate = math.floor((0xFFFF - NormRate)/0xFF0)
        return NormRate
    end
end

function NormalisedRate3(IN) -- takes the encounter rate value returns a number between 0-100, 0 being low enc and 100 being high enc
    NormRate = IN
    --IsNegative = 0
    NormRate = math.floor((0xFFFF - NormRate)/0xFF0)
    return NormRate
end

--------------------------------------------------- NEW SHIT STARTS HERE
function RNC(R)   -- RN concatenate
    return ((R >> 8) & 0xFFFF)
end


function RatePrediction(IN)
    RatePred1 = math.floor(RNC(RNA(IN)))
    RatePred2 = math.floor(RNC(RNA(RNA(IN))))
    RatePred3 = math.floor(RNC(RNA(RNA(RNA(IN)))))
    RatePred4 = math.floor(RNC(RNA(RNA(RNA(RNA(IN))))))
    RatePred =  math.floor(RatePred1 - RatePred2 + RatePred3 - RatePred4)/2
    return RatePred
end

function RatePsyCalc(IN,ADV)
    R=RNA(IN,ADV)
    R=RatePrediction(R)
    R=NormalisedRate3(R)
    return R
end

function ColorRate(R) -- R = ColorRate1
    ColorRateS= 0xFFFF0000
    ColorRateShade = math.floor((22-R)/22*255)
    if ColorRateShade <= 63 then
        ColorRateS = 0xFFFF0000 + 1024*ColorRateShade
    elseif ColorRateShade <=191 then
        ColorRateS = 0xFF00FF00 + 256*256*(255-255*(ColorRateShade-63)/128-1)
    else
        ColorRateS = 0xFF00FF00
    end
    return ColorRateS
end

--function PercentRoll(RNG,Percent)         --unused
    --RNG = &(>>(RNG,8), 0xFFFF)
    --return >>(RNG*Percent,16)
--end


--begin the script proper
print("Welcome to the Golden Sun Utility Script")
print("Currently configured for " .. version .. " version")
print("Commands:")
print("shift+g: advances the GRN by one")
print("shift+b: advances the BRN by one")
print("shift+r: advance BRN/GRN by a random amount")
print("shift+a: toggle minor hud")
print("shift+t: toggle battle timer")
print("shift+y: force display of last fight length (timer must be on)")
print("shift+p: lock Isaac's pp to 5")
print("shift+e: toggle encounters")
print("shift+o: toggle map data overlay")
print("shift+q: toggle global timer")
print("shift+k: toggle no s&q probabilities")
print("In the status menu, use 'I' and 'K' to select a stat to change. 'L' to advance the stat by 1, 'J' to decrease the stat by 1.")


function RNA (R, advances) -- RN Advance Function
    if advances == nil then 
        return multMod(R, RNmultipliers[1], RNintervals[1])
    else
        advances = (advances & -1)
        for i=1,32 do
            if (advances & 1)==1 then
            R = multMod(R, RNmultipliers[i], RNintervals[i])
            end
            advances = (advances >> 1)
            if advances == 0 then break end
        end
        return R
    end
end

function RNB (R) -- RN Advance and reduce for use in RNG calculations
    return ((RNA(R) >> 8) & 0xFFFF)
end

function FindKey(table, value) -- function to help search arrays
    for k,v in pairs(table) do
      if v == value then return k end
    end
end

function FindItemHolder(ItemIndex) -- this lets us find out who's wearing a specific item
    for i=0,3 do
        for j=0,14 do
          if ((2^10-1) & (memory.read_u16_le(0x020005D8 + 2*j + 0x14C*i)))==(0x200 + ItemIndex) then
            return i
          end
        end
    end
end

local   VenusDjinn = {"Flint","Granite","Quartz","Vine","Sap","Ground","Bane"}  -- Array of all TBS Djinn
local   MercDjinn = {"Fizz","Sleet","Mist","Spritz","Hail","Tonic","Dew"}
local   MarsDjinn = {"Forge","Fever","Corona","Scorch","Ember","Flash","Torch"}
local   JupDjinn = {"Gust","Breeze","Zephyr","Smog","Kite","Squall","Luff"}

local   DjinnType = {VenusDjinn,MercDjinn,MarsDjinn,JupDjinn} -- Lets us select the element we need

function FindDjinniHolder(DjinnName)
    local DjinnIndex, ElementNum
    for i=1,4 do
        DjinnIndex = FindKey(DjinnType[i], DjinnName)
        if DjinnIndex ~= nil then ElementNum = i-1; break; end
    end
    DjinnIndex = DjinnIndex - 1
    
    local BaseAddress = 0x020005F8 + 4*ElementNum
    for i=0,3 do
        if (2^DjinnIndex & memory.read_u8(BaseAddress + 0x14C*i)) ~= 0 then 
            return i
        end
    end
end

BattleState = nil -- Encounter detection

local MapDataCheck, EncounterDataCheck = PluginDetect({"MapData.lua","EncounterData.lua"}) -- check plugin installations

if MapDataCheck == true then -- if plugin is installed
    print("MapData plugin detected.\n Shift+D to save data.")
    require("MapData")
end
if EncounterDataCheck == true then
    print("EncounterData plugin detected.\n Ctrl+E to display.")
    require("EncounterData")
end

while true do
keypress = input.get()

gui.scaledtext(0,0,"Frame:"..(emu.framecount()),nil,"bottomleft")
gui.scaledtext(180,0,"BRN: ".. (memory.read_u32_le(AD4)))
gui.scaledtext(180,10,"GRN: ".. (memory.read_u32_le(AD5)))
--gui.scaledtext(0,80,"Dialogue ID:".. (memory.read_u16_le(0x020301D8)))

if minorhudlock==false then
if mem <= 0x2008000 then
    mem = 0x2010000
    memcount=0
end
if memory.read_u32_le(mem) ~= 0 then
    if memory.read_u32_le(mem+0x4) ~=0 or memory.read_u32_le(mem+0x8)~=0 or memory.read_u32_le(mem+0xB)~=0 or memory.read_u32_le(mem+0xF)~=0 or memory.read_u32_le(mem+0x10)~=0 then
    mem = 0x2010000
    memcount=0
    end
end
while memcount <= 20000 and memory.read_u32_le(mem) == 0 or mem==0x02010000 do
    mem = mem-0x4
    memcount = memcount+1
end
    
    --show our X,Y coordinates while not in combat or the overworld
if memory.read_u16_le(0x02000400)~=0x1FE and memory.read_u16_le(0x02000400)~=0x02 then
    local tile = memory.read_u32_le(0x020301B8)
    local tile_value = memory.read_u16_le(tile)
gui.scaledtext(80,20,"Tile Address: 0x".. string.format("%x",tile))
gui.scaledtext(120,0,"X: " .. string.format("%.6f",(memory.read_u32_le(0x02030ec4)/0x0100000)))
gui.scaledtext(120,10,"Y: " .. string.format("%.6f",(memory.read_u32_le(0x02030ecc)/0x100000)))
end

    --find nonzero
gui.scaledtext(180,0,"Nonzero Tile: " .. memcount,nil,"bottomleft")
end

-- Attacks First, Caught by Surprise Check
function AF (R) -- Attacks First Check, 0 = nothing, 1 = AF, 2 = CBS
    R1=R
    R2 = RNB(R1)
    R1 = (R1 << 8)
    R1 = (R1 >> 16)
    if (R1 & 0xF) == 0 then
        return 1
    else
        if (R2 & 0x1F) ==0 then
            return 2
        else
            return 0
        end
    end
end

    -- Cycle-based bossfight calculators follow
    -- Determine the starting point for the Saturos battle

function ModRoll(RNG, modvalue)  -- for modular cycles
    return (RNG >> 8) % modvalue
end
   
function SaturosCycle(Advances)
    return ModRoll(RNA(memory.read_u32_le(AD4),Advances), 8)
end
   
local SaturosMoveset = {[0] = "HF", "FB", "Atk", "FB", "HF", "Atk", "Erup", "Atk"}
   
if memory.read_u8(0x020309A0)==0xA1 then     -- if we are fighting Sleet, show our starting point for several BRN
gui.scaledtext(170,40,"Saturos:")
    for i=0,8 do
        local colour = 0xFFFFFFFF
        local CycleNum = SaturosCycle(i)
        if CycleNum == 7 then colour = 0xFF00FF00 elseif CycleNum == 6 then colour = 0xFF0000FF else colour = 0xFFFF0000 end
            gui.scaledtext(170,50 + 10*i, "+" .. tostring(i) .. ": " .. SaturosMoveset[SaturosCycle(i)] .. "-" .. SaturosMoveset[(SaturosCycle(i)+1) % 8], colour)
    end
end

    -- 
pc1 = memory.read_u8(0x02000438)
pc2 = memory.read_u8(0x02000439)
pc3 = memory.read_u8(0x0200043A)
pc4 = memory.read_u8(0x0200043B)

        -- Missing Agility Scripts
if memory.read_u16_le(0x02000400) ~= 0x1FE and minorhudlock == false and StatusMenuOpen == false then
    iagi=memory.read_u8(0x02000500+0x1C+0x14C*0)
    ilv=memory.read_u8(0x02000500+0x14C*0+0xF)
    iagilv=-iagi+(ilv-1)*4+0xC -- imperfect levels ups discounting randomly rolled stats on new file
    gagi=memory.read_u8(0x02000500+0x1C+0x14C*1)
    glv=memory.read_u8(0x02000500+0x14C*1+0xF)
    gagilv=-gagi+(glv-1)*4+0xA -- imperfect levels ups discounting randomly rolled stats on new file
    vagi=memory.read_u8(0x02000500+0x1C+0x14C*2)
    vlv=memory.read_u8(0x02000500+0x14C*2+0xF)
    vagilv=-vagi+(vlv-4)*4+0x1B -- imperfect levels ups discounting randomly rolled stats on new file
    magi=memory.read_u8(0x02000500+0x1C+0x14C*3)
    mlv=memory.read_u8(0x02000500+0x14C*3+0xF)
    magilv=-magi+(mlv-10)*4+0x2C -- imperfect levels ups discounting randomly rolled stats on new file
    gui.scaledtext(60,0,"Missing Agi I:" .. iagilv .. " G:" .. gagilv .. " V:" .. vagilv .. " M:" .. magilv,nil,"bottomleft")
end

        -- begin enemy HP/encounter loops
    --Agility Battle Scripts
local pcag1=memory.read_u16_le(0x0203033C)
local pcag2=memory.read_u16_le(0x0203033C+0x10)
local pcag3=memory.read_u16_le(0x0203033C+0x20)
local pcag4=memory.read_u16_le(0x0203033C+0x30)

if     memory.read_u8(0x02030368)==0xFF and memory.read_u8(0x02030368+0x02)==0 then -- Hacky way of checking if we are in fight menu or battle
    if pcag1 >= 1000 then
    pcag1 = memory.read_u8(0x02000540+0x14C*pc1)
    end
    if pcag2 >= 1000 then
    pcag2 = memory.read_u8(0x02000540+0x14C*pc2)
    end
    if pcag3 >= 1000 then
    pcag3 = memory.read_u8(0x02000540+0x14C*pc3)
    end
    if pcag4 >= 1000 then
    pcag4 = memory.read_u8(0x02000540+0x14C*pc4)
    end
    gui.scaledtext(0,40,"PC" .. pc1 .. " Agi: " .. pcag1) -- Displays agility of party member pc1
    gui.scaledtext(0,50,"PC" .. pc2 .. " Agi: " .. pcag2)
    gui.scaledtext(0,60,"PC" .. pc3 .. " Agi: " .. pcag3)
    gui.scaledtext(0,70,"PC" .. pc4 .. " Agi: " .. pcag4)

    if memory.read_u8(0x020308B0)>0 then
        gui.scaledtext(60,40, "E1 Agi: " .. memory.read_u8(0x020308B0+0x8)) -- If Enemy 1 has nonzero HP display E1 agility
        gui.scaledtext(110,40, "HP: " .. memory.read_u16_le(0x020308B0))
    else
    end

    if memory.read_u8(0x020308B0+0x14C)>0 then
        gui.scaledtext(60,50, "E2 Agi: " .. memory.read_u8(0x020308B0+0x8+0x14C))
        gui.scaledtext(110,50, "HP: " .. memory.read_u16_le(0x020308B0+0x14C))
    else
    end

    if memory.read_u8(0x020308B0+0x14C*2)>0 then
        gui.scaledtext(60,60, "E3 Agi: " .. memory.read_u8(0x020308B0+0x8+0x14C*2))
        gui.scaledtext(110,60, "HP: " .. memory.read_u16_le(0x020308B0+0x14C*2))
    else
    end

    if memory.read_u8(0x020308B0+0x14C*3)>0 then
        gui.scaledtext(60,70, "E4 Agi: " .. memory.read_u8(0x020308B0+0x8+0x14C*3))
        gui.scaledtext(110,70, "HP: " .. memory.read_u16_le(0x020308B0+0x14C*3))
    else
    end

    if memory.read_u8(0x020308B0+0x14C*4)>0 then
        gui.scaledtext(60,80, "E5 Agi: " .. memory.read_u8(0x020308B0+0x8+0x14C*4))
        gui.scaledtext(110,80, "HP: " .. memory.read_u16_le(0x020308B0+0x14C*4))
    else
    end

elseif memory.read_u16_le(0x02000400)==0x1FE then -- otherwise, we are in a battle and do the following
local j=1
local k=1
local trn={}
    while memory.read_u8(0x02030338+0x04+0x10*(j-1)) ~= 0 do --while loop which checks nonzero agilities and therefore count number of actors in the battle
        trn[j]= memory.read_u8(0x02030338+0x10*(j-1)) -- add the character index to the trn array in order
        if trn[j]==0xFF then -- if user has already acted then do nothing
            j=j+1
            else
            gui.scaledtext(310+20*k,105,trn[j]) -- if user hasn't acted then display user in the turn order queue
            j=j+1
            k=k+1
            end
        end

    gui.scaledtext(40,40, "Turn Order: ")
    end

    -- Agility Bonus Calculator
if memory.read_u8(0x0203033C-0x50)>0 then
    local l=1
    while memory.read_u8(0x02030328-0x50+0x10*l) ~= pc1 and l<15 do
            l=l+1
    end
    if l~=15 then
        pcntag1=(memory.read_u8(0x02030328-0x50+0x10*l+0x04)-memory.read_u8(0x02000BDC+0x14C*(pc1-5)))/memory.read_u8(0x02000BDC+0x14C*(pc1-5))*10000
        pcntag1= math.floor(pcntag1)/100
        gui.scaledtext(0,90,"PC" .. pc1 .. " Bonus: " .. pcntag1 .. "%")
    end

    local l=1
    while memory.read_u8(0x02030328+0x10*l) ~= pc2 and l<15 do
        l=l+1
    end
    if l~=15 then
        pcntag2=(memory.read_u8(0x02030328+0x10*l+0x04)-memory.read_u8(0x02000BDC+0x14C*(pc2-5)))/memory.read_u8(0x02000BDC+0x14C*(pc2-5))*10000
        pcntag2= math.floor(pcntag2)/100
        gui.scaledtext(0,100,"PC" .. pc2 .. " Bonus: " .. pcntag2 .. "%")
    end

    local l=1
    while memory.read_u8(0x02030328+0x10*l) ~= pc3 and l<15 do
        l=l+1
    end
    if l~=15 then
        pcntag3=(memory.read_u8(0x02030328+0x10*l+0x04)-memory.read_u8(0x02000BDC+0x14C*(pc3-5)))/memory.read_u8(0x02000BDC+0x14C*(pc3-5))*10000
        pcntag3= math.floor(pcntag3)/100
        gui.scaledtext(0,110,"PC" .. pc3 .. " Bonus: " .. pcntag3 .. "%")
    end

    if memory.read_u8(0x0200045B)==0 and memory.read_u8(0x0200045C)==0 then
    else
        local l=1
        while memory.read_u8(0x02030328+0x10*l) ~= pc4 and l<15 do
            l=l+1
        end
        if l~=15 then
            pcntag4=(memory.read_u8(0x02030328+0x10*l+0x04)-memory.read_u8(0x02000BDC+0x14C*(pc4-5)))/memory.read_u8(0x02000BDC+0x14C*(pc4-5))*10000
            pcntag4= math.floor(pcntag4)/100
            gui.scaledtext(0,120,"PC" .. pc4 .. " Bonus: " .. pcntag4 .. "% Roll " .. memory.read_u8(0x02030328+0x10*l+0x04))
        end
    end

end



        -- HP/encounter display
    -- Colorrate stuff
    -- Encounter Rate Functions
    if CurrentRate ~= NormalisedRate(AD6) then
      if memory.read_u32_le(AD6) == 0 then
        CurrentRate = 0
      end
      if EncounterRate ~= memory.read_u32_le(0x02000478) and memory.read_u32_le(0x02000478) < 0x100000 then
        if store ~= memory.read_u32_le(AD5) then
          EncounterRate = memory.read_u32_le(0x02000478)+1
        end
        ColorRate1 = memory.read_u32_le(0x02000478)-EncounterRate
        ColorRateShade = 0
        ColorRate2 = 0xFFFFFFFF
        if ColorRate1 < 0 then
          EncounterRate = memory.read_u32_le(0x02000478)
          ColorRate2 = 0xFFFFFFFF
          CurrentRate = 0
        else
          if memory.read_u16_le(0x02000400) ~= 2 then -- world map?
            GoodRateThreshold2 = GoodRateThreshold*1.3
            if memory.read_u16_le(0x020301B4)==0xCC then -- Is Felix Walking?
              GoodRateThreshold2 = GoodRateThreshold2 / 2
            end
          else
            GoodRateThreshold2 = GoodRateThreshold
            if memory.read_u16_le(0x020301B4)==0x66 then -- Is Felix Walking?
              GoodRateThreshold2 = GoodRateThreshold2 / 2
            end
          end
          if ColorRate1 >= GoodRateThreshold2 then
            ColorRate2= 0xFFFF0000
            EncounterRate = memory.read_u32_le(0x02000478)
            CurrentRate = NormalisedRate(AD6)
            if NormalisedRate(AD6) == "" then
              ColorRate2= 0xFFFFFFFF
            end
          else
            ColorRateShade = math.floor((GoodRateThreshold2-ColorRate1)/GoodRateThreshold2*255)
            if ColorRateShade <= 63 then
              ColorRate2 = 0xFFFF0000 + 1024*ColorRateShade
            elseif ColorRateShade <=191 then
              ColorRate2 = 0xFF00FF00 + 256*256*(255-255*(ColorRateShade-63)/128-1)
            else
              ColorRate2 = 0xFF00FF00
            end
            EncounterRate = memory.read_u32_le(0x02000478)
            CurrentRate = NormalisedRate(AD6)
          end
        end
      end
    end

 if memory.read_u8(0x020309a0) >= 1 then
--
 else
 gui.scaledtext(0,20,"Encounter: ".. (memory.read_u16_le(AD3)))
 gui.scaledtext(0,30,"Isaac PP: ".. (memory.read_u8(0x0200053A)))
 gui.scaledtext(180,20,"Rate: ".. NormalisedRate(AD6), ColorRate2)
 gui.scaledtext(0,40,"PP Regen: ".. (math.floor((memory.read_u8(0x020301B5))/0xF)))
 
    if memory.read_u16_le(0x02000486) > 0 then
    gui.scaledtext(0,50,"Avoid Counter: " .. (memory.read_u16_le(0x02000486)))
    end
 end

-- Encounter Value Increasing if loop
encounterValue = memory.read_u32_le(0x02000478)
if encounterValue == 0 and encounterPreviousvalue ~= 0 then
  encounterPreviousvalue = 0
  encounterColor = 0xFFFFFFFF
elseif encounterValue ~= encounterPreviousvalue then
  encounterColor = 0xFF00FF00
  encounterPreviousvalue = memory.read_u32_le(0x02000478)
else
  encounterColor = 0xFFFFFFFF
  encounterPreviousvalue = memory.read_u32_le(0x02000478)
end

        -- begin RNG counters
GRN = memory.read_u32_le(AD5)
BRN = memory.read_u32_le(AD4)

if GRN == 1710661176 then
store = 1710661176
gcount=0
end
gcountbase = 0
while store ~= GRN and gcountbase <= 10000 do
--print(store)
store = RNA(store)
if store <= 0 then
store = 0xFFFFFFFF+store+1
gcount = gcount +1
gcountbase = gcountbase +1
else
gcount = gcount +1
gcountbase = gcountbase +1
end
end

if store == GRN then
gcountbase = 0
else
store = GRN
gcountbase = 0
gcount = 0
end

bcountbase = 0

while bstore ~= BRN and bcountbase <= 1000 do
    bstore = RNA(bstore)
    if bstore <= 0 then
        bstore = 0xFFFFFFFF+bstore+1
        brncount = brncount+1
        bcountbase = bcountbase+1
    else
        brncount = brncount+1
        bcountbase = bcountbase+1
    end
end

if bstore == BRN then
    bcountbase = 0
else
    bstore = BRN
    bcountbase = 0
    brncount = 0
end


if BRN == 0 then    -- reset BRN counter on loadstate
    
bstore = BRN
bcount = 0
end

        -- Gui display
gui.scaledtext(0,10,"GRN count: " .. gcount)
gui.scaledtext(0,0,"BRN count: " .. brncount)

        -- AF/CBS scripts
        if minorhudlock == false then
afb=00
cbsb=00

if afbrn ~= BRN then
    afb = BRN
    afb = RNA(afb)
    afc1 = 0
    while AF(afb) ~= 1 do
        afb = RNA(afb)
        afc1 = afc1 + 1
    end
    afc2 = afc1+1
    afb = RNA(afb)
    while AF(afb) ~=1 do
        afb = RNA(afb)
        afc2 = afc2 + 1
    end
    afc3 = afc2+1
    afb = RNA(afb)
    while AF(afb) ~= 1 do
        afb = RNA(afb)
        afc3 = afc3 + 1
    end
    afbrn=BRN
end

if cbsbrn ~= BRN then
    cbsb = BRN
    cbsb = RNA(cbsb)
    cbsc1 = 0
    while AF(cbsb) ~= 2 do
        cbsb = RNA(cbsb)
        cbsc1 = cbsc1 + 1
        if cbsc1 == 100 then break end
    end
    cbsc2 = cbsc1+1
    cbsb = RNA(cbsb)
    while AF(cbsb) ~= 2 do
        cbsb = RNA(cbsb)
        cbsc2 = cbsc2 + 1
        if cbsc2 == 102 then break end
    end
    cbsc3 = cbsc2+1
    cbsb = RNA(cbsb)
    while AF(cbsb) ~= 2 do
        cbsb = RNA(cbsb)
        cbsc3 = cbsc3 + 1
        if cbsc3 == 104 then break end
    end
    cbsbrn = BRN
end

    gui.scaledtext(70,0,"AF  " .. afc1 .. " " .. afc2 .. " " .. afc3)
    gui.scaledtext(70,10,"CBS " .. cbsc1 .. " " .. cbsc2 .. " " .. cbsc3)
end

        --necessary information for the following scripts
    --eel = memory.read_u8(0x0203089E)  venus resistance
    --eme = memory.read_u8(0x020308A2)  merc  res
    --ema = memory.read_u8(0x020308A6)  mars  res
    --eju = memory.read_u8(0x020308A8)  jup   res

    -- Vulnerability Key
--12 = Drop Def 25%
--13 = Drop def 12%
--16 = res drop 40
--17 = res drop 20
--20 = delusion
--23 = stun
--24 = sleep
--27 = death
--31 = HP steal
--32 = PP steal
--60 = 50% dmg to health
--69 = 10% dmg to PP

        -- Begin Flee/Assassinate Scripts
local    el1 = memory.read_u8(0x02030887)     -- Enemy 1 Level
local    el2 = memory.read_u8(0x020309D3)     -- etc
local    el3 = memory.read_u8(0x02030B1F)
local    el4 = memory.read_u8(0x02030C6B)
local    Party = memory.read_u8(0x02000040)    -- Party member number
local    isl= memory.read_u8(0x0200050F)     -- Isaac level
local    gal= memory.read_u8(0x0200065B)     -- etc
local    ivl= memory.read_u8(0x020007A7)
local    mil= memory.read_u8(0x020008F3)


if (memory.read_u8(0x020309a0)) >= 1 then

    function is_alive(F)
        return memory.read_u16_le(0x02000538 + 0x14C * F) > 0
    end
    
    function get_level(F)
        return memory.read_u8(0x0200050F + 0x14C * F)
    end

    function is_member(F)
        local party_flags = memory.read_u8(0x02000040)
        return (party_flags & 2^F) > 0
    end

    function filter(array, callback)
        local out = {}
        for k,v in pairs(array) do
            if callback(v) then table.insert(out, v) end
        end
        return out
    end

    function map(array, callback)
        local out = {}
        for k,v in pairs(array) do
            out[k] = callback(v)
        end
        return out
    end
    
    function sum(array)
        local out = 0
        for i,v in ipairs(array) do
            out = out + v
        end
        return out
    end

    party = filter({0, 1, 2, 3, 4, 5, 6, 7}, is_member) -- what is our current party
    live_party = filter(party, is_alive)    -- check living members
    levels = map(live_party, get_level)     -- check living member levels

    if el4 ~= 0 then -- enemy level averages
        ela = (el1+el2+el3+el4)/4
    elseif el3 ~=0 then
        ela = (el1+el2+el3)/3
    elseif el2 ~=0 then
        ela = (el1+el2)/2
    else
        ela = el1
    end

    LevelAve = sum(levels)/#levels - ela

    fleeFail = memory.read_u8(0x02030092)

    function flee(S) -- Flee Success Calculation
        g = S
        g = RNB(g)*10000
        fl = 5000 + (2000*fleeFail) + (LevelAve * 500)
        g = (g >> 16)
        if fl > g then
            return true
        else
            return false
        end
    end

    RN= memory.read_u32_le(0x03001CB4)
    count = 0

    while flee(RN) == false do -- Attack Cancel to Flee Calculation
    count = count + 1
    if count == 100 then break end
    RN= RNA(RN)
    end

    gui.scaledtext(170,30,"ACs to Run: " .. count)

        -- % Chance to Run
    if nosq == true then
        fleecount = 0
        if fleestore ~= memory.read_u32_le(AD5) then
            fleeRN = memory.read_u32_le(AD5)
            for i=1,1000 do
                if flee(fleeRN) == true then
                    fleecount= fleecount +1
                end
                fleeRN=RNA(fleeRN)
            end
            fleepercent = fleecount/10
            fleestore = memory.read_u32_le(AD5)
            fev = fleepercent/100
            EV = (fev*1+ math.floor(fev+.20,1)*(1-fev)*2+ math.floor(fev+.40,1)*(1-math.floor(fev+.20,1))*(1-fev)*3+ math.floor(fev+.60,1)*(1-math.floor(fev+.40,1))*(1-math.floor(fev+.20,1))*(1-fev)*4+ math.floor(fev+.80,1)*(1-math.floor(fev+.60,1))*(1-math.floor(fev+.40,1))*(1-math.floor(fev+.20,1))*(1-fev)*5+ (1-math.floor(fev+.80,1))*(1-math.floor(fev+.60,1))*(1-math.floor(fev+.40,1))*(1-math.floor(fev+.20,1))*(1-fev)*6)
            gui.scaledtext(100,30,"Run EV: ".. EV)
            gui.scaledtext(160,30,"Run%: " .. fleepercent)
            else
            gui.scaledtext(100,30,"Run EV: ".. EV )
            gui.scaledtext(160,30,"Run%: " .. fleepercent)
        end
    end

    function vuln (S)
        e1Ind = S
        vuln1 = memory.read_u8((0x08080EC8 - 0xA000*JPN) + ((e1Ind - 8) * 0x54) + 0x48) -- 0x08080EC8 = U ; 0x08076EC8 = J
        vuln2 = memory.read_u8((0x08080EC8 - 0xA000*JPN) + ((e1Ind - 8) * 0x54) + 0x49)
        vuln3 = memory.read_u8((0x08080EC8 - 0xA000*JPN) + ((e1Ind - 8) * 0x54) + 0x4A)
        return vuln1, vuln2, vuln3
    end

    function enemy (S,Elm) -- Enemy Elemental Data Table
            elemInd = memory.read_u8((0x08080EC8 - 0xA000*JPN) + ((S - 8) * 0x54) + 0x34)
            enemyelmlevel = memory.read_u8((0x08088E38 - 0xA000*JPN) + (elemInd * 0x18) + 4+Elm)
            return enemyelmlevel
    end

    function bchance (E) -- base chance for status
        if E == 16 or E == 17 then
            c = 75
        elseif E == 23 then
        c = 40
        elseif E == 24 then
        c = 45
        elseif E == 27 then
        c = 20
        end
        return c
    end

    function get_edata(enemyslot) -- Find enemy elemental stats
        local addr = 0x02030878 + 0x14C*enemyslot + 0x48
        local epow, eres = {}, {}
        for i=0,3 do
            epow[i] = memory.read_u16_le(addr+4*i)
            eres[i] = memory.read_u16_le(addr+4*i+2)
        end
        return epow, eres
    end

    function effectproc (S,E,Elm,U) -- Random number, What effect is this, Elemental Affinity 0 = Venus, 1 = Mercury, 2= Mars, 3 = Jupiter, 
                                    -- Who is using this 0 = Isaac, 1 = Garet, 2 = Ivan, 3 = Mia
        uelm = memory.read_u8(0x0200061C+U*0x14C+Elm)     -- Elemental Power of User
        eluc = memory.read_u8(0x020308BA)                 -- Enemy Luck
        eind = memory.read_u8(0x020309a0)                -- Enemy Index
        eelm = enemy(eind,Elm)                             -- Enemy Elemental Levels
        vul1, vul2, vul3 = vuln(eind)                     -- Enemy Vulnerability
        if vul1 == E or vul2 == E or vul3 == E then     -- Vulnerability key at top
            v=25
            else
            v=00
        end
        if memory.read_u8((0x080844EC - 0xA000*JPN) + (U * 0xB4) + 0x92 + Elm) == 54 then
            elmaff = 5
            else
            elmaff = 0
        end
        proc = (((uelm + elmaff - eelm)-(math.floor(eluc/2)))*3+bchance(E)+v)
        g = RNB(S)*100
        g = (g >> 16)
        if proc >= g then
            return true
            else
            return false
        end
    end

    function unleash (S)
        g = S
        g = RNB(g)*100
        g = (g >> 16)
        if 35 >= g then
            return true
        else
            return false
        end
    end
    
    if BattleState ~= memory.read_u8(0x020309a0) then -- When entering combat, determine
        BladeUser = FindItemHolder(0x17)    -- Who has [item/djinni]
        WitchUser = FindItemHolder(0x39)
        ScorchUser = FindDjinniHolder("Scorch")
        MistUser = FindDjinniHolder("Mist")
        
        epow, eres = get_edata(0)
        battle_display = {}
        previous_brn = nil
        BattleState = memory.read_u8(0x020309a0)
    end

    if previous_brn ~= memory.read_u32_le(0x020023A8) then
        previous_brn = memory.read_u32_le(0x020023A8)
        for i=1,#battle_display do battle_display[i] = nil end
        
            -- begin BRN calculations for procs
        if nosq == false then    -- normal any% probabilities follow from here

            if BladeUser ~= nil then    -- if someone has ABlade
                BRN = memory.read_u32_le(0x020023A8)
                bcount=0
                
                while effectproc(RNA(BRN),27,0,BladeUser) == false or unleash(BRN) == false do  
                    bcount = bcount+1
                    if bcount == 100 then break end
                    BRN=RNA(BRN)
                end
                table.insert(battle_display, {160,50,"ABlade Kill: " .. bcount})
            end

            if Party == 15 and WitchUser ~= nil and memory.read_u8(0x02000155) < 0x14 then    -- someone has WWand and before getting off boat
                BRN = memory.read_u32_le(0x020023A8)
                bcount=0
                
                while effectproc(RNA(BRN),23,3,WitchUser) == false or unleash(BRN) == false do
                    bcount = bcount+1
                    if bcount == 50 then break end
                    BRN=RNA(BRN)
                end
                table.insert(battle_display, {160,60,"WWand Stun: " .. bcount})
            end

            if memory.read_u8(0x0200050F) >= 9 and memory.read_u8(0x02000155) < 0x14 then    -- Isaac level >= 9 and before getting off boat
                BRN = memory.read_u32_le(0x020023A8)
                bcount=0

                while effectproc(BRN,16,3,0) == false do
                    bcount = bcount+1
                    if bcount == 50 then break end
                    BRN=RNA(BRN)
                end
                table.insert(battle_display, {160,90,"IWeaken: " .. bcount})
            end

            if memory.read_u8(0x0200065B) >= 9 and memory.read_u8(0x02000155) < 0x14 then    -- Garet level >= 9 and before getting off boat
                BRN = memory.read_u32_le(0x020023A8)
                bcount=0

                while effectproc(BRN,16,3,1) == false do
                    bcount = bcount+1
                    if bcount == 50 then break end
                    BRN=RNA(BRN)
                end
                table.insert(battle_display, {160,100,"GWeaken: " .. bcount})
            end

            if MistUser ~= nil and memory.read_u8(0x0200016C)~=0x80 then        -- Navampa Win/Lose is stored at 0200016A
                BRN = memory.read_u32_le(0x020023A8)                            -- have Mist and before Colloso ends
                bcount=0
                
                if eres[1] == math.min(table.unpack(eres)) then BRN = RNA(BRN) end

                    while effectproc(BRN,24,1,MistUser) == false do
                        bcount = bcount+1
                        if bcount == 50 then break end
                        BRN=RNA(BRN)
                    end
                table.insert(battle_display, {160,70,"Mist: " .. bcount})
            end
                                                                            
            if ScorchUser ~= nil then    
                BRN = memory.read_u32_le(0x020023A8)
                bcount=0
                
                if eres[2] == math.min(table.unpack(eres)) then BRN = RNA(BRN) end

                    while effectproc(BRN,23,2,ScorchUser) == false do
                        bcount = bcount+1
                        if bcount == 50 then break end
                        BRN=RNA(BRN)
                    end
                table.insert(battle_display, {160,80,"Scorch: " .. bcount})
            end
        end

        if nosq == true then
            if memory.read_u8(0x020309A0)==0x79 then -- If in Kraken fight, return Vulcan Axe stun chances
                BRN = memory.read_u32_le(0x020023A8)
                success = 0
                if BRN_tempssss ~= BRN then
                    for i=1,1000 do -- mist calculation
                        if unleash(BRN_tempssss) == true then
                            if effectproc(RNA(BRN_tempssss),24,2,1) == true then
                                success = success + 1
                            end
                        end
                        BRN_tempssss=RNA(BRN_tempssss)
                        vulcan_success = success/10
                    end
                end
                table.insert(battle_display, {160,150,"Vulcan: " .. vulcan_success .. "%"})
                BRN_tempssss = BRN
            end
            if memory.read_u8(0x02000048)>=0x70 and memory.read_u8(0x02000155) < 0x14 then -- If you have mist, return mist information
                BRN = memory.read_u32_le(0x020023A8)
                success = 0
                if BRN_temp ~= BRN then
                    for i=1,1000 do -- mist calculation
                        if effectproc(RNA(BRN_temp),24,1,0) == true then
                            success = success + 1
                        end
                        BRN_temp=RNA(BRN_temp)
                        mist_success = success/10
                    end
                end
                table.insert(battle_display, {160,75,"Mist: " .. mist_success .. "%"})
                BRN_temp = BRN
            end

            if memory.read_u8(0x020309A0)==0x79 then -- If in the Kraken fight, do the scorch calc
                BRN = memory.read_u32_le(0x020023A8)
                success = 0
                if BRN_temps ~= BRN then
                    for i=1,1000 do -- mist calculation
                        if effectproc(RNA(BRN_temps),23,2,1) == true then
                            success = success + 1
                        end
                        BRN_temps=RNA(BRN_temps)
                        scorch_success = success/10
                    end
                end
                table.insert(battle_display, {160,90,"Scorch: " .. scorch_success .. "%"})
                BRN_temps = BRN
            end

            if memory.read_u16_le(0x020008BC) >= 2150 then -- If Ivan level 9, do the sleep calc
                BRN = memory.read_u32_le(0x020023A8)
                success = 0
                if BRN_tempss ~= BRN then
                    for i=1,1000 do -- mist calculation
                        if effectproc(RNA(BRN_tempss),24,3,2) == true then
                            success = success + 1
                        end
                        BRN_tempss=RNA(BRN_tempss)
                        sleep_success = success/10
                    end
                end
                table.insert(battle_display, {160,60,"Sleep: " .. sleep_success .. "%"})
                BRN_tempss = BRN
            end

            if memory.read_u8(0x020309A0)==0x79 then -- If in the Kraken fight, do the sleep bomb calc
                BRN = memory.read_u32_le(0x020023A8)
                success = 0
                if BRN_tempsss ~= BRN then
                    for i=1,1000 do -- mist calculation
                        if effectproc(RNA(BRN_tempsss),24,3,3) == true then
                            success = success + 1
                        end
                        BRN_tempsss=RNA(BRN_tempsss)
                        sleepb_success = success/10
                    end
                end
                table.insert(battle_display, {})
                --gui.scaledtext(160,90,"TotalB: " .. (100-math.abs(math.floor(1-(1-sleepb_success/100)*(1-sleep_success/100)*(1-mist_success/100)*(1-scorch_success/100)*10000))/100)  .. "%")
                --gui.scaledtext(160,70,"Total: " .. (100+math.floor(1-(1-sleep_success/100)*(1-mist_success/100)*(1-scorch_success/100)*10000)/100)  .. "%")
                BRN_tempsss = BRN
            end

            if memory.read_u16_le(0x02000400)==0x1FE and memory.read_u16_le(0x02000404)==0x88 then -- If you are in Colosso return the following calculation

                BRN = memory.read_u32_le(0x020023A8)
                bcount=0

                while effectproc(RNA(BRN),23,2,0) == false do --or unleash(BRN) == false do -- mist calculation
                    bcount = bcount+1
                    if bcount == 100 then break end
                    BRN=RNA(BRN)
                end
                table.insert(battle_display, {160,75,"Scorch: " .. bcount})
            end
        end
    end

    for i=1,#battle_display do
        gui.scaledtext(table.unpack(battle_display[i]))
    end


function itemdrop(S,C)
    g = S
    g = RNB(g)*100
    g = (g >> 16)
    if C >= g then
        return true
    else
        return false
    end
end
function droprate(ch) -- enemy index, chance of drop
    BRN = memory.read_u32_le(0x020023A8)
    bcount=0
    bcount2=0
    rate = (0x64 >> ch-1)
    rate2 = (0x64 >> ch-3)
        while itemdrop(BRN,rate) == false do
            bcount=bcount+1
                if itemdrop(BRN,rate2) == true then
                bcount2=bcount
                end
                if bcount == 100 then break end
            BRN=(RNA(BRN))
        end
    return bcount, bcount2
end
    if nosq == false and minorhudlock==false then -- drop chances only when nosq stats are off and minor hud is on
        if memory.read_u8(0x020309A0)>0 then
            eindex=memory.read_u16_le(0x020309A0)
            if eindex == 0x47 or eindex == 0x44 then -- Mole Enemy or Siren
                A,B= droprate(5)
            gui.scaledtext(180,120, "E1 Turns " .. A .. "|" .. B) -- A=turns without djinn, B=turns with djinn
            end
        end

        if memory.read_u8(0x020309A0+0x14C)>0 then
            eindex2=memory.read_u16_le(0x020309A0+0x14C)
            if eindex2 == 0x47 or eindex == 0x44 then  -- Mole Enemy or Siren
                A,B= droprate(5)
            gui.scaledtext(180,135, "E2 Turns " .. A .. "|" .. B) -- A=turns without djinn, B=turns with djinn
            end
        end

        if memory.read_u8(0x020308B0+0x14C*2)>0 then
            eindex3=memory.read_u16_le(0x020309A0+2*0x14C)
            if eindex3 == 0x47 or eindex == 0x44 then -- Mole Enemy or Siren
                A,B= droprate(5)
            gui.scaledtext(180,150, "E3 Turns " .. A .. "|" .. B) -- A=turns without djinn, B=turns with djinn
            end
        end

        if memory.read_u8(0x020308B0+0x14C*3)>0 then
            eindex4=memory.read_u16_le(0x020309A0+3*0x14C)
            if eindex4 == 0x47 or eindex == 0x44 then -- Mole Enemy or Siren
                A,B= droprate(5)
            gui.scaledtext(180,165, "E4 Turns " .. A .. "|" .. B) -- A=turns without djinn, B=turns with djinn
            end
        end
    end
end
-- This code is for BRN / GRN advance via keypresses (note AD4 = BRN and AD5 = GRN)
if state == true and keypress["G"] == nil and keypress["H"] == nil and keypress["B"] == nil and keypress["N"] == nil and keypress["plus"] == nil and keypress["minus"] == nil then
    state = false
end
if state == false and keypress["B"] == true and keypress["Shift"] == true then
    memory.write_u32_le(AD4,RNA(memory.read_u32_le(AD4)))
    brnadvancecounter = 30
    state = true
end
if state == false and keypress["N"] == true and keypress["Shift"] == true then
    memory.write_u32_le(AD4,RNA(memory.read_u32_le(AD4), -1))
    brnreducecounter = 30
    state = true
    bstore = memory.read_u32_le(AD4)
    brncount = brncount - 1
end
if state == false and keypress["G"] == true and keypress["Shift"] == true then
    memory.write_u32_le(AD5,RNA(memory.read_u32_le(AD5)))
    grnadvancecounter = 30
    state = true
end

    if state == false and keypress["H"] == true and keypress["Shift"] == true then
        memory.write_u32_le(AD5,RNA(memory.read_u32_le(AD5), -1))
        grnreducecounter = 30
        state = true
        store = memory.read_u32_le(AD5)
        gcount = gcount - 1
    end
if state == false and keypress["plus"] == true and keypress["Shift"] == true then
    --if memory.read_u32_le(AD5) == 0x80000000 then
    --    memory.write_u32_le(AD5,0)
    --end
    memory.write_u32_le(AD5,(memory.read_u32_le(AD5)+1)%0x80000000) -- increase GRN by one
    grnadvancecounter = 30
    state = true
end
if state == false and keypress["minus"] == true and keypress["Shift"] == true then
    --if memory.read_u32_le(AD4) == 0x80000000 then
    --    memory.write_u32_le(AD4,0)
    --end
    memory.write_u32_le(AD4,(memory.read_u32_le(AD4)+1)%0x80000000) -- increase BRN by one
    brnadvancecounter = 30
    state = true
end

if brnadvancecounter >= 1 then
    --gui.scaledtext(100,100, "BRN advanced by one","#00FF00")
    gui.scaledtext(225,00, "+1",0xFF00FF00)
    brnadvancecounter = brnadvancecounter-1
end
if brnreducecounter >= 1 then
    --gui.scaledtext(100,100, "BRN advanced by one","#00FF00")
    gui.scaledtext(225,00, "-1",0xFFFF0000)
    brnreducecounter = brnreducecounter-1
end
if grnadvancecounter >= 1 then
    --gui.scaledtext(100,100, "GRN advanced by one","#00FF00")
    gui.scaledtext(225,10, "+1",0xFF00FF00)
    grnadvancecounter = grnadvancecounter-1
end
if grnreducecounter >= 1 then
    --gui.scaledtext(100,100, "GRN advanced by one","#00FF00")
    gui.scaledtext(225,10, "-1",0xFFFF0000)
    grnreducecounter = grnreducecounter-1
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
    memory.write_u16_le(AD1,0x5)
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
    memory.write_u16_le(AD3,0x1)
    memory.write_u16_le(0x020301B5,0x1)
end
-- This code is for the map data overlay

if overlaystate == false and keypress["O"]==true and keypress["Shift"]==true and overlay == false then
    overlay = true
    overlaystate = true
    gui.clearGraphics()
    print("Overlay enabled")
end
if overlaystate == false and keypress["O"]==true and keypress["Shift"]==true and overlay == true then
    overlay = false
    overlaystate = true
    print("Overlay disabled")
    gui.clearGraphics()
end
if overlaystate == true and keypress["O"]==nil then
    overlaystate = false
    gui.clearGraphics()
end
if overlay == true and infight == false then

    local tile = memory.read_u32_le(0x020301B8)
    local tile_value = memory.read_u16_le(tile)

    function compress(S)
        R = (memory.read_u32_le(S) >> 16)
        R = (R & 0xFF)
        return R
        end

    function tile_height(X)
            X = (X >> 24)
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

    function extract_height(S)
            if (S & 0xF)==0 then
                height = ((S >> 8) & 0xFF)
                height = signed(height)
            elseif (S & 0xF)==1 or (S & 0xF)==2 or (S & 0xF)==3 or (S & 0xF)==4 or (S & 0xF)==8 or (S & 0xF)==9 then
                ha = ((S >> 8) & 0xFF)
                ha = signed(ha)
                hb = ((S >> 16) & 0xFF)
                hb = signed(hb)
                height = (ha+hb)/2
            else
                 height = ((S >> 8) & 0xFF)
                 height = signed(height)
          end

            return height
        end


    eventtable = memory.read_u32_le(0x2030010)
    function interesting_event()
            E = eventtable
            while memory.read_u32_le(E) ~= 0xFFFFFFFF do
                if memory.read_u8(E+0x4) > 0 then
                    if (memory.read_u32_le(E) & 0xF) == 1 then
                        table.insert(doorlist, memory.read_u8(E+0x4))
                    elseif (memory.read_u32_le(E) & 0xF) == 3 then
                        table.insert(objectlist, memory.read_u8(E+0x4))
                    else
                        table.insert(eventlist, memory.read_u8(E+0x4))
                    end
                end
                E = E+0xC
            end
    end
    
    if area ~= memory.read_u16_le(0x2000408) and eventtable > 0 and memory.read_u32_le(0x020301B8) > 0x02000000 and memory.read_u16_le(0x2000400)~=0 then
        eventlist = {}
        objectlist = {}
        doorlist = {}
        interesting_event()
        area = memory.read_u16_le(0x2000408)
    end

    function eventcheck(element,tablu)
      for _, value in pairs(tablu) do
        if value == element then
          return true
        end
      end
      return false
    end

    function color(S)
            T = tile_height(memory.read_u32_le(memory.read_u32_le(0x020301B8)))
            U = tile_height(memory.read_u32_le(S))
            if extract_height(T) == extract_height(U) then
                C = "white"
            elseif extract_height(T) < extract_height(U) then
                shade = math.min((extract_height(U) - extract_height(T))/4*255,255)
                C = 0xFFFF00FF + 256*(255-shade)
                -- C = { 255, 255-shade, 255-shade}
            elseif extract_height(T) > extract_height(U) then
                shade = math.min((extract_height(T) - extract_height(U))/4*255,255)
                -- C = { 255-shade, 255, 255}
                C = 0xFF00FFFF + 256*256*(255-shade)
            end
            return C
            end
--      if memory.read_u16_le(0x02000400) == 2 then    --- This code doesn't work because for some reason the world map is storing tile info differently to dungeons
--          WorldMapFactor = 1/4
--        else
--          WorldMapFactor = 1
--        end
    if tile ~= 0 then
    gui.drawLine(108, 98, 123, 98)
    gui.drawLine(123, 98, 123, 108)
    gui.drawLine(123, 108, 108, 108)
    gui.drawLine(108, 108, 108, 98)
    for i=-4,4 do
      for j=-4,4 do
        cur_tile = tile+0x200*i+0x4*j
        gui.scaledtext(110+j*15,100+i*15, compress(cur_tile), color(cur_tile))
            if eventcheck(compress(cur_tile),objectlist) == true then
                gui.drawLine(108+j*15, 98+i*15, 123+j*15, 98+i*15, 0xFFFFFF00)
                gui.drawLine(123+j*15, 98+i*15, 123+j*15, 108+i*15, 0xFFFFFF00)
                gui.drawLine(123+j*15, 108+i*15, 108+j*15, 108+i*15, 0xFFFFFF00)
                gui.drawLine(108+j*15, 108+i*15, 108+j*15, 98+i*15, 0xFFFFFF00)
            elseif eventcheck(compress(cur_tile),doorlist) == true then
                gui.drawLine(108+j*15, 98+i*15, 123+j*15, 98+i*15, 0xFF00FF00)
                gui.drawLine(123+j*15, 98+i*15, 123+j*15, 108+i*15, 0xFF00FF00)
                gui.drawLine(123+j*15, 108+i*15, 108+j*15, 108+i*15, 0xFF00FF00)
                gui.drawLine(108+j*15, 108+i*15, 108+j*15, 98+i*15, 0xFF00FF00)
            elseif eventcheck(compress(cur_tile),eventlist) == true then
                gui.drawLine(108+j*15, 98+i*15, 123+j*15, 98+i*15, 0xFFFF00FF)
                gui.drawLine(123+j*15, 98+i*15, 123+j*15, 108+i*15, 0xFFFF00FF)
                gui.drawLine(123+j*15, 108+i*15, 108+j*15, 108+i*15, 0xFFFF00FF)
                gui.drawLine(108+j*15, 108+i*15, 108+j*15, 98+i*15, 0xFFFF00FF)
        end
      end
    end
    end
end

--This code is for randomising the GRN/BRN by advancing the GRN/BRN a random number of times
if randomiserstate == true and keypress["R"] == nil then
    randomiserstate = false
end
if randomiserstate == false and keypress["R"] == true and keypress["Shift"] == true then
    randomisercounter = 50
    randomiserstate = true
end
if randomisercounter == 50 then
    grnrandomadvance = math.random(1,100)
    brnrandomadvance = math.random(1,100)
    for i=1,grnrandomadvance do
        memory.write_u32_le(AD5,RNA(memory.read_u32_le(AD5)))
    end
    for i=1,brnrandomadvance do
        memory.write_u32_le(AD4,RNA(memory.read_u32_le(AD4)))
    end
end
if randomisercounter >= 1 then
    --gui.scaledtext(100,100, "BRN advanced by one","#00FF00")
    gui.scaledtext(225,00, "+" .. brnrandomadvance,0xFF00FF00)
    gui.scaledtext(225,10, "+" .. grnrandomadvance,0xFF00FF00)
    randomisercounter = randomisercounter-1
end

--And because I need GRN randomiser for FD this code exists!
if grnrandomiserstate == true and keypress["Y"] == nil then
  grnrandomiserstate = false
end
if grnrandomiserstate == false and keypress["Y"] == true and keypress["Shift"] == true then
  grnrandomisercounter = 50
  grnrandomiserstate = true
end
if grnrandomisercounter == 50 then
  grnrandomadvance = math.random(1,100)
  for i=1,grnrandomadvance do
    memory.write_u32_le(AD5,RNA(memory.read_u32_le(AD5)))
  end
end
if grnrandomisercounter >= 1 then
  gui.scaledtext(225,10, "+" .. grnrandomadvance, 0xFF00FF00)
  grnrandomisercounter = grnrandomisercounter-1
end
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
  memory.write_u8(0x03001F54,1) 
  memory.write_u8(0x03001F64,1)
else
  memory.write_u8(0x03001F54,0)
  memory.write_u8(0x03001F64,0)
end

--- no s&q probabilities
if nosqstate == false and keypress["K"]==true and keypress["Shift"]==true and nosq == false then
    nosq = true
    nosqstate = true
    print("No S&Q probabilities enabled")
end
if nosqstate == false and keypress["K"]==true and keypress["Shift"]==true and nosq == true then
    nosq = false
    nosqstate = true
    print("No S&Q probabilities disabled")
end
if nosqstate == true and keypress["K"]==nil then
    nosqstate = false
end
-- This code is for a global timer, toggled by shift+Q
-- This block is for toggling the timer on and off and pausing the timer
if globaltimerstate == false and globaltimeron == false and keypress["Q"] == true and keypress["Shift"] == true then
    globaltimerstate = true
    globaltimeron = true
    print("Global timer enabled.")
    print("Press q to reset the timer at any point.")
    print("Press w to pause or unpause the timer.")
    print("Press tab to record a time.")
    print("Press shift+w to display last three recorded times.")
end
if globaltimerstate == false and globaltimeron == true and keypress["Q"] == true and keypress["Shift"] == true then
    globaltimerstate = true
    globaltimeron = false
    globaltimer = 0
    print("Global timer disabled.")
end
if globaltimerstate == false and globaltimeron == true and keypress["Q"] == true and keypress["Shift"] == nil then
    globaltimer = 0
    globaltimerstate = true
    print("Global timer reset")
end
if globaltimerstate == false and globaltimeron == true and globaltimerpause == false and keypress["W"] == true and keypress["Shift"] == nil then
    globaltimerpause = true
    globaltimerstate = true
end
if globaltimerstate == false and globaltimeron == true and globaltimerpause == true and keypress["W"] == true and keypress["Shift"] == nil then
    globaltimerpause = false
    globaltimerstate = true
end
if globaltimerstate == true and keypress["W"] == nil and keypress["Q"] == nil and keypress["tab"] == nil then
    globaltimerstate = false
end
-- This code is the global timer
if globaltimeron == true then
    if globaltimerpause == false then
        gui.scaledtext(0,120, "Timer " .. math.floor(globaltimer/60) .. "s")
        globaltimer = globaltimer+1
    end
    if globaltimerpause == true then
        gui.scaledtext(0,120, "Timer " .. math.floor(globaltimer/6)/10 .. "s " .. globaltimer .. " frames","#FFFF00")
    end
    if keypress["tab"] == true and globaltimerstate == false then
        globaltimerstore[3] = globaltimerstore[2]
        globaltimerstore[2] = globaltimerstore[1]
        globaltimerstore[1] = globaltimer
        globaltimer = 0
        globaltimerstate = true
        print("Time recorded")
    end
    if keypress["W"] == true and keypress["Shift"] == true and globaltimerstate == false then
        globaltimerstoretimer = 360
        globaltimerstate = true
    end
    if globaltimerstoretimer >= 1 then
        if globaltimerstore[1] >= 1 then
            gui.scaledtext(0,90, "Time #1 " .. math.floor(globaltimerstore[1]/6)/10 .. "s " .. globaltimerstore[1] .. " frames","#00FF00")
        end
        if globaltimerstore[2] >= 1 then
            gui.scaledtext(0,100, "Time #2 " .. math.floor(globaltimerstore[2]/6)/10 .. "s " .. globaltimerstore[2] .. " frames","#00FF00")
        end
        if globaltimerstore[3] >= 1 then
            gui.scaledtext(0,110, "Time #3 " .. math.floor(globaltimerstore[3]/6)/10 .. "s " .. globaltimerstore[3] .. " frames","#00FF00")
        end
        globaltimerstoretimer = globaltimerstoretimer - 1
    end
end
if memory.read_u8(0x030009A4) == 0x9C and memory.read_u8(0x0200006A) == 0x4 and memory.read_u8(0x02030468) ~= 0xFF then -- memory.read_u8(0x02032C5E) == 0x31 then --memory.read_u8(0x06012593) == 0xB0 then -- status menu open check
  -- this block works out what character the cursor is on
  StatusMenuOpen = true
  if memory.read_u16_le(Cursor) == 0x12F then
    CurrentChar = 0
    CurrentName = " Isaac"
    CurrentGoals = IsaacGoals
  elseif memory.read_u16_le(Cursor) == 0x6B then
    CurrentChar = 1
    CurrentName = " Garet"
    CurrentGoals = GaretGoals
  elseif memory.read_u16_le(Cursor) == 0xED then
    CurrentChar = 2
    CurrentName = " Ivan"
    CurrentGoals = IvanGoals
  elseif memory.read_u16_le(Cursor) == 0x1903 then
    CurrentChar = 3
    CurrentName = " Mia"
    CurrentGoals = MiaGoals
  end
  -- displays characters base stat value i.e. without class or equipment modifiers
  gui.scaledtext(0,100,CurrentName .. " Level " .. LevelCalculator(CurrentChar))
  gui.scaledtext(0,110, " HP: " .. memory.read_u16_le(BaseHP+CharMemDiff*CurrentChar), StatColor[1])
  gui.scaledtext(0,120, " PP: " .. memory.read_u16_le(BasePP+CharMemDiff*CurrentChar), StatColor[2])
  gui.scaledtext(0,130, " Atk: " .. memory.read_u16_le(BaseAtk+CharMemDiff*CurrentChar), StatColor[3])
  gui.scaledtext(0,140, " Def: " .. memory.read_u16_le(BaseDef+CharMemDiff*CurrentChar), StatColor[4])
  gui.scaledtext(0,150, " Agi: " .. memory.read_u16_le(BaseAgi+CharMemDiff*CurrentChar), StatColor[5])
  --gui.scaledtext(0,160, " Luc: " .. memory.read_u8(BaseLuc+CharMemDiff*CurrentChar), StatColor[6])

  -- This code is for stat selection
  if keypress["I"]==true and keypress["K"]==nil and statstate == false then -- moves the highlghted stat up
      statstate = true
    StatColor[6]=StatColor[1]
    for i=1,5 do
      StatColor[i] = StatColor[i+1] -- 1<-2,2<-3...6<-1 -- 7
    end
    SelectedStat = SelectedStat-1 - math.floor((SelectedStat-1)/5)*5
  end
  if keypress["K"]==true and keypress["I"]==nil and statstate == false then -- moves the highlighted stat down
      statstate = true
    for i=1,5 do
      StatColor[7-i] = StatColor[6-i] -- 6=5, 5=4,... 2=1, then 1=6
    end
    StatColor[1]=StatColor[6]
    SelectedStat = SelectedStat+1 - math.floor((SelectedStat+1)/5)*5
  end

  -- This code is for stat manipulation
  if keypress["L"]==true and statstate == false then
    statstate = true
    memory.write_u16_le(WhichStat(SelectedStat,CurrentChar),memory.read_u16_le(WhichStat(SelectedStat,CurrentChar))+1)
  end
  if keypress["J"]==true and statstate == false then
    statstate = true
    memory.write_u16_le(WhichStat(SelectedStat,CurrentChar),memory.read_u16_le(WhichStat(SelectedStat,CurrentChar))-1)
  end

  -- Reset statstate
  if keypress["I"]==nil and keypress["K"]==nil and  keypress["J"]==nil and  keypress["L"]==nil and statstate == true then
    statstate = false
  end


  -- displays characters base stat value i.e. without class or equipment modifiers
  gui.scaledtext(40,110, " [" .. math.floor((CurrentGoals[1][2]-CurrentGoals[1][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[1][1] .. "-" .. math.floor((CurrentGoals[1][2]-CurrentGoals[1][1]+19)/20)*LevelCalculator(CurrentChar)+CurrentGoals[1][1] .. "]", StatColor[1])
  gui.scaledtext(40,120, " [" .. math.floor((CurrentGoals[2][2]-CurrentGoals[2][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[2][1] .. "-" .. math.floor((CurrentGoals[2][2]-CurrentGoals[2][1]+19)/20)*LevelCalculator(CurrentChar)+CurrentGoals[2][1] .. "]", StatColor[2])
  gui.scaledtext(40,130, " [" .. math.floor((CurrentGoals[3][2]-CurrentGoals[3][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[3][1] .. "-" .. math.floor((CurrentGoals[3][2]-CurrentGoals[3][1]+19)/20)*LevelCalculator(CurrentChar)+CurrentGoals[3][1] .. "]", StatColor[3])
  gui.scaledtext(40,140, " [" .. math.floor((CurrentGoals[4][2]-CurrentGoals[4][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[4][1] .. "-" .. math.floor((CurrentGoals[4][2]-CurrentGoals[4][1]+19)/20)*LevelCalculator(CurrentChar)+CurrentGoals[4][1] .. "]", StatColor[4])
  gui.scaledtext(40,150, " [" .. math.floor((CurrentGoals[5][2]-CurrentGoals[5][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[5][1] .. "-" .. math.floor((CurrentGoals[5][2]-CurrentGoals[5][1]+19)/20)*LevelCalculator(CurrentChar)+CurrentGoals[5][1] .. "]", StatColor[5])
  gui.scaledtext(90,110, "E:" .. math.floor((((CurrentGoals[1][2]-CurrentGoals[1][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[1][1])*10)/10, StatColor[1])
  gui.scaledtext(90,120, "E:" .. math.floor((((CurrentGoals[2][2]-CurrentGoals[2][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[2][1])*10)/10, StatColor[2])
  gui.scaledtext(90,130, "E:" .. math.floor((((CurrentGoals[3][2]-CurrentGoals[3][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[3][1])*10)/10, StatColor[3])
  gui.scaledtext(90,140, "E:" .. math.floor((((CurrentGoals[4][2]-CurrentGoals[4][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[4][1])*10)/10, StatColor[4])
  gui.scaledtext(90,150, "E:" .. math.floor((((CurrentGoals[5][2]-CurrentGoals[5][1])/20)*LevelCalculator(CurrentChar)+CurrentGoals[5][1])*10)/10, StatColor[5])
else
  StatusMenuOpen = false
end

-- This code is for toggling af / cbs / missing agility display
if minorhudstate == false and keypress["A"]==true and keypress["Shift"]==true and minorhudlock == false then
    minorhudlock = true
    minorhudstate = true
    print("Minor hud disabled")
end
if minorhudstate == false and keypress["A"]==true and keypress["Shift"]==true and minorhudlock == true then
    minorhudlock = false
    minorhudstate = true
    print("Minor hud enabled")
end
if minorhudstate == true and keypress["A"]==nil then
    minorhudstate = false
end

-- This code toggle encounter analysis information
if encounteranalysisstate == false and keypress["M"]==true and keypress["Shift"]==true and encounteranalysis == false then
    encounteranalysis = true
    encounteranalysisstate = true
    print("Encounter analysis enabled")
end
if encounteranalysisstate == false and keypress["M"]==true and keypress["Shift"]==true and encounteranalysis == true then
    encounteranalysis = false
    encounteranalysisstate = true
    print("Encounter analysis disabled")
end
if encounteranalysisstate == true and keypress["M"]==nil then
    encounteranalysisstate = false
end

if encounteranalysis == true then

    -- Encounter Rate Functions
      RateRate = RatePrediction(memory.read_u32_le(AD5))
      if NewRate ~= RateRate then
        OldRate = NewRate
        NewRate = RateRate
      end
        RateCalcBase = memory.read_u32_le(AD5)
      -- TABLE VARIABLE CONTROLLER
      if keypress["L"]==true and keypress["J"]==nil and tableState == false then
        tableState = true
        tableVariable = (tableVariable - math.floor(tableVariable/7) * 7) + 1
      end
      if keypress["J"]==true and keypress["L"]==nil and tableState == false then
        tableState = true
        tableVariable = (tableVariable+5 - math.floor((tableVariable+5)/7) * 7)
        tableVariable = tableVariable + 1
      end
      if keypress["J"]==nil and keypress["L"]==nil and tableState == true then
        tableState = false
      end
      if keypress["J"]==true and keypress["L"]==true and tableState == false then
        tableState = true
        tableVariable = 1
        print("Psynergy Selector Reset")
      end

         -- Display --

         -- GUI DISPLAY FOR GRN THINGY
    if RatePredictionRNGStore ~= memory.read_u32_le(AD5) or tableVariableStore ~= tableVariable then
      tableVariableStore = tableVariable
      RatePredictionRNGStore = memory.read_u32_le(AD5)
      WorldMapGRN = 47 - (memory.read_u16_le(0x0200004A) & 0x400)/0x400 - (memory.read_u16_le(0x02000114) & 0x8)/0x8 - (memory.read_u16_le(0x02000112) & 0x8000)/0x8000
      if memory.read_u16_le(0x02000400) == 0x2 then
        WorldMapOffset=1
      else
        WorldMapOffset=0
      end
      if memory.read_u32_le(0x020301A8) == 0 then
        StepGRNOffset = 0
      else
        StepGRNOffset = 1
      end
      if tableVariable == 1 then
        BaseOffset = 0
      else
        BaseOffset = 1
      end
      for i=1,10,1 do
        RatePredictionVectorStore[i][1] = RatePsyCalc(memory.read_u32_le(AD5),grnAdvanceList[tableVariable]+i+WorldMapGRN*WorldMapOffset*BaseOffset-4*StepGRNOffset-1)
        RatePredictionVectorStore[i][2] = ColorRate(RatePredictionVectorStore[i][1])
      end
    end
    if memory.read_u16_le(0x02000400)~=0x1FE then
      gui.scaledtext(180,30,moveList[tableVariable])
      for i=0,9,1 do
        gui.scaledtext(180,40+10*i,"+".. i .. " Rate " .. RatePredictionVectorStore[i+1][1], RatePredictionVectorStore[i+1][2])
      end
    end
end

if MapDataCheck == true and ((memory.readbyte(0x02000060) >> 3) & 1) ~= 1 then -- if MapData plugin is installed then
    if keypress["Shift"] == true and keypress["D"] == true and prevkeypress["D"] ~= true then -- if combination is pressed, run MapData

    function compress(S) -- dependencies for MapData
        R = (memory.read_u32_le(S) >> 16)
        R = (R & 0xFF)
        return R
    end
        
    function signed(X)
        if X >= 0x80 then
            Y = X - 0x100
        else Y=X
        end
        return Y
    end
        
    function extract_height(S)
        S = (memory.read_u32_le(S) >> 24)
        S = 0x202C000+S*4
        S = memory.read_u32_le(S)
        if (S & 0xF)==0 then
            height = ((S >> 8) & 0xFF)
            height = signed(height)
        elseif (S & 0xF)==1 or (S & 0xF)==2 or (S & 0xF)==3 or (S & 0xF)==4 or (S & 0xF)==8 or (S & 0xF)==9 then
            ha = ((S >> 8) & 0xFF)
            ha = signed(ha)
            hb = ((S >> 16) & 0xFF)
            hb = signed(hb)
            height = (ha+hb)/2
        else
            height = ((S >> 8) & 0xFF)
            height = signed(height)
        end
        
        return height
    end
  dump()
  print("Map data saved")
  end
end


local EncounterDataState
if EncounterDataCheck == true then -- if EncounterData plugin is installed
  if keypress["Ctrl"] == true and keypress["E"] == true and prevkeypress["E"] ~= true then
  EncounterDataState = not EncounterDataState
  if EncounterDataState == true then print("Encounter data turned on") elseif EncounterDataState == false then print("Encounter data turned off") 
  end
end

if EncounterDataState == true then -- if toggled on, run EncounterData
    --placeholder()
end

end
    prevkeypress = input.get()
    --gui.clearGraphics()
    emu.frameadvance();
end
