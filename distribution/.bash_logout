# ~/.bash_logout

# Log the session stops, iff using bash (assumed to be in /usr/bin)
[ -n "${SID}" ] && [ "${0/\/usr\/bin\//}" == "bash" ] \
 sqlite3 "${SQLITE_BASH_HISTORY}" "UPDATE sessions SET logout = current_timestamp WHERE sid ='${SID//\'/''}';"
