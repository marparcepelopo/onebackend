#!/bin/bash

# GLOBAL CONSTANTS
COLOR='\033[01;31m'     # bold red
RESET='\033[00;00m'     # normal white
LOGFILE=/tmp/`basename $0`".log"

function help() {
  # Help of the tool
  # This program check the permissions the user has on the directories passed as a parameters
  echo "USE:"
  echo "===="
  echo "check_permissions <directory> [<directories separated by spaces>]"
  echo ""
}

function log() {
  # Log the message in a file
  # param type: info or debug
  # param text: text of the message
  if [ -z "$LOGFILE" ]; then
    LOGFILE="/tmp/logfile.log"
  fi

  if [ "$1" != "info" -a "$1" != "debug" ]; then
    log debug "function log: the first parameter should be info or debug"
    return 1
  fi

  if [ -z "$2" ]; then
    log debug "function log: The second parameter is empty"
    return 1
  fi
  fecha="`date '+%d/%m/%Y %H:%M'`"
  echo ${fecha}"|"$1"|"$2 >> ${LOGFILE}
  echo -e "${COLOR}${2}${RESET}"
  return 0
}


# MAIN
if [ $# -eq 0 ]; then
  help
  exit 1
fi

declare -a arr
while [ -n "$1" ]
do
  arr+=($1)
  shift
done

declare -a sinpermisoarr

log info "Directories readable and executable by the current user"
for d in ${arr[@]}
do
  find $d -type d -readable -a -executable 2>/dev/null
  RES="$(find $d -type d -prune -readable -a -executable 2>/dev/null)"

  # If the variable RES is empty, it means the directory is not readable and executable
  # so it will be added to the array of folder with no permissions
  if [ -z "$RES" ]; then
    sinpermisoarr+=($d)
  fi
done
echo "================================================"
log info "Files readable and executable by the current user"
for d in ${arr[@]}
do
  find $d -type f -readable -a -executable 2>/dev/null
  RES="$(find $d -type f -readable -a -executable 2>/dev/null)"
  if [ -z "$RES" ]; then
    sinpermisoarr+=($d)
  fi
done

log info "Changing permissions to be read and executable by the current user
for item in ${sinpermisoarr[@]}
do
  find $item -exec chmod +rx {} \; 2>/dev/null
done
 
unset arr
unset sinpermisoarr

