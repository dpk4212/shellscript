# jxl migrate

just a simple shell app to convert all applicable image files in to JPEG XL.
cjxl.sh to convert individual image
bjxl.sh to convert all images on the working folder to jxl


## Features
* Convert all image files including raw into *JXL*

## Requirements
All binaries should be added to the system's `PATH` environment variable to ensure that this script can access them.
* cjxl
* exiftool
* imagemagick
* darktable
* heif-convert

## Usage

### individual image

```sh
sh cjxl.sh inputimage [-q 1-100] [-e 1-9] [-del] [-y] [-raw] [-exif] [-single] [-d path] [outputimage] 
```
* inputimage: path to your input image
* -q : 100 for lossless transcode, 1-99 lossy transcode, default 100
* -e : effort encoding effort 1-9, smaller is faster, default 7
* -del : By default, the original file is not deleted when the conversion is successful. However, you can choose to delete it if needed.
* -y : By default, the destination file is not overwritten if it already exists. However, you can choose to overwrite it if needed.
* -raw : By default, when hadling raw file will use embedded preview if available rather than thew raw file it self, use this option to force conversion from raw file 
* -exif : By default, exif will be handling by cjxl, but it seems  exiftool and other apps base on it can't read it but Lightroom can, use this option to force copy exif to jxl file so exiftool can read it
* -single : By default, all images in a multi-image file, such as a PDF file, are converted to individual files. However, you can choose to convert only the first image if needed.
* -d : Set output directory if output image doest not contain path this input will be used as output directory
* outputimage , by default the same name as the original file

### folder
```sh
sh bjxl.sh [-r] [-q 1-100] [-e 1-9] [-del] [-y] [-raw] [-exif] [-single] [-thread x] [-d path] [ext] [ext]
```
* -r : recursive, include all sub directories
* -q : 100 for lossless transcode, 1-99 lossy transcode, default 100
* -e : effort encoding effort 1-9, smaller is faster, default 7
* -del : By default, the original file is not deleted when the conversion is successful. However, you can choose to delete it if needed.
* -y : By default, the destination file is not overwritten if it already exists. However, you can choose to overwrite it if needed.
* -raw : By default, when hadling raw file will use embedded preview if available rather than thew raw file it self, use this option to force conversion from raw file 
* -exif : By default, exif will be handling by cjxl, but it seems  exiftool and other apps base on it can't read it but Lightroom can, use this option to force copy exif to jxl file so exiftool can read it
* -single : By default, all images in a multi-image file, such as a PDF file, are converted to individual files. However, you can choose to convert only the first image if needed.
* -thread : The default is set to 1 for the maximum number of parallel conversions. You can adjust this number as needed.
* -d : Set output directory
* ext : only convert specific extension 

## Disclaimer

I used this script to migrate my entire image folder and noticed some issues. Not all images are created equal; some have different color profiles and color spaces. However, most of them convert without any problems when I use the script. I've done my best to ensure smooth conversion, but I can't guarantee flawless error handling. If files are lost, damaged, or converted incorrectly, I cannot take responsibility for it. I've taken precautions since I plan to use this script myself, but there's always an element of uncertainty.

I've made every effort to handle only image files and exclude impostors so that the script doesn't get confused and attempt to convert non-image files.

Please note that the script assumes you have all the necessary requirements in place and doesn't check for missing requirements.
