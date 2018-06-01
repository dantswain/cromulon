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

  defmodule Cluster do
    @moduledoc false

    use Ecto.Schema

    @primary_key false
    schema "kafka_clusters" do
      field(:urls, :string)
      field(:name, :string)
      field(:metadata, :any, virtual: true)
      embeds_many(:topics, Cromulon.Discovery.Kafka.Topic)
    end

    def topic_from_name(cluster, topic_name) do
      Enum.find(cluster.topics, fn t -> t.name == topic_name end)
    end

    def uris(cluster) do
      cluster.urls
      |> String.split(",")
      |> Enum.map(fn b -> parse_broker_uri(b) end)
    end

    defp parse_broker_uri(host_port) do
      [host, port_string] = String.split(host_port, ":", parts: 2)
      {host, String.to_integer(port_string)}
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
      kind: "kafka cluster",
      uuid: UUID.generate()
    }
  end

  defp describe_topics(metadata, source, worker) do
    Enum.map(metadata.topic_metadatas, fn(topic_metadata) ->
      name = topic_metadata.topic
      partition_count = length(topic_metadata.partition_metadatas)

      partition_ids =
        Enum.map(
          topic_metadata.partition_metadatas,
          & &1.partition_id
        )

      node_uuid = UUID.generate()
      topic_source = [
        %Node{
          name: name,
          kind: "kafka topic",
          types: "message",
          attributes: %{partition_ids: Enum.sort(partition_ids)},
          uuid: node_uuid
        },
        %Edge{
          from_uuid: node_uuid,
          to_uuid: source.uuid,
          uuid: UUID.generate(),
          label: "SOURCE"
        }
      ]

      messages = get_topic_sample_messages(name, partition_ids, worker, 3)

      topic_source
    end)
  end

  def infer_schemas(cluster) do
    topics =
      Enum.map(cluster.topics, fn topic ->
        schema = SchemaInference.from_sample_messages(topic.sample_messages)
        %{topic | schema: schema}
      end)

    %{cluster | topics: topics}
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

    Logger.debug(fn -> "#{last_offset} #{first_offset} #{offset}" end)

    if offset < 0 do
      Logger.warn(fn -> "Partition #{name}:#{partition_id} has no messages" end)
      []
    else
      name
      |> KafkaEx.fetch(
        partition_id,
        offset: offset,
        worker_name: worker,
        consumer_group: :no_consumer_group,
        auto_commit: false
      )
      |> messages_from_resp(lookback)
    end
  end

  # translate KafkaEx's weird offset response to an actual number
  defp offset_number_from_resp([resp]) do
    [partition_resp] = resp.partition_offsets
    [offset] = partition_resp.offset
    offset
  end

  defp messages_from_resp([resp], max_num) do
    Logger.debug(fn -> "#{inspect(resp)}" end)
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
    {:ok, worker} =
      KafkaEx.create_worker(
        :cromulon_discovery,
        uris: uris
      )

    result = cb.(worker)

    KafkaEx.stop_worker(worker)

    result
  end
end
