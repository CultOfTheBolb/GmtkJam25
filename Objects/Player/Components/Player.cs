using Godot;

public partial class Player : CharacterBody3D
{
	[ExportGroup("Refrences")]
	[Export]
	public StateMachine stateMachine;
}
