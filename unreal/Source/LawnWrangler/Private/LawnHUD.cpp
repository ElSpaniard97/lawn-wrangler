#include "LawnHUD.h"

#include "Engine/Canvas.h"
#include "Engine/Engine.h"
#include "Engine/Font.h"
#include "EngineUtils.h"
#include "LawnGridComponent.h"
#include "LawnMower.h"
#include "LawnPlayerController.h"
#include "LawnWalker.h"
#include "LawnYard.h"

namespace
{
	const FLinearColor PanelColor(0.05f, 0.08f, 0.06f, 0.62f);
	const FLinearColor Accent(0.55f, 0.85f, 0.35f);
	const FLinearColor Low(0.95f, 0.6f, 0.4f);
	const FLinearColor Soft(0.85f, 0.85f, 0.85f);
	constexpr float MpsPerCmps = 0.02237f; // cm/s to mph
	constexpr float DialMph = 10.f;
}

FString ALawnHUD::FormatTime(float Seconds)
{
	const int32 Whole = FMath::FloorToInt(Seconds);
	return FString::Printf(TEXT("%d:%02d"), Whole / 60, Whole % 60);
}

void ALawnHUD::Panel(float X, float Y, float W, float H)
{
	DrawRect(PanelColor, X * S, Y * S, W * S, H * S);
}

void ALawnHUD::Text(const FString& Value, float X, float Y, float Size, const FLinearColor& Color, bool bCenter)
{
	UFont* Font = GEngine->GetLargeFont();
	const float Scale = Size / 24.f * S;
	float W = 0.f, H = 0.f;
	if (bCenter)
	{
		GetTextSize(Value, W, H, Font, Scale);
	}
	DrawText(Value, Color, X * S - W / 2.f, Y * S, Font, Scale);
}

void ALawnHUD::Arc(const FVector2D& Center, float Radius, float From, float To, const FLinearColor& Color, float Thickness)
{
	const int32 Segments = FMath::Max(2, FMath::CeilToInt(FMath::Abs(To - From) / 0.12f));
	for (int32 I = 0; I < Segments; ++I)
	{
		const float A = FMath::Lerp(From, To, float(I) / Segments);
		const float B = FMath::Lerp(From, To, float(I + 1) / Segments);
		const FVector2D P = (Center + FVector2D(FMath::Cos(A), FMath::Sin(A)) * Radius) * S;
		const FVector2D Q = (Center + FVector2D(FMath::Cos(B), FMath::Sin(B)) * Radius) * S;
		DrawLine(P.X, P.Y, Q.X, Q.Y, Color, Thickness * S);
	}
}

void ALawnHUD::DrawHUD()
{
	Super::DrawHUD();
	if (!Canvas)
	{
		return;
	}
	if (!Yard.IsValid())
	{
		if (TActorIterator<ALawnYard> It(GetWorld()); It)
		{
			Yard = *It;
		}
	}
	if (!Yard.IsValid())
	{
		return;
	}
	// Lay out on a 720-pixel-tall screen, as wide as the window's shape allows.
	S = Canvas->ClipY / 720.f;
	ALawnYard& Y = *Yard;
	DrawObjectives(Y);
	DrawProgress(Y);
	DrawMinimap(Y);
	DrawGauge(Y);
	DrawPrompts();
	if (Y.MessageTime > 0.f)
	{
		const float Width = Canvas->ClipX / S;
		Panel(Width / 2.f - 330.f, 640.f, 660.f, 42.f);
		Text(Y.Message, Width / 2.f, 650.f, 16.f, FLinearColor::White, true);
	}
	DrawOverlay(Y);
}

void ALawnHUD::DrawObjectives(ALawnYard& Y)
{
	Panel(20.f, 20.f, 250.f, 190.f);
	Text(TEXT("Mow the Lawn"), 34.f, 30.f, 21.f, FLinearColor::White);
	for (int32 Goal = 0; Goal < FLawnObjectives::Count; ++Goal)
	{
		const float Top = 66.f + Goal * 27.f;
		const bool bDone = Y.Objectives.IsDone(Goal);
		if (bDone)
		{
			DrawRect(Accent, 34.f * S, (Top + 3.f) * S, 16.f * S, 16.f * S);
			DrawLine(37.f * S, (Top + 11.f) * S, 41.f * S, (Top + 15.f) * S, FLinearColor(0.05f, 0.1f, 0.05f), 2.f * S);
			DrawLine(41.f * S, (Top + 15.f) * S, 47.f * S, (Top + 7.f) * S, FLinearColor(0.05f, 0.1f, 0.05f), 2.f * S);
		}
		else
		{
			const FLinearColor Edge(1.f, 1.f, 1.f, 0.85f);
			DrawLine(34.f * S, (Top + 3.f) * S, 50.f * S, (Top + 3.f) * S, Edge, 1.5f * S);
			DrawLine(50.f * S, (Top + 3.f) * S, 50.f * S, (Top + 19.f) * S, Edge, 1.5f * S);
			DrawLine(50.f * S, (Top + 19.f) * S, 34.f * S, (Top + 19.f) * S, Edge, 1.5f * S);
			DrawLine(34.f * S, (Top + 19.f) * S, 34.f * S, (Top + 3.f) * S, Edge, 1.5f * S);
		}
		Text(FLawnObjectives::Name(Goal), 60.f, Top, 15.f, bDone ? FLinearColor(0.7f, 0.7f, 0.7f) : FLinearColor(0.92f, 0.92f, 0.92f));
	}
	const FString Best = Y.BestTime > 0.f ? FormatTime(Y.BestTime) : TEXT("--:--");
	Text(FString::Printf(TEXT("Time %s   Best %s"), *FormatTime(Y.Elapsed), *Best), 34.f, 178.f, 14.f, FLinearColor(0.78f, 0.78f, 0.78f));
}

void ALawnHUD::DrawProgress(ALawnYard& Y)
{
	const float Width = Canvas->ClipX / S;
	const float Left = Width - 20.f - 310.f;
	const float Percent = FMath::FloorToFloat(Y.Lawn->PercentCut());
	Panel(Left, 20.f, 310.f, 86.f);
	Text(TEXT("Progress"), Left + 14.f, 28.f, 18.f, FLinearColor::White);
	Text(FString::Printf(TEXT("%d%%"), int32(Percent)), Left + 270.f, 28.f, 18.f, FLinearColor::White, true);
	DrawRect(FLinearColor(1.f, 1.f, 1.f, 0.18f), (Left + 14.f) * S, 60.f * S, 282.f * S, 10.f * S);
	DrawRect(Accent, (Left + 14.f) * S, 60.f * S, 282.f * Percent / 100.f * S, 10.f * S);
	Text(FString::Printf(TEXT("%d patches left"), Y.Lawn->CellsLeft()), Left + 14.f, 76.f, 13.f, Soft);
}

void ALawnHUD::DrawMinimap(ALawnYard& Y)
{
	// The whole yard from above, with the house roof and where you are.
	const float H = 210.f;
	const float W = H * ALawnYard::Lot.X / ALawnYard::Lot.Y;
	const float Left = 20.f;
	const float Top = 720.f - 20.f - H;
	Panel(Left - 6.f, Top - 6.f, W + 12.f, H + 12.f);
	if (UTexture2D* Map = Y.Lawn->GetMapTexture())
	{
		DrawTexture(Map, Left * S, Top * S, W * S, H * S, 0.f, 0.f, 1.f, 1.f);
	}
	const FVector2D Roof0 = (ALawnYard::HouseCenter - ALawnYard::HouseSize / 2.f) / ALawnYard::Lot;
	const FVector2D RoofSize = ALawnYard::HouseSize / ALawnYard::Lot;
	DrawRect(FLinearColor(0.66f, 0.66f, 0.68f), (Left + Roof0.X * W) * S, (Top + Roof0.Y * H) * S, RoofSize.X * W * S, RoofSize.Y * H * S);
	auto MapPoint = [&](const FVector& At)
	{
		const FVector2D Fraction(FMath::Clamp(At.X / ALawnYard::Lot.X, 0.f, 1.f), FMath::Clamp(At.Y / ALawnYard::Lot.Y, 0.f, 1.f));
		return (FVector2D(Left, Top) + Fraction * FVector2D(W, H)) * S;
	};
	if (Y.Mower)
	{
		const FVector2D At = MapPoint(Y.Mower->GetActorLocation());
		const FVector Forward = Y.Mower->GetActorForwardVector();
		const FVector2D Ahead = FVector2D(Forward.X, Forward.Y).GetSafeNormal();
		const FVector2D Side(-Ahead.Y, Ahead.X);
		const FVector2D Tip = At + Ahead * 9.f * S;
		const FVector2D A = At - Ahead * 6.f * S + Side * 6.f * S;
		const FVector2D B = At - Ahead * 6.f * S - Side * 6.f * S;
		DrawLine(Tip.X, Tip.Y, A.X, A.Y, FLinearColor::White, 2.f * S);
		DrawLine(A.X, A.Y, B.X, B.Y, FLinearColor::White, 2.f * S);
		DrawLine(B.X, B.Y, Tip.X, Tip.Y, FLinearColor::White, 2.f * S);
	}
	if (!Y.bOnMower && Y.Walker)
	{
		const FVector2D At = MapPoint(Y.Walker->GetActorLocation());
		DrawRect(FLinearColor::Black, At.X - 4.f * S, At.Y - 4.f * S, 8.f * S, 8.f * S);
		DrawRect(FLinearColor::White, At.X - 2.5f * S, At.Y - 2.5f * S, 5.f * S, 5.f * S);
	}
}

void ALawnHUD::DrawGauge(ALawnYard& Y)
{
	const float Width = Canvas->ClipX / S;
	const float Left = Width - 20.f - 248.f;
	const float Top = 720.f - 20.f - 178.f;
	Panel(Left, Top, 248.f, 178.f);
	const float Speed = Y.bOnMower ? (Y.Mower ? Y.Mower->MeasuredSpeed : 0.f) : (Y.Walker ? Y.Walker->MeasuredSpeed : 0.f);
	const float Mph = Speed * MpsPerCmps;
	const FVector2D Center(Left + 92.f, Top + 94.f);
	const float Start = FMath::DegreesToRadians(135.f);
	const float Sweep = FMath::DegreesToRadians(270.f);
	Arc(Center, 64.f, Start, Start + Sweep, FLinearColor(1.f, 1.f, 1.f, 0.16f), 10.f);
	const float Fraction = FMath::Clamp(Mph / DialMph, 0.f, 1.f);
	if (Fraction > 0.005f)
	{
		Arc(Center, 64.f, Start, Start + Sweep * Fraction, Accent, 10.f);
	}
	Text(FString::Printf(TEXT("%d"), FMath::RoundToInt(Mph)), Center.X, Center.Y - 30.f, 44.f, FLinearColor::White, true);
	Text(TEXT("MPH"), Center.X, Center.Y + 22.f, 14.f, Soft, true);
	FString Blades = TEXT("Weed eater");
	FLinearColor BladesColor = Accent;
	if (Y.bOnMower && Y.Mower)
	{
		Blades = Y.Mower->bBladesOn ? TEXT("Blades ON") : TEXT("Blades OFF");
		BladesColor = Y.Mower->bBladesOn ? Accent : Low;
	}
	Text(Blades, Center.X, Center.Y + 56.f, 13.f, BladesColor, true);

	// Fuel: a column of segments that empties from the top.
	const float Fuel = Y.Mower ? Y.Mower->Fuel : 1.f;
	const float X = Left + 194.f;
	Text(TEXT("F"), X + 22.f, Top + 34.f, 13.f, Soft);
	Text(TEXT("E"), X + 22.f, Top + 140.f, 13.f, Soft);
	Text(TEXT("FUEL"), X + 7.f, Top + 12.f, 11.f, Soft, true);
	const int32 Segments = 8;
	const int32 Lit = FMath::CeilToInt(Fuel * Segments - 0.001f);
	const FLinearColor Color = Fuel > 0.25f ? Accent : (Fuel > 0.1f ? Low : FLinearColor(0.95f, 0.3f, 0.25f));
	for (int32 I = 0; I < Segments; ++I)
	{
		const bool bOn = Segments - I <= Lit;
		DrawRect(bOn ? Color : FLinearColor(1.f, 1.f, 1.f, 0.14f), X * S, (Top + 36.f + I * 14.f) * S, 14.f * S, 10.f * S);
	}
}

void ALawnHUD::DrawPrompts()
{
	static const TCHAR* Keyboard[][2] = {
		{TEXT("W / S"), TEXT("Drive / walk")}, {TEXT("A / D"), TEXT("Steer")}, {TEXT("Space"), TEXT("Hop off or on")},
		{TEXT("B"), TEXT("Blades on/off")}, {TEXT("P"), TEXT("Pause")}, {TEXT("R"), TEXT("Restart")}};
	static const TCHAR* Gamepad[][2] = {
		{TEXT("RT"), TEXT("Accelerate")}, {TEXT("LT"), TEXT("Reverse")}, {TEXT("L"), TEXT("Steer")},
		{TEXT("X"), TEXT("Toggle blades")}, {TEXT("Y"), TEXT("Hop off or on")}, {TEXT("Start"), TEXT("Pause")}};
	const ALawnPlayerController* PC = Cast<ALawnPlayerController>(PlayerOwner);
	const bool bPad = PC && PC->bUsingGamepad;
	const float Width = Canvas->ClipX / S;
	const float Left = Width - 20.f - 210.f;
	const float Top = 250.f;
	Panel(Left, Top, 210.f, 6 * 30.f + 20.f);
	for (int32 I = 0; I < 6; ++I)
	{
		const TCHAR* const* Row = bPad ? Gamepad[I] : Keyboard[I];
		const float RowTop = Top + 12.f + I * 30.f;
		DrawRect(FLinearColor(1.f, 1.f, 1.f, 0.12f), (Left + 12.f) * S, RowTop * S, 52.f * S, 22.f * S);
		Text(Row[0], Left + 38.f, RowTop + 2.f, 12.f, FLinearColor::White, true);
		Text(Row[1], Left + 76.f, RowTop + 1.f, 14.f, FLinearColor(0.92f, 0.92f, 0.92f));
	}
}

void ALawnHUD::DrawOverlay(ALawnYard& Y)
{
	const bool bPaused = PlayerOwner && PlayerOwner->IsPaused();
	if (!bPaused && !Y.bFinished)
	{
		return;
	}
	const float Width = Canvas->ClipX / S;
	Panel(Width / 2.f - 200.f, 260.f, 400.f, 190.f);
	if (Y.bFinished)
	{
		Text(TEXT("Lawn done!"), Width / 2.f, 280.f, 30.f, FLinearColor::White, true);
		Text(FString::Printf(TEXT("Time %s"), *FormatTime(Y.Elapsed)), Width / 2.f, 330.f, 16.f, Soft, true);
		Text(Y.bNewRecord ? FString(TEXT("New personal best!")) : FString::Printf(TEXT("Personal best %s"), *FormatTime(Y.BestTime)), Width / 2.f, 360.f, 16.f, Soft, true);
		Text(TEXT("Press R to mow again."), Width / 2.f, 400.f, 16.f, Soft, true);
	}
	else
	{
		Text(TEXT("Paused"), Width / 2.f, 290.f, 30.f, FLinearColor::White, true);
		Text(TEXT("Press P or Esc to keep mowing."), Width / 2.f, 350.f, 16.f, Soft, true);
	}
}
