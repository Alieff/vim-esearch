fu! esearch#pre(visual_mode, ...) abort
  let dir = a:0 ? a:1 : $PWD
  let initial_exp = esearch#regex#build(g:esearch_settings.use, a:visual_mode)
  let exp = esearch#cmdline#_read(initial_exp, dir)
  if empty(exp)
    return ''
  endif
  let exp = esearch#regex#finalize(exp, g:esearch_settings)
  return esearch#_start(exp, dir)
endfu

fu! esearch#_start(exp, dir) abort
  let pattern = g:esearch_settings.regex ? a:exp.pcre : a:exp.literal
  let outbufname = s:outbufname(pattern)
  call s:find_or_create_buf(outbufname)
  call esearch#win#init(a:dir)

  exe 'Dispatch! '.s:request_str(pattern, a:dir)

  let b:request = dispatch#request()
  let b:request.format = '%f:%l:%c:%m,%f:%l:%m'
  let b:request.background = 1
  let b:_es_exp = a:exp

  " matchdelete moved outside in case of dynamic .highlight_match change
  if exists('b:_es_match')
    try
      call matchdelete(b:_es_match)
    catch /E803:/
    endtry
  endif
  if g:esearch_settings.highlight_match
    let b:_es_match = matchadd('EsearchMatch', b:_es_exp.vim_match, -1)
  endif

  if !esearch#util#cgetfile(b:request)
    call esearch#win#update()
  endif
endfu

fu! s:outbufname(pattern) abort
  let format = s:bufname_fomat()
  let modifiers = ''
  let modifiers .= g:esearch_settings.case ? 'c' : ''
  let modifiers .= g:esearch_settings.word ? 'w' : ''
  let name = fnameescape(printf(format, a:pattern, modifiers))
  return substitute(name, '["]', '\\\\\0', 'g')
endfu

fu! esearch#_mappings() abort
  if !exists('s:mappings')
    let s:mappings = {
          \ '<leader>ff': '<Plug>(esearch)',
          \ 'set': function('esearch#util#set'),
          \ 'get': function('esearch#util#get'),
          \ 'dict': function('esearch#util#dict'),
          \ 'with_val': function('esearch#util#with_val'),
          \ }
  endif
  return s:mappings
endfu

fu! esearch#map(map, plug) abort
  call esearch#_mappings().set(a:map, a:plug)
endfu

fu! s:request_str(pattern, dir) abort
  let r = g:esearch_settings.parametrize('regex')
  let c = g:esearch_settings.parametrize('case')
  let w = g:esearch_settings.parametrize('word')
  return "ag ".r." ".c." ".w." --nogroup --nocolor --column -- " .
        \ esearch#util#shellescape(a:pattern)  . " " . esearch#util#shellescape(a:dir)
endfu

fu! s:find_or_create_buf(bufname) abort
  let bufnr = bufnr('^'.a:bufname.'$')
  if bufnr == bufnr('%')
    return 0
  elseif bufnr > 0
    let buf_loc = s:find_buf(bufnr)
    if empty(buf_loc)
      exe 'tabnew|b ' . bufnr
    else
      exe 'tabn ' . buf_loc[0]
      exe buf_loc[1].'winc w'
    endif
  else
    exe 'tabnew|file '.a:bufname
  endif
endfu

fu! s:find_buf(bufnr) abort
  for tabnr in range(1, tabpagenr('$'))
    if tabpagenr() == tabnr | continue | endif
    let buflist = tabpagebuflist(tabnr)
    if index(buflist, a:bufnr) >= 0
      for winnr in range(1, tabpagewinnr(tabnr, '$'))
        if buflist[winnr - 1] == a:bufnr | return [tabnr, winnr] | endif
      endfor
    endif
  endfor

  return []
endf

" Results bufname format getter
fu! s:bufname_fomat() abort
  if g:esearch_settings.regex
    if (&termencoding ==# 'utf-8' || &encoding ==# 'utf-8')
      " Since we can't use '/' in filenames
      return "Search:  \u2215%s\u2215%s"
    else
      return "Search: %%r{%s}%s"
    endif
  else
    return "Search: `%s`%s"
  endif
endfu
