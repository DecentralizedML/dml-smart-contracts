defmodule PaymentHubTest do
  use ExUnit.Case
  alias ExW3.Contract

  setup do
    accounts = ExW3.accounts()
    owner = Enum.at(accounts, 0)

    %{:BasicToken => token_address} = BasicToken.deploy(owner)
    %{:PaymentHub => hub_address} = PaymentHub.deploy(owner, token_address)

    %{accounts: accounts, owner: owner, hub_address: hub_address}
  end

  test "can connect to network", %{owner: owner, hub_address: hub_address} do
    assert BasicToken.balance(owner) == 1_000_000_000_000_000_000_000_000
    assert BasicToken.balance(hub_address) == 0
  end

  test "can deploy contract", %{owner: owner} do
    {:ok, contract_owner} = Contract.call(:PaymentHub, :owner)
    assert owner == ExW3.to_address(contract_owner)

    {:ok, fee} = Contract.call(:PaymentHub, :ownerFee)
    assert fee == 0
  end

  describe "withdraw" do
    setup %{owner: owner, hub_address: hub_address} do
      BasicToken.transfer(owner, hub_address, 10)
      :ok
    end

    test "transfer 1 DML when signature is valid", %{owner: owner, accounts: accounts, hub_address: hub_address} do
      account = Enum.at(accounts, 1)

      assert BasicToken.balance(hub_address) == 10
      assert BasicToken.balance(account) == 0
      assert {:ok, _} = PaymentHub.sign_and_withdraw(owner, account, 1, 1)
      assert BasicToken.balance(hub_address) == 9
      assert BasicToken.balance(account) == 1
    end

    test "transfer 5 DML (-fee) when signature is valid", %{owner: owner, accounts: accounts, hub_address: hub_address} do
      account = Enum.at(accounts, 1)

      # Set fee to 20% & transfer 5 tokens to account
      assert {:ok, _} = PaymentHub.setFee(owner, 20)
      assert {:ok, _} = PaymentHub.sign_and_withdraw(owner, account, 5, 1)
      assert BasicToken.balance(hub_address) == 6
      assert BasicToken.balance(account) == 4
    end

    test "prevent transfer when signature is invalid", %{accounts: accounts, hub_address: hub_address} do
      account = Enum.at(accounts, 1)

      # Try to transfer to account
      response = PaymentHub.signed_withdraw(account, 1, 1, String.duplicate("a", 65))
      error = "VM Exception while processing transaction: revert Invalid signature"
      assert {:error, %{"message" => ^error}} = response
      assert BasicToken.balance(hub_address) == 10
      assert BasicToken.balance(account) == 0
    end

    test "prevent transfer when signature created by non-owner", %{accounts: accounts, hub_address: hub_address} do
      account = Enum.at(accounts, 1)

      # Try to transfer to account
      response = PaymentHub.sign_and_withdraw(Enum.at(accounts, 2), account, 1, 1)
      error = "VM Exception while processing transaction: revert Invalid signature"
      assert {:error, %{"message" => ^error}} = response
      assert BasicToken.balance(hub_address) == 10
      assert BasicToken.balance(account) == 0
    end

    test "prevent transfer when address is blacklisted", %{owner: owner, accounts: accounts, hub_address: hub_address} do
      account = Enum.at(accounts, 1)

      # Blacklist account
      assert {:ok, _} = PaymentHub.blacklistAddress(owner, account)

      # Try to transfer to account
      response = PaymentHub.sign_and_withdraw(owner, account, 1, 1)
      error = "VM Exception while processing transaction: revert This recipient has been blacklisted"
      assert {:error, %{"message" => ^error}} = response
      assert BasicToken.balance(hub_address) == 10
      assert BasicToken.balance(account) == 0
    end

    test "prevent transfer when nonce was already used", %{owner: owner, accounts: accounts, hub_address: hub_address} do
      account = Enum.at(accounts, 1)

      # Transfer to account, creating nonce
      assert {:ok, _} = PaymentHub.sign_and_withdraw(owner, account, 1, 2)

      # Try to transfer to account again, with same nonce
      response = PaymentHub.sign_and_withdraw(owner, account, 1, 2)
      error = "VM Exception while processing transaction: revert This transfer message was already used"
      assert {:error, %{"message" => ^error}} = response

      # Try to transfer to account again, with smaller nonce
      response = PaymentHub.sign_and_withdraw(owner, account, 1, 1)
      error = "VM Exception while processing transaction: revert"
      assert {:error, %{"message" => ^error}} = response

      assert BasicToken.balance(hub_address) == 9
      assert BasicToken.balance(account) == 1
    end
  end

  describe "setFee" do
    test "owner can set fee", %{owner: owner} do
      assert {:ok, _} = PaymentHub.setFee(owner, 1)

      {:ok, fee} = Contract.call(:PaymentHub, :ownerFee)
      assert fee == 1
    end

    test "non-owner cannot set fee", %{accounts: accounts} do
      error = "VM Exception while processing transaction: revert Only owner can access this method"
      assert {:error, %{"message" => ^error}} = PaymentHub.setFee(Enum.at(accounts, 1), 1)
    end
  end

  describe "blacklistAddress" do
    test "owner can blacklist address", %{accounts: accounts, owner: owner} do
      account = Enum.at(accounts, 9)
      assert {:ok, _} = PaymentHub.blacklistAddress(owner, account)

      argument = ExW3.to_decimal(account)
      {:ok, blacklisted_at} = Contract.call(:PaymentHub, :blacklist, [argument])
      assert blacklisted_at > 0
    end

    test "non-owner cannot blacklist address", %{accounts: accounts} do
      error = "VM Exception while processing transaction: revert Only owner can access this method"
      assert {:error, %{"message" => ^error}} = PaymentHub.setFee(Enum.at(accounts, 1), 1)
    end
  end
end
