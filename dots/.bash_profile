# ~/.bash_profile: executed by bash(1) for login shells as #2
# The #1 script is /etc/bash.bashrc in every case
# For remote (ssh) login shells, this .bash_profile calls a multiplexer
# For login shells that are local, this .bash_profile sources .bashrc as #3
# For non-login shells, .bashrc (as #2) may source this .bashprofile (as #3)
# When ~/.bash_profile exists, neither ~/.bash_login nor ~/.profile are read
#
##### A) Common part always done in both interactive or non-interactive mode

##### A1) Mark this file as read by exporting its path as an env variable
# Will prevent loading more than once in .bashrc etc
# (realpath from BSD is now more standard than GNU readlink -f)
export BASHPROFILE=$( realpath ${BASH_SOURCE} || echo "${BASH_SOURCE}" || echo "unknown")

##### A2) We may have no reliable PATH, so make sure at least /usr is defined
# If we have a reliable path, can then ensure usr/local is also included
# WONTFIX: a "dynamic" relative part like $(pwd)/bin is a security risk
[ -z "${PATH}" ] \
 && PATH="/usr/sbin:/usr/bin" \
 || PATH="${HOME}/.local/bin:/usr/local/sbin:/usr/local/bin:${PATH}"
#leaving out :/sbin:/bin as they're being deprecated

[[ $- != *i* ]] && return
##### B) If not running interactively, do not do anything more, but otherwise:

##### B1) Feature: sqlite logging, separate for each bash new session/login
# Each session stores the kernel version and the username to trace regressions
##### B1A) Set (not export) basic variables expected by sqlite logging to work
[ -z "${UNAME}" ] \
 && UNAME=$(uname -a)
#[ -z "${HOME}" ] \
# && HOME=/
# On mingw/msys2, use sed because can't use -s for the long/short distiction
[ -n "${MINGW_CHOST}" ] \
 && HOST=$( hostname | sed -e 's/\..*//g' )
# On linux and wsl2, use the file or hostname -s
[ -z "${HOST}" ] \
 && [ -f /etc/hostname ] \
 && HOST=$( cat /etc/hostname ) \
 || HOST=$( hostname -s 2 >/dev/null )
##### B1B) Export filepaths variables: will have $HOME for a regular bash
export SQLITE_BASH_INIT=$( realpath ${HOME}/.sqliterc_bash ) \
export SQLITE_BASH_HISTORY="${HOME}/.bash_history-${HOST}.db"
##### B1C) Linear backoff for serial .db file to avoid locks by a few bash -l
# In practice, sleep a time t= (cardinality sqlite3 processes)/100
# Otherwise:
#  - With begin/commit:
# Error: stepping, database is locked (5)
#  - Without:
# Error: in prepare, database is locked (5)
#  - With in memory:
# Parse error near line 7: database is locked (5)
OTHERS=$( ps x | grep sqlite3 |wc -l )
[ -n "${OTHERS}" ] && sleep 0.0$OTHERS
###### B1D) If no SID, yet using bash (checks $SHELL), define a new SID
# a new SID is obtained: insert, select max (strictly increasing) then export
# This causes SID to be is maintained when opening subshells
# WARNING: shouldn't use -init "${SQLITE_BASH_INIT}" to avoid headers and spaces
[ -z "${SID}" ] \
 && [ -z "${0//\/[a-z]*bash/}" ] \
 && export SID=$( <. sqlite3 "${SQLITE_BASH_HISTORY}" "
BEGIN TRANSACTION;
 CREATE TABLE IF NOT EXISTS sessions (   -- table of sessions, pk unique for host+time
  sid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  login TIMESTAMP NOT NULL DEFAULT current_timestamp,
                                         -- bash_login timestamp
  logout TIMESTAMP NUL,                  -- bash_logout timestamp
  user TEXT,                             -- username to merge different databases later
  uname TEXT                             -- complete kernel version
 );
 CREATE TABLE IF NOT EXISTS commands (   -- table of the commands, pk autoincremented
  cid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
  ssid INTEGER NOT NULL,                 -- foreign key session(sid)
  seq INTEGER NOT NULL,                  -- deduplicate pipes + detect suspicious holes
  start TIMESTAMP NOT NULL DEFAULT current_timestamp,
                                         -- execution begins when enter is pressed
  stop TIMESTAMP NULL,                   -- ends when prompt shown again, empty if SIGINT
  err INTEGER NULL,                      -- eventual returned code
  what TEXT,                             -- command line as it was typed
  path TEXT,                             -- context where the command line was typed
  FOREIGN KEY (ssid) REFERENCES sessions(sid) ON DELETE CASCADE,
  UNIQUE (ssid, seq)
 );
 INSERT INTO sessions (user,uname) VALUES (
  '${USER//\'/''}', '${UNAME//\'/''}'   -- reason why the variables were set before
  );
 SELECT max(sid) from sessions;
COMMIT;
-- then select the returned number
" | grep "^[0-9][0-9]*")

##### B2) Feature: multiplexing, to have a few different bash always visible
# Logic based on $SSH_CONNECTION (exported by openssh-server and dropbear)
# and the currently used tty (different from each tab and terminal):
# - strip the eventual /dev prefix
# - strip the ::ffff: prefix of the IP in case IPv4 mapped into IPv6 space
# - merge, as for each ssh, origin IP likely the same but tty or pts changes
##### B2A) Create a multiplexing ID (MID)
TTY=$( tty )
[ -z "${SSH_CONNECTION}" ] \
 && MID="local:${TTY#/dev/}" \
 || MID="${SSH_CONNECTION#::ffff:}:${TTY#/dev/}"
##### B2B) Linux specific /run fixes for gnu screen
# [ -d /run/screen ] \
# && chmod 755 /run/screen \
# || mkdir /run/screen \
# && chmod 755 /run/screen \
# && chgrp utmp /run/screen
# TODO: should determine the UID when there's no /etc/groups
##### B2C) TODO: tmux should also use socketdir "/run/tmux/tmux-${UID}" 
##### B2D) When doing a remote login, divert by exec to the chosen multiplexer
# If a MID named session exists, attach, otherwise create
## If you want GNU screen
#[ -n ${SSH_CONNECTION} ] \
# && exec /usr/bin/screen -SAlaxRR $MID
## If you want tmux
# (-A)=(tmux attach || tmux) ie -A makes new-session like attach-session
#[  -n ${SSH_CONNECTION} ] \
# && [ -n ${TMUX} ] \
# && exec tmux new -As $MID
# TODO: can force tmux to use a given socket with -L ${HOME}.tmux.socket

##### B2E) Local logins will miss .bashrc defaults since not diverted by exec
# So source the normal aliases and functions from .bashrc
# But avoid forkbombs by recursion and only do that if:
# - a non-remote login (ssh defined origin IP) 
# - hasn't read the file before
# - the file exist
# - and we're not in a multiplexer
[ -z "${SSH_CONNECTION}" ] \
 && [ -z "${BASHRC}" ] \
 && [ -f ${HOME}/.bashrc ] \
 && [ "${TERM}" != "tmux" ] \
 && [ "${TERM}" != "screen" ] \
 && source ${HOME}/.bashrc

##### B3) Extra tweaks
# On WSL, make sure to start in home which may not be defined
[ "$WSL_DISTRO_NAME" ] && [ -n "${HOME}" ] && cd "${HOME}"

