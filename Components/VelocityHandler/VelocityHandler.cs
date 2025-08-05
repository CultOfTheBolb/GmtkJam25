using Godot;

[GlobalClass]
public partial class VelocityHandler : Node
{
    [ExportGroup("Refrences")]
    [Export]
    private CharacterBody3D parent;

    private Vector3 velocity;


    /*
     * Handles moving and updating the velocity of Parent.
     * This method does not handle multiplying velocity by a speed value,
     * the inputs of SetVelocity should already be multiplied by a some speed if neccesary.
     * This does, however handle multiplying by delta time.
     * */
    public override void _Process(double delta)
    {
        if (parent is null)
        {
            GD.PrintErr("Must set parent for VelocityHandler.");
            return;
        }

        Vector3 finalVelocity = velocity * (float)delta;

        parent.Velocity = finalVelocity;

        parent.MoveAndSlide();
    }

    /*
     * Inputs are NaN by default so we are able to set the specific components
     * Of the Velocity vecotor individually,
     * without having to explicitly retain the others.
     * The inputs to this function must be multiplied by some speed if neccesary.
     * However multiplying by delta time is handled by _PhysicsProcess,
     * inputs passed to this function that are already multiplied by delta time will cause unexpected results.
     * */
    public void SetVelocity(float x = float.NaN, float y = float.NaN, float z = float.NaN, bool normalize = true)
    {
        if (x is float.NaN)
        {
            x = velocity.X;
        }
        if (y is float.NaN)
        {
            y = velocity.Y;
        }
        if (z == float.NaN)
        {
            z = velocity.Z;
        }

        if (!normalize)
        {
            velocity = new Vector3(x, y, z);

            return;
        }

        velocity = new Vector3(x, y, z).Normalized();
    }
}
