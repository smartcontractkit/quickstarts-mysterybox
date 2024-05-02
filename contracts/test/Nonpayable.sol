// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface MysteryBoxLike {
  function withdraw() external;
  function acceptOwnership() external;
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

  function acceptOwnership() external {
    vrfNft.acceptOwnership();
  }

  fallback() external payable {
    revert DontAcceptFunds();
  }
}
