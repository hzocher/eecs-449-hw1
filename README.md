# HenryPlans

> Student name: Henry Zocher  
> UMID: 41910206

HenryPlans is a personal coursework planner built entirely with Jac. It keeps assignments and study sessions in one private, persistent plan and makes that plan available from a responsive web app, a native mobile app, and a CLI.

## Features

- Private accounts with persistent coursework data
- Assignment title, course, due date and time, priority, notes, and study-time estimate
- Deadline-first task ordering with high-priority items surfaced first
- Complete, reopen, and delete workflows
- A semester snapshot with open/completed counts and remaining focus minutes
- One shared backend for the web, mobile, desktop, and CLI clients
- Responsive UI that works as a browser app and native React Native interface

## Prerequisites

- Jac `0.37.23` (the version pinned in `jac.toml`)
- An internet connection for the first `jac install`
- For native Android: an emulator/device; Jac provisions the required JDK and Android SDK
- For native iOS: macOS and Xcode

## Setup and web server

From a fresh checkout, run:

```bash
jac install
jac run
```

The second command starts the default web application and its colocated planner service. Open the URL printed by Jac (normally <http://localhost:8000>), create an account, and add coursework. Data persists between sessions in Jac's project database.

For hot reload during development:

```bash
jac run --dev
```

## CLI

Keep the web/server process running, then use a second terminal:

```bash
jac run cli -- login your_username
jac run cli -- add "Finish project report" --course "EECS 449" --due 2026-10-12 --time 17:30 --priority high --minutes 120 --notes "Draft evaluation section first"
jac run cli -- list
jac run cli -- today
jac run cli -- stats
jac run cli -- done TASK_ID
jac run cli -- reopen TASK_ID
jac run cli -- delete TASK_ID
jac run cli -- logout
```

`list` prints task IDs needed by `done`, `reopen`, and `delete`. The CLI saves its authentication token with owner-only permissions in `~/.henryplans.json`. Override the backend with `HENRYPLANS_URL` or `--url`, and the session path with `HENRYPLANS_SESSION`.

## Mobile app

Start the web server first. For a fast browser preview of the mobile UI:

```bash
jac run --dev --platform web mobile
```

For native mobile development:

```bash
jac run --dev mobile
```

On the mobile connection screen, use your computer's LAN URL. An Android emulator can normally reach the host server at `http://10.0.2.2:8000`; a physical phone needs `http://YOUR_COMPUTER_LAN_IP:8000`. Production Android builds should use an HTTPS backend.

Build installable artifacts with:

```bash
jac build --platform android mobile
jac build --platform ios mobile   # macOS/Xcode required
```

## Architecture

- `core/planner.jac` is the service and graph data model. Each signed-in root owns its `Profile` and `Task` nodes, giving every user an isolated persistent plan.
- `core/ui.jac` is a shared mobUI interface used by both `web.jac` and `mobile.jac`.
- `web.jac` is the default browser frontend and hosts the colocated service when `jac run` starts.
- `mobile.jac` is a frontend-only React Native client that connects to the same planner service over Jac's generated bridge.
- `cli.jac` calls the same typed service functions, so terminal changes immediately appear on web and mobile.

The most useful detail is that this is not four unrelated demos: all clients share the exact task model, authentication system, validation rules, persistence, and completion state. The deadline/priority ordering and focus-minute summary turn a basic checklist into a small semester-planning dashboard.

## Validate

```bash
jac check
JAC_TEST_JOBS=0 jac test
jac build web
jac build --platform web mobile
```

The service test verifies authentication, task validation, private per-user storage, focus-time totals, completion, and deletion. Before submission, replace the name and UMID placeholders above and run these commands from a fresh checkout.
