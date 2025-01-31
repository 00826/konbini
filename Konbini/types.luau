--- Animation.luau

export type AnimLibraryEntry = {
	Id: string?;
	Priority: Enum.AnimationPriority?;
	Animation: Animation?;
	[string]: unknown;
}

export type AnimController = {
	Rig: Model;
	AnimPlayer: AnimationController|Humanoid;
	Animator: Animator;

	ActionTrack: AnimationTrack?;
	LoopTrack: AnimationTrack?;
}

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

export type ThumbstickDirection =
	| "Up"
	| "Down"
	| "Left"
	| "Right"
	| "None"

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

	[string]: unknown;
};

--- Instance.luau

export type TransparencyController = {
	Rig: any;

	TargetTransparency: number;
	RealTransparency: number;

	Cache: {Instance}; --- BasePart | Decal
	DescendantAdded: RBXScriptConnection?;
	DescendantRemoving: RBXScriptConnection?;

	Disconnected: boolean;
	Disconnect: () -> ();
}

export type Tree = {
	ClassName: string;
	Children: { Tree }?;
	Parent: Instance?;

	[string]: unknown;
}

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

--- Network.luau

export type ClientArg = 
	| nil
	| number
	| Player
	| { number|Player }
	| (Player) -> boolean

--- Patronage.luau

export type ReceiptInfo = {
	--- unique purchase id
	PurchaseId: string;
	--- purchaser userid
	PlayerId: number;
	--- devproduct id
	ProductId: number;
	--- placeid of purchase
	PlaceIdWherePurchased: number;
	--- currency spent
	CurrencySpent: number;
	--- Enum.CurrencyType.Robux
	CurrencyType: Enum.CurrencyType;
}

export type PolicyKey = 
	--- ads
	| "AreAdsAllowed"
	--- lootboxes
	| "ArePaidRandomItemsRestricted"
	--- | "AllowedExternalLinkReferences"
	--- off platform sharing
	| "IsContentSharingAllowed"
	--- commerce
	| "IsEligibleToPurchaseCommerceProduct"
	--- subscriptions
	| "IsEligibleToPurchaseSubscription"
	--- trading
	| "IsPaidItemTradingAllowed"
	--- china
	| "IsSubjectToChinaPolicies"
	--- (unknown/undefined)
	| string --- account for undefined policies that may in fact exist

export type MinProduct = {
	--- devproduct or gamepass
	Type: "DevProduct"|"Gamepass";
	--- devproduct or gamepass id
	Id: number;
	[string]: unknown
}

export type PatronageProfile = {
	--- number describing the player userid of this profile
	UserId: number;
	--- 2-wide string (country code) describing player region
	Region: string;
	--- boolean describing if this userid has roblox premium subscription
	IsPremium: boolean;
	--- array describing group membership states of this userid with respect to patronage config
	Groups: { { GroupId: number; Rank: number; } };
	--- binary string describing policyservice restrictions appled to this userid
	PolicyString: string;
	--- array describing gamepasses that are owned by this userid
	Gamepasses: {number};
	--- array describing the patronage lists where this userid is present
	Lists: {string};
}

--- Stats.luau

export type StatusAddMul = {
	--- additive
	Add: number?;
	--- multiplicative
	Mul: number?;
}

export type StatusManifestTable = {
	[string]: {
		Values: {
			[string]: StatusAddMul;
		};
	} & {[string]: unknown};
}

export type MatrixEntryTable = {
	[string]: {

	} & {[string]: unknown};
}

export type MatrixSourceTable = { string }

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