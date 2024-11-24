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
|f32|float|4|± 3.40 * 10<sup>38</sup> (floats)<br>[ 0, 16,777,216 ] (integers)|32-bit float|
|f64|double|8|± 1.80 * 10<sup>308</sup> (floats)<br>[ ± 9,007,199,254,740,992 ] (integers)|64-bit float|
|string|string|#string|#string|string|

### unsigned int bit flagging

|width|`2^n-1`|width|`2^n-1`|
|-|-|-|-|
|`1`|1|`11`|2,047|
|`2`|3|`12`|4,095|
|`3`|7|`13`|8,191|
|`4`|15|`14`|16,383|
|`5`|31|`15`|32,767|
|`6`|63|`16`|65,535|
|`7`|127|-|-|
|`8`|255|`31`|2,147,483,647|
|`9`|511|`32`|4,294,967,295|
|`10`|1,023|-|-|

### bit32 field, little-endian

|[31, 30, 29, 28, 27, 26, 25, 24]|[23, 22, 21, 20, 19, 18, 17, 16]|[15, 14, 13, 12, 11, 10, 9, 8]|[7, 6, 5, 4, 3, 2, 1, 0]|
|:-:|:-:|:-:|:-:|
|`0000 0000`|`0000 0000`|`0000 0000`|`0000 0000`|

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