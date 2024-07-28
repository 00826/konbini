--- Animation.luau types

export type AnimLibraryKey		= Enum.HumanoidRigType | string
export type AnimLibraryEntry	= {
	Id: string;
	Priority: Enum.AnimationPriority;
	AnimInstance: Animation?;
}
export type StepSoundKey		= Enum.Material | string

--- Bar.luau types

export type Axes				= {
	X: number?;
	Y: number?;
	Z: number?;
}

--- Bind.luau types

export type Disconnect			= () -> ()

--- Collisions.luau

export type CastShape			= "Box" | "Ball"
export type CastList			= "Whitelist" | "Blacklist"

--- Data.luau

export type SaveTemplate		= typeof(require(script.Parent.Data.Config).SaveTemplate)

--- Inputs.luau

export type DynamicGamepadKey	= "Y" | "X" | "B" | "A" | "L1" | "R1" | "L2" | "R2" | "Center"

--- Instance.luau

export type Tree				= {
	ClassName: string;
	Children: { Tree }?;
	Parent: Instance?;
} & { [string]: any }

--- Interface.luau

export type ButtonFunctions		= {
	["ClickDown"]: ((x: number?, y: number?) -> ())?;
	["ClickUp"]: ((x: number?, y: number?) -> ())?;
	["RClickDown"]: ((x: number?, y: number?) -> ())?;
	["RClickUp"]: ((x: number?, y: number?) -> ())?;
	["Enter"]: ((x: number?, y: number?) -> ())?;
	["Leave"]: ((x: number?, y: number?) -> ())?;
	["Move"]: ((x: number?, y: number?) -> ())?;
}

export type SpriteLayout		= {
	Id: string; -- rbxassetid://
	Size: Vector2; -- sprite size
	Padding: number; -- sheet padding
	Width: number; -- sheet dimensions
}

export type Sprite				= {
	Position: number; -- position of sprite (L -> R, T -> B)
	Layout: SpriteLayout -- sprite layout
}

export type LeftOrRight			= "Left" | "Right"

--- Math.luau

export type UnitCircleVertex	= { X: number, Z: number }

--- Network.luau

export type Remote				= RemoteEvent|UnreliableRemoteEvent|any
export type ClientArg			= 
	nil |
	number |
	Player |
	{ number|Player } |
	((Player) -> boolean)

--- Rig.luau

export type MoverClass			= "BodyGyro" | "BodyVelocity" | "BodyPosition" | "VectorForce"

--- Time.luau

export type Notation			= "DD:HH:MM:SS" | "HH:MM:SS" | "MM:SS" | "M:SS"
export type Format				= number | "Hour" | "Biphase" | "Day" | "Week" | "Season" | "Biseason" | "Year"
export type FormatResult		= {
	Timestamp: string;
	Seed: number;
	Until: number;
}

--- Vector3.luau

export type xyzType				= Vector3 | Vector3int16  | PVInstance | CFrame -- anything that can be represented as pure `x, y, z`

return table.create(0)