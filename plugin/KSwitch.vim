" ============================================================================
" KSwitch.vim
" Last Change: 03/08/18
" Maintainer: David Kramer
" Version: 1.0
"
" This plugin allows you view and switch between your open buffers in a
" side panel interface.
"
" ============================================================================
"
" SECTION: Script init stuff {{{1

" Flag to allow reloading of script
let g:kswitch_debug_mode = 0

" Prevent duplicate loading of this plugin but also make sure we're not in
" debug mode, so as to prevent changes
if (exists("g:loaded_kswitch") && g:kswitch_debug_mode == 0)
	finish
endif

" SECTION: Internal KSwitch Stuff {{{2

" Our buffer name
let s:kswitch_buffer_name = "[kswitch]"

" Do we have our special buffer open?.. Any non-zero value is true
let s:kswitch_open = 0

" Our special filetype that will be used for autocmd magic
let s:kswitch_filetype = "kswitch"

" Is our side panel visible?
let s:kswitch_visible = 0

" Buffer number associated with KSwitch that will be assigned on first open
let s:kswitch_buf_nr = -1

" SECTION: KSwitch Configuration Variables {{{3

" The width of our side panel
let g:kswitch_panel_width = 30

" Where we want our panel to appear when we create it
let g:kswitch_panel_direction = "left"

" Dismiss kswitch after a selection has been made?
let g:kswitch_auto_hide = 1

" Close out vim if all buffers have been closed
let g:kswitch_close_vim_if_no_buffers = 1

" Mapping to open / close KSwitch
map <F9> :KSwitchToggle<CR>

" SECTION: KSwitch Commands {{{4

command! KSwitchToggle call KSwitch#Toggle()
command! KSwitchClose call KSwitch#Close()


" SECTION: Public Commands {{{5

" Toggles the KSwitch panel between showing / hidden
func! KSwitch#Toggle()
	if (s:IsKSwitchOpen())
		" Open, but hidden
		if (s:kswitch_visible == 0)
			call KSwitch#Unhide()
		else
			call KSwitch#Close()
		endif
	else
		call KSwitch#Open()
	endif
endfunc

" Unhides the buffer.. Typically used if closed by other means than our own
" functions
func! KSwitch#Unhide()
	" let buff_num = bufnr(s:kswitch_buffer_name)
	execute s:GetSplitCmd() . " sb" . s:kswitch_buf_nr
	let s:kswitch_visible = 1
endfunc


" Closes the KSwitch panel if not already closed
func! KSwitch#Close()
	if (!s:IsKSwitchOpen())
		return
	endif
	execute "bd " . s:kswitch_buf_nr
	let s:kswitch_open = 0
endfunc

" Opens the KSwitch panel if not already open
func! KSwitch#Open()
	" Get buffer listing before we create our kswitch buffer since it
	" shouldn't be visible in the list. Needs to be global to be accessible in
	" command below
	let g:kswitch_buffer_list = GetBuffListing()

	" Update how many lines there are in listing
	let s:kswitch_line_count = GetLineCount(g:kswitch_buffer_list)

	" Magical command that creates and sets up our buffer to the correct state
	let cmd = ":" . s:GetSplitCmd() . "new " . s:kswitch_buffer_name . "
				\ | put =g:kswitch_buffer_list
				\ | setl nomodifiable
				\ | setl buftype=nofile
				\ | setl filetype=" . s:kswitch_filetype . "
				\ | set nobuflisted
				\ | setl nowrap
				\ | setl nonumber | setl nornu
				\ | ". s:GetResizeCmd() "

	" Execute doesn't work properly w/ above.. Workaround is to use feedkeys
	call feedkeys(cmd . "\<CR>")
	let s:kswitch_visible = 1
	let s:kswitch_open = 1

	if (s:kswitch_buf_nr < 0)
		" Add 1 to work around fact bufnr('$'') isn't on the kswitch buffer
		let s:kswitch_buf_nr = bufnr("$") + 1
	endif
endfunc

func! KSwitch#OpenBuff()
	call OpenBufferUnderCursor()
endfunc

func! KSwitch#SplitBuff()
	call SplitBufferUnderCursor()
endfunc

func! KSwitch#VSplitBuff()
	call VertSplitBufferUnderCursor()
endfunc

func! KSwitch#CloseBuff()
	call CloseBufferUnderCursor()
endfunc

func! KSwitch#Refresh()
	call s:Refresh()
endfunc


" SECTION: Internal Helper Functions {{{6

" Returns results from calling ':ls'
func! GetBuffListing()
	let data = ""
	redir => data
	silent ls <CR>
	redir END
	return data
endfunc

" Split data by new line and returns the count of lines
func! GetLineCount(data)
	let values = split(a:data, "\n")
	let line_count = len(values)
	return line_count
endfunc

" Internal functions that shouldn't be called elsewhere
func! OpenBufferUnderCursor()
	let last_buffer = winbufnr(winnr("#"))
	let current_line = getline(".")
	let match = matchstr(current_line, "\\d", 0)
	try
		let buff_num = str2nr(match)

		" Buffers start at 1, so we if we get anything else its a lie!
		if (buflisted(buff_num) && buff_num > 0)
			" Go to previous window and edit buffer
			silent! call feedkeys("\<C-w>p:b" . buff_num . "\<CR>")
			call s:AutoDismiss()
		else
			echohl KSplitWarn | echo "Not a valid buffer!" | echohl None
		endif
	catch
			echohl KSplitError | echo "Error: " . v:exception | echohl None
	endtry
endfunc


" Create a split of the buffer that is under cursor in kswitch
func! SplitBufferUnderCursor()
	call s:SplitBufferUnderCursor("split")
endfunc

" Create a vertical split of the buffer that is under cursor in kswitch
func! VertSplitBufferUnderCursor()
	call s:SplitBufferUnderCursor("vsplit")
endfunc

" Splits buffer under cursor w/ specified splitType: 'split' or 'vsplit'
func! s:SplitBufferUnderCursor(splitType)
	let buff_num = GetBufferNumUnderCursor()
	if (buflisted(buff_num))
		" Move to previous window, then vsplit
		call feedkeys("\<C-w>p :" . a:splitType . " #" . buff_num . "\<CR>")
		call s:AutoDismiss()
	endif
endfunc

" Closes the buffer that is under cursor in kswitch
func! CloseBufferUnderCursor()
	let buff_num = GetBufferNumUnderCursor()
	if (buflisted(buff_num))
		try
			execute "bd" . buff_num
			call s:Refresh()
		catch /^Vim\%((\a\+)\)\=:E89/
			let buff_name = bufname(buff_num)
			let msg = "Unable to close [" . buff_name . "] due to unsaved changes!"
			echohl KSplitWarn | echo msg | echohl None
		endtry
		" If we close all the buffers, quit vim
		if (g:kswitch_close_vim_if_no_buffers != 0 && GetBuffListing() == "")
			call s:QuitVim()
		endif
	endif
endfunc

" Returns the buffer number that is under the cursor. If cursor is not on
" a buffer (i.e. empty line), it returns -1
func! GetBufferNumUnderCursor()
	let last_buffer = winbufnr(winnr("#"))
	let current_line = getline(".")
	let match = matchstr(current_line, "\\d", 0)
	let buff_num = -1

	try
		let buff_num = str2nr(match)
		" Ensure buff_num is valid and exists
		if (!buflisted(buff_num) || buff_num <= 0)
			buff_num = -1
		endif
	catch
		" Silently ignore since error just indicates non-existent buffer
	endtry
	return buff_num
endfunc

func! s:QuitVim()
	call feedkeys(":q\<CR>")
endfunc

" Auto close kswitch if that option is set
func! s:AutoDismiss()
	if (g:kswitch_auto_hide != 0)
		call KSwitch#Close()
	endif
endfunc

" Helper function that creates the proper command for splitting based on our
" configuration option.
func! s:GetSplitCmd()
	let direction = tolower(g:kswitch_panel_direction)
	let split_cmd = ""

	" Trailing space on split_cmd intentional and needed!
	if (direction == "left")
		let split_cmd = "vert lefta "
	elseif (direction == "down")
		let split_cmd = "below "
	elseif (direction == "up")
		let split_cmd = "lefta "
	elseif (direction == "right")
		let split_cmd = "vert rightb "
	else
		throw "Invalid direction config!"
	endif
	return split_cmd
endfunc

func! s:GetResizeCmd()
	let direction = tolower(g:kswitch_panel_direction)
	let resize_cmd = ""

	" Trailing space on resize_cmd intentional and needed!
	if (direction == "left" || direction == "right")
		let resize_cmd = "vertical resize " . g:kswitch_panel_width
	elseif (direction == "down" || direction == "up")
		let resize_cmd = "resize " . s:kswitch_line_count
	else
		throw "Invalid direction config!"
	endif
	return resize_cmd
endfunc

" Checks to make sure that we're really open! It's possible we could have been
" closed, without setting our custom flag
func! s:IsKSwitchOpen()
	return s:kswitch_open != 0 && s:kswitch_buf_nr > 0
endfunc

" Sets the special mappings for kswitch buffer
func! s:SetMappings()
	map <buffer> <silent> <CR> :call KSwitch#OpenBuff() <CR>
	map <buffer> <silent> q :call KSwitch#Close() <CR>
	map <buffer> <silent> r :call KSwitch#Refresh() <CR>
	map <buffer> <silent> s :call KSwitch#SplitBuff() <CR>
	map <buffer> <silent> v :call KSwitch#VSplitBuff() <CR>
	map <buffer> <silent> x :call KSwitch#CloseBuff() <CR>
endfunc

" Sets our flag to closed
func! s:SetClosed()
	let s:kswitch_open = 0
endfunc

" Ensures that our window is resized
func! s:Resize()
	silent! execute "vertical resize " . g:kswitch_panel_width
endfunc

" Sets visible flag to zero, indicating that we still exist but aren't
" currently visible
func! s:SetHidden()
	if (s:IsCurrentBufferKSwitch())
		let s:kswitch_visible = 0
	endif
endfunc

" Refreshes the buffer listings in kswitch
func! s:Refresh()
	" Ensure we only refresh contents of our kswitch buffer
	if (s:IsCurrentBufferKSwitch())
		let kswitch_buffer_list = GetBuffListing()

		" Temporarily allow modifications and clear out existing
		setl modifiable
		normal Gdgg

		" Add new buffer listings and lock further modifications
		put =kswitch_buffer_list
		setl nomodifiable

		call s:Resize()
	endif
endfunc

" Returns true if current buffer is of type kswitch
func! s:IsCurrentBufferKSwitch()
	return &filetype == s:kswitch_filetype
endfunc


" SECTION: Autocommand Magic {{{7

augroup KSwitch
	autocmd!
	execute "autocmd! FileType " . s:kswitch_filetype . " call s:SetMappings()"
	execute "autocmd! WinEnter,BufWinEnter * call s:Refresh()"
	execute "autocmd! BufHidden * call s:SetHidden()"
augroup END


" SECTION: Highlight Styles {{{8

" Define custom styles for errors and such
highlight KSplitWarn term=bold ctermfg=16 ctermbg=221
highlight KSplitError term=bold ctermfg=16 ctermbg=160


" SECTION: Post Source {{{9
" We're finished loading
let g:loaded_kswitch = 1
