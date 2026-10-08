#include "LawnMower.h"

#include "Camera/CameraComponent.h"
#include "Components/BoxComponent.h"
#include "Components/InputComponent.h"
#include "Components/StaticMeshComponent.h"
#include "Engine/StaticMesh.h"
#include "GameFramework/SpringArmComponent.h"
#include "LawnArt.h"
#include "LawnGridComponent.h"
#include "Materials/MaterialInterface.h"
#include "UObject/ConstructorHelpers.h"
#include "LawnYard.h"
#include "EngineUtils.h"

ALawnMower::ALawnMower()
{
	PrimaryActorTick.bCanEverTick = true;

	Collision = CreateDefaultSubobject<UBoxComponent>(TEXT("Collision"));
	Collision->SetBoxExtent(FVector(80.f, 65.f, 40.f));
	Collision->SetCollisionProfileName(TEXT("Pawn"));
	RootComponent = Collision;

	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cube(LawnArt::CubePath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Cylinder(LawnArt::CylinderPath);
	static ConstructorHelpers::FObjectFinder<UStaticMesh> Sphere(LawnArt::SpherePath);
	static ConstructorHelpers::FObjectFinder<UMaterialInterface> Shape(LawnArt::MaterialPath);
	StandInBody = Cube.Object;
	ShapeMaterial = Shape.Object;

	// The stand-in deck. The collision box runs from 1 cm to 81 cm above the
	// ground, so its centre is 40 cm up and the ground is at Z = -40 here.
	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(Collision);
	Body->SetStaticMesh(StandInBody);
	Body->SetRelativeLocation(FVector(5.f, 0.f, -12.f));
	Body->SetRelativeScale3D(FVector(1.5f, 1.1f, 0.3f));
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	const FRotator Axle(0.f, 0.f, 90.f); // the cylinder's axis turned to point sideways
	const FLinearColor Tyre = LawnArt::Hex(0x1c1c1c);
	auto Part = [&](const TCHAR* Name, UStaticMesh* Mesh, const FVector& At, const FVector& Size, const FLinearColor& Color, const FRotator& Turn = FRotator::ZeroRotator)
	{
		StandInParts.Add(LawnArt::AddPart(this, Collision, Name, Mesh, At, Size, Turn));
		StandInColors.Add(Color);
	};
	Part(TEXT("RearWheelL"), Cylinder.Object, FVector(-45.f, -62.f, -17.f), FVector(46.f, 46.f, 22.f), Tyre, Axle);
	Part(TEXT("RearWheelR"), Cylinder.Object, FVector(-45.f, 62.f, -17.f), FVector(46.f, 46.f, 22.f), Tyre, Axle);
	Part(TEXT("CasterL"), Cylinder.Object, FVector(62.f, -45.f, -28.f), FVector(24.f, 24.f, 10.f), Tyre, Axle);
	Part(TEXT("CasterR"), Cylinder.Object, FVector(62.f, 45.f, -28.f), FVector(24.f, 24.f, 10.f), Tyre, Axle);
	Part(TEXT("Seat"), Cube.Object, FVector(-25.f, 0.f, 10.f), FVector(45.f, 55.f, 14.f), Tyre);
	Part(TEXT("SeatBack"), Cube.Object, FVector(-50.f, 0.f, 32.f), FVector(10.f, 55.f, 40.f), Tyre);
	Part(TEXT("LapBarL"), Cube.Object, FVector(10.f, -30.f, 30.f), FVector(40.f, 5.f, 5.f), LawnArt::Hex(0x777777));
	Part(TEXT("LapBarR"), Cube.Object, FVector(10.f, 30.f, 30.f), FVector(40.f, 5.f, 5.f), LawnArt::Hex(0x777777));
	Part(TEXT("Legs"), Cube.Object, FVector(0.f, 0.f, 22.f), FVector(40.f, 34.f, 14.f), LawnArt::Hex(0x3b4a63));
	Part(TEXT("Torso"), Cylinder.Object, FVector(-25.f, 0.f, 50.f), FVector(38.f, 44.f, 55.f), LawnArt::Hex(0x4f7d3a));
	Part(TEXT("Head"), Sphere.Object, FVector(-25.f, 0.f, 92.f), FVector(24.f, 24.f, 26.f), LawnArt::Hex(0xc68a64));
	Part(TEXT("Cap"), Sphere.Object, FVector(-25.f, 0.f, 101.f), FVector(26.f, 26.f, 12.f), LawnArt::Hex(0xd23a2a));

	// Chase camera: low behind the driver, like the reference picture.
	CameraArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraArm"));
	CameraArm->SetupAttachment(Collision);
	CameraArm->TargetArmLength = 380.f;
	CameraArm->SetRelativeLocation(FVector(0.f, 0.f, 110.f));
	CameraArm->SetRelativeRotation(FRotator(-15.f, 0.f, 0.f));
	CameraArm->bEnableCameraLag = true;
	CameraArm->bEnableCameraRotationLag = true;
	CameraArm->CameraRotationLagSpeed = 6.f;
	CameraArm->bDoCollisionTest = true;
	CameraArm->ProbeChannel = ECC_Camera;
	CameraArm->ProbeSize = 12.f;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(CameraArm);
	Camera->FieldOfView = 62.f;
}

void ALawnMower::BeginPlay()
{
	Super::BeginPlay();
	const bool bStandIn = Body->GetStaticMesh() == StandInBody;
	if (bStandIn)
	{
		LawnArt::Paint(Body, ShapeMaterial, LawnArt::Hex(0xe8681c));
	}
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

void ALawnMower::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	if (!Lawn)
	{
		if (TActorIterator<ALawnYard> It(GetWorld()); It)
		{
			Lawn = It->Lawn;
		}
	}
	Drive(bDriving ? ThrottleInput : 0.f, bDriving ? SteerInput : 0.f, DeltaTime);
}

void ALawnMower::Drive(float Throttle, float Steer, float DeltaTime)
{
	if (bGameplayStopped)
	{
		return;
	}

	float Target = Throttle * (Throttle >= 0.f ? MaxSpeed : ReverseSpeed);
	if (Fuel <= 0.f)
	{
		Target *= FumesSpeed;
	}
	const bool bSpeedingUp = FMath::Abs(Target) > FMath::Abs(Speed) && FMath::Sign(Target) != -FMath::Sign(Speed);
	const float Rate = bSpeedingUp ? Acceleration : Braking;
	Speed = FMath::FInterpConstantTo(Speed, Target, DeltaTime, Rate);

	// Zero-turn mowers barely turn when standing still in this arcade version.
	const float SteeringGain = FMath::Clamp(FMath::Abs(Speed) / 150.f, 0.f, 1.f);
	AddActorWorldRotation(FRotator(0.f, Steer * TurnRate * SteeringGain * FMath::Sign(Speed) * DeltaTime, 0.f));

	const FVector Before = GetActorLocation();
	const FVector Forward = GetActorForwardVector();
	FHitResult Hit;
	AddActorWorldOffset(Forward * Speed * DeltaTime, true, &Hit);
	if (Hit.bBlockingHit)
	{
		// Slide along walls instead of stopping dead.
		const FVector Slide = FVector::VectorPlaneProject(Forward * Speed * DeltaTime * (1.f - Hit.Time), Hit.Normal);
		AddActorWorldOffset(Slide, true);
	}
	const FVector Moved = GetActorLocation() - Before;
	MeasuredSpeed = DeltaTime > 0.f ? FVector(Moved.X, Moved.Y, 0.f).Size() / DeltaTime : 0.f;

	if (bDriving)
	{
		Fuel = FMath::Max(0.f, Fuel - MeasuredSpeed * DeltaTime / TankDistance * (bBladesOn ? 1.f : 0.5f));
	}

	int32 NewlyCut = 0;
	if (bDriving && bBladesOn && Lawn && MeasuredSpeed > 5.f)
	{
		const uint8 Stripe = ULawnGridComponent::StripeFor(Forward);
		const FVector Blade = GetActorTransform().TransformPosition(BladeOffset);
		NewlyCut = Lawn->CutSegment(bHasLastBlade ? LastBlade : Blade, Blade, CutRadius, Stripe);
		LastBlade = Blade;
		bHasLastBlade = true;
	}
	else
	{
		bHasLastBlade = false;
	}
	bCutting = NewlyCut > 0;
}

void ALawnMower::SetupPlayerInputComponent(UInputComponent* PlayerInputComponent)
{
	Super::SetupPlayerInputComponent(PlayerInputComponent);
	PlayerInputComponent->BindAxis(TEXT("Throttle"), this, &ALawnMower::OnThrottle);
	PlayerInputComponent->BindAxis(TEXT("Steer"), this, &ALawnMower::OnSteer);
	PlayerInputComponent->BindAction(TEXT("ToggleBlades"), IE_Pressed, this, &ALawnMower::OnToggleBlades);
	PlayerInputComponent->BindAction(TEXT("Hop"), IE_Pressed, this, &ALawnMower::OnHop);
}

void ALawnMower::PossessedBy(AController* NewController)
{
	Super::PossessedBy(NewController);
	bDriving = true;
}

void ALawnMower::UnPossessed()
{
	Super::UnPossessed();
	bDriving = false;
	ThrottleInput = 0.f;
	SteerInput = 0.f;
}

void ALawnMower::OnHop()
{
	if (TActorIterator<ALawnYard> It(GetWorld()); It)
	{
		It->ToggleMower();
	}
}

void ALawnMower::StopGameplay()
{
	bGameplayStopped = true;
	ThrottleInput = 0.f;
	SteerInput = 0.f;
	MeasuredSpeed = 0.f;
	bCutting = false;
	bDriving = false;
	Speed = 0.f;
	bHasLastBlade = false;
	SetActorTickEnabled(false);
}
