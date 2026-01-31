defmodule Coinchette.GameServerSupervisor do
  @moduledoc """
  DynamicSupervisor that manages GameServer processes.

  Each active game has its own GameServer process supervised by this supervisor.
  """
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  @doc """
  Starts a GameServer for a specific game.
  """
  def start_game(game_id) do
    spec = {Coinchette.GameServer, game_id}
    DynamicSupervisor.start_child(__MODULE__, spec)
  end

  @doc """
  Stops a GameServer for a specific game.
  """
  def stop_game(game_id) do
    case Registry.lookup(Coinchette.GameRegistry, game_id) do
      [{pid, _}] ->
        DynamicSupervisor.terminate_child(__MODULE__, pid)

      [] ->
        :ok
    end
  end

  @doc """
  Lists all running game servers.
  """
  def list_games do
    DynamicSupervisor.which_children(__MODULE__)
    |> Enum.map(fn {_, pid, _, _} -> pid end)
  end
end
