local screenWidth, screenHeight, meshHeight, meshTop
local font, stars, red, blue, gold, player

local showDebug = false

local posTable = require "posTable"
local levels = require "levels"
local levelTime = 0
local blueBallRemain = 0
local currentLevel = {}
local frame = { -- frame and transition info
  player = 0, -- player animation frame
  prevX = 0,  -- previous 'touch' position (slightly leads the worldPos x,y)
  prevY = 0,
  touchLead = 0.35, -- leading edge for touching next position
  headingForward = true -- if true, we try to match the calculated forwards speed. Else we just coast at current speed.
}
local worldPos = { -- world state
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

function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")
  screenWidth, screenHeight = love.graphics.getDimensions( )
  meshTop = screenHeight / 3
  meshHeight = meshTop * 2

  font = love.graphics.newImageFont("font.png", "0123456789<>[]abcdefghijklmnopqrstuvwxyz() .-#*?_")
  stars = love.graphics.newImageFont("star_font.png", "0123456789ABCDEx")
  red = love.graphics.newImageFont("red_font.png", "0123456789ABCDEx")
  blue = love.graphics.newImageFont("blue_font.png", "0123456789ABCDEx")
  gold = love.graphics.newImageFont("gold_font.png", "0123456789ABCDEx")
  player = love.graphics.newImageFont("player_font.png", "ABCDEFGHIJK0123456")
  font:setFilter("linear", "nearest")
  stars:setFilter("linear", "nearest")
  red:setFilter("linear", "nearest")
  blue:setFilter("linear", "nearest")
  gold:setFilter("linear", "nearest")
  player:setFilter("linear", "nearest")
  love.graphics.setFont(font)
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

  loadLevel(1)
end

function loadLevel(idx)
  currentLevel = {}
  levelTime = 0
  blueBallRemain = 0

  for row = 1, #levels[idx] do
    local rowStr = levels[idx][row]
    table.insert(currentLevel, {})
    for col = 1, rowStr:len() do
      local code = rowStr:sub(col,col)
      if code == "s" then
        code = " "
        worldPos.x = col - 1
        worldPos.y = row - 1
        -- TODO: store, read and set dx,dy
      elseif code == "#" then
        blueBallRemain = blueBallRemain + 1
      end
      currentLevel[row][col] = code
    end
  end
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

function love.update(dt)
  if (dt > 0.1) then return end
  levelTime = levelTime + dt
  frame.player = frame.player + (dt * worldPos.speed * 2)
  local tstep = dt * worldPos.speed
  local qstep = tstep / 4

  -- do position updates
  worldPos.animSteps = math.max(0, worldPos.animSteps - (tstep))

  if (worldPos.animSteps <= 0) then
    worldPos.isTurning = false
    worldPos.y = math.floor(worldPos.y + 0.4999)
    worldPos.x = math.floor(worldPos.x + 0.4999)
    worldPos.rot = math.floor(worldPos.rot + 0.4999)
  end

  -- debug switches
  if (love.keyboard.isDown("z")) then showDebug = true end
  if (love.keyboard.isDown("x")) then showDebug = false end

  if worldPos.animSteps > 4 then worldPos.animSteps = worldPos.animSteps - 4 end
  if (worldPos.animSteps <= 0) then
    if (worldPos.canTurn) and (worldPos.jump < 0.3) and (love.keyboard.isDown("left")) then
      worldPos.drot = -1
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 3.2
      worldPos.rot = worldPos.rot - 0.125
    elseif (worldPos.canTurn) and (worldPos.jump < 0.3) and (love.keyboard.isDown("right")) then
      worldPos.drot = 1
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 3.2
      worldPos.rot = worldPos.rot + 0.125
    else -- start moving forward, unlock turn
      worldPos.animSteps = 4
      worldPos.canTurn = true
    end
  end

  -- switch forward
  if (love.keyboard.isDown("up")) then frame.headingForward = true end
  if frame.headingForward then
    local ds = math.min(dt * 10, targetSpeed() - worldPos.speed)
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
    worldPos.jump = worldPos.jump - (qstep / 2)
  end

  -- trigger ball touch transitions
  local touchX,touchY = offsetToAbsolute(0, frame.touchLead)
  setTouchLead()
  if (worldPos.jump <= 0) and ((frame.prevX ~= touchX) or (frame.prevY ~= touchY)) then
    transitionTrigger()
    frame.prevX = touchX
    frame.prevY = touchY
  end

  -- jump. We do this after triggers so you can't bunny hop over everything
  if (love.keyboard.isDown("space")) and (worldPos.jump <= 0) and (worldPos.speed > 0) and (not worldPos.isTurning) then
    worldPos.jump = 1
    worldPos.canTurn = false
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
  elseif type == "g" then
    -- TODO: launch for 5 positions
  elseif type == "*" then
    bouncePlayer()
  elseif type == "0" then
    -- TODO: pick up ring
  end
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
      if (currentLevel[y - 1][x    ] == '#') then return true end
      if (currentLevel[y    ][x - 1] == '#') then return true end
    elseif (dy == 0) then
      if (currentLevel[y - 1][x - 1] == '#') then return true end
      if (currentLevel[y - 1][x    ] == '#') then return true end
      if (currentLevel[y + 1][x - 1] == '#') then return true end
      if (currentLevel[y + 1][x    ] == '#') then return true end
    elseif (dy == -1) then
      if (currentLevel[y + 1][x    ] == '#') then return true end
      if (currentLevel[y    ][x - 1] == '#') then return true end
    end
  elseif (dx == 0) then
    if (dy == 1) then
      if (currentLevel[y - 1][x - 1] == '#') then return true end
      if (currentLevel[y    ][x - 1] == '#') then return true end
      if (currentLevel[y - 1][x + 1] == '#') then return true end
      if (currentLevel[y    ][x + 1] == '#') then return true end
    elseif (dy == -1) then
      if (currentLevel[y    ][x - 1] == '#') then return true end
      if (currentLevel[y + 1][x - 1] == '#') then return true end
      if (currentLevel[y    ][x + 1] == '#') then return true end
      if (currentLevel[y + 1][x + 1] == '#') then return true end
    end
  elseif (dx == -1) then
    if (dy == 1) then
      if (currentLevel[y - 1][x    ] == '#') then return true end
      if (currentLevel[y    ][x + 1] == '#') then return true end
    elseif (dy == 0) then
      if (currentLevel[y - 1][x + 1] == '#') then return true end
      if (currentLevel[y - 1][x    ] == '#') then return true end
      if (currentLevel[y + 1][x + 1] == '#') then return true end
      if (currentLevel[y + 1][x    ] == '#') then return true end
    elseif (dy == -1) then
      if (currentLevel[y + 1][x    ] == '#') then return true end
      if (currentLevel[y    ][x + 1] == '#') then return true end
    end
  end
  return false
end

-- return the 4-connected neighbors of the tile that contain red balls
-- which are also 8-connected to a blue
-- excludes (ox,oy) from the list
function red4Conns(x,y, ox, oy)
  local list = {}
  if (currentLevel[y][x - 1] == "x") and ((ox ~= (x - 1)) or (oy ~= y)) and hasBlue8Conn(x,y, -1,0) then
    table.insert(list, {x=(x - 1), y=y,       px=x, py=y})
  end
  if (currentLevel[y][x + 1] == "x") and ((ox ~= (x + 1)) or (oy ~= y)) and hasBlue8Conn(x,y, 1,0) then
    table.insert(list, {x=(x + 1), y=y,       px=x, py=y})
  end
  if (currentLevel[y - 1][x] == "x") and ((ox ~= x) or (oy ~= (y - 1))) and hasBlue8Conn(x,y, 0,-1) then
    table.insert(list, {x=x,       y=(y - 1), px=x, py=y})
  end
  if (currentLevel[y + 1][x] == "x") and ((ox ~= x) or (oy ~= (y + 1))) and hasBlue8Conn(x,y, 0,1) then
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
          --appendMap(traceBack, newHead[j], key) -- we hit this later in the loop anyway
          escape = 0 -- got an overlap! time to back trace the loop
        end
      end
    end
  end

  -- trace from the one end of the loop to the other. This excludes any traces
  -- that went nowhere from our list
  local loopPositions = { {x=nx, y=ny} }
  local traceQueue = traceBack[traceBackX.."_"..traceBackY]
  while #traceQueue > 0 do
    local nextQueue = {}
    for i = 1,#traceQueue do local t = traceQueue[i]
      loopPositions[1+#loopPositions] = {x=t.x, y=t.y}
      TableConcat(nextQueue, traceBack[t.px.."_"..t.py])
    end
    traceQueue = nextQueue
  end

  -- once we have the loop, we flip it to rings by scan linear
  -- we need to check there is at least one blue ball *inside* our loop.
  for i = 1,#loopPositions do local t = loopPositions[i]
    currentLevel[t.y][t.x] = "*" -- for testing, flip to stars
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

function love.draw()
  drawSky()

  if (worldPos.isTurning) then
    drawRotation()
  else
    drawNormal()
  end

  drawTails()

  drawUI()
end

function drawTails()
  love.graphics.setFont(player)

  -- shadow
  -- TODO: shadow should go between ground and balls.
  leftStr("H", (screenWidth/2) - 22, screenHeight - 182, 2)
  local height = 0

  -- body
  if (worldPos.jump > 0) then
    height = math.sin(worldPos.jump * math.pi) * 40
    local b = math.floor(worldPos.jump * 2) + 1
    leftStr(("KJI"):sub(b,b), (screenWidth/2) - 22, screenHeight - 182 - height, 2)
  else
    local b = math.floor(frame.player % 12) + 1
    leftStr(("ABCDEFGFEDCB"):sub(b,b), (screenWidth/2) - 22, screenHeight - 182, 2)
  end

  -- the tail
  local t = math.floor((levelTime * 10) % 7) + 1
  leftStr(("0123456"):sub(t,t), (screenWidth/2) - 12, screenHeight - 174 - height, 2)
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
  love.graphics.draw(mesh)
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
    drawDotPosition(pos[1], pos[2], pos[3], pos[4], xf, yf, pos[5])
    if (pos[1] ~= 0) then -- flipped on y axis
      -- dx, dy, tx, ty, xf, yf, size
      drawDotPosition(-(pos[1]), pos[2], 320 - pos[3], pos[4], xf, yf, pos[5])
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
    --love.graphics.setFont(Red)
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

  local levelX = (px % 32) + 1 -- TODO: variable level size
  local levelY = (py % 32) + 1 -- TODO: variable level size

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
  -- TODO: for two of the quadrants, there is a brief flash of wrong position.
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
  else
    leftStr( "<"..blueBallRemain..">", 10, 10, 1)

    if levelTime < 3 then
      centreFontStr( "(get blue spheres)", screenWidth / 2, screenHeight / 2, 2, font)
      centreFontStr( "left and right to turn", screenWidth / 2, screenHeight - 60, 1, font)
      centreFontStr( "up and down to change speed", screenWidth / 2, screenHeight - 40, 1, font)
    end
    if blueBallRemain < 1 then
      centreFontStr( "(you win)", screenWidth / 2, screenHeight / 2, 2, font)
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
  local w = scale * fnt:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end
