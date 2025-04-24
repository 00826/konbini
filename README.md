# konbini

## about

|ico.svg|lore|
|-|-|
|<img src="./konbini-ico.svg" width="96"/>|a shelf of roblox-luau convenience modules<br><br>started as a util module, ended as a library<br>*"the best thing since catalog price floors"*<br><br>while "stocking the shelves" i wanted to keep everything:<br>- simple & straightforward<br>- concise & to-the-point<br>- portable & copy-pastable|

## aisles

*although not objectively unit-tested (laziness), every function in some capacity is guaranteed to have been used at least once, as each function and/or submodule was written to fill some sort of prior need*

|module|why it exists|dependencies|unit tested?|
|-|-|-|:-:|
|[Konbini](./Konbini/init.luau)|main module|-|⭕|
|-|-|-|-|
|[Animation.luau](./Konbini/Animation/init.luau)|aio animation handler|-|⭕|
|*[await.luau](./Konbini/await/init.luau)*|`task.await()`|-|⭕|
|[Bullet.luau](./Konbini/Bullet/init.luau)|projectile solver|-|⭕|
|**[CFrame.luau](./Konbini/CFrame/init.luau)**|`CFrame` library extension|-|⭕|
|[Collisions.luau](./Konbini/Collisions/init.luau)|condensed spatial queries|-|⭕|
|**[Color3.luau](./Konbini/Color3/init.luau)**|`Color3` library extension|-|⭕|
|[Couture.luau](./Konbini/Couture/init.luau)|near-client-authoritative accessory/cosmetic handling<br>game server has better things to do than weld accessories<br>*gated to `InsertService:LoadAsset()` being server-only :/*|-|⭕|
|[Data.luau](./Konbini/Data/init.luau)|glorified `ProfileService` interface|*implied dependence on profileservice*|⭕|
|[Encoder.luau](./Konbini/Encoder/init.luau)|buffer/string manip library|-|⭕|
|[Entity.luau](./Konbini/Entity/init.luau)|entity replicator|-|⭕|
|*[Hook.luau](./Konbini/Hook/init.luau)*|function binder|-|⭕|
|[Inputs.luau](./Konbini/Inputs/init.luau)|`UserInputService` wrapper, universal mouse position|-|⭕|
|**[Instance.luau](./Konbini/Instance/init.luau)**|`Instance` library extension|-|⭕|
|[Interface.luau](./Konbini/Interface/init.luau)|user-interface helper functions|-|⭕|
|**[Math.luau](./Konbini/Math/init.luau)**|`math` library extension|-|⭕|
|[Memory.luau](./Konbini/Memory/init.luau)|`MemoryStoreService` wrapper|-|⭕|
|[Network.luau](./Konbini/Network/init.luau)|straightforward two-function networking interface|-|⭕|
|[Patronage.luau](./Konbini/Patronage/init.luau)|easily handle devproducts, gamepasses, group membership, etc|-|⭕|
|**[Table.luau](./Konbini/Table/init.luau)**|`table` library extension|-|⭕|
|[Time.luau](./Konbini/Tween/init.luau)|server-auth global time|-|⭕|
|**[Vector3.luau](./Konbini/Vector3/init.luau)**|`Vector3` library extension|-|⭕|

## design language

```lua
--- GlobalScope
--- FieldOfTable
--- localscope
--- --- side commentary

--- directives

--- services
--- variables
--- private functions
--- export types

--- header
local module = {}
--- functions

--- ...
--- <line break> -- "block opener"
--- local definition
--- definition.x
--- definition.func()
--- <line break> -- "block closer"
--- ... | return definition -- "scope closer"

--- x::y -- "kick rocks"
--- ;(x::any) = y -- "kick rocks"
--- ;(x::any).y = z -- "kick rocks"

--- runtime-sensitive work
return module
```

**コ** Konbini by 00826 / overflowed