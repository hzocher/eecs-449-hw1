import datetime;
import from jaclang.runtime.runtime { JacRuntime }

node Profile {
    has username: str;
}

node Task {
    has title: str,
        course: str = "Personal",
        due: str = "",
        priority: str = "medium",
        notes: str = "",
        minutes: int = 30,
        completed: bool = False,
        created: str = "";
}

obj TaskView {
    has id: str,
        title: str,
        course: str,
        due: str,
        priority: str,
        notes: str,
        minutes: int,
        completed: bool;
}

obj Dashboard {
    has tasks: list[TaskView] = [],
        viewer: str = "",
        open_count: int = 0,
        done_count: int = 0,
        focus_minutes: int = 0;
}

def me -> Profile {
    profiles = [root-->[?:Profile]];
    if jid(root) == jid(root.shared) or not profiles {
        raise ValueError("Please sign in first.");
    }
    return profiles[0];
}

def:pub join(username: str) -> str {
    manager = JacRuntime.get_user_manager(JacRuntime.get_base_path_dir() or ".");
    user = manager.find_user_by_identity(username.strip());
    if not user or manager.get_root_id(str(user["user_id"])) != jid(root) {
        raise ValueError("This username does not belong to your signed-in account.");
    }
    name = manager.get_username(str(user["user_id"])) or username.strip();
    profiles = [root-->[?:Profile]];
    if not profiles {
        root ++> Profile(username=name);
    } else {
        profiles[0].username = name;
    }
    return name;
}

def:pub add_task(
    title: str,
    course: str = "Personal",
    due: str = "",
    priority: str = "medium",
    notes: str = "",
    minutes: int = 30
) -> str {
    me();
    clean_title = title.strip();
    clean_priority = priority.lower().strip();
    if not clean_title or len(clean_title) > 120 {
        raise ValueError("Task titles must be between 1 and 120 characters.");
    }
    if clean_priority not in ["low", "medium", "high"] {
        raise ValueError("Priority must be low, medium, or high.");
    }
    if minutes < 5 or minutes > 1440 {
        raise ValueError("Estimated time must be between 5 and 1440 minutes.");
    }
    if due {
        try {
            datetime.datetime.fromisoformat(due);
        } except ValueError {
            raise ValueError("Due date and time must use ISO format (YYYY-MM-DDTHH:MM:SS).");
        }
    }
    task = root ++> Task(
        title=clean_title,
        course=course.strip() or "Personal",
        due=due,
        priority=clean_priority,
        notes=notes.strip(),
        minutes=minutes,
        created=datetime.datetime.now(datetime.UTC).isoformat()
    );
    return jid(task);
}

def:pub set_complete(task_id: str, completed: bool = True) -> bool {
    me();
    for task in [root-->[?:Task]] {
        if jid(task) == task_id {
            task.completed = completed;
            return task.completed;
        }
    }
    raise ValueError("Task not found.");
}

def:pub remove_task(task_id: str) -> bool {
    me();
    for task in [root-->[?:Task]] {
        if jid(task) == task_id {
            del task;
            return True;
        }
    }
    raise ValueError("Task not found.");
}

def:pub load_dashboard -> Dashboard {
    profiles = [root-->[?:Profile]];
    tasks = [root-->[?:Task]];
    tasks.sort(
        key=lambda (t: Task) {
            (t.completed, t.due or "9999-12-31", {"high": 0, "medium": 1, "low": 2}[t.priority], t.created);
        }
    );
    views = [
        TaskView(
            id=jid(t), title=t.title, course=t.course, due=t.due,
            priority=t.priority, notes=t.notes, minutes=t.minutes,
            completed=t.completed
        ) for t in tasks
    ];
    return Dashboard(
        tasks=views,
        viewer=profiles[0].username if profiles else "",
        open_count=sum(1 for t in tasks if not t.completed),
        done_count=sum(1 for t in tasks if t.completed),
        focus_minutes=sum(t.minutes for t in tasks if not t.completed)
    );
}
