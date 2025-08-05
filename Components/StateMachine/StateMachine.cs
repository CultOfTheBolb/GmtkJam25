using Godot;
using Godot.Collections;

[GlobalClass]
public partial class StateMachine : Node
{
    [ExportGroup("State")]
    [Export]
    private State initialState;
    [ExportGroup("Refrences")]
    [Export]
    private CharacterBody3D parent;

    public State currentState { get; set; }

    public Dictionary<StringName, State> states { get; set; } = new Dictionary<StringName, State>();


    /*
     * Initialize The StateMachine with all children of type State.
     * Manage the initial state of the StateMachine.
     * */
    public override void _Ready()
    {
        foreach (State child in GetChildren())
        {

            states.Add(child.Name, child);
            child.Transitioned += (State state, StringName newStateName) =>
            {
                OnStateTransition(state, newStateName);
            };
        }

        if (initialState is State)
        {
            initialState.parent = parent;
            initialState.Enter();
            currentState = initialState;
        }
    }

    /*
     * Handle the builtin process and event based functions of the current State.
     * */
    public override void _Process(double delta)
    {
        currentState.Update(delta);
    }

    public override void _PhysicsProcess(double delta)
    {
        currentState.PhysicsUpdate(delta);
    }

    public override void _Input(InputEvent @event)
    {
        currentState.InputUpdate(@event);
    }


    /*
     * Can only be called by the CurrentState signaling a state transition.
     * Exiting the CurrentState and entering the NewState.
     * */
    private void OnStateTransition(State state, StringName newStateName)
    {
        if (state != currentState)
        {
            return;
        }

        State newState = states[newStateName];
        if (newState is null)
        {
            GD.PrintErr("newStateName does not correspond with a State present in the StateMachine.");
            return;
        }

        currentState.Exit();

        newState.parent = parent;
        newState.Enter();

        currentState = newState;
    }
}
