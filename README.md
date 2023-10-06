# jxl migrate

just a simple app to convert all applicable image files recursively in  JPEG XL.
cjxl.sh convert individual image
bjxl.sh convert all images on the working folder to jxl


## Features
* Convert all image files including raw into *JXL*

## Requirements
All binaries should be added to the system's `PATH` environment variable so this script can access them. 
* cjxl
* exiftool
* imagemagick
* darktable

## Usage

### individual image

```sh
sh cjxl.sh inputimage [-q=1-100] [-e=1-9] [-del] [-y] [-single] [outputimage] 
```
* inputimage: path to your input image
* -q : 100 for lossless transcode, 1-99 lossy transcode, default 100
* -e : effort encoding effort 1-9, smaller is faster, default 7
* -del : delete original file when successful, default not deleted
* -y : overwrite destination file if exists, default no overwrite
* -single : only convert first image on a multi-image file such as a pdf file, default convert all images to an individual file
* outputimage , by default the same name as the original file

### folder
```sh
sh bjxl.sh [-r] [-q=1-100] [-e=1-9] [-del] [-y] [-single] [-thread=x] [ext] [ext]
```
* -r : recursive, include all sub directories
* -q : 100 for lossless transcode, 1-99 lossy transcode, default 100
* -e : effort encoding effort 1-9, smaller is faster, default 7
* -del : delete original file when successful, default not deleted
* -y : overwrite destination file if exists, default no overwrite
* -single : only convert the first image on a multi-image file such as a pdf file, default convert all images to an individual file
* -thread : max parallel convert, default 1
* ext : only convert specific extension 

## Disclaimer

I used this script to migrate my entire image folder and did notice some issues, not all images are built the same, some of those images have different color profiles and color space, but most of them have no issues when I convert them, and try to convert all of the perfectly 
But I still cannot guarantee that the error handling in this script is perfect and I can't help it if files get lost or damaged or converted incorrectly. 
I cannot take responsibility for that. I did my best to avoid that since I actually intend to use this script myself, but you never know.

I tried the best way to only handle image files, and ditch all impostors so this script will not confused and try to convert not an image file

The script runs assuming you have all requirements satisfied and does not check if there are missing requirements.
