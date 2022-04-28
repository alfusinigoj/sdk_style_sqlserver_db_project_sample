#!/bin/bash

set -e

echo Executing build with default.ps1 configuration

pwsh -NoProfile -ExecutionPolicy bypass -Command "& { .\configure-build.ps1 ; Invoke-psake .\default.ps1 $1; exit !((GET-Variable psake -valueOnly).build_success) }"

exit $?