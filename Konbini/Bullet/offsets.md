### empty bullet
|offset/total|type|alias|desc|
|-|-|-|-|
|0|string4|id|4-character id of this bullet|
|4|u8|cycle|frame cycle, for cases where this bullet should only be updated every `n`th frame|
|5|u8|type|bullet type|
|6|f32|time|bullet spawn time|
|[10, 14, 18]|f32|pX, pY, pZ|bullet position|
|[22, 26, 30]|f32|dX, dY, dZ|bullet vector, describing either direction or a point in 3d space<br>`.Unit` = direction<br>`.Magnitude` = distance or speed|
|-|-|-|-|
|34|-|-|empty bullet size|

### hitscan
|offset/total|type|alias|desc|
|-|-|-|-|
|34|-|-|*bytes carried from empty bullet*|
|-|-|-|-|
|34|-|-|buffer describing a hitscan bullet|

### ballistic
|offset/total|type|alias|desc|
|-|-|-|-|
|34|-|-|*bytes carried from empty bullet*|
|-|-|-|-|
|34|i16|gravity|force of gravity acting on this bullet|
|36|i8|ylimit|bullet will be destroyed if it goes below this y-value|
|-|-|-|-|
|37|-|-|buffer describing a ballistic bullet|

### beam
|offset/total|type|alias|desc|
|-|-|-|-|
|34|-|-|*bytes carried from empty bullet*|
|-|-|-|-|
|34|u16|speed|speed of this bullet|
|-|-|-|-|
|36|-|-|buffer describing a beam bullet|

### bezier
|offset/total|type|alias|desc|
|-|-|-|-|
|34|-|-|*bytes carried from empty bullet*|
|-|-|-|-|
|[34, 38, 42]|f32|cX, cY, cZ|control point of this bullet|
|46|u16|speed|speed of this bullet|
|-|-|-|-|
|48|-|-|buffer describing a bezier bullet|

### track
|offset/total|type|alias|desc|
|-|-|-|-|
|34|-|-|*bytes carried from empty bullet*|
|-|-|-|-|
|34|string4|target|4-character id of target|
|38|u16|speed|speed of this bullet|
|-|-|-|-|
|40|-|-|buffer describing a tracking bullet|