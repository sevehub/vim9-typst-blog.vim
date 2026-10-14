vim9script
# ftplugin/markdown.vim - mappings only for drafts inside g:typst_blog_draft_dir
import autoload 'typst_blog.vim' as blog

if !exists('g:loaded_typst_blog')
  finish
endif
if blog.IsDraft(expand('%:p'))
  blog.MapBuffer()
endif

