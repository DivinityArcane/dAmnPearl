#!/bin/sh

run_bot() {
    perl bot.pl
    if [ -f restart ]
    then
        echo "Bot restarting...\n"
        rm restart
        run_bot
    else
        ask
    fi
}

ask() {
    echo "Bot has shut down. Run again? [y/n]: "
    read ans
    case $ans in
        y)
            run_bot
            ;;
        n)
            echo "Okay! Bye!\n"
            exit
            read -p "Press any key to close the window."
            ;;
        *)
            echo "Sorry, you must answer with y or n.\n"
            ask
            ;;
    esac
}

echo "Checking if Perl is installed...\n"
if perl -v >/dev/null 2>&1
then
    echo "Perl is installed!\n"
    run_bot
else
    echo "Perl isn't installed!\n"
fi
