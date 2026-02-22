@echo off
pushd %~dp0
set PATH=%PATH%;%~dp0
echo Running Flutter App...
flutter run -d windows
pause
popd
