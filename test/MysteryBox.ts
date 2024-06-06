import { expect } from 'chai'
import { ethers } from 'hardhat'
import { BigNumber } from 'ethers'
import { MerkleTree } from 'merkletreejs'
import keccak256 from 'keccak256'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import {
  MysteryBox,
  FPEMapMock,
  VRFCoordinatorV2PlusMock,
  MysteryBox__factory as MysteryBoxFactory,
  FPEMapMock__factory as FPEMapMockFactory,
  Nonpayable__factory as NonpayableFactory,
  VRFCoordinatorV2PlusMock__factory as VRFCoordinatorV2PlusMockFactory,
} from '../typechain-types'

const { AddressZero, HashZero } = ethers.constants
const { parseEther } = ethers.utils
const { createRandom } = ethers.Wallet

let mysteryBoxFactory: MysteryBoxFactory
let vrfCoordinatorV2PlusMockFactory: VRFCoordinatorV2PlusMockFactory
let fpeMapMockFactory: FPEMapMockFactory
let nonPayableFactory: NonpayableFactory

before(async function () {
  mysteryBoxFactory = (await ethers.getContractFactory(
    'MysteryBox',
  )) as MysteryBoxFactory
  vrfCoordinatorV2PlusMockFactory = (await ethers.getContractFactory(
    'VRFCoordinatorV2PlusMock',
  )) as VRFCoordinatorV2PlusMockFactory
  fpeMapMockFactory = (await ethers.getContractFactory(
    'FPEMapMock',
  )) as FPEMapMockFactory
  nonPayableFactory = (await ethers.getContractFactory(
    'Nonpayable',
  )) as NonpayableFactory
})

describe('MysteryBox', function () {
  const name = 'Name'
  const symbol = 'SYMBOL'
  const unrevealedUri = 'https://unrevealed.com'
  const extension = '.json'
  const fee = parseEther('0.01')
  const maxSupply = 10
  const maxMintPerUser = 10
  const royaltyBps = 100

  const baseFee = '100000000000000000'
  const gasPriceLink = '1000000000'
  const subscriptionId = 1
  const subscriptionFundAmount = parseEther('1')
  const keyHash = HashZero

  let mysteryBox: MysteryBox
  let vrfCoordinatorV2PlusMock: VRFCoordinatorV2PlusMock

  let merkleTree: MerkleTree

  let owner: SignerWithAddress
  let regularUser: SignerWithAddress
  let whitelistedUser: SignerWithAddress
  let nonWhitelistedUser: SignerWithAddress

  before(async function () {
    const accounts = await ethers.getSigners()
    owner = accounts[0]
    regularUser = accounts[1]
    nonWhitelistedUser = accounts[2]
    whitelistedUser = accounts[3]

    merkleTree = new MerkleTree(
      [whitelistedUser.address, createRandom().address, createRandom().address],
      keccak256,
      { sortPairs: true, hashLeaves: true },
    )
  })

  beforeEach(async function () {
    vrfCoordinatorV2PlusMock = (await vrfCoordinatorV2PlusMockFactory.deploy(
      baseFee,
      gasPriceLink,
    )) as VRFCoordinatorV2PlusMock
    await vrfCoordinatorV2PlusMock.createSubscription()
    await vrfCoordinatorV2PlusMock.fundSubscription(
      subscriptionId,
      subscriptionFundAmount,
    )
    mysteryBox = (await mysteryBoxFactory.deploy(
      name,
      symbol,
      unrevealedUri,
      maxSupply,
      maxMintPerUser,
      fee,
      merkleTree.getHexRoot(),
      royaltyBps,
      vrfCoordinatorV2PlusMock.address,
      keyHash,
      subscriptionId,
    )) as MysteryBox
    await mysteryBox.setPublicMint(true)
    await vrfCoordinatorV2PlusMock.addConsumer(
      subscriptionId,
      mysteryBox.address,
    )
  })

  describe('Mint', function () {
    it('should revert if amount is 0', async function () {
      await expect(
        mysteryBox.connect(regularUser).publicMint(0),
      ).to.be.revertedWithCustomError(mysteryBox, 'MysteryBox__ZeroAmount')
    })

    it('should revert if funds are insufficient', async function () {
      await expect(
        mysteryBox.connect(regularUser).publicMint(2, {
          value: fee,
        }),
      ).to.be.revertedWithCustomError(
        mysteryBox,
        'MysteryBox__InsufficientValue',
      )
    })

    it('should revert if max mint per user reached', async function () {
      const exceedingAmount = maxMintPerUser + 1
      await expect(
        mysteryBox.publicMint(exceedingAmount, {
          value: fee.mul(exceedingAmount),
        }),
      ).to.be.revertedWithCustomError(
        mysteryBox,
        'MysteryBox__LimitPerUserExceeded',
      )
    })

    it('should revert if cap reached', async function () {
      await mysteryBox.publicMint(maxMintPerUser, {
        value: fee.mul(maxMintPerUser),
      })
      await expect(
        mysteryBox.connect(regularUser).publicMint(1, {
          value: fee,
        }),
      ).to.be.revertedWithCustomError(
        mysteryBox,
        'ERC721Psi__ExceedMaximumSupply',
      )
    })

    it('should transfer requested amount of tokens', async function () {
      await mysteryBox.connect(regularUser).publicMint(2, {
        value: fee.mul(2),
      })
      expect(await mysteryBox.balanceOf(regularUser.address)).to.equal(2)
    })
  })

  describe('Private mint', function () {
    beforeEach(async function () {
      await mysteryBox.setPublicMint(false)
    })

    it('should revert if proof is incorrect', async function () {
      const proof = merkleTree.getHexProof(
        keccak256(nonWhitelistedUser.address),
      )
      await expect(
        mysteryBox.connect(whitelistedUser).privateMint(1, proof, {
          value: fee,
        }),
      ).to.be.revertedWithCustomError(mysteryBox, 'MysteryBox__NotEligible')
    })

    it('should revert if non-whitelisted users tries to mint', async function () {
      const proof = merkleTree.getHexProof(keccak256(whitelistedUser.address))
      await expect(
        mysteryBox.connect(nonWhitelistedUser).privateMint(1, proof, {
          value: fee,
        }),
      ).to.be.revertedWithCustomError(mysteryBox, 'MysteryBox__NotEligible')
    })

    it('should allow whitelisted users to mint', async function () {
      const proof = merkleTree.getHexProof(keccak256(whitelistedUser.address))
      await expect(
        mysteryBox.connect(whitelistedUser).privateMint(1, proof, {
          value: fee,
        }),
      )
        .to.emit(mysteryBox, 'Transfer')
        .withArgs(AddressZero, whitelistedUser.address, 0)
    })
  })

  describe('Public mint', function () {
    it('should revert if public mint is not enabled', async function () {
      await mysteryBox.setPublicMint(false)
      await expect(
        mysteryBox.publicMint(1, {
          value: fee,
        }),
      ).to.be.revertedWithCustomError(mysteryBox, 'MysteryBox__NotAllowed')
    })

    it('should allow anyone to mint', async function () {
      await expect(
        mysteryBox.connect(nonWhitelistedUser).publicMint(1, {
          value: fee,
        }),
      )
        .to.emit(mysteryBox, 'Transfer')
        .withArgs(AddressZero, nonWhitelistedUser.address, 0)
    })
  })

  describe('Pre-reveal', function () {
    beforeEach(async function () {
      await mysteryBox.publicMint(1, {
        value: fee,
      })
    })

    it('should return not-revealed URI', async function () {
      expect(await mysteryBox.tokenURI(0)).to.equal(unrevealedUri)
    })
  })

  describe('Reveal', function () {
    const revealedUri = 'https://revealed.com/'

    let fpeMapMock: FPEMapMock

    let randomData: BigNumber

    beforeEach(async function () {
      fpeMapMock = (await fpeMapMockFactory.deploy()) as FPEMapMock

      await mysteryBox.publicMint(1, { value: fee })
      await mysteryBox.setBaseURI(revealedUri)

      const reveal = await mysteryBox.reveal()
      const revealReceipt = await reveal.wait()
      const vrfRequestId = revealReceipt.events?.[1].args?.requestId

      const fulfilledTx = await vrfCoordinatorV2PlusMock.fulfillRandomWords(
        vrfRequestId,
        mysteryBox.address,
      )
      const fulfilledRequestReceipt = await fulfilledTx.wait()
      randomData = await fulfilledRequestReceipt.events?.[0].args?.randomWord
    })

    it('should revert if minting after reveal', async function () {
      await expect(
        mysteryBox.connect(regularUser).publicMint(1, {
          value: fee,
        }),
      ).to.be.revertedWithCustomError(mysteryBox, 'MysteryBox__NotAllowed')
    })

    it('should revert if requested token does not exist', async function () {
      await expect(mysteryBox.tokenURI(maxSupply + 1)).to.be.revertedWith(
        'ERC721Psi: URI query for nonexistent token',
      )
    })

    it('should return correct token uri after revealing', async function () {
      const metadataId = await fpeMapMock.fpeMappingFeistelAuto(
        0,
        randomData,
        maxSupply,
      )
      expect(await mysteryBox.tokenURI(0)).to.eq(
        `${revealedUri}${metadataId}${extension}`,
      )
    })

    it('should return empty string if baseURI is not set', async function () {
      await mysteryBox.setBaseURI('')
      expect(await mysteryBox.tokenURI(0)).to.equal('')
    })

    it('should return revealed baseURI', async function () {
      expect(await mysteryBox.getBaseURI()).to.equal(revealedUri)
    })
  })

  describe('Owner', function () {
    it('should revert if regular user tries to withdraw funds', async function () {
      await expect(
        mysteryBox.connect(nonWhitelistedUser).withdraw(),
      ).to.be.revertedWith('Only callable by owner')
    })

    it('should revert when transfer call fails', async function () {
      const nonpayableNft = await nonPayableFactory.deploy(mysteryBox.address)
      await mysteryBox.transferOwnership(nonpayableNft.address)
      await nonpayableNft.acceptOwnership()
      expect(await mysteryBox.owner()).to.equal(nonpayableNft.address)
      await mysteryBox.connect(nonWhitelistedUser).publicMint(1, { value: fee })
      await expect(nonpayableNft.withdraw()).to.be.revertedWithCustomError(
        mysteryBox,
        'MysteryBox__FailedToWithdrawFunds',
      )
    })

    it('should transfer funds to owner address', async function () {
      await mysteryBox.connect(nonWhitelistedUser).publicMint(1, {
        value: fee,
      })
      await expect(() => mysteryBox.withdraw()).to.changeEtherBalance(
        owner,
        fee,
      )
    })

    it('should update royalty info', async function () {
      const newReceiver = regularUser.address
      const newRoyaltyBps = 500
      const saleAmount = 1000
      const newFeeAmount = saleAmount * (newRoyaltyBps / 10000)

      await mysteryBox.connect(owner).setRoyalty(newReceiver, newRoyaltyBps)

      const [receiver, amount] = await mysteryBox.royaltyInfo(0, saleAmount)

      expect(receiver).to.equal(newReceiver)
      expect(amount).to.equal(newFeeAmount)
    })

    it('should update whitelist', async function () {
      const newMerkleTree = new MerkleTree(
        [
          createRandom().address,
          createRandom().address,
          createRandom().address,
        ],
        keccak256,
        {
          sortPairs: true,
          hashLeaves: true,
        },
      )
      const hexRoot = newMerkleTree.getHexRoot()
      await mysteryBox.setWhitelistRoot(hexRoot)

      expect(await mysteryBox.getWhitelistRoot()).to.equal(hexRoot)
    })

    it('should update mint fee', async function () {
      const newFee = parseEther('0.2')
      await mysteryBox.setMintFee(newFee)

      expect(await mysteryBox.getFee()).to.eq(newFee)
    })

    it('should set provenance hash', async function () {
      const randomBytes = '0x1234abcd'
      await mysteryBox.setProvenanceHash(randomBytes)
      expect(await mysteryBox.getProvenanceHash()).to.equal(randomBytes)
    })
  })

  describe('Royalties', function () {
    it('should return correct royalty info', async function () {
      const saleAmount = 1000
      const feeAmount = saleAmount * (royaltyBps / 10000)
      const [receiver, amount] = await mysteryBox.royaltyInfo(0, saleAmount)
      expect(receiver).to.equal(owner.address)
      expect(amount).to.equal(feeAmount)
    })
  })

  describe('Misc', function () {
    const Interfaces = {
      ERC165: '0x01ffc9a7',
      ERC721: '0x80ac58cd',
      ERC2981: '0x2a55205a',
    }

    it('should have the right interfaces', async function () {
      expect(await mysteryBox.supportsInterface(Interfaces.ERC165)).equals(true)
      expect(await mysteryBox.supportsInterface(Interfaces.ERC721)).equals(true)
      expect(await mysteryBox.supportsInterface(Interfaces.ERC2981)).equals(
        true,
      )
    })
  })
})
