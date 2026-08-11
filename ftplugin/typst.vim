vim9script
# ftplugin/typst.vim
# Optional buffer-local mappings for the vim9-typst-blog.vim workflow.
# Only defined when the main plugin is loaded and the user hasn't already
# disabled ftplugin mappings with g:typst_blog_no_mappings.

if !exists('g:loaded_typst_blog') || get(g:, 'typst_blog_no_mappings', false)
  finish
endif

if exists('b:did_typst_blog_ftplugin')
  finish
endif
b:did_typst_blog_ftplugin = true

var prefix = get(g:, 'typst_blog_map_prefix', '<localleader>b')

# {suffix, rhs} pairs. BlogNew is special-cased: it drops into the command
# line (with a trailing space) so you can type the title, rather than
# firing immediately like the zero-argument commands below.
var maps: list<list<string>> = [
  ['n', ':BlogNew '],
  ['p', '<Cmd>BlogPublish<CR>'],
  ['l', '<Cmd>BlogList<CR>'],
  ['a', '<Cmd>BlogListAll<CR>'],
  ['i', '<Cmd>BlogLink<CR>'],
  ['b', '<Cmd>BlogBacklinks<CR>'],
  ['c', '<Cmd>BlogCompile<CR>'],
]

var undoParts: list<string> = []
for [suffix, rhs] in maps
  execute 'nnoremap <buffer> ' .. prefix .. suffix .. ' ' .. rhs
  add(undoParts, 'silent! nunmap <buffer> ' .. prefix .. suffix)
endfor
add(undoParts, 'unlet! b:did_typst_blog_ftplugin')

var previous = get(b:, 'undo_ftplugin', '')
b:undo_ftplugin = (empty(previous) ? '' : previous .. ' | ') .. join(undoParts, ' | ')
