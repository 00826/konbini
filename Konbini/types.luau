--- Animation.luau types

export type AnimLibraryEntry = {Id: string?, Priority: Enum.AnimationPriority?, Animation: Animation?} & {[string]: any}
export type LocomotionState = "Idle" | "Walk" | "Run"

--- Bar.luau types

export type Axes = {
	X: number?;
	Y: number?;
	Z: number?;
}

--- Bind.luau types

export type Disconnect = () -> ()

--- Bullet.luau types

export type WriteOptions = {
	id: string?;
	time: number?;
	position: Vector3?;
	direction: Vector3?;
}

--- Collisions.luau

export type CastShape = "Box" | "Ball"
export type CastList = "Whitelist" | "Blacklist"

--- Data.luau

export type SaveTemplate = typeof(require(script.Parent.Data.Config).SaveTemplate)

--- Inputs.luau

export type Cursor = {
	--- 3d position of cursor
	Position: Vector3;
	--- unit vector of cursor surface
	Normal: Vector3;
	--- unit vector of camera
	Camera: Vector3;
	--- instance that cursor is on
	Instance: Instance?;
}
export type DynamicGamepadKey = "Y" | "X" | "B" | "A" | "L1" | "R1" | "L2" | "R2" | "R3"

export type Keybind = {
	--- real-time values that will activate this keybind \
	--- indices are as follows, and default to 0 when unbound: \
	--- `1`: pc \
	--- `2`: mobile \
	--- `3`: gamepad
	Reals: {number};
	--- default values that are written to reals \
	--- indices are as follows, and default to 0 when unbound: \
	--- `1`: pc \
	--- `2`: mobile \
	--- `3`: gamepad
	Defaults: {number};
} & {[string]: any};

--- Instance.luau

export type Tree = {
	ClassName: string;
	Children: { Tree }?;
	Parent: Instance?;
} & { [string]: any }

--- Interface.luau

export type ButtonFunctions = {
	["ClickDown"]: ((x: number?, y: number?) -> ())?;
	["ClickUp"]: ((x: number?, y: number?) -> ())?;
	["RClickDown"]: ((x: number?, y: number?) -> ())?;
	["RClickUp"]: ((x: number?, y: number?) -> ())?;
	["Enter"]: ((x: number?, y: number?) -> ())?;
	["Leave"]: ((x: number?, y: number?) -> ())?;
	["Move"]: ((x: number?, y: number?) -> ())?;
}

export type SpriteLayout = {
	--- rbxassetid://
	Id: string;
	--- sprite size
	Size: Vector2;
	--- sheet padding
	Padding: number;
	--- sheet dimensions
	Width: number;
}

export type Sprite = {
	--- position of sprite (L -> R, T -> B)
	Position: number;
	--- sprite layout
	Layout: SpriteLayout;
}

export type LeftOrRight = "Left" | "Right"

--- Math.luau

export type UnitCircleVertex = { X: number, Z: number }

--- Network.luau

export type Remote = RemoteEvent|UnreliableRemoteEvent|any
export type ClientArg = 
	| nil
	| number
	| Player
	| { number|Player }
	| ((Player) -> boolean)

--- Rig.luau

export type MoverClass = "BodyGyro" | "BodyVelocity" | "BodyPosition" | "VectorForce"

--- Time.luau

export type Notation = "DD:HH:MM:SS" | "HH:MM:SS" | "MM:SS" | "M:SS"
export type Format = number | "Hour" | "Biphase" | "Day" | "Week" | "Season" | "Biseason" | "Year"
export type FormatResult = {
	Timestamp: string;
	Seed: number;
	Until: number;
}

--- Vector3.luau

--- anything that can be represented as pure `x, y, z`
export type xyzType = Vector3 | Vector3int16 | PVInstance | CFrame

--- Zone.luau

export type Zone = {
	--- parent container for placements of this zone
	Container: Instance?;
	--- global position of this zone
	Position: Vector3?;
	--- load radius of this zone
	Radius: number?;
	--- default spawn box of this zone
	SpawnBox: (SpawnLocation|BasePart)?;

	--- instances that are visible when zone is `in a loaded state`, and are otherwise non-visible
	Placements: {Instance}?;
	--- instances that are visible when zone is `in an offloaded state`, and are otherwise non-visible
	Emplacements: {Instance}?;
	--- instances that are *never* visible regardless of loaded/offloaded state
	Never: {Instance}?;
}

return { R = Random.new(); }