using Godot;

public partial class Moving : State
{
    [ExportGroup("Movement")]
    [Export]
    public float speed;
    [ExportGroup("Refrences")]
    [Export]
    public VelocityHandler velocityHandler;


    /*
     * Translates inputs into a movement direction and sends it to velocityHandler.
     * Handles entering the Idling State.
     * */
    public override void Update(double delta)
    {
        base.Update(delta);

        if (velocityHandler is null)
        {
            GD.PrintErr("Must set VelocityHandler for State: Moving.");
            return;
        }

        Vector2 inputDirection = new Vector2();
        inputDirection = Input.GetVector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward");

        if (inputDirection == new Vector2(0, 0))
        {
            EmitSignal(SignalName.Transitioned, this, (StringName)"Idling");
        }

        velocityHandler.SetVelocity(x: inputDirection.X * speed, z: inputDirection.Y * speed, normalize: false);
    }
}
