// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
import { chainlink, ethers, network, run } from 'hardhat'
import { BigNumber } from 'ethers'
import { MerkleTree } from 'merkletreejs'
import keccak256 from 'keccak256'
import { networkConfig } from '../network-config'
import whitelist from './data/whitelist.json'

const name = process.env.NFT_NAME
const symbol = process.env.NFT_SYMBOL
const unrevealedUri = process.env.NFT_UNREVEALED_URI
const maxSupply = process.env.NFT_MAX_SUPPLY
const maxMintPerUser = process.env.NFT_MAX_MINT_PER_USER
const fee = process.env.NFT_FEE
const royaltyBps = process.env.NFT_ROYALTY_BPS

const existingSubscriptionId = process.env.VRF_SUBSCRIPTION_ID

async function main() {
  // Hardhat always runs the compile task when running scripts with its command
  // line interface.
  //
  // If this script is run directly using `node` you may want to call compile
  // manually to make sure everything is compiled
  // await hre.run('compile');
  if (
    !name ||
    !symbol ||
    !unrevealedUri ||
    !maxSupply ||
    !maxMintPerUser ||
    !fee ||
    !royaltyBps
  ) {
    throw new Error('Missing required env variable(s)!')
  }

  const { chainId } = network.config

  if (!chainId) {
    throw new Error('Missing network configuration!')
  }

  const { vrfCoordinatorV2, keyHash, linkToken, fundAmount } =
    networkConfig[chainId]

  // Create and fund a VRF subscription if existing one is not configured
  let subscriptionId: BigNumber
  if (existingSubscriptionId) {
    subscriptionId = BigNumber.from(existingSubscriptionId)
  } else {
    const createSubscriptionResponse = await chainlink.createVrfSubscription(
      vrfCoordinatorV2,
    )
    subscriptionId = createSubscriptionResponse.subscriptionId
    console.log('Created VRF subscription with ID', subscriptionId.toString())

    // Fund the newly created subscription
    const fundAmountInJuels = BigNumber.from(fundAmount)
    await chainlink.fundVrfSubscription(
      vrfCoordinatorV2,
      linkToken,
      fundAmountInJuels,
      subscriptionId,
    )
    console.log(
      `Subscription funded with ${ethers.utils.formatEther(fundAmount)} LINK`,
    )
  }

  // Generate whitelist root
  const merkleTree = new MerkleTree(whitelist, keccak256, {
    sortPairs: true,
    hashLeaves: true,
  })
  const whitelistRoot = merkleTree.getHexRoot()
  console.log('Generated whitelist root', whitelistRoot)

  // Deploy contract
  const feeInWei = ethers.utils.parseEther(fee)
  const mysteryBoxFactory = await ethers.getContractFactory('MysteryBox')
  const constructorArguments = [
    name,
    symbol,
    unrevealedUri,
    maxSupply,
    maxMintPerUser,
    feeInWei,
    whitelistRoot,
    royaltyBps,
    vrfCoordinatorV2,
    keyHash,
    subscriptionId,
  ]
  const mysteryBox = await mysteryBoxFactory.deploy(...constructorArguments)
  await mysteryBox.deployed()
  console.log('MysteryBox deployed to', mysteryBox.address, network.name)

  // Add consumer to subscription
  // Note: The owner of the subscription must be the same as the deployer.
  // If you are using a different account, you will need comment out the following call.
  await chainlink.addVrfConsumer(
    vrfCoordinatorV2,
    mysteryBox.address,
    subscriptionId,
  )
  console.log(
    'MysteryBox added as consumer to subscription with ID',
    subscriptionId.toString(),
  )

  // Verify contract
  console.log('Verifying MysteryBox contract on Etherscan...')
  await mysteryBox.deployTransaction.wait(10)
  await run('verify:verify', {
    address: mysteryBox.address,
    contract: 'contracts/MysteryBox.sol:MysteryBox',
    constructorArguments,
  })
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
