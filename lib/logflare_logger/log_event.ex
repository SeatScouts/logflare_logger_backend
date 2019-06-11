defmodule LogflareLogger.LogEvent do
  @moduledoc """
  Parses and encodes incoming Logger messages for further serialization.
  """
  alias LogflareLogger.{Stacktrace, Utils}
  @default_metadata_keys Utils.default_metadata_keys()

  @doc """
  Creates a LogEvent struct when all fields have serializable values
  """
  def new(timestamp, level, message, metadata) do
    log =
      %{
        timestamp: timestamp,
        level: level,
        message: message,
        metadata: metadata
      }
      |> encode_message()
      |> encode_timestamp()
      |> encode_metadata()

    {system_context, user_context} =
      log.metadata
      |> Map.split(@default_metadata_keys)

    log
    |> Map.drop([:metadata])
    |> Map.put(:context, %{
      system: system_context,
      user: user_context
    })
  end

  @doc """
  Encodes message, if is iodata converts to binary.
  """
  def encode_message(%{message: m} = log) do
    %{log | message: to_string(m)}
  end

  @doc """
  Converts erlang datetime tuple into ISO:Extended binary.
  """
  def encode_timestamp(%{timestamp: t} = log) when is_tuple(t) do
    timestamp =
      t
      # |> Timex.to_naive_datetime()
      |> Timex.to_datetime(Timex.Timezone.local())
      |> Timex.format!("{ISO:Extended}")

    %{log | timestamp: timestamp}
  end

  def encode_metadata(%{metadata: meta} = log) do
    meta =
      meta
      |> encode_pid()
      |> encode_crash_reason()

    %{log | metadata: meta}
  end

  @doc """
  Converts pid to string
  """
  def encode_pid(%{pid: pid} = meta) when is_pid(pid) do
    pid =
      pid
      |> :erlang.pid_to_list()
      |> to_string()

    %{meta | pid: pid}
  end

  def encode_pid(meta), do: meta

  @doc """
  Adds formatted stacktrace to the metadata
  """
  def encode_crash_reason(%{crash_reason: cr} = meta) when not is_nil(cr) do
    {_err, stacktrace} = cr

    meta
    |> Map.drop([:crash_reason])
    |> Map.merge(%{stacktrace: Stacktrace.format(stacktrace)})
  end

  def encode_crash_reason(meta), do: meta

  def encode_metadata_charlists(metadata) do
    for {k, v} <- metadata, into: Map.new() do
      v =
        cond do
          is_map(v) -> encode_metadata_charlists(v)
          is_list(v) and List.ascii_printable?(v) -> to_string(v)
          true -> v
        end

      {k, v}
    end
  end
end
