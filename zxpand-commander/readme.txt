--== ZXpand Commander ==--


With this program and a ZX81 computer equipped with a ZXpand interface you can:

 * Browse the content of an SD card
 * Execute programs
 * Create directories
 * View text and monochrome BMP files
 * Delete files and empty directories
 * Rename files and directories
 * Move and copy files
 * Instantly become more attractive to the
   opposite sex**


Help is always available by pressing Shift + H.

Controls are as follows:

Cursor keys              Move the selection cursor.
Shift + cursor up/down   File listing page up/down.

Enter                    Open a sub-directory or execute the highlighted program.
Shift + Enter            Open the highlighted sub-directory in the other pane.
.                        Go up a directory level.

Shift + C                Copy the highlighted file to the other pane.
Shift + M                Move the highlighted file to the other pane.
Shift + D                Delete the highlighted file or empty sub-directory.
Shift + R                Rename the highlighted file.
Shift + K                Create a sub-directory.
Shift + X                Run the highlighted program with the 'X' flag.

Shift + Space            Cancel text input.

Shift + Q                Quit.

The selection cursor may also be controlled with a joystick attached to a ZXpand-AY daughterboard. The button acts as the Enter key.

BMP viewer limitations:
 - mono (1bit)
 - no compression
 - image size max 256x192


KMurta's JOY81 programmable joystick is configured when executing a program through the commander.


The program comes with full source code. Please consider submitting any improvements or feature upgrades back to the author for inclusion in the official release.


For full functionality you should have firmware version 2.2 or above flashed to your ZXpand interface. For instructions on how to do this please consult the documentation.


Code (mostly) by:

  SirMorris, Kelly Murta, Krystian Wlosek


For submissions please contact: charlie_robson@hotmail.com
For more sinclair ZX80/81 goodness please visit: http://www.sinclairzxworld.com/



--== Change log ==--

-- V1.8:-- 

 + KMurta's programmable joystick integration - Thanks Kelly!


-- V1.7 SP1:-- 

 + Bugfixes - Thanks Kelly!
 + New font
 + Corrected version string


-- V1.7:-- 

 + Monochrome BMP viewer added by Kristian Wlosek - Thanks Kristian!
 - Removed title screen as it's not really adding anything to the workflow.


-- V1.6:-- 

 + Hires TXT file viewer added by K.Murta! Thanks Kelly!
 + Improved display update after delete/rename operations


-- V1.5:-- 

 + Better error handling


-- V1.4:-- 

 + Fast navigation using shifted cursor up/down keys


-- V1.3:-- 

 + Execution of programs needing overlay-disable ('X') flag
 + Improved help


-- V1.2:-- 

 + Deleting files works in all cases now


-- V1.1:-- 
 
 + Running programs in sub-directories works now
 + Selection cursor correctly tracks moves, deletes and renames


-- Known issues:-- 
 
 + Files larger than 16k can't be copied
 + Copying or renaming files where the target already exists will abort with an error
 + Filename buffers are unbounded - deep directory paths may overflow and cause crashes


** - This is actually a lie, sorry.
