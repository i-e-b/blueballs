local screenWidth, screenHeight, meshHeight, meshTop
local font, stars, red, blue, gold, player, ring_1
local music
local winJumpImg

local showDebug = false

local posTable = require "posTable"
local levels = require "levels"
local levelTime = 0
local blueBallRemain = 0
local ringsRemain = 0
local currentLevel = {}
local localLevelNumber = 1
local levelRows = 0
local levelCols = 0
local gamepad
local templateFrame = { -- frame and transition info
  player = 3, -- player animation frame
  prevX = 0,  -- previous 'touch' position (slightly leads the worldPos x,y)
  prevY = 0,
  touchLead = 0.35, -- leading edge for touching next position
  headingForward = false, -- if true, we try to match the calculated forwards speed. Else we just coast at current speed.
  leftTurnLatch = false, -- pressed left control
  rightTurnLatch = false, -- pressed right control
  jumpLatch = false,
  jumpHeight = 1,
  avatarOffset = 0,   -- for level transition
  fadeStep = 1,       -- also for level transition
  perfectTimer = 3,
}
local templateWorldPos = { -- world state
                  rot = 0,       -- out of 4 (0 to 3)
                  drot = 0,      -- rotate direction (-1 or 1)
                  animSteps = 0, -- steps remaining
                  dx = 0,        -- walking direction
                  dy = 1,
                  x = 0,         -- absolute position
                  y = 0,
                  jump = 0,      -- steps of jump left
                  isTurning = false,
                  canTurn = false,
                  speed = 0      -- actual current speed. Can be negative when going backwards
                }
local frame = {}
local worldPos = {}

function love.load()
  for k,v in pairs(templateFrame) do frame[k] = v end
  for k,v in pairs(templateWorldPos) do worldPos[k] = v end
  love.window.fullscreen = (love.system.getOS() == "Android")
  screenWidth, screenHeight = love.graphics.getDimensions( )
  meshTop = screenHeight / 3
  meshHeight = meshTop * 2

  font = love.graphics.newImageFont("font.png", "0123456789<>[]abcdefghijklmnopqrstuvwxyz() .-#*?_")
  stars = love.graphics.newImageFont("star_font.png", "0123456789ABCDEx")
  red = love.graphics.newImageFont("red_font.png", "0123456789ABCDEx")
  blue = love.graphics.newImageFont("blue_font.png", "0123456789ABCDEx")
  gold = love.graphics.newImageFont("gold_font.png", "0123456789ABCDEx")
  ring_1 = love.graphics.newImageFont("ring_1_font.png", "0123456789ABCDEx")
  player = love.graphics.newImageFont("player_font.png", "ABCDEFGHIJK0123456")
  font:setFilter("linear", "nearest")
  stars:setFilter("linear", "nearest")
  red:setFilter("linear", "nearest")
  blue:setFilter("linear", "nearest")
  gold:setFilter("linear", "nearest")
  ring_1:setFilter("linear", "nearest")
  player:setFilter("linear", "nearest")
  love.graphics.setFont(font)

  winJumpImg = love.graphics.newImage("win_jump.png")
  winJumpImg:setFilter("linear", "nearest")

  -- Palette animation shader
  -- green channel encodes palette index
  -- background is last color index
  -- the palette lookup can be simpler on PC, but this works on PC and mobile
  shader = love.graphics.newShader([[
		extern vec4 palette[9]; // size of color palette
		vec4 effect(vec4 color, Image texture, vec2 tc, vec2 sc) {
      int idx = int((Texel(texture, tc).g * 255.0f) + 0.5) - 1;
      return palette[idx];
		}
	]] )

  local r = screenWidth
  local h = screenHeight
  local t = meshTop
  mesh = love.graphics.newMesh( {
    { 0,t,  0,0 }, { r,h,  1,1 }, { 0,h,  0,1 }, -- triangle #1 uses first color (0)
    { r,h,  1,1 }, { r,t,  1,0 }, { 0,t,  0,0 }      -- triangle #2 uses second color (1)
  }, "triangles" )
  flipmesh = love.graphics.newMesh( {
    { 0,t,  1,0 }, { r,h,  0,1 }, { 0,h,  1,1 }, -- triangle #1 uses first color (0)
    { r,h,  0,1 }, { r,t,  0,0 }, { 0,t,  1,0 }      -- triangle #2 uses second color (1)
  }, "triangles" )

  texture1 = love.graphics.newImage("bg1idx.png")
  texture2 = love.graphics.newImage("bg2idx.png")

  rot1 = love.graphics.newImage("bgr1.png")
  rot2 = love.graphics.newImage("bgr2.png")
  rot3 = love.graphics.newImage("bgr3.png")
  rot4 = love.graphics.newImage("bgr4.png")

  -- All the textures must be nearest neighbor for the palette mapping to work
  texture1:setFilter("nearest", "nearest")
  texture2:setFilter("nearest", "nearest")
  rot1:setFilter("nearest", "nearest")
  rot2:setFilter("nearest", "nearest")
  rot3:setFilter("nearest", "nearest")
  rot4:setFilter("nearest", "nearest")

  loadLevel(localLevelNumber)

  --music = love.audio.newSource("popcorn.mod")
  --music:play()
end

function loadLevel(idx)
  currentLevel = {}
  levelTime = 0
  for k,v in pairs(templateFrame) do frame[k] = v end
  for k,v in pairs(templateWorldPos) do worldPos[k] = v end

  blueBallRemain = 0
  ringsRemain = levels[idx].ringsAvail
  worldPos.rot = levels[idx].rotation
  worldPos.speed = 0.000000001
  rotToDxDy()

  local layout = levels[idx].layout

  levelRows = #layout
  levelCols = (layout[1]):len()
  for row = 1, #layout do
    local rowStr = layout[row]
    table.insert(currentLevel, {})
    for col = 1, rowStr:len() do
      local code = rowStr:sub(col,col)
      if code == "s" then
        code = " "
        worldPos.x = col - 1
        worldPos.y = row - 1
      elseif code == "#" then
        blueBallRemain = blueBallRemain + 1
      end
      currentLevel[row][col] = code
    end
  end
  setTouchLead()
end

local A = { 33,109,0,255 }
local B = { 0, 255, 181,255 }
local X = { 0,0,0,0 } -- transparent color
function P(idx)
  local i = math.floor(idx) % 9
  if     (i <  2) then shader:sendColor( "palette", A, A, A, A, B, B, B, B, X)
  elseif (i == 2) then shader:sendColor( "palette", B, A, A, A, A, B, B, B, X)
  elseif (i == 3) then shader:sendColor( "palette", B, B, A, A, A, A, B, B, X)
  elseif (i == 4) then shader:sendColor( "palette", B, B, B, A, A, A, A, B, X)
  elseif (i == 5) then shader:sendColor( "palette", B, B, B, B, A, A, A, A, X)
  elseif (i == 6) then shader:sendColor( "palette", A, B, B, B, B, A, A, A, X)
  elseif (i == 7) then shader:sendColor( "palette", A, A, B, B, B, B, A, A, X)
  elseif (i == 8) then shader:sendColor( "palette", A, A, A, B, B, B, B, A, X) end
end

function updateLevelTransition(dt)
  frame.avatarOffset = math.min(600, frame.avatarOffset + (dt * 800))
  if (frame.fadeStep > 0) then
    frame.fadeStep = math.min(1, frame.fadeStep + dt)
  elseif (frame.jumpLatch) and (frame.avatarOffset > 300) then
    frame.fadeStep = math.min(1, frame.fadeStep + dt)
  end

  if (frame.fadeStep >= 1) then
    localLevelNumber = localLevelNumber + 1
    loadLevel(localLevelNumber)
  end
end

function love.update(dt)
  if (dt > 0.1) then return end
  levelTime = levelTime + dt
  frame.player = frame.player + (dt * worldPos.speed * 2)

  local tstep = 0
  local qstep = 0
  readControls()
  if blueBallRemain > 0 then
    frame.fadeStep = math.max(0, frame.fadeStep - dt)
    tstep = dt * worldPos.speed
    qstep = tstep / 4
  else
    updateLevelTransition(dt)
    frame.jumpLatch = false
  end

  if ringsRemain < 1 then
    frame.perfectTimer = math.max(0, frame.perfectTimer - dt)
  end

  -- do position updates
  worldPos.animSteps = math.max(0, worldPos.animSteps - (tstep))

  if (worldPos.animSteps <= 0) then
    worldPos.isTurning = false
    worldPos.y = math.floor(worldPos.y + 0.5)
    worldPos.x = math.floor(worldPos.x + 0.5)
    worldPos.rot = math.floor(worldPos.rot + 0.5)
  end

  local jumpThreshold = 4 -- for easy mode. Normal should be 0

  if worldPos.animSteps > 4 then worldPos.animSteps = worldPos.animSteps - 4 end
  if (worldPos.animSteps <= 0) then
    if (worldPos.canTurn) and (worldPos.jump <= jumpThreshold) and (frame.leftTurnLatch) then
      frame.leftTurnLatch = false
      worldPos.drot = -1
      worldPos.jump = 0
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 3.2
      worldPos.rot = worldPos.rot - 0.125
    elseif (worldPos.canTurn) and (worldPos.jump <= jumpThreshold) and (frame.rightTurnLatch) then
      frame.rightTurnLatch = false
      worldPos.drot = 1
      worldPos.jump = 0
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 3.2
      worldPos.rot = worldPos.rot + 0.125
    else -- start moving forward, unlock turn
      frame.jumpLatch = false
      frame.leftTurnLatch = false
      frame.rightTurnLatch = false
      worldPos.animSteps = 4
      worldPos.canTurn = true
    end
  end

  if frame.headingForward then
    local ds = math.max(-dt * 20, math.min(dt * 10, targetSpeed() - worldPos.speed))
    worldPos.speed = worldPos.speed + ds
  end

  if (worldPos.rot >= 4) then worldPos.rot = 0 end
  if (worldPos.rot < 0) then worldPos.rot = 4 end
  rotToDxDy()

  if (worldPos.isTurning) then
    worldPos.rot = worldPos.rot + (worldPos.drot * qstep)
  elseif (worldPos.animSteps > 0) then
    worldPos.y = worldPos.y + (qstep * worldPos.dy)
    worldPos.x = worldPos.x + (qstep * worldPos.dx)
  end
  if (worldPos.jump > 0) then
    worldPos.jump = worldPos.jump - tstep
  end

  -- trigger ball touch transitions
  if not worldPos.isTurning then
    setTouchLead()
    local touchX,touchY = offsetToAbsolute(0, frame.touchLead)
    if (worldPos.jump <= 0) and ((frame.prevX ~= touchX) or (frame.prevY ~= touchY)) then
      transitionTrigger()
      frame.prevX = touchX
      frame.prevY = touchY
    elseif (worldPos.jump > 0) then -- easy mode only...
      frame.prevX = touchX
      frame.prevY = touchY
    end
  end

  -- jump. We do this after triggers so you can't bunny hop over everything
  if (frame.jumpLatch) and (worldPos.jump <= 0) and (worldPos.speed > 0) and (not worldPos.isTurning) then
    regularJump()
  end
end

function regularJump()
  worldPos.jump = 7
  frame.jumpHeight = 7
  frame.jumpLatch = false
  worldPos.canTurn = false
end
function goldJump()
  worldPos.jump = 24
  frame.jumpHeight = 24
  worldPos.speed = 20
  frame.jumpLatch = false
  worldPos.canTurn = false
end

function readControls()
  -- debug switches
  if (love.keyboard.isDown("z")) then showDebug = true end
  if (love.keyboard.isDown("x")) then showDebug = false end
  if (love.keyboard.isDown("c")) then -- simulate gold ball
    goldJump()
  end

  local left = false
  local right = false
  local up = false
  local jump = false

  if gamepad then
    local dx = gamepad:getAxis(1)
    local dy = gamepad:getAxis(2)
    if dx == 1 then right = true end
    if dx == -1 then left = true end
    if gamepad:isDown(1,2,3,4) then jump = true end
    if dy == -1 then up = true end
  end
  if love.keyboard.isDown("left") then left = true end
  if love.keyboard.isDown("right") then right = true end
  if love.keyboard.isDown("space") then jump = true end
  if love.keyboard.isDown("up") then up = true end

  if (up) and (not frame.headingForward) then
    frame.headingForward = true
    frame.leftTurnLatch = false
    frame.rightTurnLatch = false
    frame.jumpLatch = false
  else
    -- limit turn pickup to improve 'feel'
    if (worldPos.animSteps > 0.7) and (worldPos.animSteps < 3) then
      if left then frame.leftTurnLatch = true end
      if right then frame.rightTurnLatch = true end
    end
    if jump then frame.jumpLatch = true end
  end
end

-- connect joysticks and gamepads
function love.joystickadded(joystick)
  gamepad = joystick
end

function love.joystickremoved(joystick)
  if (gamepad == joystick) then
    gamepad = nil
  end
end

function targetSpeed()
  return 7 -- TODO: calculate based on difficulty and progress through the level
end

function setTouchLead()
  if (worldPos.speed > 0) then frame.touchLead = 0.35 else frame.touchLead = 0.75 end
end

function transitionTrigger()
  local type = dotType(0, frame.touchLead)
  local nx, ny = offsetToAbsolute(0, frame.touchLead)
  if type == "x" then -- impact! FAIL!
    -- TODO: handle failure
    bouncePlayer() -- boucing on red can be 'easy mode' for kids
  elseif type == "#" then -- blue dot, flip to red
    flipBallAt(nx, ny)
    if dotType(0, frame.touchLead) == "0" then
      ringsRemain = ringsRemain - 1
      currentLevel[ny][nx] = " "
    end
  elseif type == "g" then
    goldJump()
  elseif type == "*" then
    bouncePlayer()
  elseif type == "0" then
    ringsRemain = ringsRemain - 1
    currentLevel[ny][nx] = " "
  end
end

function levelTile(y,x)
  local px = ((x-1) % levelCols) + 1  -- 1-based indexing is stupid
  local py = ((y-1) % levelRows) + 1  -- very stupid

  return currentLevel[py][px]
end

-- true if any of the position's 8 neighbors are blue balls
-- that are shared with the 8-conn blue balls of the parent
-- px,py: position of the parent
-- dx,dy: offset of the target position. Must be within -1..1
function hasBlue8Conn(px,py, dx, dy)
  local x = px+dx
  local y = py+dy

  if (dx == 1) then
    if (dy == 1) then
      if (levelTile(y - 1,x    ) == '#') then return true end
      if (levelTile(y    ,x - 1) == '#') then return true end
    elseif (dy == 0) then
      if (levelTile(y - 1,x - 1) == '#') then return true end
      if (levelTile(y - 1,x    ) == '#') then return true end
      if (levelTile(y + 1,x - 1) == '#') then return true end
      if (levelTile(y + 1,x    ) == '#') then return true end
    elseif (dy == -1) then
      if (levelTile(y + 1,x    ) == '#') then return true end
      if (levelTile(y    ,x - 1) == '#') then return true end
    end
  elseif (dx == 0) then
    if (dy == 1) then
      if (levelTile(y - 1,x - 1) == '#') then return true end
      if (levelTile(y    ,x - 1) == '#') then return true end
      if (levelTile(y - 1,x + 1) == '#') then return true end
      if (levelTile(y    ,x + 1) == '#') then return true end
    elseif (dy == -1) then
      if (levelTile(y    ,x - 1) == '#') then return true end
      if (levelTile(y + 1,x - 1) == '#') then return true end
      if (levelTile(y    ,x + 1) == '#') then return true end
      if (levelTile(y + 1,x + 1) == '#') then return true end
    end
  elseif (dx == -1) then
    if (dy == 1) then
      if (levelTile(y - 1,x    ) == '#') then return true end
      if (levelTile(y    ,x + 1) == '#') then return true end
    elseif (dy == 0) then
      if (levelTile(y - 1,x + 1) == '#') then return true end
      if (levelTile(y - 1,x    ) == '#') then return true end
      if (levelTile(y + 1,x + 1) == '#') then return true end
      if (levelTile(y + 1,x    ) == '#') then return true end
    elseif (dy == -1) then
      if (levelTile(y + 1,x    ) == '#') then return true end
      if (levelTile(y    ,x + 1) == '#') then return true end
    end
  end
  return false
end

-- return the 4-connected neighbors of the tile that contain red balls
-- which are also 8-connected to a blue
-- excludes (ox,oy) from the list
function red4Conns(x,y, ox, oy)
  local list = {}
  if (levelTile(y,x - 1) == "x") and ((ox ~= (x - 1)) or (oy ~= y)) and hasBlue8Conn(x,y, -1,0) then
    table.insert(list, {x=(x - 1), y=y,       px=x, py=y})
  end
  if (levelTile(y,x + 1) == "x") and ((ox ~= (x + 1)) or (oy ~= y)) and hasBlue8Conn(x,y, 1,0) then
    table.insert(list, {x=(x + 1), y=y,       px=x, py=y})
  end
  if (levelTile(y - 1,x) == "x") and ((ox ~= x) or (oy ~= (y - 1))) and hasBlue8Conn(x,y, 0,-1) then
    table.insert(list, {x=x,       y=(y - 1), px=x, py=y})
  end
  if (levelTile(y + 1,x) == "x") and ((ox ~= x) or (oy ~= (y + 1))) and hasBlue8Conn(x,y, 0,1) then
    table.insert(list, {x=x,       y=(y + 1), px=x, py=y})
  end
  return list
end
function TableConcat(t1,t2)
  if (not t2) then return end
  for i=1,#t2 do
    t1[#t1+1] = t2[i]
  end
  return t1
end

-- This handles flipping blue->red and converting red loops to rings.
-- More complex than the rest of the game!
function flipBallAt(nx, ny)
  blueBallRemain = blueBallRemain - 1
  currentLevel[ny][nx] = "x"

  -- loop check: must complete a 4-connected loop (no diagonals) of red balls,
  -- with at least 1 blue ball inside. Double-thick walls don't trigger
  -- if a loop is detected, all the blue balls and their 8-connections flip to rings?

  -- We build a table of reds that are 4 connected, with links back to the trigger ball
  -- we only follow reds that are 8 connected to a blue

  -- in both these lists, we have the x,y position we are looking at, plus the direction we came from
  local escape = 1000
  local traceBack = {}
  local traceBackX = 0
  local traceBackY = 0
  local head = red4Conns(nx,ny) -- if any position is repeated here, we have a loop. If we run out, no loop so exit

  while escape > 0 do escape = escape - 1
    local newHead = {}
    for i = 1, #head do
      local p = head[i]
      TableConcat(newHead, red4Conns(p.x, p.y, p.px, p.py))
      appendMap(traceBack, p, p.x.."_"..p.y)
    end
    if #newHead < 2 then return end -- not possible to find a loop
    head = newHead

    -- check for overlaps
    for i = 1, #newHead do
      for j = 1, #newHead do -- not efficient, but should never be more than 4
        if (i ~= j) and (newHead[i].x == newHead[j].x) and (newHead[i].y == newHead[j].y) then
          traceBackX = newHead[i].x
          traceBackY = newHead[i].y
          appendMap(traceBack, newHead[i], newHead[i].x.."_"..newHead[i].y)
          escape = 0 -- got an overlap! time to back trace the loop
        end
      end
    end
  end

  -- trace from the one end of the loop to the other. This excludes any traces
  -- that went nowhere from our list
  local loopPositions = { } -- {x=nx, y=ny}
  loopPositions[nx] = {}
  loopPositions[nx][ny] = true
  local traceQueue = traceBack[traceBackX.."_"..traceBackY]
  while #traceQueue > 0 do
    local nextQueue = {}
    for i = 1,#traceQueue do local t = traceQueue[i]
      loopPositions[t.x] = loopPositions[t.x] or {}
      loopPositions[t.x][t.y] = true
      TableConcat(nextQueue, traceBack[t.px.."_"..t.py])
    end
    traceQueue = nextQueue
  end

  -- now we have a load of loop positions.
  -- go through the level in scan lines, noting the position of all trapped blue balls
  -- when we see the other side of a loop, we add the found balls to the pop list
  local pops = {}
  local pending = {}
  local trig = 0
  for y = 1, levelRows do
    pending = {}
    trig = 0 -- trigger state: 0:wait for loop, 1: loop edge, 2:loop body, 3:loop exit
    for x = 1, levelCols do
      if (loopPositions[x]) and (loopPositions[x][y]) then
        if (trig < 2) then
          trig = 1
        else
          TableConcat(pops, pending)
          pending = {}
          trig = 3
        end
      elseif (trig == 1) then
        if (currentLevel[y][x] == "#") then -- a blueball to pop
          trig = 2 -- latch to inside of loop
          table.insert(pending, {x=x, y=y})
        else
          trig = 0 -- we left the edge of a loop
        end
      elseif (trig == 2) and (currentLevel[y][x] == "#") then
        table.insert(pending, {x=x, y=y})
      elseif (trig > 2) then -- out of the loop
        trig = 0
      end -- not inside a loop, or empty gap in a loop
    end
  end

  -- Finally, pop all the trapped blue balls and their 8-connected red balls
  for i = 1,#pops do
    -- flip the blue to a ring
    local x = pops[i].x
    local y = pops[i].y
    currentLevel[y][x] = "0"
    blueBallRemain = blueBallRemain - 1
    -- flip reds to rings
    if (currentLevel[y-1][x-1] == "x") then currentLevel[y-1][x-1] = "0" end
    if (currentLevel[y-1][x  ] == "x") then currentLevel[y-1][x  ] = "0" end
    if (currentLevel[y-1][x+1] == "x") then currentLevel[y-1][x+1] = "0" end

    if (currentLevel[y  ][x-1] == "x") then currentLevel[y  ][x-1] = "0" end
    if (currentLevel[y  ][x+1] == "x") then currentLevel[y  ][x+1] = "0" end

    if (currentLevel[y+1][x-1] == "x") then currentLevel[y+1][x-1] = "0" end
    if (currentLevel[y+1][x  ] == "x") then currentLevel[y+1][x  ] = "0" end
    if (currentLevel[y+1][x+1] == "x") then currentLevel[y+1][x+1] = "0" end
  end
end

function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))
    else
      print(formatting .. v)
    end
  end
end

function appendMap(arry, obj, index)
  if not arry[index] then
    arry[index] = {obj}
    return
  end
  table.insert(arry[index], obj)
end

function bouncePlayer()
  worldPos.speed = - worldPos.speed
  worldPos.jump = 0
  local tx, ty = offsetToAbsolute(0, -0.7)
  frame.prevX = tx
  frame.prevY = ty
  setTouchLead()
  if worldPos.speed < 0 then frame.headingForward = false else frame.headingForward = true end
end

function rotToDxDy()
  local qrot = math.floor(worldPos.rot)
  if (qrot == 0) then
    worldPos.dx = 0
    worldPos.dy = 1
  elseif (qrot == 1) then
    worldPos.dx = 1
    worldPos.dy = 0
  elseif (qrot == 2) then
    worldPos.dx = 0
    worldPos.dy = -1
  else
    worldPos.dx = -1
    worldPos.dy = 0
  end
end

function idxPhase()
  local rph = math.floor(worldPos.rot) % 2
  local xph = (worldPos.x) % 2
  local yph = (worldPos.y) % 2
  local corePhase = (rph + xph + yph) % 2

  return corePhase * 4
end

--##############################################

function love.draw()
  drawSky()

  if (worldPos.isTurning) then
    drawRotation()
  else
    drawNormal()
  end

  drawTails()

  drawUI()

  -- fade here
  if (frame.fadeStep > 0) then
    love.graphics.setBlendMode("add")
    local f = math.min(frame.fadeStep * 511, 255)
    local f2 = math.min((frame.fadeStep * 511) - f, 255)
  	love.graphics.setColor(f,f,f2)
  	love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
  	love.graphics.setColor(255,255,255)
    love.graphics.setBlendMode("alpha")
  end
end

function drawTails()
  love.graphics.setFont(player)

  -- shadow
  leftStr("H", (screenWidth/2) - 22, screenHeight - 182 + frame.avatarOffset, 2)
  local height = 0

  -- body
  if (worldPos.jump > 0) then
    height = math.sin((worldPos.jump / frame.jumpHeight) * math.pi) * 4 * frame.jumpHeight
    local b = math.floor((worldPos.jump / frame.jumpHeight) * 2) + 1
    leftStr(("KJIKJIKJI"):sub(b,b), (screenWidth/2) - 22, screenHeight - 182 - height, 2)
  else
    local b = math.floor(frame.player % 12) + 1
    leftStr(("ABCDEFGFEDCB"):sub(b,b), (screenWidth/2) - 22, screenHeight - 182 + frame.avatarOffset, 2)
  end

  -- the tail
  local t = math.floor((levelTime * 10) % 7) + 1
  leftStr(("0123456"):sub(t,t), (screenWidth/2) - 12, screenHeight - 174 - height + frame.avatarOffset, 2)


  if blueBallRemain < 1 then
    love.graphics.draw(winJumpImg, (screenWidth / 2) - 110, screenHeight + 200 - frame.avatarOffset, 0, 2, 2, 0, 0)
  end
end

function drawNormal()
  local phase = idxPhase()
  if (worldPos.dx + worldPos.dy) < 0 then
    phase = 8 - phase
  end

  -- checker ball floor
  love.graphics.setShader( shader )
  P(phase + 1)
  if (phase - math.floor(phase)) < 0.5 then
    mesh:setTexture( texture1 )
  else
    mesh:setTexture( texture2 )
  end
  love.graphics.draw(mesh, 0, frame.avatarOffset)
  love.graphics.setShader()

  -- dots
  love.graphics.setColor(255,255,255, 255)
  local xf = screenWidth / 320
  local yf = meshHeight / 192
  local pidx = math.floor((phase % 4) + 1)

  if showDebug then leftStr("<"..pidx.."]", 10, 170, 2) end

  for i=#(posTable.mov[pidx]),1,-1 do -- table of offsets (going backward for z order)
    local pos = posTable.mov[pidx][i]
    -- dx, dy, tx, ty, xf, yf, size
    drawDotPosition(pos[1], pos[2], pos[3], pos[4] - frame.avatarOffset, xf, yf, pos[5])
    if (pos[1] ~= 0) then -- flipped on y axis
      -- dx, dy, tx, ty, xf, yf, size
      drawDotPosition(-(pos[1]), pos[2], 320 - pos[3], pos[4] - frame.avatarOffset, xf, yf, pos[5])
    end
  end -- end of dots
  love.graphics.setFont(font)
end

function setBallFont(type)
  -- Red:x, Blue:#, Gold:G, Star:*, Ring:0, Blank:" "
  -- Sonic: S
  if type == "x" then
    love.graphics.setFont(red)
  elseif type == "#" then
    love.graphics.setFont(blue)
  elseif type == "g" then
    love.graphics.setFont(gold)
  elseif type == "*" then
    love.graphics.setFont(stars)
  elseif type == "0" then
    love.graphics.setFont(ring_1) -- TODO: timer to spin the rings
  end
end

function offsetToAbsolute(dx,dy)
  local dpx = 0
  local dpy = 0

  -- rotate the offsets to match the world
  if (worldPos.rot < 1) then     -- x, +y
    dpx = -dx
    dpy = dy
  elseif (worldPos.rot < 2) then -- +x, y
    dpx = dy
    dpy = dx
  elseif (worldPos.rot < 3) then -- x, -y
    dpx = dx
    dpy = 1 - dy
  else                           -- -x, y
    dpx = 1 - dy
    dpy = -dx
  end

  -- calculate positions
  local px = math.floor(worldPos.x + dpx)
  local py = math.floor(worldPos.y + dpy)

  local levelX = (px % levelCols) + 1
  local levelY = (py % levelRows) + 1

  return levelX, levelY
end

function dotType(dx,dy)
  local levelX, levelY = offsetToAbsolute(dx,dy)
  return currentLevel[levelY][levelX]
end

function drawDotPosition(dx, dy, tx, ty, xf, yf, size)
  local sx = tx * xf
  local sy = meshTop + (ty * yf) - 32

  local type = dotType(dx,dy)
  if (type ~= " ") then
    setBallFont(type)
    centreFontStr(size, sx, sy, 2, stars)
  end
end

function drawRotation()
  local i = (worldPos.rot * 8) % 8

  if (idxPhase() < 4) then
    P(1)
  else
    P(5)
  end

  local drawMesh = flipmesh
  if (i < 5) then drawMesh = mesh end
  local pidx = 1

  -- checker board
  if (i < 2) then
    pidx = 1
    drawMesh:setTexture(rot1)
  elseif (i < 3) then
    pidx = 2
    drawMesh:setTexture(rot2)
  elseif (i < 4) then
    pidx = 3
    drawMesh:setTexture(rot3)
  elseif (i < 5) then
    pidx = 4
    drawMesh:setTexture(rot4)
  elseif (i < 6) then
    pidx = 5
    drawMesh:setTexture(rot3)
  elseif (i < 7) then
    pidx = 6
    drawMesh:setTexture(rot2)
  else
    pidx = 7
    drawMesh:setTexture(rot1)
  end
  love.graphics.setShader( shader )
  love.graphics.draw(drawMesh)
  love.graphics.setShader()

  -- dots
  love.graphics.setColor(255,255,255, 255)
  local xf = screenWidth / 320
  local yf = meshHeight / 192

  if showDebug then leftStr("<"..pidx.."]", 10, 170, 2) end

  -- adjust the rotation offsets
  local ddy = 0
  if (worldPos.rot > 2) then
    ddy = 1
  end

  if (pidx > 0) then
    for i=#(posTable.rot[pidx]),1,-1 do -- table of offsets (going backward for z order)
      local pos = posTable.rot[pidx][i]
      -- dx, dy, tx, ty, xf, yf, size
      drawDotPosition(pos[1], pos[2] + ddy, pos[3], pos[4], xf, yf, pos[5])
    end -- end of dots
  end
  love.graphics.setFont(font)
end

function drawSky()
  love.graphics.setShader( )
  love.graphics.setColor(120,120,255, 255)
  love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
end

function drawUI()
  love.graphics.setFont(font)
  love.graphics.setShader()
  love.graphics.setColor(255,255,255, 255)

  local r = screenWidth
  local h = (2 * screenHeight) / 3
  local t = screenHeight / 3
  local x, y = love.mouse.getPosition()
  x = x / r
  y = math.max(0, (y - t) / h)

  if showDebug then
    leftStr( "rot <"..(worldPos.rot)..">", 10, 10, 1)
    leftStr( "spd <"..(math.floor(worldPos.speed))..">", 10, 30, 1)

    rightStr( " x y  ["..(math.floor(worldPos.x))..".."..(math.floor(worldPos.y)).."]", screenWidth - 10, 10, 1)
    rightStr( "dx dy ["..(math.floor(worldPos.dx))..".."..(math.floor(worldPos.dy)).."]", screenWidth - 10, 40, 1)
    rightStr( "mouse ["..(math.floor(x * 2000)/1000)..".."..(math.floor(y * 1450)/1000).."]", screenWidth - 10, 70, 1)

    if gamepad then
      local dx = gamepad:getAxis(1)
      local dy = gamepad:getAxis(2)
      leftStr( "pad dx dy <"..dx.."]<"..dy.."]", 10, 80, 1)
      if gamepad:isDown(1,2,3,4) then frame.jumpLatch = true end
    end
  else
    leftStr( "<"..blueBallRemain..">", 10, 10, 1)
    rightStr("["..ringsRemain.."]", screenWidth - 10, 10, 1)

    if levelTime < 3 then
      centreFontStr( "up to move forward", screenWidth / 2, (screenHeight / 2) - 40, 1, font)
      centreFontStr( "(get blue spheres)", screenWidth / 2, screenHeight / 2, 2, font)
      centreFontStr( "left and right to turn", screenWidth / 2, screenHeight - 60, 1, font)
      centreFontStr( "spacebar to jump", screenWidth / 2, screenHeight - 40, 1, font)
    end
    if blueBallRemain < 1 then
      centreFontStr( "(you win)", screenWidth / 2, screenHeight / 2, 2, font)
      centreFontStr( "jump to continue", screenWidth / 2, screenHeight - 40, 1, font)
    end
    if (ringsRemain < 1) and (frame.perfectTimer > 0) then
      centreFontStr( "(perfect!)", screenWidth / 2, screenHeight / 2, 2, font)
    end
  end
end

function leftStr(str, x, y, scale)
  love.graphics.print(str, math.floor(x), math.floor(y), 0, scale)
end
function rightStr(str, x, y, scale)
  scale = scale or 1
  local w = scale * font:getWidth(str)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end
function centreFontStr(str, x, y, scale, fnt)
  scale = scale or 1
  local w = (scale * fnt:getWidth(str)) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end
