#include "LawnYard.h"

#include "Components/BoxComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/DirectionalLightComponent.h"
#include "Components/ExponentialHeightFogComponent.h"
#include "Components/InstancedStaticMeshComponent.h"
#include "Components/SkyAtmosphereComponent.h"
#include "Components/SkyLightComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
#include "LawnArt.h"
#include "LawnGridComponent.h"
#include "LawnMower.h"
#include "LawnSaveGame.h"
#include "LawnWalker.h"
#include "Materials/MaterialInstanceDynamic.h"
#include "UObject/ConstructorHelpers.h"

// The layout, in centimetres from the back-left corner of the lot (X across,
// Y towards the street). Same numbers as the Godot yard, times 100.
const FVector2D ALawnYard::Lot(3000.f, 3600.f);
const FVector2D ALawnYard::HouseCenter(500.f, 1900.f);
const FVector2D ALawnYard::HouseSize(1000.f, 1200.f);
const FVector2D ALawnYard::GasCan(1350.f, 1660.f);
const FVector ALawnYard::StartLocation(1600.f, 3050.f, 41.f);

namespace
{
	const FVector2D Trees[] = {{2000.f, 800.f}, {2400.f, 2800.f}, {600.f, 3100.f}};
	constexpr float RingRadius = 60.f;
	// Round flower beds: x, y, radius.
	const FVector Beds[] = {{2500.f, 1750.f, 130.f}, {1400.f, 600.f, 100.f}};
	const FBox2D Porch(FVector2D(1000.f, 1580.f), FVector2D(1400.f, 2220.f));
	const FBox2D ShrubBeds[] = {
		FBox2D(FVector2D(1000.f, 1300.f), FVector2D(1150.f, 1580.f)),
		FBox2D(FVector2D(1000.f, 2220.f), FVector2D(1150.f, 2500.f)),
		FBox2D(FVector2D(300.f, 0.f), FVector2D(1700.f, 140.f)),
		FBox2D(FVector2D(2860.f, 1000.f), FVector2D(3000.f, 2400.f)),
	};
	const FBox2D Patio(FVector2D(2150.f, 0.f), FVector2D(3000.f, 750.f));
	constexpr float FenceHeight = 180.f;
	constexpr float RefuelDistance = 250.f;
	constexpr float RefuelRate = 0.35f;
	constexpr float LowFuel = 0.2f;
	constexpr float RemountDistance = 180.f;
	const TCHAR* SaveSlot = TEXT("LawnWrangler");

	// Stand-in grass tiles: one per 25 cm cell, a little smaller so the soil
	// shows between them. Colours are sRGB, like a paint picker.
	constexpr float TileSize = 23.f;
	constexpr float TallHeight = 11.f;
	constexpr float CutHeight = 3.f;
	constexpr uint32 TallColor = 0x4c7a2a;
	constexpr uint32 StripeAColor = 0x7fae4a;
	constexpr uint32 StripeBColor = 0x4f8a33;
	constexpr uint32 SoilColor = 0x3d4a22;
}

ALawnYard::ALawnYard()
{
	PrimaryActorTick.bCanEverTick = true;

	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));

	Lawn = CreateDefaultSubobject<ULawnGridComponent>(TEXT("Lawn"));

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Plane(LawnArt::PlanePath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(LawnArt::CubePath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(LawnArt::CylinderPath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(LawnArt::SpherePath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> ShapeFinder(LawnArt::MaterialPath);
	CubeMesh = Cube.Object;
	CylinderMesh = Cylinder.Object;
	SphereMesh = Sphere.Object;
	ShapeMaterial = ShapeFinder.Object;

	// The engine plane is 100 cm square and centred, so stretch it over the lot.
	Ground = LawnArt::AddPart(this, RootComponent, TEXT("Ground"), Plane.Object,
		FVector(Lot.X / 2.f, Lot.Y / 2.f, 0.5f), FVector(Lot.X, Lot.Y, 100.f));

	auto MakeGrass = [this](FName Name)
	{
		UInstancedStaticMeshComponent* Layer = CreateDefaultSubobject<UInstancedStaticMeshComponent>(Name);
		Layer->SetupAttachment(RootComponent);
		Layer->SetCollisionEnabled(ECollisionEnabled::NoCollision);
		Layer->SetCastShadow(false);
		return Layer;
	};
	Grass = MakeGrass(TEXT("Grass"));
	CutGrassA = MakeGrass(TEXT("CutGrassA"));
	CutGrassB = MakeGrass(TEXT("CutGrassB"));

	MowerClass = ALawnMower::StaticClass();
	WalkerClass = ALawnWalker::StaticClass();
}

void ALawnYard::BeginPlay()
{
	Super::BeginPlay();

	Lawn->Columns = FMath::RoundToInt(Lot.X / Lawn->CellSize);
	Lawn->Rows = FMath::RoundToInt(Lot.Y / Lawn->CellSize);
	Lawn->ResetCells();
	BuildLayout();
	Lawn->SealLayout();
	Objectives.Setup(*Lawn, HouseCenter.Y - HouseSize.Y / 2.f, HouseCenter.Y + HouseSize.Y / 2.f);
	Lawn->OnCellCut.AddDynamic(this, &ALawnYard::HandleCellCut);

	if (GroundMaterial)
	{
		GroundInstance = UMaterialInstanceDynamic::Create(GroundMaterial, this);
		GroundInstance->SetTextureParameterValue(TEXT("CutMask"), Lawn->GetMaskTexture());
		Ground->SetMaterial(0, GroundInstance);
	}
	else
	{
		LawnArt::Paint(Ground, ShapeMaterial, LawnArt::Hex(SoilColor));
	}
	PlantGrass();
	if (bStandInArt)
	{
		BuildStandInArt();
	}
	if (bAddSkyIfMissing)
	{
		BuildSky();
	}

	if (const ULawnSaveGame* Save = Cast<ULawnSaveGame>(UGameplayStatics::LoadGameFromSlot(SaveSlot, 0)))
	{
		// Only trust a sensible saved time, like the Godot version.
		BestTime = FMath::IsFinite(Save->BestTime) && Save->BestTime > 0.f && Save->BestTime < 360000.f ? Save->BestTime : 0.f;
	}

	SpawnPawns();
	Say(TEXT("Mow the open lawn, then press Space (or Y) to hop off and trim the edges."), 5.f);
}

void ALawnYard::BuildLayout()
{
	// Privacy fence round the lot. The fence art itself is placed in the level.
	AddBlock(FBox2D(FVector2D(-20.f, -20.f), FVector2D(Lot.X + 20.f, 0.f)), FenceHeight, false);
	AddBlock(FBox2D(FVector2D(-20.f, Lot.Y), FVector2D(Lot.X + 20.f, Lot.Y + 20.f)), FenceHeight, false);
	AddBlock(FBox2D(FVector2D(-20.f, 0.f), FVector2D(0.f, Lot.Y)), FenceHeight, false);
	AddBlock(FBox2D(FVector2D(Lot.X, 0.f), FVector2D(Lot.X + 20.f, Lot.Y)), FenceHeight, false);

	for (const FVector2D& Tree : Trees)
	{
		AddRound(Tree, RingRadius, 200.f);
	}
	for (const FVector& Bed : Beds)
	{
		AddRound(FVector2D(Bed.X, Bed.Y), Bed.Z, 60.f);
	}

	// The house and its porch deck and steps; the paver landing in front of
	// the steps has no grass but can be walked on.
	AddBlock(FBox2D(HouseCenter - HouseSize / 2.f, HouseCenter + HouseSize / 2.f), 500.f);
	Lawn->BlockRect(Porch);
	AddBlock(FBox2D(Porch.Min, FVector2D(Porch.Min.X + 280.f, Porch.Max.Y)), 60.f, false);

	for (const FBox2D& Bed : ShrubBeds)
	{
		AddBlock(Bed, 60.f);
	}

	// Patio under the pergola: no grass, posts and the table block.
	Lawn->BlockRect(Patio);
	const FVector2D PatioCenter = Patio.GetCenter();
	const FVector2D Inset = Patio.GetExtent() - FVector2D(80.f, 80.f);
	for (const float SX : {-1.f, 1.f})
	{
		for (const float SY : {-1.f, 1.f})
		{
			const FVector2D Post = PatioCenter + FVector2D(SX * Inset.X, SY * Inset.Y);
			AddBlock(FBox2D(Post - FVector2D(15.f, 15.f), Post + FVector2D(15.f, 15.f)), 260.f, false);
		}
	}
	AddBlock(FBox2D(PatioCenter - FVector2D(140.f, 140.f), PatioCenter + FVector2D(140.f, 140.f)), 100.f, false);

	// The red gas can on the porch landing.
	AddBlock(FBox2D(GasCan - FVector2D(25.f, 25.f), GasCan + FVector2D(25.f, 25.f)), 60.f, false);
}

void ALawnYard::AddBlock(const FBox2D& Rect, float Height, bool bBlockGrass)
{
	UBoxComponent* Box = NewObject<UBoxComponent>(this);
	Box->SetupAttachment(RootComponent);
	Box->SetBoxExtent(FVector(Rect.GetExtent().X, Rect.GetExtent().Y, Height / 2.f));
	Box->SetRelativeLocation(FVector(Rect.GetCenter().X, Rect.GetCenter().Y, Height / 2.f));
	Box->SetCollisionProfileName(TEXT("BlockAll"));
	Box->RegisterComponent();
	if (bBlockGrass)
	{
		Lawn->BlockRect(Rect);
	}
}

void ALawnYard::AddRound(const FVector2D& Center, float Radius, float Height)
{
	UCapsuleComponent* Capsule = NewObject<UCapsuleComponent>(this);
	Capsule->SetupAttachment(RootComponent);
	Capsule->SetCapsuleSize(Radius, FMath::Max(Radius, Height / 2.f));
	Capsule->SetRelativeLocation(FVector(Center.X, Center.Y, Height / 2.f));
	Capsule->SetCollisionProfileName(TEXT("BlockAll"));
	Capsule->RegisterComponent();
	Lawn->BlockCircle(Center, Radius);
}

void ALawnYard::PlantGrass()
{
	GrassIndex.Init(INDEX_NONE, Lawn->Columns * Lawn->Rows);
	// Without a grass model, the lawn is drawn as a carpet of small green
	// tiles; cutting swaps a tall tile for a short light or dark one.
	bTileGrass = GrassMesh == nullptr;
	Grass->SetStaticMesh(bTileGrass ? CubeMesh.Get() : GrassMesh.Get());
	if (bTileGrass)
	{
		CutGrassA->SetStaticMesh(CubeMesh);
		CutGrassB->SetStaticMesh(CubeMesh);
		LawnArt::Paint(Grass, ShapeMaterial, LawnArt::Hex(TallColor));
		LawnArt::Paint(CutGrassA, ShapeMaterial, LawnArt::Hex(StripeAColor));
		LawnArt::Paint(CutGrassB, ShapeMaterial, LawnArt::Hex(StripeBColor));
	}
	FRandomStream Random(7);
	TArray<FTransform> Transforms;
	TArray<FTransform> Hidden;
	TArray<int32> Cells;
	for (int32 Y = 0; Y < Lawn->Rows; ++Y)
	{
		for (int32 X = 0; X < Lawn->Columns; ++X)
		{
			if (Lawn->GetCell(X, Y) == LawnCell::Blocked)
			{
				continue;
			}
			const FVector Center((X + 0.5f) * Lawn->CellSize, (Y + 0.5f) * Lawn->CellSize, 0.f);
			if (bTileGrass)
			{
				const float Height = TallHeight * Random.FRandRange(0.8f, 1.2f);
				Transforms.Add(FTransform(FRotator::ZeroRotator, Center + FVector(0.f, 0.f, Height / 2.f),
					FVector(TileSize, TileSize, Height) / 100.f));
				Hidden.Add(FTransform(FRotator::ZeroRotator, Center, FVector::ZeroVector));
			}
			else
			{
				const FVector Jitter(Random.FRandRange(-8.f, 8.f), Random.FRandRange(-8.f, 8.f), 0.f);
				const float Size = Random.FRandRange(0.85f, 1.15f);
				Transforms.Add(FTransform(FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f), Center + Jitter, FVector(Size)));
			}
			Cells.Add(Y * Lawn->Columns + X);
		}
	}
	const TArray<int32> Indices = Grass->AddInstances(Transforms, true);
	if (bTileGrass)
	{
		// Same order, so a cell has the same index in all three layers.
		CutGrassA->AddInstances(Hidden, false);
		CutGrassB->AddInstances(Hidden, false);
	}
	for (int32 I = 0; I < Indices.Num(); ++I)
	{
		GrassIndex[Cells[I]] = Indices[I];
	}
}

void ALawnYard::HandleCellCut(int32 X, int32 Y, uint8 Stripe)
{
	Objectives.OnCellCut(X, Y);
	const int32 Index = GrassIndex.IsValidIndex(Y * Lawn->Columns + X) ? GrassIndex[Y * Lawn->Columns + X] : INDEX_NONE;
	if (Index == INDEX_NONE)
	{
		return;
	}
	FTransform Clump;
	Grass->GetInstanceTransform(Index, Clump);
	if (bTileGrass)
	{
		// Hide the tall tile and show a short one in this stripe's colour.
		const FVector Center((X + 0.5f) * Lawn->CellSize, (Y + 0.5f) * Lawn->CellSize, CutHeight / 2.f);
		UInstancedStaticMeshComponent* Cut = Stripe == LawnCell::StripeA ? CutGrassA : CutGrassB;
		Cut->UpdateInstanceTransform(Index, FTransform(FRotator::ZeroRotator, Center,
			FVector(Lawn->CellSize, Lawn->CellSize, CutHeight) / 100.f), false, false, true);
		Clump.SetScale3D(FVector::ZeroVector);
	}
	else
	{
		// Cut grass drops to short stubble.
		Clump.SetScale3D(FVector(Clump.GetScale3D().X, Clump.GetScale3D().Y, 0.2f));
	}
	Grass->UpdateInstanceTransform(Index, Clump, false, false, true);
	bGrassDirty = true;
}

UStaticMeshComponent* ALawnYard::Shape(UStaticMesh* Mesh, uint32 Color, const FVector& Center, const FVector& Size, const FRotator& Rotation)
{
	return LawnArt::Spawn(this, RootComponent, Mesh, ShapeMaterial, LawnArt::Hex(Color), Center, Size, Rotation);
}

void ALawnYard::BuildStandInArt()
{
	UStaticMesh* Box = CubeMesh;
	UStaticMesh* Round = CylinderMesh;
	UStaticMesh* Ball = SphereMesh;
	auto Flat = [this, Box](const FBox2D& Rect, float Height, uint32 Color)
	{
		const FVector2D C = Rect.GetCenter();
		const FVector2D E = Rect.GetSize();
		return Shape(Box, Color, FVector(C.X, C.Y, Height / 2.f), FVector(E.X, E.Y, Height));
	};

	// The world outside the fence: neighbours' lawns, the street, two houses behind.
	Shape(Ground->GetStaticMesh(), 0x3f6b2c, FVector(Lot.X / 2.f, Lot.Y / 2.f, -2.f), FVector(20000.f, 20000.f, 100.f));
	Shape(Box, 0x3a3a3c, FVector(Lot.X / 2.f, Lot.Y + 900.f, 1.f), FVector(20000.f, 700.f, 4.f));
	auto Neighbour = [&](float X, float Y, uint32 Wall)
	{
		Shape(Box, Wall, FVector(X, Y, 300.f), FVector(1200.f, 900.f, 600.f));
		Shape(Box, 0x4a4a4f, FVector(X, Y, 620.f), FVector(1300.f, 1000.f, 40.f));
	};
	Neighbour(700.f, -1000.f, 0xc9b79c);
	Neighbour(2500.f, -1100.f, 0xa8b5c0);

	// Privacy fence: boards with darker posts every 2.4 m.
	const uint32 Wood = 0x8a6a48;
	Flat(FBox2D(FVector2D(-10.f, -10.f), FVector2D(Lot.X + 10.f, 0.f)), FenceHeight, Wood);
	Flat(FBox2D(FVector2D(-10.f, Lot.Y), FVector2D(Lot.X + 10.f, Lot.Y + 10.f)), FenceHeight, Wood);
	Flat(FBox2D(FVector2D(-10.f, 0.f), FVector2D(0.f, Lot.Y)), FenceHeight, Wood);
	Flat(FBox2D(FVector2D(Lot.X, 0.f), FVector2D(Lot.X + 10.f, Lot.Y)), FenceHeight, Wood);
	for (float X = 0.f; X <= Lot.X; X += 240.f)
	{
		Shape(Box, 0x6e5238, FVector(X, -5.f, 95.f), FVector(14.f, 14.f, 190.f));
		Shape(Box, 0x6e5238, FVector(X, Lot.Y + 5.f, 95.f), FVector(14.f, 14.f, 190.f));
	}
	for (float Y = 240.f; Y < Lot.Y; Y += 240.f)
	{
		Shape(Box, 0x6e5238, FVector(-5.f, Y, 95.f), FVector(14.f, 14.f, 190.f));
		Shape(Box, 0x6e5238, FVector(Lot.X + 5.f, Y, 95.f), FVector(14.f, 14.f, 190.f));
	}

	// The house: walls, a gable roof with its ridge running along Y, a door
	// onto the porch and windows either side.
	Shape(Box, 0xd9d2c0, FVector(HouseCenter.X, HouseCenter.Y, 250.f), FVector(HouseSize.X, HouseSize.Y, 500.f));
	const float HalfSpan = HouseSize.X / 2.f + 40.f;
	const float Rise = HalfSpan * FMath::Tan(FMath::DegreesToRadians(30.f));
	const FVector Slab(HalfSpan / FMath::Cos(FMath::DegreesToRadians(30.f)), HouseSize.Y + 80.f, 20.f);
	Shape(Box, 0x4a4a4f, FVector(HouseCenter.X - HalfSpan / 2.f, HouseCenter.Y, 500.f + Rise / 2.f), Slab, FRotator(30.f, 0.f, 0.f));
	Shape(Box, 0x4a4a4f, FVector(HouseCenter.X + HalfSpan / 2.f, HouseCenter.Y, 500.f + Rise / 2.f), Slab, FRotator(-30.f, 0.f, 0.f));
	const float Face = HouseCenter.X + HouseSize.X / 2.f;
	Shape(Box, 0x6b3b2a, FVector(Face + 3.f, HouseCenter.Y, 165.f), FVector(6.f, 100.f, 210.f));
	for (const float Y : {1430.f, 2370.f})
	{
		Shape(Box, 0x9fb8c8, FVector(Face + 3.f, Y, 260.f), FVector(6.f, 140.f, 120.f));
	}

	// Porch deck, steps and the paver landing with the red gas can.
	Flat(FBox2D(Porch.Min, FVector2D(Porch.Min.X + 280.f, Porch.Max.Y)), 60.f, 0xa07850);
	Shape(Box, 0xa07850, FVector(Porch.Min.X + 300.f, HouseCenter.Y, 15.f), FVector(40.f, 300.f, 30.f));
	Flat(FBox2D(FVector2D(Porch.Min.X + 280.f, Porch.Min.Y), Porch.Max), 4.f, 0x9a9590);
	Shape(Box, 0xc8261e, FVector(GasCan.X, GasCan.Y, 18.f), FVector(30.f, 20.f, 36.f));
	Shape(Box, 0x222222, FVector(GasCan.X + 10.f, GasCan.Y, 40.f), FVector(6.f, 6.f, 10.f));

	// Shrub beds: mulch with a row of round shrubs.
	for (const FBox2D& Bed : ShrubBeds)
	{
		Flat(Bed, 10.f, 0x4a3020);
		const FVector2D Size = Bed.GetSize();
		const bool bAlongX = Size.X >= Size.Y;
		const float Shrub = FMath::Min(Size.X, Size.Y) * 0.95f;
		const float Length = bAlongX ? Size.X : Size.Y;
		const int32 Count = FMath::Max(1, FMath::FloorToInt(Length / Shrub));
		for (int32 I = 0; I < Count; ++I)
		{
			const float Along = (I + 0.5f) * Length / Count;
			const FVector2D At = bAlongX ? FVector2D(Bed.Min.X + Along, Bed.GetCenter().Y) : FVector2D(Bed.GetCenter().X, Bed.Min.Y + Along);
			Shape(Ball, I % 2 ? 0x2f5a25 : 0x37672b, FVector(At.X, At.Y, Shrub * 0.4f), FVector(Shrub, Shrub, Shrub * 0.85f));
		}
	}

	// Trees in stone rings.
	for (const FVector2D& Tree : Trees)
	{
		Shape(Round, 0x8c8a85, FVector(Tree.X, Tree.Y, 10.f), FVector(RingRadius * 2.f, RingRadius * 2.f, 20.f));
		Shape(Round, 0x4a3020, FVector(Tree.X, Tree.Y, 11.f), FVector(RingRadius * 1.6f, RingRadius * 1.6f, 20.f));
		Shape(Round, 0x5a4030, FVector(Tree.X, Tree.Y, 170.f), FVector(30.f, 30.f, 340.f));
		Shape(Ball, 0x3a6b2a, FVector(Tree.X, Tree.Y, 430.f), FVector(380.f, 380.f, 320.f));
		Shape(Ball, 0x447a30, FVector(Tree.X + 60.f, Tree.Y - 40.f, 560.f), FVector(260.f, 260.f, 230.f));
	}

	// Round flower beds with pink and yellow flowers.
	for (const FVector& Bed : Beds)
	{
		Shape(Round, 0x4a3020, FVector(Bed.X, Bed.Y, 8.f), FVector(Bed.Z * 2.f, Bed.Z * 2.f, 16.f));
		for (int32 I = 0; I < 8; ++I)
		{
			const float Angle = I * UE_PI / 4.f;
			const FVector At(Bed.X + FMath::Cos(Angle) * Bed.Z * 0.6f, Bed.Y + FMath::Sin(Angle) * Bed.Z * 0.6f, 30.f);
			Shape(Ball, I % 2 ? 0xe35d9a : 0xf2c84b, At, FVector(45.f, 45.f, 40.f));
		}
		Shape(Ball, 0x37672b, FVector(Bed.X, Bed.Y, 40.f), FVector(Bed.Z * 0.8f, Bed.Z * 0.8f, 70.f));
	}

	// Patio: pavers, a pergola on four posts, and a table with chairs.
	Flat(Patio, 4.f, 0xb0aaa0);
	const FVector2D PatioCenter = Patio.GetCenter();
	const FVector2D Inset = Patio.GetExtent() - FVector2D(80.f, 80.f);
	for (const float SX : {-1.f, 1.f})
	{
		for (const float SY : {-1.f, 1.f})
		{
			Shape(Box, 0xe8e4dc, FVector(PatioCenter.X + SX * Inset.X, PatioCenter.Y + SY * Inset.Y, 130.f), FVector(30.f, 30.f, 260.f));
		}
		Shape(Box, 0xe8e4dc, FVector(PatioCenter.X + SX * Inset.X, PatioCenter.Y, 270.f), FVector(20.f, Inset.Y * 2.f + 80.f, 20.f));
	}
	for (int32 I = 0; I < 7; ++I)
	{
		const float Y = PatioCenter.Y - Inset.Y + I * Inset.Y / 3.f;
		Shape(Box, 0xe8e4dc, FVector(PatioCenter.X, Y, 288.f), FVector(Inset.X * 2.f + 80.f, 10.f, 16.f));
	}
	Shape(Box, 0x5a4636, FVector(PatioCenter.X, PatioCenter.Y, 74.f), FVector(180.f, 180.f, 8.f));
	Shape(Round, 0x5a4636, FVector(PatioCenter.X, PatioCenter.Y, 36.f), FVector(20.f, 20.f, 72.f));
	for (const FVector2D& Seat : {FVector2D(-120.f, 0.f), FVector2D(120.f, 0.f), FVector2D(0.f, -120.f), FVector2D(0.f, 120.f)})
	{
		Shape(Box, 0x2f2f2f, FVector(PatioCenter.X + Seat.X, PatioCenter.Y + Seat.Y, 23.f), FVector(50.f, 50.f, 46.f));
	}
}

void ALawnYard::BuildSky()
{
	for (TActorIterator<AActor> It(GetWorld()); It; ++It)
	{
		if (It->FindComponentByClass<UDirectionalLightComponent>())
		{
			return; // The level has its own lighting.
		}
	}
	// Mid-afternoon sun from over the back-right corner, a physical sky that
	// it lights, a sky light that captures that sky for Lumen, and light haze.
	UDirectionalLightComponent* Sun = NewObject<UDirectionalLightComponent>(this);
	Sun->SetMobility(EComponentMobility::Movable);
	Sun->SetupAttachment(RootComponent);
	Sun->SetRelativeRotation(FRotator(-40.f, 125.f, 0.f));
	Sun->SetIntensity(10.f);
	Sun->SetAtmosphereSunLight(true);
	Sun->RegisterComponent();

	USkyAtmosphereComponent* Sky = NewObject<USkyAtmosphereComponent>(this);
	Sky->SetupAttachment(RootComponent);
	Sky->RegisterComponent();

	USkyLightComponent* SkyLight = NewObject<USkyLightComponent>(this);
	SkyLight->SetMobility(EComponentMobility::Movable);
	SkyLight->bRealTimeCapture = true;
	SkyLight->SetupAttachment(RootComponent);
	SkyLight->RegisterComponent();

	UExponentialHeightFogComponent* Fog = NewObject<UExponentialHeightFogComponent>(this);
	Fog->SetupAttachment(RootComponent);
	Fog->SetFogDensity(0.004f);
	Fog->RegisterComponent();
}

void ALawnYard::SpawnPawns()
{
	FActorSpawnParameters Params;
	Params.SpawnCollisionHandlingOverride = ESpawnActorCollisionHandlingMethod::AlwaysSpawn;
	// Facing the back fence (-Y), with the house on the left like the reference picture.
	Mower = GetWorld()->SpawnActor<ALawnMower>(MowerClass, StartLocation, FRotator(0.f, -90.f, 0.f), Params);
	Walker = GetWorld()->SpawnActor<ALawnWalker>(WalkerClass, StartLocation + FVector(0.f, 0.f, 500.f), FRotator::ZeroRotator, Params);
	if (Mower)
	{
		Mower->Lawn = Lawn;
	}
	if (Walker)
	{
		Walker->Lawn = Lawn;
		Walker->SetActorHiddenInGame(true);
		Walker->SetActorEnableCollision(false);
	}
	if (APlayerController* PC = GetWorld()->GetFirstPlayerController(); PC && Mower)
	{
		PC->Possess(Mower);
	}
}

bool ALawnYard::ToggleMower()
{
	APlayerController* PC = GetWorld()->GetFirstPlayerController();
	if (!PC || !Mower || !Walker || bFinished)
	{
		return false;
	}
	if (bOnMower)
	{
		// Left, right, behind, then ahead of the mower.
		const FVector Offsets[] = {FVector(0.f, -110.f, 0.f), FVector(0.f, 110.f, 0.f), FVector(-150.f, 0.f, 0.f), FVector(150.f, 0.f, 0.f)};
		FCollisionQueryParams Query;
		Query.AddIgnoredActor(Mower);
		Query.AddIgnoredActor(Walker);
		for (const FVector& Offset : Offsets)
		{
			FVector Spot = Mower->GetActorTransform().TransformPosition(Offset);
			Spot.Z = 90.f;
			const bool bInLot = Spot.X > 30.f && Spot.Y > 30.f && Spot.X < Lot.X - 30.f && Spot.Y < Lot.Y - 30.f;
			if (bInLot && !GetWorld()->OverlapAnyTestByChannel(Spot, FQuat::Identity, ECC_Pawn, FCollisionShape::MakeCapsule(25.f, 85.f), Query))
			{
				Walker->SetActorLocationAndRotation(Spot, Mower->GetActorRotation());
				Walker->SetActorHiddenInGame(false);
				Walker->SetActorEnableCollision(true);
				PC->Possess(Walker);
				bOnMower = false;
				Say(TEXT("Weed eater out! Trim along the fence and around the beds."));
				return true;
			}
		}
		Say(TEXT("No room to step off here."));
		return false;
	}
	if (FVector::Dist2D(Walker->GetActorLocation(), Mower->GetActorLocation()) > RemountDistance)
	{
		Say(TEXT("Walk over to the mower to hop back on."));
		return false;
	}
	Walker->SetActorHiddenInGame(true);
	Walker->SetActorEnableCollision(false);
	PC->Possess(Mower);
	bOnMower = true;
	Say(TEXT("Back on the mower."));
	return true;
}

void ALawnYard::Say(const FString& Text, float Seconds)
{
	Message = Text;
	MessageTime = Seconds;
}

void ALawnYard::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	if (bGrassDirty)
	{
		Grass->MarkRenderStateDirty();
		CutGrassA->MarkRenderStateDirty();
		CutGrassB->MarkRenderStateDirty();
		bGrassDirty = false;
	}
	MessageTime = FMath::Max(0.f, MessageTime - DeltaTime);
	// If the player's controller arrived after the yard, hand it the mower now.
	if (bOnMower && Mower && !Mower->Controller)
	{
		if (APlayerController* PC = GetWorld()->GetFirstPlayerController())
		{
			PC->Possess(Mower);
		}
	}
	if (bFinished)
	{
		return;
	}
	Elapsed += DeltaTime;
	if (Lawn->PercentCut() >= WinPercent)
	{
		Finish();
		return;
	}
	UpdateFuel(DeltaTime);
}

void ALawnYard::UpdateFuel(float DeltaTime)
{
	if (!Mower)
	{
		return;
	}
	const AActor* Helper = bOnMower ? static_cast<AActor*>(Mower) : static_cast<AActor*>(Walker);
	const bool bNear = Helper && FVector2D::Distance(FVector2D(Helper->GetActorLocation()), GasCan) < RefuelDistance;
	if (bNear && Mower->Fuel < 1.f)
	{
		Mower->Refuel(RefuelRate * DeltaTime);
		if (!bRefuelling)
		{
			Say(TEXT("Filling up the tank..."), 2.f);
		}
		bRefuelling = true;
		if (Mower->Fuel >= 1.f)
		{
			Say(TEXT("Tank full!"), 1.5f);
		}
	}
	else
	{
		bRefuelling = false;
	}
	if (Mower->Fuel > 0.5f)
	{
		FuelWarning = 0;
	}
	else if (Mower->Fuel <= 0.f && FuelWarning < 2)
	{
		FuelWarning = 2;
		Say(TEXT("Out of gas! Crawl over to the red gas can by the porch steps."), 5.f);
	}
	else if (Mower->Fuel < LowFuel && FuelWarning < 1)
	{
		FuelWarning = 1;
		Say(TEXT("Fuel is low. Top up at the red gas can by the porch steps."), 4.f);
	}
}

void ALawnYard::Finish()
{
	bFinished = true;
	bNewRecord = BestTime <= 0.f || Elapsed < BestTime;
	if (bNewRecord)
	{
		BestTime = Elapsed;
		ULawnSaveGame* Save = Cast<ULawnSaveGame>(UGameplayStatics::CreateSaveGameObject(ULawnSaveGame::StaticClass()));
		Save->BestTime = BestTime;
		UGameplayStatics::SaveGameToSlot(Save, SaveSlot, 0);
	}
	if (Mower)
	{
		Mower->StopGameplay();
	}
	if (Walker)
	{
		Walker->StopGameplay();
	}
}
