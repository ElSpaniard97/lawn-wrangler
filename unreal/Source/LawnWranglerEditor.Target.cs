using UnrealBuildTool;

public class LawnWranglerEditorTarget : TargetRules
{
	public LawnWranglerEditorTarget(TargetInfo Target) : base(Target)
	{
		Type = TargetType.Editor;
		DefaultBuildSettings = BuildSettingsVersion.Latest;
		IncludeOrderVersion = EngineIncludeOrderVersion.Latest;
		ExtraModuleNames.Add("LawnWrangler");
	}
}
