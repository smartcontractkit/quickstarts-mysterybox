// SPDX-License-Identifier: MIT
/**
 * ______ _____   _____ ______ ___  __ _  _  _
 *  |  ____|  __ \ / ____|____  |__ \/_ | || || |
 *  | |__  | |__) | |        / /   ) || | \| |/ |
 *  |  __| |  _  /| |       / /   / / | |\_   _/
 *  | |____| | \ \| |____  / /   / /_ | |  | |
 *  |______|_|  \_\\_____|/_/   |____||_|  |_|
 */
pragma solidity 0.8.19;

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import "fpe-map/contracts/FPEMap.sol";

import "erc721psi/contracts/ERC721Psi.sol";

abstract contract ERC721PsiMysteryBox is VRFConsumerBaseV2Plus, ERC721Psi {
  using Strings for uint256;

  error ERC721PsiMysteryBox__AlreadyRevealed();
  error ERC721Psi__ExceedMaximumSupply();

  uint32 private constant _callbackGasLimit = 200000;

  uint256 private seed;

  event RandomnessRequest(uint256 requestId);

  constructor(address vrfCoordinatorV2Plus) VRFConsumerBaseV2Plus(vrfCoordinatorV2Plus) {}

  /**
   * @dev The metadata URI before revealing.
   */
  function _unrevealedURI() internal view virtual returns (string memory) {
    return "";
  }

  /**
   * @dev Returns true after revealing.
   */
  function _revealed() internal view returns (bool) {
    return seed != 0;
  }

  /**
   * @dev See {IERC721Metadata-tokenURI}.
   */
  function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
    require(_exists(tokenId), "ERC721Psi: URI query for nonexistent token");

    if (seed == 0) {
      return _unrevealedURI();
    }

    string memory baseURI = _baseURI();

    uint256 metadataId = FPEMap.fpeMappingFeistelAuto(tokenId, seed, _maxSupply());

    return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, metadataId.toString(), _extension())) : "";
  }

  /**
   * @dev Override the function to provide the maxium supply of the collection. It should be a constant value.
   */
  function _maxSupply() internal view virtual returns (uint256);

  /**
   * @dev Override the function to provide the VRF 2.5 coordinator address.
   */
  function _coordinator() internal virtual returns (address);

  /**
   * @dev Override the function to provide the corresponding keyHash for VRF V2.5.
   */
  function _keyHash() internal virtual returns (bytes32);

  /**
   * @dev Override the function to provide the corresponding subscription ID for Chainlink VRF V2.5.
   *     see also: https://docs.chain.link/vrf/v2-5/subscription/create-manage
   */
  function _subscriptionId() internal virtual returns (uint256);

  /**
   * @dev Required block confirmations before the VRF callback.
   */
  function _requestConfirmations() internal virtual returns (uint16) {
    return 10;
  }

  /**
   * @dev Override the function to provide the file extension appended to the baseURI after revealing.
   */
  function _extension() internal view virtual returns (string memory) {
    return ".json";
  }

  /**
   * Callback function used by the VRF Coordinator
   */
  function fulfillRandomWords(uint256, uint256[] calldata randomWords) internal override {
    if (seed != 0) revert ERC721PsiMysteryBox__AlreadyRevealed();
    seed = randomWords[0];
  }

  function _beforeTokenTransfers(
    address from,
    address to,
    uint256 startTokenId,
    uint256 quantity
  ) internal virtual override {
    if (from == address(0)) {
      if (startTokenId + quantity > _maxSupply()) revert ERC721Psi__ExceedMaximumSupply();
    }
    super._beforeTokenTransfers(from, to, startTokenId, quantity);
  }

  /**
   * @dev Call this function when you want to reveal the mystery box.
   */
  function _reveal() internal virtual {
    if (seed != 0) revert ERC721PsiMysteryBox__AlreadyRevealed();

    uint256 requestId = s_vrfCoordinator.requestRandomWords(
      VRFV2PlusClient.RandomWordsRequest({
        keyHash: _keyHash(),
        subId: _subscriptionId(),
        requestConfirmations: _requestConfirmations(),
        callbackGasLimit: _callbackGasLimit,
        numWords: 1,
        extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
      })
    );

    emit RandomnessRequest(requestId);
  }
}
