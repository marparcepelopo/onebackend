#!/bin/bash

# VARIABLES
BASEDIR=${HOME}"/one/"
CONFIG_FILE=${BASEDIR}"configfile.conf"
CASE=""
ALIAS=""

# Load library
source ${BASEDIR}common.sh
if [ $? -ne 0 ]; then
  echo "ERROR: There was an error loading the library common.sh"
  exit 1
fi

function help() {
  # A short brief help to guide you throught the functionaly of this menu
  echo "HELP"
  echo "===="
  echo
  echo "The menu has 7 items
}

function show_menu() {
#  clear
  echo "MENU"
  echo "1. Copiar datos"
  echo "2. Carga de fichero de configuracion"
  echo "3. Busqueda"
  echo "4. Ver listado de fichero en \"incoming\""
  echo "5. Ejecutar analisis de ficheros segun fichero de config"
  echo "6. Capturar resultado de una evidencia"
  echo "7. Consultar estado de las importaciones y metadatos ya realizados"
  echo "0. Salir"
  echo "Choose option:"
  stty echo
  read opt
  return $opt
  }

function main() {
  clear
  check_config_loaded
  show_menu
  while :
  do
    case $opt in

      1) clear
         option_picked "1. Copia de datos"
         if [ -z "$TARGETDIR" ]; then
           echo "Write the target directory of the copy: \(empty=cancel\)"
           read TARGETDIR
         fi
         check_directory "$TARGETDIR"
         ls ${INCOMINGDIR}/*.E01 >/dev/null 2>&1
         if [ $? -eq 0 ]; then
           copy_data_to &
         else
           echo "There is no EnCase file found in the \"incoming\" folder"
         fi
         show_menu
         ;;

      2) clear
         option_picked "2. Carga de fichero de configuracion"
         echo
         carga_config
         show_menu
         ;;

      3) clear
         option_picked "3. Busqueda"
         query_metadata_records
         show_menu
         ;;

      4) clear
         option_picked "4. Ver listado de ficheros en \"incoming\""
         ls -l $INCOMINGDIR
         show_menu
         ;;
         
      5) clear
         option_picked "5. Ejecutar analisis de ficheros segun fichero de config"
         run_analysis
         show_menu
         ;;

      6) clear
         option_picked "6. Capturar resultado de una evidencia"
         ls $INCOMINGDIR/*.E01 | awk '{print ++val, $1}'
         echo "Choose a file to get a capture of the partition layout (empty=cancel):"
         read num
         if [ -n "$num" -a "$num" -ge 1 -a "$num" -le "`ls $INCOMINGDIR/*.E01|wc -l`" ]; then
           mmls "`ls $INCOMINGDIR/*.E01 | head -$num | tail -1`"
         elif [ -z "$num" ]; then
           show_menu
         else
           echo "ERROR: the number is not correct"
         fi
         show_menu
         ;;

      7) clear
         option_picked "7. Consultar estado de las importaciones y metadatos ya realizados"
         find_imports
         show_menu
         ;;

      0) clear
         exit 1
         ;;

      *) clear
         show_menu
         ;;

      exit) exit
    esac
  done
  }


# MAIN
if [ ! -f $CONFIG_FILE ]; then
  touch $CONFIG_FILE
fi

if [ -n "$1" -a "$1" = "-h" ]; then
  help
  exit 1
fi

main
