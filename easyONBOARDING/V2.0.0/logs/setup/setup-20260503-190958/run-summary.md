# Setup Run Summary

- RunId: `setup-20260503-190958`
- FinalStatus: `failed`
- LastPhase: `install-external-prerequisites`
- PendingReboot: `False`
- ResumeTaskRegistered: `True`
- InstallerManifestPath: `Z:\00-GitWork\PhinIT-Active-Directory-File-Tools\easyONBOARDING\V2.0.0\setup-cache\installer-manifest.json`

## Message

The property 'PythonRuntime' cannot be found on this object. Verify that the property exists.

## Completed Actions

- installer:python-runtime
- scheduled-task:registered
- installer:iis-arr

## Notes

- Auto-Resume Scheduled Task registriert: easyONBOARDING-V2-Setup-Resume
- Optionale Komponenten fuer diesen Lauf aktiviert: IIS Application Request Routing (ARR)
- Fehler: Es konnte kein Python-Interpreter gefunden werden. Bitte Python 3.13.x installieren.
- Fehler: The property 'PythonRuntime' cannot be found on this object. Verify that the property exists.

## Component Logs

- Setup Auto Resume / register-scheduled-task: error (ExitCode: 1)
- Python 3.13.x / install-exe: success (ExitCode: 0)
- Setup Auto Resume / register-scheduled-task: success (ExitCode: 0)
- Python 3.13.x / install-exe: success (ExitCode: 0)
- Python 3.13.x / install-exe: success (ExitCode: 0)
- IIS Application Request Routing (ARR) / resolve-installer: success (ExitCode: 0)
- IIS Application Request Routing (ARR) / install-msi: success (ExitCode: 0)
