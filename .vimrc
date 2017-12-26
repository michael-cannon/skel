" An example for a vimrc file.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2008 Jul 02
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.vimrc
"	      for Amiga:  s:.vimrc
"  for MS-DOS and Win32:  $VIM\_vimrc
"	    for OpenVMS:  sys$login:.vimrc

" When started as "evim", evim.vim will already have done these settings.
if v:progname =~? "evim"
  finish
endif

" Use Vim settings, rather then Vi settings (much better!).
" This must be first, because it changes other options as a side effect.
set nocompatible

" allow backspacing over everything in insert mode
set backspace=indent,eol,start

if has("vms")
  set nobackup		" do not keep a backup file, use versions instead
else
  set backup		" keep a backup file
endif
set history=1000		" keep 50 lines of command line history
set ruler		" show the cursor position all the time
set showcmd		" display incomplete commands
set incsearch		" do incremental searching

" For Win32 GUI: remove 't' flag from 'guioptions': no tearoff menu entries
" let &guioptions = substitute(&guioptions, "t", "", "g")

" Don't use Ex mode, use Q for formatting
map Q gq

" CTRL-U in insert mode deletes a lot.  Use CTRL-G u to first break undo,
" so that you can undo CTRL-U after inserting a line break.
inoremap <C-U> <C-G>u<C-U>

" In many terminal emulators the mouse works just fine, thus enable it.
if has('mouse')
  set mouse=a
endif

" Switch syntax highlighting on, when the terminal has colors
" Also switch on highlighting the last used search pattern.
if &t_Co > 2 || has("gui_running")
  syntax on
  set hlsearch
endif

" Only do this part when compiled with support for autocommands.
if has("autocmd")

  " Enable file type detection.
  " Use the default filetype settings, so that mail gets 'tw' set to 72,
  " 'cindent' is on in C files, etc.
  " Also load indent files, to automatically do language-dependent indenting.
  filetype plugin indent on

  " Put these in an autocmd group, so that we can delete them easily.
  augroup vimrcEx
  au!

  " For all text files set 'textwidth' to 78 characters.
"  autocmd FileType text setlocal textwidth=78
"  autocmd FileType php setlocal textwidth=80
"  autocmd FileType sh setlocal textwidth=80

  " When editing a file, always jump to the last known cursor position.
  " Don't do it when the position is invalid or when inside an event handler
  " (happens when dropping a file on gvim).
  " Also don't do it when the mark is in the first line, that is the default
  " position when opening a file.
  autocmd BufReadPost *
    \ if line("'\"") > 1 && line("'\"") <= line("$") |
    \   exe "normal! g`\"" |
    \ endif

  augroup END

else

  set autoindent		" always set autoindenting on

endif " has("autocmd")

" Convenient command to see the difference between the current buffer and the
" file it was loaded from, thus the changes you made.
" Only define it when not defined already.
if !exists(":DiffOrig")
  command DiffOrig vert new | set bt=nofile | r # | 0d_ | diffthis
		  \ | wincmd p | diffthis
endif


" comprock edits
" @author Michael Cannon <mc@aihr.us>


set showmatch

" Set standard setting for PEAR coding standards
set tabstop=4
set shiftwidth=4

" Auto indent after a {
set smartindent

" Map <CTRL>-C .. B to run PHP parser check
map <C-P> :!/usr/bin/php -lf %<CR>

" Unix file format
set ff=unix

" Don't write backup file if vim is being called by "crontab -e"
au BufWrite /tmp/crontab.* set nowritebackup
au BufWrite /tmp/crontab.* set nobackup

" set UTF-8 encoding
set encoding=utf-8
set fileencoding=utf8
set fileencodings=ucs-bom,utf8,prc

" ignore whitespace in diffs
set diffopt+=iwhite

" abbreviation helpers
ab cbhd <?php<CR>/**<CR> SCRIPT_SUMMARY<CR><CR>@author Michael Cannon <mc@aihr.us><CR>/<CR><CR>?>
ab edp print_r(); echo "\n<br />"; echo '' . __LINE__ . ':' . basename( __FILE__ )  . "\n<br />"
ab edpb echo '<pre>'; debug_print_backtrace(); echo '</pre>'; echo "\n<br />"; echo '' . __LINE__ . ':' . basename( __FILE__ )  . "\n<br />"
ab edv var_dump(); echo "\n<br />"; echo '' . __LINE__ . ':' . basename( __FILE__ )  . "\n<br />"
ab eex exit( __LINE__ . ':' . basename( __FILE__ ) . " ERROR<br />\n" )
ab efl echo __LINE__ . ':' . basename( __FILE__ ) . '<br />'
ab efp print_r(func_get_args()); echo "\n<br />"; echo '' . __LINE__ . ':' . basename( __FILE__ )  . "\n<br />"
ab efv var_dump(func_get_args()); echo "\n<br />"; echo '' . __LINE__ . ':' . basename( __FILE__ )  . "\n<br />"
ab errl error_log( __LINE__ . ':' . basename( __FILE__ ) )
ab errp error_log( print_r( , true ) . ':' . __LINE__ . ':' . basename( __FILE__ ) )
ab erra error_log( print_r( func_get_args(), true ) . ':' . __LINE__ . ':' . basename( __FILE__ ) )
ab errv error_log( var_export( , true ) . ':' . __LINE__ . ':' . basename( __FILE__ ) )
ab t3dd t3lib_utility::debug( $var, __LINE__ . ':' . basename( __FILE__ ) )
ab t3df t3lib_div::devLog( true, __FUNCTION__, 0, func_get_args() )
ab t3dl t3lib_div::devLog( true, __FUNCTION__, 0, false )
ab t3dr t3lib_utility::debugRows( $rows, __LINE__ . ':' . basename( __FILE__ ) )
ab t3dv t3lib_div::devLog( var_export( $, true ), __FUNCTION__, 0, false )
ab wpddb define('WP_DEBUG', true);<CR>define('WP_DEBUG_LOG', true);<CR>define('WP_DEBUG_DISPLAY', false)
ab wpdm if ( get_mbi_options( 'debug_mode' ) ) {<CR>print_r(); echo '<br />'; echo '' . __LINE__ . ':' . basename( __FILE__ )  . '<br />';<CR>}
ab wpidb if ( defined( 'WP_DEBUG' ) && WP_DEBUG ) {<CR>}
ab jsdb console.log();


set showmode
set binary noeol
"colorscheme default
colorscheme murphy

if has("win32")
	if has("gui_running")
		" Windows
		set backupdir=C:\tmp
		set directory=C:\tmp
		set guifont=Courier_New:h11
		set guifontwide=NSimsun:h11
	endif
else
	" *nix
	set backupdir=/tmp
	set directory=/tmp
endif

" syntax helpers
au BufNewFile,BufRead jquery.*.js setlocal ft=javascript syntax=jquery
au BufNewFile,BufRead mozex.textarea.* setlocal filetype=typoscript
" au BufNewFile,BufRead *.ts setlocal filetype=typoscript
au BufNewFile,BufRead *.ts setlocal filetype=javascript tabstop=2
au BufNewFile,BufRead *.js setlocal filetype=javascript tabstop=2
au BufRead,BufNewFile *.php setlocal ft=php syntax=php

set gfn=Monaco:h13

" for presentations
" colorscheme delek

if &diff
	" diff mode
	set diffopt+=iwhite
endif

" yank to clipboard
" if has("clipboard")
" 	set clipboard=unnamed " copy to the system clipboard
" 
" 	if has("unnamedplus") " X11 support
" 		set clipboard+=unnamedplus
" 	endif
" endif
