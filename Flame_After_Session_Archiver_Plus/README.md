# Flame After Session Archiver

Scripts for making frequent Flame project archives after a Flame session exits.

The current Flame project is explicitly selected from inside Flame. A Python hook records the project name in a small JSON state file, and the archive process runs only after Flame exits.

## IMPORTANT

This is not an official Autodesk script.

Test the complete archive and restore workflow before using it on production projects.

Review and change `archive_storage_path` before use. An unsuitable location can fill the system partition quickly.

Compact and Omitted archives intentionally do not force all source media into the archive. Use the archive type appropriate for the required restore workflow.

## WHAT THIS DOES

1. Flame is started using `start_wrapper.sh`.
2. The current project is flagged from the **After Session Archiver** menu inside Flame.
3. The hook writes the selected project to `state.json`.
4. Flame exits normally.
5. `flame_after_session_archiver.sh` reads the queued project.
6. The archive type is read from `archive.config` when automatic mode is enabled.
7. The script creates or appends to the Flame archive under `archive_storage_path`.
8. The actual archive location and effective archive type are written to `state.json` while the archive is running.
9. The state file is removed after the archive completes successfully.
10. Uploads the completed archive to Flow Production Tracking or other destination.  (Coming Soon).

If archiving fails, the state file is preserved for troubleshooting and remains queued. Unless the request is cleared, the wrapper will retry it after a later Flame session exits.

## REPOSITORY FILES

```text
Flame_After_Session_Archiver_Plus/
├── README.md
├── archive.config
├── start_wrapper.sh
├── flame_after_session_archiver.sh
└── after_session_archiver_hook.py
```

### `archive.config`

Contains customizable variables for Flame, archive storage, archive type, and the Python interpreter used for state-file processing.

### `start_wrapper.sh`

Starts Flame, preserves Flame's exit status, and starts the archive script after Flame exits when a project has been flagged.

### `flame_after_session_archiver.sh`

Creates or appends to the Flame archive for the project selected from Flame.

### `after_session_archiver_hook.py`

Adds the **After Session Archiver** menu to Flame and records the current project when it is flagged.

## REQUIREMENTS

- Autodesk Flame Family
- `/opt/Autodesk/io/bin/flame_archive`
- Bash
- Python 3
- A writable archive storage location with sufficient free space

The workflow is intended for Rocky Linux and macOS Flame workstations. Validate the exact Flame and operating-system release before production deployment.

## INSTALLATION

Create the installation folders:

```bash
sudo mkdir -p /opt/Autodesk/archive/Flame_After_Session_Archiver
sudo mkdir -p /var/tmp/Flame_After_Session_Archiver
```

Copy the archive files:

```bash
sudo cp \
    archive.config \
    start_wrapper.sh \
    flame_after_session_archiver.sh \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/
```

Copy the Flame hook:

```bash
sudo cp \
    after_session_archiver_hook.py \
    /opt/Autodesk/shared/python/
```

Set permissions:

```bash
sudo chmod 644 \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/archive.config

sudo chmod 755 \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/start_wrapper.sh

sudo chmod 755 \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/flame_after_session_archiver.sh

sudo chmod 755 \
    /opt/Autodesk/shared/python/after_session_archiver_hook.py

sudo chmod 1777 /var/tmp/Flame_After_Session_Archiver
```

For production use, set the owner or group for the Flame user and use the least-permissive access that allows the workflow to run.

`/opt/Autodesk/shared/python` is the normal shared Flame Python hook location. Sites using centralized Flame configuration may use a redirected shared Python location instead.

## SETUP: CUSTOMIZABLE VARIABLES

Edit:

```bash
sudo nano /opt/Autodesk/archive/Flame_After_Session_Archiver/archive.config
```

### `archive_storage_path`

Define the archive storage location. This can be local, external, SAN, or NAS storage.

```bash
archive_storage_path="/mnt/flame_archives"
```

The location must already exist and must be writable by the user running the archive script.

The project archive folder is created as:

```text
ARCHIVE_STORAGE_PATH/PROJECT_NAME_archive/
```

The Flame archive container is created as:

```text
ARCHIVE_STORAGE_PATH/PROJECT_NAME_archive/PROJECT_NAME
```

### `archive_type`

`archive.config` is the authoritative source for the automatic archive type.

Normal Archive:

```bash
archive_type="N"
```

Normal mode passes `-N` to `flame_archive`, which forces applicable source media and renders into the archive according to Flame's Normal archive behavior.

Compact Archive:

```bash
archive_type="C"
```

Compact is the default `flame_archive` behavior when `-N` is not supplied. It minimizes archive size and does not force all source media into the archive. Do not assume a Compact archive is a self-contained media backup.

Omitted Archive:

```bash
archive_type="O"
```

The current Omitted mode uses:

```text
-k -O renders,sources,unused,maps
```

This intentionally omits media categories and should not be treated as a self-contained media backup.

### `auto_archive`

Archive automatically without user input when Flame exits:

```bash
auto_archive="true"
```

Prompt for the archive type after Flame exits:

```bash
auto_archive="false"
```

Manual mode requires an interactive terminal. In manual mode, the operator's N/C/O choice overrides `archive_type` for that run.

### `turn_off`

Disable the After Session Archiver without removing its files:

```bash
turn_off="true"
```

Enable it:

```bash
turn_off="false"
```

### `flame_version`

Set the installed Flame version:

```bash
flame_version="2027.1"
```

The default Flame launch path is built from this value:

```bash
flame_start_application="/opt/Autodesk/flame_${flame_version}/bin/startApplication"
```

If Flame uses another location, edit `flame_start_application` directly.

### `python_binary`

The archive script uses Python to read and atomically update the JSON state file:

```bash
python_binary="/usr/bin/python3"
```

Set this to an executable Python 3 interpreter available on the workstation.

## STARTING FLAME

Start Flame using:

```bash
/opt/Autodesk/archive/Flame_After_Session_Archiver/start_wrapper.sh
```

The after-session workflow runs only when Flame is started through this wrapper.

If Flame is normally started through a desktop launcher, update the launcher to call `start_wrapper.sh` instead of Flame's `startApplication` directly.

The wrapper returns Flame's original exit status. A post-session archive failure is reported separately and does not replace Flame's exit status.

## USING THE FLAME MENU

After Flame loads the hook, the menu contains:

```text
After Session Archiver
├── Flag Project For Archive
├── Clear Archive Flag
└── Show Archive Status
```

### Flag Project For Archive

Records the project currently open in Flame and queues that project for archive after Flame exits.

The request is written to:

```text
/var/tmp/Flame_After_Session_Archiver/state.json
```

The hook deliberately does not choose the archive type. The automatic archive type comes from `archive.config` when the archive process starts.

If the user flags Project A and later switches to Project B without flagging again, Project A remains queued. Flagging another project replaces the pending request with the newly selected project.

### Clear Archive Flag

Removes the pending archive request. Flame can then exit without starting an archive.

### Show Archive Status

Displays the queued project and current state. If the archiver has already populated them, it also displays the effective archive type and archive location.

During a normal Flame session the state will usually remain `pending`; the actual archive begins only after Flame exits.

## STATE FILE

After a project is flagged, the state file resembles:

```json
{
    "current_project": "temp_only",
    "requested_at": "2026-09-28T12:17:33",
    "status": "pending"
}
```

After the archiver starts, it records the effective archive settings and destination:

```json
{
    "current_project": "temp_only",
    "requested_at": "2026-09-28T12:17:33",
    "status": "archiving",
    "archive_type": "C",
    "archive_storage_path": "/mnt/flame_archives",
    "project_folder": "temp_only_archive",
    "archive_file": "/mnt/flame_archives/temp_only_archive/temp_only",
    "status_updated_at": "2026-09-28T12:22:10",
    "archive_preparation_started_at": "2026-09-28T12:22:09",
    "archive_started_at": "2026-09-28T12:22:10"
}
```

The state file is removed after successful completion.

If an archive fails, the state file is intentionally retained. That retained request remains queued and will be retried after a later Flame session exits through the wrapper unless the request is cleared first.

## TESTING

Use a disposable Flame project and test archive storage before production use.

### 1. Configure Test Storage

For example:

```bash
archive_storage_path="/var/tmp/TEST ARC FOLDER"
archive_type="C"
auto_archive="true"
```

Create the test location:

```bash
mkdir -p "/var/tmp/TEST ARC FOLDER"
chmod 777 "/var/tmp/TEST ARC FOLDER"
```

### 2. Validate the Scripts

```bash
bash -n \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/archive.config

bash -n \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/start_wrapper.sh

bash -n \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/flame_after_session_archiver.sh

```

Validate the Python hook with an available Python 3 interpreter outside Flame for syntax only:

```bash
/usr/bin/python3 -m py_compile \
    /opt/Autodesk/shared/python/after_session_archiver_hook.py
```

The PySide/Flame imports are runtime dependencies supplied by the Flame environment; syntax validation alone does not prove the hook has loaded into Flame.

### 3. Start Flame Through the Wrapper

```bash
/opt/Autodesk/archive/Flame_After_Session_Archiver/start_wrapper.sh
```

### 4. Flag the Project

Inside Flame, select:

```text
After Session Archiver > Flag Project For Archive
```

### 5. Confirm the Request

From another terminal:

```bash
cat /var/tmp/Flame_After_Session_Archiver/state.json
```

Confirm that `current_project` matches the project open in Flame. The initial queued state should not contain `archive_type`; that value comes from `archive.config` after Flame exits.

### 6. Exit Flame

Exit Flame normally. The archive process should start after Flame exits.

### 7. Review the Archive

Confirm that the expected project archive folder and archive container were created under `archive_storage_path`.

Review the log:

```bash
cat \
    /var/tmp/Flame_After_Session_Archiver/flame_after_session_archiver.log
```

Test restoration of Normal, Compact, and Omitted archives according to the intended recovery requirements before production use.

## TROUBLESHOOTING

### The Menu Does Not Appear in Flame

Confirm the hook exists:

```bash
ls -l /opt/Autodesk/shared/python/after_session_archiver_hook.py
```

Restart Flame after installing or replacing the hook.

If the site uses centralized Flame configuration, confirm that the shared Python hook location has not been redirected.

### The Hook Cannot Determine the Current Project

The hook prints the underlying exception to Flame's console/shell before showing the generic warning dialog. Review that output for the Python API error.

### The Archive Does Not Run After Flame Exits

Confirm:

- Flame was started using `start_wrapper.sh`.
- The project was flagged from the Flame menu.
- `state.json` exists before Flame exits.
- `turn_off="false"`.

Review the state file:

```bash
cat /var/tmp/Flame_After_Session_Archiver/state.json
```

### Archive Storage Is Not Accessible

Review the configured path:

```bash
grep '^archive_storage_path=' \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/archive.config
```

Confirm the path exists and is writable:

```bash
test -d "/your/archive/path" && echo "Directory exists"
test -w "/your/archive/path" && echo "Directory is writable"
```

### Python Interpreter Is Not Available

Review:

```bash
grep '^python_binary=' \
    /opt/Autodesk/archive/Flame_After_Session_Archiver/archive.config
```

Confirm it exists and is executable:

```bash
test -x /usr/bin/python3 && echo "Python is executable"
```

### The State File Is Preserved

A preserved state file indicates that the archive did not complete successfully or was intentionally left queued.

Review:

```bash
cat /var/tmp/Flame_After_Session_Archiver/state.json
```

and:

```bash
tail -n 100 \
    /var/tmp/Flame_After_Session_Archiver/flame_after_session_archiver.log
```

Look for `archive_error`, `archive_status`, or the current `status` value.

A retained state file remains queued. Fix the underlying problem and allow the wrapper to retry it, or clear the request from Flame before exiting if the retry is not wanted.

## UNINSTALL

Remove the installed files, or stop launching Flame through `start_wrapper.sh`.

## NOTES AND CAVEATS

- This is not an official Autodesk script.
- Review all scripts before use.
- Change `archive_storage_path` before production use.
- Confirm the archive storage has enough available space.
- Test archive creation and archive restoration.
- Compact and Omitted archives may not contain all source media.
- The archive path comes from `archive.config`, not the Flame hook.
- The automatic archive type comes from `archive.config`, not the Flame hook.
- The project is captured from Flame when **Flag Project For Archive** is chosen.
- A failed archive request remains queued until it succeeds or is cleared.

## DISCLAIMER

This project is provided as an example workflow and for informational guidance only. Use it at your own risk.

Test archive creation, archive restoration, permissions, storage usage, and recovery behavior in a non-production environment before deployment.

The operator and system administrator are responsible for backup verification, available storage, access control, and recovery testing.
