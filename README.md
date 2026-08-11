# vim9-typst-blog.vim

A small Vim9script plugin for running a Typst-powered static blog:
draft new articles with the standard preamble already filled in, publish
them by moving DRAFT → DOCUMENTS, and cross-link articles Zettelkasten
style — with optional integration for
[fdminifuzzy.vim](https://github.com/sevehub/fdminifuzzy.vim) and
[typstpowershell](https://github.com/sevehub/typstpowershell).

It intentionally does **not**:

* generate or touch your shared `website.typ` import — that's assumed to
already exist,
* run your build pipeline for you unless you explicitly call
`:BlogCompile` — your existing `make` / `Build-TypstSite.js` step
stays the source of truth.

## Install

Vim 9.0+, `+vim9script`. Manual install (or use your plugin manager of
choice — no dependencies required):

```sh
mkdir -p \\\~/.vim/pack/bundle/start
git clone https://github.com/sevehub/vim9-typst-blog.vim \\\\
    \\\~/.vim/pack/bundle/start/vim9-typst-blog.vim
```

Optionally, also install the two companion plugins for the full
experience (see [Integrations](#integrations) below):

```sh
git clone https://github.com/sevehub/fdminifuzzy.vim \\\\
    \\\~/.vim/pack/bundle/start/fdminifuzzy.vim
git clone https://github.com/sevehub/typstpowershell \\\\
    \\\~/.vim/pack/bundle/start/typstpowershell
```

## Layout this plugin expects

```
<project root>/
├── DRAFT/          # :BlogNew writes here
├── DOCUMENTS/       # :BlogPublish moves here
├── libs/website.typ # already exists, never touched by this plugin
└── Makefile          # your existing build entry point
```

Set `g:typst\\\_blog\\\_root` if Vim's cwd isn't your project root, and
`g:typst\\\_blog\\\_draft\\\_dir` / `g:typst\\\_blog\\\_publish\\\_dir` if your directory
names differ from `DRAFT` / `DOCUMENTS`.

## Commands

|Command|What it does|
|-|-|
|`:BlogNew {title}`|New `DRAFT/{slug}.typ`, preamble filled in, cursor in `subtitle`|
|`:BlogPublish`|Move current file DRAFT → DOCUMENTS (`git mv` inside a git repo)|
|`:BlogList`|Fuzzy-open a draft|
|`:BlogListAll`|Fuzzy-open a draft *or* published article|
|`:BlogOpenDrafts`|Fuzzy picker scoped to DRAFT|
|`:BlogOpenPublished`|Fuzzy picker scoped to DOCUMENTS|
|`:BlogLink`|Zettelkasten: pick an article, insert `#link(...)\\\[Title]` below cursor|
|`:BlogBacklinks`|Quickfix list of every article linking to the current one|
|`:BlogCompile`|typstpowershell command → `make` → raw `typst compile`, first hit wins|

Full details: `:help typst-blog`.

## Example: `:BlogNew`

```
:BlogNew Migrating the Build Pipeline to Node
```

writes `DRAFT/migrating-the-build-pipeline-to-node.typ`:

```typst
#import "/libs/website.typ": article
#show: article.with(
  title: "Migrating the Build Pipeline to Node",
  subtitle: "",
  author: "SEVETECH",
  date: datetime(year: 2026, month: 8, day: 11),
  keywords: "",
)

= Migrating the Build Pipeline to Node


```

and leaves you in insert mode inside `subtitle: ""`.

## Integrations

Both companion plugins are wired in by **command/Funcref name only**, so
you don't need this plugin's source to match their exact API — just
point the config variable at whatever they actually call things:

```vim
" defaults shown
let g:typst\\\_blog\\\_fuzzy\\\_cmd   = 'FdMiniFuzzy'   " sevehub/fdminifuzzy.vim
let g:typst\\\_blog\\\_compile\\\_cmd = 'TypstCompile'  " sevehub/typstpowershell
```

* **fdminifuzzy.vim** — used by `:BlogList` / `:BlogListAll` /
`:BlogOpenDrafts` / `:BlogOpenPublished` to open a directory-scoped
picker. Falls back automatically to a built-in `matchfuzzy()` +
`inputlist()` picker if the command isn't found, so the plugin works
standalone too.

  `:BlogLink` needs the *chosen path back* (to insert a link), not just
a buffer opened, so it always goes through `g:typst\\\_blog\\\_picker`
instead. If fdminifuzzy.vim exposes a synchronous "return the pick"
function rather than only an `:Ex` command, wire it in directly:

```vim
  let g:typst\\\_blog\\\_picker = (files) => fdminifuzzy#PickOne(files)
  ```

* **typstpowershell** — `:BlogCompile` runs its compile command when
loaded, otherwise falls back to `make` in the project root, then to a
raw `typst compile` on the current file.

> Since neither companion plugin's exact public API was available while
> writing this, both hooks default to their most likely command names
> and degrade gracefully if wrong. Once you confirm the real names,
> just update the two `g:` variables above — no code changes needed.

## Suggested mappings

Buffer-local mappings are set automatically for `\\\*.typ` files, rooted at
`g:typst\\\_blog\\\_map\\\_prefix` (default `<localleader>b`): `<prefix>n/p/l/a/i/b/c`
for New/Publish/List/ListAll/Link/Backlinks/Compile. Set
`g:typst\\\_blog\\\_no\\\_mappings = v:true` to disable and roll your own.

## License

MIT — see [LICENSE](LICENSE).



