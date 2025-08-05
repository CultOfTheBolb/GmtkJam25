using Godot;

public partial class Idling : State
{
    /*
     * Handles entering the Moving State when a movement input is pressed.
     * */
    public override void InputUpdate(InputEvent input)
    {
        base.InputUpdate(input);

        if (Input.GetVector("MoveLeft", "MoveRight", "MoveForward", "MoveBackward") != new Vector2(0, 0))
        {
            EmitSignal(SignalName.Transitioned, this, (StringName)"Moving");
        }
    }
}
