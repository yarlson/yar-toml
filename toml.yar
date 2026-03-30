package toml

pub enum Value {
    String { val str }
    Integer { val i64 }
    Boolean { val bool }
    Array { items []Value }
    Table { entries map[str]Value }
}

pub fn new_table() Value {
    return Value.Table{entries: map[str]Value{}}
}

pub fn parse(input str) !Value {
    p := Parser{input: input, pos: 0}
    return parse_document(&p)
}

pub fn get(v Value, key str) !Value {
    match v {
    case Value.Table(t) {
        return t.entries[key]
    }
    else { return error.TypeError }
    }
}

pub fn get_str(v Value, key str) !str {
    inner := get(v, key)?
    return as_str(inner)
}

pub fn get_int(v Value, key str) !i64 {
    inner := get(v, key)?
    return as_int(inner)
}

pub fn get_bool(v Value, key str) !bool {
    inner := get(v, key)?
    return as_bool(inner)
}

pub fn get_table(v Value, key str) !Value {
    inner := get(v, key)?
    match inner {
    case Value.Table(_) {
        return inner
    }
    else { return error.TypeError }
    }
}

pub fn get_array(v Value, key str) ![]Value {
    inner := get(v, key)?
    return as_array(inner)
}

pub fn as_str(v Value) !str {
    match v {
    case Value.String(s) { return s.val }
    else { return error.TypeError }
    }
}

pub fn as_int(v Value) !i64 {
    match v {
    case Value.Integer(i) { return i.val }
    else { return error.TypeError }
    }
}

pub fn as_bool(v Value) !bool {
    match v {
    case Value.Boolean(b) { return b.val }
    else { return error.TypeError }
    }
}

pub fn as_array(v Value) ![]Value {
    match v {
    case Value.Array(a) { return a.items }
    else { return error.TypeError }
    }
}

pub fn as_table(v Value) !map[str]Value {
    match v {
    case Value.Table(t) { return t.entries }
    else { return error.TypeError }
    }
}
