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
|[Animation.luau](./Konbini/Animation/init.luau)|animation controller|-|⭕|
|*[await.luau](./Konbini/await/init.luau)*|`task.await()`|-|⭕|
|[Collisions.luau](./Konbini/Collisions/init.luau)|collision solver and spatial query wrapper|-|⭕|
|[Color3.luau](./Konbini/Color3/init.luau)|`Color3`, `ColorSequence` library extension|-|⭕|
|[Couture.luau](./Konbini/Couture/init.luau)|server-instanced, client-authoritative accessories|-|⭕|
|[Datastore.luau](./Konbini/Datastore/init.luau)|pcall-wrapped datastore functions|-|⭕|
|[Encoder.luau](./Konbini/Encoder/init.luau)|primitive type helper functions|-|⭕|
|[Entity.luau](./Konbini/Entity/init.luau)|entity replication controller|-|⭕|
|*[Hook.luau](./Konbini/Hook/init.luau)*|oopless function binder|-|⭕|
|[Inputs.luau](./Konbini/Inputs/init.luau)|`UserInputService`, `GamepadService` wrapper|-|⭕|
|[Instance.luau](./Konbini/Instance/init.luau)|`Instance` library extension|-|⭕|
|[Interface.luau](./Konbini/Interface/init.luau)|`UDim`, `UDim2`, `Vector2` library extensions, ui helper functions|-|⭕|
|[Math.luau](./Konbini/Math/init.luau)|`math` library extension|-|⭕|
|[Network.luau](./Konbini/Network/init.luau)|basic remote interface|-|⭕|
|[Patronage.luau](./Konbini/Patronage/init.luau)|player patronage (devproducts, gamepasses, premium, group membership, etc)|-|⭕|
|[Table.luau](./Konbini/Table/init.luau)|`table` library extension|-|⭕|
|[Time.luau](./Konbini/Time/init.luau)|server-authoritative global time|-|⭕|
|[Vector3.luau](./Konbini/Vector3/init.luau)|`Vector3` library extension|-|⭕|

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

コ Konbini by 00826 / overflowed