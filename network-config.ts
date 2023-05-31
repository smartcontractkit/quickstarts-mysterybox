export type NetworkConfig = Record<
  string,
  {
    name: string
    linkToken: string
    vrfCoordinatorV2: string
    keyHash: string
    fundAmount: string
  }
>

export const networkConfig: NetworkConfig = {
  '5': {
    name: 'goerli',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    vrfCoordinatorV2: '0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D',
    keyHash:
      '0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15',
    fundAmount: '15000000000000000000', // 15 LINK
  },
  '31337': {
    name: 'hardhat',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    vrfCoordinatorV2: '0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D',
    keyHash:
      '0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15',
    fundAmount: '10000000000000000000', // 10 LINK
  },
}
