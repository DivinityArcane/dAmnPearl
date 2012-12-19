@ECHO off
CLS
ECHO Installing deps...

CALL perl -MCPAN -e "install Crypt::SSLeay"

ECHO Done!
PAUSE
