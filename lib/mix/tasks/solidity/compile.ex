defmodule Mix.Tasks.Solidity.Compile do
  use Mix.Task

  @contract_folder "lib/contracts"
  @output_folder "test/contracts"

  def run(_) do
    contracts()
    |> Enum.filter(fn contract -> should_compile_contract?(contract) end)
    |> Enum.each(fn contract -> compile_contract(contract) end)
  end

  defp contracts do
    Path.wildcard("#{@contract_folder}/*.sol")
  end

  defp compile_contract(contract) do
    System.cmd("solc", ["--abi", "--bin", "--overwrite", "-o", @output_folder, contract])
    File.write!(checksum_file(contract), checksum(contract))
  end

  defp should_compile_contract?(contract) do
    checksum = checksum(contract)

    case File.read(checksum_file(contract)) do
      {:ok, ^checksum} -> false
      _ -> true
    end
  end

  defp checksum(contract) do
    case File.read(contract) do
      {:ok, content} -> :crypto.hash(:md5, content) |> Base.encode16()
      _ -> nil
    end
  end

  defp checksum_file(contract) do
    "#{@output_folder}/#{Path.basename(contract, ".sol")}.md5"
  end
end
