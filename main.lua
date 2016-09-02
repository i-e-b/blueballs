local screenWidth, screenHeight
local font

local worldPos = { -- world state
                  rot = 0,       -- out of 4
                  drot = 0,      -- rotate direction
                  animSteps = 0, -- steps remaining
                  dx = 0,        -- walking direction
                  dy = 1,
                  x = 0,         -- absolute position
                  y = 0,
                  isTurning = false,
                  canTurn = false,
                  speed = 7      -- goes up as level progresses
                }

function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")
  screenWidth, screenHeight = love.graphics.getDimensions( )

  font = love.graphics.newImageFont("font.png", "0123456789<>[]abcdefghijklmnopqrstuvwxyz() .-")
  font:setFilter("linear", "nearest")
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
  local t = screenHeight / 3
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
end

local A = { 107,36,0,255 }
local B = { 255,146,0,255 }
local X = { 0,0,0,0 }
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
  local tstep = dt * worldPos.speed

  -- controls
  if (love.keyboard.isDown("up")) then
    worldPos.speed = worldPos.speed + (dt * 3)
  elseif (love.keyboard.isDown("down")) then
    worldPos.speed = worldPos.speed - (dt * 3)
  end
  if (worldPos.animSteps <= 0) then
    if (worldPos.canTurn) and (love.keyboard.isDown("left")) then
      worldPos.drot = -1
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 4
    elseif (worldPos.canTurn) and (love.keyboard.isDown("right")) then
      worldPos.drot = 1
      worldPos.isTurning = true
      worldPos.canTurn = false
      worldPos.animSteps = 4
    else -- start moving forward, unlock turn
      worldPos.animSteps = 4
      worldPos.canTurn = true
    end
  end

  -- TODO: jump and switch forward

  -- do position updates
  worldPos.animSteps = math.max(0, worldPos.animSteps - (tstep))

  if (worldPos.animSteps <= 0) then
    worldPos.animSteps = 0
    worldPos.isTurning = false
    worldPos.y = math.floor(worldPos.y + 0.4999)
    worldPos.x = math.floor(worldPos.x + 0.4999)
    worldPos.rot = math.floor(worldPos.rot + 0.4999)
  end

  if (worldPos.rot >= 4) then worldPos.rot = worldPos.rot - 4 end
  if (worldPos.rot < 0) then worldPos.rot = worldPos.rot + 4 end
  rotToDxDy()

  if (worldPos.isTurning) then
    worldPos.rot = worldPos.rot + (worldPos.drot * tstep / 4)
  elseif (worldPos.animSteps > 0) then
    worldPos.y = worldPos.y + (tstep * worldPos.dy / 4)
    worldPos.x = worldPos.x + (tstep * worldPos.dx / 4)
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

  drawUI()
end

function drawNormal()
  local phase = idxPhase()
  if (worldPos.dx + worldPos.dy) < 0 then
    phase = 8 - phase
  end

  love.graphics.setShader( shader )
  P(phase + 1)
  if (phase - math.floor(phase)) < 0.5 then
    mesh:setTexture( texture1 )
  else
    mesh:setTexture( texture2 )
  end
  love.graphics.draw(mesh)
end

function drawRotation()
  local i = (worldPos.rot * 8) % 8

  if (idxPhase() < 4) then
    P(1)
  else
    P(5)
  end

  local drawMesh = flipmesh
  if (i < 4) then drawMesh = mesh end

  if (i < 1) then
    drawMesh:setTexture(texture1)
  elseif (i < 2) then
    drawMesh:setTexture(rot1)
  elseif (i < 3) then
    drawMesh:setTexture(rot2)
  elseif (i < 4) then
    drawMesh:setTexture(rot3)
  elseif (i < 5) then
    drawMesh:setTexture(rot4)
  elseif (i < 6) then
    drawMesh:setTexture(rot3)
  elseif (i < 7) then
    drawMesh:setTexture(rot2)
  else
    drawMesh:setTexture(rot1)
  end
  love.graphics.setShader( shader )
  love.graphics.draw(drawMesh)
end

function drawSky()
  love.graphics.setShader( )
  love.graphics.setColor(120,120,255, 255)
  love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)
end

function drawUI()
  love.graphics.setShader()
  love.graphics.setColor(255,255,255, 255)

  local r = screenWidth
  local h = (2 * screenHeight) / 3
  local t = screenHeight / 3
  local x, y = love.mouse.getPosition()
  x = x / r
  y = math.max(0, (y - t) / h)

  leftStr( "rot <"..(worldPos.rot)..">", 10, 10, 1)
  leftStr( "spd <"..(math.floor(worldPos.speed))..">", 10, 30, 1)

  rightStr( " x y  ["..(math.floor(worldPos.x))..".."..(math.floor(worldPos.y)).."]", screenWidth - 10, 10, 1)
  rightStr( "dx dy ["..(math.floor(worldPos.dx))..".."..(math.floor(worldPos.dy)).."]", screenWidth - 10, 40, 1)
  rightStr( "mouse ["..(math.floor(x * 2000)/1000)..".."..(math.floor(y * 1450)/1000).."]", screenWidth - 10, 70, 1)

  centreStr( "(get blue spheres)", screenWidth / 2, screenHeight / 2, 2)
  centreStr( "left and right to turn", screenWidth / 2, screenHeight - 60, 1)
  centreStr( "up and down to change speed", screenWidth / 2, screenHeight - 40, 1)
end

function leftStr(str, x, y, scale)
  love.graphics.print(str, math.floor(x), math.floor(y), 0, scale)
end
function rightStr(str, x, y, scale)
  scale = scale or 1
  local w = scale * font:getWidth(str)
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end
function centreStr(str, x, y, scale)
  scale = scale or 1
  local w = scale * font:getWidth(str) / 2
  love.graphics.print(str, math.floor(x - w), math.floor(y), 0, scale)
end
