// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

import {IVRFCoordinatorV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {ERC721Psi, ERC721PsiMysteryBox} from "./ERC721Psi/ERC721PsiMysteryBox.sol";

/// @title MysteryBox
/// @author HackBG Team (https://hack.bg)
/// @author Updated for VRF2.5 by the Chainlink team
/// @notice NFT collection with random token distribution
/// @dev Using Chainlink VRF for randomness
contract MysteryBox is ERC721PsiMysteryBox, ERC2981 {
  /*//////////////////////////////////////////////////////////////
                                 DATA
    //////////////////////////////////////////////////////////////*/

  /// @notice The maximum amount of tokens that can be minted
  uint256 private immutable i_maxSupply;

  /// @notice The maximum amount of tokens that can be minted per address
  uint256 private immutable i_maxMintPerUser;

  /// @notice The keyhash for Chainlink VRF
  bytes32 private immutable i_vrfKeyHash;

  /// @notice The address of Chainlink VRF Coordinator
  address private immutable i_vrfCoordinatorV2Plus;

  /// @notice The subscription ID for Chainlink VRF
  uint256 private immutable i_vrfSubscriptionId;

  /*//////////////////////////////////////////////////////////////
                                 STATE
    //////////////////////////////////////////////////////////////*/

  /// @notice The fee for minting one token
  uint256 private s_fee;

  /// @notice The base URI for tokens after it is revealed
  string private s_baseURI;

  /// @notice The URI for all tokens before reveal
  string private s_unrevealedURI;

  /// @notice The provenance hash of all images in the collection
  string private s_provenanceHash;

  /// @notice Whether the public mint is enabled
  bool private s_publicMint;

  /// @notice The root of the whitelist merkle tree
  bytes32 private s_whitelistRoot;

  /// @notice The amount of tokens minted per address
  mapping(address => uint256) private s_userAmountMinted;

  /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/

  /// @notice The user is not allowed to mint
  error MysteryBox__NotAllowed();

  /// @notice The user is not eligible for private mint
  error MysteryBox__NotEligible();

  /// @notice The amount requested for mint is zero
  error MysteryBox__ZeroAmount();

  /// @notice The value sent is insufficient for the mint
  error MysteryBox__InsufficientValue();

  /// @notice The user has exceeded the limit of tokens per address
  error MysteryBox__LimitPerUserExceeded();

  /// @notice The funds could not be withdrawn
  error MysteryBox__FailedToWithdrawFunds();

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

  /// @notice Deploys a new MysteryBox contract with the specified parameters
  /// @dev Sets the contract owner and royalty receiver to the deployer
  /// @dev For Chainlink VRF parameters, see https://docs.chain.link/vrf/v2-5/overview/subscription
  /// @param name The name of the collection
  /// @param symbol The symbol of the collection
  /// @param unrevealedURI The URI for all tokens before reveal
  /// @param maxSupply The maximum amount of tokens that can be minted
  /// @param maxMintPerUser The maximum amount of tokens that can be minted per address
  /// @param fee The fee for minting one token in wei
  /// @param whitelistRoot The root of the whitelist merkle tree
  /// @param royaltyBps The royalty percentage in basis points
  /// @param vrfCoordinatorV2Plus The address of Chainlink VRF Coordinator V2Plus
  /// @param vrfKeyhash The keyhash for Chainlink VRF
  /// @param vrfSubscriptionId The subscription ID for Chainlink VRF
  constructor(
    string memory name,
    string memory symbol,
    string memory unrevealedURI,
    uint256 maxSupply,
    uint256 maxMintPerUser,
    uint256 fee,
    bytes32 whitelistRoot,
    uint96 royaltyBps,
    address vrfCoordinatorV2Plus,
    bytes32 vrfKeyhash,
    uint256 vrfSubscriptionId
  ) ERC721PsiMysteryBox(vrfCoordinatorV2Plus) ERC721Psi(name, symbol) {
    i_maxSupply = maxSupply;
    i_maxMintPerUser = maxMintPerUser;
    i_vrfKeyHash = vrfKeyhash;
    i_vrfCoordinatorV2Plus = vrfCoordinatorV2Plus;
    i_vrfSubscriptionId = vrfSubscriptionId;
    s_fee = fee;
    s_whitelistRoot = whitelistRoot;
    s_unrevealedURI = unrevealedURI;

    _setDefaultRoyalty(msg.sender, royaltyBps);
  }

  /*//////////////////////////////////////////////////////////////
                           MINT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @notice Mint a specified amount of tokens during the public mint
  /// @param amount The amount of tokens to mint
  function publicMint(uint256 amount) external payable {
    if (!s_publicMint) revert MysteryBox__NotAllowed();

    _mintAmount(amount);
  }

  /// @notice Mint a specified amount of tokens during the private mint
  /// @dev The user must be in the whitelist merkle tree
  /// @dev To generate the merkle proof, see https://github.com/merkletreejs/merkletreejs
  /// @param amount The amount of tokens to mint
  /// @param proof The merkle proof for the user's address
  function privateMint(uint256 amount, bytes32[] calldata proof) external payable {
    bytes32 leaf = keccak256(abi.encodePacked(msg.sender));

    if (!MerkleProof.verify(proof, s_whitelistRoot, leaf)) revert MysteryBox__NotEligible();

    _mintAmount(amount);
  }

  /*//////////////////////////////////////////////////////////////
                              INTERNAL
    //////////////////////////////////////////////////////////////*/

  /// @dev A function used internally to mint a specified amount of tokens
  /// @param amount The amount of tokens to mint
  function _mintAmount(uint256 amount) internal {
    if (_revealed()) revert MysteryBox__NotAllowed();

    if (amount == 0) revert MysteryBox__ZeroAmount();

    if (msg.value < s_fee * amount) revert MysteryBox__InsufficientValue();

    if (s_userAmountMinted[msg.sender] + amount > i_maxMintPerUser) revert MysteryBox__LimitPerUserExceeded();

    s_userAmountMinted[msg.sender] += amount;

    _safeMint(msg.sender, amount);
  }

  /*//////////////////////////////////////////////////////////////
                           PUBLIC GETTERS
    //////////////////////////////////////////////////////////////*/

  /// @notice Get the fee for minting one token
  /// @return The fee for minting one token in wei
  function getFee() external view returns (uint256) {
    return s_fee;
  }

  /// @notice Get the whitelist merkle tree root
  /// @return The hash of the whitelist merkle tree root
  function getWhitelistRoot() external view returns (bytes32) {
    return s_whitelistRoot;
  }

  /// @notice Get the provenance hash of all images in the collection
  /// @return THe provenance hash of all images in the collection
  function getProvenanceHash() external view returns (string memory) {
    return s_provenanceHash;
  }

  /// @notice Get the URI for the revealed collection
  /// @return The base URI of the collection
  function getBaseURI() external view returns (string memory) {
    return s_baseURI;
  }

  /*//////////////////////////////////////////////////////////////
                          OWNER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

  /// @notice Reveal the collection
  /// @dev This action is irreversible
  /// @dev The VRF subscription must be funded with LINK
  /// @dev After reveal the tokenURI will use the baseURI
  function reveal() external onlyOwner {
    _reveal();
  }

  /// @notice Set the revealed base URI for all tokens
  /// @dev Must end with a slash
  /// @dev Should be set right before calling reveal
  /// @param newBaseURI The base URI for all tokens
  function setBaseURI(string memory newBaseURI) external onlyOwner {
    s_baseURI = newBaseURI;
  }

  /// @notice Enable or disable public mint
  /// @param publicMintEnabled True to enable public mint, false to disable
  function setPublicMint(bool publicMintEnabled) external onlyOwner {
    s_publicMint = publicMintEnabled;
  }

  /// @notice Set the whitelist merkle tree root
  /// @dev To generate the merkle tree, see https://github.com/merkletreejs/merkletreejs
  /// @param whiteListRoot The hash of the whitelist merkle tree root
  function setWhitelistRoot(bytes32 whiteListRoot) external onlyOwner {
    s_whitelistRoot = whiteListRoot;
  }

  /// @notice Set the provenance hash of all images in the collection
  /// @dev The provenance hash should be computed off-chain by SHA256 hashing every
  /// image, concatenating the hashes and then SHA256 hashing the combined string too.
  /// @param provenanceHash A hash string of all images in the collection
  function setProvenanceHash(string memory provenanceHash) external onlyOwner {
    s_provenanceHash = provenanceHash;
  }

  /// @notice Set the fee for minting one token
  /// @param fee The fee amount for minting one token in wei
  function setMintFee(uint256 fee) external onlyOwner {
    s_fee = fee;
  }

  /// @notice Set the royalty parameters
  /// @param receiver The address that will receive the royalties
  /// @param feeBps The royalty fee on sale in basis points
  function setRoyalty(address receiver, uint96 feeBps) external onlyOwner {
    _setDefaultRoyalty(receiver, feeBps);
  }

  /// @notice Transfer the contract balance to the owner
  function withdraw() external onlyOwner {
    // solhint-disable-next-line avoid-low-level-calls
    (bool sent, ) = payable(owner()).call{value: address(this).balance}("");

    if (!sent) revert MysteryBox__FailedToWithdrawFunds();
  }

  /*//////////////////////////////////////////////////////////////
                     ERC721PsiMysteryBox LOGIC
    //////////////////////////////////////////////////////////////*/

  /// @inheritdoc ERC721Psi
  function _baseURI() internal view override returns (string memory) {
    return s_baseURI;
  }

  /// @inheritdoc ERC721PsiMysteryBox
  function _unrevealedURI() internal view override returns (string memory) {
    return s_unrevealedURI;
  }

  /// @inheritdoc ERC721PsiMysteryBox
  function _maxSupply() internal view override returns (uint256) {
    return i_maxSupply;
  }

  /// @inheritdoc ERC721PsiMysteryBox
  function _coordinator() internal view override returns (address) {
    return i_vrfCoordinatorV2Plus;
  }

  /// @inheritdoc ERC721PsiMysteryBox
  function _keyHash() internal view override returns (bytes32) {
    return i_vrfKeyHash;
  }

  /// @inheritdoc ERC721PsiMysteryBox
  function _subscriptionId() internal view override returns (uint256) {
    return i_vrfSubscriptionId;
  }

  /*//////////////////////////////////////////////////////////////
                           ERC 165 LOGIC
    //////////////////////////////////////////////////////////////*/

  function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Psi, ERC2981) returns (bool) {
    return super.supportsInterface(interfaceId);
  }
}
