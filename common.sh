#!/bin/bash

# GLOBAL VARIABLES
BASEDIR=${HOME}"/one/"
INCOMINGDIR=${BASEDIR}"incoming/"
DEFAULT_CONFIG_FILE=${BASEDIR}"/config_file_model.txt"
METADATAFILE="metadatafile.dat"
COLOR='\033[01;31m'     # bold red
RESET='\033[00;00m'     # normal white

function are_you_sure() {
  # To ask yes or no
  # return 1:yes and 0:no

  read -r -p "Are you sure? [y/N] " RESPONSE
  if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    return 1
  else
    return 0
  fi
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


function check_directory() {
  # Check if the directory exists or is not empty
  # param folder: The folder to check

  if [ -z "$1" ]; then
    log debug "function check_directory: The parameter cannot be empty"
    show_menu
  elif [ -d "$1" ]; then
    find $1 >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "The directory exists and is not empty."
      are_you_sure
      if [ $? -eq 1 ]; then
        echo "Deleting files in the folder \"$1\"..."
        rm -rf ${1}/* >/dev/null 2>&1
      else
        show_menu
      fi
    fi
  fi
}

function option_picked() {
  COLOR='\033[01;31m'     # bold red
  RESET='\033[00;00m'     # normal white
  MESSAGE=${*:-"${RESET}Error: No message passed"}
  echo -e "${COLOR}${MESSAGE}${RESET}"
  if [[ "$MESSAGE" =~ "Error" ]]; then
    log debug "Error: No message passed"
  fi
}

function check_config_loaded(){
  # Check if the config file is loaded

  if [ -z "$CASE" -o -z "$VALUE" -o -z "$TARGETDIR" -o -z "$LOGFILE" ]; then
    config_filename="$(head -1 $CONFIG_FILE)"
    if [[ ! "$config_filename" =~ "^[a-zA-Z0-9_-/.]+$" || ! -f $config_filename ]]; then
      echo "$DEFAULT_CONFIG_FILE" > $CONFIG_FILE
      log info "Default config file selected"
    fi
    carga_config "$(head -1 $CONFIG_FILE)"
  fi
  }

function parse_config_file(){
  # Parse the config file

  file="$1"

  if [ -z "`grep -E "^CASE=[a-zA-Z0-9_-]+$" "$file"`" ]; then
    log debug "The CASE value should be a non-zero string"
    return 1
  fi

  if [ -z "`grep -E "^ALIAS=[a-zA-Z0-9_-]+$" "$file"`" ]; then
    log debug "The ALIAS value should be a non-zero string"
    return 1
  fi
  
  if [ -z "`grep -E "^TARGETDIR=[a-zA-Z0-9_/-]+$" "$file"`" ]; then
    log debug "The TARGETDIR value should be a non-zero string"
    return 1
  fi

  if [ -z "`grep -E "^LOGFILE=[a-zA-Z0-9_/.-]+$" "$file"`" ]; then
    log debug "The LOGFILE value should be a non-zero string"
    return 1
  fi

  }

function carga_config(){
  if [ -n "$1" ]; then
    pathfile="$1"
  else
    echo "Introduzca la ruta del fichero de configuracion: (empty=exit)"
    read pathfile
  fi

  if [[ -n "$pathfile" && -f "$pathfile" ]]; then
    log info "Reading configuration file..."
    parse_config_file "$pathfile"

    if [ $? -eq 0 ]; then
      CASE="$(awk -F'=' '/^CASE=/ {print $2}' $file)"
      ALIAS="$(awk -F'=' '/^ALIAS=/ {print $2}' $file)"
      TARGETDIR="$(awk -F'=' '/^TARGETDIR=/ {print $2}' $file)"
      LOGFILE="$(awk -F'=' '/^LOGFILE=/ {print $2}' $file)"

      echo "$pathfile" > $CONFIG_FILE
      log info "File loaded successfully!"
    else
      log info "Some values in the config file were not right"
      return 1
    fi
  else
    log info "Config file not found"
    return 1
  fi
  return 0
}

function is_the_file_empty() {
  # Check if the file is empty
  if [ ! -s "$1" ]; then
    log info "The file \"$1\" is empty"
    return 1
  else
    return 0
  fi
}

function process_file_copy() {
  # Process the file image
  # Create the dir with the image
  local IMAGEFILE="$1"
  local new_dir=${TARGETDIR}/${IMAGEFILE}
  mkdir $new_dir >/dev/null 2>&1
  mmls $IMAGEFILE | awk 'match($0, /NTFS|FAT[0-9][0-9]/) {
    OFS="|"
    print $1+0, $3+0, tolower(substr($0, RSTART, RLENGTH))
    }' > /tmp/partitions

  is_the_file_empty /tmp/partitions
  if [ $? -ne 0 ]; then
    log debug "function process_file_copy: File /tmp/files was not dumped with files"
    return 1
  fi

  log info "Create data file in $new_dir/${METADATAFILE}"
  echo "CASE|ID|ALIAS|IMAGEFILE|SECTORINI|FS|SIZE|FILENAME|MD5|CTIME|COPYTIME|EXT|INODE" > ${new_part_dir}/${METADATAFILE}
  while read partition
  do
    local PARTID="$(echo $partition | cut -d'|' -f1)"

    local SECTORINI="$(echo $partition | cut -d'|' -f2)"
    local FS="$(echo $partition | cut -d'|' -f3)"
    local OPTIONS="-o "${SECTORINI}" -f "${FS}
    log info "Creating the partition folder..."
    local new_part_dir=${new_dir}/$PARTID
    mkdir -p $new_part_dir

    log info "Reading partition $PARTID..."
    fls $OPTIONS "$IMAGEFILE" -rpl | awk -F'\t' '{
      OFS="|"
      split($1, v, " ")
      print v[1], substr(v[2],1,length(v[2])-1), $2, $6, $7
      }' > /tmp/files

    is_the_file_empty /tmp/files
    if [ $? -ne 0 ]; then
      log debug "function process_file_copy: File /tmp/files was not dumped with files"
      return 1
    fi

    local ID=1
    while read fileline
    do
      local TYPE="$(echo $fileline | cut -c1)"
      local INODE="$(echo $fileline | cut -d'|' -f2)"
      # To avoid confusing characters in the name of the file. The conversion is:
      #         " " => "_"
      #         "/" => "+"
      #         "$" => "="
      #local NOMBRE="$(echo $fileline | cut -d'|' -f3 | tr '$ /' '=_+')"
      local NOMBRE="$(echo $fileline | cut -d'|' -f3)"
      local CTIME="$(echo $fileline | cut -d'|' -f4)"
      local SIZE="$(echo $fileline | cut -d'|' -f5)"
      if [ "$TYPE" = "d" ]; then
        mkdir "${new_part_dir}/${NOMBRE}" -p
      elif [ -n "$INODE" ]; then
        (time icat $OPTIONS "$IMAGEFILE" $INODE) > "${new_part_dir}/${NOMBRE}" 2>/tmp/timeres
        local COPYTIME="$(awk '/real/ {print $2}' /tmp/timeres)"
        local MD5="$(icat $OPTIONS "$IMAGEFILE" $INODE|md5sum|awk '{print $1}')"
        if [ "$MD5" != "`cat "${new_part_dir}/${NOMBRE}"|md5sum|awk '{print $1}'`" ]; then
          log debug "The copy of the file \"${NOMBRE}\" did not passed the integrity check"
        fi
      fi
      local EXT="$(echo "$NOMBRE" | awk '{split($0, arr, "."); for (i in arr){val++}; print arr[val]}')"

      echo "$CASE|$ID|$ALIAS|$IMAGEFILE|$SECTORINI|$FS|$SIZE|$NOMBRE|$MD5|$CTIME|$COPYTIME|$EXT|$INODE" >>  ${new_dir}/${METADATAFILE}
      ID=$(($ID+1))
    done < /tmp/files
  done < /tmp/partitions
}

function copy_data_to() {
  # List the image files
  pushd "${INCOMINGDIR}" >/dev/null
  for f in `ls *.E01`
  do
    process_file_copy "$f"
    if [ $? -eq 0 ]; then
      log debug "function copy_data_to: Image file \"$f\" processed succesfully"
    else
      log debug "function copy_data_to: There was an error processing the file \"$f\""
    fi
  done
  popd >/dev/null
}

