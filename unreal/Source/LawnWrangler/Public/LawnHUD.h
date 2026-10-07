#pragma once

#include "CoreMinimal.h"
#include "GameFramework/HUD.h"
#include "LawnHUD.generated.h"

class ALawnYard;

/**
 * The on-screen display from the Godot version, drawn with the canvas so it
 * needs no editor assets: the objectives checklist, progress bar, minimap,
 * speedometer with fuel gauge, keyboard or gamepad prompts, hints, and the
 * pause and finish screens. Laid out for 1280 x 720 and scaled to the window.
 */
UCLASS()
class LAWNWRANGLER_API ALawnHUD : public AHUD
{
	GENERATED_BODY()

public:
	virtual void DrawHUD() override;

private:
	TWeakObjectPtr<ALawnYard> Yard;
	float S = 1.f;

	void Panel(float X, float Y, float W, float H);
	void Text(const FString& Value, float X, float Y, float Size, const FLinearColor& Color, bool bCenter = false);
	void Arc(const FVector2D& Center, float Radius, float From, float To, const FLinearColor& Color, float Thickness);

	void DrawObjectives(ALawnYard& InYard);
	void DrawProgress(ALawnYard& InYard);
	void DrawMinimap(ALawnYard& InYard);
	void DrawGauge(ALawnYard& InYard);
	void DrawPrompts();
	void DrawOverlay(ALawnYard& InYard);

	static FString FormatTime(float Seconds);
};
