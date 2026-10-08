#include "Misc/AutomationTest.h"
#include "Engine/World.h"
#include "GameFramework/SpringArmComponent.h"
#include "LawnGridComponent.h"
#include "LawnMower.h"
#include "LawnWalker.h"

#if WITH_DEV_AUTOMATION_TESTS

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnCameraCollision,
    "LawnWrangler.Pawns.CameraCollision",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLawnCameraCollision::RunTest(const FString& Parameters)
{
    for (const USpringArmComponent* Arm : {
        GetDefault<ALawnMower>()->CameraArm.Get(),
        GetDefault<ALawnWalker>()->CameraArm.Get()})
    {
        TestTrue(TEXT("camera avoids environment"), Arm->bDoCollisionTest);
        TestEqual(TEXT("camera uses camera collision channel"),
            Arm->ProbeChannel.GetValue(), ECC_Camera);
        TestTrue(TEXT("camera has a nonzero probe"), Arm->ProbeSize > 0.f);
    }
    return true;
}

IMPLEMENT_SIMPLE_AUTOMATION_TEST(FLawnCompletionStopsPawns,
    "LawnWrangler.Pawns.CompletionStopsMovementAndCutting",
    EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)

bool FLawnCompletionStopsPawns::RunTest(const FString& Parameters)
{
    UWorld* World = UWorld::CreateWorld(EWorldType::Game, false);
    ALawnMower* Mower = World->SpawnActor<ALawnMower>();
    ALawnWalker* Walker = World->SpawnActor<ALawnWalker>();
    ULawnGridComponent* Grid = NewObject<ULawnGridComponent>();
    Grid->SealLayout();
    Mower->Lawn = Grid;
    Walker->Lawn = Grid;
    Mower->MeasuredSpeed = Walker->MeasuredSpeed = 100.f;
    Mower->bCutting = Walker->bCutting = true;
    const FVector MowerBefore = Mower->GetActorLocation();
    const FVector WalkerBefore = Walker->GetActorLocation();
    Mower->StopGameplay();
    Walker->StopGameplay();
    Mower->Drive(1.f, 1.f, 1.f);
    Walker->Walk(1.f, 1.f, 1.f);
    TestEqual(TEXT("mower stops"), Mower->GetActorLocation(), MowerBefore);
    TestEqual(TEXT("walker stops"), Walker->GetActorLocation(), WalkerBefore);
    TestEqual(TEXT("no grass cut after finish"), Grid->CutCount, 0);
    TestEqual(TEXT("mower speed resets"), Mower->MeasuredSpeed, 0.f);
    TestEqual(TEXT("walker speed resets"), Walker->MeasuredSpeed, 0.f);
    TestFalse(TEXT("mower cutting resets"), Mower->bCutting);
    TestFalse(TEXT("walker cutting resets"), Walker->bCutting);
    World->DestroyWorld(false);
    return true;
}
#endif
