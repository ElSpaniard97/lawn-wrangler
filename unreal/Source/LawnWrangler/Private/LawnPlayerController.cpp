#include "LawnPlayerController.h"

#include "Components/InputComponent.h"
#include "Kismet/GameplayStatics.h"

void ALawnPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();
	InputComponent->BindAction(TEXT("Pause"), IE_Pressed, this, &ALawnPlayerController::OnPause).bExecuteWhenPaused = true;
	InputComponent->BindAction(TEXT("Restart"), IE_Pressed, this, &ALawnPlayerController::OnRestart).bExecuteWhenPaused = true;
	FInputKeyBinding& Any = InputComponent->BindKey(EKeys::AnyKey, IE_Pressed, this, &ALawnPlayerController::OnAnyKey);
	Any.bConsumeInput = false;
	Any.bExecuteWhenPaused = true;
}

void ALawnPlayerController::OnPause()
{
	SetPause(!IsPaused());
}

void ALawnPlayerController::OnRestart()
{
	SetPause(false);
	UGameplayStatics::OpenLevel(this, FName(*UGameplayStatics::GetCurrentLevelName(this)));
}

void ALawnPlayerController::OnAnyKey(FKey Key)
{
	bUsingGamepad = Key.IsGamepadKey();
}
