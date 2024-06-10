# Flame After Session Archiver

A simple utility intended to give you one less reason not to archive daily.  It was
designed to help with archiving projects on Autodesk Flame. It can be setup to 
automatically archive projects after closing Flame or manually archive them based on user
input. The script provides options for different types of archiving: Normal, Compact,
or Omitted.

**Note:** To disable the script, set 'turn_off=true' to stop script and exit without
archiving.


## Disclaimer

This is not an official Autodesk certified script. Neither the author nor Autodesk are
responsible for any use, misuse, unintended results, or data loss that may occur from using
this script. This script has not been thoroughly tested and is a work in progress. It was
created on personal time to address a specific customer request and may not be applicable
to your workflow.

**Use at your own risk.**
This script is intended for providing guidance only. There is no support provided. Caution
is strongly advised as this has not been thoroughly tested.


## Test Environment

- Operating System: macOS 13.6.7
- Flame Family: 2025


## Installation:
- The script itself should be placed in /opt/Autodesk/archive if intending to run when
Flame exits.  Be sure to make the script executable.  See *Usage* section to automatically
launch after Flame exits.


## Setup
The script has several customizable variables:

**REQUIRED**: Edit the value for 'archive_storage_path' to the prefered backup location for Flame
archives.
- **archive_storage_path**: This is the location where the archives will be stored. By
default, it is set to "/var/tmp/TEST ARC FOLDER". Define the archive storage location to local,
external, SAN/NAS, etc according to your needs.

**OPTIONAL**: These are optional, but may improve the functionality.
- **archive_type**: This variable determines the type of archive to be created. It can
be set to "N" for Normal, "C" for Compact, and "O" for Omitted. If left blank, the script
will prompt you to choose the archive type every time.

- **auto_archive**: This variable determines whether the script should automatically
archive projects when Flame exits. Set it to "true" to enable automatic archiving. By
default, it is left blank which means automatic archiving is disabled.

- **turn_off**: Stop the script and exit without archivin.  Append "true" to turn off script.
Default value is "false" and will allow script to continue.


## Usage

The script can be setup to either run without user intervention or to seek user input.  To run
after Flame closes, add the following snippet at the end of the 'runApplication' function,
immediately above 'return exitStatus' in the startApplication launcher.  An example
startApplication is provided for 2025.0.1.

```
    flame_after_session_archiver = "/opt/Autodesk/archive/flame_after_session_archiver.sh"
    print("\n" * 5)
    if os.path.isfile(flame_after_session_archiver):
    # Use subprocess.call to run the bash script and wait for it to finish
    	result = subprocess.call(['bash', flame_after_session_archiver])
    else:
    	print("Archival script not found at $flame_after_session_archiver.")
```

The script can also be ran directly or added to a crontab from the command line. The
script does not require any arguments and can be executed as follows: 
```
./flame_after_session_archiver.sh
```

## Requirements

- Run as the normal flame user.
- Flame Family application
- flame_archive installed

## Helpful Links

- [Flame User Guide > Archiving a Project to a File-based Archive](https://help.autodesk.com/view/FLAME/2024/ENU/?guid=GUID-CD731E5D-6702-4B65-A2FD-FB1B5E52C733)
- [Archiving from the Command Line in Flame](https://help.autodesk.com/view/FLAME/2023/ENU/?guid=GUID-DA2C15AD-CAF8-41E8-BDB4-711DE6B7DECB)

## Always Current Version

- [FlameScripts on GitHub](https://github.com/flamescripts)
