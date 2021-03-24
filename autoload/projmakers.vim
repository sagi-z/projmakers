

function! projmakers#args(rt_args, defaults) abort
    if empty(a:rt_args)
        if empty(a:defaults)
            return ""
        else
            return a:defaults
        endif
    else
        return a:rt_args
    endif
endfunction

function! projmakers#complete(ArgLead, CmdLine, CursorPos) abort
    let cmd = split(a:CmdLine, ' ')[0]
    if ! has_key(b:projmakers_complete, cmd)
        let cmd = filter(keys(b:projmakers_complete), 'stridx(v:val, "' . cmd . '") == 0')[0]
    endif
    let args = b:projmakers_complete[cmd]
    if type(args) == v:t_string
        return args
    elseif type(args) == v:t_list
        return join(args, "\n")
    else
        return ""
    endif
endfunction

