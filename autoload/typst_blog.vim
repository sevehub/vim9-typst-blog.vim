vim9script
# autoload/typst_blog.vim
# Drafts : Markdown files             (g:typst_blog_draft_dir)
# Posts  : Typst files in the blog repo (g:typst_blog_root + g:typst_blog_publish_dir)
# :BlogPublish converts draft.md -> post.typ (preamble + body).
# website.typ is only imported by generated preambles, never written.

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

def AsDir(path: string): string
  var p = fnamemodify(expand(path), ':p')
  return p =~# '[/\\]$' ? p : p .. '/'
enddef

def Norm(path: string): string
  var p = substitute(fnamemodify(path, ':p'), '\\', '/', 'g')
  return has('win32') ? tolower(p) : p
enddef

def IsAbsolute(path: string): bool
  return path =~# '^\([/\\]\|[A-Za-z]:[/\\]\)'
enddef

def IsInside(path: string, dir: string): bool
  return stridx(Norm(path), Norm(AsDir(dir))) == 0
enddef

# Blog git repo root.
def Root(): string
  return AsDir(g:typst_blog_root)
enddef

# Draft folder (Markdown), relative to the root unless absolute.
def DraftDir(): string
  var rel = g:typst_blog_draft_dir
  return AsDir(IsAbsolute(rel) ? rel : Root() .. rel)
enddef

# Published Typst folder, inside the git repo.
def PublishDir(): string
  var rel = g:typst_blog_publish_dir
  return AsDir(IsAbsolute(rel) ? rel : Root() .. rel)
enddef

def EnsureDir(dir: string)
  if !isdirectory(dir)
    mkdir(dir, 'p')
  endif
enddef

# "/posts/my-post.typ": repo-root-absolute, same convention as /libs/website.typ.
def RootRelative(path: string): string
  if IsInside(path, Root())
    var p = substitute(fnamemodify(path, ':p'), '\\', '/', 'g')
    return '/' .. strpart(p, len(Root()))
  endif
  return fnamemodify(path, ':p')
enddef

def Files(dir: string, ext: string): list<string>
  if !isdirectory(dir)
    return []
  endif
  return sort(glob(dir .. '*' .. ext, false, true))
enddef

def DraftFiles(): list<string>
  return Files(DraftDir(), g:typst_blog_draft_ext)
enddef

def PublishedFiles(): list<string>
  return Files(PublishDir(), g:typst_blog_ext)
enddef

export def IsDraft(path: string): bool
  return !empty(path)
    && IsInside(path, DraftDir()) && path =~# escape(g:typst_blog_draft_ext, '.') .. '$'
enddef

# ---------------------------------------------------------------------------
# Slug / title
# ---------------------------------------------------------------------------

def Slugify(title: string): string
  var s = tolower(title)
  s = substitute(s, '[^a-z0-9]\+', '-', 'g')
  return substitute(s, '^-\+\|-\+$', '', 'g')
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
# Picker (fdminifuzzy.vim if present, else matchfuzzy()+inputlist())
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
  return (choice < 1 || choice > len(matches)) ? '' : matches[choice - 1]
enddef

def Pick(files: list<string>): string
  var Picker = get(g:, 'typst_blog_picker', '')
  return empty(Picker) ? DefaultPicker(files) : call(Picker, [files])
enddef

def OpenPicked(files: list<string>)
  var picked = Pick(files)
  if !empty(picked)
    execute 'edit ' .. fnameescape(picked)
  endif
enddef

# ---------------------------------------------------------------------------
# Draft parsing, conversion, preamble
# ---------------------------------------------------------------------------

# Optional YAML front matter (title, subtitle, keywords, author) becomes
# metadata. A first `# Heading` is used as the title if none is given and is
# dropped from the body. Fallback title: the file name.
def ParseDraft(path: string): dict<any>
  var lines = readfile(path)
  var meta: dict<string> = {}
  var i = 0
  if !empty(lines) && lines[0] =~# '^---\s*$'
    var j = 1
    while j < len(lines) && lines[j] !~# '^\(---\|\.\.\.\)\s*$'
      var m = matchlist(lines[j], '^\([A-Za-z][A-Za-z0-9_-]*\):\s*\(.*\)$')
      if !empty(m)
        meta[tolower(m[1])] = substitute(trim(m[2]), '^\([''"]\)\(.*\)\1$', '\2', '')
      endif
      j += 1
    endwhile
    if j < len(lines)
      i = j + 1
    endif
  endif
  while i < len(lines) && empty(trim(lines[i]))
    i += 1
  endwhile
  var h = i < len(lines) ? matchlist(lines[i], '^#\s\+\(.\{-}\)\s*$') : []
  if !empty(h)
    if empty(get(meta, 'title', ''))
      meta.title = h[1]
    endif
    i += 1
  endif
  if empty(get(meta, 'title', ''))
    meta.title = fnamemodify(path, ':t:r')
  endif
  return {meta: meta, body: lines[i :]}
enddef

# Markdown -> Typst via g:typst_blog_convert_cmd (default pandoc). Body passes
# through unchanged when the converter is missing or disabled.
def Convert(body: list<string>): list<string>
  var cmd = g:typst_blog_convert_cmd
  if empty(cmd) || !executable(split(cmd)[0])
    echo 'typst-blog: converter not available, body copied unconverted'
    return body
  endif
  var out = system(cmd, join(body, "\n") .. "\n")
  if v:shell_error != 0
    throw $'typst-blog: converter failed: {out}'
  endif
  var res = split(out, '\r\?\n', true)
  while !empty(res) && empty(res[-1])
    remove(res, -1)
  endwhile
  return res
enddef

def Q(s: string): string
  return escape(s, '\"')
enddef

def BuildPreamble(meta: dict<string>): list<string>
  var y = str2nr(strftime('%Y'))
  var m = str2nr(strftime('%m'))
  var d = str2nr(strftime('%d'))
  return [
    '#import "' .. g:typst_blog_import_path .. '": article',
    '#show: article.with(',
    '  title: "' .. Q(meta.title) .. '",',
    '  subtitle: "' .. Q(get(meta, 'subtitle', '')) .. '",',
    '  author: "' .. Q(get(meta, 'author', g:typst_blog_author)) .. '",',
    '  date: datetime(year: ' .. y .. ', month: ' .. m .. ', day: ' .. d .. '),',
    '  keywords: "' .. Q(get(meta, 'keywords', '')) .. '",',
    ')',
    '',
    '= ' .. meta.title,
    '',
  ]
enddef

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

# :BlogNew {title}  ->  {draft_dir}/{slug}.md with YAML front matter, no Typst preamble.
export def BlogNew(title: string)
  if empty(trim(title))
    echoerr 'typst-blog: BlogNew requires a title, e.g. :BlogNew My New Post'
    return
  endif
  var slug = Slugify(title)
  if empty(slug)
    echoerr $'typst-blog: could not derive a filename slug from "{title}"'
    return
  endif

  var draftDir = DraftDir()
  EnsureDir(draftDir)
  var fullpath = draftDir .. slug .. g:typst_blog_draft_ext

  if filereadable(fullpath)
    var choice = confirm($'{fnamemodify(fullpath, ":t")} already exists in drafts.', "&Open it\n&Cancel", 1)
    if choice == 1
      execute 'edit ' .. fnameescape(fullpath)
    endif
    return
  endif

  execute 'noautocmd edit ' .. fnameescape(fullpath)
  setline(1, ['---', 'title: ' .. title, 'subtitle: ', 'keywords: ', '---', '', ''])
  silent write
  &filetype = 'markdown'
  cursor(3, 1)
  startinsert!
enddef

# :BlogPublish  ->  draft.md becomes {root}/{publish_dir}/{slug}.typ with the
# Typst preamble, then opens it. The draft is left untouched.
export def BlogPublish()
  var current = expand('%:p')
  if !IsDraft(current)
    echoerr 'typst-blog: current file is not a draft (see g:typst_blog_draft_dir)'
    return
  endif
  update

  var draft = ParseDraft(current)
  var body: list<string>
  try
    body = Convert(draft.body)
  catch
    echoerr v:exception
    return
  endtry

  var publishDir = PublishDir()
  EnsureDir(publishDir)
  var target = publishDir .. fnamemodify(current, ':t:r') .. g:typst_blog_ext

  if filereadable(target)
    var choice = confirm($'{fnamemodify(target, ":t")} already exists in the blog repo.', "&Overwrite\n&Cancel", 2)
    if choice != 1
      return
    endif
  endif

  if writefile(BuildPreamble(draft.meta) + body, target) != 0
    echoerr $'typst-blog: failed to write {target}'
    return
  endif

  execute 'edit ' .. fnameescape(target)
  echo $'typst-blog: published {fnamemodify(target, ":t")} -> {RootRelative(target)}'
enddef

export def BlogListDrafts()
  BlogOpenDir('draft')
enddef

export def BlogListAll()
  OpenPicked(DraftFiles() + PublishedFiles())
enddef

export def BlogOpenDir(which: string)
  var isPub = which ==# 'publish'
  var dir = isPub ? PublishDir() : DraftDir()
  if !isdirectory(dir)
    echo $'typst-blog: {dir} does not exist yet'
    return
  endif
  if !empty(g:typst_blog_fuzzy_cmd) && exists(':' .. g:typst_blog_fuzzy_cmd) == 2
    execute g:typst_blog_fuzzy_cmd .. ' ' .. fnameescape(dir)
    return
  endif
  OpenPicked(Files(dir, isPub ? g:typst_blog_ext : g:typst_blog_draft_ext))
enddef

# :BlogLink  ->  #link("/posts/x.typ")[Title] below cursor. Published posts only.
export def BlogInsertLink()
  var current = expand('%:p')
  var picked = Pick(filter(PublishedFiles(), (_, v) => v !=# current))
  if empty(picked)
    return
  endif
  var here = line('.')
  append(here, $'#link("{RootRelative(picked)}")[{ExtractTitle(picked)}]')
  cursor(here + 1, 1)
enddef

# :BlogBacklinks  ->  quickfix of published posts linking to the current one.
export def BlogBacklinks()
  var current = expand('%:p')
  if empty(current)
    echoerr 'typst-blog: no file in the current buffer'
    return
  endif
  var needle = RootRelative(current)
  var qf: list<dict<any>> = []
  for f in filter(PublishedFiles(), (_, v) => v !=# current)
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

# :BlogCompile  ->  typstpowershell cmd, else `make` in the repo, else typst compile.
export def BlogCompile()
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
  if empty(current) || current !~# '\.typ$'
    echoerr 'typst-blog: no .typ file to compile'
    return
  endif
  execute '!typst compile ' .. fnameescape(current)
enddef

# ---------------------------------------------------------------------------
# Buffer-local mappings (called from ftplugin/typst.vim and ftplugin/markdown.vim)
# ---------------------------------------------------------------------------

export def MapBuffer()
  if exists('b:did_typst_blog_ftplugin') || get(g:, 'typst_blog_no_mappings', false)
    return
  endif
  b:did_typst_blog_ftplugin = true

  var prefix = get(g:, 'typst_blog_map_prefix', '<localleader>b')
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
enddef


