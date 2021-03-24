" Vim plugin which works with vim projectionist to multiple flexible makeprgs in projects
" Last Change:	2021 March 21
" Maintainer:	Sagi Zeevi <sagi.zeevi@gmail.com>
" License:      MIT


if exists("g:loaded_projmakers")
    finish
endif
let g:loaded_projmakers = 1

" temporarily change compatible option
let s:save_cpo = &cpo
set cpo&vim

autocmd User ProjectionistActivate call s:Activate()

function! s:ArgsComplete(params, A, L, P) abort
    return a:params
endfunction

function! s:Activate() abort
    for [root, makeprgs] in projectionist#query('makeprgs')
        for [cmd, val] in items(makeprgs)
            if has_key(val, "compiler")
                let makecfg = ":compiler " . val.compiler
                if has_key(val, "makeprg")
                    let makecfg .= " | setl makeprg=" . val.makeprg
                endif
                if exists("g:loaded_dispatch")
                    let maker = 'Make'
                else
                    let maker = 'make'
                endif
                if has_key(val, "args")
                    let defaults = '"' . val.args . '"'
                else
                    let defaults = ""
                endif
                if has_key(val, "complete")
                    if ! exists("b:projmakers_complete")
                        let b:projmakers_complete = {}
                    endif
                    let b:projmakers_complete[cmd] = val.complete
                    let complete = "-complete=custom,projmakers#complete"
                else
                    let complete = ""
                endif
                exe "command! -buffer -nargs=* " . complete . " " . cmd . " " . makecfg . " | exe '" . maker . " ' . projmakers#args(<q-args>, " . defaults . ")"
            endif
        endfor
        break
    endfor
endfunction

" restore compatible option
let &cpo = s:save_cpo
unlet s:save_cpo

