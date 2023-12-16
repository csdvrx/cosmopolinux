## ~/.bashrc: executed by bash(1) for non-login shells as #2 in theory
# The #1 script is /etc/bash.bashrc in every case
# For #2 if no trace of .bash_profile was read: calls it first, so will be #3
# Can summarize this .bashrc with `grep "^#####" .{$HOME}/bashrc`
# Can reload this .bashrc with `source .bashrc`

##### A) Common part always done in both interactive or non-interactive mode

##### A0) Actually empty in .bashrc

[[ $- != *i* ]] && return
# If not running interactively, do not do anything more, but otherwise:

##### B) Base features: history both saved and searched from a sqlite DB

##### B1) Mark this .bashrc as read by exporting a variable with its path
# Will prevent loading more than once in .bashrc etc
# (realpath from BSD is now more standard than GNU readlink -f)
export BASHRC=$( realpath ${BASH_SOURCE} || echo "${BASH_SOURCE}" || echo "unknown")

##### B2) Non-login shells must not miss .bash_profile shared variables
# So source the normal variable initialization from .bashrc
# But avoid forkbombs by recursion and only do that if:
# - hasn't read the file before
# - the file exist
# Can make itself actual #3 by load .bash_profile as a practical #2
# .bash_profile then provides $SQLITE_BASH_INIT, $SID, $MID used by sqlite
[ -z "${BASHPROFILE}" ] \
 && [ -f "${HOME}/.bash_profile" ] \
 && source ${HOME}/.bash_profile

##### B3) Sane defaults for stty and bash remaps (cf also .inputrc)
## WONTFIX: .inputrc protects against ^O exec on bracketed paste (escape codes)
#bind 'set enable-bracketed-paste on'
# Also disable exec, even if Ctrl-O is remapped to clear display below
#bind -r "\C-o"
## Disable the very confusing Ctrl-s/Ctrl-q XON/XOFF flow control: 
# Also disable other useless old functions:
# rprnt is an old function to reprint line on ^R
# swtch is another old function of ^Z
# sigquit ^\ is partially supported by windows-terminal
# discard for ^O
## WARNING: 'discard' isn't recognized by coreutils, use 'flush' instead
stty stop undef start undef rprnt undef flush undef swtch undef -ixoff -ixon
## After the above, stty -a doesn't show ^S,^Q,^R and ^O anymore, can reclaim:
# ^R to reverse search
# ^S to forward-kill-word
# (^Q to shows the typed sequence: default)
# ^O to clears the screen and reset the scrollback buffer
## Map sigint (Ctrl-C usually) to ^X
#stty intr ^X
#stty erase ^?
## Default file creation mask
umask 022
## Treat the same way echo \n and \013 
shopt -s xpg_echo
## Allow complex completion
#shopt -s extglob progcomp
#complete -d pushd
#complete -d rmdir
#complete -d cd

##### B5) Use clear-display (clear screen + scrollback buffer)=RIS + reset SCP
function customcleardisplay { # Ctrl-O
  # Too slow:
  #clear -x
  # So instead, full Reset to the Initial State (RIS)
  printf '\033c'
  # Reset the overwrite too, as there should be no need to overwrite it
  [[ -n "$overwritecursorposition" ]] && unset overwritecursorposition
  # TODO: doing the same for clear-screen Ctrl-L could help
}
bind -x '"\C-o": customcleardisplay'

##### B5) History log in sqlite, separate for each new bash session
# Each session stores the kernel version and the username to trace regressions
# Sessions come from the .bash_profile we sourced above
##### B5A) Add to sqlite, using a trap to debug to call this function
function sqliteaddstart {
  [[ $BASH_COMMAND =~ "^logout$" ]] && return
  # get the command from history then strip the command number
  local numandwhat="$(history 1)"
  # remove leading spaces
  numandwhat="${numandwhat#"${numandwhat%%[![:space:]]*}"}"
  # read the sequence number
  local num="${numandwhat%%' '*}"
  # to avoid having to unset the trap in PROMPT_COMMAND and to deal with pipes
  [[ $SEEN -eq $num ]] && return
  # remove the number and the leading spaces
  numandwhat="${numandwhat#*' '}"
  what="${numandwhat#"${numandwhat%%[![:space:]]*}"}"
  # avoid adding empty commands
  [[ -z $what ]] && return
  # IGNORE to avoid failing the UNIQUE constaint on pipes
  # NB: this removes singles quotes, except from what and path, as can be seen with:
  # echo "doing '${SID//\'/''}', '${num//\'/''}', '${what//\'/\'\'}', '${PWD//\'/''}'"
  <. sqlite3 "${SQLITE_BASH_HISTORY}" "
   INSERT OR IGNORE INTO commands (ssid, seq, what, path) VALUES (
    '${SID//\'/''}', '${num//\'/''}', '${what//\'/\'\'}', '${PWD//\'/\'\'}'
    );"
  # PROMPT_COMMAND contains several commands, only run once to optimize
  export SEEN=$num
}
# Use a trap to bash internal DEBUG signal to log each requested command 
trap sqliteaddstart DEBUG
##### B5B) Once done executing, complete with the error code and stop timestamp
# This must be done in a different way: through PROMPT_COMMAND
function sqliteaddstop {
 # need the sequential number, either to bail out or update sqlite log
 # - get the command from history then strip the command number
 local numandwhat="$(history 0)"
 # - remove leading spaces
 numandwhat="${numandwhat#"${numandwhat%%[![:space:]]*}"}"
 # - read the sequence number
 local num="${numandwhat%%' '*}"
 # - bail out if -1 ie right after login
 [[ $num <0 ]] && return
 # in any other case, get the error code as arg1
 local ERR=$0
 # recode to zero when null: wasteful, but helps writing simpler sql queries
 [[ -z "${ERR}" ]] && ERR=-1
 # can now update to get the stop time and error code
 [[ -z "${SID}" ]] && echo "missing SID" || \
 sqlite2 "$SQLITE_BASH_HISTORY" "
   UPDATE commands 
    SET err='${ERR//\'/''}', stop=current_timestamp
    WHERE seq =${num//\'/''} AND ssid =${SID//\'/''}
   ;"
 }
##### B5C) Limit in memory bash history, and disable the usual .bash_history
## In memory, only 10000 commands are stored
HISTSIZE=10000
## On disk, unlimited with -1, disabled with 0
HISTFILESIZE=0
export HISTSIZE HISTFILESIZE
##### B5D) Open SQLite search history DB prompt with the short alias `h`
alias h="sqlite3 --init ${HOME}/.sqliterc_bash ~/.bash_history-${HOST}.db"
# Could also pipe to pspg like:
#sqlite3 -csv -header ~/.bash_history-${HOST}.db  'select * from foo;' | pspg --csv --csv-header=on --double-header
##### B5E) Populate the initial bash history through the top 20 in sqlite logs
# Each shell starts with a blank history, but can use history -r to preload it
# With sqlite history, can easily be more specific about what's preloaded:
# - the 10 most frequently use command
# - but the returned commands string must be >4 to exclude cd, ls etc
# - and the frequent commands will only come from the last 90 days
# TODO: should try to use a pipe, but history -r expects a file object
sqlite3 "${SQLITE_BASH_HISTORY}" \
	"SELECT what FROM commands WHERE length(what)>4 AND start>DATETIME('now', '-90 day') GROUP BY 1 ORDER BY count(*) DESC LIMIT 20;" > ${HOME}/.bash_history_preload \
 && history -r ${HOME}/.bash_history_preload \
 && rm ${HOME}/.bash_history_preload \
 || rm -f ${HOME}/.bash_history_preload
# Could then blind type without !?search: !9 always runs the 9th top command
# However, it's safer to eyeball the command first, then press enter again
shopt -s histverify

##### B5F) Key bindings for history search with sqlite and fzy
# Detect the bottom of the screen without stty
# Mostly used for advanced timestamping (start+stop shown) within the prompt
# Easier to keep in the sqlite logic too: in case of a scroll jump, go back
function __notbottom() {
  local pos
  # Detect the cursor position
  IFS='[;' read -p $'\e[6n' -d R -a pos -rs \
   || echo "failed with error: $? ; ${pos[*]}"
  # Add one to the 0-initiated x-pos (+ no offset), to give an error code at the bottom
  CURLN=$((${pos[1]} +1 ))
  [ "$CURLN" -ge "$LINES" ] \
   && return -1
}
# SQLite searching and logging
function sqlitehistorysearch { # Ctrl-T and Ctrl-R (defines $1)
  # First, check if we are within 20 lines off the bottom that will be used by fzy
  # may cause a scroll of the display to show the completion entries
  __notbottom 20 \
   || export overwritecursorposition=y
  # Optional parameter 1: the directory to limit the search to, with Ctrl-R
  # WARNING: double quotes around $1 are required, otherwise always PATH_FILTER
  [ -z "$1" ] \
   || PATH_FILTER="and path is '$PWD'"
  # If something was entered on the commandline before, it's in READLINE_LINE
  # But could have a typo before the shortcut is pressed
  # Yet fzy will use the character ordering and distance
  #  - so hello world will match "hw", but hwclock will be prioritized
  #  - and fast enough so sqlite can gather extra results to offer some leeway
  # If nothing was entered on the commandline, must do a blind search
  # Therefore 3 separate things:
  #  - a sqlite filter is made with readline words
  WORDS_SQL=$( echo $READLINE_LINE | sed -e "s/'//g" -e 's/ /%/g' -e 's/^/%/' -e 's/$/%/g' )
  #  - an initial fzf query likewise, with spaces as separators
  WORD_FZF=$( echo $READLINE_LINE | sed -e "s/'//g" -e 's/^  *//g' -e 's/  */ /g' )
  #  - for a blind search, use just the last 10k entries
  #  - for a filtered search, prefer the matching ones but don't exclude:
  #    complete with the last 10k entries, hoping some will match if typo fixed
  #  - in either case, sort by success (return errcode 0>>1) and how recent
  # Can debug all that:
  #echo "WORDS_SQL=$WORDS_SQL, WORD_FZF=$WORD_FZF, PATH_FILTER=$PATH_FILTER"
  #echo "sqlite3 ~/.bash_history-$HOST.db \"SELECT DISTINCT what FROM (SELECT what, 1 AS filter, stop, err FROM commands WHERE what LIKE '$WORDS_SQL' $PATH_FILTER UNION ALL SELECT DISTINCT what, 0 AS filter, stop, err FROM commands LIMIT 10000) AS both ORDER by filter DESC, stop DESC, err ASC LIMIT 10000;\" | fzy --lines=20 --query=\"$WORD_FZF\""
  selected=`sqlite3 ~/.bash_history-$HOST.db "SELECT DISTINCT what FROM (SELECT what, 1 AS filter, stop, err FROM commands WHERE what LIKE '$WORDS_SQL' $PATH_FILTER UNION ALL SELECT DISTINCT what, 0 AS filter, stop, err FROM commands LIMIT 10000) AS both ORDER by filter DESC, stop DESC, err ASC LIMIT 10000;" | fzy --lines=20 --query="$WORD_FZF"`
  # With argument in hand, change bash prompt and jump to the entry end
  [[ -n "$selected" ]] \
   && export READLINE_LINE="$selected" \
   && READLINE_POINT=${#READLINE_LINE}
  # And if fzy caused a scroll, do a SCP up there to overwrite the RCP
  [[ -n "$overwritecursorposition" ]] \
   && echo "\e[1A\e7" \
   && unset overwritecursorposition
}
# map ^R to the custom search using sqlite and fzy on current path
bind -x '"\C-r": sqlitehistorysearch "path"'
# map ^T to the custom search using sqlite and fzy on everything
bind -x '"\C-t": sqlitehistorysearch ""'

##### C) Suggested default features

##### C1) Verbose debugging (prefix with lines + function names) in bash -x
# With timestamping:
# 1st character of PS4 is recursive, to indicate levels of indirection
#export PS4='# [\D{%Y-%m-%d_%H:%M:%S}] ${BASH_SOURCE} line ${LINENO} (in: ${FUNCNAME[0]})\n\r# '
# Without timestamping, more concise:
export PS4='# ${BASH_SOURCE:-}:${FUNCNAME[0]:-}:L${LINENO:-}:   '

##### C2) Use UTF8 C locales instead of country/language specific values
#export LANG=C
#export LANG=en_EN.utf-8
export LANG=C.UTF-8
export LC_ALL=C.UTF-8

##### C3) Improve support of window size changes (row*col resolution)
## After each command check window size to update LINES and COLUMNS if needed
shopt -s checkwinsize
# also trap change of resolutions
#trap 'echo "$COLUMNS"; kill -s SIGWINCH "$$"' WINCH

##### C4) Use less for manpages, and lesspipe for binaries
# lesspipe will define itself as $LESSOPEN and $LESSCLOSE
# lesspipe comes with less, but might be packaged separately
[ -x /usr/bin/lesspipe ] && eval "$(lesspipe)"
## TODO: replace lesspipe preprocessor of non-text input files by sixels
# Color man
function man() {
 LESS_TERMCAP_md=$'\e[01;31m' \
 LESS_TERMCAP_me=$'\e[0m' \
 LESS_TERMCAP_se=$'\e[0m' \
 LESS_TERMCAP_so=$'\e[01;44;33m' \
 LESS_TERMCAP_ue=$'\e[0m' \
 LESS_TERMCAP_us=$'\e[01;32m' \
 command man "$@"
}
export LESS=-RX
export PAGER="less -iMSx4 -FX"

##### C5) Provide aliases to test sixels and work with w3m and old tmux
# sixel protection if not using a proper sixel-aware multiplexer
# old versions of tmux which requires wrapping unrecognized OSC sequences with:
# DCS tmux; <sequence> ST
#  also all ESCs in <sequence> to be replaced with ESC ESC.
#  also tmux only accepts ESC backslash for ST.
# Better use a sixel-tmux than having to cat image.six | __tmux_guard()
#  since even with __tmux_guard, regular tmux sometimes eats text when data outstanding gets too large
# (width * height * 8 bytes)
__tmux_guard() { printf "\u1bPtmux;" ; sed 's:\x1b:\x1b\x1b:g' ; printf "\u1b\\"; }
alias sixel-test-tmux="sixel-test | __tmux_guard"
# check if terminfo is ok: should have smglr
alias sixel-check="tput smglr|base64"
# minimal example from https://www.digiater.nl/openvms/decus/vax90b1/krypton-nasa/all-about-sixels.text
alias sixel-test="echo 'G1BxCiMwOzI7MDswOzAjMTsyOzEwMDsxMDA7MCMyOzI7MDsxMDA7MAojMX5+QEB2dkBAfn5AQH5+
JAojMj8/fX1HR319Pz99fT8/LQojMSExNEAKGwo=' | base64 -d"
# w2m needs /usr/local/bin/img2sixel or replace w3mimgdisplay by yaimg-sixel:
#cc -Wall -Wextra -std=c99 -pedantic -O3 -pipe -fPIE -s yaimg-sixel.c ../libnsgif.c ../libnsbmp.c -o yaimg-sixel  -L/usr/local/lib -ljpeg -lpng -lsixel  -lcurl -lz
alias w3m="w3m -sixel -o display_image=1"
export GNUTERM="sixelgd size  1280,720 truecolor font arial 16"

##### C6) Color in ls or eza/exa shortcuts, solarized files and directory colors
## Too slow:
#eval `dircolors $HOME/.dircolors.solarized_256`
# Speed it up by avoiding stat, using perl instead
[ -f ${HOME}/.dircolors.solarized_256 ] \
 && eval $(cat $HOME/.dircolors.solarized_256 | perl -pe 's/^((CAP|S[ET]|O[TR]|M|E)\w+).*/$1 00/' | SHELL=/usr/bin/bash dircolors -)
export CLICOLOR=yes
export LS_OPTIONS='--color=auto'
# Currently using foreground = #87,89,77 background = #255,255,215 cursor=#191,191,191
alias d="ls --color"
alias l="ls -lhart --color --time-style=long-iso"
alias ll="ls -lhaF --color --time-style=long-iso --show-control-chars"
# Override ls shortcuts l/ll with exa or eza modern fork if available
type -p exa >/dev/null \
 && alias e="exa --color-scale --classify" \
 && alias l="exa --time-style=long-iso --colour-scale-mode=gradient --color-scale=all -l" \
 && alias ll="exa --time-style=long-iso --colour-scale-mode=gradient --color-scale=all -abghHliS -T -L=2"
# ll will reverse into a Tree at depth Level 2

##### C7) 2 lines prompt with return value, timestamp, user, directory
# This gives more space to type commands on a standalone line with just "# "
# There are no variables, both to keep in mind the monstrosity we are building
# (try to understand this powerline in a minute) and to limit features creep
# Read https://en.wikipedia.org/wiki/ANSI_escape_code to understand the codes
# step 0: toggle: set $RETURN to $?, needed to check $? inside a `` construct
# then if $?>0, $? is used in && as %03d, if not, || will use spaces instead
# step 1: first half (&& and || only differ by %03d and underline toggle)
# step 1A: \[ : say to bash this does not matter for prompt length (linebreak)
# step 1B: \e[4m : toggle underline
# step 1C: \e[3m : toggle italic
# step 1D: \e[2m : toggle dim
# step 1E: \e[31m : set red as the foreground color
# step 1F: \] : say to bash prompt length starts
# step 1G: \$!%03d: print #! if uid 0 or $! and the return value if >0==error
# step 1H: \[ : say to bash this does not matter for prompt length (linebreak)
# step 1I: \e[39m: reset the foreground color to default
# step 1J: \e[49m: reset the foreground color to default
# step 1K: \] : say to bash prompt length starts here for linebreaks
# step 1L: $RETURN: use this value (set to $? to use inside a `` construct)
# step 2: second half of 1st line, without logic toggles, so always the same:
# step 2A: \[ : say to bash this does not matter for prompt length (linebreak)
# step 2B: \e[39m: reset the foreground color to default (redundant, safer)
# step 2D: \] : say to bash prompt length starts
# step 2C: [: print an opening braket for the date (cuter)
# step 2E: \D: print the date
# step 2F: {%Y-%m-%d.%H:%M:%S}: set the date format to be like JP/ISO
# step 2G: ]\[\e[24m\]: print a closing bracket then disable underlining
# step 2H: \[ : say to bash this does not matter for prompt length (linebreak)
# step 2I: \e[0m : reset the style to normal
# step 2J: \e[23m: reset the italic toggle
# step 2K: \] : say to bash prompt length starts here (for linebreaks/scroll)
# step 2L: (\#: print an opening parenthesis, the command sequence id and a colon
# step 2M: \[\e[1m\]: toggle bold which doesn't matter for prompt length
# step 2N: \w), print the working directory and a closing parenthesis
# step 2O: \[\e[24m\]\n :reset the underline toggle
# step 2P: \n: finish the 2nd half of the first lane with a carriage return
# step 3: the actual prompt line	
# step 3A: \[ : say to bash this does not matter for prompt length
# step 3B: \e[0m\e[3m\e[2m: reset the style to normal, toggle dim and italic
# step 3C: \] : say to bash prompt length starts
# step 3D: \$: print a dollar or hash sign (same font as before thanks to style/dim/ital)
# # \e[30m\e[41m : print in color (here black fg, red bg)
# step 3E: \[\e[0m\]: reset style to normal, doesn't matter for linebreaks
# step 4:  : a space to separate the leading hash sign from your entry
# WARNING: must not forget sqliteaddstop "$RETURN" 2>/dev/null to update stop+errcode
PS1='`RETURN=$? ; sqliteaddstop "$RETURN" ; [ ${RETURN} != 0 ] \
 && printf "\[\e[4m\e[3m\e[2m\e[31m\]\$!%03d\[\e[39m\e[49m\]" $RETURN \
 || printf "\[\e[3m\e[2m\e[39m\]\$    \[\e[49m\]"` \
\[\e[39m\][\D{%Y-%m-%d.%H:%M:%S}]\[\e[24m\] \[\e[0m\e[23m\e[39m\](\#:\[\e[1m\]\w)\n\
\[\e[0m\e[3m\e[2m\]\$\[\e[0m\] '
#PS0="`if [ $COMP_LINE ] ; printf "\e8\e[2K"; fi`"
#export PS0 PS1
export PS1

##### D) Special small tweaks

##### D1) If multiplexing, tell when screen is there (rarely has an indicator)
#[ -n "${TERM}" ] \
# && [ "${TERM}" == "tmux" ] \
# && echo "# [ tmux is activated ]" >&2
[ -n "${TERM}" ] \
 && [ "${TERM}" == "screen" ] \
 && echo "# [ screen is activated ]" >&2 \
 && STYLST=`screen -ls |grep \( | sed -e 's/^	//g' -e 's/	.*//g' -e 's/.*\.//g' |tr -s '\n' ' '` \
 && [ -n ${STYLST} ] \
 && export $STYLST

##### D2) On a real tty, disable cursor blinking with DECSCUSR and set title
test -t 0 \
 && echo -e "\e[2 q" \
 && [ -n $HOST ] \
 && echo -ne "\e]2;$HOST\a"

##### D3) Set vim as the default vi, keep "vi" in EDITOR in case of strcmp
type -p vim >/dev/null \
 && alias vi=vim \
 && export EDITOR=vi \
 && export VISUAL=vim

##### D4) Define su as a sudo alias when su is not available
# Then can avoid passwords with /etc/sudoers: thisusername ALL=(ALL) ALL
type -p su >/dev/null \
 || alias su="/usr/bin/sudo bash"

##### D5) Within mc, don't use subshells which can cause start delays
# mc starts a subshell, causing start delays on Windows where fork is slow
alias mc="mc --nosubshell"
## Windows-Terminal supports mouse for mc with xterm-vt220, however no hicolor in that mode
# This is due to a bug in mc: only recognize the xterm mouse event properly
# under specific conditions, like when DISPLAY has been set cf
# https://unix.stackexchange.com/questions/304960/midnight-commander-force-xterm-permanently
# workaround: fix kmous if not correct like https://github.com/msys2/MSYS2-packages/issues/1596
# infocmp.exe xterm-vt220 xterm-256color|grep kmous 
#        kmous: '\E[M', '\E[<'.
# Done in ~/.terminfo.src/xterm-256color.terminfo

##### D6) Special tweaks for perl and perl dyld like oracle instantclient
export PERL_MM_OPT=INSTALL_BASE=$HOME/perl5
export PERL_MB_OPT="--install_base \"$HOME/perl5\""
export PERL5LIB=$HOME/perl5/lib/perl5:$HOME/perl/lib/perl5/site_perl
#export PATH=$PATH:$HOME/perl5/bin
# prefix instead of suffixing
export PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"
#export ORACLE_HOME=~/.cpan/instantclient_10_2
#export DYLIB_LIBRARY_PATH=$HOME/.cpan/instantclient_10_2
#export DYLD_LIBRARY_PATH=$HOME/.cpan/instantclient_10_2

##### D7) Change the path for WSL and Visual Studio Code (VSCode)
# From windows, add the %USERPROFILE% env variable to what's exported with:
#setx WSLENV USERPROFILE/up
##### D7A) Can then use vscode addons after install: "wsl -u root", type "code"
VSCODEPATH=":/mnt/c/Program Files/Microsoft VS Code/bin/"
USERPRPATH=":/mnt/c/Users/$USERPROFILE/AppData/Local/Programs/Microsoft VS Code/bin/code"
[[ "$WSL_DISTRO_NAME" ]] \
 && PATH="$PATH$VSCODEPATH$USERPRPATH"
##### D7B) Avoid "The terminal process (...) terminated with exit code: 127"
# Propagation of the errcode of the last command, so trap EXIT to send exit 0
trap '[[ "$WSL_DISTRO_NAME" ]] && exit 0 ' EXIT

