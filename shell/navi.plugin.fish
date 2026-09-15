function _navi_smart_replace
    set --local buffer (commandline --current-buffer | string collect)
    set --local process (commandline --current-process | string collect)
    # --current-process hands back the whitespace separating the command from a
    # preceding pipe or operator, so keep it to splice it back in afterwards
    set --local indent (string match --regex '^\s*' -- "$process")
    set --local query (string trim -- "$process")

    # A second press on a result we spliced and the user hasn't edited means the
    # best match was wrong, so fall through to the picker seeded with the query
    # that produced it. Mirrors the $LASTWIDGET check in the zsh widget.
    set --local repeat false
    if test -n "$_navi_last_buffer"; and test "$buffer" = "$_navi_last_buffer"
        set repeat true
        set query $_navi_last_query
    end

    set --local major (string match --regex '^\d+' -- "$FISH_VERSION")
    set --local force_repaint false
    # https://github.com/fish-shell/fish-shell/blob/d663f553dffba460d6d0bcdf93df21bda9ec6f3f/doc_src/interactive.rst?plain=1#L440
    #  > Bindings that change the mode are supposed to call the repaint-mode bind function
    #
    # Related issues
    #  - https://github.com/fish-shell/fish-shell/issues/5033
    #  - https://github.com/fish-shell/fish-shell/issues/5860
    #  - https://github.com/fish-shell/fish-shell/blob/d663f553dffba460d6d0bcdf93df21bda9ec6f3f/src/screen.rs#L531
    #
    # Introduced with: https://github.com/denisidoro/navi/pull/982
    if test -n "$major"; and test "$major" -ge 4
        set force_repaint true
    end

    # `string collect` keeps a multi-line snippet as a single value; without it
    # command substitution splits it per line and expansion flattens those lines
    # back into one
    set --local snippet ""
    if test -z "$query"
        set snippet (navi --print | string collect)
    else if test "$repeat" = true
        set snippet (navi --print --query "$query" | string collect)
    else
        set snippet (navi --print --query "$query" --best-match | string collect)
        if test -z "$snippet"
            set snippet (navi --print --query "$query" | string collect)
        end
    end

    if test -n "$snippet"
        # --current-process so that anything before the command under the
        # cursor, e.g. the left-hand side of a pipe, survives the replacement
        commandline --current-process --replace -- "$indent$snippet"
        commandline --function end-of-line
        set --global _navi_last_buffer (commandline --current-buffer | string collect)
        set --global _navi_last_query "$query"
    end

    # always repaint to restore the prompt after fzf clobbers the terminal
    if test "$force_repaint" = true
        commandline --function repaint
    end
end

if status is-interactive
    bind \cg _navi_smart_replace
    bind --mode insert \cg _navi_smart_replace
end
