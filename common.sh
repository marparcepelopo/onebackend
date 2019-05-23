#!/bin/bash

# GLOBAL VARIABLES
BASEDIR=${HOME}"/one/"
INCOMINGDIR=${BASEDIR}"incoming/"
DEFAULT_CONFIG_FILE=${BASEDIR}"/config_file_model.txt"
CURRENT_POINTER_FILE=${BASEDIR}"/current_pointer"
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

  if [ -z "`grep -E "^INCOMING=[a-zA-Z0-9_/.-]+$" "$file"`" ]; then
    log debug "The INCOMING value should be a non-zero string"
    return 1
  fi
  }

function carga_config(){
  # Loads the config file passed as a parameter and loads all the variables with their content
  # param $1: Absolut path name of the config file

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
      ANALYSIS_FILES="$(awk -F'=' '/^ANALYSIS_FILES=/ {print $2}' $file)"
      INCOMING="$(awk -F'=' '/^INCOMING=/ {print $2}' $file)"
      METAFILE="$(awk -F'=' '/^METAFILE=/ {print $2}' $file)"

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
  # param $1: An absolute path file name

  if [ ! -s "$1" ]; then
    log info "The file \"$1\" is empty"
    return 1
  else
    return 0
  fi
}

function generate_insert() {
  # Generate insert record
  # param $1: complete line separated by pipes
  if [ -z "$1" ]; then
    log info "ERROR: function generate_insert: The parameter cannot be null"
    return 1
  fi
  # $CASE|$ID|$ALIAS|$IMAGEFILE|$PARTID|$SECTORINI|$FS|$SIZE|$NOMBRE|$MD5|$CTIME|$COPYTIME|$EXT|$INODE
  insert="$(echo "$1"|awk -F'|' '{print "INSERT INTO encase (case_name,alias_name,imagefile,partid,sectorini,fs,size,nombre,md5,ctime,copytime,ext,inode) values (\047$1\047,\047$3\047,\047$4\047,$5,$6,\047$7\047,$8,\047$9\047,\047$10\047,\047$11\047,\047$12\047,\047$13\047,\047$14\047);"}')"
}

function process_file_copy() {
  # Process the file image
  # param $1: An absolute path Image file name
  # param $2: "continue" if and old copy process was detected
  #           "" otherwise.

  # Create the dir with the image
  local IMAGEFILE="$1"
  local CONTINUE="$2"
  local new_dir=${TARGETDIR}/${IMAGEFILE}
  mkdir $new_dir >/dev/null 2>&1

  # Manage if the copy want to continued
  if [ -n "$CONTINUE" -a "$CONTINUE" = "continue" ]; then
    last_metadata_line="$(tail -1 ${TARGETDIR}/${METADATAFILE} | awk -F'|' '{OFS="|";print $2,$4,$6,$8,$9}')"
    local CONT="yes"
  else
    local CONT="no"
  fi

  # Get the partitions list
  mmls "$IMAGEFILE" | awk 'match($0, /NTFS|FAT[0-9][0-9]/) {
    OFS="|"
    print $1+0, $3+0, tolower(substr($0, RSTART, RLENGTH))
    }' > /tmp/partitions_$IMAGEFILE

  is_the_file_empty /tmp/partitions_$IMAGEFILE
  if [ $? -ne 0 ]; then
    log debug "function process_file_copy: File \"/tmp/partitions_$IMAGEFILE\" was not dumped with files"
    return 1
  fi

  while read partition
  do
    local PARTID="$(echo $partition | cut -d'|' -f1)"
    local SECTORINI="$(echo $partition | cut -d'|' -f2)"
    local FS="$(echo $partition | cut -d'|' -f3)"
    local OPTIONS="-o "${SECTORINI}" -f "${FS}

    log info "Creating the partition folder..."
    local new_part_dir=${new_dir}/$PARTID
    if [ ! -d $new_part_dir ]; then
      mkdir -p $new_part_dir
    fi

    log info "Reading partition $PARTID..."
    local FILES_FORMAT="/tmp/files-${IMAGEFILE}-${PARTID}-${SECTORINI}-${FS}"

    # Getting the file list according to the first sector of the partition read
    # OPTIONS may have "-o <First sector of the partition> -f <FileSystem>"
    fls $OPTIONS "$IMAGEFILE" -rpl | awk -F'\t' '{
      OFS="|"
      split($1, v, " ")
      print v[1], substr(v[2],1,length(v[2])-1), $2, substr($6,1,length($6)-7), $7, ++val
      }' > $FILES_FORMAT

    is_the_file_empty $FILES_FORMAT
    if [ $? -ne 0 ]; then
      log debug "function process_file_copy: File \"$FILES_FORMAT\" was not dumped with files"
       return 1
    fi

    # Reading the list of files and copying the content file to the $TARGETDIR variable
    local ID=1
    while read fileline
    do
      local TYPE="$(echo $fileline | cut -d'|' -f1)"
      local INODE="$(echo $fileline | cut -d'|' -f2)"
      local NOMBRE="$(echo $fileline | cut -d'|' -f3)"
      local CTIME="$(echo $fileline | cut -d'|' -f4 | sed 's/ \(CET\)//')"
      local SIZE="$(echo $fileline | cut -d'|' -f5)"
      local NUMLINE="$(echo $fileline | cut -d'|' -f6)"
      if [ "$CONT" = "yes" ]; then
        cur_line="$ID|$IMAGEFILE|$SECTORINI|$SIZE|$NOMBRE"
        if [ "$last_metadata_line" = "$cur_line" ]; then
          # if the last line of matadata file is reached, the current line will be ommitted
          # but the next loop, it will get in and process de file
          CONT="no"
        fi
      else
        # If the entry belongs to an Orphan element (with no inode), we only add it to metadata file
        if [ -n "$INODE" ]; then
          if [[ "$TYPE" =~ "d" ]]; then
            mkdir "${new_part_dir}/${NOMBRE}" -p
          else
            (/usr/bin/time -f "%E" icat $OPTIONS "$IMAGEFILE" $INODE) > "${new_part_dir}/${NOMBRE}" 2>/tmp/timeres
            local COPYTIME="$(cat /tmp/timeres)"
            local MD5="$(icat $OPTIONS "$IMAGEFILE" $INODE|md5sum|awk '{print $1}')"
  
            # Checking integrity with md5sum between the origin (image file) and the target file
            if [ "$MD5" != "`cat "${new_part_dir}/${NOMBRE}"|md5sum|awk '{print $1}'`" ]; then
              log debug "The copy of the file \"${NOMBRE}\" did not passed the integrity check"
            fi
          fi # TYPE =~ d
        fi # -n INODE
        # local EXT="$(echo "$NOMBRE" | awk '{split($0, arr, "."); for (i in arr){val++}; print arr[val]}')"
        local EXT="$TYPE"

        result="$CASE|$ID|$ALIAS|$IMAGEFILE|$PARTID|$SECTORINI|$FS|$SIZE|$NOMBRE|$MD5|$CTIME|$COPYTIME|$EXT|$INODE"
        echo $result >> ${TARGETDIR}/${METADATAFILE}
        
      fi # CONT = yes

      ID=$(($ID+1))
    done < $FILES_FORMAT
  done < /tmp/partitions_$IMAGEFILE
}

function copy_data_to() {
  # Master of the copy process
  # param $1: "continue" if the copy want to be continued, "" otherwise.

  # List the image files
  pushd "${INCOMINGDIR}" >/dev/null

  # Write only if the process wants to be continued
  if [ -z "$1" ]; then
    log info "Create data file in ${TARGETDIR}/${METADATAFILE}"
    echo "CASE_NAME|ID|ALIAS_NAME|IMAGEFILE|PARTID|SECTORINI|FS|SIZE|FILENAME|MD5|CTIME|COPYTIME|EXT|INODE" > ${TARGETDIR}/${METADATAFILE}
  fi

  for f in `ls *.E01`
  do
    process_file_copy "$f" "$1"
    if [ $? -eq 0 ]; then
      log debug "function copy_data_to: Image file \"$f\" processed succesfully"
    else
      log debug "function copy_data_to: There was an error processing the file \"$f\""
    fi
  done
  popd >/dev/null

  # Delete old files used
  rm -f /tmp/files* /tmp/partitions* >/dev/null 2>&1
}

function find_imports() {
  # List the number of files_list that are imported/importing
  pushd /tmp >/dev/null
  for f in `ls files*`
  do
    if [[ "$f" =~ (-.*){4} ]]; then
      local IMAGEFILE="$(echo "$f" | cut -d'-' -f2)"
      local PARTID="$(echo "$f" | cut -d'-' -f3)"
    else
      log info "function find_imports: The file \"$f\" does not have a right format"
      return 1
    fi

    local ORIGIN_NUM_RECORDS="$(wc -l "$f" | awk '{print $1}')"
    local TARGET_NUM_RECORDS="$(awk -F'|' -v partid="$PARTID" -v img="$IMAGEFILE" '$4==img && $5==partid {sum++} END{print sum}' "${TARGETDIR}/${METADATAFILE}")" 
    fuser "$f" --silent
    if [ $? -eq 0 ]; then
      # File is in use now
      log info "The image file \"${IMAGEFILE}\" with the partition number ${PARTID} is in process of importing: $((${TARGET_NUM_RECORDS}*100/${ORIGIN_NUM_RECORDS}))% completed. "
      log info "${TARGET_NUM_RECORDS} records imported out of ${ORIGIN_NUM_RECORDS} in total"
    else
      # File is not in use, so its import ended
      log info "The image file \"${IMAGEFILE}\" with the partition number ${PARTID} is finished currently. ${TARGET_NUM_RECORDS} records imported out of ${ORIGIN_NUM_RECORDS} in total"
    fi  
  done
  popd >/dev/null
}

function show_filter_menu() {
  # Show the filters that can be applied to the metadata database file

  clear
  echo "1. FileSystem filter"
  echo "2. Image File filter"
  echo "3. Type of file"
  echo "4. Orphan files (with no Inode)"
  echo "0. Exit menu"
  stty echo
  echo "Option:"
  read opt
  return $opt
}

function check_option_valid() {
  # Check if the option is in range
  # param $1: Max index that can be used
  # param $2: The variable to find out
  if [ -z "$2" ]; then
    return 1
  elif [ "$2" -lt 0 -o "$2" -gt $1 ]; then
    return 2
  else
    return 0
  fi
}

function choose_filter_and_show() {
  # Choose among the list of possible values and return the result
  # param $1: Column number in metadata file

  declare -a arr
  for i in $(cut -d'|' -f${1} $METAFILE | tail -n +2 | sort -u)
  do
    arr+=($i)
  done

  for idx in ${!arr[@]}
  do
    echo $idx" "${arr[$idx]}
  done
  echo "Choose option:"
  stty echo
  read opt

  check_option_valid ${#arr[@]} "$opt"
  if [ $? -ne 0 ]; then
    log info "ERROR: The option \"$opt\" selected is not valid"
    return 1
  fi

  awk -F'|' -v filter="${arr[$opt]}" -v col="${1}" '$col==filter {print $0}' $METAFILE | less
  return 0
}

function query_metadata_records() {
  # Query the metadata file and apply a filter

  METAFILE="${TARGETDIR}/${METADATAFILE}"
  show_filter_menu
  check_option_valid 4 "$?"
  if [ $? -ne 0 ]; then
    log info "ERROR: error option chosen"
    show_filter_menu
  fi

  case $opt in

    1) clear
       choose_filter_and_show 7
       query_metadata_records
       ;;

    2) clear
       choose_filter_and_show 4
       query_metadata_records
       ;;

    3) clear
       choose_filter_and_show 13
       query_metadata_records
       ;;

    4) clear
       awk -F'|' '$14=="" {print $0}' $METAFILE | less
       query_metadata_records
       ;;

    0) return 1
       ;;

    *) query_metadata_records
  esac
}

function show_analysis_tools_menu() {
  # Show a list of viewers of content
  clear
  echo "VIEWERS of CONTENT"
  echo "=================="
  echo " 1. Strings"
  echo " 2. Hex values"
  echo " 0. Exit"
  echo "Choose option: (0=exit)"
  stty echo
  read opt

  check_option_valid 2 "$opt"
  if [ $? -ne 0 ]; then
    log info "ERROR: The option is not correct"
    show_analysis_tools_menu
  fi

  if [ "$opt" -eq 0 ]; then
    return 1
  fi

  return $opt
}

function run_analysis() {
  # Run analysis of the files in the Config file
  # If the file has a plus character, it is an space
  # The files in the config_file_model.txt had to be renamed
  # changing their spaces by '+' sign instead of.

  local METAFILE="${TARGETDIR}/${METADATAFILE}"
  clear
  declare -a arr
  for i in ${ANALYSIS_FILES}
  do
    arr+=($i)
  done

  echo "LIST OF FILES TO ANALYZE"
  echo "========================"
  for idx in ${!arr[@]}
  do
    echo $idx" "${arr[$idx]} | tr '+' ' '
  done
  echo "Choose which one to begin: (Empty means exit to main menu)"
  stty echo
  read opt

  if [ -z "$opt" ]; then
    return 1
  fi

  check_option_valid ${#arr[@]} "$opt"
  if [ $? -ne 0 ]; then
    log info "ERROR: The option is not correct"
    run_analysis
  fi

  FILENAME_CHOSEN="$(echo ${arr[$opt]} | tr '+' ' ')"
  show_analysis_tools_menu
  RET="$?"
  local OPTIONS="$(awk -F'|' -v filename="${FILENAME_CHOSEN}" -v incoming="${INCOMING}" '$9==filename {print "-o "$6" -f "$7" "incoming"/"$4" "$14}' $METAFILE)"

  case $RET in

    1) # Strings
       log info "Extract the strings of the file \"${FILENAME_CHOSEN}\""
       icat $OPTIONS | strings | less
       run_analysis
       ;;

    2) # Hex values
       log info "Extract the Hex values of the file \"${FILENAME_CHOSEN}\""
       icat $OPTIONS | xxd | less
       run_analysis
       ;;

    0) return 1
       ;;

    *) run_analysis
  esac
}

