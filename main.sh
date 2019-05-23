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
  echo "HELP (opcion -h)"
  echo "================"
  echo
  echo "The menu has 7 items"
  echo "1. Copia datos"
  echo " Inicia el proceso de copia de datos de las imagenes en formato EnCase"
  echo " en segundo plano."
  echo "2. Carga de fichero de configuracion"
  echo " Pregunta por donde leer el fichero de configuracion, y hace la carga de dicho fichero"
  echo " Formato de fichero de configuracion:"
  echo "  CASE=<valor> (obligatorio)"
  echo "  ALIAS=<valor> (obligatorio)"
  echo "  TARGETDIR=<Directorio destino de la copia>"
  echo "  LOGFILE=<Archivo de log>"
  echo "  INCOMING=<Carpeta de ficheros de imagen"
  echo "  METAFILE=<fichero de metadatos generico para toda la copia>"
  echo "  ANALYSIS_FILES=<Ficheros a analizar en el paso 5> (obligatorio)"
  echo "3. Busqueda."
  echo " Se muestran varios filtros de busqueda (FS, IMAGE, FILETYPE, ORPHAN ENTRIES)."
  echo "4. Ver listado de fichero en \"incoming\""
  echo " Muestra los ficheros de imagen que hay en la carpeta de INCOMING"
  echo "5. Ejecutar analisis de ficheros segun fichero de config"
  echo " Se muestran los ficheros con la etiqueta ANALYSIS_FILES y se les puede analizar"
  echo " mostrando 1. Strings y 2. Valores hexa"
  echo "6. Capturar resultado de una evidencia"
  echo " Muestra un menu con los ficheros de imagen y el que elijas, te muestra su partition layout"
  echo "7. Consultar estado de las importaciones y metadatos ya realizados"
  echo " Muestra el listado de importaciones realizadas y cuandtos registros se han copiado, y"
  echo " importaciones en curso, con el mismo resultado de registros importados / registros totales"
  echo "0. Salir"
}

function show_menu() {
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
         
         local CONT="no"
         # Check the existance of an old metadatafile.dat
         if [ -f "$TARGETDIR/metadatafile.dat" ]; then
           echo "An old copy process was detected. Do you want to go on?"
           are_you_sure
           if [ $? -eq 1 ]; then
             local CONT="continue"
           else
             check_directory "$TARGETDIR"
           fi
         fi

         ls ${INCOMINGDIR}/*.E01 >/dev/null 2>&1
         if [ $? -eq 0 ]; then
           copy_data_to "$CONT" &
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
         pkill main.sh
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
