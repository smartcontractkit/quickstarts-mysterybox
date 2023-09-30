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
  '43113': {
    name: 'avalancheFuji',
    linkToken: '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846',
    vrfCoordinatorV2: '0x2eD832Ba664535e5886b75D64C46EB9a228C2610',
    keyHash:
      '0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61',
    fundAmount: '5000000000000000000', // 5 LINK
  },
  '80001': {
    name: 'polygonMumbai',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    vrfCoordinatorV2: '0x7a1BaC17Ccc5b313516C5E16fb24f7659aA5ebed',
    keyHash:
      '0x4b09e658ed251bcafeebbc69400383d49f344ace09b9576fe248bb02c003fe9f',
    fundAmount: '5000000000000000000', // 5 LINK
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
