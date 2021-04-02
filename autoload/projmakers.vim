

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
"   Reduce the command to what it is with vim command prompt args or use the configured
"   default args. This could be executed from another buffer, so get the default args by ourself
"   anyway from the cmd (for example when an asynctask which also defines a buffered command is
"   executed directly via 'AsyncTask ...'). The default args might be expressed in a way AsyncTask
"   does not recognize, and the wrapper might also need some embedded attributes from the command line.
"   However, if executed from a 'projmakers' command with <q-args>, then it is used instead.
" Params:
"   cmd (string): For example - './test.sh <default: --all --short -- -v> <vim_cmd_args: -nargs=*>'
"   name (string): the name of the command
" Returns:
"   List of [cmdStrWithArgs, {opt: key, opt: key, ...}], as in ['.test.sh --all --short -- -v', {'default': '--all --short -- -v', 'vim_cmd_args': '-nargs=*'}]
function! projmakers#eval_orig_cmd(cmd, name)
    let [l:cmd, l:opts] = projmakers#shift_all(a:cmd)
    let l:default = get(l:opts, "default", "")
    let l:cmd .= " " . projmakers#_buffered_args(a:name, l:default)
    return [l:cmd, l:opts]
endfunction


" PUBLIC: you can use this to expand this plugin
" Description:
"   Create a command for the local buffer.
"   Implementations should use this to add a command for the current buffer.
" Params:
"   opts(Dictionary) :
"     * This dictionary MUST have :
"         * makeprg (this line will be executed)
"           * makeprg can have options embedded for sources which cannot specify arbitrary attributes:
"               <default: ...>      used if no args are supplied      (i.e. <default: --all -- -v>)
"               <vim_cmd_args: ...>  to use when creating the command  (i.e. <vim_cmd_args: -nargs=* -complete=file>)
"               <complete: ...>      for simple completion from a list (i.e. <complete: --all --allow-fail --report>)
"               <compiler: name>     for specifying a :compiler to use (i.e. <compiler: gcc>)
"         * name (the name of the command to create)
"     * a:opts can also have:
"         * args                (deprecated - same as <default: ...> above)
"         * complete            (deprecated - same as <complete: ...> above))
"         * vim_cmd_args        (deprecated - same as <vim_cmd_args: ...> above))
"         * compiler            (deprecated - same as <compiler: ...> above))
"         * errorformat         (you really should use compiler instead)
"         * projmakers_runner   (a function reference which get the a:opts and executes the command)
"   runner(function) : Optionally supply a function which gets (opts,args) to run the command instead of :Make/:make
"   makeprg_updater(function) : Optionally supply a function which gets (opts,args) and updates the makeprg before :Make/:make
function! projmakers#new_command(opts, runner=v:none, makeprg_updater=v:none) abort
    if ! has_key(a:opts, "makeprg")
        return projmakers#warn("Got opts without a makeprg for " . string(a:opts))
    endif
    if ! has_key(a:opts, "name")
        return projmakers#warn("Got opts without a name: " . string(a:opts))
    endif
    let a:opts.projmakers_runner = a:runner
    let a:opts.projmakers_updater = a:makeprg_updater
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "default", a:opts, "args")
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "vim_cmd_args", a:opts, "vim_cmd_args")
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "complete", a:opts, "complete")
    let a:opts.makeprg = s:OverrideOpt(a:opts.makeprg, "compiler", a:opts, "compiler")
    if has_key(a:opts, "args")
        let l:default = '"' . a:opts.args . '"'
    else
        let a:opts.args = ""
        let l:default = '""'
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
    exe "command! -buffer -nargs=* " . l:complete . " " . a:opts.name . " call projmakers#_make('" . a:opts.name . "', projmakers#_args(<q-args>, " . l:default . "))"
endfunction


" PUBLIC: you can use this to expand this plugin
" Description:
"   Remove projmakers' buffer variables for the current buffer.
function! projmakers#cleanup() abort
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
    if exists("b:projmakers_args")
        unlet b:projmakers_args
    endif
endfunction


function! s:OverrideOpt(str, opt, opts, key) abort
    let [l:ret, l:item_key, l:item_val] = projmakers#shift(a:str, a:opt)
    if ! has_key(a:opts, a:key) && ! empty(l:item_val)
        let a:opts[a:key] = l:item_val
    endif
    return l:ret
endfunction



" PRIVATE: this can change without a warning
" Description:
"   Returns the args given on the vim command prompt, or configured default if none where given
" Params:
"   name (string): the name of the vim command
"   default (string): optional default arguments if this is invoked from another buffer
" Returns:
"   string - the args given on the vim command prompt, or configured default if none where given
function! projmakers#_buffered_args(name, default="") abort
    let l:projmakers_args = get(b:, "projmakers_args", "")
    let l:projmakers_opts = get(b:, "projmakers_opts", {})
    let l:default = get(get(l:projmakers_opts, a:name, {}), "args", a:default)
    return projmakers#_args(l:projmakers_args, l:default)
endfunction


" PRIVATE: this can change without a warning
" Description:
"   Return command args if given, else the default
" Params:
"   rt_args (string): the args given to the command on the vim command prompt
"   default (string): the default to use if a:rt_args is empty
" Returns:
"   string of command args if given, else the default
function! projmakers#_args(rt_args, default) abort
    if empty(a:rt_args)
        if empty(a:default)
            return ""
        else
            return a:default
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
    let l:cwd = getcwd()
    let l:efm = &l:efm
    let l:makeprg = &l:makeprg
    let l:compiler = get(b:, 'current_compiler', '')
    try
        let l:opts = deepcopy(b:projmakers_opts[a:name])
        if has_key(l:opts, "errorformat")
            let &l:efm = l:opts.errorformat
        endif
        if has_key(l:opts, "compiler")
            exe ":compiler " . l:opts.compiler
        endif
        if l:opts.projmakers_runner isnot v:none && ! get(g:, 'projmakers#force_make_runner', 0)
            let l:Runner = l:opts.projmakers_runner
            call l:Runner(l:opts, a:args)
        else
            if ! has_key(l:opts, "makeprg")
                return projmakers#warn("Got opts without a makeprg for " . a:name)
            endif
            let &l:makeprg = l:opts.makeprg
            if l:opts.projmakers_updater isnot v:none
                let l:Updater = l:opts.projmakers_updater
                let &l:makeprg = l:Updater(l:opts, a:args)
                let l:args = ""
            else
                let l:args = a:args
            endif
            if exists(":Make")
                let l:maker = 'Make'
            else
                let l:maker = 'make'
            endif
            exe ":" . l:maker . ' ' . l:args
        endif
    finally
        if win_gotoid(l:win_id)
            if ! empty(l:compiler)
                exe ":compiler " . l:compiler
            endif
            let &l:efm = l:efm
            let &l:makeprg = l:makeprg
            if getcwd() != l:cwd
                if haslocaldir() == 1
                    " window local directory case
                    exe "lcd " . l:cwd
                elseif haslocaldir() == 2
                    " tab-local directory case
                    exe "tcd " . l:cwd
                else
                    " global directory case
                    exe "cd " . l:cwd
                endif
            endif
        endif
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
