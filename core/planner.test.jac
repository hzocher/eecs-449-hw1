import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtime.runtime { JacRuntime }
import from jaclang.testing.testing { JacTestClient }

def call(client: JacTestClient, name: str, fields: dict[str, any] = {}) -> any {
    response = client.post("/function/" + name, json=fields);
    assert response.ok , response.text;
    return response.data["result"];
}

test "tasks are private, validated, completed, and deleted" {
    with TemporaryDirectory() as folder {
        client = JacTestClient.from_file(
            str(Path(__file__).with_name("planner.jac")), base_path=folder
        );
        try {
            assert not client.post("/function/add_task", json={"title": "Nope"}).ok;
            for name in ["alice", "bob"] {
                assert client.register_user(name, "planner-secret-123").ok;
            }
            assert client.login("alice", "planner-secret-123").ok;
            assert call(client, "join", {"username": "alice"}) == "alice";
            assert not client.post(
                "/function/add_task", json={"title": "", "priority": "urgent"}
            ).ok;
            task_id = call(client, "add_task", {
                "title": "Finish project", "course": "EECS 449",
                "due": "2026-10-10T17:30:00", "priority": "high", "minutes": 90
            });
            dashboard = call(client, "load_dashboard");
            assert dashboard["open_count"] == 1;
            assert dashboard["focus_minutes"] == 90;
            assert dashboard["tasks"][0]["due"] == "2026-10-10T17:30:00";
            assert call(client, "set_complete", {"task_id": task_id, "completed": True}) is True;
            assert call(client, "load_dashboard")["done_count"] == 1;
            assert client.login("bob", "planner-secret-123").ok;
            call(client, "join", {"username": "bob"});
            assert call(client, "load_dashboard")["tasks"] == [];
            assert not client.post(
                "/function/remove_task", json={"task_id": task_id}
            ).ok;
            assert client.login("alice", "planner-secret-123").ok;
            assert call(client, "remove_task", {"task_id": task_id}) is True;
        } finally {
            client.close();
            JacRuntime.set_shared_root_resolver(None);
        }
    }
}
