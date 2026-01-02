@echo off
setlocal EnableDelayedExpansion

set MATLAB="C:\Program Files\MATLAB\R2025a\bin\matlab.exe"

set BASE_TRIALS=3
set BASE_FOLDERS=9
set BASE_FILES=5

cd /d %~dp0

echo === Karuta Batch START ===

for /L %%t in (1,1,%BASE_TRIALS%) do (
  for /L %%f in (1,1,%BASE_FOLDERS%) do (
    for /L %%d in (1,1,%BASE_FILES%) do (

      set TRIAL_ID=%%t
      set FOLDER_ID=%%f
      set FILE_ID=%%d

      echo === Trial !TRIAL_ID! ^| Folder !FOLDER_ID! ^| Data !FILE_ID! ===


      %MATLAB% -batch "batch_single_run"

    )
  )
)

echo === ALL TESTS FINISHED ===
pause
