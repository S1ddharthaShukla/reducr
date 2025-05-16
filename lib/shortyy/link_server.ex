defmodule Shortyy.LinkServer do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def create_short_link(long_url) do
    GenServer.call(__MODULE__, {:create_short_link, long_url})
  end

  def get_long_url(short_id) do
    GenServer.call(__MODULE__, {:get_long_url, short_id})
  end

  def clear_all do
    GenServer.call(__MODULE__, :clear_all)
  end

  @impl true
  def init(_opts) do
    initial_state = %{
      links: %{},
      counter: 0,
      base62_chars: "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ" |> String.graphemes()
    }
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:create_short_link, long_url}, _from, state) do
    new_counter = state.counter + 1
    short_id = encode_id(new_counter, state.base62_chars)
    new_links = Map.put(state.links, short_id, long_url)

    new_state = %{state | links: new_links, counter: new_counter}
    {:reply, {:ok, short_id}, new_state}
  end

  @impl true
  def handle_call({:get_long_url, short_id}, _from, state) do
    case Map.get(state.links, short_id) do
      nil -> {:reply, {:error, :not_found}, state}
      long_url -> {:reply, {:ok, long_url}, state}
    end
  end

  @impl true
  def handle_call(:clear_all, _from, state) do
    new_state = %{state | links: %{}, counter: 0}
    {:reply, :ok, new_state}
    IO.puts("LinkServer state cleared.")
    {:reply, :ok, new_state}
  end

  defp encode_id(0, chars), do: List.first(chars)
  defp encode_id(id, chars) when is_integer(id) and id > 0 do
    do_encode(id, "", chars, length(chars))
  end

  defp do_encode(0, acc, _chars, _base) when acc != "", do: acc
  defp do_encode(0, _acc, chars, _base), do: List.first(chars) 
  defp do_encode(id, acc, chars, base) do
    remainder = rem(id, base)
    quotient = div(id, base)
    do_encode(quotient, Enum.at(chars, remainder) <> acc, chars, base)
  end
end

