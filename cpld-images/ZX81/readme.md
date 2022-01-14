### ZXpand cpld images

The latest 2022 image implements a fixed memory map, so there is no need to use the CONFIG "M=x" command any more.

*   0 -> 8K   ROM
*   8 -> 16K  RAM bank 0
*  16 -> 40K  RAM banks 1-3
*  40 -> 48K  RAM bank 0
*  48 -> 64K  The usual mirrors

Writing to any memory at 8->16K will be reflected in 40->48K and vice-versa.  

The keen-eyed amongst you will observe that this replaces the ROM mirror that would normally appear at 8K. This shouldn't affect any existing program but you never know. If there is some mission critical piece of code, for example running the nuclear power station, then stay on the pre-2022 cpld image.
