#include "LawnGridComponent.h"

#include "Engine/Texture2D.h"
#include "GameFramework/Actor.h"

ULawnGridComponent::ULawnGridComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	ResetCells();
}

void ULawnGridComponent::ResetCells()
{
	Cells.Init(LawnCell::Tall, Columns * Rows);
	Total = 0;
	CutCount = 0;
	bMaskDirty = true;
}

void ULawnGridComponent::BlockCircle(FVector2D Center, float Radius)
{
	for (int32 Y = 0; Y < Rows; ++Y)
	{
		for (int32 X = 0; X < Columns; ++X)
		{
			const FVector2D Cell((X + 0.5f) * CellSize, (Y + 0.5f) * CellSize);
			if (FVector2D::DistSquared(Cell, Center) <= Radius * Radius)
			{
				Cells[Y * Columns + X] = LawnCell::Blocked;
			}
		}
	}
	bMaskDirty = true;
}

void ULawnGridComponent::BlockRect(const FBox2D& Rect)
{
	for (int32 Y = 0; Y < Rows; ++Y)
	{
		for (int32 X = 0; X < Columns; ++X)
		{
			if (Rect.IsInside(FVector2D((X + 0.5f) * CellSize, (Y + 0.5f) * CellSize)))
			{
				Cells[Y * Columns + X] = LawnCell::Blocked;
			}
		}
	}
	bMaskDirty = true;
}

void ULawnGridComponent::SealLayout()
{
	Total = 0;
	CutCount = 0;
	for (const uint8 Value : Cells)
	{
		if (Value != LawnCell::Blocked)
		{
			++Total;
		}
		if (Value == LawnCell::StripeA || Value == LawnCell::StripeB)
		{
			++CutCount;
		}
	}
	bMaskDirty = true;
}

uint8 ULawnGridComponent::StripeFor(const FVector& Direction)
{
	const float Lead = FMath::Abs(Direction.X) >= FMath::Abs(Direction.Y) ? Direction.X : Direction.Y;
	return Lead >= 0.f ? LawnCell::StripeA : LawnCell::StripeB;
}

FVector ULawnGridComponent::ToGrid(const FVector& World) const
{
	const AActor* Owner = GetOwner();
	return Owner ? Owner->GetActorTransform().InverseTransformPosition(World) : World;
}

FVector ULawnGridComponent::CellCenter(int32 X, int32 Y) const
{
	const FVector Local((X + 0.5f) * CellSize, (Y + 0.5f) * CellSize, 0.f);
	const AActor* Owner = GetOwner();
	return Owner ? Owner->GetActorTransform().TransformPosition(Local) : Local;
}

int32 ULawnGridComponent::CutAt(const FVector& WorldLocation, float Radius, uint8 Stripe)
{
	const FVector Local = ToGrid(WorldLocation);
	const int32 LoX = FMath::Max(0, FMath::FloorToInt((Local.X - Radius) / CellSize));
	const int32 HiX = FMath::Min(Columns - 1, FMath::FloorToInt((Local.X + Radius) / CellSize));
	const int32 LoY = FMath::Max(0, FMath::FloorToInt((Local.Y - Radius) / CellSize));
	const int32 HiY = FMath::Min(Rows - 1, FMath::FloorToInt((Local.Y + Radius) / CellSize));
	const uint8 Value = FMath::Clamp<uint8>(Stripe, LawnCell::StripeA, LawnCell::StripeB);
	int32 NewlyCut = 0;
	for (int32 Y = LoY; Y <= HiY; ++Y)
	{
		for (int32 X = LoX; X <= HiX; ++X)
		{
			uint8& Cell = Cells[Y * Columns + X];
			if (Cell != LawnCell::Tall)
			{
				continue;
			}
			const float DX = (X + 0.5f) * CellSize - Local.X;
			const float DY = (Y + 0.5f) * CellSize - Local.Y;
			if (DX * DX + DY * DY <= Radius * Radius)
			{
				Cell = Value;
				++CutCount;
				++NewlyCut;
				OnCellCut.Broadcast(X, Y, Value);
			}
		}
	}
	if (NewlyCut > 0)
	{
		bMaskDirty = true;
	}
	return NewlyCut;
}

int32 ULawnGridComponent::CutSegment(const FVector& From, const FVector& To, float Radius, uint8 Stripe)
{
	const int32 Steps = FMath::Max(1, FMath::CeilToInt(FVector::Dist(From, To) / (CellSize * 0.5f)));
	int32 NewlyCut = 0;
	for (int32 I = 1; I <= Steps; ++I)
	{
		NewlyCut += CutAt(FMath::Lerp(From, To, float(I) / Steps), Radius, Stripe);
	}
	return NewlyCut;
}

UTexture2D* ULawnGridComponent::MakeTexture(int32 Width, int32 Height)
{
	UTexture2D* Texture = UTexture2D::CreateTransient(Width, Height, PF_B8G8R8A8);
	Texture->Filter = TF_Nearest;
	Texture->SRGB = false;
	Texture->UpdateResource();
	return Texture;
}

UTexture2D* ULawnGridComponent::GetMaskTexture()
{
	if (!MaskTexture)
	{
		MaskTexture = MakeTexture(Columns, Rows);
		bMaskDirty = true;
	}
	if (bMaskDirty)
	{
		WriteMask();
	}
	return MaskTexture;
}

UTexture2D* ULawnGridComponent::GetMapTexture()
{
	if (!MapTexture)
	{
		MapTexture = MakeTexture(Columns, Rows);
		bMaskDirty = true;
	}
	if (bMaskDirty)
	{
		WriteMask();
	}
	return MapTexture;
}

void ULawnGridComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);
	if ((MaskTexture || MapTexture) && bMaskDirty)
	{
		WriteMask();
	}
}

void ULawnGridComponent::WriteMask()
{
	// Mask: R tall, G light stripe, B blocked. Map: what the lawn looks like from above.
	static const FColor MapColors[] = {
		FColor(46, 82, 22),   // tall
		FColor(110, 168, 52), // light stripe
		FColor(66, 120, 30),  // dark stripe
		FColor(120, 96, 72),  // blocked
	};
	for (UTexture2D* Texture : {MaskTexture.Get(), MapTexture.Get()})
	{
		if (!Texture || !Texture->GetPlatformData() || Texture->GetPlatformData()->Mips.Num() == 0)
		{
			continue;
		}
		const bool bMap = Texture == MapTexture;
		// Update the existing GPU resource. The render thread owns this
		// snapshot until the cleanup callback; never pass temporary data.
		FColor* Pixels = new FColor[Cells.Num()];
		for (int32 I = 0; I < Cells.Num(); ++I)
		{
			const uint8 Value = Cells[I];
			Pixels[I] = bMap ? MapColors[FMath::Min<int32>(Value, 3)] : FColor(
				Value == LawnCell::Tall ? 255 : 0,
				Value == LawnCell::StripeA ? 255 : 0,
				Value == LawnCell::Blocked ? 255 : 0,
				255);
		}
		auto* Region = new FUpdateTextureRegion2D(0, 0, 0, 0, Columns, Rows);
		Texture->UpdateTextureRegions(0, 1, Region, Columns * sizeof(FColor),
			sizeof(FColor), reinterpret_cast<uint8*>(Pixels),
			[](uint8* Data, const FUpdateTextureRegion2D* Regions)
			{
				delete[] reinterpret_cast<FColor*>(Data);
				delete Regions;
			});
	}
	bMaskDirty = false;
}
