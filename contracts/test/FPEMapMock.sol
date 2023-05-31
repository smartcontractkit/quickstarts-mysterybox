//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "fpe-map/contracts/FPEMap.sol";

contract FPEMapMock {
  using FPEMap for uint256;

  function fpeMappingFeistelAuto(uint256 input, uint256 key, uint256 domain) public pure returns (uint256) {
    return input.fpeMappingFeistelAuto(key, domain);
  }
}
