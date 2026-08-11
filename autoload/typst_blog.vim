vim9script
# autoload/typst_blog.vim
# Core logic for vim9-typst-blog.vim.
#
# Public entry points are defined with the classic dotted autoload name
# (typst_blog#Xxx) so they can be called from :command definitions in
# plugin/typst-blog.vim without needing `import autoload`.
#
# NOTE: this plugin never writes to /libs/website.typ - that file is
# assumed to already exist and is only ever *imported* from generated
# preambles.

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

def Root(): string
  return fnamemodify(g:typst_blog_root, ':p')
enddef

def IsAbsolute(path: string): bool
  return path =~# '^\([/\\]\|[A-Za-z]:[/\\]\)'
enddef

def ResolveDir(rel: string): string
  var target = IsAbsolute(rel) ? rel : Root() .. rel
  return fnamemodify(target, ':p')
enddef

def DraftDir(): string
  return ResolveDir(g:typst_blog_draft_dir)
enddef

def PublishDir(): string
  return ResolveDir(g:typst_blog_publish_dir)
enddef

def EnsureDir(dir: string)
  if !isdirectory(dir)
    mkdir(dir, 'p')
  endif
enddef

# Absolute-from-project-root path, e.g. "/DRAFT/my-post.typ", matching the
# same absolute-import convention website.typ already uses for /libs/...
def RootRelative(path: string): string
  var root = Root()
  var abs = fnamemodify(path, ':p')
  if strpart(abs, 0, len(root)) ==# root
    return '/' .. strpart(abs, len(root))
  endif
  return abs
enddef

def Files(dir: string): list<string>
  if !isdirectory(dir)
    return []
  endif
  return sort(glob(dir .. '*' .. g:typst_blog_ext, false, true))
enddef

def DraftFiles(): list<string>
  return Files(DraftDir())
enddef

def PublishedFiles(): list<string>
  return Files(PublishDir())
enddef

# ---------------------------------------------------------------------------
# Slug / title helpers
# ---------------------------------------------------------------------------

def Slugify(title: string): string
  var s = tolower(title)
  s = substitute(s, '[^a-z0-9]\+', '-', 'g')
  s = substitute(s, '^-\+\|-\+$', '', 'g')
  return s
enddef

def ExtractTitle(path: string): string
  if filereadable(path)
    for l in readfile(path, '', 20)
      var m = matchlist(l, '^\s*title:\s*"\(.\{-}\)"')
      if !empty(m)
        return m[1]
      endif
    endfor
  endif
  return fnamemodify(path, ':t:r')
enddef

# ---------------------------------------------------------------------------
# Picker: prefers sevehub/fdminifuzzy.vim, falls back to a small built-in
# matchfuzzy() + inputlist() picker so the plugin still works standalone.
# Override g:typst_blog_picker with your own Funcref(list<string>): string
# if fdminifuzzy.vim exposes a synchronous selection API you'd rather use.
# ---------------------------------------------------------------------------

def DefaultPicker(files: list<string>): string
  if empty(files)
    echo 'typst-blog: no articles found'
    return ''
  endif
  var query = input('typst-blog fuzzy filter (blank = all)> ')
  redraw
  var matches = empty(query) ? copy(files) : matchfuzzy(files, query)
  if empty(matches)
    echo 'typst-blog: no matches'
    return ''
  endif
  if len(matches) == 1
    return matches[0]
  endif
  var menu = ['Select an article:']
  var i = 1
  for f in matches
    add(menu, printf('%d. %s', i, fnamemodify(f, ':t')))
    i += 1
  endfor
  var choice = inputlist(menu)
  if choice < 1 || choice > len(matches)
    return ''
  endif
  return matches[choice - 1]
enddef

def Pick(files: list<string>): string
  var Picker = get(g:, 'typst_blog_picker', '')
  if empty(Picker)
    return DefaultPicker(files)
  endif
  return call(Picker, [files])
enddef

def OpenPicked(files: list<string>)
  var picked = Pick(files)
  if !empty(picked)
    execute 'edit ' .. fnameescape(picked)
  endif
enddef

# ---------------------------------------------------------------------------
# Preamble
# ---------------------------------------------------------------------------

def BuildPreamble(title: string): list<string>
  var y = str2nr(strftime('%Y'))
  var m = str2nr(strftime('%m'))
  var d = str2nr(strftime('%d'))
  return [
    '#import "' .. g:typst_blog_import_path .. '": article',
    '#show: article.with(',
    '  title: "' .. escape(title, '"') .. '",',
    '  subtitle: "",',
    '  author: "' .. g:typst_blog_author .. '",',
    '  date: datetime(year: ' .. y .. ', month: ' .. m .. ', day: ' .. d .. '),',
    '  keywords: "",',
    ')',
    '',
    '= ' .. title,
    '',
    '',
  ]
enddef

# ---------------------------------------------------------------------------
# Public commands
# ---------------------------------------------------------------------------

# :BlogNew {title}
# Creates {DRAFT}/{slug}.typ prefilled with the standard article preamble
# (title + today's date filled in, subtitle/keywords left for you) and
# opens it, cursor ready inside the subtitle field.
def typst_blog#New(title: string)
  if empty(trim(title))
    echoerr 'typst-blog: BlogNew requires a title, e.g. :BlogNew My New Post'
    return
  endif

  var draftDir = DraftDir()
  EnsureDir(draftDir)

  var slug = Slugify(title)
  if empty(slug)
    echoerr $'typst-blog: could not derive a filename slug from "{title}"'
    return
  endif

  var fullpath = draftDir .. slug .. g:typst_blog_ext

  if filereadable(fullpath)
    var choice = confirm($'{fnamemodify(fullpath, ":t")} already exists in DRAFT.', "&Open it\n&Cancel", 1)
    if choice == 1
      execute 'edit ' .. fnameescape(fullpath)
    endif
    return
  endif

  execute 'edit ' .. fnameescape(fullpath)
  setline(1, BuildPreamble(title))
  silent write

  var subtitleLnum = search('^\s*subtitle:\s*""', 'nw')
  if subtitleLnum > 0
    cursor(subtitleLnum, 1)
    normal! f"l
    startinsert
  endif
enddef

# :BlogPublish
# Moves the current buffer's file from DRAFT into DOCUMENTS (git mv when
# inside a git repo, so history follows the file), then reopens it there.
# The Node/Typst build (your Makefile) is left untouched - run :BlogCompile
# or your usual `make` afterwards.
def typst_blog#Publish()
  var current = expand('%:p')
  if empty(current)
    echoerr 'typst-blog: no file in the current buffer'
    return
  endif

  var draftDir = DraftDir()
  if strpart(current, 0, len(draftDir)) !=# draftDir
    echoerr $'typst-blog: current file is not inside {g:typst_blog_draft_dir}, refusing to publish'
    return
  endif

  var publishDir = PublishDir()
  EnsureDir(publishDir)

  var basename = fnamemodify(current, ':t')
  var target = publishDir .. basename

  if filereadable(target)
    var choice = confirm($'{basename} already exists in {g:typst_blog_publish_dir}.', "&Overwrite\n&Cancel", 2)
    if choice != 1
      return
    endif
  endif

  update

  var oldBuf = bufnr('%')
  var moved = false

  if isdirectory(Root() .. '.git')
    system('git -C ' .. shellescape(Root()) .. ' mv -f -- '
      .. shellescape(current) .. ' ' .. shellescape(target))
    moved = v:shell_error == 0 && filereadable(target)
  endif

  if !moved
    moved = rename(current, target) == 0
  endif

  if !moved
    echoerr $'typst-blog: failed to move {basename} to {g:typst_blog_publish_dir}'
    return
  endif

  execute 'edit ' .. fnameescape(target)
  if bufexists(oldBuf) && oldBuf != bufnr('%')
    execute 'bwipeout ' .. oldBuf
  endif

  echo $'typst-blog: published {basename} -> {g:typst_blog_publish_dir}'
enddef

# :BlogList / :BlogListAll / :BlogOpenDrafts / :BlogOpenPublished
def typst_blog#ListDrafts()
  typst_blog#OpenDir('draft')
enddef

def typst_blog#ListAll()
  OpenPicked(DraftFiles() + PublishedFiles())
enddef

def typst_blog#OpenDir(which: string)
  var dir = which ==# 'publish' ? PublishDir() : DraftDir()
  if !isdirectory(dir)
    echo $'typst-blog: {dir} does not exist yet'
    return
  endif
  if !empty(g:typst_blog_fuzzy_cmd) && exists(':' .. g:typst_blog_fuzzy_cmd) == 2
    execute g:typst_blog_fuzzy_cmd .. ' ' .. fnameescape(dir)
    return
  endif
  OpenPicked(Files(dir))
enddef

# :BlogLink
# Zettelkasten-style cross-linking: fuzzy-pick another article (draft or
# published) and insert a #link(...)[Title] to it on the line below the
# cursor, using a project-root-relative path.
def typst_blog#InsertLink()
  var current = expand('%:p')
  var candidates = filter(DraftFiles() + PublishedFiles(), (_, v) => v !=# current)

  var picked = Pick(candidates)
  if empty(picked)
    return
  endif

  var title = ExtractTitle(picked)
  var linkPath = RootRelative(picked)
  var linkText = $'#link("{linkPath}")[{title}]'

  var here = line('.')
  append(here, linkText)
  cursor(here + 1, 1)
enddef

# :BlogBacklinks
# Populates the quickfix list with every article that already links to the
# current one, so you can walk your Zettelkasten backwards.
def typst_blog#Backlinks()
  var current = expand('%:p')
  if empty(current)
    echoerr 'typst-blog: no file in the current buffer'
    return
  endif

  var needle = RootRelative(current)
  var qf: list<dict<any>> = []

  for f in filter(DraftFiles() + PublishedFiles(), (_, v) => v !=# current)
    if !filereadable(f)
      continue
    endif
    var lnum = 0
    for l in readfile(f)
      lnum += 1
      if stridx(l, needle) >= 0
        add(qf, {filename: f, lnum: lnum, text: trim(l)})
      endif
    endfor
  endfor

  if empty(qf)
    echo $'typst-blog: no backlinks found for {fnamemodify(current, ":t")}'
    return
  endif

  setqflist([], ' ', {title: $'Backlinks: {fnamemodify(current, ":t")}', items: qf})
  copen
enddef

# :BlogCompile
# Prefers your typstpowershell compile command if it's loaded, otherwise
# runs `make` in the project root (the Makefile you already maintain to
# drive Build-TypstSite.js), and finally falls back to a raw
# `typst compile` on the current file if neither is available.
def typst_blog#Compile()
  if !empty(g:typst_blog_compile_cmd) && exists(':' .. g:typst_blog_compile_cmd) == 2
    execute g:typst_blog_compile_cmd
    return
  endif

  var root = Root()
  if filereadable(root .. 'Makefile')
    execute '!make -C ' .. fnameescape(root)
    return
  endif

  var current = expand('%:p')
  if empty(current)
    echoerr 'typst-blog: no file to compile'
    return
  endif
  execute '!typst compile ' .. fnameescape(current)
enddef
