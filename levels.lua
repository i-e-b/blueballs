-- Game levels.
-- Red:x, Blue:#, Gold:g, Star:*, Ring:0, Blank:" "
-- Sonic: s (rotation is 0 to 3... 0= \/  1= >  2= /\  3= <)
-- Standard levels are 32x32. Custom levels can be any size, but all rows
-- must be the same length


return {
  { -- Level [1]
    rotation = 0, ringsAvail = 64, layout = {
"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
"xxs            **             xx",
"xx             **             xx",
"xx  ####                ####  xx",
"xx  ####  ##   **   ##  ####  xx",
"xx  ####  ##   **   ##  ####  xx",
"xx  ####                ####  xx",
"xx             **             xx",
"xx             **             xx",
"xx        xxxxxxxxxxxx        xx",
"xx        xxxxxxxxxxxx        xx",
"xx  *#**  xxxxxxxxxxxx  **#*  xx",
"xx  *##*  xxxxxxxxxxxx  *##*  xx",
"xx  **#*  xxxxxxxxxxxx  *#**  xx",
"xx  *##*  xxxxxxxxxxxx  *##*  xx",
"xx  *#**  xxxxxxxxxxxx  **#*  xx",
"xx  *##*  xxxxxxxxxxxx  *##*  xx",
"xx  **#*  xxxxxxxxxxxx  *#**  xx",
"xx  **#*  xxxxxxxxxxxx  *#**  xx",
"xx        xxxxxxxxxxxx        xx",
"xx        xxxxxxxxxxxx        xx",
"xx             **             xx",
"xx             **             xx",
"xx  ####                ####  xx",
"xx  ####  ##   **   ##  ####  xx",
"xx  ####  ##   **   ##  ####  xx",
"xx  ####                ####  xx",
"xx             **             xx",
"xx             **             xx",
"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}
  },
  { -- level[2]
    rotation = 3, ringsAvail = 111, layout = {
"xxxx   xxxxxxxxxxxxxxxxxxxxxxxxx",
"xxxx   xxxxxxxxxxxxxxxx         ",
"xxxx   xxxxxxxxxxxxxxxx         ",
"xxxx   xxxx*********xxx  #####  ",
"xxx*       #### ####     #***#  ",
"xxx*       #### ####     #***#  ",
"xxx*       #### ####     #***#  ",
"xxxx***xxxx*********xxx  #####  ",
"xxxxxxxxxxxxxxxxxxxxxxx         ",
"xxxxxxxxxxxxxxxxxxxxxxx         ",
"xxxxxxxxxxxxxxxxxxxxxxxxxx   xxx",
"xxxxxxxxxxxxxxxxxxxxxxxxxx   xxx",
"xxxxxxxxxxx           xxx*   *xx",
"xxxxxxxxxxx           xxx*   *xx",
"xxxxx****xx           xxx*   ***",
"     ####     #####   xxx*      ",
"     ####     #####   xxx*      ",
"     ####     #####   xxx*      ",
"xxxxx****xx           xxx*   ***",
"xxxxxxxxxxx           xxx*   *xx",
"xxxxxxxxxxx           xxx*   *xx",
"xxxxxxxxxxxxxxx   xxxxxxx*###*xx",
"xxxxxxxxxxxxxx*###*xxxxxx*###*xx",
"x         xxxx*###*xxxxxx*###*xx",
"x         xxxx*###*xxxxxx*###*xx",
"x  #####  xxx**###**xx****   *xx",
"x  #####              ####   *xx",
"x  ##*##        s     ####   *xx",
"x  #####              ####   *xx",
"x  #####  xxxx*****xxx********xx",
"x         xxxxxxxxxxxxxxxxxxxxxx",
"x         xxxxxxxxxxxxxxxxxxxxxx"
}
  }

}
