defmodule Pummpcomm.SerialRfSpy do
  @commands %{
    cmd_get_state:       0x01,
    cmd_get_version:     0x02,
    cmd_get_packet:      0x03,
    cmd_send_packet:     0x04,
    cmd_send_and_listen: 0x05,
    cmd_update_register: 0x06,
    cmd_reset:           0x07
  }

  def do_command(_, _, _, timeout) when timeout <= 0 or timeout == nil, do: {:error, "timeout must be positive"}
  def do_command(serial_pid, command_type, param, timeout) do
    send_command(serial_pid, command_type, param, timeout)
    if command_type == :cmd_reset do
      :timer.sleep(5000)
    end
    get_response(serial_pid, timeout)
  end

  def send_command(_, _, _, timeout) when timeout <= 0 or timeout == nil, do: {:error, "timeout must be positive"}
  def send_command(serial_pid, command_type, param, timeout) do
    command = @commands[command_type]
    Nerves.UART.write(serial_pid, <<command::8>> <> param, timeout)
  end

  def get_response(_, timeout) when timeout <= 0 or timeout == nil, do: {:error, "timeout must be positive"}
  def get_response(serial_pid, timeout) do
    response = Nerves.UART.read(serial_pid, timeout) |> process_response
    case response do
      {:command_interrupted} -> get_response(serial_pid, timeout)
      _                      -> response
    end
  end

  def sync(_, timeout) when timeout <= 0 or timeout == nil, do: {:error, "timeout must be positive"}
  def sync(serial_pid, timeout) do
    send_command(serial_pid, :cmd_get_state, <<>>, timeout)
    {:ok, status} = get_response(serial_pid, timeout)
    IO.puts status
    send_command(serial_pid, :cmd_get_version, <<>>, timeout)
    {:ok, version} = get_response(serial_pid, timeout)
    IO.puts version
  end

  @command_interrupted 0xBB
  defp process_response({:ok, <<>>}), do: {:empty}
  defp process_response({:ok, data = <<@command_interrupted::8, _::binary>>}) when byte_size(data) <= 2, do: {:command_interrupted}
  defp process_response({:ok, data}), do: {:ok, data}
end
