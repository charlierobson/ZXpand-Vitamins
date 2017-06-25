@echo off
setlocal

set IN=%1
set OUT=%~n1.zxm

if exist "%OUT%" del "%OUT%"

midicsv "%IN%" >temp.txt
midimash temp.txt

del temp.txt
ren temp.zxm "%OUT%"
