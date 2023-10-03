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

exitapp()
{
  #cleanup all temp before exiting
  if [ -n "$fname" ] ; then 
    rm "$tmpsfiles"* 2>/dev/null
    rm -r "${tmpsdir}" 2>/dev/null
  fi

  exit $1
}

createuniquename()
{
  local filename="$1"
  local fileext="$2"

  targetfile="${filename}.${fileext}"

  # If target file exists, generate a unique name for it
  if [ -f "$targetfile" ]; then
      unique_suffix=1
      while [ -f "${filename}_${unique_suffix}.${fileext}" ]; do
          ((unique_suffix++))
      done
      targetfile="${filename}_${unique_suffix}.${fileext}"
  fi 

  # reserve file 
  touch "$targetfile"

  echo "$targetfile"
}


parse_arguments "$@"

if [ ! -f "$input_file" ] ; then 
  echo "file not found" >&2
  exitapp 1; 
fi;

original_file="$input_file"
fixcolorspace=0
fname="${input_file%.*}"
fext="${input_file##*.}"
tmpsfiles="#__tmps__${fname}${fext}__"
tmpsfile="#__tmps__${fname}${fext}__.jpg"
tmpsdir="__tmps__${fname}${fext}__"
fext=$(echo "$fext" | tr '[:upper:]' '[:lower:]')

# Run the identify command with structured output and capture it
output=$(identify -format "Filetype: %m\nImageWidth: %w\nImageHeight: %h\nColorBit: %z\nColorSpace: %r\nICC Description: %[icc:description]\n" "$input_file" 2>&1)
#echo $output
filetype=$(echo "$output" | grep  -m 1 "Filetype" | cut -d: -f2- | sed 's/^[ \t]*//')
filetype=$(echo "$filetype" | tr '[:upper:]' '[:lower:]')

imagewidth=$(echo "$output" | grep -m 1 "ImageWidth" | cut -d: -f2- | sed 's/^[ \t]*//')
imageheight=$(echo "$output" | grep -m 1 "ImageHeight" | cut -d: -f2- | sed 's/^[ \t]*//')
colorbit=$(echo "$output" | grep "ColorBit" | cut -d: -f2- | sed 's/^[ \t]*//')
colorspace=$(echo "$output" | grep "ColorSpace" | cut -d: -f2- | sed 's/^[ \t]*//' | sed 's/DirectClass //' | tr -d ' ')
colorprofile=$(echo "$output" | grep "ICC Description" | cut -d: -f2- | sed 's/^[ \t]*//')
errormessage=$(echo "$output" | grep "identify" | cut -d: -f2- | sed -e 's/^[ \t]*//' -e 's/ .*$//')

#echo filetype: $filetype
#echo colorspace: $colorspace



#use case just in case the list will be long
case "$colorprofile" in
  "Display P3"|"ProPhoto RGB" )
    fixcolorspace=1
    ;;
esac

case "$colorspace" in
  "sRGB"| "sRGBAlpha")
    #do nothing

    ;;
    * )
      fixcolorspace=1
    ;;
esac

if [ "$errormessage" == "CorruptImageProfile" ]; then
  fixcolorspace=1
fi

if [ -z "$filetype" ] || [ $imagewidth -le 1 ];then 
  #not an image file, sometime imagemagick return width 1 for recognized file but not an image file  
  echo "file unrecognized or not an image file" >&2
  exitapp 1;
fi 

case "$filetype" in
  #this ext list base on image supported by cjxl
  png|apng|gif|jpe|jpeg|jpg|exr|ppm|pfm|pgx)
    extconvert=0
  ;;

  #this ext list base on image supported by darktable
  3fr|ari|arw|bay|bmq|cap|cine|cr2|cr3|crw|cs1|dc2|dcr|dng|gpr|erf|fff|exr|ia|iiq|k25|kc2|kdc|mdc|mef|mos|mrw|nef|nrw|orf|pef|pfm|pxn|qtk|raf|raw|rdc|rw1|rw2|sr2|srf|srw|sti|x3f)

    #extract jpeg preview if available
    #echo exiftool -b -JpgFromRaw "$input_file"
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
      #echo $darktable "$input_file" "$tmpsfile" --icc-type SRGB
      $darktable "$input_file" "$tmpsfile" --icc-type SRGB  >/dev/null 2>/dev/null

      #if conversion fail remove temp file
      if [ $? -ne 0 ]; then 
        echo "conversion fail or file not supported" >&2
        exitapp 1;
      fi
    fi

    if [ -f "$tmpsfile" ]; then
      if [ $deletefile -eq 1 ]; then
        rm "$input_file"
      fi
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

if [ $fixcolorspace -eq 1 ]  || [ $extconvert -eq 1 ]; then 
  # fix broken corrupt image color space or color space other than RGB
  if [ $fixcolorspace -eq 1 ] || [ "$colorspace" != "sRGB" ]; then 
    mkdir "${tmpsdir}"
    cp "$input_file" "${tmpsdir}"
    cd "${tmpsdir}"

    #echo convert -quality 100 "$input_file"  +profile \* -profile ~/sRGB2014.icc  "$tmpsfile"
    convert -quality 100 "$input_file" +profile * -profile ~/sRGB2014.icc  "../$tmpsfile" 2>/dev/null 

    if [ $? -ne 0 ] ; then 
      #conversion fail skip the job
      echo conversion fail skip the job >&2
      exitapp 1
    fi

    cd ..
    rm -r "${tmpsdir}"

  elif [ $extconvert -eq 1 ]; then
    #echo convert -quality 100 "$input_file" "$tmpsfile"
    convert -quality 100 "$input_file" "$tmpsfile" #2>/dev/null 

    #conversion fail skip the job
    if [ $? -ne 0 ] ; then 
      echo conversion fail skip the job >&2
      exitapp 1
    fi  
  fi
fi

if [ -f "${tmpsfiles}-0.jpg" ] ; then

  outputfile=$(createuniquename "$fname" "jxl")
  
  for i in "${tmpsfiles}"-*.jpg ; do 
    if [ $deletefile -eq 1 ]; then
      rm "$input_file"
    fi

    input_file="$i"

    if [ "$i" == "${tmpsfiles}-0.jpg" ]; then
      targetfile="$outputfile"
    else
      fnameout="${outputfile%.*}"
      targetfile=$(echo "$i" | sed "s/$tmpsfiles/$fnameout/" | sed 's/.jpg//')
      targetfile=$(createuniquename "$targetfile" "jxl")
    fi

    echo "$original_file > ${targetfile}"
    #echo cjxl $jxlquality $jxleffort "$input_file" "${targetfile}"
    cjxl $jxlquality $jxleffort "$input_file" "${targetfile}" 2>/dev/null

    if [ $? -eq 0 ] && [ -f "${targetfile}" ]; then
      #copy exif from source
      if [ $copyexif -eq 1 ]; then 
        exiftool -tagsfromfile "$input_file" -all:all "${targetfile}"
        rm "${targetfile}_original" 2>/dev/null
      fi

      if [ $deletefile -eq 1 ]; then rm "$input_file";fi
    else
      rm "${targetfile}" 2>/dev/null
    fi

  done
  #if [ $deletefile -eq 1 ]; then
  #  rm "$input_file"
  #fi
  input_file="${tmpsfiles}-0.jpg"
else 
  if  [ -f "$tmpsfile" ] ; then
    # file is single image
    if [ $deletefile -eq 1 ]; then
      rm "$input_file"
    fi


    input_file="$tmpsfile"
  fi

  if [ -n "$output_file" ]; then

    targetfile="$output_file"
    if [ -f $targetfile ] && [ $rewritefile -eq 0 ]; then
      fnameout="${targetfile%.*}"
      fextout="${targetfile##*.}"
      targetfile=$(createuniquename "$fnameout" "$fextout")
    fi
  else
    targetfile=$(createuniquename "$fname" "jxl")
  fi

  echo "$original_file > ${targetfile}"
  #echo cjxl $jxlquality $jxleffort "$input_file" "${targetfile}"
  cjxl $jxlquality $jxleffort "$input_file" "${targetfile}" 2>/dev/null

  if [ $? -eq 0 ] && [ -f "${targetfile}" ]; then
    #copy exif from source
    if [ $copyexif -eq 1 ]; then 
      exiftool -tagsfromfile "$input_file" -all:all "${targetfile}"
      rm "${targetfile}_original" 2>/dev/null
    fi

    if [ $deletefile -eq 1 ]; then rm "$input_file";fi
  fi
fi

exitapp 0
