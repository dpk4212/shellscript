#!/bin/bash

# just a script to convert all image to jxl
# require imagemagick, darktable, exiftool
# available parameter
# -r recursive , include all sub directories
# -del delete source file 
# -q=xx image quality

# Function to parse command line arguments and extract attributes and their values
quality=0
deletefile=0
reqursive=0
jxlquality=''
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
      -q=*)
        # Handle attributes with values
        quality=$(echo "$1"|cut -d= -f2-)
        if [ $quality -gt 0 ] && [ $quality -lt 100 ]; then
          jxlquality=" --lossless_jpeg=0 -q $quality "
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
    echo "none"
  fi
}

fileConvert()
{
  i="$1"

  #check if file exist
  if [ ! -f "${i}" ] ; then return; fi;

  fname="${i%.*}"
  fext="${i##*.}"
  fext=$(echo "$fext" | tr '[:upper:]' '[:lower:]')

  case "$fext" in
    #this ext list base on image supported by cjxl
    png|apng|gif|jpeg|jpg|exr|ppm|pfm|pgx)
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
        #check preview size, sometime it only a thumbnail
         ori_width=$(identify -format "%w" "$i")
         ori_width=$((ori_width - 32))
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

    #this ext list base on image supported by imagemagick
    aai|ai|art|avif|avs|bgr|bgra|bgro|bmp|bmp2|bmp3|brf|cin|cip|cur|cut|dcm|dicom|dcraw|dcx|dds|dfont|dot|dpx|dxt1|dxt5|epdf|epi|eps|eps2|eps3|epsf|epsi|ept|ept2|ept3|ff|ftp|fts|ftxt|heic|heif|hrz|j2c|j2k|jng|jnx|jpc|jpe|jpm|jps|jpt|miff|mpc|pcds|pcl|pct|pcx|pdb|pes|pfa|pfb|pgm|phm|pix|pjpeg|pnm|ps|ps2|ps3|psb|psd|ptif|pwp|qoi|ras|rgf|rla|rle|rmf|scr|sct|sfw|sgi|six|svg|svgz|tga|tif|tiff|tim|tm2|ttc|ttf|vips|wbmp|webm|webp|wpg|xcf|xpm)
      extconvert=1  
    ;;

    # do not process other file
    *)
      return
    ;;
  esac

  icc=$(get_icc_profile_name "$i")

  case "$icc" in
    "sRGB IEC61966-2.1"|"R98 - DCF basic file (sRGB)"|"none")
      icc_convert=0
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
      convert -quality 100 "$i"  +profile * -profile ~/sRGB2014.icc  "../#_tmps_${fname}.jpg" 2>/dev/null 
      if [ $? -ne 0 ] ; then cd ..; return; fi

      cd ..
      rm -r __tmps__

    else 
      echo convert -quality 100 "$i" "#_tmps_${fname}.jpg"
      convert -quality 100 "$i"  "#_tmps_${fname}.jpg" 2>/dev/null 
      if [ $? -ne 0 ] ; then return; fi
    fi

    if  [ -f "#_tmps_${fname}.jpg" ] ; then
      if [ $deletefile -eq 1 ]; then
        rm "$i"
      fi
      i="#_tmps_${fname}.jpg"
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

  echo cjxl $jxlquality  "$i" "${targetfile}"
  cjxl $jxlquality  "$i" "${targetfile}" 2>/dev/null

  if [ $? -eq 0 ] && [ -f "${targetfile}" ] && [ $deletefile -eq 1 ]; then
    rm "$i"
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
