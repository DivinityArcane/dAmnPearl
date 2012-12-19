@ECHO off

CLS
ECHO Checking if Perl is installed...
IF EXIST C:\Perl\bin\perl.exe (
    ECHO Perl exists!
    GOTO start
) ELSE (
    IF EXIST C:\Perl64\bin\perl.exe (
        ECHO Perl exists!
        GOTO start
    ) ELSE ( 
        GOTO noperl
    )
)
:noperl
ECHO Perl is  not installed.
ECHO Please install it from here: http://www.activestate.com/activeperl/downloads
GOTO end
:start
ECHO Attempting to run the bot!
ECHO.
CALL perl bot.pl

ECHO.
ECHO Bot has shut down.
IF EXIST restart (
    ECHO Restarting...
    DEL restart
    GOTO start
)
:ask
SET /P INPUT=Run again? [y/n]: 
IF %INPUT%==y (
    ECHO Right, one second please...
    CLS
    GOTO start
) ELSE IF %INPUT%==n (
    ECHO Ok, later!
    GOTO end
) ELSE (
    ECHO Sorry, you must answer with y or n.
    GOTO ask
)
:end
PAUSE
