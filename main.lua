local screenWidth, screenHeight
local font

-- our place in the world:
local worldPos = {rot = 0,  -- out of 28
                  drot = 0, -- rotate direction
                  srot = 0, --    and steps remaining
                  dx = 0,   -- vector version of our rotation
                  dy = 0,
                  x = 0,    -- absolute position. each tile is 4 steps
                  y = 0}

function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")
  screenWidth, screenHeight = love.graphics.getDimensions( )

  font = love.graphics.newImageFont("font.png", "0123456789<>[]abcdefghijklmnopqrstuvwxyz() .")
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
    worldPos.srot = 7
  elseif (canTurn) and (love.keyboard.isDown("right")) then
    worldPos.drot = 1
    worldPos.srot = 7
  end

  -- TODO: jump and switch forward

  -- do position updates
  if (worldPos.srot > 0) then
    worldPos.rot = worldPos.rot + (worldPos.drot * tstep)
    worldPos.srot = worldPos.srot - (tstep)
    if (worldPos.rot > 28) then worldPos.rot = worldPos.rot - 28 end
    if (worldPos.rot < 1) then worldPos.rot = worldPos.rot + 28 end
  else
    worldPos.y = worldPos.y + tstep
    if (worldPos.y > limit) then -- TODO: change this to wrap the level limits
      worldPos.y = worldPos.y - limit
    end
  end
end

function love.draw()
  drawSky()

  if (worldPos.srot > 0) then
    drawRotation()
  else
    drawNormal()
  end

  drawUI()
end

function idxPhase()
  local rp = math.floor((7 - worldPos.rot) * 0.571)
  return 1 + (((worldPos.x + worldPos.y + rp)) % 8)
end

function drawNormal()
  local phase = idxPhase()

  love.graphics.setShader( shader )
  P(phase)
  if (phase - math.floor(phase)) < 0.5 then
    mesh:setTexture( texture1 )
  else
    mesh:setTexture( texture2 )
  end
  love.graphics.draw(mesh)
end

function drawRotation()
  -- we must be on a tile boundary, or things will look wrong
  if idxPhase() > 5 then P(1) else P(5) end

  local i = 7 - worldPos.srot

  local drawMesh = flipmesh
  if (i > 4) then drawMesh = mesh end
  if (i < 1) then
    drawMesh:setTexture(rot1)
  elseif (i < 2) then
    drawMesh:setTexture(rot2)
  elseif (i < 3) then
    drawMesh:setTexture(rot3)
  elseif (i < 4) then
    drawMesh:setTexture(rot4)
  elseif (i < 5) then
    drawMesh:setTexture(rot3)
  elseif (i < 6) then
    drawMesh:setTexture(rot2)
  elseif (i < 7) then
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

  leftStr( "rot <"..(math.floor(worldPos.rot))..">", 10, 10, 1)
  rightStr( "srot ["..(math.floor(worldPos.srot)).."]", screenWidth - 10, 10, 1)
  centreStr( "(get blue spheres)", screenWidth / 2, screenHeight / 2, 2)

  leftStr("phase "..(idxPhase()), 10, 40, 1)
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
