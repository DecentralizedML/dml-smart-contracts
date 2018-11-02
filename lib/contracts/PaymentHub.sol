pragma solidity ^0.4.25;

import './ECDSA.sol';

contract PaymentHub {
  address public owner;
  mapping(address => mapping(uint => uint)) transfers;
  mapping(address => uint) public blacklist;
  mapping(address => uint) lastNonce;
  uint public ownerFee = 0;
  ERC20Interface token;

  using ECDSA for bytes32;

  constructor(address _tokenAddress) public {
    owner = msg.sender;
    token = ERC20Interface(_tokenAddress);
  }

  modifier protected {
    require(msg.sender == owner, "Only owner can access this method");
    _;
  }

  function withdraw(address _recipient, uint _amount, uint _nonce, bytes _signature) external {
    // Verify the [_signature]
    // Extract the address that created the [_signature]
    // Compare the address found with the [owner] of the contract
    address signer = retrieveSigner(_recipient, _amount, _nonce, _signature);

    require(signer == owner, "Invalid signature");

    // Check [_recipient] against the [blacklist] list
    require(blacklist[_recipient] == 0, "This recipient has been blacklisted");

    // Check [_nonce] against the [transfers] list
    require(transfers[_recipient][_nonce] == 0, "This transfer message was already used");

    // Check [_nonce] against previous nonces of the [_recipient]?
    require(_nonce > lastNonce[_recipient]);

    // Calculate fee
    uint fee = (_amount * ownerFee) / 100;

    // Transfer [_amount] to the [_recipient] and include on [transfers] mapping
    transfers[_recipient][_nonce] = _amount - fee;
    lastNonce[_recipient] = _nonce;
    require(token.transfer(_recipient, _amount - fee));
  }

  function setFee(uint _fee) protected external {
    require(_fee != ownerFee);
    ownerFee = _fee;
  }

  function blacklistAddress(address _recipient) protected external {
    require(blacklist[_recipient] == 0, "This address is already blacklisted");

    // Block address of receiving future transfers
    blacklist[_recipient] = block.timestamp;
  }

  function retrieveSigner(address _recipient, uint _amount, uint _nonce, bytes _signature) pure public returns (address) {
    bytes32 message = keccak256(abi.encodePacked(_recipient, "_", _amount, "_", _nonce));
    bytes32 hashedMessage = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", message));
    address signer = hashedMessage.recover(_signature);

    return signer;
  }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
contract ERC20Interface {
  function totalSupply() public constant returns (uint);
  function balanceOf(address tokenOwner) public constant returns (uint balance);
  function allowance(address tokenOwner, address spender) public constant returns (uint remaining);
  function transfer(address to, uint tokens) public returns (bool success);
  function approve(address spender, uint tokens) public returns (bool success);
  function transferFrom(address from, address to, uint tokens) public returns (bool success);

  event Transfer(address indexed from, address indexed to, uint tokens);
  event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
