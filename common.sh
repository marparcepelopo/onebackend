#!/bin/bash

# GLOBAL VARIABLES
BASEDIR=S{HOME}"/one/"
INCOMINGDIR=${BASEDIR}"incoming/"
DEFAULT_CONFIG_FILE=${BASEDIR}"/config_file_model.txt"
METADATAFILE="metadatafile.dat"

function are_you_sure() {
  read -r -p "Are you sure? [y/N] " RESPONSE
  if [[ "$RESPONSE" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
    return 1
  else
    return 0
  fi
}


function check_directory() {
  # Check if the directory exists or is not empty

  if [ -z "$targetdir" ]; then
    show_menu
  elif [ -d "$targetdir" ]; then
    find "$targetdir" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
      echo "The directory exists and is not empty."
      are_you_sure
      if [ $? -eq 1 ]; then
        copy_data "$targetdir"
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
}

function check_config_loaded(){
  # Check if the config is loaded

  if [ -z "$CASE" -o -z "$VALUE" ]; then
    config_selected_file="$(head -1 $CONFIG_FILE)"

    if [ ! "$config_selected_file" =~ "^[a-zA-Z0-9_-.]+$" ]; then
      echo "$DEFAULT_CONFIG_FILE" > $CONFIG_FILE
      echo "Config file loaded with default values"
    fi
    carga_config "$(head -1 $CONFIG_FILE)"
  fi
  }

function parse_config_file(){
  # Parse the config file
  file="$1"

  if [ -z "`grep -E "^CASE=[a-zA-Z0-9_-]+$" "$file"`" ]; then
    echo "The CASE value should be a non-zero string"
    ERR=1
  fi

  if [ -z "`grep -E "^ALIAS=[a-zA-Z0-9_-]+$" "$file"`" ]; then
    echo "The ALIAS value should be a non-zero string"
    ERR=1
  fi
  
  if [ -z "$ERR" ]; then
    CASE="$(awk -F'=' '/^CASE=/ {print $2}' $file)"
    ALIAS="$(awk -F'=' '/^ALIAS=/ {print $2}' $file)"
    return 0
  else
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
    echo "Reading configuration file..."
    parse_config_file "$pathfile"

    if [ $? -ne 0 ]; then
      echo "There was an error loading the file"
    else
      echo "$pathfile" > $CONFIG_FILE
      echo "File loaded successfully!"
    fi
  else
    echo "Config file not found"
  fi
}

function is_the_file_empty() {
  # Check if the file is empty
  if [ ! -s "$1" ]; then
    echo "ERROR: The file \"$1\" is empty"
    return 1
  else
    return 0
  fi
}

function process_file_copy() {
  # Process the file image
  # Create the dir with the image
  image="`echo $1|tr ' ' '_'`"
  new_dir=${targetdir}/${image}
  mkdir $new_dir >/dev/null 2>&1
  mmls $image | awk 'match($0, /NTFS|FAT[0-9][0-9]/) {
    print $1+0"|-o "$3+0" -f "tolower(substr($0, RSTART, RLENGTH))
    }' > /tmp/partitions

  if [ ! -s /tmp/partitions ]; then
    echo "ERROR: The file was not created rigthfully"
    return 1
  fi

  cat /tmp/partitions | while read partline
  do
    PARTID="$(echo $partline | cut -d'|' -f1)"
    OPTIONS="$(echo $partline | cut -d'|' -f2)"
    echo "Creating the partition folder..."
    new_part_dir=${new_dir}/$PARTID
    mdkir -p $new_part_dir

    echo "Reading partition $PARTID..."
    fls $OPTIONS "$1" -rpl | awk -F'\t' '{
      OFS="|"
      split($1, v, " ")
      print v[1], substr(v[2],1,length(v[2])-1), $2, $6, $7
      }' > /tmp/files

    is_the_file_empty /tmp/files
    if [ $? -ne 0 ]; then
      return 1
    fi

    local ID=1
    while read line
    do
      local TYPE="$(echo $line | cut -c1)"
      local INODE="$(echo $line | cut -d'|' -f2)"
      local NOMBRE="$(echo $line | cut -d'|' -f3)"
      local CTIME="$(echo $line | cut -d'|' -f4)"
      local SIZE="$(echo $line | cut -d'|' -f5)"
      if [ "$TYPE" = "d/d" ]; then
        mkdir -p ${new_dir}/${NOMBRE}
      elif [ "$TYPE" = "r/r" ]; then
        (time icat $OPTIONS "$1" $INODE) > ${new_part_dir}/${NOMBRE} 2>/tmp/timeres
        COPYTIME="$(awk '/real/ {print $2}' /tmp/timeres)"
        MD5="$(icat $OPTIONS "$1" $INODE|md5sum|awk '{print $1}')"
        if [ "$MD5" != "`cat ${new_part_dir}/${NOMBRE}|md5sum|awk '{print $1}'`" ]; then
          echo "The copy of the file \"${NOMBRE}\" did not passed the integrity check"
        fi
        EXT="$(awk -v file="$NOMBRE" '{split($0, arr, "."); for (i in arr){val++}; print arr[val]}')"
        echo "Create data file in $new_part_dir"
        echo "$CASE|$ID|$ALIAS|$SIZE|$NOMBRE|$MD5|$CTIME|$COPYTIME|$EXT" >> ${new_part_dir}/metadatafile.dat
        ID=$(($ID+1))
    done < /tmp/files
  done
}

function copy_data_to() {
  # List the image files
  declare -a file_list
  for f in `ls ${INCOMINGDIR}*.E01`
  do
    file_list+=($f)
    process_file_copy "$f"
    if [ $? -eq 0 ]; then
      echo "File processed succesfully"
    else
      echo "There was an error processing the file"
    fi
  done
}

