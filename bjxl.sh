#!/bin/bash

# just a script to convert all image to jxl
# require imagemagick, darktable, exiftool
# available parameter
# -r recursive , include all sub directories
# -del delete source file 
# -q=xx 1-100 image quality the higher is better large file size
# -e=x 1-9 Convertion effort higher is slower

# Function to parse command line arguments and extract attributes and their values
deletefile=0
reqursive=0
copyexif=0
jxlquality=''
jxleffort='-e 7'
darktable=/Applications/darktable.app/Contents/MacOS/darktable-cli

parse_arguments() 
{
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -del)
        #delete source fie 
        deletefile=1
        shift
        ;;

      -r)
        #include sub dir
        reqursive=1
        shift
        ;;

      -exif)
        # copy exif from source file
        # LR can read JXL exif but exiftool can't , set it to 1 so exiftool can read it too
        copyexif=1
        shift
        ;;

      -q=*)
        # Handle attributes with values
        quality=$(echo "$1"|cut -d= -f2-)
        if [ $quality -gt 0 ] && [ $quality -lt 100 ]; then
          jxlquality=" --lossless_jpeg=0 -q $quality "
        fi
        shift
        ;;

      -e=*)
        # Handle attributes with values
        effort=$(echo "$1"|cut -d= -f2-)
        if [ $effort -ge 0 ] && [ $effort -le 9 ]; then
          jxleffort="-e $effort"
        fi
        shift
        ;;
    esac
  done
}

get_icc_profile_name() 
{
  if [ $# -ne 1 ]; then
      return 1
  fi

  image_file="$1"
  exiftool_result=$(exiftool "$image_file")
  profile_name=$(echo "$exiftool_result" | grep "ICC Profile Name" | cut -d: -f2- | sed 's/^[ \t]*//')
  colorspace=$(echo "$exiftool_result" | grep "Interoperability Index" | cut -d: -f2- | sed 's/^[ \t]*//')

  if [ -n "$profile_name" ]; then
      echo "$profile_name"
  elif [ -n "$colorspace" ]; then
      echo "$colorspace"
  else 
    color_mode=$(identify -format "%[colorspace]" "$1")
    if [ -n "$color_mode" ]; then 
      echo $color_mode
    else
      echo "none"
    fi
  fi
}

fileConvert()
{
  i="$1"

  #check if file exist
  if [ ! -f "${i}" ] ; then return; fi;

  source_width=$(identify -format "%w," "$i" 2>/dev/null | cut -d, -f1) #just in case the file have multiple image just return the first one

  # Check if source_width is an integer
  if [[ ! "$source_width" =~ ^[0-9]+$ ]]; then
    # source_width is not an integer, set it to 0
    source_width=0
  fi

  if [ $source_width -le 1 ];then return; fi #not an image file, sometime it not an image file but identify return width 1

  fname="${i%.*}"
  fext="${i##*.}"
  fext=$(echo "$fext" | tr '[:upper:]' '[:lower:]')

  case "$fext" in
    #this ext list base on image supported by cjxl
    png|apng|gif|jiff|jpe|jpeg|jpg|exr|ppm|pfm|pgx)
      extconvert=0
    ;;

    #this ext list base on image supported by darktable
    3fr|ari|arw|bay|bmq|cap|cine|cr2|cr3|crw|cs1|dc2|dcr|dng|gpr|erf|fff|exr|ia|iiq|k25|kc2|kdc|mdc|mef|mos|mrw|nef|nrw|orf|pef|pfm|pxn|qtk|raf|raw|rdc|rw1|rw2|sr2|srf|srw|sti|x3f)

      #extract jpeg preview if available
      exiftool -b -JpgFromRaw "$i" > "#_tmps_${fname}.jpg"

      #if file size 0 raw don't have preview
      if [ ! -s "#_tmps_${fname}.jpg" ]; then 
         rm "#_tmps_${fname}.jpg"
      else
        #check preview size, sometime the image is slightly smaller but not much, if the diffrence less then 32 pixel just use it, but sometime it only a thumbnail 
         ori_width=$((source_width - 32))
         preview_width=$(identify -format "%w" "#_tmps_${fname}.jpg")
         
         if [ $ori_width -gt $preview_width  ]; then
           rm "#_tmps_${fname}.jpg"
         fi
      fi

      if [ -f "#_tmps_${fname}.jpg" ]; then
        #most of preview do not include exif, copy exif from raw
        exiftool -tagsfromfile "$i" -all:all "#_tmps_${fname}.jpg" >/dev/null 2>/dev/null
      else 
        #convert to jpg using darktable 
        $darktable "$i" "#_tmps_${fname}.jpg" --icc-type SRGB 2>/dev/null

        #if conversion fail remove temp file
        if [ $? -ne 0 ]; then rm "#_tmps_${fname}.jpg" 2>/dev/null ;fi
      fi

      if [ -f "#_tmps_${fname}.jpg" ]; then
        if [ $deletefile -eq 1 ]; then
          rm "$i"
        fi
        i="#_tmps_${fname}.jpg"
      else 
        #conversion fail skip the job
        return
      fi

      extconvert=0
    ;;

    # convert all other file let imagemagick do the rest
    *)
      extconvert=1
    ;;
  esac

  colorspace=""
  icc=$(get_icc_profile_name "$i")
  echo $i $icc

  case "$icc" in
    "sRGB IEC61966-2.1"|"R98 - DCF basic file (sRGB)"|"none")
      icc_convert=0
    ;;

    "CMYK")
      colorspace="-colorspace RGB"
      icc_convert=0
      extconvert=1
    ;;

    *)
      icc_convert=1
    ;;
  esac

  if [ $extconvert -eq 1 ] || [ $icc_convert -eq 1 ]; then

    if [ -n "$jxlquality" ] && [ $icc_convert -eq 1 ]; then
      mkdir __tmps__
      cp "$i" __tmps__
      cd __tmps__

      echo convert -quality 100 "$i"  +profile \* -profile ~/sRGB2014.icc  "#_tmps_${fname}.jpg"
      convert -quality 100 "$i" +profile * -profile ~/sRGB2014.icc  "../#_tmps_${fname}.jpg" 2>/dev/null 

      if [ $? -ne 0 ] ; then 
        #conversion fail skip the job
        cd ..; 
        rm -r __tmps__
        return; 
      fi

      cd ..
      rm -r __tmps__

    else 
      echo convert -quality 100 $colorspace "$i" "#_tmps_${fname}.jpg"
      convert -quality 100 $colorspace "$i" "#_tmps_${fname}.jpg" 2>/dev/null 

      #conversion fail skip the job
      if [ $? -ne 0 ] ; then return; fi
    fi

    if  [ -f "#_tmps_${fname}.jpg" ] ; then
      if [ $deletefile -eq 1 ]; then
        rm "$i"
      fi
      i="#_tmps_${fname}.jpg"

    # some time a file have multiple image just use the first one
    # next maybe an option to convert all image to individual jxl  
    elif [ -f "#_tmps_${fname}-0.jpg" ] ; then
      mv "#_tmps_${fname}-0.jpg" "#_tmps_${fname}.jpg"
      if [ $deletefile -eq 1 ]; then
        rm "$i"
      fi
      i="#_tmps_${fname}.jpg"
    else 
      #conversion fail skip the job
      return
    fi
  fi

  targetfile="$fname.jxl"

  # If target file exists, generate a unique name for it
  if [ -f "$targetfile" ]; then
      unique_suffix=1
      while [ -f "${fname}_${unique_suffix}.jxl" ]; do
          ((unique_suffix++))
      done
      targetfile="${fname}_${unique_suffix}.jxl"
  fi  

  echo cjxl $jxlquality $jxleffort "$i" "${targetfile}"
  cjxl $jxlquality $jxleffort "$i" "${targetfile}" 2>/dev/null

  if [ $? -eq 0 ] && [ -f "${targetfile}" ]; then
    #copy exif from source
    if [ $copyexif -eq 1 ]; then 
      exiftool -tagsfromfile "$i" -all:all "${targetfile}"
      rm "${targetfile}_original" 2>/dev/null
    fi

    if [ $deletefile -eq 1 ]; then rm "$i";fi
  fi

  #cleanup all temp
  rm \#_tmps_*.jpg 2>/dev/null
  rm \#_tmps_*.jpg_original 2>/dev/null
  rm -r __tmps__ 2>/dev/null
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
      if [[ "${i}" == *.jxl || "${i}" == *.JXL  || "${i}" == \#_tmps_*.jpg ]]; then
        continue
      fi

      fileConvert "${i}"
    fi
  done


  if [ "$1" != '.' ]; then 
    cd ..
  fi
}

parse_arguments "$@"

dirConvert .
