defmodule BasicToken do
  alias ExW3.Contract

  @contract :BasicToken
  @output_path "test/contracts"
  @default_gas 5_000_000

  def deploy(account, options \\ %{}) do
    Contract.register(@contract, abi: abi())
    options = Map.merge(options, %{from: account, gas: @default_gas})
    {:ok, address, _} = Contract.deploy(@contract, bin: bin(), options: options)
    Contract.at(@contract, address)

    %{@contract => address}
  end

  def transfer(account, recipient, amount) do
    recipient = ExW3.to_decimal(recipient)
    Contract.send(@contract, :transfer, [recipient, amount], %{from: account, gas: @default_gas})
  end

  def balance(address) do
    {:ok, balance} = Contract.call(@contract, :balanceOf, [address |> ExW3.to_decimal()])
    balance
  end

  defp bin, do: ExW3.load_bin(output_file_path(:bin))
  defp abi, do: ExW3.load_abi(output_file_path(:abi))
  defp output_file_path(ext), do: "#{@output_path}/#{@contract}.#{ext}"
end
