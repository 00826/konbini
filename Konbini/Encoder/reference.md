### int/float types

|alias|type|byte size (offset)|range|description|
|-|-|-|-|-|
|i8|char|1|[ -127, 127 ]|signed 8-bit integer|
|u8|unsigned char|1|[ 0, 255 ]|unsigned 8-bit integer|
|i16|short|2|[ -32,768, 32,767 ]|signed 16-bit integer|
|u16|unsigned short|2|[ 0, 65,535 ]|unsigned 16-bit integer|
|i24|24-bit integer|3|[ -8,388,608, 8,388,607 ]|signed 24-bit integer|
|u24|24-bit integer|3|[ 0, 16,777,215 ]|unsigned 24-bit integer|
|i32|long|4|[ -2,147,483,648, 2,147,483,647 ]|signed 32-bit integer|
|u32|unsigned long|4|[ 0, 4,294,967,295 ]|unsigned 32-bit integer|
|f32|float|4|floats: ± 3.40 * 10<sup>38</sup> (floats)<br>[0, 16,777,216] (integers)|32-bit float|
|f64|double|8|± 1.80 * 10<sup>308</sup> (floats)<br>[± 9,007,199,254,740,992] (integers)|64-bit float|
|string|string|#string|#string|string|

### luau regex

|pattern|type|example|
|-|-|-|
|`^`|positional character, start of string|-|
|`$`|positional character, end of string|-|
|`%`|escape character|captures magic characters: `$%^*().[]+-?`|
|-|-|-|
|`(uppercase letter)`|represents the negation of its lowercase counterpart|-|
|`.`|any|`me...ow` -> `me` .. `(3 characters)` .. `ow`|
|`%w`|alphanumeric|`aBcDeFgHiJkLmNoPqRsTuVwXyZ0123456789`|
|`%a`|uppercase or lowercase|`aBcDeFgHiJkLmNoPqRsTuVwXyZ`|
|`%u`|uppercase|`ABCDEFGHIJKLMNOPQRSTUVWXYZ`|
|`%l`|lowercase|`abcdefghijklmnopqrstuvwxyz`|
|`%d`|digit|`0123456789`|
|`%p`|punctuation|`!@#;,.`|
|`%s`|space|` `, `\n`, and `\r`|
|`%c`|control|-|
|`%x`|hexadecimal|`0123456789ABCDEF`|
|`%z`|null|`\0`|
|-|-|-|
|`[]`|establishes a range|-|
|`[ab]`|`i = "a" \| "b"`|-|
|`[^ab]`|`i = "a" NOR "b"`|-|
|`[a-z]`|`i ∈ {a ... z}`|-|
|`[0-5]`|`i ∈ {0, ... 5}`|-|
|`[a-zA-Z0-9]`|`i ∈ {a ... z} \| {A ... Z} \| {0 ... 9}`|-|
|-|-|-|
|`*`|matches previous char 0 to n times|`meow*` -> `meo` .. `(any? character)`|
|`+`|matches previous char 1 to n times|`meow+` -> `meow ... meowwwwww...`|
|`?`|matches previous char 0 or 1 times|`meow?` -> `meo\|meow`|
|-|-|-|