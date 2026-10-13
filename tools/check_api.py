"""
Read-only API contract check for the mobile app.

Logs in, calls the endpoints the app uses (GET, or POST list/read calls only - nothing is
created or changed) and prints just the SHAPE of each response: field names and types,
never values. Safe to paste the output into a chat.

Usage (credentials come from the environment so they are not stored in this file):

    set HRMS_BASE=https://vesoftsol.com
    set HRMS_USER=you@example.com
    set HRMS_PASS=your-password
    python mobile/tools/check_api.py

Or in a bash shell:

    HRMS_BASE=https://vesoftsol.com HRMS_USER=... HRMS_PASS=... python mobile/tools/check_api.py
"""
import json
import os
import sys
import urllib.error
import urllib.request

BASE = os.environ.get("HRMS_BASE", "https://vesoftsol.com").rstrip("/")
USER = os.environ.get("HRMS_USER")
PASS = os.environ.get("HRMS_PASS")


def shape(v, depth=0):
    """Describe structure only: keys and types, plus list length. No values."""
    if depth > 3:
        return "..."
    if isinstance(v, dict):
        return {k: shape(x, depth + 1) for k, x in v.items()}
    if isinstance(v, list):
        return {"list[%d]" % len(v): shape(v[0], depth + 1) if v else "empty"}
    if v is None:
        return "null"
    return type(v).__name__


def call(method, path, token=None, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=25) as r:
            raw = r.read()
            code = r.status
    except urllib.error.HTTPError as e:
        raw, code = e.read(), e.code
    except Exception as e:  # network problems
        return None, "ERR %s" % type(e).__name__
    try:
        return json.loads(raw) if raw else None, code
    except ValueError:
        return "<non-json %d bytes>" % len(raw), code


def main():
    if not USER or not PASS:
        sys.exit("Set HRMS_USER and HRMS_PASS (and optionally HRMS_BASE).")

    body, code = call("POST", "/api/v1/authorize", body={"userName": USER, "password": PASS})
    if code != 200 or not isinstance(body, dict) or not body.get("token"):
        print("LOGIN FAILED:", code, shape(body) if isinstance(body, dict) else body)
        return
    token = body["token"]
    print("LOGIN OK; response fields:", json.dumps(shape({k: v for k, v in body.items() if k != "token"})))

    page = {"pageModel": {"startIndex": 0, "pageSize": 3}}
    checks = [
        ("GET", "/api/v1/profile", None),
        ("GET", "/api/v1/org/localization", None),
        ("GET", "/api/v1/dashboard/layout", None),
        ("GET", "/api/v1/dashboard/catalog", None),
        ("GET", "/api/v1/counts/approvals-inbox", None),
        ("POST", "/api/v1/counts", {"type": "employees"}),
        ("POST", "/api/v1/counts/charts", {"chartType": "headcounttrend"}),
        ("POST", "/api/v1/counts/people", {}),
        ("GET", "/api/v1/todo/dashboard", None),
        ("GET", "/api/v1/profile/holidays", None),
        ("GET", "/api/v1/leave/myleaveinfo", None),
        ("POST", "/api/v1/leave/me", page),
        ("GET", "/api/v1/admin/GetParentOptions/leavetypes", None),
        ("GET", "/api/v1/admin/GetParentOptions/daystype", None),
        ("GET", "/api/v1/notifications/unread-count", None),
        ("POST", "/api/v1/notifications/list", {"onlyUnread": False, **page}),
        ("GET", "/api/v1/attendence/getlatestwebcheckin", None),
        ("POST", "/api/v1/attendence/getdetailAttendence", {}),
        ("POST", "/api/v1/payslip/getall", {"year": 0, **page}),
        ("POST", "/api/v1/timesheet/getall", {"scope": "own", **page}),
        ("POST", "/api/v1/feed/getall", page),
        ("POST", "/api/v1/recognition/record/getall", {"myRecognitions": False, **page}),
        ("POST", "/api/v1/recognition/record/leaderboard", {}),
        ("POST", "/api/v1/asset/my-assets", page),
        ("GET", "/api/v1/learning/my-enrollments", None),
        ("GET", "/api/v1/learning/catalog", None),
        ("GET", "/api/v1/pulse-survey/my-surveys", None),
        ("POST", "/api/v1/performance/goal/getall", page),
        ("POST", "/api/v1/performance/review/my", {}),
        ("POST", "/api/v1/performance/feedback/received", page),
        ("POST", "/api/v1/emploan/my-loans", page),
        ("POST", "/api/v1/empsaldetail/GetMySalaryDetails", page),
        ("POST", "/api/v1/ticket/getAll", page),
        ("POST", "/api/v1/wfh-requests/list", {"scope": "own", **page}),
        ("POST", "/api/v1/attendance-regularize/list", page),
        ("POST", "/api/v1/leave/approvals", {}),
        ("POST", "/api/v1/late-comers/list", {"scope": "all", "statusTypeId": 1, **page}),
        ("POST", "/api/v1/resignation/getall", page),
        ("POST", "/api/v1/leave/GetAll", page),
        ("GET", "/api/v1/counts/analytics-summary", None),
    ]

    print()
    for method, path, payload in checks:
        data, status = call(method, path, token, payload)
        print("%-4s %-55s -> %s" % (method, path, status))
        if status == 200 and data is not None:
            print("      ", json.dumps(shape(data))[:700])
        elif status != 200:
            print("       (not 200; the app would show an error or 'no access' for this)")


if __name__ == "__main__":
    main()
