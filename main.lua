local screenWidth, screenHeight
local font

-- our place in the world:
local worldPos = {rot = 0,  -- out of 32
                  drot = 0, -- rotate direction
                  srot = 0, --    and steps remaining
                  dx = 0,   -- walking direction
                  dy = 1,
                  x = 0,    -- absolute position. each tile is 4 steps
                  y = 0}

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
  local tstep = dt * 7
  local limit = 8

  -- try turning
  local canTurn = (math.floor(worldPos.x) + math.floor(worldPos.y)) % 4 == 0
  if (worldPos.srot > 0) then canTurn = false end
  if (canTurn) and (love.keyboard.isDown("left")) then
    worldPos.drot = -1
    worldPos.srot = 1
  elseif (canTurn) and (love.keyboard.isDown("right")) then
    worldPos.drot = 1
    worldPos.srot = 1
  end

  -- TODO: jump and switch forward

  -- do position updates
  worldPos.srot = math.max(0, worldPos.srot - (tstep))
  if (worldPos.srot > 0) then
    worldPos.rot = worldPos.rot + (worldPos.drot * tstep)
    if (worldPos.rot > 31) then worldPos.rot = worldPos.rot - 32 end
    if (worldPos.rot < 0) then worldPos.rot = worldPos.rot + 32 end
    rotToDxDy()
  elseif (love.keyboard.isDown("up")) then
    worldPos.rot = math.floor(worldPos.rot) --+0.499)
    rotToDxDy()
    worldPos.y = worldPos.y + (tstep * worldPos.dy)
    worldPos.x = worldPos.x + (tstep * worldPos.dx)
  end
end

function rotToDxDy()
  local qrot = worldPos.rot -- 4  -- shifted an eighth turn
  if (qrot < 8) then
    worldPos.dx = 0
    worldPos.dy = 1
  elseif (qrot < 16) then
    worldPos.dx = 1
    worldPos.dy = 0
  elseif (qrot < 24) then
    worldPos.dx = 0
    worldPos.dy = -1
  else
    worldPos.dx = -1
    worldPos.dy = 0
  end
end

function love.draw()
  drawSky()

  if (math.floor(worldPos.rot) % 8 == 0) then
    drawNormal()
  else
    drawRotation()
  end

  drawUI()
end

function idxPhase()
  local rph = (math.floor(worldPos.rot / 8) % 2) * 4
  local xph = (worldPos.x * worldPos.dx) % 8
  local yph = (worldPos.y * worldPos.dy) % 8

  return (rph + xph + yph) % 8
end

function drawNormal()
  local phase = idxPhase()

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
  local i = (worldPos.rot % 8)

  -- we must be on a tile boundary, or things will look wrong
  local pA = 5
  local pB = 1

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

  leftStr( "rot <"..((worldPos.rot))..">", 10, 10, 1)
  leftStr( "phz <"..(idxPhase())..">", 10, 30, 1)

  rightStr( "x y ["..(math.floor(worldPos.x))..".."..(math.floor(worldPos.y)).."]", screenWidth - 10, 10, 1)
  rightStr( "dx dy ["..(math.floor(worldPos.dx))..".."..(math.floor(worldPos.dy)).."]", screenWidth - 10, 30, 1)
--  centreStr( "(get blue spheres)", screenWidth / 2, screenHeight / 2, 2)

--  leftStr("phase "..(idxPhase()), 10, 40, 1)
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
