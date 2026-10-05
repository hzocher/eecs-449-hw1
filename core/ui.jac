import from "@jac/mobui" {
    View, Text, TextInput, Pressable, ScrollView, useWindowDimensions
}
import from "@jac/runtime" {
    jacSetToken, __getApiBaseUrl, jacLogout, jacIsLoggedIn,
    __getLocalStorage, __setLocalStorage
}
import from core.planner { Dashboard, join, add_task, set_complete, remove_task, load_dashboard }
import from core.theme { S }

def Button(label: str, action: Callable, quiet: bool = False, disabled: bool = False) -> JsxElement {
    return <Pressable accessibilityRole="button" accessibilityLabel={label} disabled={disabled}
        onPress={action} style={[S.button, S.quiet if quiet else {}, {"opacity": 0.45 if disabled else 1}]}>
        <Text style={[S.buttonText, S.quietText if quiet else {}]}>{label}</Text>
    </Pressable>;
}

def:pub PlannerApp(remote: bool = False) -> JsxElement {
    has dashboard: Dashboard = Dashboard(), username: str = "", password: str = "",
        title: str = "", course: str = "", due: str = "", priority: str = "medium",
        notes: str = "", minutes: str = "30", signup: bool = False,
        logged: bool = False, busy: bool = False, loading: bool = True,
        error: str = "", server: str = "", connected: bool = not remote;
    wide = useWindowDimensions().width >= 860;

    async def refresh {
        loading = True; error = "";
        try {
            dashboard = await load_dashboard();
            if logged and not dashboard.viewer { jacLogout(); logged = False; }
        } except Exception { error = "Could not load your coursework. Check the server and retry."; }
        finally { loading = False; }
    }

    async def connect {
        if not server.startswith("http://") and not server.startswith("https://") {
            error = "Enter a server address beginning with http:// or https://."; return;
        }
        server = server.rstrip("/"); globalThis.__JAC_API_BASE_URL__ = server;
        __setLocalStorage("courseflow_server", server); jacLogout();
        logged = False; connected = True; error = ""; await refresh();
    }

    can with entry {
        logged = jacIsLoggedIn();
        username = __getLocalStorage("courseflow_username") or "";
        saved_server = __getLocalStorage("courseflow_server") or "http://10.0.2.2:8000";
        should_connect = not remote or bool(__getLocalStorage("courseflow_server"));
        server = saved_server;
        if remote and should_connect {
            globalThis.__JAC_API_BASE_URL__ = saved_server; connected = True;
        }
        if should_connect { refresh(); } else { loading = False; }
    }

    async def authenticate {
        if busy { return; }
        busy = True; error = "";
        try {
            if not username.strip() or not password { error = "Enter a username and password."; return; }
            identity = {"type": "username", "value": username.strip()};
            payload: dict[str, any] = {"credential": {"type": "password", "password": password}};
            if signup { payload["identities"] = [identity]; } else { payload["identity"] = identity; }
            response = await fetch(__getApiBaseUrl() + "/api/planner/user/" + ("register" if signup else "login"),
                {"method": "POST", "headers": {"Content-Type": "application/json"}, "body": JSON.stringify(payload)});
            result: any = await response.json();
            if not response.ok { error = result.error.message or "Could not sign in."; return; }
            jacSetToken(result.data.token); username = await join(username.strip());
            __setLocalStorage("courseflow_username", username); logged = True; password = ""; await refresh();
        } except Exception { error = "Could not sign in. Check your connection and retry."; }
        finally { busy = False; }
    }

    async def create_task {
        if busy { return; }
        busy = True; error = "";
        try {
            await add_task(title, course, due, priority, notes, int(minutes));
            title = ""; notes = ""; due = ""; minutes = "30"; await refresh();
        } except Exception { error = "Check the title, YYYY-MM-DD due date, and time estimate."; }
        finally { busy = False; }
    }

    async def act(kind: str, id: str, done: bool = False) {
        if busy { return; }
        busy = True; error = "";
        try {
            if kind == "complete" { await set_complete(id, not done); }
            elif kind == "delete" { await remove_task(id); }
            await refresh();
        } except Exception { error = "That change did not save. Refresh and retry."; }
        finally { busy = False; }
    }

    async def logout { jacLogout(); logged = False; password = ""; error = ""; await refresh(); }

    return <ScrollView style={S.screen} contentContainerStyle={S.page} keyboardShouldPersistTaps="handled">
        <View style={S.header}><Text style={S.brand}>CourseFlow<Text style={S.accent}>.</Text></Text>
            <Text style={S.eyebrow}>COURSEWORK, UNDER CONTROL</Text></View>
        <View style={S.stack}><Text accessibilityRole="header" style={S.title}>Make the semester feel manageable.</Text>
            <Text style={S.subtitle}>Capture assignments, plan study time, and see what deserves attention next.</Text></View>
        {<Text accessibilityRole="alert" style={S.error}>{error}</Text> if error else None}
        {<View style={S.card}><Text style={S.name}>Connect to your CourseFlow server</Text>
            <TextInput accessibilityLabel="Server address" style={S.input} value={server} autoCapitalize="none"
                onChangeText={lambda (t: str) { server = t; }}/><Button label="Connect" action={connect}/></View>
        if not connected else <View style={[S.layout, {"flexDirection": "row" if wide else "column"}]}>
            <View style={[S.stack, {"flex": 1, "minWidth": 0}]}>
                {<View style={S.card}><Text style={S.eyebrow}>ADD COURSEWORK</Text>
                    <TextInput accessibilityLabel="Assignment title" style={S.input} placeholder="Assignment or study task"
                        value={title} onChangeText={lambda (t: str) { title = t; }}/>
                    <View style={S.row}><TextInput accessibilityLabel="Course" style={[S.input, S.flexInput]}
                        placeholder="Course (e.g. EECS 449)" value={course} onChangeText={lambda (t: str) { course = t; }}/>
                        <TextInput accessibilityLabel="Due date" style={[S.input, S.flexInput]} placeholder="YYYY-MM-DD"
                            value={due} autoCapitalize="none" onChangeText={lambda (t: str) { due = t; }}/></View>
                    <View style={S.row}>{for level in ["low", "medium", "high"] {
                        <Button key={level} label={level.capitalize()} quiet={priority != level}
                            action={lambda { priority = level; }}/>
                    }}</View>
                    <TextInput accessibilityLabel="Estimated minutes" style={S.input} placeholder="Estimated minutes"
                        keyboardType="numeric" value={minutes} onChangeText={lambda (t: str) { minutes = t; }}/>
                    <TextInput accessibilityLabel="Notes" style={[S.input, S.notes]} placeholder="Notes, links, or a first step"
                        multiline={True} value={notes} onChangeText={lambda (t: str) { notes = t; }}/>
                    <Button label={"Saving…" if busy else "Add to plan"} action={create_task}
                        disabled={busy or not title.strip()}/></View> if logged else None}
                <View style={S.between}><Text style={S.eyebrow}>YOUR ASSIGNMENTS</Text>
                    <Button label="Refresh" quiet={True} action={refresh} disabled={loading}/></View>
                {<Text style={S.small}>Loading your plan…</Text> if loading else None}
                {<View style={S.card}><Text style={S.name}>Nothing due yet.</Text>
                    <Text style={S.body}>Add your first assignment or study session above.</Text></View>
                    if logged and not loading and not dashboard.tasks else None}
                {for task in dashboard.tasks { <View key={task.id} style={[S.card, {"opacity": 0.58 if task.completed else 1}]}>
                    <View style={S.between}><View style={[S.badge, S[task.priority]]}>
                        <Text style={S.badgeText}>{task.priority.upper()}</Text></View><Text style={S.small}>{task.minutes} min</Text></View>
                    <Text style={S.taskTitle}>{task.title}</Text><Text style={S.course}>{task.course}</Text>
                    {<Text style={S.body}>{task.notes}</Text> if task.notes else None}
                    <Text style={S.small}>{"Due " + task.due if task.due else "No deadline"}</Text>
                    <View style={S.row}><Button label={"Mark open" if task.completed else "Complete"}
                        action={lambda { act("complete", task.id, task.completed); }} disabled={busy}/>
                        <Button label="Delete" quiet={True} action={lambda { act("delete", task.id); }} disabled={busy}/></View>
                </View> }}
            </View>
            <View style={[S.stack, {"width": 300 if wide else "100%"}]}>
                {<View style={S.card}><Text style={S.eyebrow}>SEMESTER SNAPSHOT</Text>
                    <Text style={S.metric}>{dashboard.open_count}</Text><Text style={S.name}>open items</Text><View style={S.rule}/>
                    <Text style={S.metricSmall}>{dashboard.focus_minutes}</Text><Text style={S.small}>minutes of planned focus</Text>
                    <Text style={S.metricSmall}>{dashboard.done_count}</Text><Text style={S.small}>completed items</Text>
                    <Text style={S.small}>Signed in as {dashboard.viewer}</Text>
                    <Button label="Sign out" quiet={True} action={logout} disabled={busy}/></View> if logged else
                <View style={S.card}><Text style={S.name}>{"Create your planner" if signup else "Welcome back"}</Text>
                    <TextInput accessibilityLabel="Username" style={S.input} placeholder="Username" value={username}
                        autoCapitalize="none" autoCorrect={False} onChangeText={lambda (t: str) { username = t; }}/>
                    <TextInput accessibilityLabel="Password" style={S.input} placeholder="Password" value={password}
                        secureTextEntry={True} onChangeText={lambda (t: str) { password = t; }} onSubmitEditing={authenticate}/>
                    <Button label={"Create account" if signup else "Sign in"} action={authenticate} disabled={busy}/>
                    <Button label={"I already have an account" if signup else "Create an account"} quiet={True}
                        action={lambda { signup = not signup; error = ""; }}/></View>}
                <View style={S.tip}><Text style={S.eyebrow}>FOCUS TIP</Text><Text style={S.body}>
                    Start with the nearest high-priority deadline. A specific 30-minute block beats a vague plan.
                </Text></View>
            </View>
        </View>}
        <View style={S.footer}>{<Button label="Change server" quiet={True} action={lambda {
            jacLogout(); logged = False; connected = False; error = ""; dashboard = Dashboard();
        }}/> if remote and connected else None}<Text style={S.small}>CourseFlow · One plan across web, mobile, and terminal.</Text></View>
    </ScrollView>;
}
