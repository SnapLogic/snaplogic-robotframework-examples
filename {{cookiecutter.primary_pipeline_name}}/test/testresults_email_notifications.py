import glob
import os
import smtplib
import subprocess
import sys
from datetime import datetime
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from robot.api import ExecutionResult


def find_latest_output_xml():
    """
    Find the latest output.xml file in common Robot Framework output directories.
    Searches in order: robot_output/, output/, results/, current directory.
    Returns the most recently modified output.xml file.
    """
    # Common directories where Robot Framework outputs are stored
    search_patterns = [
        "robot_output/output.xml",
        "robot_output/**/output.xml",
        "output/output.xml",
        "output/**/output.xml",
        "results/output.xml",
        "results/**/output.xml",
        "output.xml",
        "**/output.xml",
    ]

    all_files = []
    for pattern in search_patterns:
        files = glob.glob(pattern, recursive=True)
        all_files.extend(files)

    if not all_files:
        return None

    # Remove duplicates and get the most recent file
    unique_files = list(set(all_files))
    latest_file = max(unique_files, key=os.path.getmtime)

    return latest_file

# Email configuration from environment variables
SMTP_SERVER = os.getenv("SMTP_SERVER", "smtp.snaplogic.com")  # Default: SnapLogic internal SMTP relay
SMTP_PORT = int(os.getenv("SMTP_PORT", "25"))  # Default port 25 for internal relay (no TLS)
SMTP_USE_TLS = os.getenv("SMTP_USE_TLS", "false").lower() in ("true", "1", "yes")  # TLS disabled by default
SMTP_USERNAME = os.getenv("SMTP_USERNAME")  # Optional - only needed if server requires auth
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")  # Optional - only needed if server requires auth
EMAIL_RECIPIENTS = os.getenv("EMAIL_RECIPIENTS", "spothana@snaplogic.com").split(",")  # Comma-separated list
EMAIL_SENDER = os.getenv("EMAIL_SENDER", "robot-tests-automation@snaplogic.com")  # Default sender

# Print configuration status
if SMTP_SERVER:
    print(f"SMTP Server: {SMTP_SERVER}:{SMTP_PORT}")
    print(f"TLS Enabled: {SMTP_USE_TLS}")
    print(f"Authentication: {'Enabled' if SMTP_USERNAME else 'Disabled (internal relay mode)'}")
else:
    print("WARNING: SMTP_SERVER not configured")

if EMAIL_SENDER:
    print(f"Sender: {EMAIL_SENDER}")
else:
    print("WARNING: EMAIL_SENDER not configured")

if EMAIL_RECIPIENTS and EMAIL_RECIPIENTS[0]:
    print(f"Recipients configured: {len(EMAIL_RECIPIENTS)} recipient(s)")
else:
    print("WARNING: EMAIL_RECIPIENTS not configured")


def get_travis_test_result():
    """Fetches the correct Travis CI test result, ensuring it is properly converted."""
    result = os.environ.get("TRAVIS_TEST_RESULT", "-1")
    try:
        return int(result)
    except ValueError:
        return -1


def get_author_name():
    """Get the author name from Travis environment variables or a default value."""
    travis_author = os.environ.get("TRAVIS_COMMIT_AUTHOR_NAME", "")
    if travis_author and travis_author.strip():
        return travis_author.strip()

    travis_email = os.environ.get("TRAVIS_COMMIT_AUTHOR_EMAIL", "")
    if travis_email and "@" in travis_email:
        return travis_email.split("@")[0]

    try:
        author = subprocess.check_output(
            ["git", "log", "-1", "--pretty=format:%an"], stderr=subprocess.DEVNULL
        ).decode("utf-8").strip()
        if author:
            return author
    except Exception:
        pass

    return "CI Build"


def get_robot_command():
    """Get the robot command from travis.yml"""
    try:
        travis_path = '/app/.travis.yml'
        if os.path.exists(travis_path):
            with open(travis_path, 'r') as f:
                for line in f:
                    if 'make robot-run-all-tests' in line and 'TAGS=' in line:
                        command = line.strip().lstrip('-').strip()
                        return command
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
                for line in lines:
                    if line.startswith('Total Wall Clock Time:'):
                        return line.split(':', 1)[1].strip()
    except Exception as e:
        print(f"Could not read wall clock time: {e}")
    return None


def get_test_statistics(xml_path):
    """Parse Robot Framework output.xml and extract test statistics."""
    result = ExecutionResult(xml_path)
    stats = result.statistics

    total_tests = stats.total.total
    passed = stats.total.passed
    failed = stats.total.failed
    skipped = stats.total.skipped

    elapsed_milliseconds = int(result.suite.elapsedtime)
    minutes = elapsed_milliseconds // 60000
    seconds = (elapsed_milliseconds % 60000) // 1000
    ms = elapsed_milliseconds % 1000
    cumulative_time = f"{minutes}m {seconds}s {ms}ms"

    wall_clock_time = get_wall_clock_time()
    formatted_time = wall_clock_time if wall_clock_time else cumulative_time

    pass_percentage = (passed / total_tests) * 100 if total_tests > 0 else 0
    fail_percentage = (failed / total_tests) * 100 if total_tests > 0 else 0
    skip_percentage = (skipped / total_tests) * 100 if total_tests > 0 else 0

    return {
        "total": total_tests,
        "passed": passed,
        "failed": failed,
        "skipped": skipped,
        "pass_percentage": pass_percentage,
        "fail_percentage": fail_percentage,
        "skip_percentage": skip_percentage,
        "elapsed_time": formatted_time,
        "cumulative_time": cumulative_time,
        "result": result
    }


def get_failed_tests(result):
    """Extract failed test names and messages from all suites."""
    failed_tests = []

    def extract_from_suite(suite):
        for test in suite.tests:
            if test.status == "FAIL":
                failed_tests.append({
                    "name": test.name,
                    "message": test.message,
                    "suite": suite.name
                })
        for child_suite in suite.suites:
            extract_from_suite(child_suite)

    extract_from_suite(result.suite)
    return failed_tests


def get_build_info():
    """Collect Travis CI and build information."""
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

    # Determine branch name
    if travis_info["pull_request"] != "false":
        branch_name = f"{travis_info['pull_request_branch']} #PR-{travis_info['pull_request']}"
    else:
        branch_name = travis_info["branch"]

    travis_info["branch_name"] = branch_name
    travis_info["author"] = get_author_name()
    travis_info["robot_command"] = get_robot_command()

    # Build URLs
    if travis_info["repo_slug"] != "N/A" and travis_info["build_id"] != "N/A":
        travis_info["build_url"] = f"https://travis-ci.com/github/{travis_info['repo_slug']}/builds/{travis_info['build_id']}"
    else:
        travis_info["build_url"] = "N/A"

    if travis_info["repo_slug"] != "N/A" and travis_info["commit"] != "N/A":
        travis_info["commit_url"] = f"https://github.com/{travis_info['repo_slug']}/commit/{travis_info['commit']}"
    else:
        travis_info["commit_url"] = "N/A"

    return travis_info


def get_event_type_description(event_type):
    """Get human-readable description for Travis event type."""
    descriptions = {
        "cron": "Nightly Full Regression Suite Execution",
        "api": "Customized API Trigger Build Execution",
        "pull_request": "Pull Request Full Regression Execution",
        "push": "Manual PR Merge to Main Branch Full Regression Execution",
        "N/A": "Local Regression Execution"
    }
    return descriptions.get(event_type, "Robot Framework E2E Automated Tests Execution")


def build_email_body_html(stats, failed_tests, build_info):
    """Build HTML email body with test results and build information."""
    status_color = "#36a64f" if stats["failed"] == 0 else "#dc3545"
    status_text = "PASSED" if stats["failed"] == 0 else "FAILED"
    status_emoji = "✅" if stats["failed"] == 0 else "❌"

    event_description = get_event_type_description(build_info["event_type"])

    html = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <style>
            body {{ font-family: Arial, sans-serif; line-height: 1.6; color: #333; }}
            .header {{ background-color: {status_color}; color: white; padding: 20px; text-align: center; }}
            .content {{ padding: 20px; }}
            table {{ border-collapse: collapse; width: 100%; margin: 15px 0; }}
            th, td {{ border: 1px solid #ddd; padding: 10px; text-align: left; }}
            th {{ background-color: #f5f5f5; }}
            .passed {{ background-color: #d4edda; }}
            .failed {{ background-color: #f8d7da; }}
            .skipped {{ background-color: #fff3cd; }}
            .section-title {{ color: #333; border-bottom: 2px solid {status_color}; padding-bottom: 5px; margin-top: 20px; }}
            .build-info {{ background-color: #f8f9fa; padding: 15px; border-radius: 5px; }}
            .error-message {{ background-color: #f8f9fa; padding: 10px; font-family: monospace; font-size: 12px; white-space: pre-wrap; word-wrap: break-word; max-height: 200px; overflow-y: auto; }}
            a {{ color: #007bff; }}
            .footer {{ margin-top: 30px; padding-top: 15px; border-top: 1px solid #ddd; font-size: 12px; color: #666; }}
        </style>
    </head>
    <body>
        <div class="header">
            <h1>{status_emoji} Robot Framework Tests {status_text}</h1>
            <p>{event_description}</p>
        </div>

        <div class="content">
            <h2 class="section-title">📊 Test Summary</h2>
            <table>
                <tr>
                    <th>Metric</th>
                    <th>Count</th>
                    <th>Percentage</th>
                </tr>
                <tr class="passed">
                    <td>✅ Passed</td>
                    <td>{stats['passed']}</td>
                    <td>{stats['pass_percentage']:.2f}%</td>
                </tr>
                <tr class="failed">
                    <td>❌ Failed</td>
                    <td>{stats['failed']}</td>
                    <td>{stats['fail_percentage']:.2f}%</td>
                </tr>
                <tr class="skipped">
                    <td>⏭️ Skipped</td>
                    <td>{stats['skipped']}</td>
                    <td>{stats['skip_percentage']:.2f}%</td>
                </tr>
                <tr>
                    <td><strong>Total Tests</strong></td>
                    <td><strong>{stats['total']}</strong></td>
                    <td>100.00%</td>
                </tr>
                <tr>
                    <td>⏱️ Elapsed Time</td>
                    <td colspan="2">{stats['elapsed_time']}</td>
                </tr>
            </table>
    """

    # Add failed tests section if there are failures
    if failed_tests:
        html += """
            <h2 class="section-title">❌ Failed Tests Details</h2>
            <table>
                <tr>
                    <th style="width: 25%;">Test Name</th>
                    <th style="width: 20%;">Suite</th>
                    <th style="width: 55%;">Error Message</th>
                </tr>
        """
        for test in failed_tests:
            # Truncate error message if too long
            error_msg = test['message']
            if len(error_msg) > 500:
                error_msg = error_msg[:500] + "..."
            # Escape HTML characters
            error_msg = error_msg.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")

            html += f"""
                <tr>
                    <td><strong>{test['name']}</strong></td>
                    <td>{test['suite']}</td>
                    <td><div class="error-message">{error_msg}</div></td>
                </tr>
            """
        html += "</table>"

    # Add build information section
    html += f"""
            <h2 class="section-title">🔧 Build Information</h2>
            <div class="build-info">
                <table>
                    <tr><td><strong>Build Number</strong></td><td>#{build_info['build_number']}</td></tr>
                    <tr><td><strong>Branch</strong></td><td>{build_info['branch_name']}</td></tr>
                    <tr><td><strong>Repository</strong></td><td>{build_info['repo_slug']}</td></tr>
                    <tr><td><strong>Event Type</strong></td><td>{build_info['event_type']}</td></tr>
                    <tr><td><strong>Commit</strong></td><td>{build_info['commit'][:7] if build_info['commit'] != 'N/A' else 'N/A'}</td></tr>
                    <tr><td><strong>Commit Message</strong></td><td>{build_info['commit_message']}</td></tr>
                    <tr><td><strong>Author</strong></td><td>{build_info['author']}</td></tr>
                    <tr><td><strong>Robot Command</strong></td><td><code>{build_info['robot_command']}</code></td></tr>
    """

    if build_info["build_url"] != "N/A":
        html += f"""
                    <tr><td><strong>Travis Build</strong></td><td><a href="{build_info['build_url']}">View Build</a></td></tr>
        """

    if build_info["commit_url"] != "N/A":
        html += f"""
                    <tr><td><strong>GitHub Commit</strong></td><td><a href="{build_info['commit_url']}">View Commit</a></td></tr>
        """

    html += f"""
                </table>
            </div>

            <div class="footer">
                <p>This email was automatically generated by Robot Framework Test Results Notifier.</p>
                <p>Generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
            </div>
        </div>
    </body>
    </html>
    """

    return html


def build_email_body_plain(stats, failed_tests, build_info):
    """Build plain text email body as fallback."""
    status_text = "PASSED" if stats["failed"] == 0 else "FAILED"
    event_description = get_event_type_description(build_info["event_type"])

    text = f"""
Robot Framework Tests {status_text}
{event_description}
{'=' * 50}

TEST SUMMARY
------------
Passed:  {stats['passed']} ({stats['pass_percentage']:.2f}%)
Failed:  {stats['failed']} ({stats['fail_percentage']:.2f}%)
Skipped: {stats['skipped']} ({stats['skip_percentage']:.2f}%)
Total:   {stats['total']}
Elapsed Time: {stats['elapsed_time']}
"""

    if failed_tests:
        text += f"""
FAILED TESTS
------------
"""
        for test in failed_tests:
            text += f"""
Test: {test['name']}
Suite: {test['suite']}
Error: {test['message'][:300]}
---
"""

    text += f"""
BUILD INFORMATION
-----------------
Build Number: #{build_info['build_number']}
Branch: {build_info['branch_name']}
Repository: {build_info['repo_slug']}
Event Type: {build_info['event_type']}
Commit: {build_info['commit'][:7] if build_info['commit'] != 'N/A' else 'N/A'}
Author: {build_info['author']}

Travis Build: {build_info['build_url']}
GitHub Commit: {build_info['commit_url']}

---
Generated at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

    return text


def send_email_notification(xml_path, send_on_failure_only=True):
    """
    Send email notification based on Robot Framework test results.

    Supports two modes:
    1. Internal SMTP Relay (no authentication) - Default
       Just set SMTP_SERVER and EMAIL_RECIPIENTS
    2. Authenticated SMTP (Gmail, etc.)
       Set SMTP_USERNAME, SMTP_PASSWORD, and SMTP_USE_TLS=true

    Args:
        xml_path: Path to Robot Framework output.xml file
        send_on_failure_only: If True, only send email when tests fail (default: True)
    """
    # Validate configuration
    if not SMTP_SERVER:
        print("ERROR: SMTP_SERVER must be configured")
        print("       Set the SMTP_SERVER environment variable (e.g., smtp.yourcompany.com)")
        return False

    if not EMAIL_SENDER:
        print("ERROR: EMAIL_SENDER must be configured")
        print("       Set the EMAIL_SENDER environment variable (e.g., robot-tests@yourcompany.com)")
        return False

    if not EMAIL_RECIPIENTS or not EMAIL_RECIPIENTS[0]:
        print("ERROR: EMAIL_RECIPIENTS must be configured")
        print("       Set the EMAIL_RECIPIENTS environment variable (e.g., team@yourcompany.com)")
        return False

    # Parse test results
    print(f"Parsing test results from: {xml_path}")
    stats = get_test_statistics(xml_path)
    failed_tests = get_failed_tests(stats["result"])
    build_info = get_build_info()

    # Check if we should send (based on send_on_failure_only flag)
    if send_on_failure_only and stats["failed"] == 0:
        print("All tests passed. Skipping email notification (send_on_failure_only=True)")
        return True

    # Build email
    status = "FAILED" if stats["failed"] > 0 else "PASSED"
    subject = f"[Robot Tests {status}] {stats['passed']}/{stats['total']} passed - {build_info['branch_name']}"

    msg = MIMEMultipart("alternative")
    msg["Subject"] = subject
    msg["From"] = EMAIL_SENDER
    msg["To"] = ", ".join(EMAIL_RECIPIENTS)

    # Attach both plain text and HTML versions
    plain_body = build_email_body_plain(stats, failed_tests, build_info)
    html_body = build_email_body_html(stats, failed_tests, build_info)

    msg.attach(MIMEText(plain_body, "plain"))
    msg.attach(MIMEText(html_body, "html"))

    # Send email
    try:
        print(f"Connecting to SMTP server: {SMTP_SERVER}:{SMTP_PORT}")
        with smtplib.SMTP(SMTP_SERVER, SMTP_PORT) as server:
            # Only use TLS if explicitly enabled (for Gmail, etc.)
            if SMTP_USE_TLS:
                print("Starting TLS...")
                server.starttls()

            # Only authenticate if credentials are provided
            if SMTP_USERNAME and SMTP_PASSWORD:
                print("Authenticating...")
                server.login(SMTP_USERNAME, SMTP_PASSWORD)
            else:
                print("Using internal relay mode (no authentication)")

            server.send_message(msg)
        print(f"Email notification sent successfully to: {', '.join(EMAIL_RECIPIENTS)}")
        return True
    except smtplib.SMTPAuthenticationError as e:
        print(f"SMTP Authentication failed. Check your username/password: {e}")
        raise
    except smtplib.SMTPException as e:
        print(f"SMTP error occurred: {e}")
        raise
    except Exception as e:
        print(f"Failed to send email: {e}")
        raise


if __name__ == "__main__":
    # Check for --help flag
    if "--help" in sys.argv or "-h" in sys.argv:
        print("Usage: python testresults_email_notifications.py [path/to/output.xml] [--always]")
        print("")
        print("If no path is provided, the script will automatically find the latest output.xml file.")
        print("")
        print("Options:")
        print("  --always    Send email even when all tests pass (default: only on failure)")
        print("  --help, -h  Show this help message")
        print("")
        print("Environment variables:")
        print("")
        print("  For SnapLogic Internal Relay (default - no password needed):")
        print("    SMTP_SERVER      - SMTP server address (default: smtp.snaplogic.com)")
        print("    SMTP_PORT        - SMTP server port (default: 25)")
        print("    EMAIL_SENDER     - Sender email address (default: robot-tests-automation@snaplogic.com)")
        print("    EMAIL_RECIPIENTS - Comma-separated list of recipient emails (default: spothana@snaplogic.com)")
        print("")
        print("  For Gmail (with authentication):")
        print("    SMTP_SERVER      - smtp.gmail.com")
        print("    SMTP_PORT        - 587")
        print("    SMTP_USE_TLS     - true")
        print("    SMTP_USERNAME    - your-email@gmail.com")
        print("    SMTP_PASSWORD    - your-app-password (NOT regular password)")
        print("    EMAIL_SENDER     - your-email@gmail.com")
        print("")
        print("Examples:")
        print("  # Auto-find latest output.xml:")
        print("  python testresults_email_notifications.py --always")
        print("")
        print("  # Specify output.xml path:")
        print("  python testresults_email_notifications.py robot_output/output.xml --always")
        sys.exit(0)

    # Parse arguments
    send_always = "--always" in sys.argv

    # Get xml_path from arguments or auto-discover
    non_flag_args = [arg for arg in sys.argv[1:] if not arg.startswith("--")]

    if non_flag_args:
        xml_path = non_flag_args[0]
        print(f"Using specified output file: {xml_path}")
    else:
        # Auto-discover the latest output.xml
        print("No output.xml path provided. Searching for latest output.xml...")
        xml_path = find_latest_output_xml()
        if xml_path:
            print(f"Found latest output.xml: {xml_path}")
        else:
            print("ERROR: No output.xml file found!")
            print("       Run your Robot Framework tests first, or specify the path manually.")
            print("       Usage: python testresults_email_notifications.py path/to/output.xml [--always]")
            sys.exit(1)

    # Print test statistics
    stats = get_test_statistics(xml_path)
    print("\nTest Statistics:")
    print(f"  Total:   {stats['total']}")
    print(f"  Passed:  {stats['passed']} ({stats['pass_percentage']:.2f}%)")
    print(f"  Failed:  {stats['failed']} ({stats['fail_percentage']:.2f}%)")
    print(f"  Skipped: {stats['skipped']} ({stats['skip_percentage']:.2f}%)")
    print(f"  Time:    {stats['elapsed_time']}")
    print("")

    try:
        success = send_email_notification(xml_path, send_on_failure_only=not send_always)
        if success:
            print("Email notification process completed successfully.")
        sys.exit(0)
    except Exception as e:
        print(f"Email notification failed: {str(e)}")
        sys.exit(1)
