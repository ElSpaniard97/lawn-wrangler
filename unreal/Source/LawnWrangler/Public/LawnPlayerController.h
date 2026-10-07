#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "LawnPlayerController.generated.h"

/** Pause and restart, which work whether you are riding or walking, and gamepad detection for the prompts. */
UCLASS()
class LAWNWRANGLER_API ALawnPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	/** True when a gamepad was the last thing used, so the HUD shows gamepad prompts. */
	UPROPERTY(BlueprintReadOnly, Category = "Input")
	bool bUsingGamepad = false;

protected:
	virtual void SetupInputComponent() override;

private:
	void OnPause();
	void OnRestart();
	void OnAnyKey(FKey Key);
};
