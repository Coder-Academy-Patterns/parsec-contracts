
/**
 * Copyright (c) 2017-present, Parsec Labs (parseclabs.org)
 *
 * This source code is licensed under the Mozilla Public License, version 2,
 * found in the LICENSE file in the root directory of this source tree.
 */
 
pragma solidity ^0.4.22;

library TxLib {
//   DEPOSIT: 2,
//   TRANSFER: 3,
//   CONSOLIDATE: 4,
//   COMP_REQ: 5,
//   COMP_RESP: 6,
  enum TxType { Deposit, Transfer, Consolidate, CompReq, CompRsp }

  struct Outpoint {
    bytes32 hash;
    uint8 pos;
  }

  struct Input {
    Outpoint outpoint;
    bytes32 r;
    bytes32 s;
    uint8 v;
  }

  struct Output {
    uint64 value;
    uint16 color;
    address owner;
    uint32 gasPrice;
    bytes msgData;
    bytes32 stateRoot;
  }
    
  struct Tx {
    TxType txType;
    Input[] ins;
    Output[] outs;
  }
  
  function parseInput(TxType _type, bytes _txData, uint256 _pos, uint256 offset, Input[] _ins) internal pure returns (uint256 newOffset) {
    bytes32 hash;
    uint8 index;
    if (_type == TxType.Deposit) {
      assembly {
        hash := mload(add(add(offset, 4), _txData))
      }
      hash = bytes32(uint32(hash));
      index = 0;
      newOffset = offset + 4;
    } else {    
      assembly {
          hash := mload(add(add(offset, 32), _txData))
          index := mload(add(add(offset, 33), _txData))
      }
      newOffset = offset + 33;
    }
    Outpoint memory outpoint = Outpoint(hash, index);
    Input memory input = Input(outpoint, 0, 0, 0);
    if (_type == TxType.Transfer ||
      ((_type == TxType.CompReq || _type == TxType.CompRsp ) && _pos > 0)) {
      bytes32 r;
      bytes32 s;
      uint8 v;
      assembly {
        r := mload(add(add(offset, 65), _txData))
        s := mload(add(add(offset, 97), _txData))
        v := mload(add(add(offset, 98), _txData))
      }
      input.r = r;
      input.s = s;
      input.v = v;
      newOffset = offset + 33 + 65;
    }
    _ins[_pos] = input;
  }
  
  function parseOutput(TxType _type, bytes _txData, uint256 _pos, uint256 offset, Output[] _outs) internal pure returns (uint256 newOffset) {
    uint64 value;
    uint16 color;
    address owner;
    assembly {
        value := mload(add(add(offset, 8), _txData))
        color := mload(add(add(offset, 10), _txData))
        owner := mload(add(add(offset, 30), _txData))
    }
    bytes memory data = new bytes(0);
    Output memory output = Output(value, color, owner, 0, data, 0);
    _outs[_pos] = output;
    newOffset = offset + 30;
    if (_type == TxType.CompReq && _pos == 0) {
        // read gasPrice
        // read length of msgData
        value = 10;
        uint32 gasPrice = 1000;
        // read msgData
        newOffset = offset + 30 + value;
        data = new bytes(10);
        output.msgData = data;
        output.gasPrice = gasPrice;
    } else if (_type == TxType.CompRsp && _pos == 0) {
        // read new stateRoot
        bytes32 stateRoot;
        output.stateRoot = stateRoot; 
        newOffset = offset + 33 + 32;
    }
  }
    
  function parseTx(bytes _txData) internal pure returns (Tx memory txn) {
    // read type
    TxType txType;
    uint256 a;
    assembly {
        a := mload(add(0x20, _txData))
    }
    a = a >> 248; // get first byte
    if (a == 2 ) {
        txType = TxType.Deposit;
    } else if (a == 3 ) {
        txType = TxType.Transfer;
    } else if (a == 4 ) {
        txType = TxType.Consolidate;
    } else if (a == 5 ) {
        txType = TxType.CompReq;
    } else if (a == 6 ) {
        txType = TxType.CompRsp;
    } else {
        revert("unknow tx type");
    }
    // read ins and outs
    assembly {
        a := mload(add(0x21, _txData))
    }
    a = a >> 252; // get ins nibble
    Input[] memory ins = new Input[](a);
    uint256 offset = 2;
    for (uint i = 0; i < ins.length; i++) {
        offset = parseInput(txType, _txData, i, offset, ins);
    }
    assembly {
        a := mload(add(0x21, _txData))
    }
    a = (a >> 248) & 0x0f; // get ins nibble
    Output[] memory outs = new Output[](a);
    if (txType == TxType.Consolidate && ins.length <= outs.length) {
      revert("invalide consolidate");
    }
    for (i = 0; i < outs.length; i++) {
        offset = parseOutput(txType, _txData, i, offset, outs);
    }
    txn = Tx(txType, ins, outs);
  }
    
}
