@echo Executing build with default.ps1 configuration
@echo off

powershell.exe -NoProfile -ExecutionPolicy bypass -Command "& {.\configure-build.ps1; invoke-psake .\default.ps1 %1 }"

EXIT /B %ERRORLEVEL%

