using Godot;

public partial class State : Node
{
    [Signal]
    public delegate void TransitionedEventHandler(State state, StringName newStateName);


    public CharacterBody3D parent;


    /*
     * To be defined in Inherited classes if neccesary.
     * */
    public virtual void Enter() { }

    public virtual void Exit() { }

    /*
     * Triggered by respective built in godot functions within parent StateMachine.
     * */
    public virtual void InputUpdate(InputEvent input) { }

    public virtual void Update(double delta) { }

    public virtual void PhysicsUpdate(double delta) { }
}
