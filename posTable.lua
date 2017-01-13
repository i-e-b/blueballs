-- to scale the positions to 0..1
-- all the screen coords must be scaled by factors:
--  (x / 320), (y / 195)

return {
  rot = { -- the eight rotation positions
    { --[1] {dx, dy, texture x, texture y, size}, where dx,dy is measured from grid coords
      {0,0,160,135,"1"},{-1,0,253,122,"1"},{1,0,56,155,"1"},
      {1,1,64,85,"A"},{0,1,145, 72,"A"},{-1,1,219, 65,"A"},{-2,1,284,63,"A"},
      {0,2,135,36,"B"},{1,2,70,46,"B"},{2,2,5,62,"B"},{-1,2,197,32,"B"},{-2,2,251,33,"B"},{-3,2,299,38,"B"},
      {0,3,129,17,"C"},{1,3,76,25,"C"},{2,3,23,37,"C"},{-1,3,180,14,"C"},{-2,3,228,16,"C"},{-3,3,272,21,"C"},{-4,3,308,30,"C"},
      {0,4,126,7,"D"},{1,4,81,13,"D"},{2,4,36,23,"D"},{-1,4,170,5,"D"},{-2,4,209,6,"D"},{-3,4,247,11,"D"},
      {0,5,124,3,"E"},{1,5,83,9,"E"},{2,5,45,17,"E"},{3,5,11,29,"E"},{-1,5,164,2,"E"},{-2,5,200,3,"E"},{-3,5,246,11,"E"}
    },
    {
      {0,0,160,135,"1"}
    },
    {
      {0,0,160,135,"1"}
    },
    {
      {0,0,160,135,"1"}
    },
    {
      {0,0,160,135,"1"}
    },
    {
      {0,0,160,135,"1"}
    },
    {
      {0,0,160,135,"1"}
    },
    {
      {0,0,160,135,"1"}
    }
  },

  mov = { -- eight movement steps TODO: interpolate out to 8
{ --[1] {dx, dy, texture x, texture y, size}, where dx,dy is measured from grid coords
{0,0,160,146,"1"},{0,1,160, 76,"3"},{0,2,160, 38,"5"},{0,3,160, 16,"9"},{0,4,160,  6,"B"},{0,5,160,  1,"C"},
{1,0, 57,148,"1"},{1,1, 80, 79,"3"},{1,2, 96, 40,"5"},{1,3,106, 19,"9"},{1,4,115,  8,"B"},{1,5,121,  3,"C"},
                  {2,1,  4, 87,"3"},{2,2, 34, 48,"6"},{2,3, 56, 25,"9"},{2,4, 72, 13,"B"},{2,5, 83,  8,"D"},
                                                      {3,3,  8, 36,"B"},{3,4, 28, 24,"C"},{3,5, 47, 16,"D"},
                                                                        {4,4,  2, 32,"D"},{4,5, 19, 25,"D"}
},
{ --[2]
{0,0,160,171,"0"},{0,1,160, 90,"2"},{0,2,160, 45,"4"},{0,3,160, 21,"8"},{0,4,160,  8,"A"},{0,5,160,  2,"B"},
{1,0, 49,173,"0"},{1,1, 75, 92,"2"},{1,2, 92, 48,"4"},{1,3,104, 23,"8"},{1,4,113, 10,"A"},{1,5,119,  4,"B"},
                                    {2,2, 28, 55,"5"},{2,3, 51, 30,"8"},{2,4, 68, 16,"A"},{2,5, 79,  9,"C"},
                                                      {3,3,  1, 41,"A"},{3,4, 25, 26,"B"},{3,5, 45, 17,"C"},
                                                                                          {4,5, 15, 27,"D"}
},
{ --[3]
{0,1,160,106,"2"},{0,2,160, 54,"4"},{0,3,160, 25,"7"},{0,4,160, 10,"A"},{0,5,160,  3,"B"},
{1,1, 70,108,"2"},{1,2, 89, 57,"4"},{1,3,102, 28,"7"},{1,4,111, 12,"A"},{1,5,117,  5,"B"},
                  {2,2, 20, 65,"5"},{2,3, 46, 35,"8"},{2,4, 63, 19,"A"},{2,5, 77, 10,"C"},
                                                      {3,4, 22, 28,"B"},{3,5, 40, 19,"C"},
                                                                        {4,5, 10, 29,"D"}
},
{ --[4]
{0,1,160,124,"1"},{0,2,160, 64,"3"},{0,3,160, 31,"6"},{0,4,160, 13,"9"},{0,5,160,  4,"B"},
{1,1, 64,126,"1"},{1,2, 85, 67,"3"},{1,3, 99, 33,"6"},{1,4,110, 15,"9"},{1,5,116,  6,"B"},
                  {2,2, 13, 75,"4"},{2,3, 41, 41,"7"},{2,4, 59, 22,"9"},{2,5, 75, 11,"C"},
                                                      {3,4, 14, 32,"A"},{3,5, 34, 21,"C"},
                                                                        {4,5,  6, 31,"D"}
}
  }
}
