# konbini

## about

|ico.svg|lore|
|-|-|
|<img src="./konbini-ico.svg" width="96"/>|a shelf of roblox-luau convenience modules<br><br>started as a util module, ended as a library<br>*"the best thing since catalog price floors"*<br><br>while "stocking the shelves" i wanted to keep everything:<br>- simple & straightforward<br>- concise & to-the-point<br>- portable & copy-pastable|

## items

> [!NOTE]
> because exported types can't be accessed more than a file deep, types are housed in `types.luau`, and are exported directly from `require(path.to.Konbini)`

|module|why it exists|dependencies|unit tested?|
|-|-|-|:-:|
|[Konbini](./Konbini/init.luau)|main module|-|❌|
|[types](./Konbini/types.luau)|export types|-|-|
|-|-|-|-|
|[Animation.luau](./Konbini/Animation/init.luau)|aio animation handler|-|❌|
|*[async.luau](./Konbini/async/init.luau)*|task async-await|-|❌|
|*[Bind.luau](./Konbini/Bind/init.luau)*|bind functions|-|❌|
|[Bullet.luau](./Konbini/Bullet/init.luau)|projectile solver|`Konbini.Encoder`<br>`Konbini.Time`<br>`Konbini.Vector3`|❌|
|[CFrame.luau](./Konbini/CFrame/init.luau)|`CFrame` library extension|-|❌|
|[Collisions.luau](./Konbini/Collisions/init.luau)|condensed spatial queries|-|❌|
|[Couture.luau](./Konbini/Couture/init.luau)|near-client-authoritative accessory/cosmetic handling<br>game server has better things to do than weld accessories|-|❌|
|[Data.luau](./Konbini/Data/init.luau)|glorified `ProfileService` interface|`Konbini.Bind`<br>*implied dependence on profileservice*|❌|
|*[Debounce.luau](./Konbini/Debounce/init.luau)*|debounce function|`Konbini.Time`|❌|
|[Encoder.luau](./Konbini/Encoder/init.luau)|buffer/string manip library|-|❌|
|[Entity.luau](./Konbini/Entity/init.luau)|entity replicator|`Konbini.Bind`<br>`Konbini.Table`|❌|
|[Inputs.luau](./Konbini/Inputs/init.luau)|`UserInputService` wrapper, universal mouse position|`Konbini.Bind`|❌|
|[Instance.luau](./Konbini/Instance/init.luau)|`Instance` library extension|-|❌|
|[Interface.luau](./Konbini/Interface/init.luau)|user-interface helper functions|-|❌|
|[Math.luau](./Konbini/Math/init.luau)|`math` library extension|-|❌|
|*[Matrix.luau](./Konbini/Matrix/init.luau)*|buffer matrix-esque implementation|-|❌|
|[Misc.luau](./Konbini/Misc/init.luau)|collection of miscellaneous functions|-|❌|
|[Network.luau](./Konbini/Network/init.luau)|straightforward networking interface<br>tired of referencing remotes on every new script|`Konbini.async`|❌|
|[Rig.luau](./Konbini/Rig/init.luau)|motor6d-based rig helper functions|-|❌|
|[Table.luau](./Konbini/Table/init.luau)|`table` library extension|-|❌|
|[Time.luau](./Konbini/Tween/init.luau)|server-auth global time|-|❌|
|*[Tween.luau](./Konbini/Tween/init.luau)*|`TweenService` wrapper|-|❌|
|[Vector3.luau](./Konbini/Vector3/init.luau)|`Vector3` library extension|-|❌|
|[Zone.luau](./Konbini/Zone/init.luau)|server-defined, client-authoritative load zones|-|❌|

## design language

```lua
--- types

--- services
--- variables
--- private functions

--- description
local konbini_module = {}
--- public functions
--- runtime-specific operations
return konbini_module
```

**コ** Konbini by 00826 / overflowed