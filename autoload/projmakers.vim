
function! projmakers#warn(msg)
    echohl WarningMsg | echom "projmakers: " . a:msg | echohl None
endfunction

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


function! s:shift(str, opt)
    let l:opt_str = ""
    function! s:ShiftSub(m) closure
        let l:opt_str = a:m[1]
        return ""
    endfunction
    let l:res_str = substitute(a:str, "<\s*" . a:opt . ":\\\(\[^>\]*\\\)>", funcref("s:ShiftSub"), "")
    return [l:res_str, l:opt_str]
endfunction

" Note that it is expected from an asynchronous ':Make' to capture the
" 'errorformat' when it starts and use it later on. Here we'll set
" it before invoking ':Make' and revert it back immediately.
function! projmakers#make(name, args) abort
    let l:efm = &l:efm
    let l:makeprg = &l:makeprg
    let l:compiler = get(b:, 'current_compiler', '')
    try
        let opts = b:projmakers_opts[a:name]
        if ! has_key(opts, "makeprg")
            return projmakers#warn("Got opts without a makeprg for " . a:name)
        endif
        if has_key(opts, "compiler")
            exe ":compiler " . opts.compiler
        endif
        let &l:makeprg = opts.makeprg
        if has_key(opts, "errorformat")
            let &l:efm = opts.errorformat
        endif
        if has_key(opts, "projmakers_runner") && ! get(g:, 'projmakers#force_make_runner', 0)
            let l:Runner = opts.projmakers_runner
            call l:Runner(opts)
        else
            if exists(":Make")
                let l:maker = 'Make'
            else
                let l:maker = 'make'
            endif
            exe ":" . l:maker . ' ' . a:args
        endif
    finally
        if ! empty(l:compiler)
            exe ":compiler " . l:compiler
        endif
        let &l:efm = l:efm
        let &l:makeprg = l:makeprg
    endtry
endfunction


function! projmakers#complete(ArgLead, CmdLine, CursorPos) abort
    let cmd = split(a:CmdLine, ' ')[0]
    if ! has_key(b:projmakers_complete, cmd)
        let cmd = filter(keys(b:projmakers_complete), 'stridx(v:val, "' . cmd . '") == 0')[0]
    endif
    return b:projmakers_complete[cmd]
endfunction


function! s:WS2CR(str) abort
    return substitute(a:str, "\\s\\+", "\n", "g")
endfunction


function! s:OverrideOpt(str, opt, opts, key) abort
    let [l:ret, l:item] = s:shift(a:str, a:opt)
    if ! has_key(a:opts, a:key) && ! empty(l:item)
        let a:opts[a:key] = l:item
    endif
    return l:ret
endfunction


" Implementations use this to add a command for the current buffer.
" a:opts MUST have:
" * makeprg
"   + makeprg can have <defaults: ...> <vim_cmd_args: ...> <complete: ...>
" * name
" a:opts can also have:
" * args (default args, which can be overridden during usage - same as <defaults: ...> above)
" * complete (to offer options to user during usage - same as <complete: ...> above))
" * vim_cmd_args (to set -nargs or a -complete - same as <vim_cmd_args: ...> above))
" * compiler
" * errorformat
" * projmakers_runner (a function reference to get the opts and execute the command)
function! projmakers#new_command(opts) abort
    if ! has_key(a:opts, "makeprg")
        return projmakers#warn("Got opts without a makeprg: " . string(a:opts))
    endif
    if ! has_key(a:opts, "name")
        return projmakers#warn("Got opts without a name: " . string(a:opts))
    endif
    if has_key(a:opts, "makeprg")
        let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "default\[s\]*", a:opts, "args")
        let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "vim_cmd_arg\[s\]*", a:opts, "vim_cmd_args")
        let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "complete", a:opts, "complete")
    endif
    if has_key(a:opts, "args")
        let l:defaults = '"' . a:opts.args . '"'
    else
        let l:defaults = '""'
    endif
    let l:complete = ""
    let b:projmakers_complete = get(b:, "projmakers_complete" ,{})
    if has_key(a:opts, "vim_cmd_args")
        let l:complete = a:opts.vim_cmd_args
    endif
    if has_key(a:opts, "complete")
        let l:complete_items = a:opts.complete
        if type(l:complete_items) == v:t_string
            let b:projmakers_complete[a:opts.name] = s:WS2CR(l:complete_items)
        elseif type(l:complete_items) == v:t_list
            let b:projmakers_complete[a:opts.name] = join(l:complete_items, "\n")
        else
            let b:projmakers_complete[a:opts.name] = ""
        endif
        let l:complete .= " -complete=custom,projmakers#complete"
    endif
    let b:projmakers_opts = get(b:, "projmakers_opts" ,{})
    let b:projmakers_opts[a:opts.name] = a:opts
    exe "command! -buffer -nargs=* " . l:complete . " " . a:opts.name . " call projmakers#make('" . a:opts.name . "', projmakers#args(<q-args>, " . l:defaults . "))"
endfunction


function! s:CleanupBuffer() abort
    if exists("b:projmakers_opts")
        for l:cmd in keys(b:projmakers_opts)
            try
                exe "delcommand " . l:cmd
            catch
            endtry
        endfor
        unlet b:projmakers_opts
    endif
    if exists("b:projmakers_complete")
        unlet b:projmakers_complete
    endif
endfunction


augroup projmakers
    autocmd BufUnload * call s:CleanupBuffer()
augroup end
