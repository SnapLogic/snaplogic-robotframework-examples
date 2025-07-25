import os
import re
import subprocess
import sys
from datetime import datetime

import requests
from robot.api import ExecutionResult
from tabulate import tabulate

# SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/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"
SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/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"


# Global variables for commit information
commit_url = None
commit_link = None


def format_build_id_field(build_number, commit_sha, repo_slug, branch, author, build_url):
    """
    Formats the Build ID field in a more informative format with hyperlinks.

    Example: Build #110 (97c4b7c) of SnapLogic/slim-tx-engine@main by Raffaele Cataldo passed in 4 min 48 sec
    """
    global commit_url, commit_link

    # Get short commit SHA (first 7 characters)
    short_sha = commit_sha[:7] if commit_sha and commit_sha != "N/A" else "N/A"

    # Create hyperlinks for Travis build and GitHub commit
    build_number_link = f"<{build_url}|#{build_number}>"

    # Create commit link
    commit_link = "N/A"
    if commit_sha and commit_sha != "N/A":
        # Create GitHub commit URL
        commit_url = f"https://github.com/{repo_slug}/commit/{commit_sha}"
        commit_link = f"<{commit_url}|{short_sha}>"

    # Determine build result
    result = os.environ.get("TRAVIS_TEST_RESULT")
    build_result = "passed" if result == "0" else "failed"

    # Format the build ID string with hyperlinks
    build_id_str = f"_Travis Build {build_number_link} ({commit_link}) of {repo_slug}@{branch} by {author}"

    return build_id_str


def get_travis_test_result():
    """Fetches the correct Travis CI test result, ensuring it is properly converted."""
    result = os.environ.get("TRAVIS_TEST_RESULT", "-1")  # Default to -1 if not set
    try:
        return int(result)
    except ValueError:
        return -1  # Handle unexpected non-numeric values


def get_author_name():
    """
    Get the author name from Travis environment variables or a default value.
    Prioritize environment variables over git commands to avoid git repository issues.
    """
    # First try to get the author from Travis environment variables
    travis_author = os.environ.get("TRAVIS_COMMIT_AUTHOR_NAME", "")
    if travis_author and travis_author.strip():
        return travis_author.strip()

    # Next try to get it from the author email
    travis_email = os.environ.get("TRAVIS_COMMIT_AUTHOR_EMAIL", "")
    if travis_email and "@" in travis_email:
        return travis_email.split("@")[0]

    # Try git as a last resort, but handle errors gracefully
    try:
        author = subprocess.check_output(["git", "log", "-1", "--pretty=format:%an"], stderr=subprocess.DEVNULL).decode("utf-8").strip()
        if author:
            return author
    except Exception:
        # Silently fail if git command doesn't work
        pass

    # Default fallback
    return "CI Build"


def get_robot_command():
    """Get the robot command from travis.yml"""
    try:
        # Always read from travis.yml (both local and CI/CD)
        travis_path = '/app/.travis.yml'
        if os.path.exists(travis_path):
            with open(travis_path, 'r') as f:
                for line in f:
                    if 'make robot-run-all-tests' in line and 'TAGS=' in line:
                        # Remove leading dash and whitespace
                        command = line.strip().lstrip('-').strip()
                        return command
        
        # Default fallback
        return "make robot-run-all-tests"
        
    except Exception as e:
        print(f"Error getting robot command: {e}")
        return "make robot-run-all-tests"


def get_wall_clock_time():
    """Read wall clock time from file if available"""
    try:
        wall_clock_file = 'robot_output/wall_clock_time.txt'
        if os.path.exists(wall_clock_file):
            with open(wall_clock_file, 'r') as f:
                lines = f.readlines()
                for line in lines:
                    if line.startswith('Formatted Time:'):
                        return line.split(':', 1)[1].strip()
                # Fallback to Total Wall Clock Time if Formatted Time not found
                for line in lines:
                    if line.startswith('Total Wall Clock Time:'):
                        return line.split(':', 1)[1].strip()
    except Exception as e:
        print(f"Could not read wall clock time: {e}")
    return None


def get_test_statistics(xml_path):
    result = ExecutionResult(xml_path)
    stats = result.statistics

    total_tests = stats.total.total
    passed = stats.total.passed
    failed = stats.total.failed
    knownissues = stats.total.skipped

    # Get the total elapsed time in milliseconds
    elapsed_milliseconds = int(result.suite.elapsedtime)

    # Convert to minutes, seconds, milliseconds format
    minutes = elapsed_milliseconds // 60000
    seconds = (elapsed_milliseconds % 60000) // 1000
    ms = elapsed_milliseconds % 1000
    cumulative_time = f"{minutes}m {seconds}s {ms}ms"
    
    # Try to get actual wall clock time
    wall_clock_time = get_wall_clock_time()
    
    # Use wall clock time if available, otherwise use cumulative time
    if wall_clock_time:
        formatted_time = wall_clock_time
        time_label = "Elapsed Time ⏱️"  # Changed from "Wall Clock Time ⏱️"
    else:
        formatted_time = cumulative_time
        time_label = "Elapsed Time ⏱️"

    pass_percentage = (passed / total_tests) * 100 if total_tests > 0 else 0
    fail_percentage = (failed / total_tests) * 100 if total_tests > 0 else 0
    knownissues_percentage = (knownissues / total_tests) * 100 if total_tests > 0 else 0

    data = [
        ["Passed", passed, f"{pass_percentage:.2f}%", "🟢"],
        ["Failed", failed, f"{fail_percentage:.2f}%", "🔴"],
        ["Skipped", knownissues, f"{knownissues_percentage:.2f}%", "🟡"],
        ["Total Tests", total_tests, "100.00%", ""],
        ["=============", "=====", "=========", "====="],
        [time_label, formatted_time, "", ""],
    ]

    headers = ["Status", "Count", "Percentage", ""]
    table = tabulate(data, headers=headers, tablefmt="pipe")

    return table, pass_percentage, fail_percentage, knownissues_percentage, formatted_time, wall_clock_time, cumulative_time


def send_slack_notification(table, pass_percentage, fail_percentage, knownissues_percentage, formatted_time=None):
    global commit_url, commit_link

    # ---------- TRAVIS CI INFORMATION COLLECTION ----------
    # Get all Travis-related environment variables in one place
    travis_info = {
        "pull_request": os.environ.get("TRAVIS_PULL_REQUEST", "false"),
        "pull_request_branch": os.environ.get("TRAVIS_PULL_REQUEST_BRANCH", "N/A"),
        "branch": os.environ.get("TRAVIS_BRANCH", "N/A"),
        "build_number": os.environ.get("TRAVIS_BUILD_NUMBER", "N/A"),
        "test_result": get_travis_test_result(),
        "repo_slug": os.environ.get("TRAVIS_REPO_SLUG", "N/A"),
        "build_id": os.environ.get("TRAVIS_BUILD_ID", "N/A"),
        "commit_message": os.environ.get("TRAVIS_COMMIT_MESSAGE", "N/A"),
        "commit": os.environ.get("TRAVIS_COMMIT", "N/A"),
        "event_type": os.environ.get("TRAVIS_EVENT_TYPE", "N/A"),
    }

    # ---------- DERIVED TRAVIS INFORMATION ----------
    # Determine branch name based on Travis environment
    if travis_info["pull_request"] != "false":
        branch_name = f"{travis_info['pull_request_branch']} #PR-{travis_info['pull_request']}"
    else:
        branch_name = travis_info["branch"]

    # Set build result
    print(f"test_result value: {travis_info['test_result']}, type: {type(travis_info['test_result'])}")
    build_result = "Passed" if travis_info["test_result"] == 0 else "Failed"

    # Set the Travis CI build link
    build_url = f"https://travis-ci.com/github/{travis_info['repo_slug']}/builds/{travis_info['build_id']}"

    # ---------- OTHER INFORMATION COLLECTION ----------
    author = get_author_name()
    robot_command = get_robot_command()

    # This will ensure the global variables are set before using them
    if commit_url is None or commit_link is None:
        format_build_id_field(travis_info["build_number"], travis_info["commit"], travis_info["repo_slug"], branch_name, author, build_url)

    # ---------- SLACK MESSAGE CONSTRUCTION ----------
    # Determine the pretext based on event type
    if travis_info["event_type"] == "cron":
        pretext = "🌙  *Nightly Full Regression Suite Execution Report*"
    elif travis_info["event_type"] == "api":
        pretext = "🎯  *Customized API Trigger Build Execution Report*"
    elif travis_info["event_type"] == "pull_request":
        pretext = "🔀 *Pull Request Full Regression Execution Report*"
    elif travis_info["event_type"] == "push":
        pretext = "🚀  *Manual PR Merge to Main Branch Full Regression Execution Report*"
    elif travis_info["event_type"] == "N/A":
        pretext = "💻 *Local Regression Execution Report*"
    else:
        pretext = "🚀  *Robot Framework E2E Automated Tests Execution Report*"

    # Create formatted build ID with all required parameters
    formatted_build_id = format_build_id_field(
        travis_info["build_number"], travis_info["commit"], travis_info["repo_slug"], branch_name, author, build_url
    )

    # Only use commit_url for GitHub Link
    github_commit_link = commit_url if commit_url else "N/A"

    # Set color for Slack message
    color = "#36a64f" if build_result == "Passed" else "#FF0000"  # Green for pass, Red for fail

    # Create attachment for Slack message
    attachment = {
        "color": color,
        "pretext": pretext,
        "fields": [
            {
                "title": "--------Build Information------",
                "value": (
                    f"*• Build ID:* {formatted_build_id}\n"
                    f"*• Travis_Event_Type:* `{travis_info['event_type']}`\n"
                    f"*• GitHub Commit Link:* {github_commit_link}\n"
                    f"*• Commit:* `{travis_info['commit_message']}`\n"
                    f"*• Travis Job Started By:* `{author}`\n"
                    f"*• Robot Command:* `{robot_command}`\n"
                ),
                "short": False,
            },
            {"title": "******Test Results******", "value": "```{table}```".format(table=table), "short": False},
        ],
        "footer": "Travis CI Build Report",
        "footer_icon": "https://travis-ci.com/images/logos/TravisCI-Mascot-1.png",
    }

    # Construct final payload
    payload = {
        "attachments": [attachment],
        "text": f"Test Pass Rate: {'%.2f' % pass_percentage}% | Fail Rate: {'%.2f' % fail_percentage}% | known issues Percent: {'%.2f' % knownissues_percentage}%",  # noqa
    }

    # ---------- SEND NOTIFICATION ----------
    response = requests.post(SLACK_WEBHOOK_URL, json=payload)
    if response.status_code != 200:
        raise ValueError(f"Request to Slack returned an error {response.status_code}, the response is:\n{response.text}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script_name.py path/to/output.xml")
        sys.exit(1)

    xml_path = sys.argv[1]
    table, pass_percentage, fail_percentage, knownissues_percentage, formatted_time, wall_clock_time, cumulative_time = get_test_statistics(xml_path)

    print("Test Statistics:")
    print(table)
    if wall_clock_time:
        print(f"Elapsed Time (Actual): {formatted_time}")
        print(f"Note: Cumulative execution time was {cumulative_time}")
    else:
        print(f"Elapsed Time: {formatted_time}")

    try:
        send_slack_notification(table, pass_percentage, fail_percentage, knownissues_percentage, formatted_time)
        print("Slack notification sent successfully.")
    except Exception as e:
        print(f"Failed to send Slack notification: {str(e)}")
