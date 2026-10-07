#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "LawnGameMode.generated.h"

/** Uses the Lawn Wrangler controller and HUD; the yard spawns the mower and walker itself. */
UCLASS()
class LAWNWRANGLER_API ALawnGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ALawnGameMode();
};
