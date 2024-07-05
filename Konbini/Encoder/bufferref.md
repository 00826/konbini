### buffer reference table

|alias|type|byte size (offset)|range|description|
|-|-|-|-|-|
|i8|char|1|[ -127, 127 ]|signed 8-bit integer|
|u8|unsigned char|1|[ 0, 255 ]|unsigned 8-bit integer|
|i16|short|2|[ -32,768, 32,767 ]|signed 16-bit integer|
|u16|unsigned short|2|[ 0, 65,535 ]|unsigned 16-bit integer|
|i32|long|4|[ -2,147,483,648, 2,147,483,647 ]|signed 32-bit integer|
|u32|unsigned long|4|[ 0, 4,294,967,295 ]|unsigned 32-bit integer|
|f32|float|4|floats: ± 3.40 * 10<sup>38</sup> (floats)<br>[0, 16,777,216] (integers)|32-bit float|
|f64|double|8|± 1.80 * 10<sup>308</sup> (floats)<br>[± 9,007,199,254,740,992] (integers)|64-bit float|
|string|string|#string|#string|string|