function fish_greeting
    set -l TODAY (date -d '-6 hours' +%y%m%d)

    # Set todays emoji if it hasn't been set yet.
    if test -z "$EMOJI"
        set_random_symbol $TODAY
    else if test "$EMOJI_DATE" != "$TODAY"
        set_random_symbol $TODAY
    end
end
