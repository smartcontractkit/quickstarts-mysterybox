// SPDX-License-Identifier: MIT
// A mock for testing code that relies on VRFCoordinatorV2Plus.
pragma solidity 0.8.19;

import {IVRFCoordinatorV2Plus} from "../interfaces/IVRFCoordinatorV2Plus.sol";
import {VRFConsumerBaseV2Plus} from "./VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "../libraries/VRFV2PlusClient.sol";

contract VRFCoordinatorV2PlusMock is IVRFCoordinatorV2Plus {
  uint96 public immutable BASE_FEE;
  uint96 public immutable GAS_PRICE_LINK;
  uint16 public immutable MAX_CONSUMERS = 100;

  error InvalidSubscription();
  error InsufficientBalance();
  error MustBeSubOwner(address owner);
  error TooManyConsumers();
  error InvalidConsumer();
  error InvalidRandomWords();

  event RandomWordsRequested(
    bytes32 indexed keyHash,
    uint256 requestId,
    uint256 preSeed,
    uint256 indexed subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords,
    bytes extraArgs,
    address indexed sender
  );
  event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint96 payment, bool success);
  event SubscriptionCreated(uint256 indexed subId, address owner);
  event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
  event SubscriptionCanceled(uint256 indexed subId, address to, uint256 amount);
  event ConsumerAdded(uint256 indexed subId, address consumer);
  event ConsumerRemoved(uint256 indexed subId, address consumer);
  event AddedRandomWord(uint256 randomWord);

  uint256 s_currentSubId;
  uint256 requestIdCounter = 0;
  uint256 s_nextRequestId = 1;
  uint256 s_nextPreSeed = 100;

  struct Subscription {
    address owner;
    uint96 balance;
    uint96 nativeBalance;
    uint64 reqCount;
    address[] consumers;
  }

  mapping(uint256 => Subscription) s_subscriptions; /* subId */ /* subscription */
  uint256 public nextSubscriptionId = 1;
  mapping(uint256 => address[]) s_consumers; /* subId */ /* consumers */

  mapping(uint256 => VRFV2PlusClient.RandomWordsRequest) s_requests; /* requestId */ /* request */

  constructor(uint96 _baseFee, uint96 _gasPriceLink) {
    BASE_FEE = _baseFee;
    GAS_PRICE_LINK = _gasPriceLink;
  }

  function consumerIsAdded(uint256 _subId, address _consumer) public view returns (bool) {
    address[] memory consumers = s_consumers[_subId];
    for (uint256 i = 0; i < consumers.length; i++) {
      if (consumers[i] == _consumer) {
        return true;
      }
    }
    return false;
  }

  modifier onlyValidConsumer(uint256 _subId, address _consumer) {
    if (!consumerIsAdded(_subId, _consumer)) {
      revert InvalidConsumer();
    }
    _;
  }

  /**
   * @notice fulfillRandomWords fulfills the given request, sending the random words to the supplied
   * @notice consumer.
   *
   * @dev This mock uses a simplified formula for calculating payment amount and gas usage, and does
   * @dev not account for all edge cases handled in the real VRF coordinator. When making requests
   * @dev against the real coordinator a small amount of additional LINK is required.
   *
   * @param _requestId the request to fulfill
   * @param _consumer the VRF randomness consumer to send the result to
   */
  function fulfillRandomWords(uint256 _requestId, address _consumer) external {
    fulfillRandomWordsWithOverride(_requestId, _consumer, new uint256[](0));
  }

  /**
   * @notice fulfillRandomWordsWithOverride allows the user to pass in their own random words.
   *
   * @param _requestId the request to fulfill
   * @param _consumer the VRF randomness consumer to send the result to
   * @param _words user-provided random words
   */
  function fulfillRandomWordsWithOverride(uint256 _requestId, address _consumer, uint256[] memory _words) public {
    uint256 startGas = gasleft();
    if (s_requests[_requestId].subId == 0) {
      revert("nonexistent request");
    }
    VRFV2PlusClient.RandomWordsRequest memory req = s_requests[_requestId];

    if (_words.length == 0) {
      _words = new uint256[](req.numWords);
      for (uint256 i = 0; i < req.numWords; i++) {
        _words[i] = uint256(keccak256(abi.encode(_requestId, i)));
        emit AddedRandomWord(_words[i]);
      }
    } else if (_words.length != req.numWords) {
      revert InvalidRandomWords();
    }

    VRFConsumerBaseV2Plus v;
    bytes memory callReq = abi.encodeWithSelector(v.rawFulfillRandomWords.selector, _requestId, _words);
    (bool success, ) = _consumer.call{gas: req.callbackGasLimit}(callReq);

    uint96 payment = uint96(BASE_FEE + ((startGas - gasleft()) * GAS_PRICE_LINK));
    if (s_subscriptions[req.subId].balance < payment) {
      revert InsufficientBalance();
    }
    s_subscriptions[req.subId].balance -= payment;
    delete (s_requests[_requestId]);
    emit RandomWordsFulfilled(_requestId, _requestId, payment, success);
  }

  function fundSubscription(uint256 _subId, uint96 _amount) public {
    if (s_subscriptions[_subId].owner == address(0)) {
      revert InvalidSubscription();
    }
    uint96 oldBalance = s_subscriptions[_subId].balance;
    s_subscriptions[_subId].balance += _amount;
    emit SubscriptionFunded(_subId, oldBalance, oldBalance + _amount);
  }

  function requestRandomWords(
    VRFV2PlusClient.RandomWordsRequest calldata req
  ) external override returns (uint256 requestId) {
    requestId = ++requestIdCounter; // Ensure unique request IDs
    // Store the complete request, respecting the provided structure
    s_requests[requestId] = VRFV2PlusClient.RandomWordsRequest({
      subId: req.subId,
      callbackGasLimit: req.callbackGasLimit,
      numWords: req.numWords,
      keyHash: req.keyHash,
      requestConfirmations: req.requestConfirmations,
      extraArgs: req.extraArgs
    });

    // Emit an event to mimic the actual request handling
    emit RandomWordsRequested(
      req.keyHash,
      requestId,
      uint256(keccak256(abi.encode(req.subId, requestId))), // Simulated preSeed
      req.subId,
      req.requestConfirmations,
      req.callbackGasLimit,
      req.numWords,
      req.extraArgs,
      msg.sender // Include sender in the event
    );

    return requestId; // Return the newly created request ID
  }

  function createSubscription() external override returns (uint256 subId) {
    subId = nextSubscriptionId++;
    Subscription storage newSub = s_subscriptions[subId];
    newSub.owner = msg.sender;
    emit SubscriptionCreated(uint256(subId), msg.sender);
  }

  function getSubscription(
    uint256 subId
  )
    external
    view
    override
    returns (uint96 balance, uint96 nativeBalance, uint64 reqCount, address owner, address[] memory consumers)
  {
    Subscription storage sub = s_subscriptions[subId];
    require(sub.owner != address(0), "Non-existent subscription");
    return (sub.balance, sub.nativeBalance, sub.reqCount, sub.owner, sub.consumers);
  }

  function fundSubscriptionWithNative(uint256 subId) external payable override {
    Subscription storage sub = s_subscriptions[subId];
    sub.nativeBalance += uint96(msg.value);
    emit SubscriptionFunded(uint256(subId), sub.balance, sub.balance);
  }

  function cancelSubscription(uint256 subId, address to) external override {
    require(msg.sender == s_subscriptions[subId].owner, "Not owner");
    Subscription storage sub = s_subscriptions[subId];
    delete s_subscriptions[subId];
    emit SubscriptionCanceled(uint256(subId), to, sub.balance);
  }

  modifier onlySubOwner(uint256 _subId) {
    address owner = s_subscriptions[_subId].owner;
    if (owner == address(0)) {
      revert InvalidSubscription();
    }
    if (msg.sender != owner) {
      revert MustBeSubOwner(owner);
    }
    _;
  }

  function addConsumer(uint256 subId, address consumer) external override {
    require(msg.sender == s_subscriptions[subId].owner, "Not owner");
    Subscription storage sub = s_subscriptions[subId];
    require(sub.consumers.length < MAX_CONSUMERS, "Max consumers reached");
    for (uint256 i = 0; i < sub.consumers.length; ++i) {
      require(sub.consumers[i] != consumer, "Consumer already added");
    }
    sub.consumers.push(consumer);
    emit ConsumerAdded(uint64(subId), consumer);
  }

  function removeConsumer(uint256 subId, address consumer) external override {
    require(msg.sender == s_subscriptions[subId].owner, "Not owner");
    Subscription storage sub = s_subscriptions[subId];
    uint256 length = sub.consumers.length;
    for (uint256 i = 0; i < length; ++i) {
      if (sub.consumers[i] == consumer) {
        sub.consumers[i] = sub.consumers[length - 1];
        sub.consumers.pop();
        emit ConsumerRemoved(uint256(subId), consumer);
        return;
      }
    }
    revert("Consumer not found");
  }

  function getConfig()
    external
    pure
    returns (
      uint16 minimumRequestConfirmations,
      uint32 maxGasLimit,
      uint32 stalenessSeconds,
      uint32 gasAfterPaymentCalculation
    )
  {
    return (4, 2_500_000, 2_700, 33285);
  }

  function getFeeConfig()
    external
    pure
    returns (
      uint32 fulfillmentFlatFeeLinkPPMTier1,
      uint32 fulfillmentFlatFeeLinkPPMTier2,
      uint32 fulfillmentFlatFeeLinkPPMTier3,
      uint32 fulfillmentFlatFeeLinkPPMTier4,
      uint32 fulfillmentFlatFeeLinkPPMTier5,
      uint24 reqsForTier2,
      uint24 reqsForTier3,
      uint24 reqsForTier4,
      uint24 reqsForTier5
    )
  {
    return (
      100000, // 0.1 LINK
      100000, // 0.1 LINK
      100000, // 0.1 LINK
      100000, // 0.1 LINK
      100000, // 0.1 LINK
      0,
      0,
      0,
      0
    );
  }

  function getFallbackWeiPerUnitLink() external pure returns (int256) {
    return 4000000000000000; // 0.004 Ether
  }

  function requestSubscriptionOwnerTransfer(uint256 _subId, address _newOwner) external pure override {
    revert("not implemented");
  }

  function acceptSubscriptionOwnerTransfer(uint256 _subId) external override {
    revert("not implemented");
  }

  function pendingRequestExists(uint256 subId) external view override returns (bool) {
    revert("not implemented");
  }

  function getActiveSubscriptionIds(
    uint256 startIndex,
    uint256 maxCount
  ) external view override returns (uint256[] memory) {
    revert("not implemented");
  }

  function _argsToBytes(VRFV2PlusClient.ExtraArgsV1 memory extraArgs) internal pure returns (bytes memory bts) {
    return abi.encodeWithSelector(VRFV2PlusClient.EXTRA_ARGS_V1_TAG, extraArgs);
  }
}
