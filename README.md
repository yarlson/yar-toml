# yar-toml

TOML parser for [Yar](https://github.com/yarlson/yar).

## Install

Add to your `yar.toml`:

```toml
[dependencies]
toml = { git = "https://github.com/yarlson/yar-toml.git", tag = "v0.1.0" }
```

## Usage

```
package main

import "toml"

fn main() !i32 {
    input := "[package]\nname = \"myapp\"\nversion = \"0.1.0\""

    doc := toml.parse(input)?

    pkg := toml.get_table(doc, "package")?
    name := toml.get_str(pkg, "name")?
    print(name)
    print("\n")

    version := toml.get_str(pkg, "version")?
    print(version)
    print("\n")

    return 0
}
```

## API

### Types

```
pub enum Value {
    String { val str }
    Integer { val i64 }
    Boolean { val bool }
    Array { items []Value }
    Table { entries map[str]Value }
}
```

### Parsing

| Function                  | Description                        |
| ------------------------- | ---------------------------------- |
| `parse(input str) !Value` | Parse TOML text, return root table |
| `new_table() Value`       | Create an empty table              |

### Table access

| Function                               | Description              |
| -------------------------------------- | ------------------------ |
| `get(v Value, key str) !Value`         | Look up a key in a table |
| `get_str(v Value, key str) !str`       | Look up a string value   |
| `get_int(v Value, key str) !i64`       | Look up an integer value |
| `get_bool(v Value, key str) !bool`     | Look up a boolean value  |
| `get_table(v Value, key str) !Value`   | Look up a sub-table      |
| `get_array(v Value, key str) ![]Value` | Look up an array         |

### Value extraction

| Function                           | Description                      |
| ---------------------------------- | -------------------------------- |
| `as_str(v Value) !str`             | Extract string from Value        |
| `as_int(v Value) !i64`             | Extract integer from Value       |
| `as_bool(v Value) !bool`           | Extract boolean from Value       |
| `as_array(v Value) ![]Value`       | Extract array items from Value   |
| `as_table(v Value) !map[str]Value` | Extract table entries from Value |

### Errors

- `error.ParseError` — malformed TOML input
- `error.TypeError` — wrong value type (e.g. `as_str` on an integer)
- `error.MissingKey` — key not found in table

## Supported TOML features

- Key/value pairs with bare and quoted keys
- Dotted keys (`a.b.c = value`)
- Basic strings with `\n`, `\t`, `\\`, `\"` escapes
- Integers with optional sign and `_` separators
- Booleans (`true`, `false`)
- Arrays (including multiline)
- Inline tables
- Table headers (`[section]`, `[a.b.c]`)
- Comments (`# ...`)

## Not yet supported

- Multi-line basic strings (`"""..."""`)
- Literal strings (`'...'`)
- Hex, octal, and binary integers
- Floats
- Datetimes
- Array of tables (`[[section]]`)

## Tests

```bash
yar test .
```

## License

[MIT](LICENSE)
