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

the background image scrolls up as you move forward, down as you
move backwards, and horizontally as you turn (in the same visual
direction: turning left scrolls the background right)

## Todo:

* interpolated ball positions for non rotation
* rings spin animation
* level end animation/ win screen : balls burst off the stage (multiply distance from 0,0 position?)
* level transition and the rest of the levels
* gamepad controls, difficulty setting
* phone touch controls
* failure (hard mode) : the stage spins as it fades to white
