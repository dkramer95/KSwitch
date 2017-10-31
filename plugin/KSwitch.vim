" KSwitch.vim
" Last Change: 10/31/17
" Maintainer: David Kramer
" Version: 1.0
"
" This plugin allows you view and switch between your open buffers in a
" side panel interface.
"
" This is very much a WIP!


" Prevent duplicate loading of this plugin
if exists("g:loaded_kswitch")
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


" === Implementation ===

" Toggles the KSwitch panel between showing / hidden
func! KSwitch#Toggle()
	if (s:kswitch_open != 0)
		call KSwitch#Close()
	else
		call KSwitch#Open()
	endif
endfunc

" Closes the KSwitch panel if not already closed
func! KSwitch#Close()
	if (s:kswitch_open == 0)
		" Already closed
		return
	endif
	execute "bd " . s:kswitch_buffer_name
	let s:kswitch_open = 0
endfunc

" Opens the KSwitch panel if not already open
func! KSwitch#Open()
	if (s:kswitch_open != 0)
		" Already open
		return
	endif

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
				\ | vertical resize " . g:kswitch_panel_width

	" Execute doesn't work properly w/ above.. Workaround is to use feedkeys
	call feedkeys(cmd . "\<CR>")
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
func! s:OpenBufferUnderCursor()
	echo "Not Implemented!"
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

" === Autocommmand Magic ===
augroup KSwitch
	autocmd!
	execute "autocmd! FileType " . s:kswitch_filetype .
			\" map <buffer> <CR> :call s:OpenBufferUnderCursor() <CR>"
augroup END


" We're finished loading
let g:loaded_kswitch = 1
