local screenWidth, screenHeight, meshHeight, meshTop
local font, stars, red, blue, gold, player

local debug = false

local posTable = require "posTable"
local levels = require "levels"
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
  if (love.keyboard.isDown("z")) then debug = true end
  if (love.keyboard.isDown("x")) then debug = false end

  --[[ controls
  if (love.keyboard.isDown("up")) then
    worldPos.speed = worldPos.speed + (dt * 3)
  elseif (love.keyboard.isDown("down")) then
    worldPos.speed = worldPos.speed - (dt * 3)
  end]]

  if (love.keyboard.isDown("up")) then frame.headingForward = true end

  if worldPos.animSteps > 4 then worldPos.animSteps = worldPos.animSteps - 4 end
  if (worldPos.animSteps <= 0) then
    if (worldPos.canTurn) and (love.keyboard.isDown("left")) then
      worldPos.drot = -1
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 3.2
      worldPos.rot = worldPos.rot - 0.125
    elseif (worldPos.canTurn) and (love.keyboard.isDown("right")) then
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
  if frame.headingForward then
    local ds = math.min(dt * 10, targetSpeed() - worldPos.speed)
    worldPos.speed = worldPos.speed + ds
  end

  -- TODO: jump

  if (worldPos.rot >= 4) then worldPos.rot = 0 end
  if (worldPos.rot < 0) then worldPos.rot = 4 end
  rotToDxDy()

  if (worldPos.isTurning) then
    worldPos.rot = worldPos.rot + (worldPos.drot * qstep)
  elseif (worldPos.animSteps > 0) then
    worldPos.y = worldPos.y + (qstep * worldPos.dy)
    worldPos.x = worldPos.x + (qstep * worldPos.dx)
  end

  -- trigger ball touch transitions
  local touchX,touchY = offsetToAbsolute(0, frame.touchLead)
  setTouchLead()
  if (frame.prevX ~= touchX) or (frame.prevY ~= touchY) then
    transitionTrigger()
    frame.prevX = touchX
    frame.prevY = touchY
  end
end

function targetSpeed()
  return 7 -- TODO: calculate based on difficulty and progress through the level
end

function setTouchLead() -- 0.35
  if (worldPos.speed > 0) then frame.touchLead = 0.35 else frame.touchLead = 0.75 end
end

function transitionTrigger()
  local type = dotType(0, frame.touchLead)
  local nx, ny = offsetToAbsolute(0, frame.touchLead)
  if type == "x" then -- impact! FAIL!
    -- TODO: handle failure
  elseif type == "#" then -- blue dot, flip to red
    -- TODO: score, countdown, check for looping, etc
    currentLevel[ny][nx] = "x" -- 1-based vs 0-based issues
  elseif type == "g" then
    -- TODO: launch for 5 positions
  elseif type == "*" then
    -- TODO: proper bounce
    worldPos.speed = - worldPos.speed
    local tx, ty = offsetToAbsolute(0, -0.7)
    frame.prevX = tx
    frame.prevY = ty
    setTouchLead()
    if worldPos.speed < 0 then frame.headingForward = false else frame.headingForward = true end

  elseif type == "0" then
    -- TODO: pick up ring
  end
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
  local b = math.floor(frame.player % 12) + 1
  local t = math.floor(frame.player % 7) + 1
  leftStr(("ABCDEFGFEDCB"):sub(b,b), (screenWidth/2) - 22, screenHeight - 182, 2)
  leftStr(("0123456"):sub(t,t), (screenWidth/2) - 12, screenHeight - 174, 2)
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

  if debug then leftStr("<"..pidx.."]", 10, 170, 2) end

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

  if debug then leftStr("<"..pidx.."]", 10, 170, 2) end

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

  if debug then
    leftStr( "rot <"..(worldPos.rot)..">", 10, 10, 1)
    leftStr( "spd <"..(math.floor(worldPos.speed))..">", 10, 30, 1)
    leftStr( "stp <"..(math.floor(worldPos.animSteps))..">", 10, 50, 1)

    rightStr( " x y  ["..(math.floor(worldPos.x))..".."..(math.floor(worldPos.y)).."]", screenWidth - 10, 10, 1)
    rightStr( "dx dy ["..(math.floor(worldPos.dx))..".."..(math.floor(worldPos.dy)).."]", screenWidth - 10, 40, 1)
    rightStr( "mouse ["..(math.floor(x * 2000)/1000)..".."..(math.floor(y * 1450)/1000).."]", screenWidth - 10, 70, 1)

    leftStr("type <"..dotType(0,0.35).."]", 10, 70, 1)
  else
    centreFontStr( "(get blue spheres)", screenWidth / 2, screenHeight / 2, 2, font)
    centreFontStr( "left and right to turn", screenWidth / 2, screenHeight - 60, 1, font)
    centreFontStr( "up and down to change speed", screenWidth / 2, screenHeight - 40, 1, font)
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
