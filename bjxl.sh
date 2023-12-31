#!/bin/bash

# just a script to convert all image to jxl
# require imagemagick, darktable, exiftool
# available parameter
# -r recursive , include all sub directories
# -del delete source file 
# -q=xx 1-100 image quality the higher is better large file size
# -e=x 1-9 Convertion effort higher is slower

# Function to parse command line arguments and extract attributes and their values
reqursive=0
bjxlpath="$0" 
basedir=$(dirname "$bjxlpath")  
cjxlpath="${basedir}/cjxl.sh"
thread=1
showdebug=''
extlist=()
params=()
param=""
inputdir=$(pwd)
outputbasedir=""

if [ ! -f "$cjxlpath" ]; then
  echo $cjxlpath
  echo "cjxl.sh not found"
  exit 1
fi

zleep()
{
  threads=$(ps | grep "$1" | grep -v grep | wc -l)

  while [ $threads -gt $2 ]; do
      threads=$(ps | grep "$1" | grep -v grep | wc -l)
      sleep 0.001
  done
}


parse_arguments() 
{
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -del|-exif|-y|-debug|-raw|-single)
        #delete source fie 
        params+=("$1")
        shift
        ;;

      -q|-e)
        #delete source fie 
        params+=("$1 $2")
        shift
        shift
        ;;

      -r)
        #include sub dir
        reqursive=1
        shift
        ;;

      -thread)
        # Handle attributes with values
        threadval=$(echo "$2")
        if [ $threadval -gt 0 ] && [ $threadval -le 100 ]; then
          thread=$threadval
        fi
        shift
        shift
        ;;

      -d)
        # Handle attributes with values
        outputbasedir=$(echo "$2")
        shift
        shift
        ;;

      *)
        extlist+=("$1")
        shift
      ;;

    esac
  done

  # Loop through the array and concatenate elements with spaces
  for p in "${params[@]}"; do
      param+=" $p"
  done
}


fileconvert()
{
  ls *.$1  >/dev/null 2>/dev/null|| return

  if [[ -n "$outputbasedir" ]]; then
    currentdir=$(pwd)
    outputdir=$(echo "$currentdir" | sed "s|${inputdir}|${outputbasedir}|")
  fi

  for i in *.$1 ; do 
    if [ -f "${i}" ] ; then

      # do not convert JXL and temp files
      if [[ "${i}" == *.jxl || "${i}" == *.JXL  || "${i}" == .__tmps__* || "${i}" == __tmps__* ]]; then
        continue
      fi

      if [ $thread -eq 1 ]; then
        sh "$cjxlpath" -i "$i" -b $param -d "$outputdir"
      else 
        sh "$cjxlpath" -i "$i" -b $param -d "$outputdir" 2>/dev/null & 
        zleep cjxl.sh $thread
      fi
    fi
  done
}


dirConvert()
{
  cd "$1"
  pwd
      
  # only convert listed ext
  if [ ${#extlist[@]} -gt 0 ]; then
    for ext in "${extlist[@]}"; do
      fileconvert "$ext"
    done

  # convert all files
  else
    fileconvert "*"
  fi


  for i in * ; do 
    if [ -d "${i}" ] && [ $reqursive -eq 1 ] ; then
      dirConvert "${i}"
    fi
  done


  if [ "$1" != '.' ]; then 
    cd ..
  fi
}

parse_arguments "$@"

dirConvert .

if [ $thread -gt 1 ];then
  zleep cjxl.sh 0
fi