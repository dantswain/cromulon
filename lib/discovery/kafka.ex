defmodule Cromulon.Discovery.Kafka do
  @moduledoc false

  defmodule Topic do
    @moduledoc false
    use Ecto.Schema

    @primary_key false
    schema "kafka_topics" do
      field(:name, :string)
      field(:partition_count, :integer)
      embeds_many(:schema, :map)
      embeds_many(:partition_ids, {:array, :integer})
      embeds_many(:sample_messages, {:array, :string})
    end
  end

  alias Cromulon.SchemaInference
  alias KafkaEx.Protocol.Metadata.TopicMetadata

  alias Ecto.UUID
  alias Cromulon.Schema
  alias Cromulon.Schema.Edge
  alias Cromulon.Schema.Node
  alias Cromulon.Schema.Source

  require Logger

  def get_identity(seed_host, seed_port) do
    with_kafkaex([{seed_host, seed_port}], fn worker ->
      metadata = KafkaEx.metadata(worker_name: worker)
      urls_from_brokers(metadata.brokers)
    end)
  end

  def describe_cluster(seed_host, seed_port) do
    with_kafkaex([{seed_host, seed_port}], fn worker ->
      metadata = KafkaEx.metadata(worker_name: worker)
      topics = Enum.map(metadata.topic_metadatas, &topic_from_metadata/1)
      urls = urls_from_brokers(metadata.brokers)

      source = describe_source(seed_host, seed_port, metadata)

      topics = describe_topics(metadata, source, worker)

      List.flatten([source | topics])
    end)
  end

  defp describe_source(seed_host, seed_port, metadata) do
    %Source{
      name: "#{seed_host}:#{seed_port}",
      connection_info: urls_from_brokers(metadata.brokers),
      identity: urls_from_brokers(metadata.brokers),
      kind: "kafka cluster",
      uuid: UUID.generate()
    }
  end

  defp describe_topics(metadata, source, worker) do
    Enum.map(metadata.topic_metadatas, fn topic_metadata ->
      name = topic_metadata.topic
      Logger.debug(fn -> "Exploring Kafka topic #{name}" end)
      partition_count = length(topic_metadata.partition_metadatas)

      partition_ids =
        Enum.map(
          topic_metadata.partition_metadatas,
          & &1.partition_id
        )

      node_uuid = UUID.generate()

      messages = get_topic_sample_messages(name, partition_ids, worker, 2)

      node = %Node{
        name: name,
        kind: "kafka topic",
        types: "message",
        attributes: %{partition_ids: Enum.sort(partition_ids)},
        uuid: node_uuid
      }

      edge = %Edge{
        from_uuid: node_uuid,
        to_uuid: source.uuid,
        uuid: UUID.generate(),
        label: "SOURCE"
      }

      if Enum.all?(messages, &String.valid?/1) do
        node = %{node | attributes: Map.put(node.attributes, :sample_messages, messages)}

        message_schema =
          SchemaInference.from_sample_messages(messages, node, "TOPIC_MESSAGE_FIELD")
      else
        message_schema = []
      end

      List.flatten([node, edge, message_schema])
    end)
  end

  defp get_topic_sample_messages(name, partition_ids, worker, lookback) do
    partition_ids
    |> Enum.map(fn partition_id ->
      get_partition_sample_messages(name, partition_id, worker, lookback)
    end)
    |> List.flatten()
  end

  defp get_partition_sample_messages(name, partition_id, worker, lookback) do
    last_offset =
      name
      |> KafkaEx.latest_offset(partition_id, worker)
      |> offset_number_from_resp

    first_offset =
      name
      |> KafkaEx.earliest_offset(partition_id, worker)
      |> offset_number_from_resp

    offset = max(first_offset - 1, last_offset - lookback)

    if offset < 0 do
      Logger.warn(fn -> "Partition #{name}:#{partition_id} has no messages" end)
      []
    else
      resp =
        KafkaEx.fetch(
          name,
          partition_id,
          offset: offset,
          worker_name: worker,
          consumer_group: :no_consumer_group,
          auto_commit: false
        )

      case resp do
        [:timeout] -> get_partition_sample_messages(name, partition_id, worker, lookback)
        [resp] -> messages_from_resp([resp], lookback)
      end
    end
  end

  # translate KafkaEx's weird offset response to an actual number
  defp offset_number_from_resp([resp]) do
    [partition_resp] = resp.partition_offsets
    [offset] = partition_resp.offset
    offset
  end

  defp messages_from_resp([resp], max_num) do
    [partition_resp] = resp.partitions

    partition_resp.message_set
    |> Enum.map(& &1.value)
    |> Enum.take(-max_num)
  end

  defp urls_from_brokers(brokers) do
    brokers
    |> Enum.map(fn b -> "#{b.host}:#{b.port}" end)
    |> Enum.join(",")
  end

  defp topic_from_metadata(topic_metadata = %TopicMetadata{}) do
    name = topic_metadata.topic
    partition_count = length(topic_metadata.partition_metadatas)

    partition_ids =
      Enum.map(
        topic_metadata.partition_metadatas,
        & &1.partition_id
      )

    %Topic{
      name: name,
      partition_count: partition_count,
      partition_ids: partition_ids
    }
  end

  defp with_kafkaex(uris, cb) do
    {:ok, worker} = start_worker(uris)

    result = cb.(worker)

    KafkaEx.stop_worker(worker)

    result
  end

  defp start_worker(uris) do
    case KafkaEx.create_worker(:cromulon_discovery, uris: uris) do
      {:error, {:already_started, pid}} ->
        :ok = KafkaEx.stop_worker(pid)
        start_worker(uris)

      {:ok, worker} ->
        {:ok, worker}
    end
  end
end
