#!/bin/bash

# just a script to convert all images to jxl
# require imagemagick, darktable, exiftool
# available parameter
# -r recursive, include all subdirectories
# -del delete source file 
# -q=xx 1-100 image quality the higher is better large file size
# -e=x 1-9 Conversion effort higher is slower

# Function to parse command line arguments and extract attributes and their values
sdfiles=0
showdebug=0
deletefile=0
rewritefile=0
copyexif=0
singlefile=0
jxlquality=''
jxleffort='-e 7'
darktable=/Applications/darktable.app/Contents/MacOS/darktable-cli
iccpath=~/sRGB2014.icc
inputfile=""
outputfile=""

 
# An intermediate format for conversions between the source and target if necessary. 
# Any format will suffice as long as it's supported by cjxl, 
# such as png, apng, gif, jpe, jpeg, jpg, exr, ppm, pfm, or pgx. 
# PNG is recommended for its quality, 
# while JPG may be chosen for faster conversion speeds.
extBridge=jpg

parse_arguments() 
{
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -del)
        # Delete the original file if the conversion is successful.
        deletefile=1
        shift
        ;;

      -y)
        # force to rewrite output file
        rewritefile=1
        shift
        ;;

      -debug)
        # just for debugging purposes 
        showdebug=1
        shift
        ;;

      -exif)
        # Copy the EXIF data from the source file. 
        # Digikam can't display EXIF data, but Lightroom can show minimal EXIF data. 
        # Set it to 1 to copy the EXIF data from the source, so Exiftool can display all EXIF information. 
        # If you set 'copyexif' to 0, use djxl if you plan to convert JXL to another format.
        # using another tool might result in the loss of image EXIF information.
        copyexif=1
        shift
        ;;

      -single)
        # only convert first image on multi-image file such as PDF or other format
        singlefile=1
        shift
        ;;

      -ai)
        # Image from the stable diffusion keep generated prompt in EXIF properties or user comments. 
        # Make sure to retain this data in the exported file.
        sdfiles=1
        shift
        ;;

      -q=*)
        # JXL output quality
        quality=$(echo "$1"|cut -d= -f2-)
        if [ $quality -gt 0 ] && [ $quality -lt 100 ]; then
          jxlquality=" --lossless_jpeg=0 -q $quality "
        fi
        shift
        ;;

      -e=*)
        # conversion effort 
        effort=$(echo "$1"|cut -d= -f2-)
        if [ $effort -ge 0 ] && [ $effort -le 9 ]; then
          jxleffort="-e $effort"
        fi
        shift
        ;;

      *)
        # Assume the argument is a file path (input or output)
        if [ -z "$inputfile" ]; then
          inputfile="$1"
        else
          outputfile="$1"
        fi
        shift
        ;;
    esac
  done
}

showdebug() {
  if [ $showdebug -eq 1 ]; then
    echo "#: $*"
  fi
}

imageinfo()
{
    showdebug $filepath
    showdebug $original_file
    showdebug filetype $filetype
    showdebug imagewidth $imagewidth
    showdebug imageheight $imageheight
    showdebug colorbit $colorbit
    showdebug colorspace \'$colorspace\'
    showdebug colorprofile \'$colorprofile\'
    showdebug number_of_images \'$number_of_images\'    
    showdebug extconvert \'$extconvert\'
    showdebug fixcolorspace \'$fixcolorspace\'
    showdebug errormessage $errormessage
}

exitapp()
{
  if [ -n "$fname" ] && [ $showdebug -eq 0 ]; then 
    #cleanup all temp before exiting
    showdebug delete all temp

    output=$(rm "$tmpsfiles"* 2>&1)
    showdebug "$output" 

    output=$(rm -r "${tmpsdir}" 2>&1)
    showdebug "$output" 
  fi    
  
  if [ $deletefile -eq 1 ] && [ $1 -eq 0 ]; then
    #remove original file if conversion success 
    showdebug "delete original file \"${original_file}\""
    output=$(rm -- "$original_file" 2>&1)
    showdebug "$output" 
  fi

  imageinfo

  if [ $1 -eq 0 ]; then
    showdebug "Conversion Success"
  else
    echo "${filepath}/${original_file}:Conversion Fail"
    echo "${targetfile}"
    if [ ! -s "$targetfile" ]; then 
      rm "${targetfile}" 2>/dev/null
    fi  
  fi

  exit $1
}

createuniquename()
{
  local dirpath="$1"
  local filename="${2%.*}"
  local fileext="${2##*.}"

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
  output=$(touch "$targetfile" 2>&1)
  if [ $? -ne 0 ]; then
    showdebug "$output"
    echo "${original_file}: failed to reserve file" >&2
    return 1
  fi

  echo "$targetfile"
  return 0
}

function setimageparam()
{
  local output=''
  if [ -f "$1" ]; then
    showdebug write exif UserComment to "$1"
    output=$(exiftool  -UserComment="$sdprompt" "$1" 2>&1)

    if echo "$output" | grep -q "1 image files updated"; then
        rm "${1}_original" 2>/dev/null  
    else
      showdebug "Fail to write UserComment"
      showdebug $output
    fi
  fi
}

function copyallexif()
{
   if [[ -f "$1" && -f "$2" ]]; then
      output=$(exiftool -tagsfromfile "${1}" -all:all "${2}" 2>&1)
      # Check if the output contains the success message
      if echo "$output" | grep -q "1 image files updated"; then
          rm "${2}_original" 2>/dev/null  
      else
        echo "Fail to copy exif from from ${1}" >&2
        showdebug "Fail to copy exif from from ${1}"
        showdebug $output
      fi
   fi
} 

function converttojxl()
{
  showdebug cjxl $jxlquality $jxleffort "$1" "$2"
  echo $filepath/$original_file ">" $(basename "$2")

  output=$(cjxl $jxlquality $jxleffort -- "$1" "$2" 2>&1)  

  if [ $? -eq 0 ] && [ -s "$2" ]; then
    #copy exif from source
    if [ $sdfiles -eq 1 ]; then
      setimageparam "$2"

    elif [ $copyexif -eq 1 ]; then 
      copyallexif "$original_file" "$2"

    fi
    
    return 0
  else
    showdebug "$output"
    return 1
  fi  
}

_exiftool() {
    output=$(exiftool "$1")

    colortype=$(echo "$output" | grep -m 1 "Color Type" | cut -d: -f2- )
    colormode=$(echo "$output" | grep -m 1 "Color Mode" | cut -d: -f2- )
    colorprofile=$(echo "$output" | grep -m 1 "ICC Profile Name" | cut -d: -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    colorprofiledesc=$(echo "$output" | grep -m 1 "Profile Description" | cut -d: -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    sdparameter=$(echo "$output" | grep  "Parameters" | cut -d: -f2- )
    sdusercomment=$(echo "$output" | grep  "User Comment" | cut -d: -f2- )

    if [[ ! -n "$colorprofile" && -n "$colorprofiledesc" ]]; then
      colorprofile="$colorprofiledesc"
    fi

}

_identify()
{
    # Run the identify command and capture its output
    output=$(identify "$1" 2>&1)
    identify_data=$(echo "$output" | awk -F "identify: " '{print $1}')
    errormessage=$(echo "$output" | awk -F "identify: " '{print $2}'| awk '{print $1}')
    
    # Count the number of images
    number_of_images=$(echo "$identify_data" | wc -l)
    number_of_images=$(echo "$number_of_images" | tr -d '[:space:]')

    # Get the first line and remove file name on the line
    if [[ $number_of_images -gt 1 ]]; then
        first_line=$(echo "$identify_data" | head -n 1 | sed "s/${1}\[0\] //")
    else
        first_line=$(echo "$identify_data" | head -n 1 | sed "s/$1 //")
    fi

    # Extract File Type, Image Size, Image Width, Image Height, and Color Bit
    dataline="$first_line"
    space=($dataline)
    space_length=${#space[@]}

    filetype="${space[0]}"
    image_size="${space[1]}"
    imagewidth=$(echo "$image_size" | cut -dx -f1)
    imageheight=$(echo "$image_size" | cut -dx -f2)
    colorbit="${space[3]}"

    
    for (( i = 0; i < 4; i++ )); do
      element="${space[i]}"
      dataline=$(echo "$dataline" | sed  "s/$element //")
    done
    
    for (( i = 1; i <= 2; i++ )); do
      element="${space[space_length - i]}"
      dataline=$(echo "$dataline" | sed  "s/ $element//")
    done

    element="${space[space_length - 3]}"

    if [[ "$element" == *B ]]; then
        dataline=$(echo "$dataline" | sed  "s/ $element//")
    fi

    colorspace="$dataline"

    filetype=$(echo "$filetype" | tr '[:upper:]' '[:lower:]')
}

parse_arguments "$@"

if [ ! -f "$inputfile" ] ; then 
  echo "file not found:$inputfile" >&2
  exit 1; 
fi;

if [ ! -s "$inputfile" ] ; then 
  echo "Not an image file:$inputfile" >&2
  exit 1; 
fi;

filepath=$(pwd)
original_file="$inputfile"
filename=$(basename -- "$inputfile")
inputdir=$(dirname -- "$inputfile")
fname="${filename%.*}"
fext="${filename##*.}"

if [ -n "$outputfile" ]; then
  outputdir=$(dirname -- "$outputfile")  
  outputfile=$(basename -- "$outputfile")  
else
  outputfile="${fname}.jxl"
  outputdir="$inputdir"
fi

hidden_file='.'
if [ $showdebug -eq 1 ];then 
  hidden_file=""
fi

tmpsfiles="${hidden_file}__tmps__${fname}${fext}__"
tmpsfile="${hidden_file}__tmps__${fname}${fext}__.${extBridge}"
tmpsdir="${hidden_file}__tmps__${fname}${fext}__"

fext=$(echo "$fext" | tr '[:upper:]' '[:lower:]')

# this ext list based on images supported by imagemagick
case $fext in
  3fr|aai|ai|apng|art|arw|ashlar|avif|avs|bayer|bayera|bgr|bgra|bgro|bmp|bmp2|bmp3|brf|cal|cals|cin|cip|clip|cmyk|cmyka|cr2|cr3|crw|cube|cur|cut|data|dcm|dcr|dcraw|dcx|dds|dfont|dng|dot|dpx|dxt1|dxt5|epdf|epi|eps|eps2|eps3|epsf|epsi|ept|ept2|ept3|erf|exr|ff|file|fits|fl32|flv|ftp|fts|ftxt|g3|g4|gif|gif87|gray|graya|group4|gv|hald|hdr|heic|heif|hrz|icb|ico|icon|iiq|ipl|j2c|j2k|jfif|jng|jnx|jp2|jpc|jpe|jpf|jpeg|jpg|jpm|jif|jiff|jps|jpt|jxl|k25|kdc|mac|mask|mat|matte|mef|miff|mng|mono|mpc|mpeg|mpg|mpo|mrw|msl|msvg|mtv|mvg|nef|nrw|null|ora|orf|otb|otf|pal|palm|pam|pbm|pcd|pcds|pcl|pct|pcx|pdb|pdf|pdfa|pef|pes|pfa|pfb|pfm|pgm|pgx|phm|picon|pict|pix|pjpeg|png|png00|png24|png32|png48|png64|png8|pnm|ppm|ps|ps2|ps3|psb|psd|ptif|pwp|qoi|raf|ras|raw|rgb|rgb565|rgba|rgbo|rgf|rla|rle|rmf|rw2|scr|sct|sfw|sgi|six|sixel|sr2|srf|sun|svg|svgz|tga|tif|tiff|tiff64|tile|tim|tm2|ttc|ttf|ubrl|ubrl6|uil|uyvy|vda|vicar|vid|viff|vips|vst|wbmp|webp|wpg|x3f|xbm|xc|xcf|xpm|xps|xv|yaml|yuv )
    supportedfile=1
  ;;

  *)
    echo "${original_file}: unsupported file" >&2
    exit 1;
  ;;
esac

# This is necessary because we need to assess what needs to be done before converting the image to JXL. 
# This includes checking for attributes such as color space (RGB, CMYK, Grey), broken color profiles (which can cause unusual colors during conversion), 
# and the possibility that some files may not be valid image files.
_identify "$inputfile"
_exiftool "$inputfile"

if  [[ $sdfiles -eq 1 ]] && [[ "$filetype" == "jpg" || "$filetype" == "jpeg" || "$filetype" == "png" ]]; then
  showdebug sdparameter \'$sdparameter\'
  showdebug sdusercomment \'$sdusercomment\'

  # check on which parameter prompt exist
  if [[ -n "$sdusercomment" ]]; then
    sdprompt="$sdusercomment"
  elif [[ -n "$sdparameter" ]]; then
    sdprompt="$sdparameter"
    if [[ ! -n "$sdusercomment" ]]; then
      # Attempt to write EXIF data to the source file. 
      # If the source file doesn't have the 'UserComment' tag in its EXIF data, the write operation will fail for the target file.
      setimageparam "$inputfile"
    fi
  else
    sdprompt=""
  fi

  if [[ ! -n "$sdprompt" ]]; then
    sdfiles=0
  fi
else
  # treat as a regular file for other file type
  sdfiles=0
fi

if [ -z "$filetype" ] || [ $imagewidth -le 1 ];then 
  # When it's not an image file, ImageMagick returns a width of 1 for a recognized file that is not actually an image file.
  echo "${original_file}:file unrecognized or not an image file" >&2
  exitapp 1;
fi 

# Just in case there's a video disguised as an image, although there are more format, this is a common one.
case $filetype in
  "mp4" | "mkv" | "mov" | "mpg" | "hevc" | "mpeg")
    echo "${original_file}: unsupported file" >&2
    exitapp 1;
    ;;
esac

fixcolorspace=0
converttoColorRGB=0
extconvert=0


if [[ "$filetype" == "gif" && $number_of_images -gt 1 ]]; then
    # I need to conduct more tests for converting GIF animations to JXL animations.
    # On my computer, JXL animations are still not playable.
    # Converting them to HEVC video remains a better option.
    echo "${original_file}: unsupported file" >&2
    exitapp 1;
fi

if [[ "$errormessage" == "CorruptImageProfile" 
  || "$colorprofile" == "e-sRGB" 
  || "$colorspace" == "CMYK" ]] ; then
  fixcolorspace=1

elif [ -n "$jxlquality" ]; then
  if [[ "$colorprofile" == "AdobeRGB" 
    || "$colorprofile" == "Adobe RGB (1998)" 
    || "$colorprofile" == "Apple RGB" 
    || "$colorprofile" == "Display P3" 
    || "$colorprofile" == "ProPhoto RGB" 
    || "$colorprofile" == "Generic RGB Profile" 
    || "$colorprofile" == "Wide Gamut RGB" ]]; then
    fixcolorspace=1
  elif [[ "$colorspace" == "Gray" && "$colorprofile" == sRGB* ]] || 
       [[ "$colorspace" == "sRGB" && "$colorprofile" == Dot\ Gain* ]] ||
       [[ "$colorspace" == "sRGB" && "$colorprofile" == Generic\ Gray* ]]; then
    fixcolorspace=1
  fi
fi

if [ $fixcolorspace -eq 0 ];then
  if [[ "$colorprofile" == sRGB* 
    || "$colorspace" == sRGB* 
    || "$colorspace" == Grayscale* 
    || "$colorprofile" == "uRGB" 
    || "$colorspace" == "uRGB" 
    || "$colorspace" == "Gray" 
    || "$colorspace" == "CIELab" ]]; then
      fixcolorspace=0
  else
    # need more tests for the rest of the image type
    exitapp 1
  fi  
fi

case "$filetype" in
  # This list of file extensions is based on the image formats supported by cjxl
  png|apng|gif|jpe|jpeg|jpg|exr|ppm|pfm|pgx)
    extconvert=0
  ;;

  # This list of file extensions is based on the image formats supported by Darktable. 
  # Before converting any raw files to JXL, first convert them to a bridge file. 
  # Currently, cjxl does not support raw files.
  3fr|ari|arw|bay|bmq|cap|cine|cr2|cr3|crw|cs1|dc2|dcr|dng|gpr|erf|fff|exr|ia|iiq|k25|kc2|kdc|mdc|mef|mos|mrw|nef|nrw|orf|pef|pfm|pxn|qtk|raf|raw|rdc|rw1|rw2|sr2|srf|srw|sti|x3f)

    # Some raw files have a preview image, so extract that first to save time and avoid the need to convert using Darktable.
    showdebug exiftool -b -JpgFromRaw "$inputfile"
    exiftool -b -JpgFromRaw "$inputfile" > "$tmpsfile" 2>/dev/null

    # check the preview file size, if it's zero, run darktable to convert from RAW
    if [ ! -s "$tmpsfile" ]; then 
       rm "$tmpsfile" 2>/dev/null
    else
       # Check the dimensions of the preview image. Some raw files store the image slightly smaller, 
       # while others store only a thumbnail preview. 
       # Prior to conversion, verify this: if the preview is only slightly smaller, with a difference of less than 32 pixels, then use it. 
       # Otherwise, proceed to convert the raw file using Darktable."
       ori_width=$((imagewidth - 32))
       preview_width=$(identify -format "%w" "$tmpsfile")
       
       if [ $ori_width -gt $preview_width  ]; then
         rm "$tmpsfile"
       fi
    fi

    if [ -f "$tmpsfile" ]; then
      # Since most previews do not include EXIF data, copy the EXIF data from the raw file.
      copyallexif "$inputfile" "$tmpsfile"
    else 
      # If the preview is not available or too small, convert it to a bridge file using Darktable. 
      # Use the SRGB color profile so that cjxl can successfully convert the file.
      showdebug $darktable "$inputfile" "$tmpsfile" --icc-type SRGB
      output=$($darktable "$inputfile" "$tmpsfile" --icc-type SRGB 2>&1)
      
      # if conversion fails remove bridge file and exit
      if [ $? -ne 0 ]; then 
        showdebug "$output"
        echo "${original_file}: raw conversion fail or file not supported" >&2
        exitapp 1;
      fi
    fi

    if [ -f "$tmpsfile" ]; then
      # Conversion success set converted file to input file
      inputfile="$tmpsfile"
    fi

    # Because it has already been converted, there's no need to convert it again.
    fixcolorspace=0
    extconvert=0
  ;;

  # Convert all other files that cjxl can't handle using ImageMagick.
  *)
    extconvert=1
  ;;
esac

# Convert the file if it is necessary.
if [ $fixcolorspace -eq 1 ] || [ $extconvert -eq 1 ]; then 
  mkdir "${tmpsdir}" 2>/dev/null
  cp "$inputfile" "${tmpsdir}"
  cd "${tmpsdir}"

  # Convert all images that cjxl can't handle to bridge files.
  # Fix broken or corrupt images with color spaces or color profiles other than RGB.
  common_args="-quality 100"

  if [ $fixcolorspace -eq 1 ] ; then 
    if [ "$colorspace" == "CMYK" ]; then
      if [[ "$colorprofile" ==  "" || "$colorprofile" ==  sRGB* ]]; then
        specific_args="-colorspace sRGB -type truecolor"
      else
        specific_args="+profile \* -profile $iccpath"
      fi
    elif [[ "$colorspace" == "Gray" && "$colorprofile" == sRGB* ]]; then
      specific_args="-colorspace sRGB -type truecolor"
    elif [[ "$colorspace" == "sRGB" && "$colorprofile" == Dot\ Gain* ]] ||
         [[ "$colorspace" == "sRGB" && "$colorprofile" == Generic\ Gray* ]]; then
      specific_args="-colorspace Gray -type Grayscale"
    else
      specific_args="-colorspace sRGB -type truecolor  +profile \* -profile $iccpath"
    fi
  else
    specific_args="" 
  fi

  showdebug convert "$inputfile" $common_args $specific_args "$tmpsfile"
  output=$(convert "$inputfile" $common_args $specific_args "../${tmpsfile}" 2>&1)

  if [ $? -ne 0 ] ; then 
    showdebug "$output"
    echo conversion fail skip the job >&2
    exitapp 1
  fi

  cd ..
  extconvert=1
fi

# In the case of multi-image files, it will be converted into individual files by ImageMagick.
if [[ $extconvert -eq 1 && $number_of_images -gt 1 ]] ; then
  baseoutputname="$outputfile"
  if [ $rewritefile -eq 0 ]; then
    baseoutputname=$(createuniquename "$outputdir" "$baseoutputname")
    if [ $? -ne 0 ];then
      echo fail to reserve file >&2
      exitapp 1
    fi
    baseoutputname=$(basename "$baseoutputname")
  fi

  maxconvert=$number_of_images

  if [[ $singlefile -eq 1 ]]; then
    maxconvert=1
  fi

  errorexist=0

  for (( i = 0; i < $maxconvert; i++ )); do
    inputfile="${tmpsfiles}-${i}.${extBridge}"

    if [[ -f "$inputfile" ]]; then
      if [[ $i -eq 0 ]]; then
        targetfile="${outputdir}/$baseoutputname"
      else
        fnameout="${baseoutputname%.*}"
        fextout="${baseoutputname##*.}"
        outputname="${fnameout}-${i}.${fextout}"
        targetfile="${outputdir}/${outputname}"
        if [ $rewritefile -eq 0 ]; then
          targetfile=$(createuniquename "$outputdir" "$outputname")
          if [ $? -ne 0 ];then
            echo fail to reserve file >&2
            exitapp 1
          fi
        fi
      fi

      converttojxl "$inputfile" "$targetfile"
      if [[ $? -ne 0 ]]; then
        errorexist=1
      fi
    fi
  done
  if [[ $errorexist -eq 1 ]]; then
    echo "some image might be not converted" >&2
  fi
  exitapp $errorexist

else 
  # If the conversion is successful and the result exists, change the source to the converted file; 
  # otherwise, try to convert the original file.
  if  [[ $extconvert -eq 1 && -f "$tmpsfile" ]] ; then
    inputfile="$tmpsfile"
  fi

  targetfile="${outputdir}/${outputfile}"
  if [ $rewritefile -eq 0 ]; then
    targetfile=$(createuniquename "$outputdir" "$outputfile")
      if [ $? -ne 0 ];then
        echo fail to reserve file >&2
        exitapp 1
      fi
  fi

  converttojxl "$inputfile" "${targetfile}"
  exitapp $?
fi