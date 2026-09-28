#!/bin/bash
#
# Name: Flame After Session Archiver
#
# USAGE:
#   ./flame_after_session_archiver.sh
#
# REQUIRED:
# Edit archive_storage_path in archive.config.
#
# SETUP:
#   archive_storage_path:
#       Archive storage location.
#
#   archive_type:
#       Select (N)ormal, (C)ompact, or (O)mitted.
#
#   auto_archive:
#       Set to "true" to archive without user input.
#
#   turn_off:
#       Set to "true" to disable the archiver.
#

## Configuration
archiver_folder="/opt/Autodesk/archive/Flame_After_Session_Archiver"
config_file="${archiver_folder}/archive.config"

if [[ ! -r "${config_file}" ]]; then
    printf "Warning: The configuration file is not available:\n"
    printf "    %s\n\n" "${config_file}"
    exit 1
fi

# shellcheck source=/dev/null
source "${config_file}"

## Typesetting
if [[ -t 1 ]]; then
    bold=$(tput bold)
    underline=$(tput smul)
    normal=$(tput sgr0)
else
    bold=
    underline=
    normal=
fi


## Functions
write_log() {
    local message

    message="$1"

    mkdir -p "$(dirname "${log_file}")"

    printf "%s | %s\n" \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "${message}" \
        | tee -a "${log_file}"
}

read_state_value() {
    local state_key

    state_key="$1"

    "${python_binary}" - \
        "${state_file}" \
        "${state_key}" <<'PY'
import json
import sys

state_file = sys.argv[1]
state_key = sys.argv[2]

with open(state_file, "r", encoding="utf-8") as handle:
    state = json.load(handle)

state_value = state.get(state_key)

if state_value is None:
    raise SystemExit(1)

if isinstance(state_value, str):
    state_value = state_value.strip()

if state_value == "":
    raise SystemExit(1)

print(state_value)
PY
}

update_state() {
    local new_status
    local status_key
    local status_value

    new_status="$1"
    status_key="${2:-}"
    status_value="${3:-}"

    export state_file
    export new_status
    export status_key
    export status_value
    export current_project
    export archive_type
    export archive_storage_path
    export project_folder
    export archive_file

    "${python_binary}" <<'PY'
import json
import os
from datetime import datetime
from pathlib import Path

state_file = Path(os.environ["state_file"])

with state_file.open("r", encoding="utf-8") as handle:
    state = json.load(handle)

state["current_project"] = os.environ["current_project"]
state["archive_type"] = os.environ["archive_type"]
state["archive_storage_path"] = os.environ["archive_storage_path"]
state["project_folder"] = os.environ["project_folder"]
state["archive_file"] = os.environ["archive_file"]
state["status"] = os.environ["new_status"]
state["status_updated_at"] = datetime.now().isoformat()

status_key = os.environ.get("status_key", "")
status_value = os.environ.get("status_value", "")

if status_key:
    if status_value:
        state[status_key] = status_value
    else:
        state[status_key] = datetime.now().isoformat()

temporary_state_file = state_file.with_suffix(".tmp")

with temporary_state_file.open("w", encoding="utf-8") as handle:
    json.dump(state, handle, indent=4)

temporary_state_file.replace(state_file)
PY
}

check_prereqs() {
    local flame_family_pid

    if [[ "${turn_off}" == "true" ]]; then
        printf "%sNotice%s: Script has been turned off. " \
            "${bold}" \
            "${normal}"

        printf "Flame After Session Archiver Exiting.\n\n"
        exit 0
    fi

    flame_family_pid=$(
        for flame_family_application in flame flare
        do
            pgrep "${flame_family_application}" 2>/dev/null
        done
    )

    if [[ -n "${flame_family_pid}" ]]; then
        printf "%sWarning%s: Flame Family is still running " \
            "${bold}" \
            "${normal}"

        printf "(PID %s). " "${flame_family_pid}"
        printf "Flame After Session Archiver Exiting.\n\n"
        exit 1
    fi

    if [[ ! -f "${state_file}" ]]; then
        printf "%sWarning%s: Archive state file is not available:\n" \
            "${bold}" \
            "${normal}"

        printf "    %s\n\n" "${state_file}"
        exit 1
    fi

    if [[ ! -d "${archive_storage_path}" ]]; then
        printf "%sWarning%s: Archive storage path is not accessible:\n" \
            "${bold}" \
            "${normal}"

        printf "    %s\n\n" "${archive_storage_path}"
        exit 1
    fi

    if [[ ! -w "${archive_storage_path}" ]]; then
        printf "%sWarning%s: Archive storage path is not writable:\n" \
            "${bold}" \
            "${normal}"

        printf "    %s\n\n" "${archive_storage_path}"
        exit 1
    fi

    if [[ ! -x "${archive_binary}" ]]; then
        printf "%sWarning%s: The flame_archive binary is unavailable:\n" \
            "${bold}" \
            "${normal}"

        printf "    %s\n\n" "${archive_binary}"
        exit 1
    fi

    if [[ ! -x "${python_binary}" ]]; then
        printf "%sWarning%s: The configured Python interpreter is unavailable:\n" \
            "${bold}" \
            "${normal}"

        printf "    %s\n\n" "${python_binary}"
        exit 1
    fi
}

get_user_input() {
    printf "Would you like to archive the project %s%s%s?\n" \
        "${bold}" \
        "${current_project}" \
        "${normal}"

    printf "  Enter (%sN%s) for a Normal archive.\n" \
        "${bold}" \
        "${normal}"

    printf "  Enter (%sC%s) for a Compact archive.\n" \
        "${bold}" \
        "${normal}"

    printf "  Enter (%sO%s) for an Omitted archive.\n" \
        "${bold}" \
        "${normal}"

    printf "  Enter (%sQ%s) to quit without archiving.\n\n" \
        "${bold}" \
        "${normal}"

    read -r -n 1 -p \
        "Choose an archive type: " \
        archive_type

    printf "\n"

    case "${archive_type}" in
        [Nn])
            archive_project "N" "Normal Archive"
            ;;

        [Cc])
            archive_project "C" "Compact Archive"
            ;;

        [Oo])
            archive_project "O" \
                "Archive omitting sources, renders, maps and unused"
            ;;

        [Qq])
            printf "Flame After Session Archiver Exiting.\n\n"
            exit 0
            ;;

        *)
            printf "%s%s%s is an invalid option. " \
                "${bold}" \
                "${archive_type}" \
                "${normal}"

            printf "Flame After Session Archiver Exiting.\n\n"
            exit 1
            ;;
    esac
}

archive_project() {
    local selected_archive_type
    local archive_description

    selected_archive_type="$1"
    archive_description="$2"

    if [[ "${new_screen}" == "true" ]] && [[ -t 1 ]]; then
        clear
    fi

    printf "%s%s%s was selected: Archiving project %s%s%s.\n\n" \
        "${bold}" \
        "${archive_description}" \
        "${normal}" \
        "${bold}" \
        "${current_project}" \
        "${normal}"

    if ! update_state \
        "preparing_archive" \
        "archive_preparation_started_at"
    then
        printf "%sWarning%s: Unable to update archive state.\n\n" \
            "${bold}" \
            "${normal}"

        exit 1
    fi

    printf "Checking if an existing Flame archive exists for "
    printf "%s%s%s...\n" \
        "${bold}" \
        "${current_project}" \
        "${normal}"

    if [[ -f "${archive_file}" ]]; then
        printf "Using the existing Flame archive:\n"
        printf "    %s%s%s\n\n" \
            "${underline}" \
            "${archive_file}" \
            "${normal}"
    else
        printf "Creating the archive structure.\n"

        printf " - Create folder %s%s/%s%s...\n" \
            "${underline}" \
            "${archive_storage_path}" \
            "${project_folder}" \
            "${normal}"

        if ! mkdir -m 777 -p \
            "${archive_storage_path}/${project_folder}"
        then
            printf "Unable to create the archive project folder.\n\n"

            update_state \
                "archive_failed" \
                "archive_error" \
                "Unable to create the archive project folder."

            exit 1
        fi

        printf "   + Folder created.\n"

        printf " - Create Flame archive container %s%s%s...\n" \
            "${underline}" \
            "${archive_file}" \
            "${normal}"

        if ! "${archive_binary}" \
            --format \
            --name "${current_project}" \
            --comment \
            "Created using Flame After Session Archiver on $(date '+%A %m-%d-%Y %H:%M')" \
            --file "${archive_file}" \
            1>/dev/null
        then
            printf "Unable to create the Flame archive container.\n\n"

            update_state \
                "archive_failed" \
                "archive_error" \
                "Unable to create the Flame archive container."

            exit 1
        fi

        printf "   + Flame archive container created.\n\n"
    fi

    update_state \
        "archiving" \
        "archive_started_at"

    printf "Starting %s%s%s project archive.\n\n" \
        "${bold}" \
        "${current_project}" \
        "${normal}"

    case "${selected_archive_type}" in
        N)
            "${archive_binary}" \
                -a \
                -P "${current_project}" \
                --file "${archive_file}" \
                -N
            ;;

        C)
            "${archive_binary}" \
                -a \
                -P "${current_project}" \
                --file "${archive_file}"
            ;;

        O)
            "${archive_binary}" \
                -a \
                -P "${current_project}" \
                --file "${archive_file}" \
                -k \
                -O renders,sources,unused,maps
            ;;

        *)
            printf "Invalid internal archive type: %s\n\n" \
                "${selected_archive_type}"

            exit 1
            ;;
    esac

    archive_status=$?

    if [[ ${archive_status} -ne 0 ]]; then
        printf "\n%sWarning%s: flame_archive failed during " \
            "${bold}" \
            "${normal}"

        printf "the session write.\n\n"

        update_state \
            "archive_failed" \
            "archive_status" \
            "${archive_status}"

        exit 1
    fi

    update_state \
        "archive_complete" \
        "archive_completed_at"

    printf "\n%s%s%s %s process complete.\n\n" \
        "${bold}" \
        "${current_project}" \
        "${normal}" \
        "${archive_description}"

    printf "Archive container:\n"
    printf "    %s%s%s\n\n" \
        "${underline}" \
        "${archive_file}" \
        "${normal}"


    update_state \
        "complete" \
        "completed_at"

    rm -f "${state_file}"

    printf "Flame After Session Archiver complete.\n\n"

    exit 0
}

## Start
printf "\nFlame After Session Archiver Starting.\n\n"
printf "This script operates independently of Flame and should be "
printf "deactivated if issues are encountered within Flame.\n\n"

check_prereqs

## Read Project From Hook State
current_project=$(
    read_state_value "current_project"
)

state_status=$?

if [[ ${state_status} -ne 0 ]] ||
   [[ -z "${current_project}" ]]
then
    printf "%sWarning%s: Unable to read current_project from:\n" \
        "${bold}" \
        "${normal}"

    printf "    %s\n\n" "${state_file}"
    exit 1
fi

## Archive Variables
project_folder="${current_project}_archive"
archive_file="${archive_storage_path}/${project_folder}/${current_project}"


write_log \
    "Flame project selected by hook: ${current_project}"

write_log \
    "Archive storage path: ${archive_storage_path}"

write_log \
    "Archive container: ${archive_file}"

## Automatic Archive Mode
if [[ -n "${archive_type}" ]] &&
   [[ "${auto_archive}" == "true" ]]
then
    new_screen=false

    printf "Note: auto_archive is true and archive_type is %s%s%s.\n\n" \
        "${bold}" \
        "${archive_type}" \
        "${normal}"

    case "${archive_type}" in
        [Nn])
            archive_project "N" "Normal Archive"
            ;;

        [Cc])
            archive_project "C" "Compact Archive"
            ;;

        [Oo])
            archive_project "O" \
                "Archive omitting sources, renders, maps and unused"
            ;;

        *)
            printf "Expected N, C, or O but received: %s\n\n" \
                "${archive_type}"

            printf "Flame After Session Archiver Exiting.\n\n"
            exit 1
            ;;
    esac


## Manual Fallback
else
    new_screen=true
    get_user_input
fi
