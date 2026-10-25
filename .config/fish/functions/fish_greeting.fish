function fish_greeting
    if [ (uname) != Darwin ]
        set TODAY (date -d '-6 hours' +%y%m%d)
    else
        set TODAY (date +%y%m%d)
    end

    # Set todays emoji if it hasn't been set yet.
    if test -z "$EMOJI"
        set_random_symbol $TODAY
    else if test "$EMOJI_DATE" != "$TODAY"
        set_random_symbol $TODAY
    end
end
