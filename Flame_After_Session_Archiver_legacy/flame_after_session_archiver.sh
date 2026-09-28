#!/bin/bash
#
# 06/08/24
#
# Name: Flame After Session Archiver
#
# USAGE: ./flame_after_session_archiver.sh
#
# REQUIRED: Edit value for archive_storage_path to the prefered backup location for Flame.
# * Change this or the system partition will fill up fast.
#
# SETUP (Customizable Variables):
#   - archive_storage_path: Define the archive storage location, local, external, SAN/NAS, etc.
#   - archive_type: Select the desired archive Type, (N)ormal, (C)ompact, (O)mitted or leave blank to be prompeted after each Flame session.  Only available when used with 'auto_archive'.
#   - auto_archive: Archive automatically without user input when Flame exits.  Append "true" to enable.  Default value is "false". Only available when used with 'archive_type'.
#   - turn_off=true: Stop script and exit without archivin.  Append "true" to turn off script.  Default value is "false" will allow script to continue.
#
# See README.md for description, disclaimer, testing environments, installation notes and caveats.
#
# Always Current Version: https://github.com/flamescripts


## Customizable Variables
archive_storage_path="/var/tmp/TEST ARC FOLDER"
archive_type=
auto_archive= 
turn_off=

## Other Variables
archive_binary=/opt/Autodesk/io/bin/flame_archive
current_project=$(ls -lrt /opt/Autodesk/clip/stonefs*/*.prj/*.wksp/.\#workspace.000.wks | tail -n 1 | cut -d "/" -f6 | cut -d "." -f1)
project_folder=${current_project}_archive
archive_file=${archive_storage_path}/${project_folder}/${current_project}

## Typesetting
bold=$(tput bold)
underline=$(tput smul)
normal=$(tput sgr0)

## Functions
check_prereqs() {
    # Check if script is disabled, if so, exit
    if [[ "$turn_off" ]]; then
        printf "${bold}Notice${normal}: Script has been turned off... Flame After Session Archiver Exiting.\n\n"
        exit 0
    fi

    # Check if Flame family is in session
    local flame_family_pid=$(for i in flame flare; do pgrep $i; done)
    if [[ "$flame_family_pid" ]]; then
        printf "${bold}Warning${normal}: Flame Family is still running (${bold}PID $flame_family_pid${normal})... Flame After Session Archiver Exiting.\n\n"
        exit 1
    fi

	# Check if the Archive base path exists
    if [ ! -d "${archive_storage_path}" ]; then
        printf "${bold}Warning${normal}: ${archive_storage_path} is not accessible""... Flame After Session Archiver Exiting.\n\n"
        exit 1
    fi

    # Check if the Archive base path is writable
    if [ ! -w "${archive_storage_path}" ]; then
        printf "${bold}Warning${normal}: ${archive_storage_path} is not writable or not accessible... Flame After Session Archiver Exiting.\n\n"
        exit 1
    fi

	# Validate that flame_archive exists and is usable by this script.
    command -v $archive_binary >/dev/null 2>&1 || {
        printf "${bold}Warning!${normal} The flame_archive binary not available.  Flame After Session Archiver Exiting.\n\n"
        exit 1
    }
}

get_user_input() {
	printf "Would you like to archive the project ${bold}$current_project${normal}?
	  Enter (${bold}N${normal}) to Archive/Append to a \"${bold}Normal${normal}\" archive - Archive media from clips, and renders.
	  Enter (${bold}C${normal}) to Archive/Append to a \"${bold}Compact${normal}\" archive - Archive Timeline FX renders and already cached media.
	  Enter (${bold}O${normal}) to Archive/Append to a \"${bold}Omitted${normal}\" archive - Archive and exclude sources,renders,maps and unused.
	  Enter (${bold}Q${normal}) to ${bold}Quit${normal} this script and exit the Flame session${normal} without archiving.\n\n"

    read -r -n 1 -p "Choose from the above options to select your archive types or press any other key to exit: " archive_type;printf "\n"

    case $archive_type in
        [Nn]* ) archive_project "-N" "Normal Archive";;
        [Cc]* ) archive_project "" "Compact Archive";;
        [Oo]* ) archive_project "-k -O renders,sources,unused,maps" "Archive omitting sources, renders, maps and unused";;
        [Qq]* ) printf "*Flame After Session Archiver Exiting.\n\n"; exit 0 ;;
        *     ) printf "${bold}$archive_type${normal} is an ${bold}Invalid option${normal}. Flame After Session Archiver Exiting.\n\n"; exit 1 ;;
    esac
}

archive_project() {
    if [[ "${new_screen}" = true ]]; then
    	clear
    fi
    
    printf "${bold}$2${normal} was selected: Archiving project ${bold}$current_project${normal}.\n\n"
    
    # Check if Archive exists, else, create the Path and Flame archive container
    printf "Checking if existing Flame archive exists for ${bold}$current_project${normal}..\n"
    if [ -f "$archive_file" ]; then
        printf "Using the existing Flame archive: ${underline}$archive_file${normal}.\n\n"
    else
        printf "An archive of ${bold}$current_project${normal} does not exist in ${underline}$archive_storage_path${normal}!\n\nCreating that archive structure now...\n"
		printf " - Create folder ${underline}${archive_storage_path}/${project_folder}${normal}...\n"
        mkdir -m 777 -p "${archive_storage_path}/${project_folder}"
		if [ $? -ne 0 ] && [ ! -f "${archive_storage_path}/${project_folder}" ]; then
			printf "Something went wrong with creating the project folder... Flame After Session Archiver Exiting.\n\n"
			exit 1
		else
			printf "   + Folder ${underline}${archive_storage_path}/${project_folder}${normal} was created.\n"
		fi

		printf " - Create Flame archive container ${underline}$archive_file${normal}...\n"
        if ! $archive_binary --format --name "$current_project" --comment "Created using Flame After Session Archiver on $(date '+%A %m-%d-%Y %H:%M')" --file "$archive_file" 1>/dev/null; then
			printf "Something went wrong with flame_archive on container creation... Flame After Session Archiver Exiting.\n\n"
			exit 1
		else
			printf "   + Flame archive container ${underline}$archive_file${normal} was created.\n\n"			
		fi
    fi

	# Archive the project based on user input, check for errors.
    printf "Starting ${bold}$current_project${normal} project archive.\n\n"
	$archive_binary -a -P "$current_project" --file "$archive_file" $1

	# Capture the exit status immediately after the command execution
	archive_status=$?

	# Check and report status to user
	if [ $archive_status -ne 0 ]; then
    	printf "\n${bold}Warning${normal}: Something went wrong with flame_archive on session write... Flame After Session Archiver Exiting.\n\n"
		exit 1
	else
    	printf "\n${bold}$current_project${normal} $2 process complete.\n\nPlease review the information above for errors or other important information from flame_archive .\n\n"
    	printf "Archive log can be found in ${underline}${archive_storage_path}/${project_folder}${normal}.\n\n"
    	exit 0
	fi
}

# Indicate to user that this is the start of a new program and not related top Flame.
printf "\nFlame After Session Archiver Starting.\n\nThis script operates independently of Flame and should be deactivated if issues are encountered within Flame.\n\n"

# Check if Flame Family is running, script is launched prior to return of exitStatus in function runApplication in the start script, ~line 389.
check_prereqs
	
# Check if 'archive_type' is set and 'auto_archive' is true
if [[ "${archive_type}" && "${auto_archive}" == "true" ]]; then
    new_screen=false
       printf "Note: 'auto_archive' is set to ${bold}true${normal} and archive_type is declared (${bold}$archive_type${normal}), attempting to proceed automatically.\n\n"
    if [[ ${archive_type} =~ ^[Nn]$ ]]; then
        archive_project "-N" "Normal Archive"
    elif [[ ${archive_type} =~ ^[Cc]$ ]]; then
        archive_project "" "Compact Archive"
    elif [[ ${archive_type} =~ ^[Oo]$ ]]; then
        archive_project "-k -O renders,sources,unused,maps" "Archive omitting sources, renders, maps and unused"
    else
        printf "Something went wrong with selecting the archive type. Expected N, C, or O but got ($archive_type) for 'archive_type'...\n\nFlame After Session Archiver Exiting.\n\n"
        exit 1
    fi

# Check if 'auto_archive' is true and 'archive_type' is not set
elif [[ -z "${archive_type}" && "${auto_archive}" == "true" ]]; then
    printf "${bold}Warning${normal}: 'auto_archive' is set to true, but the 'archive_type' is not declared. This should be resolved. Switching to manual mode.\n\n"
    new_screen=true
    get_user_input

# Manual Selection Mode
else
    new_screen=true
    get_user_input
fi
