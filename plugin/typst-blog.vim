vim9script
import autoload 'typst_blog.vim' as blog
# plugin/typst-blog.vim
# vim9-typst-blog.vim - Draft/publish/link management for a Typst-powered
# static blog (SEVETECH / PaperStackPro workflow).
#
# This file only wires up configuration defaults and user commands. All
# logic lives in autoload/typst_blog.vim so nothing is loaded until a
# command is actually used.

if exists('g:loaded_typst_blog') && g:loaded_typst_blog
  finish
endif
g:loaded_typst_blog = true

if v:version < 900 || !has('vim9script')
  echoerr 'vim9-typst-blog.vim requires Vim 9+ with Vim9script support'
  finish
endif

# ---------------------------------------------------------------------------
# Configuration (set any of these in your vimrc *before* the plugin loads,
# or at any point with `:let g:typst_blog_xxx = ...` and re-source).
# ---------------------------------------------------------------------------

# Blog repo root (Typst posts are written here).
g:typst_blog_root = get(g:, 'typst_blog_root', getcwd())

# Draft folder (Markdown), relative to g:typst_blog_root unless absolute.
# Point it outside the repo to keep drafts private. Created on first :BlogNew.
g:typst_blog_draft_dir = get(g:, 'typst_blog_draft_dir', 'DRAFT')

# Published posts, relative to g:typst_blog_root unless absolute.
g:typst_blog_publish_dir = get(g:, 'typst_blog_publish_dir', 'posts')

# Preamble values. website.typ itself is never touched.
g:typst_blog_import_path = get(g:, 'typst_blog_import_path', '/libs/website.typ')
g:typst_blog_author      = get(g:, 'typst_blog_author', 'SEVETECH')

# Extensions: drafts (Markdown) and published posts (Typst).
g:typst_blog_draft_ext = get(g:, 'typst_blog_draft_ext', '.md')
g:typst_blog_ext       = get(g:, 'typst_blog_ext', '.typ')

# Markdown -> Typst body converter, stdin to stdout. '' disables conversion.
g:typst_blog_convert_cmd = get(g:, 'typst_blog_convert_cmd', 'pandoc -f markdown -t typst')

# --- Integration: sevehub/fdminifuzzy.vim -----------------------------
# Name of the Ex command that fdminifuzzy.vim exposes for picking a file
# from a list/directory. Adjust this if your installed version names it
# differently - vim9-typst-blog.vim degrades to a built-in matchfuzzy()
# popup picker automatically when the command isn't found, so it will
# work either way.
g:typst_blog_fuzzy_cmd = get(g:, 'typst_blog_fuzzy_cmd', 'FdMiniFuzzy')

# --- Integration: sevehub/typstpowershell -------------------------------
# Name of the Ex command typstpowershell exposes to compile the buffer /
# project. Adjust if yours differs. Falls back to `make` in the project
# root, then to a raw `typst compile` if no Makefile is found either.
g:typst_blog_compile_cmd = get(g:, 'typst_blog_compile_cmd', 'TypstCompile')

# Funcref(list<string>): string used by :BlogLink (and as a fallback for
# the list/open commands) to turn a list of candidate files into a single
# chosen path. Defaults to a small built-in matchfuzzy()+inputlist()
# picker. If fdminifuzzy.vim exposes a synchronous "pick one of these"
# function rather than just an :Ex command, point this at a thin wrapper
# around it instead, e.g.:
#   g:typst_blog_picker = (files) => fdminifuzzy#PickOne(files)
g:typst_blog_picker = get(g:, 'typst_blog_picker', '')

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
command! -nargs=1 BlogNew                 call blog.BlogNew(<q-args>)
command! -nargs=0 -bar BlogPublish        call blog.BlogPublish()
command! -nargs=0 -bar BlogList           call blog.BlogListDrafts()
command! -nargs=0 -bar BlogListAll        call blog.BlogListAll()
command! -nargs=0 -bar BlogLink           call blog.BlogInsertLink()
command! -nargs=0 -bar BlogBacklinks      call blog.BlogBacklinks()
command! -nargs=0 -bar BlogCompile        call blog.BlogCompile()
command! -nargs=0 -bar BlogOpenDrafts     call blog.BlogOpenDir('draft')
command! -nargs=0 -bar BlogOpenPublished  call blog.BlogOpenDir('publish')

