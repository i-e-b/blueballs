-- to centre the ball on 1,1
-- all the screen coords must be scaled by factors:
--  (x / 320), (y / 195)

return {
  cen = {1,1}, -- centre of rotation, character position

  rot = { -- the eight rotation positions
  -- then for each we have {grid dx, grid dy, screen x, screen y}
  -- we pick the right position, then scan the grid for matching balls to show
  -- we also pick the mirror image position, to save on table space!
  -- how to scale? a sqrt(dx^2 + dy^2) should do?
    {
{0,0, 1,1},{0,1, 1,0.52},{0,2, 1,0.25},{0,3, 1,0.11},{0,4, 1,0.036},{0,5, 1,0.003},
{1,0, 0.38,1.02},{1,1, 0.52,0.54},{1,2, 0.60, 0.27},{1,3, 0.67,0.134},{1,4, 0.725,0.47},{1,5, 0.76,0.01},
{2,1, 0.055, 0.59},{2,2, 0.235,0.32},{2,3, 0.362, 0.17},{2,4, 0.46,0.09},{2,5, 0.5, 0.058},
{3,3, 0.067,0.25},{3,4, 0.2,0.155}
    },
    {},
    {},
    {},
    {},
    {},
    {},
    {}
  },

  mov = { -- eight movement steps
    {},
    {},
    {},
    {},
    {},
    {},
    {},
    {}
  }
}
