#pragma once

#include "CoreMinimal.h"

class ULawnGridComponent;

/**
 * The checklist on screen: cut the front, side and back yards, and trim
 * the edges the mower cannot reach. Each goal counts its own cells of the
 * lawn and ticks off once nearly all of them are cut. Ported from the Godot
 * version's Objectives.
 */
struct LAWNWRANGLER_API FLawnObjectives
{
	enum EGoal : int32 { Front = 0, Side = 1, Back = 2, Trim = 3, Count = 4 };

	static const TCHAR* Name(int32 Goal);

	/** A goal is done at this share of its cells; finishing still needs 99% overall. */
	static constexpr float DonePercent = 97.f;
	/** Cells this close (in cells) to the fence or anything blocked are edges. */
	static constexpr int32 EdgeCells = 2;

	int32 Totals[Count] = {0, 0, 0, 0};
	int32 Cuts[Count] = {0, 0, 0, 0};

	/**
	 * SideFrom and SideTo are where the side yard starts and ends, in cm from
	 * the back fence; less is the back yard and more the front.
	 */
	void Setup(const ULawnGridComponent& Lawn, float SideFrom, float SideTo);

	/** Call for every cell that gets cut. */
	void OnCellCut(int32 X, int32 Y);

	float Percent(int32 Goal) const;
	bool IsDone(int32 Goal) const { return Percent(Goal) >= DonePercent; }

private:
	/** Goal bits for each cell: its yard (1 << zone) and 1 << Trim for edges. */
	TArray<uint8> Goals;
	int32 Columns = 0;

	static bool NearEdge(const ULawnGridComponent& Lawn, int32 X, int32 Y);
};
