#pragma once

#include "CoreMinimal.h"

class AActor;
class UMaterialInterface;
class UPrimitiveComponent;
class USceneComponent;
class UStaticMesh;
class UStaticMeshComponent;

/**
 * Stand-in art built from the engine's basic shapes (100 cm cube, cylinder
 * and sphere, all centred on their pivot) and its BasicShapeMaterial, so the
 * game is playable before any Fab models are added. Sizes are in cm.
 */
namespace LawnArt
{
	const TCHAR* const CubePath = TEXT("/Engine/BasicShapes/Cube.Cube");
	const TCHAR* const CylinderPath = TEXT("/Engine/BasicShapes/Cylinder.Cylinder");
	const TCHAR* const SpherePath = TEXT("/Engine/BasicShapes/Sphere.Sphere");
	const TCHAR* const PlanePath = TEXT("/Engine/BasicShapes/Plane.Plane");
	const TCHAR* const MaterialPath = TEXT("/Engine/BasicShapes/BasicShapeMaterial.BasicShapeMaterial");

	/** Adds a shape as a default subobject. Call from a constructor only. */
	LAWNWRANGLER_API UStaticMeshComponent* AddPart(AActor* Owner, USceneComponent* Parent, FName Name, UStaticMesh* Mesh,
		const FVector& Location, const FVector& Size, const FRotator& Rotation = FRotator::ZeroRotator);

	/** Adds a shape while the game runs. */
	LAWNWRANGLER_API UStaticMeshComponent* Spawn(AActor* Owner, USceneComponent* Parent, UStaticMesh* Mesh, UMaterialInterface* Material,
		const FLinearColor& Color, const FVector& Location, const FVector& Size, const FRotator& Rotation = FRotator::ZeroRotator);

	/** Gives a mesh a plain colour, using a copy of the basic shape material. */
	LAWNWRANGLER_API void Paint(UPrimitiveComponent* Mesh, UMaterialInterface* Material, const FLinearColor& Color);

	/** Turns an sRGB colour such as 0x5a8f3c into the linear colour materials expect. */
	inline FLinearColor Hex(uint32 RGB)
	{
		return FLinearColor(FColor((RGB >> 16) & 0xff, (RGB >> 8) & 0xff, RGB & 0xff));
	}
}
