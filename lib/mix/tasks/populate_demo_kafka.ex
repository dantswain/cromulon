defmodule Mix.Tasks.PopulateDemoKafka do
  @moduledoc false

  use Mix.Task

  @shortdoc "Populate messages to kafka for demo/testing"
  def run(_) do
    Application.ensure_all_started(:kafka_ex)
    {:ok, worker} = KafkaEx.create_worker(:cromulon_populator, uris: [{"localhost", 9092}])


    populate_sales_events(worker)
    populate_log_events(worker)

    KafkaEx.stop_worker(worker)
  end

  defp populate_sales_events(worker) do
    # needs to match what we create in docker-compose.yml
    topic = "sales_events"
    partition_count = 4
    n = partition_count * 10

    msg_templates = [
      %{
        event_id: 0,
        customer_id: 0,
        sold: true,
        item: %{
          name: "A fun toy!",
          price: 123.45,
          notes: [
            "This", "is", "a", "list"
          ]
        }
      },
      %{
        event_id: 0,
        customer_id: 0,
        sold: false,
        item: %{
          name: "A less-than-fun toy",
          price: 0.99,
          notes: "This one is not a list"
        }
      }
    ]

    produce_messages(topic, partition_count, n, msg_templates, worker)
  end

  defp populate_log_events(worker) do
    # needs to match what we create in docker-compose.yml
    topic = "log_events"
    partition_count = 8
    n = partition_count * 4

    msg_templates = [
      %{
        event_id: 0,
        device_id: "abc123",
        log: "idunno something happened"
      }
    ]

    produce_messages(topic, partition_count, n, msg_templates, worker)
  end

  defp produce_messages(topic, partition_count, n, msg_templates, worker) do
    for id <- 0..n do
      msg = Enum.at(msg_templates, rem(id, length(msg_templates)))
      msg = %{msg | event_id: id}
      partition = rem(id, partition_count)

      KafkaEx.produce(topic, partition, Poison.encode!(msg), worker_name: worker)
    end
  end
end
