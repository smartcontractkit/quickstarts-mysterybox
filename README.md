# Chainlink Solution Accelerator: Mystery Box

This is a template for NFT collection with a mystery box mechanic powered by [Chainlink VRF](https://vrf.chain.link/). It could be used as is or as a starting point for your own project.

Smart contracts are based on the gas efficient [ERC721Psi](https://github.com/estarriolvetch/ERC721Psi) and are fully tested. It's super easy to deploy and configure with most of the steps automated in the deploy script.

Some of the key features of this template include private minting stage with a merkle tree, rate limited batch minting, delayed reveal with randomization technique to save gas, provenance hash to verify the authenticity of the metadata, royalties for secondary sales, and configurable parameters.

## Table of Contents

- [Requirements](#requirements)
- [Getting Started](#getting-started)
- [Setup](#setup)
- [Test](#test)
- [Deploy](#deploy)
- [Private Mint](#private-mint)
- [Public Mint](#public-mint)
- [Metadata](#metadata)
- [Provenance](#provenance)
- [Reveal](#reveal)
- [Withdraw Funds](#withdraw-funds)
- [Royalties](#royalty)
- [Configuration](#configuration)
- [Format](#format)
- [Lint](#lint)
- [References](#references)

## Requirements

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
  - You'll know you did it right if you can run `git --version` and you see a response like `git version x.x.x`
- [Nodejs](https://nodejs.org/en/) 16.0.0 or higher
  - You'll know you've installed nodejs right if you can run:
    - `node --version` and get an output like: `v16.x.x`

## Getting Started

- Clone the repo:

  ```bash
  git clone https://github.com/smartcontractkit/quickstarts-mysterybox.git
  ```

- Change directories and install all dependencies:

  ```bash
  cd quickstarts-mysterybox && npm install
  ```

  Alternatively, you can use [yarn](https://yarnpkg.com/) to install dependencies:

  ```bash
  yarn install
  ```

## Setup

Copy the `.env.example` file to `.env` and fill in the values.

```bash
cp .env.example .env
```

Begin by setting up the parameters for the NFT contract.

| Parameter               | Description                                                                                                                   | Example                                                                         |
| ----------------------- | ----------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `NFT_NAME`              | The name of the NFT collection                                                                                                | `MysteryBox`                                                                    |
| `NFT_SYMBOL`            | The symbol of the NFT collection                                                                                              | `BOX`                                                                           |
| `NFT_UNREVEALED_URI`    | The metadata URI for all tokens before reveal                                                                                 | `https://example.com`                                                           |
| `NFT_MAX_SUPPLY`        | The maximum number of tokens that can be minted                                                                               | `100`                                                                           |
| `NFT_MAX_MINT_PER_USER` | The maximum number of tokens that can be minted per user address                                                              | `10`                                                                            |
| `NFT_FEE`               | The fee for minting a token in ETH                                                                                            | `0.01`                                                                          |
| `NFT_ROYALTY_BPS`       | The royalty fee for selling a token in basis points                                                                           | `500`                                                                           |
| `VRF_SUBSCRIPTION_ID`   | A funded Chainlink VRF 2.5 subscription ID. If you leave this blank, a new subscription will be created and funded on deploy. | `79850349243438349975305816782035019118399435445660033947721688676378382535454` |

Next, set up the parameters for the Hardhat project.

| Parameter         | Description                                               | Example                                    |
| ----------------- | --------------------------------------------------------- | ------------------------------------------ |
| `SEPOLIA_RPC_URL` | The RPC URL for Ethereum Sepolia.                         | `https://eth-sepolia.g.alchemy.com/v2/...` |
| `PRIVATE_KEY`     | The private key of the account you want to deploy from.   | `abc123abc123abc123abc123abc123...`        |
| `SCANNER_API_KEY` | The API key for Etherscan used for contract verification. | `ABC123ABC123ABC123ABC123ABC123ABC1`       |

## Test

To run the unit tests, run the following command.

```bash
npm run test
```

If you want to see gas usage, run the following command.

```bash
REPORT_GAS=true npm run test
```

For coverage reports, run the following command.

```bash
npm run coverage
```

## Deploy

Besides deploying the contract, the deploy script will also:

1. Create and fund a 2.5 VRF subscription if one is not provided.
   Note: Make sure the deployer account has enough LINK to fund the subscription. The initial funding amount is configured in `network-config.js`. For testnets, you can use the [LINK faucet](https://faucets.chain.link/).
2. Add the deployed contract address as a consumer to the VRF subscription.
   Note: If you provided a subscription ID, make sure the deployer account is the owner of the subscription. Otherwise, comment out the `addConsumerToSubscription` function in the deploy script and add the contract address manually.
3. Generate a merkle tree for the private mint.
   Note: The merkle tree is generated from the address list in `scripts/data/whitelist.json` file. Leave the file empty if you don't want to do a private mint.
4. Verify the contract on Etherscan. If you want to skip this step, comment out the `verify` function in the deploy script.

To run the deploy script, run the following command and replace `<network>` with the network you want to deploy to (as defined in `network-config.ts`).

```bash
npx hardhat run scripts/deploy.ts --network <network>
```

E.g. for Ethereum Sepolia:

```bash
npx hardhat run scripts/deploy.ts --network ethereumSepolia
```

Note: The network must also be configured in `hardhat.config.ts`.

## Private Mint

The contract is by default in private mode after deployment. This means that only whitelisted addresses can mint tokens. The list of whitelisted addresses is stored in a merkle tree. The merkle tree is generated from the address list in `scripts/data/whitelist.json` file.

If you don't want to do a private mint, enable public minting by calling the `setPublicMint` function with `true` as the parameter.

Minting tokens in private mode is done by calling the `privateMint` function. The function takes the following parameters:

- `amount` The amount of tokens to mint.
- `proof` The merkle proof for the user's address. To generate it, see [merkletreejs](https://github.com/merkletreejs/merkletreejs).

## Public Mint

To enable public minting, call the `setPublicMint` function with `true` as the parameter.

Minting tokens in public mode is done by calling the `publicMint` function. The function takes the following parameters:

- `publicMint`: The payable amount in ETH (per token).
- `amount`: The amount of tokens to mint.

Each address can only mint a maximum of `NFT_MAX_MINT_PER_USER` tokens.

## Metadata

NFT metadata is the standard description of an asset which allows applications (like wallets and marketplaces) to present them with rich data. You can learn more about this in the [Metadata Standards](https://docs.opensea.io/docs/metadata-standards) Guide by OpenSea.

Because of the [randomization technique](https://mirror.xyz/ctor.xyz/ZEY5-wn-3EeHzkTUhACNJZVKc0-R6EsDwwHMr5YJEn0) used, the actual metadata for each token can be known before the reveal. So it is safe to set the `baseURI` in advance.

This creates additional trust for the users because they can verify the metadata before minting.

#### Storage Options

The metadata for each token is stored in a JSON file and must be hosted somewhere. You can use any storage provider you want. Here are some options:

- Decentralized
  - [IPFS](https://ipfs.io/)
  - [Arweave](https://www.arweave.org/)
  - [Pinata](https://pinata.cloud/)
- Centralized
  - [AWS S3](https://aws.amazon.com/s3/)
  - [Google Cloud Storage](https://cloud.google.com/storage)

Alternatively, you can build a metadata server that serves the metadata for each token. Here's an example of a [metadata server](https://github.com/ProjectOpenSea/metadata-api-nodejs) built by OpenSea.

## Provenance

The provenance hash is a hash of the collection's metadata. It is used to verify the authenticity of the collection in addition to the metadata known before reveal.

It should be computed off-chain by SHA256 hashing every image, concatenating the hashes and then SHA256 hashing the combined string too. The resulting hash should be set as the provenance hash by calling the `setProvenanceHash` function.

Learn more about the elegance of the provenance hash in this [blog post](https://blog.0xproject.com/the-elegance-of-the-provenance-hash-4d8d9b2a0b0e).

## Reveal

To reveal the NFTs, call the `reveal` function from the owner account. It will create a Chainlink VRF request to generate a random seed.

When the request is fulfilled, the NFTs metadata for each token will be randomized with the seed provided.

The token URI will also start to use the `baseURI` instead of the `unrevealedURI`, so make sure to call the `setBaseURI` function before calling the `reveal` function.

Once the collection is revealed, the minting functions will be disabled.

## Withdraw Funds

At any time, the owner can withdraw funds from the contract by calling the `withdraw` function. By doing so the contract balance will be transferred to the owner account.

## Royalties

This contract supports royalties for secondary sales. The royalty fee is set to `NFT_ROYALTY_BPS` basis points and royalty receiver is set to the owner account by default. It can be changed by calling the `setRoyalty` function.

The standard for royalties is defined in the [ERC2981](https://eips.ethereum.org/EIPS/eip-2981) EIP and this contract implements it.

## Configuration

Upon deployment, some of the contract parameters can be changed by calling the following functions from the owner account.

| Function            | Description                              | Parameters           |
| ------------------- | ---------------------------------------- | -------------------- |
| `setBaseURI`        | Set the base URI for the token metadata. | `newBaseURI`         |
| `setMintFee`        | Set new mint fee.                        | `fee`                |
| `setWhitelistRoot`  | Set new merkle root for the whitelist.   | `whitelistRoot`      |
| `setProvenanceHash` | Set new provenance hash.                 | `provenanceHash`     |
| `setRoyalty`        | Set new royalty receiver and fee.        | `receiver`, `feeBps` |
| `setPublicMint`     | Enable/disable public minting.           | `publicMintEnabled`  |

## Format

For formatting, we use [prettier](https://prettier.io/).

To check the formatting, run the following command.

```bash
npm run prettier:check
```

To fix the formatting, run the following command.

```bash
npm run prettier:write
```

## Lint

For linting, we use [eslint](https://eslint.org/).

To run the linter, run the following command.

```bash
npm run lint
```

## References

- [Chainlink VRF](https://docs.chain.link/vrf)
- [OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/)
- [ERC721Psi](https://github.com/estarriolvetch/ERC721Psi)
- [ERC721](https://eips.ethereum.org/EIPS/eip-721)
- [Hardhat](https://hardhat.org/hardhat-runner/docs/getting-started)

> :warning: **Disclaimer**: This tutorial represents an educational example to use a Chainlink system, product, or service and is provided to demonstrate how to interact with Chainlink’s systems, products, and services to integrate them into your own. This template is provided “AS IS” and “AS AVAILABLE” without warranties of any kind, it has not been audited, and it may be missing key checks or error handling to make the usage of the system, product or service more clear. Do not use the code in this example in a production environment without completing your own audits and application of best practices. Neither Chainlink Labs, the Chainlink Foundation, nor Chainlink node operators are responsible for unintended outputs that are generated due to errors in code.
