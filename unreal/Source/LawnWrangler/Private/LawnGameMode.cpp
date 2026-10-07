#include "LawnGameMode.h"

#include "LawnHUD.h"
#include "LawnPlayerController.h"

ALawnGameMode::ALawnGameMode()
{
	PlayerControllerClass = ALawnPlayerController::StaticClass();
	HUDClass = ALawnHUD::StaticClass();
	// No default pawn: the yard spawns the mower and possesses it.
	DefaultPawnClass = nullptr;
}
