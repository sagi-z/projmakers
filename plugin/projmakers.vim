" Vim plugin which works with vim projectionist/asynctasks to simplify makeprgs in projects
" Last Change:	2021 March 31
" Maintainer:	Sagi Zeevi <sagi.zeevi@gmail.com>
" License:      MIT


if exists("g:loaded_projmakers")
    finish
endif
let g:loaded_projmakers = 1

" temporarily change compatible option
let s:save_cpo = &cpo
set cpo&vim


" Cleanup here - and later add implementation autocmd (projectionist, asynctasks, ...)
augroup projmakers
    autocmd!
augroup end

"""
" projectionist support:
"
function! s:ProjectionistActivated() abort
    if ! exists("*projectionist#query")
        return
    endif
    for [l:root, l:makeprgs] in projectionist#query('makeprgs')
        for [l:cmd, l:opts] in items(l:makeprgs)
            let l:opts.name = l:cmd
            call projmakers#new_command(l:opts)
        endfor
        break
    endfor
endfunction


augroup projmakers
    autocmd User ProjectionistActivate call s:ProjectionistActivated()
augroup end
"
"""

"""
" asynctasks support:
"
let s:projmakers_task_prefix = '.makeprgs.'
let s:task_prefix_len = len(s:projmakers_task_prefix)

" This program implementation can be invoked in 2 situations:
" 1. When executing for a command it will update itself with configured defaults and optionally
"    delegate to another program.
" 2. When updating the makeprg when :Make is used, do the same as 2 above, but throw an exception
"    to return the new command.
function! s:AsyncOptsInterceptor(opts)
    if ! s:IsBufferedCommandName(a:opts.name)
        call projmakers#warn("asynctask '". a:opts.name.
                    \"' is either wrongly named or should not use program 'makeprgs'")
        return a:opts.cmd
    endif
    let [l:cmd, l:inline_opts] = projmakers#eval_orig_cmd(a:opts.cmd, s:BufferedCommandName(a:opts.name))
    if has_key(l:inline_opts, "program")
        let a:opts.cmd = l:cmd
        let l:F = l:inline_opts.program
        if type(l:F) == v:t_string
            let l:F = function(l:F)
        endif
        let l:cmd = l:F(a:opts)
    endif
    let l:is_updating = get(b:, 'projmakers_is_updating', 0)
    if l:is_updating
        let b:projmakers_updated_makeprg = l:cmd
        throw "AsyncOptsInterceptor"
    endif
    return l:cmd
endfunction
let g:asyncrun_program = get(g:, 'asyncrun_program', {})
let g:asyncrun_program.makeprgs = funcref("s:AsyncOptsInterceptor")


function! s:IsBufferedCommandName(orig_name) abort
    return a:orig_name[:s:task_prefix_len - 1] == s:projmakers_task_prefix
endfunction


function! s:BufferedCommandName(orig_name) abort
    if s:IsBufferedCommandName(a:orig_name)
        return a:orig_name[s:task_prefix_len:]
    endif
    return ""
endfunction


function! s:AsyncTaskCmdUpdater(opts, args) abort
    try
        let b:projmakers_updated_makeprg = a:opts.makeprg
        let b:projmakers_is_updating = 1
        try
            exe "AsyncTask " . a:opts.orig_name
        catch /^AsyncOptsInterceptor$/
        endtry
    finally
        let b:projmakers_is_updating = 0
    endtry
    return b:projmakers_updated_makeprg
endfunction


function! s:AsyncTaskRunner(opts, args) abort
    exe "AsyncTask " . a:opts.orig_name
endfunction


function! s:RefreshFromAsyncTasks() abort
    if ! exists("*asynctasks#list")
        return
    endif
    call s:AsyncTasksCleanup()
    let b:projmakers_async_tasks_loaded = 1
    for l:task in asynctasks#list('')
        if s:IsBufferedCommandName(l:task.name)
            let l:opts = {}
            let l:opts.orig_name = l:task.name
            let l:opts.name = s:BufferedCommandName(l:task.name)
            let l:opts.makeprg = l:task.command
            call projmakers#new_command(l:opts,
                        \ function("s:AsyncTaskRunner"),
                        \ function("s:AsyncTaskCmdUpdater"))
        endif
    endfor
endfunction


function! s:AsyncTasksCleanup() abort
    if exists("b:projmakers_async_tasks_loaded")
        unlet b:projmakers_async_tasks_loaded
    endif
    if exists("b:projmakers_is_updating")
        unlet b:projmakers_is_updating
    endif
    if exists("b:projmakers_updated_makeprg")
        unlet b:projmakers_updated_makeprg
    endif
    call projmakers#cleanup()
endfunction


augroup projmakers
    autocmd FileType * call s:RefreshFromAsyncTasks()
augroup end
"
"""


" restore compatible option
let &cpo = s:save_cpo
unlet s:save_cpo

