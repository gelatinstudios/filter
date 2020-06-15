@echo off
dmd -m64 -inline -i -O -release -g filter.d stb_image.obj stb_image_write.obj
IF %ERRORLEVEL% == 0 (
	del filter.obj
	filter.exe crying_sad.png crying_sad_filtered.png
)
