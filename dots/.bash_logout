# ~/.bash_logout

## Close the session
echo ${SHELL} | grep -q bash \
 sqlite3 "${SQLITE_BASH_HISTORY}" "UPDATE sessions SET logout = current_timestamp WHERE sid ='${SID//\'/''}';"
