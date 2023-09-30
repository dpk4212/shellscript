#!/bin/bash


# Function to parse command line arguments and extract attributes and their values
quality=0
deletefile=0
reqursive=0
jxlquality=''

parse_arguments() {
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

get_icc_profile_name() {
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
  if [ -f "${i}" ] && [ "${i:0:7}" != "#_tmps_" ]; then
    #echo "Convert $i $icc"
    fname="${i%.*}"
    fext="${i##*.}"

    icc=$(get_icc_profile_name "$i")

    case "$icc" in
      "sRGB IEC61966-2.1"|"R98 - DCF basic file (sRGB)")
        icc_convert=0
      ;;
      *)
        icc_convert=1
      ;;
    esac

    case "$fext" in
      PNG|APNG|GIF|JPEG|JPG|EXR|PPM|PFM|PGX|png|apng|gif|jpeg|jpg|exr|ppm|pfm|pgx)
        extconvert=0
        ;;
        JXL|jxl)
          continue
        ;;
        *)
        extconvert=1  
        ;;
    esac

    if [ $extconvert -eq 1 ] || [ $icc_convert -eq 1 ]; then

      

      if [ -n "$jxlquality" ] && [ $icc_convert -eq 1 ]; then
        mkdir __tmps__
        cp "$i" __tmps__
        cd __tmps__

        #echo convert -quality 100 "$i"  +profile \* -profile ~/sRGB2014.icc  "#_tmps_${fname}.jpg"
        convert -quality 100 "$i"  +profile * -profile ~/sRGB2014.icc  "../#_tmps_${fname}.jpg" 2>/dev/null 

        cd ..
        rm -r __tmps__

      else 
        echo convert -quality 100 "$i" "#_tmps_${fname}.jpg"
        convert -quality 100 "$i"  "#_tmps_${fname}.jpg" 2>/dev/null 
      fi

      if [ $? -eq 0 ] ; then
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
          continue
        fi

      else 
        #conversion fail skip the job
        continue 
      fi
    fi


    echo cjxl $jxlquality  "$i" "${fname}.jxl"
    cjxl $jxlquality  "$i" "${fname}.jxl" 2>/dev/null

    if [ $? -eq 0 ] && [ -f "${fname}.jxl" ] && [ $deletefile -eq 1 ]; then
      rm "$i"
    fi
    rm \#_tmps_*.jpg 2>/dev/null
  fi
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
        fileConvert "${i}"
      fi
    done


    if [ "$1" != '.' ]; then 
      cd ..
    fi

}

parse_arguments "$@"

dirConvert .
