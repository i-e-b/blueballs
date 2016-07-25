local screenWidth, screenHeight

function love.load()
  love.window.fullscreen = (love.system.getOS() == "Android")
  screenWidth, screenHeight = love.graphics.getDimensions( )


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
local X ={ 0,0,0,0 }
function setPal1 () shader:sendColor( "palette", A, A, A, A, B, B, B, B, X) end
function setPal2 () shader:sendColor( "palette", B, A, A, A, A, B, B, B, X) end
function setPal3 () shader:sendColor( "palette", B, B, A, A, A, A, B, B, X) end
function setPal4 () shader:sendColor( "palette", B, B, B, A, A, A, A, B, X) end
function setPal5 () shader:sendColor( "palette", B, B, B, B, A, A, A, A, X) end
function setPal6 () shader:sendColor( "palette", A, B, B, B, B, A, A, A, X) end
function setPal7 () shader:sendColor( "palette", A, A, B, B, B, B, A, A, X) end
function setPal8 () shader:sendColor( "palette", A, A, A, B, B, B, B, A, X) end

local i = 0
function love.update(dt)
  if (dt > 0.4) then return end
  i = i + (dt * 4)
  if (i > 8) then i = i - 8 end
end

function love.draw()
  -- Draw sky
  love.graphics.setShader( )
  love.graphics.setColor(120,120,255, 255)
  love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight)

  -- Draw ball background
  love.graphics.setShader( shader )
  -- Move forward animation
--[[
  if (i - math.floor(i)) < 0.5 then
    mesh:setTexture( texture1 )
  else
    mesh:setTexture( texture2 )
  end
  if (i < 1) then
    setPal1()
  elseif (i < 2) then
    setPal2()
  elseif (i < 3) then
    setPal3()
  elseif (i < 4) then
    setPal4()
  elseif (i < 5) then
    setPal5()
  elseif (i < 6) then
    setPal6()
  elseif (i < 7) then
    setPal7()
  elseif (i < 8) then
    setPal8()
  end
  love.graphics.draw(mesh)
  ]]

  -- rotate animation
  local drawMesh = mesh
  setPal1()
  if (i < 1) then
    drawMesh:setTexture(rot1)
  elseif (i < 2) then
    drawMesh:setTexture(rot2)
  elseif (i < 3) then
    drawMesh:setTexture(rot3)
  elseif (i < 4) then
    drawMesh:setTexture(rot4)
  elseif (i < 5) then
    drawMesh = flipmesh
    drawMesh:setTexture(rot3)
  elseif (i < 6) then
    drawMesh = flipmesh
    drawMesh:setTexture(rot2)
  elseif (i < 7) then
    drawMesh = flipmesh
    drawMesh:setTexture(rot1)
  elseif (i < 8) then
    drawMesh = flipmesh
    setPal4()
    drawMesh:setTexture(texture1)
  end
  love.graphics.draw(drawMesh)


  love.graphics.setShader( )
  love.graphics.setColor(0,0,0, 255)
  love.graphics.print( "index: "..math.floor(i), 10, 10)
end
