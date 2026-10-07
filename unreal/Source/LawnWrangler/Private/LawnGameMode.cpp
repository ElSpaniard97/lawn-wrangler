#include "LawnGameMode.h"

#include "Engine/World.h"
#include "EngineUtils.h"
#include "LawnHUD.h"
#include "LawnPlayerController.h"
#include "LawnYard.h"

ALawnGameMode::ALawnGameMode()
{
	PlayerControllerClass = ALawnPlayerController::StaticClass();
	HUDClass = ALawnHUD::StaticClass();
	// No default pawn: the yard spawns the mower and possesses it.
	DefaultPawnClass = nullptr;
}

void ALawnGameMode::StartPlay()
{
	bool bHasYard = false;
	for (TActorIterator<ALawnYard> It(GetWorld()); It; ++It)
	{
		bHasYard = true;
		break;
	}
	if (!bHasYard)
	{
		GetWorld()->SpawnActor<ALawnYard>(ALawnYard::StaticClass(), FTransform::Identity);
	}
	Super::StartPlay();
}
