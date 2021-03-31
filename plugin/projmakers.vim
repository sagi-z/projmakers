" Vim plugin which works with vim projectionist/asynctasks to simplify makeprgs in projects
" Last Change:	2021 March 30
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

function! s:OptsInterceptor(opts)
    let is_caching = get(b:, 'projmakers_is_caching', 0)
    if is_caching
        let b:projmakers_async_tasks = get(b:, 'projmakers_async_tasks', {})
        let b:projmakers_async_tasks[a:opts.name] = deepcopy(a:opts)
        throw "OptsInterceptor"
    else
        return b:projmakers_async_tasks[a:opts.name].makeprg
    endif
endfunction
let g:asyncrun_program = get(g:, 'asyncrun_program', {})
let g:asyncrun_program.makeprgs = funcref("s:OptsInterceptor")


function! s:AsyncTaskRunner(opts) abort
    exe "AsyncTask " . a:opts.orig_name
endfunction


function! s:RefreshFromAsyncTasks() abort
    if exists("b:projmakers_async_tasks")
        return
    endif
    try
        let b:projmakers_is_caching = 1
        for l:task in asynctasks#list('')
            if l:task.name[:s:task_prefix_len - 1] == s:projmakers_task_prefix
                try
                    exe "AsyncTask " . l:task.name
                catch /^OptsInterceptor$/
                    continue
                endtry
            endif
        endfor
    finally
        let b:projmakers_is_caching = 0
    endtry
    if exists("b:projmakers_async_tasks")
        for [l:name, l:opts] in items(b:projmakers_async_tasks)
            let l:opts.projmakers_runner = function("s:AsyncTaskRunner")
            let l:opts.orig_name = l:name
            let l:opts.name = l:name[s:task_prefix_len:]
            let l:opts.makeprg = l:opts.cmd
            if stridx(l:opts.errorformat, '\s\+') == -1
                let l:opts.compiler = l:opts.errorformat
                let l:opts.errorformat = ''
            endif
            call projmakers#new_command(l:opts)
        endfor
    endif
endfunction


function! s:AsyncTasksCleanup() abort
    if exists("b:projmakers_async_tasks")
        unlet b:projmakers_async_tasks
    endif
    if exists("b:projmakers_is_caching")
        unlet b:projmakers_is_caching
    endif
endfunction


augroup projmakers
    autocmd BufEnter * call s:RefreshFromAsyncTasks()
    autocmd BufUnload * call s:AsyncTasksCleanup()
augroup end
"
"""


" restore compatible option
let &cpo = s:save_cpo
unlet s:save_cpo

