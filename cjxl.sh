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
inputfile=""
outputfile=""
batchconvert=0

# If the 'darktable' path is empty, we will use ImageMagick for the raw image conversion.
darktable=/Applications/darktable.app/Contents/MacOS/darktable-cli
rawfile=0

iccpath=~/sRGB2014.icc

 
# An intermediate format for conversions between the source and target if necessary. 
# Any format will suffice as long as it's supported by cjxl, 
# such as png, apng, gif, jpe, jpeg, jpg, exr, ppm, pfm, or pgx. 
# PNG is recommended for its quality, 
# JPG may be chosen for faster conversion speeds.
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

      -raw)
        # by default when handling raw file we use the preview rather than convert it 
        # set value to 1 to always convert raw file
        rawfile=1
        shift
        ;;

      -b)
        # display output progress on batch convert 
        batchconvert=1
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
  if [[ "$tmpsfiles" == .__tmps__* &&  "$tmpsdir" == .__tmps__*  ]]; then 
    output=$(rm "$tmpsfiles"* 2>&1)
    output=$(rm -r "${tmpsdir}" 2>&1)
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

  if [[ $batchconvert -eq 1 ]]; then
    echo $filepath/$original_file ">" $(basename "$2")
  fi

  output=$(cjxl $jxlquality $jxleffort -- "$1" "$2" 2>&1)  

  if [ $? -eq 0 ] && [ -s "$2" ]; then
    #copy exif from source
    if [ -n "$sdprompt" ]; then
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

_exiftool() 
{
    output=$(exiftool "$1")

    filetype=$(echo "$output" | grep -m 1 "File Type" | cut -d: -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    colortype=$(echo "$output" | grep -m 1 "Color Type" | cut -d: -f2- )
    mimetype=$(echo "$output" | grep -m 1 "MIME Type" | cut -d: -f2- )
    fileformat=$(echo "$mimetype" | cut -d/ -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    mimetype=$(echo "$mimetype" | cut -d/ -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    colormode=$(echo "$output" | grep -m 1 "Color Mode" | cut -d: -f2- )
    colorprofile=$(echo "$output" | grep -m 1 "ICC Profile Name" | cut -d: -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    colorprofiledesc=$(echo "$output" | grep -m 1 "Profile Description" | cut -d: -f2- | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    imagewidth=$(echo "$output" | grep -E "Image Width" | awk '{print $NF}' | tail -n 1)
    imageheight=$(echo "$output" | grep -E "Image Height" | awk '{print $NF}' | tail -n 1)
    sdparameter=$(echo "$output" | grep  "Parameters" | cut -d: -f2- )
    sdusercomment=$(echo "$output" | grep  "User Comment" | cut -d: -f2- )

    if [[ ! -n "$colorprofile" && -n "$colorprofiledesc" ]]; then
      colorprofile="$colorprofiledesc"
    fi

    if [[ "$fileformat" == "application" ]]; then
      fileformat="$mimetype" 
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

if [[ "$filename" == *.* ]]; then
  fext="${filename##*.}"
else
  fext=""
fi



if [ -n "$outputfile" ]; then
  outputdir=$(dirname -- "$outputfile")  
  outputfile=$(basename -- "$outputfile")  
  outputfilelow=$(echo "$outputfile" | tr '[:upper:]' '[:lower:]')

  if [[ "$outputfilelow" != *.jxl ]]; then
    echo "Target file extension not an JXL file" >&2
    exit 1
  fi
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

fext=$(echo "$fext" | tr '[:lower:]' '[:upper:]')

# this ext list based on images supported by imagemagick
case $fext in
  3FR|AAI|AI|APNG|ART|ARW|ASHLAR|AVIF|AVS|BAYER|BAYERA|BGR|BGRA|BGRO|BMP|BMP2|BMP3|BRF|CAL|CALS|CIN|CIP|CLIP|CMYK|CMYKA|CR2|CR3|CRW|CUBE|CUR|CUT|DATA|DCM|DCR|DCRAW|DCX|DDS|DFONT|DNG|DOT|DPX|DXT1|DXT5|EPDF|EPI|EPS|EPS2|EPS3|EPSF|EPSI|EPT|EPT2|EPT3|ERF|EXR|FF|FILE|FITS|FL32|FLV|FTP|FTS|FTXT|G3|G4|GIF|GIF87|GRAY|GRAYA|GROUP4|GV|HALD|HDR|HEIC|HEIF|HRZ|ICB|ICO|ICON|IIQ|IPL|J2C|J2K|JFIF|JNG|JNX|JP2|JPC|JPE|JPF|JPEG|JPG|JPM|JIF|JIFF|JPS|JPT|JXL|K25|KDC|MAC|MASK|MAT|MATTE|MEF|MIFF|MNG|MONO|MPC|MPEG|MPG|MPO|MRW|MSL|MSVG|MTV|MVG|NEF|NRW|NULL|ORA|ORF|OTB|OTF|PAL|PALM|PAM|PBM|PCD|PCDS|PCL|PCT|PCX|PDB|PDF|PDFA|PEF|PES|PFA|PFB|PFM|PGM|PGX|PHM|PICON|PICT|PIX|PJPEG|PNG|PNG00|PNG24|PNG32|PNG48|PNG64|PNG8|PNM|PPM|PS|PS2|PS3|PSB|PSD|PTIF|PWP|QOI|RAF|RAS|RAW|RGB|RGB565|RGBA|RGBO|RGF|RLA|RLE|RMF|RW2|SCR|SCT|SFW|SGI|SIX|SIXEL|SR2|SRF|SUN|SVG|SVGZ|TGA|TIF|TIFF|TIFF64|TILE|TIM|TM2|TTC|TTF|UBRL|UBRL6|UIL|UYVY|VDA|VICAR|VID|VIFF|VIPS|VST|WBMP|WEBP|WPG|X3F|XBM|XC|XCF|XPM|XPS|XV|YAML|YUV )
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
_exiftool "$inputfile"

case $fileformat in
  "image" | "vnd.adobe.photoshop" | "postscript" | "pdf")
    supportedfile=1
    ;;
    *)
    echo "${original_file}: unsupported file : $mimetype " >&2
    exit 1;
  ;;
esac

# A PNG image from the stable diffusion store contains generation data in its image properties. 
# Usually, this information is lost during conversion. 
# However,  this process will preserve that information by storing it in the EXIF user comment.
sdprompt=""
if [[ "$filetype" == "PNG" ]]; then
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
  fi
elif [[ "$filetype" == "JPEG" ]]; then
  if [[ -n "$sdusercomment" ]]; then
    sdprompt="$sdusercomment"
  fi
fi

if [[ "$filetype" == "gif" && $number_of_images -gt 1 ]]; then
    # I need to conduct more tests for converting GIF animations to JXL animations.
    # On my computer, JXL animations are still not playable.
    # Converting them to HEVC video remains a better option.
    echo "${original_file}: unsupported file" >&2
    exitapp 1;
fi

showdebug filetype \'$filetype\'

# check file base on file type 
case "$filetype" in
  # This list of file extensions is based on the image formats supported by cjxl
  PNG|APNG|GIF|JPE|JPEG|JPG|EXR|PPM|PFM|PGX)
    extconvert=0
  ;;

  # This list of file extensions is based on the image formats supported by Darktable. 
  # Before converting any raw files to JXL, first convert them to a bridge file. 
  # Currently, cjxl does not support raw files.
  3FR|ARI|ARW|BAY|BMQ|CAP|CINE|CR2|CR3|CRW|CS1|DC2|DCR|DNG|GPR|ERF|FFF|EXR|IA|IIQ|K25|KC2|KDC|MDC|MEF|MOS|MRW|NEF|NRW|ORF|PEF|PFM|PXN|QTK|RAF|RAW|RDC|RW1|RW2|SR2|SRF|SRW|STI|X3F )

    if [[ $rawfile -eq 0 ]]; then
      # Some raw files have a preview image, so extract that first to save time and avoid the need to convert using Darktable.
      showdebug exiftool -b -JpgFromRaw "$inputfile"
      exiftool -b -JpgFromRaw "$inputfile" > "$tmpsfile" 2>/dev/null

      # check the preview file size, if it's zero, run darktable to convert from RAW
      if [ -s "$tmpsfile" ]; then 
         # Check the dimensions of the preview image. Some raw files store the image slightly smaller, 
         # while others store only a thumbnail preview. 
         # Prior to conversion, verify this: if the preview is only slightly smaller, with a difference of less than 32 pixels, then use it. 
         # Otherwise, proceed to convert the raw file using Darktable."
         ori_width=$((imagewidth - 32))
         preview_width=$(identify -format "%w" "$tmpsfile")
         
         if [ $ori_width -gt $preview_width  ]; then
           rm "$tmpsfile"
         fi
      else
         rm "$tmpsfile" 2>/dev/null
      fi

      if [[ -f "$tmpsfile" ]]; then
        # Since most previews do not include EXIF data, copy the EXIF data from the raw file.
        copyallexif "$inputfile" "$tmpsfile"
        inputfile="$tmpsfile"
        extconvert=0
      else
        # Since the preview is not available or too small, convert it to a bridge file using Darktable or ImageMagick. 
        rawfile=1
      fi
    fi

    if [ $rawfile -eq 1 ]; then
      if [[ -n "$darktable" ]]; then
        # Use the SRGB color profile so that cjxl can successfully convert the file.
        showdebug $darktable "$inputfile" "$tmpsfile" --icc-file $iccpath
        output=$($darktable "$inputfile" "$tmpsfile" --icc-file $iccpath 2>&1)
        
        if [ $? -eq 0 ]; then 
          extconvert=0
          colorspace="sRGB"
          colorprofile="sRGB"
          errormessage="" 
          inputfile="$tmpsfile"
        else
          rm "$tmpsfile" 2>/dev/null
          showdebug "conversion using Darktable fails, attempt to use ImageMagick for the conversion."
          extconvert=1
        fi
      else
        extconvert=1
      fi
    fi      
  ;;

  # Convert all other files that cjxl can't handle using ImageMagick.
  *)
    extconvert=1
  ;;
esac

_identify "$inputfile"

fixcolorspace=0
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

# While converting to JXL with lossy compression, I noticed some color variation for a few color profiles or color spaces. 
# I need to conduct more tests with other color profiles not on this list because this list is based on the images I have. 
# For lossless compression, there's no need to convert it, as I've observed that JXL handles it quite well.
if [[ -n "$jxlquality" ]]; then
  if [[ $fixcolorspace -eq 0 ]];then
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
      echo "${original_file}: unsupported color space or color profile : ${colorspace} ${colorprofile} " >&2
      exitapp 1
    fi  
  fi
fi


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

  inputfile="$tmpsfile"
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