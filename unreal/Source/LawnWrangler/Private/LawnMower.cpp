#include "LawnMower.h"

#include "Camera/CameraComponent.h"
#include "Components/BoxComponent.h"
#include "Components/InputComponent.h"
#include "Components/StaticMeshComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "LawnGridComponent.h"
#include "LawnYard.h"
#include "EngineUtils.h"

ALawnMower::ALawnMower()
{
	PrimaryActorTick.bCanEverTick = true;

	Collision = CreateDefaultSubobject<UBoxComponent>(TEXT("Collision"));
	Collision->SetBoxExtent(FVector(80.f, 65.f, 40.f));
	Collision->SetCollisionProfileName(TEXT("Pawn"));
	RootComponent = Collision;

	Body = CreateDefaultSubobject<UStaticMeshComponent>(TEXT("Body"));
	Body->SetupAttachment(Collision);
	Body->SetRelativeLocation(FVector(0.f, 0.f, -40.f));
	Body->SetCollisionEnabled(ECollisionEnabled::NoCollision);

	// Chase camera: low behind the driver, like the reference picture.
	CameraArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraArm"));
	CameraArm->SetupAttachment(Collision);
	CameraArm->TargetArmLength = 380.f;
	CameraArm->SetRelativeLocation(FVector(0.f, 0.f, 110.f));
	CameraArm->SetRelativeRotation(FRotator(-15.f, 0.f, 0.f));
	CameraArm->bEnableCameraLag = true;
	CameraArm->bEnableCameraRotationLag = true;
	CameraArm->CameraRotationLagSpeed = 6.f;
	CameraArm->bDoCollisionTest = false;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(CameraArm);
	Camera->FieldOfView = 62.f;
}

void ALawnMower::Tick(float DeltaTime)
{
	Super::Tick(DeltaTime);
	if (!Lawn)
	{
		for (TActorIterator<ALawnYard> It(GetWorld()); It; ++It)
		{
			Lawn = It->Lawn;
			break;
		}
	}
	Drive(bDriving ? ThrottleInput : 0.f, bDriving ? SteerInput : 0.f, DeltaTime);
}

void ALawnMower::Drive(float Throttle, float Steer, float DeltaTime)
{
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
	for (TActorIterator<ALawnYard> It(GetWorld()); It; ++It)
	{
		It->ToggleMower();
		return;
	}
}
