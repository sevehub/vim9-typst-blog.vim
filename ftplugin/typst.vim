vim9script
# ftplugin/typst.vim
import autoload 'typst_blog.vim' as blog
 
if !exists('g:loaded_typst_blog')
  finish
endif
blog.MapBuffer()


