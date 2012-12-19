@ECHO off
CLS
ECHO Installing deps...

CALL ppm install Crypt::SSLeay
ECHO Done!
PAUSE
