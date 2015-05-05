# Run this script from the Spell root with
#
#     mix spell.example.pubsub

defmodule PubSub do
  @moduledoc """
  The `PubSub` module implements the example noise publisher (`PubSub.Noise`)
  and printer subscriber (`PubSub.Printer`).
  """

  defmodule PubRepeatedly do
    @moduledoc """
    The `PubSub.PubRepeatedly` module implements a peer which will publish
    the results of a repeatedly called 0-arity function.
    """

    # Module Attributes


    defstruct [:publisher, :topic, :generator, :gen_state, interval: 500]

    # Public Functions

    @doc """
    Start the repeatedly publisher.
    """
    def start_link(topic, generator, gen_state \\ nil, options \\ []) do
      {:ok, spawn_link(fn -> init(topic, generator, gen_state, options) end)}
    end

    # Private Functions

    defp init(topic, generator, gen_state, options) do
      {:ok, publisher} = PubSub.new_peer([Spell.Role.Publisher], options)
      %__MODULE__{publisher: publisher,
                  topic: topic,
                  generator: generator,
                  gen_state: gen_state}
        |> struct(options)
        |> loop()
    end

    defp loop(state) do
      receive do
        :stop -> :ok
      after
        state.interval ->
          {:ok, message, gen_state} = state.generator.(state.gen_state)
          {:ok, _} = Spell.call_publish(state.publisher,
                                        state.topic,
                                        message)
          loop(%{state | gen_state: gen_state})
      end
    end

  end

  defmodule SubLogger do
    @moduledoc """
    The `PubSub.SubLogger` module subscribes to topics and prints
    messages as they arrive.
    """
    require Logger

    defstruct [:subscriber, :topics, timeout: 1000]

    # Public Functions

    @doc """
    Start the printer subscriber.
    """
    def start_link(topics, options \\ []) do
      {:ok, spawn_link(fn -> init(topics, options) end)}
    end

    # Private Functions

    defp init(topic, options) when is_binary(topic) do
      init([topic], options)
    end
    defp init(topics, options) when is_list(topics) do
      {:ok, subscriber} = PubSub.new_peer([Spell.Role.Subscriber], options)
      for topic <- topics do
        {:ok, _publication} = Spell.call_subscribe(subscriber, topic)
      end
      %__MODULE__{subscriber: subscriber, topics: topics}
        |> struct(options)
        |> loop()
    end

    defp loop(state) do
      receive do
        :stop   -> :ok
        {Spell.Peer, pid, message} ->
          Logger.info(fn -> "From #{inspect(pid)}: #{inspect(message)}" end)
          loop(state)
      after
        state.timeout -> {:error, :timeout}
      end
    end
  end

  # Public Interface

  @doc """
  Shared helper function for create a new peer configured with `roles` and
  `options`.
  """
  def new_peer(roles, options) do
    uri   = Keyword.get(options, :uri, Crossbar.get_uri)
    realm = Keyword.get(options, :realm, Crossbar.realm)
    Spell.connect(uri, realm: realm, roles: roles)
  end

end


alias PubSub.PubRepeatedly
alias PubSub.SubLogger

# Preamble
randoms_topic      = "com.spell.example.randoms"
command_line_topic = "com.spell.example.command_line"
command_line_words = ~w|About twenty years ago Jobs and Wozniak, the founders of Apple, came up with the very strange idea of selling information processing machines for use in the home. The business took off, and its founders made a lot of money and received the credit they deserved for being daring visionaries. But around the same time, Bill Gates and Paul Allen came up with an idea even stranger and more fantastical: selling computer operating systems. This was much weirder than the idea of Jobs and Wozniak. A computer at least had some sort of physical reality to it. It came in a box, you could open it up and plug it in and watch lights blink. An operating system had no tangible incarnation at all. It arrived on a disk, of course, but the disk was, in effect, nothing more than the box that the OS came in. The product itself was a very long string of ones and zeroes that, when properly installed and coddled, gave you the ability to manipulate other very long strings of ones and zeroes. Even those few who actually understood what a computer operating system was were apt to think of it as a fantastically arcane engineering prodigy, like a breeder reactor or a U-2 spy plane, and not something that could ever be (in the parlance of high-tech) "productized."|
# Credit: http://www.cryptonomicon.com/beginning.html

# Start the crossbar testing server
Crossbar.start()

# Start a publisher of random floats ranging from 0-1
{:ok, randoms_publisher} = PubRepeatedly.start_link(
  randoms_topic,
  fn state -> {:ok, [arguments: [:random.uniform()]], state} end)

# Start the In the Command Line intro publisher
# NB: This function will crash on completion. There's no way to complete!
{:ok, command_line_publisher} = PubRepeatedly.start_link(
  command_line_topic,
  fn [word | words] -> {:ok, [arguments: [word]], words} end,
  command_line_words, interval: 150)

# Start the logging subscriber and subscribe it to the two active topics
{:ok, subscriber} = SubLogger.start_link([randoms_topic, command_line_topic])

# Let it happen
:timer.sleep(10000)

# Kill all the processes with a `:stop` message
for pid <- [randoms_publisher,
            command_line_publisher,
            subscriber], do: send(pid, :stop)
