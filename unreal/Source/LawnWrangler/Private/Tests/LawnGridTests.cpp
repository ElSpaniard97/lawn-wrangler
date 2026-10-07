// Automation tests, ported from the Godot version's grid and checklist
// tests. Run them in the editor from Tools > Session Frontend > Automation,
// filtered to "LawnWrangler", or from the command line with
//   UnrealEditor-Cmd LawnWrangler.uproject -ExecCmds="Automation RunTests LawnWrangler; Quit" -unattended -nullrhi

#include "Misc/AutomationTest.h"
#include "LawnGridComponent.h"
#include "LawnObjectives.h"

#if WITH_DEV_AUTOMATION_TESTS

namespace
{
	ULawnGridComponent* MakeGrid(int32 Columns, int32 Rows)
	{
		ULawnGridComponent* Grid = NewObject<ULawnGridComponent>();
		Grid->Columns = Columns;
		Grid->Rows = Rows;
		Grid->CellSize = 25.f;
		Grid->ResetCells();
		return Grid;
	}
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnGridCutsEachCellOnce, "LawnWrangler.Grid.CutsEachCellOnce",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FLawnGridCutsEachCellOnce::RunTest(const FString& Parameters)
{
	ULawnGridComponent* Grid = MakeGrid(40, 40);
	Grid->SealLayout();
	const int32 First = Grid->CutAt(FVector(500.f, 500.f, 0.f), 60.f, LawnCell::StripeA);
	TestTrue(TEXT("cutting cuts some cells"), First > 0);
	TestEqual(TEXT("cutting the same spot again cuts nothing"), Grid->CutAt(FVector(500.f, 500.f, 0.f), 60.f, LawnCell::StripeA), 0);
	TestEqual(TEXT("cut count matches"), Grid->CutCount, First);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnGridBlockedNeverCounts, "LawnWrangler.Grid.BlockedCellsNeverCount",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FLawnGridBlockedNeverCounts::RunTest(const FString& Parameters)
{
	ULawnGridComponent* Grid = MakeGrid(40, 40);
	Grid->BlockCircle(FVector2D(500.f, 500.f), 100.f);
	Grid->BlockRect(FBox2D(FVector2D(0.f, 0.f), FVector2D(250.f, 250.f)));
	Grid->SealLayout();
	TestTrue(TEXT("blocked cells are left out of the total"), Grid->Total < 40 * 40);
	TestEqual(TEXT("blocked cells cannot be cut"), Grid->CutAt(FVector(500.f, 500.f, 0.f), 50.f, LawnCell::StripeA), 0);
	TestEqual(TEXT("a corner rect is blocked"), Grid->GetCell(0, 0), LawnCell::Blocked);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnGridSweptCutLeavesNoGaps, "LawnWrangler.Grid.SweptCutLeavesNoGaps",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FLawnGridSweptCutLeavesNoGaps::RunTest(const FString& Parameters)
{
	ULawnGridComponent* Grid = MakeGrid(40, 40);
	Grid->SealLayout();
	// One big jump, as on a slow frame: every cell along the line is still cut.
	Grid->CutSegment(FVector(50.f, 500.f, 0.f), FVector(950.f, 500.f, 0.f), 40.f, LawnCell::StripeA);
	for (int32 X = 2; X < 38; ++X)
	{
		if (Grid->GetCell(X, 20) == LawnCell::Tall)
		{
			AddError(FString::Printf(TEXT("gap left at column %d"), X));
			break;
		}
	}
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnGridStripesAlternate, "LawnWrangler.Grid.BackAndForthPassesAlternateStripes",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FLawnGridStripesAlternate::RunTest(const FString& Parameters)
{
	TestEqual(TEXT("one way is the light stripe"), ULawnGridComponent::StripeFor(FVector(1.f, 0.2f, 0.f)), LawnCell::StripeA);
	TestEqual(TEXT("coming back is the dark stripe"), ULawnGridComponent::StripeFor(FVector(-1.f, 0.2f, 0.f)), LawnCell::StripeB);
	TestEqual(TEXT("along Y works the same way"), ULawnGridComponent::StripeFor(FVector(0.1f, -1.f, 0.f)), LawnCell::StripeB);
	return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnObjectivesTickOffByYard, "LawnWrangler.Objectives.TickOffByYard",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ClientContext | EAutomationTestFlags::EngineFilter)

bool FLawnObjectivesTickOffByYard::RunTest(const FString& Parameters)
{
	ULawnGridComponent* Grid = MakeGrid(40, 40);
	Grid->BlockRect(FBox2D(FVector2D(0.f, 300.f), FVector2D(250.f, 700.f)));
	Grid->SealLayout();
	FLawnObjectives Goals;
	Goals.Setup(*Grid, 300.f, 700.f);
	for (int32 Goal = 0; Goal < FLawnObjectives::Count; ++Goal)
	{
		TestTrue(FString::Printf(TEXT("%s has cells and starts unticked"), FLawnObjectives::Name(Goal)), Goals.Totals[Goal] > 0 && !Goals.IsDone(Goal));
	}
	// Cut every cell in the front yard (past 700 cm).
	for (int32 Y = 0; Y < Grid->Rows; ++Y)
	{
		for (int32 X = 0; X < Grid->Columns; ++X)
		{
			if ((Y + 0.5f) * Grid->CellSize > 700.f && Grid->CutAt(Grid->CellCenter(X, Y), 1.f, LawnCell::StripeA) > 0)
			{
				Goals.OnCellCut(X, Y);
			}
		}
	}
	TestTrue(TEXT("cutting the front yard ticks it off"), Goals.IsDone(FLawnObjectives::Front));
	TestFalse(TEXT("the back yard stays unticked"), Goals.IsDone(FLawnObjectives::Back));
	return true;
}

#endif
