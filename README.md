# Schlieffen
A turn-based strategy game demo developed with Godot, simulating asymmetric warfare with hidden information mechanics.

This project is developed using the Godot 4.3 engine. If you want to view the source code, the complete game script is stored here for reference. Please use the corresponding version of the Godot engine to complete the testing

The detailed rules of the game are as follows:

# Game Rules – Schlieffen
## Overview:
Schlieffen is a turn-based, two-player strategy board game set during World War I. The game is a non-perfect information game, meaning that players can only see their own units, the blocks they control, and blocks controlled by the opponent. The exact location of enemy units remains hidden.

## Game Structure:
The game consists of five rounds, and each round includes the following four sequential phases:

### Activation Phase

Each player may activate a limited number of their own pawns (units), according to the rule defined in constants.gd (variable ROUND).
If the number of available inactive pawns is greater than or equal to the required activation count, the player must activate that number of pawns.
If the number of available pawns is less than the required count, the player can activate all remaining pawns.

### Movement Phase

Activated pawns may move to adjacent tiles that are either neutral or controlled by the same faction.
If pawns from both sides move to the same neutral tile, it remains neutral, and neither side gains control.

### Attack Phase – Allies Attack First, followed by Germans

Only activated and unmoved pawns can initiate attacks.
Attacks can target adjacent tiles.
The outcome is decided by comparing the number of attackers to the number of active defenders:
If the attackers outnumber the defenders, the tile is conquered, and enemy pawns may be eliminated.
Otherwise, the attack fails, and some attacking pawns may become inactive.

## Scoring System:

+1 point for killing an enemy pawn.
+1 point for successfully occupying a new tile.
-1 point for losing a pawn.
-1 point for losing a tile.

## Special Victory Condition:

If Germany occupies the Paris tile, it achieves instant victory, regardless of the current round or score.



Contact the author: ym2013@hw.ac.uk Or ym21020036050@gmail.com
