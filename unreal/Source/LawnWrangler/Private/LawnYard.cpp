#include "LawnYard.h"

#include "Components/BoxComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/HierarchicalInstancedStaticMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "Engine/World.h"
#include "GameFramework/PlayerController.h"
#include "Kismet/GameplayStatics.h"
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
}

ALawnYard::ALawnYard()
{
	PrimaryActorTick.bCanEverTick = true;

	RootComponent = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));

	Lawn = CreateDefaultSubobject<ULawnGridComponent>(TEXT("Lawn"));

	Ground = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Ground"));
	Ground->SetupAttachment(RootComponent);
	Ground->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Plane(TEXT("/Engine/BasicShapes/Plane.Plane"));
	if (Plane.Succeeded())
	{
		Ground->SetStaticMesh(Plane.Object);
	}
	// The engine plane is 100 cm square and centred, so stretch it over the lot.
	Ground->SetRelativeLocation(FVector(Lot.X / 2.f, Lot.Y / 2.f, 0.5f));
	Ground->SetRelativeScale3D(FVector(Lot.X / 100.f, Lot.Y / 100.f, 1.f));

	Grass = CreateDefaultSubobject<UHierarchicalInstancedStaticMeshComponent>(TEXT("Grass"));
	Grass->SetupAttachment(RootComponent);
	Grass->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Grass->SetCastShadow(false);

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
	PlantGrass();

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
	if (!GrassMesh)
	{
		return;
	}
	Grass->SetStaticMesh(GrassMesh);
	FRandomStream Random(7);
	TArray<FTransform> Transforms;
	TArray<int32> Cells;
	for (int32 Y = 0; Y < Lawn->Rows; ++Y)
	{
		for (int32 X = 0; X < Lawn->Columns; ++X)
		{
			if (Lawn->GetCell(X, Y) == LawnCell::Blocked)
			{
				continue;
			}
			const FVector Jitter(Random.FRandRange(-8.f, 8.f), Random.FRandRange(-8.f, 8.f), 0.f);
			const float Size = Random.FRandRange(0.85f, 1.15f);
			Transforms.Add(FTransform(FRotator(0.f, Random.FRandRange(0.f, 360.f), 0.f),
				FVector((X + 0.5f) * Lawn->CellSize, (Y + 0.5f) * Lawn->CellSize, 0.f) + Jitter, FVector(Size)));
			Cells.Add(Y * Lawn->Columns + X);
		}
	}
	const TArray<int32> Indices = Grass->AddInstances(Transforms, true);
	for (int32 I = 0; I < Indices.Num(); ++I)
	{
		GrassIndex[Cells[I]] = Indices[I];
	}
}

void ALawnYard::HandleCellCut(int32 X, int32 Y, uint8 Stripe)
{
	Objectives.OnCellCut(X, Y);
	const int32 Index = GrassIndex.IsValidIndex(Y * Lawn->Columns + X) ? GrassIndex[Y * Lawn->Columns + X] : INDEX_NONE;
	if (Index != INDEX_NONE)
	{
		// Cut grass drops to short stubble.
		FTransform Clump;
		Grass->GetInstanceTransform(Index, Clump);
		Clump.SetScale3D(FVector(Clump.GetScale3D().X, Clump.GetScale3D().Y, 0.2f));
		Grass->UpdateInstanceTransform(Index, Clump, false, false, true);
		bGrassDirty = true;
	}
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
		Mower->bDriving = false;
	}
}
