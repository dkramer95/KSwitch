" KSwitch.vim
" Last Change: 10/31/17
" Maintainer: David Kramer
" Version: 1.0
"
" This plugin allows you view and switch between your open buffers in a
" side panel interface.
"
" This is very much a WIP!


" Flag to allow reloading of script
let g:kswitch_debug_mode = 1

" Prevent duplicate loading of this plugin but also make sure we're not in
" debug mode, so as to prevent changes
if (exists("g:loaded_kswitch") && g:kswitch_debug_mode == 0)
	finish
endif

" === KSwitch Stuff ===

" Our buffer name
let s:kswitch_buffer_name = "@kswitch@"

" Do we have our special buffer open?.. Any non-zero value is true
let s:kswitch_open = 0

" Our special filetype that will be used for autocmd magic
let s:kswitch_filetype = "kswitch"

" Is our side panel visible?
let s:kswitch_visible = 0


" ===Configuration Options===

" The width of our side panel
let g:kswitch_panel_width = 30

" Where we want our panel to appear when we create it
let g:kswitch_panel_direction = "right"

nnoremap <F9> :call KSwitch#Toggle()<CR>


" === Implementation ===

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
	let buff_num = bufnr(s:kswitch_buffer_name)
	execute s:GetSplitCmd() . " sb" . buff_num
	let s:kswitch_visible = 1
endfunc


" Closes the KSwitch panel if not already closed
func! KSwitch#Close()
	if (!s:IsKSwitchOpen())
		return
	endif
	execute "bd " . s:kswitch_buffer_name
	let s:kswitch_open = 0
endfunc

" Opens the KSwitch panel if not already open
func! KSwitch#Open()
	" Get buffer listing before we create our kswitch buffer since it
	" shouldn't be visible in the list. Needs to be global to be accessible in
	" command below
	let g:kswitch_buffer_list = GetBuffListing()

	" Magical command that creates and sets up our buffer to the correct state
	let cmd = ":" . s:GetSplitCmd() . "new " . s:kswitch_buffer_name . "
				\ | put =g:kswitch_buffer_list
				\ | setl nomodifiable
				\ | setl buftype=nofile
				\ | setl filetype=" . s:kswitch_filetype . "
				\ | setl nowrap
				\ | setl nonumber | setl nornu
				\ | vertical resize " . g:kswitch_panel_width

	" Execute doesn't work properly w/ above.. Workaround is to use feedkeys
	call feedkeys(cmd . "\<CR>")
	let s:kswitch_visible = 1
	let s:kswitch_open = 1
endfunc

" Returns results from calling ':ls'
func! GetBuffListing()
	let data = ""
	redir => data
	silent ls <CR>
	redir END
	return data
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
		else
			echohl KSplitWarn | echo "Not a valid buffer!" | echohl None
		endif
	catch
			echohl KSplitError | echo "Error: " . v:exception | echohl None
	endtry
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
		echo "Not yet supported"
	elseif (direction == "up")
		echo "Not yet supported"
	elseif (direction == "right")
		let split_cmd = "vert rightb "
	else
		throw "Invalid direction config!"
	endif
	return split_cmd
endfunc

" Checks to make sure that we're really open! It's possible we could have been
" closed, without setting our custom flag
func! s:IsKSwitchOpen()
	return buflisted(s:kswitch_buffer_name) && s:kswitch_open != 0
endfunc

" Sets the special mappings for this
func! s:SetMappings()
	map <buffer> <CR> :call OpenBufferUnderCursor() <CR>
endfunc

" Sets our flag to closed
func! s:SetClosed()
	let s:kswitch_open = 0
endfunc

" Ensures that our window is resized
func! s:Resize()
	silent! execute "vertical resize " . g:kswitch_panel_width
endfunc

" Sets visible flag to zero, indiciating that we still exist but aren't
" currently visible
func! s:SetHidden()
	let s:kswitch_visible = 0
endfunc

" Ensures that we are really cleared out
func! s:Delete()
	let s:kswitch_open = 0
endfunc

" === Autocommmand Magic ===
augroup KSwitch
	autocmd!
	execute "autocmd! FileType " . s:kswitch_filetype . " call s:SetMappings()"
	execute "autocmd! BufHidden " . s:kswitch_buffer_name . " call s:SetHidden()"
	execute "autocmd! BufDelete " . s:kswitch_buffer_name . " call s:Delete()"
	execute "autocmd! BufWinEnter " . s:kswitch_buffer_name . " call s:Resize()"
augroup END


" Define custom styles for errors and such
highlight KSplitWarn term=bold ctermfg=16 ctermbg=221
highlight KSplitError term=bold ctermfg=16 ctermbg=160


" We're finished loading
let g:loaded_kswitch = 1