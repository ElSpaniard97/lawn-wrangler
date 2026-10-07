#include "LawnArt.h"

#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/Actor.h"
#include "Materials/MaterialInstanceDynamic.h"

namespace LawnArt
{
	static void Place(UStaticMeshComponent* Part, UStaticMesh* Mesh, const FVector& Location, const FVector& Size, const FRotator& Rotation)
	{
		Part->SetStaticMesh(Mesh);
		Part->SetRelativeLocationAndRotation(Location, Rotation);
		Part->SetRelativeScale3D(Size / 100.f);
		Part->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		Part->SetGenerateOverlapEvents(false);
	}

	UStaticMeshComponent* AddPart(AActor* Owner, USceneComponent* Parent, FName Name, UStaticMesh* Mesh,
		const FVector& Location, const FVector& Size, const FRotator& Rotation)
	{
		UStaticMeshComponent* Part = Owner->CreateDefaultSubobject<UStaticMeshComponent>(Name);
		Part->SetupAttachment(Parent);
		Place(Part, Mesh, Location, Size, Rotation);
		return Part;
	}

	UStaticMeshComponent* Spawn(AActor* Owner, USceneComponent* Parent, UStaticMesh* Mesh, UMaterialInterface* Material,
		const FLinearColor& Color, const FVector& Location, const FVector& Size, const FRotator& Rotation)
	{
		UStaticMeshComponent* Part = NewObject<UStaticMeshComponent>(Owner);
		Part->SetupAttachment(Parent);
		Place(Part, Mesh, Location, Size, Rotation);
		Part->RegisterComponent();
		Paint(Part, Material, Color);
		return Part;
	}

	void Paint(UPrimitiveComponent* Mesh, UMaterialInterface* Material, const FLinearColor& Color)
	{
		if (!Mesh || !Material)
		{
			return;
		}
		UMaterialInstanceDynamic* Instance = UMaterialInstanceDynamic::Create(Material, Mesh);
		Instance->SetVectorParameterValue(TEXT("Color"), Color);
		Mesh->SetMaterial(0, Instance);
	}
}
