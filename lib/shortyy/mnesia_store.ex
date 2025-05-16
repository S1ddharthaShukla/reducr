defmodule Shortyy.MnesiaStore do
  @moduledoc """
  Handles Mnesia setup and interactions for the link shortener.
  """

  require Logger
  # Import Record module for defrecord macro
  require Record

  # Define record structures for Mnesia
  # :links stores the mapping from short_id (key) to long_url
  Record.defrecord(:links, short_id: nil, long_url: nil, created_at: nil)

  # :counters stores our global counter for generating short_ids
  Record.defrecord(:counters, name: nil, value: 0)

  @links_table :links
  @counters_table :counters
  @default_counter_key :link_counter

  # Base62 characters for encoding
  @chars "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
         |> String.graphemes()

  @base 62

  # --- Public API ---

  def start_mnesia do
    # Create schema
    node_name = node()
    case :mnesia.create_schema([node_name]) do
      :ok -> Logger.info("Mnesia schema created")
      {:error, {_, {:already_exists, _}}} -> Logger.info("Mnesia schema already exists")
      error -> Logger.error("Failed to create Mnesia schema: #{inspect(error)}")
    end
    
    # Start Mnesia
    case :mnesia.start() do
      :ok ->
        Logger.info("Mnesia started successfully.")
        create_schema_and_tables()

      {:error, {:already_started, _Node}} ->
        Logger.info("Mnesia already started.")
        create_schema_and_tables()

      {:error, reason} ->
        Logger.error("Failed to start Mnesia: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def stop_mnesia do
    :mnesia.stop()
    Logger.info("Mnesia stopped.")
  end

  def create_short_link(long_url) do
    case next_id() do
      {:ok, id} ->
        short_id = encode_id(id)
        timestamp = DateTime.utc_now()
        link_record = links(short_id: short_id, long_url: long_url, created_at: timestamp)

        # Using a transaction for atomicity of counter increment and link creation is safer
        atomic_write_fun = fn ->
          :mnesia.write(@links_table, link_record, :write)
        end

        case :mnesia.transaction(atomic_write_fun) do
          {:atomic, _} ->
            {:ok, short_id}
          {:aborted, reason} ->
            Logger.error("Failed to create short link (transaction aborted): #{inspect(reason)}")
            {:error, :mnesia_transaction_failed}
        end
      {:error, reason} ->
        Logger.error("Failed to get next ID: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_long_url(short_id) when is_binary(short_id) do
    # Dirty read for maximum speed
    case :mnesia.dirty_read(@links_table, short_id) do
      [links(short_id: ^short_id, long_url: long_url, created_at: _)] -> 
        {:ok, long_url}
      [] -> 
        {:error, :not_found}
      other ->
        Logger.error("Unexpected Mnesia read result: #{inspect(other)}")
        {:error, :mnesia_error}
    end
  end

  # --- Mnesia Initialization ---
  defp create_schema_and_tables do
    node_name = node()

    # Create :links table
    case :mnesia.create_table(@links_table, [
           attributes: links_attributes(),
           ram_copies: [node_name],
           record_name: :links,
           type: :set
         ]) do
      {:atomic, :ok} -> Logger.info("Table '#{@links_table}' created.")
      {:aborted, {:already_exists, @links_table}} -> Logger.info("Table '#{@links_table}' already exists.")
      {:aborted, reason} -> Logger.error("Failed to create table '#{@links_table}': #{inspect(reason)}")
    end

    # Create :counters table
    case :mnesia.create_table(@counters_table, [
           attributes: counters_attributes(),
           ram_copies: [node_name],
           record_name: :counters,
           type: :set
         ]) do
      {:atomic, :ok} ->
        Logger.info("Table '#{@counters_table}' created.")
        initialize_counter()
      {:aborted, {:already_exists, @counters_table}} ->
        Logger.info("Table '#{@counters_table}' already exists.")
        initialize_counter()
      {:aborted, reason} -> 
        Logger.error("Failed to create table '#{@counters_table}': #{inspect(reason)}")
    end
    
    # Wait for tables, useful especially after starting/restarting
    :mnesia.wait_for_tables([@links_table, @counters_table], 5000)
    
    :ok
  end

  defp initialize_counter do
    # Initialize counter if it doesn't exist using a transaction for safety
    init_fun = fn ->
      case :mnesia.read(@counters_table, @default_counter_key, :write) do
        [] -> # Counter does not exist, create it
          counter_record = counters(name: @default_counter_key, value: 0)
          :mnesia.write(@counters_table, counter_record, :write)
        _ -> # Counter already exists
          :ok
      end
    end

    case :mnesia.transaction(init_fun) do
      {:atomic, _} -> 
        Logger.info("Counter '#{@default_counter_key}' initialized or already exists.")
      {:aborted, reason} -> 
        Logger.error("Failed to initialize counter: #{inspect(reason)}")
    end
  end

  # --- Short ID Generation ---
  defp next_id do
    # Using a transaction for robust counter increment
    update_fun = fn ->
      case :mnesia.read(@counters_table, @default_counter_key, :write) do
        [counters(name: @default_counter_key, value: current_val)] ->
          new_val = current_val + 1
          counter_record = counters(name: @default_counter_key, value: new_val)
          :mnesia.write(@counters_table, counter_record, :write)
          new_val
        [] ->
          Logger.warning("Counter not found during next_id, attempting to re-initialize.")
          counter_record = counters(name: @default_counter_key, value: 1)
          :mnesia.write(@counters_table, counter_record, :write)
          1
        other ->
          Logger.error("Unexpected read result in next_id: #{inspect(other)}")
          :mnesia.abort({:error, :counter_read_failed_unexpected_format})
      end
    end

    case :mnesia.transaction(update_fun) do
      {:atomic, new_id} when is_integer(new_id) ->
        {:ok, new_id}
      {:aborted, reason} ->
        Logger.error("Failed to increment counter: #{inspect(reason)}")
        {:error, :counter_increment_failed}
      other ->
        Logger.error("Unexpected transaction result for next_id: #{inspect(other)}")
        {:error, :counter_increment_unexpected_result}
    end
  end

  # Simple Base62 Encoding
  defp encode_id(0), do: List.first(@chars) # Handle 0 explicitly
  defp encode_id(id) when is_integer(id) and id > 0 do
    do_encode(id, "")
  end

  defp do_encode(0, acc), do: acc
  defp do_encode(id, acc) do
    remainder = rem(id, @base)
    quotient = div(id, @base)
    do_encode(quotient, Enum.at(@chars, remainder) <> acc)
  end

  # Define attributes for record creation
  defp links_attributes, do: [:short_id, :long_url, :created_at]
  defp counters_attributes, do: [:name, :value]

  # --- For Development/Testing: Clear Tables ---
  def clear_links_table do
    :mnesia.transaction(fn -> :mnesia.clear_table(@links_table) end)
    Logger.info("Links table cleared.")
  end

  def clear_counters_table do
    :mnesia.transaction(fn ->
      :mnesia.clear_table(@counters_table)
      initialize_counter()
    end)
    Logger.info("Counters table cleared and re-initialized.")
  end
end
