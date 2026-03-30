package toml

import "conv"

struct Parser {
    input str
    pos i32
}

// --- Byte classification helpers ---

fn is_ws(b i32) bool {
    return b == ' ' || b == '\t'
}

fn is_newline(b i32) bool {
    return b == '\n' || b == '\r'
}

fn is_digit(b i32) bool {
    return b >= '0' && b <= '9'
}

fn is_bare_key_char(b i32) bool {
    return (b >= 'A' && b <= 'Z') || (b >= 'a' && b <= 'z') || (b >= '0' && b <= '9') || b == '-' || b == '_'
}

// --- Parser navigation ---

fn p_at_end(p *Parser) bool {
    return p.pos >= len(p.input)
}

fn p_peek(p *Parser) i32 {
    return p.input[p.pos]
}

fn p_advance(p *Parser) void {
    p.pos += 1
}

fn p_expect(p *Parser, expected i32) !void {
    if p_at_end(p) || p_peek(p) != expected {
        return error.ParseError
    }
    p_advance(p)
}

fn p_starts_with(p *Parser, s str) bool {
    if p.pos + len(s) > len(p.input) {
        return false
    }
    return p.input[p.pos:p.pos + len(s)] == s
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
    if !p_at_end(p) && p_peek(p) == '#' {
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
        if b == '#' {
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
    if b == '"' {
        s := p_parse_string(p)?
        return Value.String(s)
    }
    if b == 't' || b == 'f' {
        val := p_parse_bool(p)?
        return Value.Boolean(val)
    }
    if is_digit(b) || b == '+' || b == '-' {
        n := p_parse_integer(p)?
        return Value.Integer(n)
    }
    if b == '[' {
        return p_parse_array(p)
    }
    if b == '{' {
        return p_parse_inline_table(p)
    }
    return error.ParseError
}

fn p_parse_string(p *Parser) !str {
    p_expect(p, '"')?
    sb := sb_new()
    for !p_at_end(p) && p_peek(p) != '"' {
        if p_peek(p) == '\\' {
            p_advance(p)
            if p_at_end(p) {
                return error.ParseError
            }
            b := p_peek(p)
            if b == 'n' {
                sb_write(sb, "\n")
            } else if b == 't' {
                sb_write(sb, "\t")
            } else if b == 'r' {
                sb_write(sb, "\r")
            } else if b == '\\' {
                sb_write(sb, "\\")
            } else if b == '"' {
                sb_write(sb, "\"")
            } else {
                return error.ParseError
            }
            p_advance(p)
        } else {
            pos := p.pos
            sb_write(sb, p.input[pos:pos + 1])
            p_advance(p)
        }
    }
    p_expect(p, '"')?
    return sb_string(sb)
}

fn p_parse_integer(p *Parser) !i64 {
    negative := false
    if !p_at_end(p) && p_peek(p) == '+' {
        p_advance(p)
    } else if !p_at_end(p) && p_peek(p) == '-' {
        negative = true
        p_advance(p)
    }
    if p_at_end(p) || !is_digit(p_peek(p)) {
        return error.ParseError
    }
    var result i64 = 0
    for !p_at_end(p) && (is_digit(p_peek(p)) || p_peek(p) == '_') {
        if p_peek(p) == '_' {
            p_advance(p)
            continue
        }
        digit := conv.to_i64(p_peek(p) - '0')
        result = result * 10 + digit
        p_advance(p)
    }
    if negative {
        return -result
    }
    return result
}

fn p_parse_bool(p *Parser) !bool {
    if p_starts_with(p, "true") {
        p.pos += 4
        return true
    }
    if p_starts_with(p, "false") {
        p.pos += 5
        return false
    }
    return error.ParseError
}

fn p_parse_array(p *Parser) !Value {
    p_expect(p, '[')?
    items := []Value{}
    p_skip_insignificant(p)
    if !p_at_end(p) && p_peek(p) == ']' {
        p_advance(p)
        return Value.Array(items)
    }
    val := p_parse_value(p)?
    items = append(items, val)
    for !p_at_end(p) {
        p_skip_insignificant(p)
        if p_at_end(p) || p_peek(p) == ']' {
            break
        }
        p_expect(p, ',')?
        p_skip_insignificant(p)
        if !p_at_end(p) && p_peek(p) == ']' {
            break
        }
        val = p_parse_value(p)?
        items = append(items, val)
    }
    p_expect(p, ']')?
    return Value.Array(items)
}

fn p_parse_inline_table(p *Parser) !Value {
    p_expect(p, '{')?
    entries := map[str]Value{}
    p_skip_ws(p)
    if !p_at_end(p) && p_peek(p) == '}' {
        p_advance(p)
        return Value.Table(entries)
    }
    key_path := p_parse_key_path(p)?
    p_skip_ws(p)
    p_expect(p, '=')?
    p_skip_ws(p)
    val := p_parse_value(p)?
    set_nested(entries, key_path, val)?
    for !p_at_end(p) {
        p_skip_ws(p)
        if p_at_end(p) || p_peek(p) == '}' {
            break
        }
        p_expect(p, ',')?
        p_skip_ws(p)
        if !p_at_end(p) && p_peek(p) == '}' {
            break
        }
        key_path = p_parse_key_path(p)?
        p_skip_ws(p)
        p_expect(p, '=')?
        p_skip_ws(p)
        val = p_parse_value(p)?
        set_nested(entries, key_path, val)?
    }
    p_expect(p, '}')?
    return Value.Table(entries)
}

// --- Key parsing ---

fn p_parse_key_path(p *Parser) ![]str {
    key_parts := []str{}
    key := p_parse_simple_key(p)?
    key_parts = append(key_parts, key)
    for !p_at_end(p) && p_peek(p) == '.' {
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
    if p_peek(p) == '"' {
        return p_parse_string(p)
    }
    start := p.pos
    for !p_at_end(p) && is_bare_key_char(p_peek(p)) {
        p_advance(p)
    }
    if p.pos == start {
        return error.ParseError
    }
    return p.input[start:p.pos]
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
            else { return error.ParseError }
            }
        } else {
            sub := map[str]Value{}
            current[key] = Value.Table(sub)
            current = sub
        }
        i += 1
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
            else { return error.ParseError }
            }
        } else {
            sub := map[str]Value{}
            current[key] = Value.Table(sub)
            current = sub
        }
        i += 1
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
        if b == '[' {
            p_advance(p)
            if !p_at_end(p) && p_peek(p) == '[' {
                return error.ParseError
            }
            path := p_parse_key_path(p)?
            p_skip_ws(p)
            p_expect(p, ']')?
            p_skip_ws(p)
            p_skip_comment(p)
            current = ensure_table(root, path)?
        } else {
            path := p_parse_key_path(p)?
            p_skip_ws(p)
            p_expect(p, '=')?
            p_skip_ws(p)
            val := p_parse_value(p)?
            p_skip_ws(p)
            p_skip_comment(p)
            set_nested(current, path, val)?
        }
    }

    return Value.Table{entries: root}
}
