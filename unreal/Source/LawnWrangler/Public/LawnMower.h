#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Pawn.h"
#include "LawnMower.generated.h"

class UBoxComponent;
class UCameraComponent;
class USpringArmComponent;
class UStaticMeshComponent;
class ULawnGridComponent;

/**
 * Arcade zero-turn mower, ported from the Godot version. Cuts the lawn grid
 * under its deck while someone is driving, the blades are on and it is
 * moving. The blade is narrower than the body, so the strip of grass right
 * against the fence and around beds is left for the weed eater.
 *
 * Give the Blueprint child (BP_Mower) a mower model on Body; everything
 * else works from code.
 */
UCLASS()
class LAWNWRANGLER_API ALawnMower : public APawn
{
	GENERATED_BODY()

public:
	ALawnMower();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Mower")
	TObjectPtr<UBoxComponent> Collision;

	/** The mower model. Assign a mesh in the Blueprint (for example a Fab zero-turn mower). */
	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Mower")
	TObjectPtr<UStaticMeshComponent> Body;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Mower")
	TObjectPtr<USpringArmComponent> CameraArm;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Mower")
	TObjectPtr<UCameraComponent> Camera;

	/** Top speeds and handling, in centimetres and degrees per second. */
	UPROPERTY(EditAnywhere, Category = "Mower")
	float MaxSpeed = 400.f;

	UPROPERTY(EditAnywhere, Category = "Mower")
	float ReverseSpeed = 150.f;

	UPROPERTY(EditAnywhere, Category = "Mower")
	float Acceleration = 300.f;

	UPROPERTY(EditAnywhere, Category = "Mower")
	float Braking = 600.f;

	UPROPERTY(EditAnywhere, Category = "Mower")
	float TurnRate = 92.f;

	UPROPERTY(EditAnywhere, Category = "Mower")
	float CutRadius = 40.f;

	/** Where the blade sits, relative to the mower (forward is +X). */
	UPROPERTY(EditAnywhere, Category = "Mower")
	FVector BladeOffset = FVector(15.f, 0.f, 0.f);

	/** How far a full tank goes with the blades on, in centimetres; twice that with them off. */
	UPROPERTY(EditAnywhere, Category = "Mower")
	float TankDistance = 120000.f;

	/** Share of full speed left when the tank is empty. */
	UPROPERTY(EditAnywhere, Category = "Mower")
	float FumesSpeed = 0.3f;

	UPROPERTY(BlueprintReadOnly, Category = "Mower")
	bool bBladesOn = true;

	UPROPERTY(BlueprintReadOnly, Category = "Mower")
	bool bDriving = true;

	/** Fuel left, from 0 (empty) to 1 (full). */
	UPROPERTY(BlueprintReadOnly, Category = "Mower")
	float Fuel = 1.f;

	/** Ground speed actually achieved last frame, in cm/s (0 when blocked by a wall). */
	UPROPERTY(BlueprintReadOnly, Category = "Mower")
	float MeasuredSpeed = 0.f;

	/** True while the blades cut new grass this frame; drive clippings particles from this. */
	UPROPERTY(BlueprintReadOnly, Category = "Mower")
	bool bCutting = false;

	UPROPERTY()
	TObjectPtr<ULawnGridComponent> Lawn;

	void ToggleBlades() { bBladesOn = !bBladesOn; }
	void Refuel(float Amount) { Fuel = FMath::Min(1.f, Fuel + Amount); }

	/** Moves and cuts for one frame. Public so tests can drive it directly. */
	void Drive(float Throttle, float Steer, float DeltaTime);

	virtual void Tick(float DeltaTime) override;
	virtual void SetupPlayerInputComponent(UInputComponent* PlayerInputComponent) override;
	virtual void PossessedBy(AController* NewController) override;
	virtual void UnPossessed() override;

private:
	float Speed = 0.f;
	float ThrottleInput = 0.f;
	float SteerInput = 0.f;
	FVector LastBlade = FVector::ZeroVector;
	bool bHasLastBlade = false;

	void OnThrottle(float Value) { ThrottleInput = Value; }
	void OnSteer(float Value) { SteerInput = Value; }
	void OnToggleBlades() { ToggleBlades(); }
	void OnHop();
};
