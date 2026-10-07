#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "LawnGameMode.generated.h"

/**
 * Uses the Lawn Wrangler controller and HUD. If the level has no yard, it
 * spawns one at the world origin, so pressing Play in any level (even an
 * empty one) starts the game. The yard spawns the mower and walker itself.
 */
UCLASS()
class LAWNWRANGLER_API ALawnGameMode : public AGameModeBase
{
	GENERATED_BODY()

public:
	ALawnGameMode();

	virtual void StartPlay() override;
};
