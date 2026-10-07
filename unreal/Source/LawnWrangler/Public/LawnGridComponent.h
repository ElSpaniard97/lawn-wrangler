#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "LawnGridComponent.generated.h"

class UTexture2D;

/** What one cell of the lawn holds. */
namespace LawnCell
{
	constexpr uint8 Tall = 0;
	constexpr uint8 StripeA = 1;
	constexpr uint8 StripeB = 2;
	constexpr uint8 Blocked = 3;
}

DECLARE_DYNAMIC_MULTICAST_DELEGATE_ThreeParams(FOnLawnCellCut, int32, X, int32, Y, uint8, Stripe);

/**
 * The one source of truth for which grass is cut, ported from the Godot
 * version's LawnGrid. Cutting, the grass instances, the ground stripes and
 * the progress bar all read from here.
 *
 * Cells are CellSize centimetres square. The grid's corner is the owning
 * actor's location; +X is columns (across the yard) and +Y is rows (from the
 * back fence towards the street).
 */
UCLASS(ClassGroup = (LawnWrangler), meta = (BlueprintSpawnableComponent))
class LAWNWRANGLER_API ULawnGridComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	ULawnGridComponent();

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Lawn")
	int32 Columns = 120;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Lawn")
	int32 Rows = 144;

	/** Centimetres per cell. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "Lawn")
	float CellSize = 25.f;

	/** Fires once for every cell that goes from tall to cut. */
	UPROPERTY(BlueprintAssignable, Category = "Lawn")
	FOnLawnCellCut OnCellCut;

	/** Clears every cell to tall grass. Block cells, then call SealLayout(). */
	void ResetCells();

	/** Blocks cells whose centres are within Radius (cm) of Center (cm, grid space). */
	void BlockCircle(FVector2D Center, float Radius);

	/** Blocks cells whose centres fall inside a rectangle (cm, grid space). */
	void BlockRect(const FBox2D& Rect);

	/** Counts the cells that can be cut. Blocked cells never count toward 100%. */
	void SealLayout();

	/** Mowing one way along a line and back the other leaves light and dark stripes. */
	static uint8 StripeFor(const FVector& Direction);

	/** Cuts tall grass within Radius (cm) of a world location. Returns cells newly cut. */
	int32 CutAt(const FVector& WorldLocation, float Radius, uint8 Stripe);

	/** Cuts along the path between two blade positions so fast moves leave no gaps. */
	int32 CutSegment(const FVector& From, const FVector& To, float Radius, uint8 Stripe);

	uint8 GetCell(int32 X, int32 Y) const { return Cells[Y * Columns + X]; }

	UFUNCTION(BlueprintPure, Category = "Lawn")
	float PercentCut() const { return Total > 0 ? 100.f * CutCount / Total : 0.f; }

	UFUNCTION(BlueprintPure, Category = "Lawn")
	int32 CellsLeft() const { return Total - CutCount; }

	/** World position of a cell's centre, on the ground. */
	FVector CellCenter(int32 X, int32 Y) const;

	/**
	 * A small texture with one pixel per cell, for the ground material: R is
	 * 1 for tall grass, G is 1 for a light stripe, B is 1 for blocked.
	 * Updated whenever cells are cut.
	 */
	UFUNCTION(BlueprintPure, Category = "Lawn")
	UTexture2D* GetMaskTexture();

	/** The same lawn in display colours (stripes, tall grass, brown for blocked), for the minimap. */
	UFUNCTION(BlueprintPure, Category = "Lawn")
	UTexture2D* GetMapTexture();

	TArray<uint8> Cells;
	int32 Total = 0;
	int32 CutCount = 0;

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

private:
	FVector ToGrid(const FVector& World) const;
	void WriteMask();

	UPROPERTY(Transient)
	TObjectPtr<UTexture2D> MaskTexture;

	UPROPERTY(Transient)
	TObjectPtr<UTexture2D> MapTexture;

	static UTexture2D* MakeTexture(int32 Width, int32 Height);

	bool bMaskDirty = true;
};
