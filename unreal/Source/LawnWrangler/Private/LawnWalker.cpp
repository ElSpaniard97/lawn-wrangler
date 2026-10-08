#include "LawnWalker.h"

#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/InputComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/SpringArmComponent.h"
#include "LawnArt.h"
#include "LawnGridComponent.h"
#include "Materials/MaterialInterface.h"
#include "Math/RotationMatrix.h"
#include "UObject/ConstructorHelpers.h"
#include "LawnYard.h"
#include "EngineUtils.h"

ALawnWalker::ALawnWalker()
{
	PrimaryActorTick.bCanEverTick = true;

	Collision = CreateDefaultSubobject<UCapsuleComponent>(TEXT("Collision"));
	Collision->InitCapsuleSize(25.f, 85.f);
	Collision->SetCollisionProfileName(TEXT("Pawn"));
	RootComponent = Collision;

	Body = CreateDefaultSubobject<USkeletalMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(Collision);
	Body->SetRelativeLocation(FVector(0.f, 0.f, -85.f));
	Body->SetRelativeRotation(FRotator(0.f, -90.f, 0.f)); // Unreal character models face +Y
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	// Stand-in landscaper. The capsule's centre is 85 cm up, so feet are at Z = -85.
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(LawnArt::CubePath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(LawnArt::CylinderPath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(LawnArt::SpherePath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> Shape(LawnArt::MaterialPath);
	ShapeMaterial = Shape.Object;
	auto Part = [&](const TCHAR* Name, UStaticMesh* Mesh, const FVector& At, const FVector& Size, const FLinearColor& Color, const FRotator& Turn = FRotator::ZeroRotator)
	{
		StandInParts.Add(LawnArt::AddPart(this, Collision, Name, Mesh, At, Size, Turn));
		StandInColors.Add(Color);
	};
	const FLinearColor Jeans = LawnArt::Hex(0x3b4a63);
	Part(TEXT("LegL"), Cylinder.Object, FVector(0.f, -10.f, -43.f), FVector(16.f, 16.f, 84.f), Jeans);
	Part(TEXT("LegR"), Cylinder.Object, FVector(0.f, 10.f, -43.f), FVector(16.f, 16.f, 84.f), Jeans);
	Part(TEXT("Torso"), Cylinder.Object, FVector(0.f, 0.f, 25.f), FVector(30.f, 42.f, 60.f), LawnArt::Hex(0x4f7d3a));
	Part(TEXT("Head"), Sphere.Object, FVector(0.f, 0.f, 70.f), FVector(24.f, 24.f, 26.f), LawnArt::Hex(0xc68a64));
	Part(TEXT("Cap"), Sphere.Object, FVector(0.f, 0.f, 79.f), FVector(26.f, 26.f, 12.f), LawnArt::Hex(0xd23a2a));
	// The weed eater: a shaft from the hands down to the spinning head at TipOffset.
	const FVector Hands(25.f, 15.f, 25.f);
	const FVector Tip(85.f, 15.f, -80.f);
	Part(TEXT("Shaft"), Cylinder.Object, (Hands + Tip) / 2.f, FVector(4.f, 4.f, FVector::Dist(Hands, Tip)),
		LawnArt::Hex(0x888888), FRotationMatrix::MakeFromZ(Hands - Tip).Rotator());
	Part(TEXT("Motor"), Cube.Object, Hands - FVector(12.f, 0.f, -10.f), FVector(22.f, 14.f, 16.f), LawnArt::Hex(0xe8681c));
	Part(TEXT("TrimmerHead"), Cylinder.Object, Tip, FVector(20.f, 20.f, 8.f), LawnArt::Hex(0xe8681c));

	CameraArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraArm"));
	CameraArm->SetupAttachment(Collision);
	CameraArm->TargetArmLength = 320.f;
	CameraArm->SetRelativeLocation(FVector(0.f, 0.f, 60.f));
	CameraArm->SetRelativeRotation(FRotator(-15.f, 0.f, 0.f));
	CameraArm->bEnableCameraRotationLag = true;
	CameraArm->CameraRotationLagSpeed = 6.f;
	CameraArm->bDoCollisionTest = true;
	CameraArm->ProbeChannel = ECC_Camera;
	CameraArm->ProbeSize = 12.f;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(CameraArm);
	Camera->FieldOfView = 62.f;
}

FVector ALawnWalker::TipLocation() const
{
	return GetActorTransform().TransformPosition(TipOffset);
}

void ALawnWalker::BeginPlay()
{
	Super::BeginPlay();
	const bool bStandIn = Body->GetSkeletalMeshAsset() == nullptr;
	for (int32 I = 0; I < StandInParts.Num(); ++I)
	{
		if (bStandIn)
		{
			LawnArt::Paint(StandInParts[I], ShapeMaterial, StandInColors[I]);
		}
		else
		{
			StandInParts[I]->SetVisibility(false);
		}
	}
}

void ALawnWalker::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	if (!Lawn)
	{
		if (TActorIterator<ALawnYard> It(GetWorld()); It)
		{
			Lawn = It->Lawn;
		}
	}
	if (IsPlayerControlled())
	{
		Walk(ThrottleInput, SteerInput, DeltaTime);
	}
}

void ALawnWalker::Walk(float Throttle, float Steer, float DeltaTime)
{
	if (bGameplayStopped)
	{
		return;
	}

	AddActorWorldRotation(FRotator(0.f, Steer * TurnRate * DeltaTime, 0.f));
	const float Speed = Throttle * (Throttle >= 0.f ? WalkSpeed : BackSpeed);
	const FVector Before = GetActorLocation();
	const FVector Forward = GetActorForwardVector();
	FHitResult Hit;
	AddActorWorldOffset(Forward * Speed * DeltaTime, true, &Hit);
	if (Hit.bBlockingHit)
	{
		AddActorWorldOffset(FVector::VectorPlaneProject(Forward * Speed * DeltaTime * (1.f - Hit.Time), Hit.Normal), true);
	}
	const FVector Moved = GetActorLocation() - Before;
	MeasuredSpeed = DeltaTime > 0.f ? FVector(Moved.X, Moved.Y, 0.f).Size() / DeltaTime : 0.f;

	int32 NewlyCut = 0;
	if (Lawn)
	{
		const FVector Tip = TipLocation();
		NewlyCut = Lawn->CutSegment(bHasLastTip ? LastTip : Tip, Tip, CutRadius, ULawnGridComponent::StripeFor(Forward));
		LastTip = Tip;
		bHasLastTip = true;
	}
	bCutting = NewlyCut > 0;
}

void ALawnWalker::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
	PlayerInputComponent->BindAxis(TEXT("Throttle"), this, &ALawnWalker::OnThrottle);
	PlayerInputComponent->BindAxis(TEXT("Steer"), this, &ALawnWalker::OnSteer);
	PlayerInputComponent->BindAction(TEXT("Hop"), IE_Pressed, this, &ALawnWalker::OnHop);
}

void ALawnWalker::UnPossessed()
{
	Super::UnPossessed();
	ThrottleInput = 0.f;
	SteerInput = 0.f;
	bHasLastTip = false;
	bCutting = false;
}

void ALawnWalker::OnHop()
{
	if (TActorIterator<ALawnYard> It(GetWorld()); It)
	{
		It->ToggleMower();
	}
}

void ALawnWalker::StopGameplay()
{
	bGameplayStopped = true;
	ThrottleInput = 0.f;
	SteerInput = 0.f;
	MeasuredSpeed = 0.f;
	bCutting = false;
	bHasLastTip = false;
	SetActorTickEnabled(false);
}
