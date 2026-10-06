import argparse;
import asyncio;
import datetime;
import getpass;
import json;
import os;
import sys;
import urllib.request;
import from pathlib { Path }
import from jaclang.server { sv_client }
import from core.planner { join, add_task, set_complete, remove_task, load_dashboard }

def auth_request(base: str, username: str, password: str) -> str {
    payload = json.dumps({"identity": {"type": "username", "value": username},
        "credential": {"type": "password", "password": password}}).encode();
    request = urllib.request.Request(base + "/user/login", data=payload,
        headers={"Content-Type": "application/json"});
    with urllib.request.urlopen(request, timeout=15) as response {
        return str(json.loads(response.read())["data"]["token"]);
    }
}

async def main -> int {
    parser = argparse.ArgumentParser(description="CourseFlow: coursework planning from your terminal.");
    parser.add_argument("--url", `default=os.environ.get("COURSEFLOW_URL", "http://127.0.0.1:8000"));
    parser.add_argument("command", choices=["login", "logout", "list", "today", "add", "done", "reopen", "delete", "stats"]);
    parser.add_argument("value", nargs="?", `default="");
    parser.add_argument("--course", `default="Personal");
    parser.add_argument("--due", `default="");
    parser.add_argument("--time", `default="23:59");
    parser.add_argument("--priority", choices=["low", "medium", "high"], `default="medium");
    parser.add_argument("--minutes", type=int, `default=30);
    parser.add_argument("--notes", `default="");
    args = parser.parse_args();
    base = str(args.url).rstrip("/");
    credentials = Path(os.environ.get("COURSEFLOW_SESSION", str(Path.home() / ".courseflow.json")));
    os.environ["JAC_APP_PLANNER_URL"] = base + "/api/planner";
    try {
        if args.command == "logout" {
            credentials.unlink(missing_ok=True); print("Signed out."); return 0;
        }
        if args.command == "login" {
            if not args.value { parser.error("login needs a username"); }
            password = os.environ.get("COURSEFLOW_PASSWORD") or getpass.getpass("Password: ");
            token = auth_request(base, str(args.value), password); sv_client.set_bearer_token(token);
            name = await join(str(args.value));
            fd = os.open(str(credentials), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600);
            with os.fdopen(fd, "w") as handle { json.dump({"url": base, "token": token}, handle); }
            credentials.chmod(0o600); print("Signed in as " + name); return 0;
        }
        if credentials.exists() {
            saved = json.loads(credentials.read_text());
            if saved.get("url") == base { sv_client.set_bearer_token(str(saved["token"])); }
        }
        if args.command in ["add", "done", "reopen", "delete"] and not args.value {
            parser.error(args.command + " needs a title or task ID");
        }
        if args.command == "add" {
            deadline = str(args.due) + "T" + str(args.time) + ":00" if args.due else "";
            task_id = await add_task(str(args.value), str(args.course), deadline,
                str(args.priority), str(args.notes), int(args.minutes));
            print("Added " + task_id);
        } elif args.command in ["done", "reopen"] {
            await set_complete(str(args.value), args.command == "done"); print("Updated.");
        } elif args.command == "delete" {
            await remove_task(str(args.value)); print("Deleted.");
        } else {
            dashboard = await load_dashboard();
            if args.command == "stats" {
                print(f"{dashboard.open_count} open · {dashboard.done_count} done · {dashboard.focus_minutes} focus minutes");
            } else {
                today = datetime.date.today().isoformat();
                shown = 0;
                for task in dashboard.tasks {
                    if args.command != "today" or task.due[:10] == today {
                        mark = "✓" if task.completed else "○";
                        deadline = "due " + task.due if task.due else "no deadline";
                        print(f"{mark} {task.id}  [{task.priority.upper()}] {task.course}\n  {task.title} · {deadline} · {task.minutes} min");
                        shown += 1;
                    }
                }
                if shown == 0 { print("No coursework found."); }
            }
        }
        return 0;
    } except Exception as e {
        print("CourseFlow: " + str(e), file=sys.stderr); return 1;
    }
}

with entry:__main__ { sys.`exit(asyncio.run(main())); }
