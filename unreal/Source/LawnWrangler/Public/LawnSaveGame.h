#pragma once

#include "CoreMinimal.h"
#include "GameFramework/SaveGame.h"
#include "LawnSaveGame.generated.h"

/** The personal best, kept in the player's save folder. */
UCLASS()
class LAWNWRANGLER_API ULawnSaveGame : public USaveGame
{
	GENERATED_BODY()

public:
	/** Best time for the first yard, in seconds; 0 means none yet. */
	UPROPERTY()
	float BestTime = 0.f;
};
