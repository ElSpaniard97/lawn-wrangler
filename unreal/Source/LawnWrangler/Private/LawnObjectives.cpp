#include "LawnObjectives.h"

#include "LawnGridComponent.h"

const TCHAR* FLawnObjectives::Name(int32 Goal)
{
	static const TCHAR* Names[] = {
		TEXT("Cut the front yard"),
		TEXT("Cut the side yard"),
		TEXT("Cut the back yard"),
		TEXT("Trim around objects"),
	};
	return Names[FMath::Clamp(Goal, 0, Count - 1)];
}

void FLawnObjectives::Setup(const ULawnGridComponent& Lawn, float SideFrom, float SideTo)
{
	Columns = Lawn.Columns;
	Goals.Init(0, Lawn.Columns * Lawn.Rows);
	for (int32 Goal = 0; Goal < Count; ++Goal)
	{
		Totals[Goal] = 0;
		Cuts[Goal] = 0;
	}
	for (int32 Y = 0; Y < Lawn.Rows; ++Y)
	{
		const float Centimetres = (Y + 0.5f) * Lawn.CellSize;
		const int32 Zone = Centimetres < SideFrom ? Back : (Centimetres <= SideTo ? Side : Front);
		for (int32 X = 0; X < Lawn.Columns; ++X)
		{
			const uint8 Value = Lawn.GetCell(X, Y);
			if (Value == LawnCell::Blocked)
			{
				continue;
			}
			uint8 Bits = 1 << Zone;
			if (NearEdge(Lawn, X, Y))
			{
				Bits |= 1 << Trim;
			}
			Goals[Y * Columns + X] = Bits;
			for (int32 Goal = 0; Goal < Count; ++Goal)
			{
				if (Bits & (1 << Goal))
				{
					++Totals[Goal];
					if (Value != LawnCell::Tall)
					{
						++Cuts[Goal];
					}
				}
			}
		}
	}
}

bool FLawnObjectives::NearEdge(const ULawnGridComponent& Lawn, int32 X, int32 Y)
{
	for (int32 DY = -EdgeCells; DY <= EdgeCells; ++DY)
	{
		for (int32 DX = -EdgeCells; DX <= EdgeCells; ++DX)
		{
			const int32 NX = X + DX;
			const int32 NY = Y + DY;
			if (NX < 0 || NY < 0 || NX >= Lawn.Columns || NY >= Lawn.Rows)
			{
				return true;
			}
			if (Lawn.GetCell(NX, NY) == LawnCell::Blocked)
			{
				return true;
			}
		}
	}
	return false;
}

void FLawnObjectives::OnCellCut(int32 X, int32 Y)
{
	const uint8 Bits = Goals.IsValidIndex(Y * Columns + X) ? Goals[Y * Columns + X] : 0;
	for (int32 Goal = 0; Goal < Count; ++Goal)
	{
		if (Bits & (1 << Goal))
		{
			++Cuts[Goal];
		}
	}
}

float FLawnObjectives::Percent(int32 Goal) const
{
	return Totals[Goal] > 0 ? 100.f * Cuts[Goal] / Totals[Goal] : 100.f;
}
