### int/float types

|alias|type|byte size (offset)|range|description|
|-|-|-|-|-|
|i8|char|1|[ -128, 127 ]|signed 8-bit integer|
|u8|unsigned char|1|[ 0, 255 ]|unsigned 8-bit integer|
|i16|short|2|[ -32,768, 32,767 ]|signed 16-bit integer|
|u16|unsigned short|2|[ 0, 65,535 ]|unsigned 16-bit integer|
|i24|sword|3|[ -8,388,608, 8,388,607 ]|signed 24-bit integer|
|u24|unsigned sword|3|[ 0, 16,777,215 ]|unsigned 24-bit integer|
|i32|long|4|[ -2,147,483,648, 2,147,483,647 ]|signed 32-bit integer|
|u32|unsigned long|4|[ 0, 4,294,967,295 ]|unsigned 32-bit integer|
|f32|float|4|± 3.40 * 10<sup>38</sup> (floats)<br>[ 0, 16,777,216 ] (integers)|32-bit float|
|f64|double|8|± 1.80 * 10<sup>308</sup> (floats)<br>[ ± 9,007,199,254,740,992 ] (integers)|64-bit float|
|string|string|#string|#string|string|

### unsigned int bit flagging

|width|`2^n-1`|width|`2^n-1`|width|`2^n-1`|width|`2^n-1`|
|-|-|-|-|-|-|-|-|
|`1`|1|`9`|511|`17`|131071|`25`|33554431|
|`2`|3|`10`|1023|`18`|262143|`26`|67108863|
|`3`|7|`11`|2047|`19`|524287|`27`|134217727|
|`4`|15|`12`|4095|`20`|1048575|`28`|268435455|
|`5`|31|`13`|8191|`21`|2097151|`29`|536870911|
|`6`|63|`14`|16383|`22`|4194303|`30`|1073741823|
|`7`|127|`15`|32767|`23`|8388607|`31`|2147483647|
|`8`|255|`16`|65535|`24`|16777215|`32`|4294967295|

### hexadecimal compression

|maxvalue|datastore unit cost (json-encoded integer)|`string.format("%x", n)`|datastore unit cost (hexadecimal)|
|-|-|-|-|
|15|2|`f`|1|
|255|3|`ff`|2|
|4095|4|`fff`|3|
|65535|5|`ffff`|4|
|1048575|7|`fffff`|5|
|16777215|8|`ffffff`|6|
|268435455|9|`fffffff`|7|

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