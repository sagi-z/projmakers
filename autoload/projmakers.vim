

" PUBLIC: you can use this to expand this plugin
" Description:
"   echom with warning highlights
function! projmakers#warn(msg)
    echohl WarningMsg | echom "projmakers: " . a:msg | echohl None
endfunction


" PUBLIC: you can use this to expand this plugin
" Description:
"   Remove the first <a:opt: .*> option from a:str
" Params:
"   str (string): For example - '$(VIM_ROOT)/test.sh <default: --all --short -- -v> <vim_cmd_args: -nargs=*>'
"   opt (pattern): For example - 'default\[s\]*'
" Returns:
"   List of [strWithoutOptStr, matchedOptName, matchedOptValue]
function! projmakers#shift(str, opt)
    let l:opt_key = ""
    let l:opt_val = ""
    function! s:ShiftSub(m) closure
        let l:opt_key = trim(a:m[1])
        let l:opt_val = trim(a:m[2])
        return ""
    endfunction
    let l:res_str = substitute(a:str, "<\s*\\\(" . a:opt . "\\\):\\\(\[^>\]*\\\)>", funcref("s:ShiftSub"), "")
    return [trim(l:res_str), l:opt_key, l:opt_val]
endfunction


" PUBLIC: you can use this to expand this plugin
" Description:
"   Removes all the <\w\+: .*> options from a:str
" Params:
"   str (string): For example - '$(VIM_ROOT)/test.sh <default: --all --short -- -v> <vim_cmd_args: -nargs=*>'
" Returns:
"   List of [strWithoutOptionsStr, {opt: key, opt: key, ...}], as in ['$(VIM_ROOT)/test.sh', {'default': '--all --short -- -v', 'vim_cmd_args': '-nargs=*'}]
function! projmakers#shift_all(str)
    let l:opts = {}
    let l:str = a:str
    while 1
        let [l:str, l:opt_key, l:opt_val] = projmakers#shift(l:str, '\w\+')
        if ! empty(l:opt_key)
            let l:opts[l:opt_key] = l:opt_val
        else
            return [l:str, l:opts]
        endif
    endwhile
endfunction


" PUBLIC: you can use this to expand this plugin
" Description:
"   Returns the args given on the vim command prompt, or configured defaults if none where given
" Params:
"   cmd (string): the name of the vim command
" Returns:
"   string - the args given on the vim command prompt, or configured defaults if none where given
function! projmakers#args(cmd) abort
    let l:projmakers_args = get(b:, "projmakers_args", "")
    return l:projmakers_args
endfunction


" PUBLIC: you can use this to expand this plugin
" Description:
"   Create a command for the local buffer.
"   Implementations should use this to add a command for the current buffer.
" Params:
"   a:opts(Dictionary) :
"     * This dictionary MUST have :
"         * makeprg (this line will be executed)
"           * makeprg can have options embedded for sources which cannot specify arbitrary attributes:
"               <defaults: ...>      used if no args are supplied      (i.e. <defaults: --all -- -v>)
"               <vim_cmd_args: ...>  to use when creating the command  (i.e. <vim_cmd_args: -nargs=* -complete=file>)
"               <complete: ...>      for simple completion from a list (i.e. <complete: --all --allow-fail --report>)
"               <compiler: name>     for specifying a :compiler to use (i.e. <compiler: gcc>)
"         * name (the name of the command to create)
"     * a:opts can also have:
"         * args (deprecated - same as <defaults: ...> above)
"         * complete (deprecated - same as <complete: ...> above))
"         * vim_cmd_args (deprecated - same as <vim_cmd_args: ...> above))
"         * compiler
"         * errorformat
"         * projmakers_runner (a function reference which get the a:opts and executes the command)
function! projmakers#new_command(opts) abort
    if ! has_key(a:opts, "makeprg")
        return projmakers#warn("Got opts without a makeprg: " . string(a:opts))
    endif
    if ! has_key(a:opts, "name")
        return projmakers#warn("Got opts without a name: " . string(a:opts))
    endif
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "default\[s\]*", a:opts, "args")
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "vim_cmd_arg\[s\]*", a:opts, "vim_cmd_args")
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "complete", a:opts, "complete")
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "compiler", a:opts, "compiler")
    if has_key(a:opts, "args")
        let l:defaults = '"' . a:opts.args . '"'
    else
        let a:opts.args = ""
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
        let l:complete .= " -complete=custom,projmakers#_complete"
    endif
    let b:projmakers_opts = get(b:, "projmakers_opts" ,{})
    let b:projmakers_opts[a:opts.name] = a:opts
    exe "command! -buffer -nargs=* " . l:complete . " " . a:opts.name . " call projmakers#_make('" . a:opts.name . "', projmakers#_args(<q-args>, " . l:defaults . "))"
endfunction


function! s:OverrideOpt(str, opt, opts, key) abort
    let [l:ret, l:item_key, l:item_val] = projmakers#shift(a:str, a:opt)
    if ! has_key(a:opts, a:key) && ! empty(l:item_val)
        let a:opts[a:key] = l:item_val
    endif
    return l:ret
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


" PRIVATE: this can change without a warning
" Description:
"   Return command args if given, else the defaults
" Params:
"   rt_args (string): the args given to the command on the vim command prompt
"   defaults (string): the defaults to use if a:rt_args is empty
" Returns:
"   string of command args if given, else the defaults
function! projmakers#_args(rt_args, defaults) abort
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


" PRIVATE: this can change without a warning
" Note: it is expected from an asynchronous ':Make' to capture the
" 'errorformat' when it starts and use it later on. Here we'll set
" it before invoking ':Make' and revert it back immediately.
function! projmakers#_make(name, args) abort
    let l:win_id = win_getid()
    let b:projmakers_args = a:args
    let l:efm = &l:efm
    let l:makeprg = &l:makeprg
    let l:compiler = get(b:, 'current_compiler', '')
    try
        let opts = b:projmakers_opts[a:name]
        if ! has_key(opts, "makeprg")
            return projmakers#warn("Got opts without a makeprg for " . a:name)
        endif
        if has_key(opts, "errorformat")
            let &l:efm = opts.errorformat
        endif
        if has_key(opts, "compiler")
            exe ":compiler " . opts.compiler
        endif
        let &l:makeprg = opts.makeprg
        if has_key(opts, "projmakers_runner") && ! get(g:, 'projmakers#force_make_runner', 0)
            let l:Runner = opts.projmakers_runner
            call l:Runner(opts, a:args)
        else
            if exists(":Make")
                let l:maker = 'Make'
            else
                let l:maker = 'make'
            endif
            exe ":" . l:maker . ' ' . a:args
        endif
    finally
        call win_gotoid(l:win_id)
        if ! empty(l:compiler)
            exe ":compiler " . l:compiler
        endif
        let &l:efm = l:efm
        let &l:makeprg = l:makeprg
        unlet b:projmakers_args
    endtry
endfunction


" PRIVATE: this can change without a warning
" Description:
"   An internal function used for command completions.
function! projmakers#_complete(ArgLead, CmdLine, CursorPos) abort
    let cmd = split(a:CmdLine, ' ')[0]
    if ! has_key(b:projmakers_complete, cmd)
        let cmd = filter(keys(b:projmakers_complete), 'stridx(v:val, "' . cmd . '") == 0')[0]
    endif
    return b:projmakers_complete[cmd]
endfunction


function! s:WS2CR(str) abort
    return substitute(a:str, "\\s\\+", "\n", "g")
endfunction


augroup projmakers
    autocmd BufUnload * call s:CleanupBuffer()
augroup end
