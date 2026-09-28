#!/usr/bin/env python3
#
# Name: after_session_archiver_hook.py
#
# Description:
# Flag the current Flame project for archiving after Flame exits.
#

import json
from datetime import datetime
from pathlib import Path

try:
    from PySide6 import QtWidgets
except ImportError:
    from PySide2 import QtWidgets


STATE_FILE = Path(
    "/var/tmp/Flame_After_Session_Archiver/state.json"
)

MENU_NAME = "After Session Archiver"


def show_info(message):
    QtWidgets.QMessageBox.information(
        None,
        MENU_NAME,
        message
    )


def show_warning(message):
    QtWidgets.QMessageBox.warning(
        None,
        MENU_NAME,
        message
    )


def current_project_name():
    try:
        import flame

        project = flame.project.current_project

        if project and project.name:
            return str(project.name).strip()

    except Exception as exception:
        print(
            "After Session Archiver: "
            "Unable to determine current project: %s"
            % exception
        )

    return None


def write_state(state):
    STATE_FILE.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    temporary_file = STATE_FILE.with_suffix(".tmp")

    with temporary_file.open(
        "w",
        encoding="utf-8"
    ) as handle:
        json.dump(
            state,
            handle,
            indent=4
        )

    temporary_file.replace(STATE_FILE)


def flag_project_for_archive(selection):
    del selection

    project_name = current_project_name()

    if not project_name:
        show_warning(
            "Unable to determine the current Flame project."
        )
        return

    state = {
        "current_project": project_name,
        "requested_at": datetime.now().isoformat(),
        "status": "pending"
    }

    try:
        write_state(state)
    except Exception as exception:
        show_warning(
            "Unable to create archive request:\n\n%s"
            % exception
        )
        return

    show_info(
        "Project queued for archive.\n\n"
        "Project:\n"
        "    %s"
        % project_name
    )


def clear_archive_flag(selection):
    del selection

    try:
        STATE_FILE.unlink(missing_ok=True)
    except Exception as exception:
        show_warning(
            "Unable to clear archive request:\n\n%s"
            % exception
        )
        return

    show_info("Archive request cleared.")


def show_archive_status(selection):
    del selection

    if not STATE_FILE.is_file():
        show_info(
            "No project is currently queued for archive."
        )
        return

    try:
        with STATE_FILE.open(
            "r",
            encoding="utf-8"
        ) as handle:
            state = json.load(handle)

    except Exception as exception:
        show_warning(
            "Unable to read archive state:\n\n%s"
            % exception
        )
        return

    message = (
        "Project:\n"
        "    %s\n\n"
        "Archive Type:\n"
        "    %s\n\n"
        "Status:\n"
        "    %s"
        % (
            state.get("current_project", ""),
            state.get("archive_type", "Not started"),
            state.get("status", "pending")
        )
    )

    archive_file = state.get("archive_file")

    if archive_file:
        message += (
            "\n\nArchive:\n"
            "    %s"
            % archive_file
        )

    show_info(message)


def get_main_menu_custom_ui_actions():
    return [
        {
            "name": MENU_NAME,
            "actions": [
                {
                    "name": "Flag Project For Archive",
                    "execute": flag_project_for_archive
                },
                {
                    "name": "Clear Archive Flag",
                    "execute": clear_archive_flag
                },
                {
                    "name": "Show Archive Status",
                    "execute": show_archive_status
                }
            ]
        }
    ]
