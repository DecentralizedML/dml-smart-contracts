defmodule PaymentHub do
  alias ExW3.Contract

  @contract :PaymentHub
  @output_path "test/contracts"
  @default_gas 5_000_000

  def deploy(account, tokenAddress, options \\ %{}) do
    Contract.register(@contract, abi: abi())

    token = ExW3.to_decimal(tokenAddress)
    options = Map.merge(options, %{from: account, gas: @default_gas})
    {:ok, address, _} = Contract.deploy(@contract, bin: bin(), options: options, args: [token])

    Contract.at(@contract, address)

    %{@contract => address}
  end

  def sign_and_withdraw(signer, recipient, amount, nonce) do
    message = <<ExW3.to_decimal(recipient)::size(160), "_", <<amount::size(256)>>, "_", (<<nonce::size(256)>>)>>
    signature = sign_message(signer, message)
    signed_withdraw(recipient, amount, nonce, signature)
  end

  def signed_withdraw(account, amount, nonce, signature) do
    recipient = ExW3.to_decimal(account)
    Contract.send(@contract, :withdraw, [recipient, amount, nonce, signature], %{from: account, gas: @default_gas})
  end

  def setFee(account, value) do
    Contract.send(@contract, :setFee, [value], %{from: account, gas: @default_gas})
  end

  def blacklistAddress(account, address) do
    address = ExW3.to_decimal(address)
    Contract.send(@contract, :blacklistAddress, [address], %{from: account, gas: @default_gas})
  end

  defp sign_message(signer, message) do
    message = ExW3.keccak256(message)
    {:ok, signature} = ExW3.eth_sign(signer, message)
    signature |> ExW3.to_decimal() |> :binary.encode_unsigned()
  end

  defp bin, do: ExW3.load_bin(output_file_path(:bin))
  defp abi, do: ExW3.load_abi(output_file_path(:abi))
  defp output_file_path(ext), do: "#{@output_path}/#{@contract}.#{ext}"
end
