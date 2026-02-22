@echo off
pushd %~dp0
set PATH=%PATH%;%~dp0
echo ==================================================
echo STEP 1: Checking Flutter Installation...
echo ==================================================
call flutter doctor

echo.
echo ==================================================
echo STEP 2: Running App (Verbose Mode)
echo This may take 5-10 minutes for the first build.
echo Please wait and watch the logs below.
echo ==================================================
call flutter run -d windows -v

echo.
echo ==================================================
echo App execution finished.
echo ==================================================
pause
popd
