using UnrealBuildTool;

public class LawnWranglerTarget : TargetRules
{
	public LawnWranglerTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Game;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("LawnWrangler");
	}
}
