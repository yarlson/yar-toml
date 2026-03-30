package toml

import "testing"

fn test_parse_string(t *testing.T) void {
    doc := parse("name = \"hello\"") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    val := get_str(doc, "name") or |err| {
        testing.fail(t, "get_str failed")
        return
    }
    testing.equal[str](t, val, "hello")
}

fn test_parse_string_escapes(t *testing.T) void {
    doc := parse("msg = \"line1\\nline2\"") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    val := get_str(doc, "msg") or |err| {
        testing.fail(t, "get_str failed")
        return
    }
    testing.equal[str](t, val, "line1\nline2")
}

fn test_parse_integer(t *testing.T) void {
    doc := parse("port = 8080") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    val := get_int(doc, "port") or |err| {
        testing.fail(t, "get_int failed")
        return
    }
    testing.equal[i64](t, val, 8080)
}

fn test_parse_negative_integer(t *testing.T) void {
    doc := parse("offset = -42") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    val := get_int(doc, "offset") or |err| {
        testing.fail(t, "get_int failed")
        return
    }
    testing.equal[i64](t, val, -42)
}

fn test_parse_bool(t *testing.T) void {
    doc := parse("enabled = true\ndisabled = false") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    enabled := get_bool(doc, "enabled") or |err| {
        testing.fail(t, "get_bool enabled failed")
        return
    }
    testing.is_true(t, enabled)
    disabled := get_bool(doc, "disabled") or |err| {
        testing.fail(t, "get_bool disabled failed")
        return
    }
    testing.is_false(t, disabled)
}

fn test_parse_array(t *testing.T) void {
    doc := parse("ports = [80, 443, 8080]") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    items := get_array(doc, "ports") or |err| {
        testing.fail(t, "get_array failed")
        return
    }
    testing.equal[i32](t, len(items), 3)
    first := as_int(items[0]) or |err| {
        testing.fail(t, "as_int failed")
        return
    }
    testing.equal[i64](t, first, 80)
}

fn test_parse_table(t *testing.T) void {
    input := "[server]\nhost = \"localhost\"\nport = 9090"
    doc := parse(input) or |err| {
        testing.fail(t, "parse failed")
        return
    }
    server := get_table(doc, "server") or |err| {
        testing.fail(t, "get_table failed")
        return
    }
    host := get_str(server, "host") or |err| {
        testing.fail(t, "get_str host failed")
        return
    }
    testing.equal[str](t, host, "localhost")
    port := get_int(server, "port") or |err| {
        testing.fail(t, "get_int port failed")
        return
    }
    testing.equal[i64](t, port, 9090)
}

fn test_parse_inline_table(t *testing.T) void {
    doc := parse("point = {x = 1, y = 2}") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    point := get_table(doc, "point") or |err| {
        testing.fail(t, "get_table failed")
        return
    }
    x := get_int(point, "x") or |err| {
        testing.fail(t, "get_int x failed")
        return
    }
    testing.equal[i64](t, x, 1)
    y := get_int(point, "y") or |err| {
        testing.fail(t, "get_int y failed")
        return
    }
    testing.equal[i64](t, y, 2)
}

fn test_parse_dotted_key(t *testing.T) void {
    doc := parse("database.host = \"localhost\"") or |err| {
        testing.fail(t, "parse failed")
        return
    }
    host := get_str(get_table(doc, "database") or |err| {
        testing.fail(t, "get_table failed")
        return
    }, "host") or |err| {
        testing.fail(t, "get_str host failed")
        return
    }
    testing.equal[str](t, host, "localhost")
}

fn test_parse_comment(t *testing.T) void {
    input := "# this is a comment\nname = \"yar\" # inline comment\n# trailing"
    doc := parse(input) or |err| {
        testing.fail(t, "parse failed")
        return
    }
    val := get_str(doc, "name") or |err| {
        testing.fail(t, "get_str failed")
        return
    }
    testing.equal[str](t, val, "yar")
}

fn test_parse_yar_toml(t *testing.T) void {
    input := "[package]\nname = \"myapp\"\nversion = \"0.1.0\"\n\n[dependencies]\nhttp = {git = \"https://github.com/user/yar-http.git\", tag = \"v0.3.1\"}"
    doc := parse(input) or |err| {
        testing.fail(t, "parse failed")
        return
    }
    pkg := get_table(doc, "package") or |err| {
        testing.fail(t, "get_table package failed")
        return
    }
    name := get_str(pkg, "name") or |err| {
        testing.fail(t, "get_str name failed")
        return
    }
    testing.equal[str](t, name, "myapp")
    version := get_str(pkg, "version") or |err| {
        testing.fail(t, "get_str version failed")
        return
    }
    testing.equal[str](t, version, "0.1.0")
    deps := get_table(doc, "dependencies") or |err| {
        testing.fail(t, "get_table deps failed")
        return
    }
    http := get_table(deps, "http") or |err| {
        testing.fail(t, "get_table http failed")
        return
    }
    git := get_str(http, "git") or |err| {
        testing.fail(t, "get_str git failed")
        return
    }
    testing.equal[str](t, git, "https://github.com/user/yar-http.git")
    tag := get_str(http, "tag") or |err| {
        testing.fail(t, "get_str tag failed")
        return
    }
    testing.equal[str](t, tag, "v0.3.1")
}

fn test_as_str_type_error(t *testing.T) void {
    val := Value.Integer{val: 42}
    as_str(val) or |err| {
        testing.equal[error](t, err, error.TypeError)
        return
    }
    testing.fail(t, "expected TypeError")
}

fn test_as_int_type_error(t *testing.T) void {
    val := Value.String{val: "hello"}
    as_int(val) or |err| {
        testing.equal[error](t, err, error.TypeError)
        return
    }
    testing.fail(t, "expected TypeError")
}
