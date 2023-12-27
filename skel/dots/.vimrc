" .vimrc version 20231224

" #### WHEN STARTING/STOPPING

" ### FILES

" ## LOAD PLUGINS AUTOMATICALLY
" Use vim defaults (much better!) to load plugins by default
set nocompatible

" ## IGNORE MODELINES INSIDE OPENED FILES
" Prevent potential malicious modelines evaluations (default=5)
set modelines=0

" ## OPENING AND CLOSING FILES (:e, :n)

" When using :edit autocomplete, deprioritize files named with these extensions:
set suffixes=.aux,.bak,.dvi,.idx,.ps,.swp,.swo,.tar

" Automatically save modifications to files on :next
set autowrite

" ## KEEP BACKUPS AND UNDO ON A PER FILE BASIS

" In ~/.vim/ : backup swap undo .netrwhist
if !isdirectory($HOME."/.vim")
 call mkdir($HOME."/.vim", "", 0770)
endif

" In case of a crash, save a swapfile
if !isdirectory($HOME."/.vim/swap")
 call mkdir($HOME."/.vim/swap", "", 0700)
endif
set directory=~/.vim/swap

" In regular use, keep a per file undo history
if !isdirectory($HOME."/.vim/undo")
 call mkdir($HOME."/.vim/undo", "", 0700)
endif
set undodir=~/.vim/undo
set undofile

" After saving, backup the old file as file~
if !isdirectory($HOME."/.vim/backup")
  call mkdir($HOME."/.vim/backup", "", 0700)
endif
set backupdir=~/.vim/backup
set backup

" ## JUMP TO THE LAST KNOWN CURSOR POSITION
if has("autocmd")
" Not done if the position is invalid or when inside an event handler
" (happens when dropping a file on gvim).
autocmd BufReadPost *
 \ if line("'\"") > 0 && line("'\"") <= line("$") |
 \   exe "normal g`\"" |
 \ endif " if line

" ## KEEP PREVIOUS VERSIONS OF FILES
" WARNING: autocmd can confuse to busybox vi, always make it conditional
if has("autocmd")
" Can limit max files per day with .strftime("%F") or if per hour: %F.%H etc
" Use an extension to the buffer filename on open
"autocmd BufWritePre * let &bex = '~' . strftime("%F")
" On better, do that on write with the full recoded path
 autocmd BufWritePost * :silent! execute ':w! ' . &backupdir . "/" . substitute(escape(substitute(expand('%:p'), "/", "%", "g"), "%"), ' ', '\\ ', 'g') . '~' . strftime("%F.%H")
endif

" ### TERMINAL

" ## USE ALTERNATE SCREEN TO LEAVE A CLEAR SCREEN ON EXIT

" Either don't clear the screen upon exit
"set t_ti=
"set t_te=

" Or do not damage scrollback using the alternative screen buffer
"set t_ti=^[[?1049h
"set t_te=^[[?1049l

" Or by default, leave it to terminfo based on $TERM: check if the test fails:
" printf "Hello, \e[?1049h ABCDEFG \e[?1049l World\n"
"  as it can also be a (deprecated) variant of:
" printf "Hello, \e[[?47h ABCDEFG \e[2J\e[[?47l World\n"

" This is because ti clears memory before switching to the alternate screen.
" The older and deprecated \E[?47h did not do this, requiring applications to embed
" a \E[2J in the ti string which is called rmcup by terminfo.
" It's seen with $TERM=xterm-old where rmcup=\E[2J\E[?47l\E8, smcup=\E7\E[?47h
" set t_ti=^[7^[[r^[[?47h t_te=^[[?47l^[8

" ## SAVE POWER BY CHANGING THE CURSOR TO NOT BLINK

" When starting vi, based on the above, use a block curson
"let &t_ti.="\e[1 q" " blinking
let &t_ti.="\e[2 q"  " not blinking
"let &t_ti .= "\e[?2004h"
" When leaving vim likewise:
"let &t_te.="\e[0 q" " reset the cursor
let &t_te.="\e[2 q"  " block not blinking
"let &t_te = "\e[?2004l" . &t_te

" Then change cursor depending on mode:
" (can also use colors ex blinking orange)
" let &t_SI = "\e[5 q\e]12;orange\x7"

" Insert mode
let &t_SI.="\e[6 q"  " bar unblinking
"let &t_SI.="\e[5 q" " bar blinking
" Replace mode
let &t_SR.="\e[4 q"  " underline unblinking
"let &t_SR.="\e[3 q" " underline blinking
" Otherwise
let &t_EI.="\e[2 q"  " block unblinking
"let &t_EI.="\e[1 q" " unblinking

" vim supports modifyOtherKeys (dedicated section below)
"cf  https://vi.stackexchange.com/questions/27399/whats-t-te-and-t-ti-added-by-vim-8
" but foot needs a workaround for a vim bug to jump between prompts
"cf https://github.com/vim/vim/issues/9014
"cf https://codeberg.org/dnkl/foot/wiki#vim
" Vim thinks modifyOtherKeys level 2 is enabled, even when it's not
" The snippets below ensure modifyOtherKeys=2 is enabled.
if &term =~ "foot"
 let &t_TI = "\e[>4;2m"
 let &t_TE = "\e[>4;m"
endif

" ## SET THE TITLEBAR
" Filename associated with the current edit buffer in the xterm title
set title
let &titlestring = expand("%:t")

" #### BACKSPACE AND DELETE KEYS

" ### DELETE
" Make delete work by approximating the right sequence even without terminfo
set t_kD=^[[3~
" ...except in VT100 mode where it's Ctrl-?
if &term =~ "vt100"
 set t_kD=
endif

" ## SHIFT-DELETE
" Shift-Delete deletes to the end of the line like Ctrl-K
inoremap <S-DEL> <C-O>d$
noremap <S-DEL> d$
" Shift-Delete in foot, wezterm and others
inoremap <ESC>[3;2~ <C-O>d$
noremap <ESC>[3;2~ d$

" ## ALT-DELETE
" TODO: currently the same for Alt-Delete, change it?
inoremap <A-DEL> <C-O>d$
noremap <A-DEL> d$
" Alt-Delete in foot, wezterm and others
inoremap <ESC>[3;3~ <C-O>d$
noremap <ESC>[3;3~ d$

" ## CTRL-DELETE
" Make Ctrl-Delete delete next word
inoremap <ESC>[3;5~ <C-O>dw
" outside insert mode, delete the entire word
"noremap  <ESC>[3;5~    daw
" or delete from the cursor position
noremap  <ESC>[3;5~    dw
" Same for the variant for tmux and urxvt
inoremap <ESC>[3M <C-O>dw
"noremap  <ESC>[3M    daw
noremap  <ESC>[3M    dw
inoremap <ESC>[3^ <C-O>dw
"noremap  <ESC>[3^   daw
noremap  <ESC>[3^    dw

" ### BACKSPACE
" Make backspace work by approximating the right sequence even without terminfo
set t_kb=
if &term =~ "vt100"
" ...except in VT100 mode where it's Ctrl-H
set t_kb=
"else
"" but otherwise Ctrl-H is Ctrl-Backspace
"inoremap <C-H> <C-\><C-o>db
"noremap <C-H> bdw
endif

" Allow backspacing over everything in insert mode
" When backspacing, do not stop at \n: go to previous line if necessary
set backspace=indent,eol,start

" ## SHIFT-BACKSPACE
" Shift-Backspace deletes to the beginning of line like Ctrl-U
inoremap <S-BS> <C-O>d0
noremap <S-BS> d0

" ## ALT-BACKSPACE
" TODO: currently the same for Alt-Backspace, change it?
inoremap <A-BS> <C-O>d0
noremap <A-BS> d0
" Alt-Backspace for wezterm
inoremap <ESC><BS> <C-O>d0
noremap <ESC><BS> d0

" ## CTRL-BACKSPACE
" Ctrl-Backspace deletes previous word in insert mode.
" Outside a VT100, gives either Ctrl-_ or Ctrl-H
" To remain generic map both <C-BS> and <C-_> + test for vt100 above to also cover <C-H>
inoremap <C-BS> <C-\><C-o>db
inoremap <C-_> <C-\><C-o>db
" and in edit mode too
noremap <C-BS> bdw
noremap <C-_> bdw
" If this test doesn't work, see the modifyOtherKeys section below
"nnoremap <C-BS> <Cmd>echomsg 'C-BS was hit'<CR>

" #### MOKS, CONTROL KEYS AND SHORTCUTS

" ### MOKS SEQUENCES
" modifyOtherKeys allows to separate <C-i> from <Tab>, <M-h> from è etc
" and map shortcuts beyond C0 ie Ctrl-symbol with symbol outside @[\]^_space
"cf https://invisible-island.net/xterm/modified-keys.html
"cf https://invisible-island.net/xterm/manpage/xterm.html#VT100-Widget-Resources:modifyCursorKeys
" can see the exact mok sequence with a log file like 
"rm /tmp/logfile && vim --cmd "call ch_logfile('/tmp/logfile', 'w')" && vim /tmp/logfile
" cf https://groups.google.com/g/vim_dev/c/OwIDwziTHQ8

" ## CTRL-BACKSPACE NEEDS A SPECIAL CASE TO BACKWARD WORD DELETE
" Ctrl-Backspace with wezterm in vim: with Ctrl-Q Ctrl-Backspace vim sees ^H
" but in the logfile, Ctrl-BS really generates the MOK: ^[[27;5;8~
" So this doesn't works:
"nnoremap <C-BS> <Cmd>echomsg 'C-BS was hit'<CR>
" While this works:
"nnoremap <ESC>[27;5;8~ <Cmd>echomsg 'C-BS was hit'<CR>
" Not clear why C-BS doesn't work when C-; doesn't need the MOK:
" This works even if Ctrl-; ^[[27;5;59~ on my wezterm:
"nnoremap <C-;> <Cmd>echomsg 'C-; was hit'<CR>
" So start by a special case for remapping Ctrl-Backspace
nnoremap <ESC>[27;5;8~ bdw
inoremap <ESC>[27;5;8~ <C-\><C-o>db
" And don't fully trust the map of other shortcuts: test and document each MOK

" ## CTRL-SLASH NEEDS A SPECIAL CASE TO DO COMPOSE LIKE CTRL-K

" Remap the MOK for Ctrl-K to the Emacs-like kill to the EOL
" Ctrl-k is <ESC>[27;5;107~
"nnoremap <ESC>[27;5;107~ D
inoremap <ESC>[27;5;107~ <C-O>D
" Can then map some other MOK to achieve Ctrl-K compose function: here Ctrl-/
" Ctrl-/ is <ESC>[27;5;47~
"nnoremap <ESC>[27;5;47~ <C-K>
inoremap <ESC>[27;5;47~ <C-K>

" ## OTHERS ON A CASE-BY-CASE

" Ctrl-; mok is [27;5;59~
nnoremap <ESC>[27;5;59~ <Cmd>echomsg 'C-; was hit'<CR>
" Ctrl-' mok is [27;5;39~ but doesn't work
nnoremap <ESC>[27;5;39~ <Cmd>echomsg 'C-apostrophe was hit'<CR>
" Ctrl-\ mok is [27;5;92~
nnoremap <ESC>[27;5;92~ <Cmd>echomsg 'C-\ was hit'<CR>
" Ctrl-/ mok is [27;5;47~
"nnoremap <ESC>[27;5;47~ <Cmd>echomsg 'C-/ was hit'<CR>
" Ctrl-/ was mapped to compose

" Left available in C0: Ctrl-\, Ctrl-_ (maps to Ctrl-/), Ctrl-@

" ## SAVE CTRL- ORIGINAL FUNCTIONS BEFORE DEDUPED MAPPINGS

" Keep Ctrl-I/Ctrl-O to jump between previous edit positions (:change )
" Ctrl-I is confused with Tab, while Tab in normal mode is helpful for indent
"nnoremap <ESC>[27;5;105~ <Cmd>echomsg 'C-I was hit'<CR>
" This "saves" the function of C-I before adding a separate mapping to Tab
"cf https://vi.stackexchange.com/questions/16161/how-to-map-c-i-separate-from-tab
nnoremap <C-I> <C-I>

" Ctrl-O is working normally
"nnoremap <ESC>[27;5;111~ <Cmd>echomsg 'C-O was hit'<CR>

" ### SHORTCUTS

" Allow cursor keys within insert mode by timeout, cf timeoutlen ttimeoutlen
set esckeys

" ## BASH/READLINE LIKE HOME/END WORD/LINE DELETE LEFT/RIGHT CTRL-AESWUK

" Make Ctrl-A go to the beginning of the line
inoremap <C-A> <Home>
noremap <C-A> <Home>

" Make Ctrl-E go to the end of the line
inoremap <C-E> <End>
noremap <C-E> <End>

" Make Ctrl-S delete the next word, typically Esc-D equivalent to Alt-D in bash
inoremap <C-S> <C-O>dw
noremap  <C-S> daw

" Make Ctrl-W delete the previous work
inoremap <C-W> <C-\><C-o>dB
noremap <C-W> bdw

" Make Ctrl-K delete to the end of the line: D is a synonym of d$
" Vim default C-K was compose: remapping compose may need some MOK magic
" Add the following to have Ctrl-K work in edit mode even without MOK support
"inoremap <C-K> <C-O>D
noremap <C-K> D
" Could also use backspace as a compose key for accents/8 bits chars/unicode
"set digraph

" Make Ctrl-U delete to the beginning of the line
inoremap <C-U> <C-O>d0
noremap <C-U> d0

" WONTFIX: In Ctrl-K Ctrl-U, after Ctrl-K the cursor will end on (the left of)
" the current character so the current character won't be deleted, unlike bash
" This might be fixable by using c$ or C to go into insert mode but such a rare
" case could disrupt normal function that is more often needed

" ## WINDOWS-LIKE UNDO, REDO WITH CTRL-Z CTRL-Y

" CTRL-Z is Undo; not in cmdline though
noremap <C-Z> u
inoremap <C-Z> <C-O>u

" CTRL-Y tries to be Redo (although not repeat); not in cmdline though
" TODO: see how Ctrl-R does it to do the same (Ctrl-R is a better redo)
noremap <C-Y> <C-R>
inoremap <C-Y> <C-O><C-R>

" ## WINDOWS-LIKE MOVE WITH CTRL+ARROWS 

" Ctrl-Left|Right are mapped by default
" Ctrl-Home <ESC>[1;5H is already defined by default
" Likewise Ctrl-End <ESC>[1;5F is already defined by default
" If going to EOL instead of EOF is wanted, need settings like:
"inoremap <ESC>[1;5F <End>
"nnoremap <ESC>[1;5F <End>
""vnoremap <ESC>[1;5F <End>

" On MacOS, when Terminal.app has Option key being a Meta key
" Option-Left and Option-Right are mapped to the Emacs equivalents 
inoremap <ESC>f <C-Right>
nnoremap <ESC>f <C-Right>
inoremap <ESC>b <C-Left>
nnoremap <ESC>b <C-Left>
" Option-Up and Option-Down are not mapped

" Ctrl-Up|Down jump to the beginning or end of the paragraph:
" non repeatable version:
"inoremap <ESC>[1;5A <ESC><C-O>{<CR>i
"nnoremap <ESC>[1;5A <C-O>{
"inoremap <ESC>[1;5B <ESC><C-O>}<CR>i
"nnoremap <ESC>[1;5B <C-O>}
" repeatable version: needs h to go back one char
inoremap <ESC>[1;5A <ESC>{<CR>hi
nnoremap <ESC>[1;5A {
inoremap <ESC>[1;5B <ESC>}<CR>i
nnoremap <ESC>[1;5B }<CR>

" ## WINDOWS-LIKE SELECT WITH SHIFT+ARROWS

inoremap <S-right> <C-o>vw
nnoremap <S-right> vw
vnoremap <S-right> w
inoremap <S-left> <C-o>vb
nnoremap <S-left> vb
vnoremap <S-left> b
inoremap <S-Up> <C-o>v<Up>
nnoremap <S-Up> v<Up>
vnoremap <S-Up> <Up>
inoremap <S-Down> <C-o>v<Down>
nnoremap <S-Down> v<Down>
vnoremap <S-Down> <Down>

" ## ECLIPSE-LIKE ALT+ARROW MOVES THE SELECTED LINES OR THE CURRENT LINE
" in insert mode, just the current line, indented with ==
" gi moves to the last position and reenters insert mode
inoremap <A-Up> <Esc>:m .-2<CR>==gi
inoremap <A-Down> <Esc>:m .+1<CR>==gi
" otherwise move full lines of the selection even if not extends to begin/EOL
"  "==" can be used to "fix" identation, then gv for reselect in visual
nnoremap <A-Up> :m .-2<CR>==
nnoremap <A-Down> :m .+1<CR>==
vnoremap <A-Up> :m .-2<CR>==gv
vnoremap <A-Down> :m '>+1<CR>==gv
" this will move the whole word left and right
" # FIXME: should includes commas (etc) and only consider spaces boundaries
nnoremap <A-Left> bdwbP`[l
nnoremap <A-Right> bdwwP`[l
" eb instead of b necessary for right to repeat more than once
inoremap <A-Left> <Esc>ebdwbP`[li
inoremap <A-Right> <Esc>ebdwwP`[li
" this will move just the selection if it exists
"vnoremap <A-Left> dhPgvhoho
"vnoremap <A-Right> dpgvlolo
" # FIXME: trims following the selection, instead of rounding up to whole words
vnoremap <A-Left> dbP`[v`]
vnoremap <A-Right> dwhp`[v`]

" ## NOTEPAD++ LIKE CTRL+SHIFT+ARROW MOVES THE SELECTED BLOCK
" insert mode is useless: done by vnoremap
" so just "duplicate" alt functionality if no selection
inoremap <C-S-Down> <Esc>:m .+1<CR>==gi
inoremap <C-S-Up> <Esc>:m .-2<CR>==gi
" WARNING: wezterm remaps Ctrl+Shift+Up/Down for ActivatePaneDirection="Up|Down"
"cf https://wezfurlong.org/wezterm/config/default-keys.html
" Can avoid the errors on the first and last lines with MoveLineAndInsert()
"cf https://superuser.com/questions/1434741/vim-move-selection-up-down-with-ctrlshiftarrow
" if want to do only the full lines
"nnoremap <C-S-Up> :m '<,'>-2<CR>==
"nnoremap <C-S-Down> :m '<,'>+1<CR>==
" here different from the above: cuts the selection out of the line
" # FIXME: should keep the horizontal coordinate in case a line up or down is empty
nnoremap <C-S-Up> :m '<-2<CR>==
nnoremap <C-S-Down> :m '>+1<CR>==

"" this UP works alone + in repetitions
"vnoremap <C-S-Up> dkPV`]
"" but this DOWN only works if prefixed by UP the 1st time 
"vnoremap <C-S-Down> dpV`]
" better:
" this will move the selection if it exists
vnoremap <C-S-Up> dkP`[v`]
vnoremap <C-S-Down> djP`[v`]
" this will move the selection left and right if it exists
vnoremap <C-S-Left> dhPgvhoho
vnoremap <C-S-Right> dpgvlolo

" ## SUSE METHOD TO MAP EDIT AND KEYMAP KEYS
" Should keep it: wezterm home=OH end=OF as in the old xterm/kvt section

" Defaults from suse to try and get the correct main terminal type and edit keyss
if &term =~ "xterm"
 let myterm = "xterm"
else
 let myterm =  &term
endif
let myterm = substitute(myterm, "cons[0-9][0-9].*$",  "linux", "")
let myterm = substitute(myterm, "vt1[0-9][0-9].*$",   "vt100", "")
let myterm = substitute(myterm, "vt2[0-9][0-9].*$",   "vt220", "")
let myterm = substitute(myterm, "\\([^-]*\\)[_-].*$", "\\1",   "")

" Here we define the keys of the NumLock in keyboard transmit mode of xterm
" which misses or hasn't activated Alt/NumLock Modifiers.  Often not defined
" within termcap/terminfo and we should map the character printed on the keys.
if myterm == "xterm" || myterm == "kvt" || myterm == "gnome"
 " keys in insert/command mode.
 map! <ESC>Oo  :
 map! <ESC>Oj  *
 map! <ESC>Om  -
 map! <ESC>Ok  +
 map! <ESC>Ol  ,
 map! <ESC>OM  
 map! <ESC>Ow  7
 map! <ESC>Ox  8
 map! <ESC>Oy  9
 map! <ESC>Ot  4
 map! <ESC>Ou  5
 map! <ESC>Ov  6
 map! <ESC>Oq  1
 map! <ESC>Or  2
 map! <ESC>Os  3
 map! <ESC>Op  0
 map! <ESC>On  .
 " keys in normal mode
 map <ESC>Oo  :
 map <ESC>Oj  *
 map <ESC>Om  -
 map <ESC>Ok  +
 map <ESC>Ol  ,
 map <ESC>OM  
 map <ESC>Ow  7
 map <ESC>Ox  8
 map <ESC>Oy  9
 map <ESC>Ot  4
 map <ESC>Ou  5
 map <ESC>Ov  6
 map <ESC>Oq  1
 map <ESC>Or  2
 map <ESC>Os  3
 map <ESC>Op  0
 map <ESC>On  .
endif

" xterm but without activated keyboard transmit mode
" and therefore not defined in termcap/terminfo.
if myterm == "xterm" || myterm == "kvt" || myterm == "gnome"
 " keys in insert/command mode.
 map! <ESC>[H  <Home>
 map! <ESC>[F  <End>
 " Home/End: older xterms
 map! <ESC>[1~ <Home>
 map! <ESC>[4~ <End>
 " Up/Down/Right/Left
 map! <ESC>[A  <Up>
 map! <ESC>[B  <Down>
 map! <ESC>[C  <Right>
 map! <ESC>[D  <Left>
 " KP_5 (NumLock off) to Backspace
 "map! <ESC>[E  <BS>
 " KP_5 (NumLock off) to Insert
 map! <ESC>[E  <Insert>
 " PageUp/PageDown
 map <ESC>[5~ <PageUp>
 map <ESC>[6~ <PageDown>
 map <ESC>[5;2~ <PageUp>
 map <ESC>[6;2~ <PageDown>
 map <ESC>[5;5~ <PageUp>
 map <ESC>[6;5~ <PageDown>
 " keys in normal mode
 map <ESC>[H  0
 map <ESC>[F  $
 " Home/End: older xterms
 map <ESC>[1~ 0
 map <ESC>[4~ $
 " Up/Down/Right/Left
 map <ESC>[A  k
 map <ESC>[B  j
 map <ESC>[C  l
 map <ESC>[D  h
 " KP_5 (NumLock off) to Backspace
 "map <ESC>[E  d
 " KP_5 (NumLock off) to Insert
 map <ESC>[E  i
 " PageUp/PageDown
 map <ESC>[5~ 
 map <ESC>[6~ 
 map <ESC>[5;2~ 
 map <ESC>[6;2~ 
 map <ESC>[5;5~ 
 map <ESC>[6;5~ 
endif

" xterm/kvt but with activated keyboard transmit mode.
" Sometimes not (or wronglr) defined within termcap/terminfo.
if myterm == "xterm" || myterm == "kvt" || myterm == "gnome"
 " keys in insert/command mode.
 map! <ESC>OH <Home>
 map! <ESC>OF <End>
 map! <ESC>O2H <Home>
 map! <ESC>O2F <End>
 map! <ESC>O5H <Home>
 map! <ESC>O5F <End>
 " Cursor keys which mostly work by default
 " map! <ESC>OA <Up>
 " map! <ESC>OB <Down>
 " map! <ESC>OC <Right>
 " map! <ESC>OD <Left>
 map! <ESC>[2;2~ <Insert>
 map! <ESC>[2;5~ <Insert>
 map! <ESC>O2A <PageUp>
 map! <ESC>O2B <PageDown>
 map! <ESC>O2C <S-Right>
 map! <ESC>O2D <S-Left>
 map! <ESC>O5A <PageUp>
 map! <ESC>O5B <PageDown>
 map! <ESC>O5C <S-Right>
 map! <ESC>O5D <S-Left>
 " KP_5 (NumLock off) to Backspace
 "map! <ESC>OE <BS>
 " KP_5 (NumLock off) to Insert
 map! <ESC>OE <Insert>
 " keys in normal mode
 map <ESC>OH  0
 map <ESC>OF  $
 map <ESC>O2H  0
 map <ESC>O2F  $
 map <ESC>O5H  0
 map <ESC>O5F  $
 " Cursor keys which mostly work by default
 " map <ESC>OA  k
 " map <ESC>OB  j
 " map <ESC>OD  h
 " map <ESC>OC  l
 map <ESC>[2;2~ i
 map <ESC>[2;5~ i
 map <ESC>O2A  ^B
 map <ESC>O2B  ^F
 map <ESC>O2D  b
 map <ESC>O2C  w
 map <ESC>O5A  ^B
 map <ESC>O5B  ^F
 map <ESC>O5D  b
 map <ESC>O5C  w
 " KP_5 (with NumLock off) to Backspace
 " map <ESC>OE  d
 " KP_5 (with NumLock off) to Insert
 map <ESC>OE  i
endif

if myterm == "linux"
 " keys in insert/command mode.
 map! <ESC>[G  <Insert>
 " KP_5 (NumLock off)
 " keys in normal mode
 " KP_5 (NumLock off)
 map <ESC>[G  i
endif

" ### FUNCTIONS

" ## MOUSE-ENABLED VISUAL MODE 
" For terminal emulators with mouse support
behave xterm
set selectmode=mouse
" Disable vim automatic visual mode on mouse select
"set mouse-=a
" or keep visual mode but copy without the line numbers
set mouse=a
" Shift-Insert works like in Xterm
map <S-Insert> <MiddleMouse>
map! <S-Insert> <MiddleMouse>
" Hide the mouse pointer while typing
set mousehide

" ## SEARCH & REPLACE

" Show matches while incrementially searching
set incsearch
" Hilight search strings
set hlsearch
" Ignore the case in search patterns, required for smartcase
set ignorecase
" Default to ignore case, can restore with /searchsomething\c
set smartcase

" ## TAB INDENTS, SHIFT-TAB UNINDENTS

" Replace tab with softtabstop spaces for indentation (problematic for python)
"set expandtab
"Indent by 4 spaces when using >>, <<, == etc.
set shiftwidth=4
"Indent by 4 spaces when pressing <TAB>
set softtabstop=4
" could also set tabstop
"Keep indentation from previous line
set autoindent
" Off since I usually prefer perltidy
set noautoindent
"Automatically indents new lines based on old lines
set smartindent
"Like smartindent, but stricter and more customisable
set cindent

" Tab to indent and Shit-Tab to unindent
nmap <Tab> <C-g>>><CR>k
nmap <S-Tab> <C-g><<<CR>k
vmap <Tab> <Esc>:'<,'>>><CR>
vmap <S-Tab> <Esc>:'<,'><<<CR>

" ## COPY/CUT AND PASTE

" Due to remap of Ctrl-c and Ctrl-v to copy/paste
" can make Ctrl-q input chars like Ctrl-v did with:
"noremap! <C-Q>  <C-V>
" (but already setup by default, no need to redo it)

" Use system clipboard to yank from other applications in gvim
"set clipboard=unnamedplus
set clipboard=unnamed

" Paste from xterm by definining F28 and F29
function! XTermPasteBegin(ret)
 set pastetoggle=<f29>
 set paste
 return a:ret
endfunction

execute "set <f28>=\<Esc>[200~"
execute "set <f29>=\<Esc>[201~"
map <expr> <f28> XTermPasteBegin("i")
imap <expr> <f28> XTermPasteBegin("")
vmap <expr> <f28> XTermPasteBegin("c")
cmap <f28> <nop>
cmap <f29> <nop>

" # FIXME: add copy-paste for Xorg

" CTRL-C does copy in visual mode only (can also do xnoremap)
"vnoremap <C-C> "+y
" CTRL-X does cut in visual mode only
""vnoremap <C-X> "+x
" cut not to the default y/p buffer but to wl-copy
"vnoremap <C-X> :w !wl-copy<CR><CR>
" this can't work in range mode as :w doesn't support it
"vnoremap <C-X> :'<,'> w !wl-copy<CR><CR>
" silent version in line mode, without flashing enter
"vnoremap <silent> <C-X> :silent w !wl-copy<CR><CR>
" this requires pressing y first
"vnoremap <C-X> :call system("wl-copy", @")<CR><CR>
" so declare a function
function! WLCopy()
 " Save the unnamed register and its type.
 let last_yank = getreg()
 " Copy the selection.
 execute "normal! y"
 " Send it as-is, without --trim-newline
 call system("wl-copy", @")
endfunction
function! WLCut()
 " Save the unnamed register and its type.
 let last_yank = getreg()
 " Copy the selection.
 execute "normal! d"
 call system("wl-copy", @")
endfunction

" Copy
vnoremap <C-C> <CMD>call WLCopy()<CR>
vnoremap <C-X> <CMD>call WLCut()<CR>

" CTRL-V does Paste from wl-paste automatically
"nnoremap <silent> <C-v> :r !wl-paste<CR>
" so keep that for the console
nnoremap <C-V> P

" Separate the terminal copy-paste from vim own
"map <C-V>"+gP
"cmap <C-V><C-R>+

" Separate wayland cut-paste from vim: Ctrl-Insert paste and Shift-Delete cut
vnoremap <C-Insert> "+y
"vnoremap <S-Del> <CMD>call WLCut()<CR>
vnoremap <S-Del> "+x

" #### APPEARANCE AND INTERACTION

" ## MAIN WINDOW LOOKS

" Redraw the whole screen as needed, helps on android when not displaying
"if match ($LD_PRELOAD, "com.termux") != 0 
set ttyfast
"endif

" No beeps
set noerrorbells
set visualbell
set t_vb=

" Show line numbers, disable with :se nu!
set number

" Show relative number for inactive lines
set relativenumber

" Hilight the current line (and the line numbers)
set cursorline

" Show matching parenthesis
set showmatch

" always keep 2 lines of context at the bottom of screen
set scrolloff=2

" Disable line warping
set nowrapscan

" Make the text wrap to the next line when it is X letters from the end
"set wrapmargin=8

" Always limit the width of text
"set tw=72

" ## EDITION

" Insert two spaces after a period with every joining of lines
"set joinspaces

" Do not jump to first character with page commands
set nostartofline

" Moving left/right ignores the beginning/end of line to continue
set whichwrap=<,>,h,l,[,]

" Add the dash ('-'), the dot ('.'), and the '@' as "letters" to "words".
set iskeyword=@,48-57,_,192-255,-,.,@-@

"  Options for the "text format" command ("gq")
set formatoptions=cqrto

" ## SHOW COMMENTS IN ITALICS

" If Vim doesn't know the escape codes to switch to italic
let &t_ZH="\e[3m"
let &t_ZR="\e[23m"
" Italics pseudo-auto toggle: force italics if we recognize it's supported from TERM
if match($TERM, "xterm-256color-italic")==0
 highlight Comment cterm=italic
" For Windows-Terminal which supports italic, nothing is needed anymore even if not in TERM
"elseif match($TERM, "xterm-256color")==0
" highlight Comment cterm=italic gui=italic
elseif match($TERM, "tmux-sixel")==0
 highlight Comment cterm=italic
elseif match($TERM, "mintty")==0
 highlight Comment cterm=italic
endif

" ### AT THE TOP OF THE SCREEN: TABLINE

" Show on the left the timestamp + encoding, on the right the positions and format
"%{len(getbufinfo({'buflisted': 1}))}:%a
set tabline=%{g:gitbranch}%t%a\ %{FileData()}\ \%{&fenc==\"\"?&enc:&fenc}(%{&bomb})\ %{&ff==\"dos\"?\"CRLF\":\"LF\"}%=%{mode()}\ @(x:%03c/%03{virtcol('$')},y:%04l/%0L)\ =0x%02B\ @%08O\ %P
" Show the tabline; can hide it with: :set showtabline=0
set showtabline=2
" The tabline need an autocommand to be dynamic
if has("autocmd")
 autocmd CursorMoved * :redrawtabline
 " redraw it in insert mode too
 autocmd CursorMovedI * redrawtabline
endif

" ## GET INFORMATION ABOUT THE FILE FOR THE TABLINE
" Function to show the file name, creation date and git branch
function! FileData()
 " get the epoch
 let ftime=getftime(expand("%"))
 if ftime>0
  let msg=strftime("@%Y-%m-%d %H:%M:%S",ftime)
 else " if ftime
  " epoch<0 means the file doesn't exist
  let msg="(UNSAVED NEW FILE)"
 endif " if ftime
 return msg
endfunction

" ## READ THE GIT DATA MANUALLY
" Function to read git data manually directly (not recursive like gitbranch)
function! GetGitBranch()
 let fpath=expand("%:p:h")
 if filereadable(fpath . '/.git/HEAD')
 " silent! 
  let branch = get(readfile(fpath . '/.git/HEAD'), 0, '')
  if branch =~# '^ref: '
   let branchname= substitute(branch, '^ref: \%(refs/\%(heads/\|remotes/\|tags/\)\=\)\=', '', '')
  elseif branch =~# '^\x\{20\}'
   let branchname= branch[:6]
  endif " if branch
  if (strlen(branchname)>0)
   return "⎇  " . branchname . ":"
  endif " if strlen
 endif " if filereadable
" Default to an empty string instead of the integer 0
return ""
endfunction

" ## BUT READ THE GIT INFO JUST ONCE WHEN ENTERING THE BUFFER
" Call this function when entering a buffer to set a global variable
if has("autocmd")
 autocmd BufEnter * let g:gitbranch=GetGitBranch()
endif

" ### AT THE BOTTOM OF THE SCREEN: MINIMAL COMMANDLINE (NO STATUSLINE)

" Statusline with colors and display of options
" at the bottom of the screen?
"set statusline=%{FileData()}\ %{&fenc==\"\"?&enc:&fenc},%{&bomb}\%a%=\ %8l,%c%V/%L\ %{&ff==\"dos\"?\"CRLF\":\"LF\"}\ %P\ %08O:%02B

" Make command line two lines high
" set ch=2
" Always show status line, even for only one buffer.
"set laststatus=2
" Don't show anything and hide the line too
set laststatus=0
" Don't show the position of the cursor already show in the tabline
set noruler
"set ruler
" Don't show the mode either
set noshowmode
"set showmode
" Don't show the current uncompleted command either
set noshowcmd
"set showcmd

" Show commandline completion
set wildmenu

" Complete longest common string, then each full match like bash
"set wildmode=longest,full

" Hilight : 8b,db,es,hs,mb,Mn,nu,rs,sr,tb,vr,ws
"set highlight=8r,db,es,hs,mb,Mr,nu,rs,sr,tb,vr,ws

" Use magic patterns (extended regular expressions)
set magic

" The char used for "expansion" on the command line
set wildchar=<TAB>

" ### LIGHT OR DARK MODE

" ## CHOSE THE DEFAULT MODE BASED ON $TERM
" Leave the background and style autodetects on
if has('gui_running')
 set background=dark
 let g:solarized_style="dark"
" set guifont=Menlo\ Regular:h24
 set guifont=Monospace\ 13
else
 " for solarized, 256 color is better than nothing (ex: xterm-256color)
 " and avoids tweaking with the standard colors assignations
 " but worse than replacing the palette + can kill italics/bold/underline
 if match($TERM, "rxvt-unicode-256color")==0
  set background=dark
"  set background=light
"  let g:solarized_style="light"
  " Tweakings are required on Linux, but are better than 256 color fallback
"  let g:solarized_termcolors=256
  let g:solarized_termtrans = 1
  let g:solarized_termcolors=16
 elseif match($TERM, "rxvt-unicode")==0
" set background=light
  set background=dark
" let g:solarized_style="light"
  let g:solarized_termcolors=16
 elseif match($TERM, "xterm-256color-italic")==0
 " if used with mintty, need tweaking as the 256 colors fallback looks better
  set background=light
  let g:solarized_style="light"
  let g:solarized_termcolors=256
  " Using 256 colors kills italics without that
  let g:solarized_italic=1
  let g:solarized_bold=1
  let g:solarized_underline=1
  " when showing EOL with :set list
  let g:solarized_visibility="low"
  let g:solarized_hitrail=0
 elseif match($TERM, "xterm-256color")==0
 " This is the new TERM for Windows-Terminal
 " No tweakings required except the 256 color fallback to looks better:
 " it now answers to xterm send sequence attributes (send secondary DA)
 " https://github.com/microsoft/terminal/issues/5836
 " May also extend to vt240 extras with sixel support, cf current status
 " https://terminalnuget.blob.core.windows.net/packages/TerminalSequences.html
 " FIXME: should read current theme
 " ideally from a variable like https://github.com/microsoft/terminal/issues/4566
 " or using Get-WTTheme with PSWinTerminal.psd1
  set background=dark
  let g:solarized_style="dark"
"  set background=dark
"  let g:solarized_style="dark"
  let g:solarized_termcolors=256
  " when showing EOL with :set list
  let g:solarized_visibility="low"
  let g:solarized_hitrail=1
 elseif match($TERM, "xterm")==0
  " This is a wildcard match for xterm*
  set background=dark
  let g:solarized_style="dark"
  let g:solarized_termtrans = 1
  let g:solarized_termcolors=16
 elseif match($TERM, "screen")==0
  " This is for GNU screen
  let g:solarized_termtrans = 1
  let g:solarized_termcolors=16
  set background=dark
 elseif match($TERM, "sixel-tmux")==0
  " This is for sixel-tmux (with sixel derasterize)
  set background=light
  let g:solarized_style="light"
  let g:solarized_termcolors=256
  let g:solarized_italic=1
  let g:solarized_underline=1
  let g:solarized_visibility="low"
  let g:solarized_hitrail=1
 elseif match($TERM, "mintty")==0
  " This is mintty default
  set background=light
  let g:solarized_style="light"
  let g:solarized_termcolors=256
  let g:solarized_bold=1
  let g:solarized_underline=1
  let g:solarized_visibility="low"
  let g:solarized_hitrail=1
 elseif match($TERM, "cygwin")==0
  " This was the old TERM for Windows-Terminal
  set background=dark
  let g:solarized_style="dark"
  let g:solarized_termcolors=16
  let g:solarized_bold=1
  let g:solarized_underline=1
  let g:solarized_visibility="low"
  let g:solarized_hitrail=1
 elseif match($TERM, "foot")==0
  " This is for the foot terminal
  set background=light
  let g:solarized_style="lightdark"
  let g:solarized_termcolors=256
  let g:solarized_bold=1
  let g:solarized_underline=1
  let g:solarized_visibility="low"
  let g:solarized_hitrail=1
 endif " if match $TERM
endif " if has('guirunning

" ## OVERRIDE THE DEFAULT MODE WITH OTHER ENVIRONMENT VARIABLES
if match ($WEZTERM_CONFIG_FILE, "/home/charlotte/.config/wezterm/wezterm.lua")==0
 set background=dark
 let g:solarized_style="dark"
 let g:solarized_termcolors=256
 " when showing EOL with :set list
 let g:solarized_visibility="low"
 let g:solarized_hitrail=1
 set t_ti=
 set t_te=
endif
" Can override the default color by WT profile UUID
if match ($WT_PROFILE_ID, "{b9261ded-f302-4538-889e-665aef724946}")==0
 set background=light
 let g:solarized_style="light"
 let g:solarized_termcolors=256
 " when showing EOL with :set list
 let g:solarized_visibility="low"
 let g:solarized_hitrail=1
 set t_ti=
 set t_te=
endif
if match ($WT_PROFILE_ID, "{2c4de342-38b7-51cf-b940-2309a097f518}")==0
 set background=dark
 let g:solarized_style="dark"
 let g:solarized_termcolors=256
 " when showing EOL with :set list
 let g:solarized_visibility="low"
 let g:solarized_hitrail=1
"set t_ti=
"set t_te=
endif

" ### COLOR SETTING

if has("terminfo")
" set t_Co=8
 set t_Sf=[3%p1%dm
 set t_Sb=[4%p1%dm
 else
" set t_Co=8
 set t_Sf=[3%dm
 set t_Sb=[4%dm
endif

" Color interacts with set nolist matching below
if &t_Co > 1
 syntax on
endif

" ## FUNCTION TO HIGHLIGHT CSV FILES

" Hilight the nths column in csv text, 0=switch off
function! CSVHighlight(colnr)
 if a:colnr > 1
  let n = a:colnr - 1
  execute 'match Keyword /^\([^,]*,\)\{'.n.'}\zs[^,]*/'
  execute 'normal! 0'.n.'f,'
 elseif a:colnr == 1
  match Keyword /^[^,]*/
  normal! 0
 else
  match
 endif " if a:colnr
endfunction
command! -nargs=1 CsvHighlight :call CSVHighlight(<args>)

" ## FUNCTION TO CREATE A 'RAINBOW' INDENT (COLORED IN LIGHT MODE)
							
" use 256-colors.sh to pick, here we have shades of black + the usual rainbow
if !exists("g:rainbow_colors_black")
    let g:rainbow_colors_black= [ 234, 235, 236, 237, 238, 239 ]
endif
if !exists("g:rainbow_colors_color")
    let g:rainbow_colors_color= [226, 192, 195, 189, 225, 221]
endif

" use one of these unless specified otherwise
function! Rainbow_Enable() abort
	if !exists("w:ms")
		let w:ms=[]
	endif
        let g:rainbow_colors = ( &background == "dark"? g:rainbow_colors_black : g:rainbow_colors_color )
	if len(w:ms) == 0
		let groups = []
		for color in g:rainbow_colors
			let group = "colorgroup_".color
			execute "hi ".group." ctermbg=".color
			call add(groups, group)
		endfor
		let level = 0
		let maxlevel = 40
		let tab_pat = "\\zs\t\\ze"
		let tab_seq = ""
		let spc_in_tab = ""
		let spc_left = &tabstop
		while spc_left > 0
			let spc_in_tab = spc_in_tab . " "
			let spc_left = spc_left - 1
		endwhile
		let spc_pat = "\\zs" . spc_in_tab . "\\ze"
		let spc_seq = ""
		while level <= maxlevel
			let gridx = level % len(groups)
			" echom s:grs[gridx] . "   ^" . tabseq . pat
			let mtab = matchadd( groups[gridx] , "^" . tab_seq . tab_pat )
			call add(w:ms, mtab)
			let mspc = matchadd( groups[gridx] , "^" . spc_seq . spc_pat )
			call add(w:ms, mspc)
			let tab_seq = tab_seq . "\t"
			let spc_seq = spc_seq . spc_in_tab
			let level = level + 1
		endwhile
	endif
endfunction

function! Rainbow_Disable() abort
	if !exists("w:ms")
		let w:ms=[]
	endif
	if len(w:ms) != 0
		for m in w:ms
			call matchdelete(m)
		endfor
		let w:ms = []
	endif
endfunction

function! Rainbow_Toggle() abort
	if !exists("w:ms")
		let w:ms=[]
	endif
	if len(w:ms) == 0
		call Rainbow_Enable()
	else
		call Rainbow_Disable()
	endif
endfunction


" ## FUNCTIONS TO ALTER THE COLOR SCHEME

" on OLED screens, replace the ugly darkgrey with pitchblack
function! OLED_Black()
" override the grey of solarized dark to OLED black with:
 if match (&background, "dark")==0
  hi Normal ctermbg=16
  hi LineNr ctermbg=16
  hi CursorLine ctermbg=16
  hi TabLineFill ctermbg=16 ctermfg=244
  " and use a very visible color for mouse selection
  hi Visual ctermbg=9
 else
  set background=light
  let g:solarized_style="light"
"  let g:solarized_termcolors=256
  " Using 256 colors kills italics without the following:
  let g:solarized_italic=1
  let g:solarized_bold=1
  let g:solarized_underline=1
"  let g:solarized_visibility="high"
  let g:solarized_hitrail=1
 endif " if match (&background
endfunction

if has("autocmd")
 autocmd ColorScheme * call OLED_Black()
endif

" ## FUNCTIONS TO HILIGHTS CHARACTERS

" Show space errors and hilight invisible characters
function! Hilight_HiddenChars_Syntax()
 " supports: ada, c, chill, csc, forth, groovy, icon, java, lpc, mel, nqc, nroff, ora, pascal, plm, plsql, python and ruby
 let c_space_errors = 1
 let python_space_errors = 1

 " WARNING: SpecialKey highlighting overrules syntax highlighting
 " So if not using syntax, can better show hidden characters using different colors:
 " this is a tab a space a tab then h:	 	h
 " this is a tab a space a tab:	 	
 " this is a tab:	
 " this is a trailing space: 
 " this is a control-F: 
" this is a control-F then space an control-M:  

 syn match TabChar /\t/ containedin=ALL
 syn match TrailingSpaceChar " *$" containedin=ALL
 syn match NonBreakingSpaceChar "\%u00a0" containedin=ALL
 syn match ExtraWhitespace / \+\ze\t/ containedin=ALL
" syn match NonPrintableASCII /[^\x00-\x7F]/ containedin=ALL
 syn match NonPrintableASCII /[\x0C\x0E-\x1F\x7F-\x9F]/ containedin=ALL
 syn match ControlChars /[\x00-\x08]/ containedin=ALL
 syn match ControlChars /[\x00-\x08]/ containedin=ALL
endfunction

function! Hilight_HiddenChars_Color()
 if match(&background,"light") ==0
  highlight TabChar ctermbg=grey guibg=grey
  highlight TrailingSpaceChar ctermbg=grey guibg=grey
 else
  highlight TabChar ctermbg=8 guibg=grey
  highlight TrailingSpaceChar ctermbg=8 guibg=grey
 endif
 highlight NonBreakingSpaceChar ctermbg=red guibg=red
 highlight ExtraWhitespace ctermbg=red guibg=red
 highlight NonPrintableASCII ctermbg=red guibg=red
 highlight ControlChars ctermbg=blue guibg=blue
 highlight ControlChars ctermbg=blue guibg=blue
endfunction

" Automatically call these functions with autocmd
" (when toggling syntax with `:syntax off` or changing colors with :colorscheme)
if has("autocmd")
 autocmd Syntax * call Hilight_HiddenChars_Syntax()
 autocmd ColorScheme * call Hilight_HiddenChars_Color()
endif

" Avoid performance issue due to memory leaks as BufWinEnter commands are executed every time a buffer is displayed
" ie whenever loading files
if version >= 702
 autocmd BufWinLeave * call clearmatches()
endif

" ## F8 SHORTCUT TO TOGGLE LISTCHARS

" Default is off, `se list` to turn on and `se nolist` to turn off
" Traditional:
"set listchars=tab:»·space:_,trail:·,eol:¶
" Or cute with unicodes:
set listchars=tab:↹⇥,space:_,nbsp:␣,trail:•,extends:⟩,precedes:⟨,eol:↲
set showbreak=↪
inoremap <silent> <F8> <Esc>:set list!<CR>
noremap <silent> <F8> :set list!<CR>

" ## F9 SHORTCUT TO TOGGLE COLOR SCHEME

" Apply one of the packed default colorschemes at startup
"colorscheme slate
"colorscheme desert
"colorscheme wildcharm
"colorscheme habamax
" Or use the packed solarized color scheme
colorscheme solarized

function! Cycle_Colorscheme()
 if (strlen(g:colors_name)>0)
  if g:colors_name== "habamax"
"   set background=light
"   let g:solarized_style="light"
   set background=dark
   let g:solarized_style="dark"
"   let g:solarized_termcolors=256
   " Using 256 colors kills italics without the following:
   let g:solarized_italic=1
   let g:solarized_bold=1
   let g:solarized_underline=1
"   let g:solarized_visibility="high"
"   let g:solarized_visibility="low"
"   let g:solarized_hitrail=1
   colorscheme solarized
 elseif g:colors_name== "solarized"
   set background=light
   colorscheme quiet
   syntax on
   call Hilight_HiddenChars_Syntax()
   call Hilight_HiddenChars_Color()
"  elseif g:colors_name== "solarized"
  else
   set background=dark
   colorscheme habamax
   syntax on
   call Hilight_HiddenChars_Syntax()
   call Hilight_HiddenChars_Color()
  endif " if g:colors_name
 endif " if strlen
endfunction

" Hotkey to cycle through themes
inoremap <silent> <F9> <Esc>:call Cycle_Colorscheme()<CR>
noremap <silent> <F9> :call Cycle_Colorscheme()<CR>

" ## F10 SHORTCUT TO TOGGLE RAINBOW INDENT
inoremap <silent> <F10> <Esc>:call Rainbow_Toggle()<CR>
noremap <silent> <F10> :call Rainbow_Toggle()<CR>

" #### INSERT MODE SHORTCUTS

" ### ABBREVIATIONS AS Y

" Yruler : A "ruler" - nice for counting the length of words
iab Yruler  1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890

" Date
iab Ydate <C-R>=strftime("%Y-%m-%d %H:%M")<CR>

" ### FUNCTIONS  AS ,

" ,cel = "clear empty lines", but don't delete the lines
" delete the *contents* of all lines which contain only whitespace.
map ,cel :%s/^\s\+$//

" ,del = "delete 'empty' lines", don't don't delete empty lines
" delete all lines which contain only whitespace
map ,del :g/^\s\+$/d

" ,ksr = "kill space runs" to substitute >2 spaces by just 1 space
nmap ,ksr :%s/  \+/ /g
vmap ,ksr  :s/  \+/ /g

" ,Sel = "squeeze empty lines" to merge multiple purely empty lines in just 1
map ,Sel :g/^$/,/./-j

" ,Sbl = "squeeze blank lines" to merge empty lines (with spaces) into just 1
map ,Sbl :g/^\s*$/,/\S/-j


" ## DEFAULTS BY FILETYPE

augroup python
 au!
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set tabstop=4
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set softtabstop=4
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set shiftwidth=4
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set expandtab
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set autoindent
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set autoindent
 autocmd BufNewFile,BufReadPre,FileReadPre        *.py set fileformat=unix
" Not doing set textwidth=79
" autocmd WinEnter,VimEnter *.py :call rainbow#enable()
augroup END

augroup gzip
 au!
 autocmd BufReadPre,FileReadPre        *.gz set bin
 autocmd BufReadPost,FileReadPost      *.gz '[,']!gunzip
 autocmd BufReadPost,FileReadPost      *.gz set nobin
 autocmd BufReadPost,FileReadPost      *.gz execute ":doautocmd BufReadPost " .  expand("%:r")
" autocmd BufWritePost,FileWritePost    *.gz !mv <afile> <afile>:r
" autocmd BufWritePost,FileWritePost    *.gz !gzip <afile>:r
 autocmd FileAppendPre                 *.gz !gunzip <afile>
 autocmd FileAppendPre                 *.gz !mv <afile>:r <afile>
 autocmd FileAppendPost                *.gz !mv <afile> <afile>:r
 autocmd FileAppendPost                *.gz !gzip <afile>:r
augroup END

augroup bzip
 au!
 autocmd BufReadPre,FileReadPre        *.bz2 set bin
 autocmd BufReadPost,FileReadPost      *.bz2 '[,']!bunzip2
 autocmd BufReadPost,FileReadPost      *.bz2 set nobin
 autocmd BufReadPost,FileReadPost      *.bz2 execute ":doautocmd BufReadPost " .  expand("%:r")
 autocmd BufWritePost,FileWritePost    *.bz2 !mv <afile> <afile>:r
 autocmd BufWritePost,FileWritePost    *.bz2 !bzip2 <afile>:r
 autocmd FileAppendPre                 *.bz2 !bunzip2 <afile>
 autocmd FileAppendPre                 *.bz2 !mv <afile>:r <afile>
 autocmd FileAppendPost                *.bz2 !mv <afile> <afile>:r
 autocmd FileAppendPost                *.bz2 !bzip2 <afile>:r
augroup END

augroup html
" autocmd BufWritePost			*.html :!firefox -remote "reload()"
 autocmd BufEnter			*.html :noremap <F3> :!firefox -remote "openURL(file:%)"^M^M
 autocmd BufEnter			*.html :inoremap <F3> ^[^[:!firefox -remote "openURL(file:%)"^M^Ma
" autocmd BufWritePost			*.css :!firefox -remote "reload()"
 autocmd BufEnter			*.css :noremap <F3> :!firefox -remote "reload()"^M^M
 autocmd BufEnter			*.css :inoremap <F3> ^[^[:!firefox -remote "reload()"^M^Ma

augroup END

augroup cprog
 au!
" autocmd BufRead *       set formatoptions=tcql nocindent comments&
 autocmd BufRead *.c,*.h set formatoptions=croql cindent comments=sr:/*,mb:*,el:*/,://
augroup END

endif " has("autocmd")
