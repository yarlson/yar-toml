package toml

import "conv"

struct Parser {
    input str
    pos i32
}

// --- Byte classification helpers ---

fn is_ws(b i32) bool {
    return b == 32 || b == 9
}

fn is_newline(b i32) bool {
    return b == 10 || b == 13
}

fn is_digit(b i32) bool {
    return b >= 48 && b <= 57
}

fn is_bare_key_char(b i32) bool {
    return (b >= 65 && b <= 90) || (b >= 97 && b <= 122) || (b >= 48 && b <= 57) || b == 45 || b == 95
}

// --- Parser navigation ---

fn p_at_end(p *Parser) bool {
    return (*p).pos >= len((*p).input)
}

fn p_peek(p *Parser) i32 {
    return (*p).input[(*p).pos]
}

fn p_advance(p *Parser) void {
    (*p).pos = (*p).pos + 1
}

fn p_expect(p *Parser, expected i32) !void {
    if p_at_end(p) || p_peek(p) != expected {
        return error.ParseError
    }
    p_advance(p)
}

fn p_starts_with(p *Parser, s str) bool {
    if (*p).pos + len(s) > len((*p).input) {
        return false
    }
    return (*p).input[(*p).pos:(*p).pos + len(s)] == s
}

// --- Whitespace and comment handling ---

fn p_skip_ws(p *Parser) void {
    for !p_at_end(p) {
        if !is_ws(p_peek(p)) {
            break
        }
        p_advance(p)
    }
}

fn p_skip_comment(p *Parser) void {
    if !p_at_end(p) && p_peek(p) == 35 {
        for !p_at_end(p) && !is_newline(p_peek(p)) {
            p_advance(p)
        }
    }
}

fn p_skip_insignificant(p *Parser) void {
    for !p_at_end(p) {
        b := p_peek(p)
        if is_ws(b) || is_newline(b) {
            p_advance(p)
            continue
        }
        if b == 35 {
            for !p_at_end(p) && !is_newline(p_peek(p)) {
                p_advance(p)
            }
            continue
        }
        break
    }
}

// --- Value parsing ---

fn p_parse_value(p *Parser) !Value {
    p_skip_ws(p)
    if p_at_end(p) {
        return error.ParseError
    }
    b := p_peek(p)
    if b == 34 {
        s := p_parse_string(p)?
        return Value.String{val: s}
    }
    if b == 116 || b == 102 {
        val := p_parse_bool(p)?
        return Value.Boolean{val: val}
    }
    if is_digit(b) || b == 43 || b == 45 {
        n := p_parse_integer(p)?
        return Value.Integer{val: n}
    }
    if b == 91 {
        return p_parse_array(p)
    }
    if b == 123 {
        return p_parse_inline_table(p)
    }
    return error.ParseError
}

fn p_parse_string(p *Parser) !str {
    p_expect(p, 34)?
    result := ""
    for !p_at_end(p) && p_peek(p) != 34 {
        if p_peek(p) == 92 {
            p_advance(p)
            if p_at_end(p) {
                return error.ParseError
            }
            b := p_peek(p)
            if b == 110 {
                result = result + "\n"
            } else if b == 116 {
                result = result + "\t"
            } else if b == 92 {
                result = result + "\\"
            } else if b == 34 {
                result = result + "\""
            } else {
                return error.ParseError
            }
            p_advance(p)
        } else {
            pos := (*p).pos
            result = result + (*p).input[pos:pos + 1]
            p_advance(p)
        }
    }
    p_expect(p, 34)?
    return result
}

fn p_parse_integer(p *Parser) !i64 {
    negative := false
    if !p_at_end(p) && p_peek(p) == 43 {
        p_advance(p)
    } else if !p_at_end(p) && p_peek(p) == 45 {
        negative = true
        p_advance(p)
    }
    if p_at_end(p) || !is_digit(p_peek(p)) {
        return error.ParseError
    }
    var result i64 = 0
    for !p_at_end(p) && (is_digit(p_peek(p)) || p_peek(p) == 95) {
        if p_peek(p) == 95 {
            p_advance(p)
            continue
        }
        digit := conv.to_i64(p_peek(p) - 48)
        result = result * 10 + digit
        p_advance(p)
    }
    if negative {
        return 0 - result
    }
    return result
}

fn p_parse_bool(p *Parser) !bool {
    if p_starts_with(p, "true") {
        (*p).pos = (*p).pos + 4
        return true
    }
    if p_starts_with(p, "false") {
        (*p).pos = (*p).pos + 5
        return false
    }
    return error.ParseError
}

fn p_parse_array(p *Parser) !Value {
    p_expect(p, 91)?
    items := []Value{}
    p_skip_insignificant(p)
    if !p_at_end(p) && p_peek(p) == 93 {
        p_advance(p)
        return Value.Array{items: items}
    }
    val := p_parse_value(p)?
    items = append(items, val)
    for !p_at_end(p) {
        p_skip_insignificant(p)
        if p_at_end(p) || p_peek(p) == 93 {
            break
        }
        p_expect(p, 44)?
        p_skip_insignificant(p)
        if !p_at_end(p) && p_peek(p) == 93 {
            break
        }
        val = p_parse_value(p)?
        items = append(items, val)
    }
    p_expect(p, 93)?
    return Value.Array{items: items}
}

fn p_parse_inline_table(p *Parser) !Value {
    p_expect(p, 123)?
    entries := map[str]Value{}
    p_skip_ws(p)
    if !p_at_end(p) && p_peek(p) == 125 {
        p_advance(p)
        return Value.Table{entries: entries}
    }
    key_path := p_parse_key_path(p)?
    p_skip_ws(p)
    p_expect(p, 61)?
    p_skip_ws(p)
    val := p_parse_value(p)?
    set_nested(entries, key_path, val)?
    for !p_at_end(p) {
        p_skip_ws(p)
        if p_at_end(p) || p_peek(p) == 125 {
            break
        }
        p_expect(p, 44)?
        p_skip_ws(p)
        if !p_at_end(p) && p_peek(p) == 125 {
            break
        }
        key_path = p_parse_key_path(p)?
        p_skip_ws(p)
        p_expect(p, 61)?
        p_skip_ws(p)
        val = p_parse_value(p)?
        set_nested(entries, key_path, val)?
    }
    p_expect(p, 125)?
    return Value.Table{entries: entries}
}

// --- Key parsing ---

fn p_parse_key_path(p *Parser) ![]str {
    key_parts := []str{}
    key := p_parse_simple_key(p)?
    key_parts = append(key_parts, key)
    for !p_at_end(p) && p_peek(p) == 46 {
        p_advance(p)
        key = p_parse_simple_key(p)?
        key_parts = append(key_parts, key)
    }
    return key_parts
}

fn p_parse_simple_key(p *Parser) !str {
    p_skip_ws(p)
    if p_at_end(p) {
        return error.ParseError
    }
    if p_peek(p) == 34 {
        return p_parse_string(p)
    }
    start := (*p).pos
    for !p_at_end(p) && is_bare_key_char(p_peek(p)) {
        p_advance(p)
    }
    if (*p).pos == start {
        return error.ParseError
    }
    return (*p).input[start:(*p).pos]
}

// --- Table navigation helpers ---

fn ensure_table(root map[str]Value, path []str) !map[str]Value {
    current := root
    i := 0
    for i < len(path) {
        key := path[i]
        if has(current, key) {
            existing := current[key]?
            match existing {
            case Value.Table(t) {
                current = t.entries
            }
            case Value.String(_) { return error.ParseError }
            case Value.Integer(_) { return error.ParseError }
            case Value.Boolean(_) { return error.ParseError }
            case Value.Array(_) { return error.ParseError }
            }
        } else {
            sub := map[str]Value{}
            current[key] = Value.Table{entries: sub}
            current = sub
        }
        i = i + 1
    }
    return current
}

fn set_nested(entries map[str]Value, path []str, val Value) !void {
    current := entries
    i := 0
    for i < len(path) - 1 {
        key := path[i]
        if has(current, key) {
            existing := current[key]?
            match existing {
            case Value.Table(t) {
                current = t.entries
            }
            case Value.String(_) { return error.ParseError }
            case Value.Integer(_) { return error.ParseError }
            case Value.Boolean(_) { return error.ParseError }
            case Value.Array(_) { return error.ParseError }
            }
        } else {
            sub := map[str]Value{}
            current[key] = Value.Table{entries: sub}
            current = sub
        }
        i = i + 1
    }
    last := path[len(path) - 1]
    current[last] = val
}

// --- Document parsing ---

fn parse_document(p *Parser) !Value {
    root := map[str]Value{}
    current := root

    for !p_at_end(p) {
        p_skip_insignificant(p)
        if p_at_end(p) {
            break
        }

        b := p_peek(p)
        if b == 91 {
            p_advance(p)
            if !p_at_end(p) && p_peek(p) == 91 {
                return error.ParseError
            }
            path := p_parse_key_path(p)?
            p_skip_ws(p)
            p_expect(p, 93)?
            p_skip_ws(p)
            p_skip_comment(p)
            current = ensure_table(root, path)?
        } else {
            path := p_parse_key_path(p)?
            p_skip_ws(p)
            p_expect(p, 61)?
            p_skip_ws(p)
            val := p_parse_value(p)?
            p_skip_ws(p)
            p_skip_comment(p)
            set_nested(current, path, val)?
        }
    }

    return Value.Table{entries: root}
}
