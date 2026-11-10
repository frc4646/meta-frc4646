# ffmpeg only lets the x264 command line tool read other formats.  x264enc
# just uses the library, so leave ffmpeg out of the image.
PACKAGECONFIG:remove = "ffmpeg"
