@set EO_SD=C:\Users\Developer\Desktop\retro\EightyOneV1.8\ZXpand_SD_Card

set src=_-_eq.asm
set dest=eq.p

brass %src% %dest% -s -l listing.html

@copy %dest% %EO_SD%\menu.p
@copy %dest%.sym %EO_SD%\menu.p.sym
