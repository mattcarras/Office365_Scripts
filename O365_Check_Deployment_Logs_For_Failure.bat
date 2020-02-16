@echo off
REM Check Office Deployment Tool logs in current directory for possible failure
REM Last updated 9-11-19 MJC
SETLOCAL EnableDelayedExpansion
FOR %%G IN ("%~dp0\*.log") DO (
	find /C /I "Failure has occured" "%%~fG" >Nul && (
		SET _MATCH=0
		find /C /I "UserCancel" "%%~fG" >Nul && SET _MATCH=1
		IF "!_MATCH!"=="1" (
			echo [%%~nxG] Deployment failure detected due to blocking processes that could not be killed without user interaction.
		) ELSE (
			find /C /I "InvalidProductInConfigXml" "%%~fG" >Nul && SET _MATCH=1
			IF "!_MATCH!"=="1" (
				echo [%%~nxG] Deployment failure detected with error [InvalidProductInConfigXml].
			) ELSE (
				echo [%%~nxG] Deployment failure detected.
			)
		)
	)
)
pause

