// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;

interface MysteryBoxLike {
  function withdraw() external;
}

contract Nonpayable {
  error DontAcceptFunds();

  MysteryBoxLike public vrfNft;

  constructor(address nft) {
    vrfNft = MysteryBoxLike(nft);
  }

  function withdraw() external {
    vrfNft.withdraw();
  }

  fallback() external payable {
    revert DontAcceptFunds();
  }
}
