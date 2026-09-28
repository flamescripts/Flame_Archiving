#!/bin/bash
#
# Name: Flame After Session Archiver Start Wrapper
#
# USAGE:
#   /opt/Autodesk/archive/Flame_After_Session_Archiver/start_wrapper.sh
#
# Description:
# Start Flame, preserve its exit status, and run the After Session
# Archiver when Flame exits if a project has been flagged.
#

## Variables
archiver_folder="/opt/Autodesk/archive/Flame_After_Session_Archiver"
config_file="${archiver_folder}/archive.config"

## Check Configuration
if [[ ! -r "${config_file}" ]]; then
    printf "Warning: The configuration file is not available:\n"
    printf "    %s\n\n" "${config_file}"
    exit 1
fi

# shellcheck source=/dev/null
source "${config_file}"

## Check Flame Start Application
if [[ ! -x "${flame_start_application}" ]]; then
    printf "Warning: Flame startApplication is not executable:\n"
    printf "    %s\n\n" "${flame_start_application}"
    exit 1
fi

## Start Flame
"${flame_start_application}" "$@"
flame_exit_status=$?

## Check Archive Request
if [[ ! -f "${state_file}" ]]; then
    exit "${flame_exit_status}"
fi

## Check Archiver
if [[ ! -x "${archiver_script}" ]]; then
    printf "\nWarning: Flame After Session Archiver is not executable:\n"
    printf "    %s\n\n" "${archiver_script}"
    exit "${flame_exit_status}"
fi


## Start Archiver
"${archiver_script}"
archiver_status=$?

if [[ ${archiver_status} -ne 0 ]]; then
    printf "\nWarning: Flame After Session Archiver failed.\n"
    printf "Archiver status: %s\n" "${archiver_status}"
    printf "State file preserved at:\n"
    printf "    %s\n\n" "${state_file}"
fi

## Preserve Flame Exit Status
exit "${flame_exit_status}"
