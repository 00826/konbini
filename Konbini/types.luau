--- Animation.luau

export type AnimLibraryEntry = {Id: string?, Priority: Enum.AnimationPriority?, Animation: Animation?} & {[string]: any}
export type LocomotionState = 
	| "Idle"
	| "Walk"
	| "Run"

--- Bullet.luau

export type BaseOptions = {
	--- [*Bullet*] \
	--- bullet id
	Id: string?;
	--- [*Bullet*] \
	--- bullet update every nth frame
	Cycle: number?;
	--- [*Bullet*] \
	--- bullet time
	Time: number?;
	--- [*Bullet*] \
	--- bullet position
	Position: Vector3?;
	--- [*Bullet*] \
	--- bullet vector
	Vector: Vector3?;
}

export type TypeOptions = {
	--- [*Ballistic*] \
	--- gravity acting upon a ballistic bullet
	Gravity: number?;
	--- [*Ballistic*] \
	--- y-limit of a ballistic bullet
	Ylimit: number?;
	--- [*Ballistic, Beam, Bezier, Track*] \
	--- speed of any non-hitscan bullet
	Speed: number?;
	--- [*Bezier*] \
	--- control point of a bezier bullet
	Start: Vector3?;
	--- [*Bezier*] \
	--- control point of a bezier bullet
	Control: Vector3?;
	--- [*Bezier*] \
	--- goal point of a bezier bullet
	Goal: Vector3?;
	--- [*Track*] \
	--- string describing the target of a track bullet
	Target: string?;
}

export type Bullet =
	| "Hitscan" --- 1
	| "Ballistic" --- 2
	| "Beam" --- 3
	| "Bezier" --- 4
	| "Track" --- 5

--- Collisions.luau

export type CastShape =
	| "Box"
	| "Ball"
export type CastList =
	| "Whitelist"
	| "Blacklist"

--- Data.luau

export type SaveTemplate = typeof(require(script.Parent.Data.Config).SaveTemplate)

--- Encoder.luau

export type intfloat = 
	| "i8"
	| "u8"
	| "i16"
	| "u16"
	| "i24"
	| "u24"
	| "i32"
	| "u32"
	| "f32"
	| "f64"
export type Notation = 
	| "DD:HH:MM:SS"
	| "HH:MM:SS"
	| "MM:SS"
	| "M:SS"
export type Format =
	| number
	| "Hour"
	| "Biphase"
	| "Day"
	| "Week"
	| "Season"
	| "Biseason"
	| "Year"
export type Timestamp = {
	--- unique, non-recurring string describing format time
	Id: string;
	--- unique, non-recurring number describing format time
	Seed: number;
	--- time until format changes
	Until: number;
}

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

export type MoverClass =
	| "BodyGyro"
	| "BodyVelocity"
	| "BodyPosition"
	| "VectorForce"

export type KeyframeInfo = {
	Framerate: number;
	Framerule: number;

	Time: number;
	Elapsed: number;
	IsPaused: boolean;

	Style: Enum.EasingStyle;
	Direction: Enum.EasingDirection;

	Initial: {[string]: any};
	Goal: {[string]: any};
	Destruct: number?;

	Pause: () -> ();
	Resume: () -> ();
	Stop: () -> ();
}

export type KeyframeType =
	| number
	| boolean
	| Vector2
	| Vector3
	| CFrame
	| Color3
	| ColorSequence
	| EnumItem
	| NumberRange
	| NumberSequence
	| UDim
	| UDim2

--- Interface.luau

export type ButtonFunctions = {
	--- `.MouseButton1Down`
	ClickDown: ((x: number?, y: number?) -> ())?;
	--- `.MouseButton1Up`
	ClickUp: ((x: number?, y: number?) -> ())?;
	--- `.MouseButton2Down`
	RClickDown: ((x: number?, y: number?) -> ())?;
	--- `.MouseButton2Up`
	RClickUp: ((x: number?, y: number?) -> ())?;
	--- `.MouseEnter` \
	--- `.SelectionGained`
	Enter: ((x: number?, y: number?) -> ())?;
	--- `.MouseLeave` \
	--- `.SelectionLost`
	Leave: ((x: number?, y: number?) -> ())?;
	--- `.MouseMoved`
	Move: ((x: number?, y: number?) -> ())?;
}

export type ButtonSounds = {
	--- `.MouseButton1Up`
	Click: string?;
	--- `.MouseButton2Up`
	RClick: string?;
	--- `.MouseEnter` \
	--- `.SelectionGained`
	Enter: string?;
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

export type LeftOrRight =
	| "Left"
	| "Right"

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