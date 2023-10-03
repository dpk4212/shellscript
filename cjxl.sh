#!/bin/bash

# just a script to convert all image to jxl
# require imagemagick, darktable, exiftool
# available parameter
# -r recursive , include all sub directories
# -del delete source file 
# -q=xx 1-100 image quality the higher is better large file size
# -e=x 1-9 Convertion effort higher is slower

# Function to parse command line arguments and extract attributes and their values
showdebug=0
deletefile=0
rewritefile=0
copyexif=0
jxlquality=''
jxleffort='-e 7'
darktable=/Applications/darktable.app/Contents/MacOS/darktable-cli
input_file=""
output_file=""

parse_arguments() 
{
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -del)
        #delete source fie 
        deletefile=1
        shift
        ;;

      -y)
        #delete source fie 
        rewritefile=1
        shift
        ;;

      -debug)
        #delete source fie 
        showdebug=1
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

      *)
        # Assume the argument is a file path (input or output)
        if [ -z "$input_file" ]; then
          input_file="$1"
        else
          output_file="$1"
        fi
        shift
        ;;
    esac
  done
}

showdebug() {
  if [ $showdebug -eq 1 ]; then
    echo "Debug Info: $*"
  fi
}

imageinfo()
{
    showdebug $filepath
    showdebug $original_file
    showdebug filetype: $filetype
    showdebug imagewidth $imagewidth
    showdebug imageheight $imageheight
    showdebug colorbit=$colorbit
    showdebug colorspace: $colorspace 
    showdebug colorprofile: $colorprofile    
}
exitapp()
{
  imageinfo

  #cleanup all temp before exiting
  showdebug delete all temp

  if [ -n "$fname" ] && [ $showdebug -eq 0 ]; then 
    rm "$tmpsfiles"* 2>/dev/null
    rm -r "${tmpsdir}" 2>/dev/null
  fi    
  
  if [ $deletefile -eq 1 ] && [ $1 -eq 0 ]; then
    #remove original file if conversion success 
    showdebug delete orriginal file \"$original_file\"
    rm "$original_file" 2>/dev/null
  fi

  if [ $1 -ne 0 ]; then
    echo "Conversion Fail"
  fi

  exit $1
}

createuniquename()
{
  local dirpath="$1"
  local filename="$2"
  local fileext="$3"

  targetfile="${dirpath}/${filename}.${fileext}"

  # If target file exists, generate a unique name for it
  if [ -f "$targetfile" ]; then
      unique_suffix=1
      while [ -f "${dirpath}/${filename}_${unique_suffix}.${fileext}" ]; do
          ((unique_suffix++))
      done
      targetfile="${dirpath}/${filename}_${unique_suffix}.${fileext}"
  fi 

  # reserve file 
  touch "$targetfile"

  echo "$targetfile"
}


parse_arguments "$@"

if [ ! -f "$input_file" ] ; then 
  echo "file not found" >&2
  exit 1; 
fi;

if [ ! -s "$input_file" ] ; then 
  echo "Not an image file" >&2
  exit 1; 
fi;

filepath=$(pwd)
original_file="$input_file"
filename=$(basename "$input_file")
inputdir=$(dirname "$input_file")
fname="${filename%.*}"
fext="${filename##*.}"

if [ -n "$output_file" ]; then
  outputdir=$(dirname "$output_file")  
  output_file=$(basename "$output_file")  
else
  output_file="${fname}.jxl"
  outputdir="$inputdir"
fi


tmpsfiles="#__tmps__${fname}${fext}__"
tmpsfile="#__tmps__${fname}${fext}__.jpg"
tmpsdir="__tmps__${fname}${fext}__"

fext=$(echo "$fext" | tr '[:upper:]' '[:lower:]')

#this ext list base on image supported by imagemagick
case $fext in
  3fr|aai|ai|apng|art|arw|ashlar|avif|avs|bayer|bayera|bgr|bgra|bgro|bmp|bmp2|bmp3|brf|cal|cals|cin|cip|clip|cmyk|cmyka|cr2|cr3|crw|cube|cur|cut|data|dcm|dcr|dcraw|dcx|dds|dfont|dng|dot|dpx|dxt1|dxt5|epdf|epi|eps|eps2|eps3|epsf|epsi|ept|ept2|ept3|erf|exr|ff|file|fits|fl32|flv|ftp|fts|ftxt|g3|g4|gif|gif87|gray|graya|group4|gv|hald|hdr|heic|heif|hrz|htm|html|http|https|icb|ico|icon|iiq|ipl|j2c|j2k|jng|jnx|jp2|jpc|jpe|jpeg|jpg|jpm|jps|jpt|jxl|k25|kdc|mac|map|mask|mat|matte|mef|miff|mng|mono|mpc|mpeg|mpg|mpo|mrw|msl|msvg|mtv|mvg|nef|nrw|null|ora|orf|otb|otf|pal|palm|pam|pbm|pcd|pcds|pcl|pct|pcx|pdb|pdf|pdfa|pef|pes|pfa|pfb|pfm|pgm|pgx|phm|picon|pict|pix|pjpeg|png|png00|png24|png32|png48|png64|png8|pnm|ppm|ps|ps2|ps3|psb|psd|ptif|pwp|qoi|raf|ras|raw|rgb|rgb565|rgba|rgbo|rgf|rla|rle|rmf|rw2|scr|sct|sfw|sgi|six|sixel|sr2|srf|sun|svg|svgz|tga|tiff|tiff64|tile|tim|tm2|ttc|ttf|ubrl|ubrl6|uil|uyvy|vda|vicar|vid|viff|vips|vst|wbmp|webp|wpg|x3f|xbm|xc|xcf|xpm|xps|xv|yaml|yuv )
    supportedfile=1
  ;;

  *)
    echo "unsupported file" >&2
    exit 1;
  ;;
esac

# Run the identify command with structured output and capture it
output=$(identify -format "Filetype: %m\nImageWidth: %w\nImageHeight: %h\nColorBit: %z\nColorSpace: %[colorspace]\nICC Description: %[icc:description]\n" "$input_file" 2>&1)
# secho $output
filetype=$(echo "$output" | grep  -m 1 "Filetype" | cut -d: -f2- | sed 's/^[ \t]*//')
filetype=$(echo "$filetype" | tr '[:upper:]' '[:lower:]')

imagewidth=$(echo "$output" | grep -m 1 "ImageWidth" | cut -d: -f2- | sed 's/^[ \t]*//')
imageheight=$(echo "$output" | grep -m 1 "ImageHeight" | cut -d: -f2- | sed 's/^[ \t]*//')
colorbit=$(echo "$output" | grep "ColorBit" | cut -d: -f2- | sed 's/^[ \t]*//')
colorspace=$(echo "$output" | grep "ColorSpace" | cut -d: -f2- | sed 's/^[ \t]*//' | sed 's/DirectClass //' | tr -d ' ')
colorprofile=$(echo "$output" | grep "ICC Description" | cut -d: -f2- | sed 's/^[ \t]*//')
errormessage=$(echo "$output" | grep "identify" | cut -d: -f2- | sed -e 's/^[ \t]*//' -e 's/ .*$//')

if [ -z "$filetype" ] || [ $imagewidth -le 1 ];then 
  #not an image file, sometime imagemagick return width 1 for recognized file but not an image file  
  echo "file unrecognized or not an image file" >&2
  exitapp 1;
fi 

# just in case there's video disguise as image
case $filetype in
  "mp4" | "mkv" | "mov" | "mp5" | "hevc" )
    echo "unsupported file" >&2
    exitapp 1;
    ;;
esac

fixcolorspace=0
converttoColorRGB=0
extconvert=0

if [[ "$errormessage" == "CorruptImageProfile" || "$colorprofile" == "Display P3" || "$colorprofile" == "ProPhoto RGB" || "$colorprofile" == "c2" || "$colorprofile" == "AdobeRGB" || "$colorprofile" == "Adobe RGB (1998)" || "$colorspace" == "Gray"  || "$colorspace" == "CMYK" ]]; then
  fixcolorspace=1
elif [[ "$colorprofile" == sRGB* || "$colorspace" == sRGB* || "$colorprofile" == "uRGB" || "$colorspace" == "uRGB" ]]; then
    fixcolorspace=0
else
  exitapp 1
fi

case "$fext" in
  #this ext list base on image supported by cjxl
  png|apng|gif|jpe|jpeg|jpg|exr|ppm|pfm|pgx)
    extconvert=0
  ;;

  #this ext list base on image supported by darktable
  3fr|ari|arw|bay|bmq|cap|cine|cr2|cr3|crw|cs1|dc2|dcr|dng|gpr|erf|fff|exr|ia|iiq|k25|kc2|kdc|mdc|mef|mos|mrw|nef|nrw|orf|pef|pfm|pxn|qtk|raf|raw|rdc|rw1|rw2|sr2|srf|srw|sti|x3f)

    #extract jpeg preview if available
    echo exiftool -b -JpgFromRaw "$input_file"
    exiftool -b -JpgFromRaw "$input_file" > "$tmpsfile" 2>/dev/null

    #if file size 0 raw don't have preview
    if [ ! -s "$tmpsfile" ]; then 
       rm "$tmpsfile"
    else
      #check preview size, sometime the image is slightly smaller but not much, if the diffrence less then 32 pixel just use it, but sometime it only a thumbnail 
       ori_width=$((imagewidth - 32))
       preview_width=$(identify -format "%w" "$tmpsfile")
       
       if [ $ori_width -gt $preview_width  ]; then
         rm "$tmpsfile"
       fi
    fi

    if [ -f "$tmpsfile" ]; then
      #most of preview do not include exif, copy exif from raw
      exiftool -tagsfromfile "$input_file" -all:all "$tmpsfile" >/dev/null 2>/dev/null
    else 
      #convert to jpg using darktable 
      echo $darktable "$input_file" "$tmpsfile" --icc-type SRGB
      $darktable "$input_file" "$tmpsfile" --icc-type SRGB  >/dev/null 2>/dev/null

      #if conversion fail remove temp file
      if [ $? -ne 0 ]; then 
        echo "conversion fail or file not supported" >&2
        exitapp 1;
      fi
    fi

    if [ -f "$tmpsfile" ]; then
      input_file="$tmpsfile"
    fi

    # already converted 
    fixcolorspace=0
    extconvert=0
  ;;

  # convert all other file let imagemagick do the rest
  *)
    extconvert=1
  ;;
esac

# fix broken corrupt image color space or color space other than RGB
if [ $fixcolorspace -eq 1 ] ; then 
  mkdir "${tmpsdir}"
  cp "$input_file" "${tmpsdir}"
  cd "${tmpsdir}"

  if [ "$colorspace" == "CMYK" ]; then
    #showdebug convert -quality 100 "$input_file" -colorspace RGB  "../$tmpsfile" 2>/dev/null 
    #convert -quality 100 "$input_file" -colorspace RGB  "../$tmpsfile" 2>/dev/null 

    showdebug convert -quality 100 "$input_file" +profile \* -profile ~/sRGB2014.icc  "$tmpsfile"
    convert -quality 100 "$input_file" +profile * -profile ~/sRGB2014.icc  "../$tmpsfile" 2>/dev/null 
  elif [ "$colorspace" == "Gray" ]; then
    showdebug convert -quality 100 "$input_file" -colorspace sRGB -type truecolor "$tmpsfile"
    convert -quality 100 "$input_file" -colorspace sRGB -type truecolor "../$tmpsfile" 2>/dev/null 
  else
    showdebug convert -quality 100 "$input_file"   -colorspace sRGB -type truecolor  +profile \* -profile ~/sRGB2014.icc  "$tmpsfile"
    convert -quality 100 "$input_file"  -colorspace sRGB -type truecolor  +profile * -profile ~/sRGB2014.icc  "../$tmpsfile" 2>/dev/null 
  fi

  if [ $? -ne 0 ] ; then 
    #conversion fail skip the job
    echo conversion fail skip the job >&2
    exitapp 1
  fi

  cd ..
  rm -r "${tmpsdir}"

elif [ $extconvert -eq 1 ]; then
  showdebug convert -quality 100 "$input_file" "$tmpsfile"
  convert -quality 100 "$input_file" "$tmpsfile" #2>/dev/null 

  #conversion fail skip the job
  if [ $? -ne 0 ] ; then 
    echo conversion fail skip the job >&2
    exitapp 1
  fi  
fi

if [ -f "${tmpsfiles}-0.jpg" ] ; then

  baseoutputname="$output_file"
  if [ $rewritefile -eq 0 ]; then
    fnameout="${baseoutputname%.*}"
    fextout="${baseoutputname##*.}"
    baseoutputname=$(createuniquename "$outputdir" "$fnameout" "$fextout")
    baseoutputname=$(basename "$baseoutputname")
  fi

  errorexist=0

  for i in "${tmpsfiles}"-* ; do 
    input_file="$i"

    if [ "$i" == "${tmpsfiles}-0.jpg" ]; then
      targetfile="${outputdir}/$baseoutputname"
    else
      fnameout="${baseoutputname%.*}"
      fextout="${baseoutputname##*.}"
      outputname=$(echo "$i" | sed "s/$tmpsfiles/$fnameout/" | sed 's/.jpg//')
      targetfile="${outputdir}/${outputname}.${fextout}"
      if [ $rewritefile -eq 0 ]; then
        targetfile=$(createuniquename "$outputdir" "$outputname" "$fextout")
      fi
    fi

    echo "$original_file > ${targetfile}"
    showdebug cjxl $jxlquality $jxleffort "$input_file" "${targetfile}"
    cjxl $jxlquality $jxleffort "$input_file" "${targetfile}" 2>/dev/null

    if [ $? -eq 0 ] && [ -s "${targetfile}" ]; then
      #copy exif from source
      if [ $copyexif -eq 1 ]; then 
        exiftool -tagsfromfile "$input_file" -all:all "${targetfile}"
        rm "${targetfile}_original" 2>/dev/null
      fi
    else
      rm "${targetfile}" 2>/dev/null
      errorexist=1
      #
    fi
  done

  exitapp $errorexist
else 
  if  [ -f "$tmpsfile" ] ; then
    # file is single image
    input_file="$tmpsfile"
  fi

  targetfile="${outputdir}/${output_file}"
  if [ $rewritefile -eq 0 ]; then
    fnameout="${output_file%.*}"
    fextout="${output_file##*.}"
    targetfile=$(createuniquename "$outputdir" "$fnameout" "$fextout")
  fi

  echo "$original_file > ${targetfile}"
  showdebug cjxl $jxlquality $jxleffort "$input_file" "${targetfile}"
  cjxl $jxlquality $jxleffort "$input_file" "${targetfile}" 2>/dev/null

  if [ $? -eq 0 ] && [ -s "${targetfile}" ]; then
    #copy exif from source
    if [ $copyexif -eq 1 ]; then 
      exiftool -tagsfromfile "$input_file" -all:all "${targetfile}"
      rm "${targetfile}_original" 2>/dev/null
    fi
    exitapp 0
  else
    rm "${targetfile}" 2>/dev/null
    exitapp 1
  fi
fi


