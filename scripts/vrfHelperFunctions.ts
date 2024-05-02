import { ethers } from 'hardhat'
import { BigNumber } from 'ethers'
import VRFCoordinatorV2Plus from '../artifacts/contracts/interfaces/IVRFCoordinatorV2Plus.sol/IVRFCoordinatorV2Plus.json'
import LinkToken from '../artifacts/contracts/interfaces/LinkTokenInterface.sol/LinkTokenInterface.json'

export async function createVRFSubscription(
  vrfCoordinatorAddress: string,
): Promise<BigNumber> {
  console.log('Creating a new VRF 2.5 subscription...')
  const [deployer] = await ethers.getSigners()
  const vrfCoordinator = new ethers.Contract(
    vrfCoordinatorAddress,
    VRFCoordinatorV2Plus.abi,
    deployer,
  )

  const transactionResponse = await vrfCoordinator.createSubscription()
  const receipt = await transactionResponse.wait()
  console.log(
    `Subscription created with transaction hash: ${receipt.transactionHash}`,
  )

  const subscriptionCreatedEvent = receipt.events?.find(
    (event: { topics: string[]; data: string }) =>
      event.topics[0] ===
      '0x1d3015d7ba850fa198dc7b1a3f5d42779313a681035f77c8c03764c61005518d',
  )

  if (!subscriptionCreatedEvent || !subscriptionCreatedEvent.topics[1]) {
    throw new Error('Subscription ID not found in transaction receipt')
  }

  const subId = BigNumber.from(subscriptionCreatedEvent.topics[1])

  return subId
}

export async function fundSubscription(
  vrfCoordinatorAddress: string,
  linkTokenAddress: string,
  amount: string,
  subscriptionId: string,
) {
  const [signer] = await ethers.getSigners()
  const linkToken = new ethers.Contract(linkTokenAddress, LinkToken.abi, signer)
  const txResponse = await linkToken.transferAndCall(
    vrfCoordinatorAddress,
    amount,
    ethers.utils.defaultAbiCoder.encode(['uint256'], [subscriptionId]),
  )
  await txResponse.wait()
  console.log(
    `Subscription ${subscriptionId} funded with ${ethers.utils.formatEther(
      amount,
    )} LINK`,
  )
}

export async function addConsumerToSubscription(
  vrfCoordinatorAddress: string,
  subscriptionId: string,
  consumerAddress: string,
) {
  const [deployer] = await ethers.getSigners()
  const vrfCoordinator = new ethers.Contract(
    vrfCoordinatorAddress,
    VRFCoordinatorV2Plus.abi,
    deployer,
  )

  const txResponse = await vrfCoordinator.addConsumer(
    subscriptionId,
    consumerAddress,
  )
  await txResponse.wait()
  console.log(
    `Consumer ${consumerAddress} added to subscription ${subscriptionId}`,
  )
}
