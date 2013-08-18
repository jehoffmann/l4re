" Vim syntax file for modules.list configuration language
" Language:    modules.list configuration language
" Maintainer:  Adam Lackorzynski <adam@os.inf.tu-dresden.de>
" Last Change: 2013 Jul

if exists("b:current_syntax")
  finish
endif

syn clear
syn case match

setlocal iskeyword+=-
setlocal iskeyword+=:
syn keyword l4modsStatement       modaddr module bin bin-nostrip data data-nostrip kernel sigma0
syn keyword l4modsStatement       roottask moe default-kernel default-sigma0 default-roottask default-bootstrap
syn keyword l4modsStatement       module-group module bootstrap initrd set
syn keyword l4modsStatement       perl: glob: shell:
syn keyword l4modsStatementTitle  entry group contained
syn keyword l4modsStatementTitle  include
syn match   l4modsTitle           /^ *\(entry\|group\).*/ contains=l4modsStatementTitle
syn match   l4modsComment         /#.*/

hi def link l4modsStatement      Statement
hi def link l4modsStatementTitle Type
hi def link l4modsComment        Comment
hi def link l4modsTitle          String

let b:current_syntax = "l4mods"
