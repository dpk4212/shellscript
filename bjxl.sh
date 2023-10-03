#!/bin/bash

# just a script to convert all image to jxl
# require imagemagick, darktable, exiftool
# available parameter
# -r recursive , include all sub directories
# -del delete source file 
# -q=xx 1-100 image quality the higher is better large file size
# -e=x 1-9 Convertion effort higher is slower

# Function to parse command line arguments and extract attributes and their values
deletefile=''
reqursive=''
copyexif=''
jxlquality=''
jxleffort=''
bjxlpath="$0" 
basedir=$(dirname "$bjxlpath")  
cjxlpath="${basedir}/cjxl.sh"
thread=1

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
  done
}


parse_arguments() 
{
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -del)
        #delete source fie 
        deletefile="$1"
        shift
        ;;

      -r)
        #include sub dir
        reqursive="$1"
        shift
        ;;

      -exif)
        copyexif="$1"
        shift
        ;;

      -q=*)
        jxlquality="$1"
        shift
        ;;

      -e=*)
        jxleffort="$1"
        shift
        ;;

      -thread=*)
        # Handle attributes with values
        threadval=$(echo "$1"|cut -d= -f2-)
        if [ $threadval -gt 0 ] && [ $threadval -le 100 ]; then
          thread=$threadval
        fi
        shift
        ;;

    esac
  done
}


dirConvert()
{
  echo "$1"
  cd "$1"
      
  for i in * ; do 
    if [ -d "${i}" ] && [ $reqursive -eq 1 ] ; then
      dirConvert "${i}"
    fi

    if [ -f "${i}" ] ; then
      #do not process jxl and temp file
      if [[ "${i}" == *.jxl || "${i}" == *.JXL  || "${i}" == \#__tmps* ]]; then
        continue
      fi

      #echo "$i"
      #echo "$cjxlpath" "$i" $deletefile $copyexif $jxlquality $jxleffort
      if [ $thread -eq 1 ]; then
        sh "$cjxlpath" "$i" $deletefile $copyexif $jxlquality $jxleffort
      else 
        sh "$cjxlpath" "$i" $deletefile $copyexif $jxlquality $jxleffort 2>/dev/null & 
        zleep cjxl.sh $thread
      fi
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