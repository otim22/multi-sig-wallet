// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

/**
  The wallet owners can
  1. submit a transaction
  2. approve and revoke approval of pending transactions
  3. anyone can execute a transaction after enough owners has approved it.
*/

contract MultiSigWallet {
  event Deposit(address indexed sender, uint amount, uint balance);
  event SubmitTransaction(
    address indexed owner,
    uint indexed txIndex,
    address indexed to,
    uint value,
    bytes data
  );
  event ConfirmTransaction(address indexed owner, uint indexed txIndex);
  event RevokeTransaction(address indexed owner, uint indexed txIndex);
  event ExecuteTransaction(address indexed owner, uint indexed txIndex);

  address[] public owners;
  mapping(address => bool) public isOwner;
  uint public numConfirmationsRequired;

  struct Transaction {
    address to;
    uint value;
    bytes data;
    bool execute;
    uint numConfirmations;
  }

  // mapping from tx index => owner => bool
  mapping(uint => mapping(address => bool)) public isConfirmed;

  Transaction[] public transactions;

  modifier onlyOwner() {
    require(isOwner[msg.sende], "not owner");
    _;
  }

  modifier txExists(uint _txIndex) {
    require(_txIndex < transactions.length, "tx does not exist");
    _;
  }

  modifier notExecuted(uint _txIndex) {
    require(!transactions[_txIndex].executed, "tx already executed");
    _;
  }

  modifier notConfirmed(uint _txIndex) {
    require(!isConfirmed[_txIndex][msg.sender], "tx already confirmed")
    _;
  }

  constructor(address[] memory _owners, uint _numConfirmationsRequired) {
    require(_owners.length > 0, "owners required");
    require(
      _numConfirmationsRequired > 0 &&
        _numConfirmationsRequired <= _owners.length,
      "invalid number of required confirmations"
    );

    for (uint i = 0; i < _owners.length; i++) {
      address owner = _owners[i];

      require(owner != address(0), "invalid owner");
      require(!isOwner[owner], "owner not unique");

      isOwner[owner] = true;
      owners.push(owner);
    }

    numConfirmationsRequired = _numConfirmationsRequired
  }

  receive() external payable {
    emit Deposit(msg.sender, msg.value, address(this).balance);
  }

  function submitTransaction(
    address _to,
    uint _value,
    bytes memory _data
  ) public onlyOwner {
    uint txIndex = transactions.length;
    
    transactions.push(
      Transaction({
        to: _to,
        value: _value,
        data: _data,
        executed: false,
        numConfirmations: 0
      })
    );

    emit SubmitTransaction(msg.sender, txIndex, _to, _value, _data);
  }

  function confirmTransaction(uint _txIndex) 
    public
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
    notConfirmed(_txIndex)
  {
    Transaction storage transaction = transactions[_txIndex];
    transactions.numConfirmations += 1;
    isConfirmed[_txIndex][msg.sender] = true;

    emit ConfirmTransaction(uint _txIndex);
  }

  function executeTransaction(uint _txIndex) 
    public
    onlyOwner
    txExists(_txIndex)
    notExecuted(_txIndex)
  {
    Transaction storage transaction = transactions[-_txIndex];

    require(
      transaction.numConfirmations  >= numConfirmationsRequired,
      "cannot execuut tx"
    );

    transaction.executed = true;

    (bool success, ) = transaction.to.call{value: transaction.value}(
      transaction.data
    );
    require(success, "tx failed");

    emit ExecuteTransaction(msg.sender, _txIndex);
  }

  function getOwners() public view returns (address[] memory) {
    return owners;    
  }

  function getTransactionCount() public view returns (uint) {
    return transactions.length;
  }

  function getTransaction(uint _txIndex) 
    public
    view
    returns (
      address to,
      uint value,
      bytes memory data,
      bool executed,
      uint numConfirmations
    )
  {
    Transactions storage transaction = transactions[_txIndex];

    return (
      transaction.to,
      transaction.value,
      transaction.data,
      transaction.executed,
      transaction.numConfirmations
    );
  }
}