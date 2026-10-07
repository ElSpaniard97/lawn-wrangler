#include "LawnWalker.h"

#include "Camera/CameraComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/InputComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "GameFramework/SpringArmComponent.h"
#include "LawnGridComponent.h"
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

	CameraArm = CreateDefaultSubobject<USpringArmComponent>(TEXT("CameraArm"));
	CameraArm->SetupAttachment(Collision);
	CameraArm->TargetArmLength = 320.f;
	CameraArm->SetRelativeLocation(FVector(0.f, 0.f, 60.f));
	CameraArm->SetRelativeRotation(FRotator(-15.f, 0.f, 0.f));
	CameraArm->bEnableCameraRotationLag = true;
	CameraArm->CameraRotationLagSpeed = 6.f;
	CameraArm->bDoCollisionTest = false;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetupAttachment(CameraArm);
	Camera->FieldOfView = 62.f;
}

FVector ALawnWalker::TipLocation() const
{
	return GetActorTransform().TransformPosition(TipOffset);
}

void ALawnWalker::Tick(float DeltaTime)
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
	if (IsPlayerControlled())
	{
		Walk(ThrottleInput, SteerInput, DeltaTime);
	}
}

void ALawnWalker::Walk(float Throttle, float Steer, float DeltaTime)
{
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
	for (TActorIterator<ALawnYard> It(GetWorld()); It; ++It)
	{
		It->ToggleMower();
		return;
	}
}
