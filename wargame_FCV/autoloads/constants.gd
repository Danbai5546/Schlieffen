extends Node

const ROUNDS = [
	{
		"date": "ROUND1: \nAug 25th ~ Aug 29th",
		"activatable_pawns":
		{
			Pawn.Type.GE: 1,
			Pawn.Type.FR: 1,
		}
	},
	{
		"date": "ROUND2: \nAug 30th ~ Sep 3th",
		"activatable_pawns":
		{
			Pawn.Type.GE: 1,
			Pawn.Type.FR: 1,
		}
	},
	{
		"date": "ROUND3: \nSep 4th ~ Sep 8th",
		"activatable_pawns":
		{
			Pawn.Type.GE: 2,
			Pawn.Type.FR: 1,
			Pawn.Type.BR: 1,
		}
	},
	{
		"date": "ROUND4: \nSep 9th ~ Sep 13th",
		"activatable_pawns":
		{
			Pawn.Type.GE: 2,
			Pawn.Type.FR: 1,
		}
	},
	{
		"date": "ROUND5: \nSep 14th ~ Sep 18th",
		"activatable_pawns":
		{
			Pawn.Type.GE: 1,
			Pawn.Type.FR: 1,
		}
	}
]

enum Phase {
	ACTIVATE,
	MOVE,
	BATTLE_A,
	BATTLE_G
}

var AI_coords_dic := {
	"AMIENS": Vector2i(0, 0),
	"PARIS": Vector2i(-1, 1),
	"SOSSIONS": Vector2i(0, 1),
	"SEDAN": Vector2i(1, 1),
	"MELUN": Vector2i(0, 2),
	"CHALONS": Vector2i(1, 2),
	"VERDUN": Vector2i(2, 2),
	"LUXEMBOURG": Vector2i(2, 1),
	"LIEGE": Vector2i(2, 0),
	"LE CATEAU": Vector2i(1, 0),
	"TROYES": Vector2i(0, 3),
	"LANGRES": Vector2i(1, 3)
}

var pawn_faction := {
	"Pawn": Block.Faction.ALLIES,
	"Pawn2": Block.Faction.ALLIES,
	"Pawn3": Block.Faction.ALLIES,
	"Pawn4": Block.Faction.ALLIES,
	"Pawn5": Block.Faction.ALLIES,
	"Pawn6": Block.Faction.ALLIES,
	"Pawn7": Block.Faction.ALLIES,
	"Pawn8": Block.Faction.ALLIES,
	"Pawn9": Block.Faction.GERMAN,
	"Pawn10": Block.Faction.GERMAN,
	"Pawn11": Block.Faction.GERMAN,
	"Pawn12": Block.Faction.GERMAN,
	"Pawn13": Block.Faction.GERMAN,
	"Pawn14": Block.Faction.GERMAN,
	"Pawn15": Block.Faction.GERMAN,
	"Pawn16": Block.Faction.GERMAN,
}
