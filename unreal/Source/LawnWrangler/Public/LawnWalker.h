#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "LawnWalker.generated.h"

class UCapsuleComponent;
class UCameraComponent;
class USpringArmComponent;
class USkeletalMeshComponent;
class ULawnGridComponent;

/**
 * The landscaper on foot with a weed eater, ported from the Godot version.
 * Steers like the mower (A/D turn, W/S walk) so the chase camera stays
 * behind. The trimmer cuts a small circle in front of them the whole time
 * they are on foot, which is how you reach grass along the fence and around
 * beds.
 *
 * Give the Blueprint child (BP_Walker) a character model on Body, for
 * example a MetaHuman or the Unreal mannequin holding a trimmer.
 */
UCLASS()
class LAWNWRANGLER_API ALawnWalker : public APawn
{
	GENERATED_BODY()

public:
	ALawnWalker();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Walker")
	TObjectPtr<UCapsuleComponent> Collision;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Walker")
	TObjectPtr<USkeletalMeshComponent> Body;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Walker")
	TObjectPtr<USpringArmComponent> CameraArm;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Walker")
	TObjectPtr<UCameraComponent> Camera;

	UPROPERTY(EditAnywhere, Category = "Walker")
	float WalkSpeed = 220.f;

	UPROPERTY(EditAnywhere, Category = "Walker")
	float BackSpeed = 120.f;

	UPROPERTY(EditAnywhere, Category = "Walker")
	float TurnRate = 150.f;

	UPROPERTY(EditAnywhere, Category = "Walker")
	float CutRadius = 30.f;

	/** Where the trimmer head spins, relative to the landscaper (forward is +X). */
	UPROPERTY(EditAnywhere, Category = "Walker")
	FVector TipOffset = FVector(85.f, 15.f, -85.f);

	/** Ground speed achieved last frame, in cm/s; feed the walk animation from this. */
	UPROPERTY(BlueprintReadOnly, Category = "Walker")
	float MeasuredSpeed = 0.f;

	UPROPERTY(BlueprintReadOnly, Category = "Walker")
	bool bCutting = false;

	UPROPERTY()
	TObjectPtr<ULawnGridComponent> Lawn;

	/** Moves and trims for one frame. Public so tests can drive it directly. */
	void Walk(float Throttle, float Steer, float DeltaTime);

	FVector TipLocation() const;

	virtual void Tick(float DeltaTime) override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual void UnPossessed() override;

private:
	float ThrottleInput = 0.f;
	float SteerInput = 0.f;
	FVector LastTip = FVector::ZeroVector;
	bool bHasLastTip = false;

	void OnThrottle(float Value) { ThrottleInput = Value; }
	void OnSteer(float Value) { SteerInput = Value; }
	void OnHop();
};
