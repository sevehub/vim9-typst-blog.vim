# vim9-typst-blog.vim

Vim9script plugin for a Typst-powered static blog. Drafts are plain
Markdown files; `:BlogPublish` converts a draft into a Typst post (standard
`article` preamble plus converted body) inside the blog repository. Published
posts can be cross-linked Zettelkasten style. Optional integration with
[fdminifuzzy.vim](https://github.com/sevehub/fdminifuzzy.vim) and
[typstpowershell](https://github.com/sevehub/typstpowershell).

It intentionally does **not** touch `website.typ` (only imported by generated
preambles) and does **not** run the build unless `:BlogCompile` is called.

## Install

Vim 9.0+ with `+vim9script`:

```sh
git clone https://github.com/sevehub/vim9-typst-blog.vim ~/vimfiles/pack/plugin/start/vim9-typst-blog.vim
```

Markdown-to-Typst conversion uses [pandoc](https://pandoc.org) when found
on the PATH; otherwise the body is copied unconverted.

## Configure

Two locations: the draft directory and the blog repository.

```vim
g:typst_blog_root        = 'C:/work/blog'          # blog repo (default: cwd)
g:typst_blog_draft_dir   = 'C:/notes/blog-drafts'  # Markdown drafts (default: DRAFT)
g:typst_blog_publish_dir = 'posts'                 # Typst output, relative to root
```

Relative paths resolve against `g:typst_blog_root`. Other variables:
`g:typst_blog_import_path`, `g:typst_blog_author`, `g:typst_blog_draft_ext`,
`g:typst_blog_ext`, `g:typst_blog_convert_cmd`, `g:typst_blog_fuzzy_cmd`,
`g:typst_blog_compile_cmd`, `g:typst_blog_picker`. See `:help typst-blog`.

## Draft format

Markdown with optional YAML front matter (`title`, `subtitle`, `keywords`,
`author`):

```markdown
---
title: Migrating the Build Pipeline to Node
subtitle:
keywords: typst, node
---

Body in Markdown.
```

A missing title falls back to the first `# Heading`, then to the file name.

## Commands

|Command|What it does|
|-|-|
|`:BlogNew {title}`|New `{draft_dir}/{slug}.md` with front matter, cursor in `subtitle`|
|`:BlogPublish`|Convert the current draft to `{root}/{publish_dir}/{slug}.typ` and open it; draft unchanged|
|`:BlogList`|Fuzzy-open a draft|
|`:BlogListAll`|Fuzzy-open a draft or published post|
|`:BlogOpenDrafts`|Picker scoped to drafts|
|`:BlogOpenPublished`|Picker scoped to published posts|
|`:BlogLink`|Pick a published post, insert `#link(...)[Title]` below cursor|
|`:BlogBacklinks`|Quickfix list of published posts linking to the current one|
|`:BlogCompile`|typstpowershell command, else `make`, else `typst compile`|

## Example: `:BlogPublish`

Draft `my-post.md` above publishes to `posts/my-post.typ`:

```typst
#import "/libs/website.typ": article
#show: article.with(
  title: "Migrating the Build Pipeline to Node",
  subtitle: "",
  author: "SEVETECH",
  date: datetime(year: 2026, month: 10, day: 13),
  keywords: "typst, node",
)

= Migrating the Build Pipeline to Node

<converted body>
```

## Integrations

Both companion plugins are wired by command or Funcref name only and degrade
gracefully when absent:

```vim
g:typst_blog_fuzzy_cmd   = 'FdMiniFuzzy'
g:typst_blog_compile_cmd = 'TypstCompile'
# synchronous picker for :BlogLink
g:typst_blog_picker = (files) => fdminifuzzy#PickOne(files)
```

## Mappings

Buffer-local, set in `.typ` buffers and in Markdown files inside the draft
directory, under `g:typst_blog_map_prefix` (default `<localleader>b`):
`n` New, `p` Publish, `l` List, `a` ListAll, `i` Link, `b` Backlinks,
`c` Compile. Set `g:typst_blog_no_mappings = true` to disable.

## License

MIT
