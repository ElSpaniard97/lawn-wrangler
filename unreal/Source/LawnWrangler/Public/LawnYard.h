#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "LawnObjectives.h"
#include "LawnYard.generated.h"

class ALawnMower;
class ALawnWalker;
class UInstancedStaticMeshComponent;
class ULawnGridComponent;
class UMaterialInstanceDynamic;
class UMaterialInterface;
class UStaticMesh;
class UStaticMeshComponent;

/**
 * The yard and the rules of the game, ported from the Godot version's
 * yard.gd: a 30 x 36 m lot inside a privacy fence, the house along the left
 * side with a porch facing the lawn, so the grass wraps round it as back,
 * side and front yards. Trees sit in stone rings, shrubs fill edged beds,
 * and a pergola shades a patio in the back corner.
 *
 * This actor owns the lawn grid, the grass, the invisible colliders for the
 * layout below, fuel and the gas can, the checklist, the timer and the best
 * time. The game mode spawns one at the world origin when the level has
 * none, and until real art is added it draws the yard, the sky and the sun
 * itself from the engine's basic shapes. To dress it with Fab art, place a
 * BP_Yard (a Blueprint child) at the origin instead, turn off Stand In Art
 * and put the models at the positions listed in unreal/README.md.
 */
UCLASS()
class LAWNWRANGLER_API ALawnYard : public AActor
{
	GENERATED_BODY()

public:
	ALawnYard();

	/** Lot size in cm: X across, Y from the back fence to the street. */
	static const FVector2D Lot;
	static const FVector2D HouseCenter;
	static const FVector2D HouseSize;
	static const FVector2D GasCan;
	static const FVector StartLocation;
	static constexpr float WinPercent = 99.f;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Yard")
	TObjectPtr<ULawnGridComponent> Lawn;

	/** One grass clump per cell; cut clumps shrink to stubble. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Yard")
	TObjectPtr<UInstancedStaticMeshComponent> Grass;

	/** Without a GrassMesh, cut cells show as short light or dark tiles from these, making the stripes. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Yard")
	TObjectPtr<UInstancedStaticMeshComponent> CutGrassA;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Yard")
	TObjectPtr<UInstancedStaticMeshComponent> CutGrassB;

	/** The lawn's ground, coloured by GroundMaterial from the cut mask. */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Yard")
	TObjectPtr<UStaticMeshComponent> Ground;

	/** A grass clump mesh, for example from Fab's free Megascans grass. */
	UPROPERTY(EditAnywhere, Category = "Yard|Art")
	TObjectPtr<UStaticMesh> GrassMesh;

	/** A material with a Texture parameter named CutMask (see README). */
	UPROPERTY(EditAnywhere, Category = "Yard|Art")
	TObjectPtr<UMaterialInterface> GroundMaterial;

	/** Draws the fence, house, porch, beds, trees and patio from basic shapes. Turn off once real art is placed. */
	UPROPERTY(EditAnywhere, Category = "Yard|Art")
	bool bStandInArt = true;

	/** Adds a sun, sky, sky light and haze when the level has no sun of its own. */
	UPROPERTY(EditAnywhere, Category = "Yard|Art")
	bool bAddSkyIfMissing = true;

	UPROPERTY(EditAnywhere, Category = "Yard|Pawns")
	TSubclassOf<ALawnMower> MowerClass;

	UPROPERTY(EditAnywhere, Category = "Yard|Pawns")
	TSubclassOf<ALawnWalker> WalkerClass;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	TObjectPtr<ALawnMower> Mower;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	TObjectPtr<ALawnWalker> Walker;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	bool bOnMower = true;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	float Elapsed = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	float BestTime = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	bool bFinished = false;

	UPROPERTY(BlueprintReadOnly, Category = "Yard")
	bool bNewRecord = false;

	FLawnObjectives Objectives;

	/** The hint shown above the bottom edge, and how long it has left. */
	FString Message;
	float MessageTime = 0.f;

	/** Shows a short hint on screen for a few seconds. */
	void Say(const FString& Text, float Seconds = 2.5f);

	/** Hops off beside the mower where there is room, or back on when close. */
	bool ToggleMower();

	virtual void BeginPlay() override;
	virtual void Tick(float DeltaTime) override;

private:
	void BuildLayout();
	void AddBlock(const FBox2D& Rect, float Height, bool bBlockGrass = true);
	void AddRound(const FVector2D& Center, float Radius, float Height);
	void PlantGrass();
	void BuildStandInArt();
	void BuildSky();
	UStaticMeshComponent* Shape(UStaticMesh* Mesh, uint32 Color, const FVector& Center, const FVector& Size, const FRotator& Rotation = FRotator::ZeroRotator);
	void SpawnPawns();
	void UpdateFuel(float DeltaTime);
	void Finish();

	UFUNCTION()
	void HandleCellCut(int32 X, int32 Y, uint8 Stripe);

	UPROPERTY(Transient)
	TObjectPtr<UMaterialInstanceDynamic> GroundInstance;

	UPROPERTY()
	TObjectPtr<UStaticMesh> CubeMesh;

	UPROPERTY()
	TObjectPtr<UStaticMesh> CylinderMesh;

	UPROPERTY()
	TObjectPtr<UStaticMesh> SphereMesh;

	UPROPERTY()
	TObjectPtr<UMaterialInterface> ShapeMaterial;

	/** True when the grass is drawn as tiles (no GrassMesh), so cutting swaps tiles. */
	bool bTileGrass = false;

	/** Grass instance index for each cell, or INDEX_NONE where blocked. */
	TArray<int32> GrassIndex;
	bool bGrassDirty = false;
	int32 FuelWarning = 0;
	bool bRefuelling = false;
};
