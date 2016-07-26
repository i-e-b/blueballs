##What?

A little test game for GLSL palette index animations
Note that 'round' doesn't work on my phone, so there is some funky casting.

## Notes

Each forward movement 'square' is 4 frames out of an 8 frame cycle.
A turn is 7 frames, with 3 of those horizontally mirrored.
After a rotate, the palette has to start a half cycle forward, and to
re-sync, you have to move a square forward after a turn (so you can't
do a 180).
Regular jumps move exactly a square forwards. You must release and
re-time jumps to get another. Balls have a 0.25 square radius.

## Todo:
add a position/rotation counter and calculate the texture and palette from that
