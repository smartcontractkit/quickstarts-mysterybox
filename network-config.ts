export type NetworkConfig = Record<
  string,
  {
    name: string
    linkToken: string
    vrfCoordinatorV2Plus: string
    keyHash: string
    fundAmount: string
  }
>

export const networkConfig: NetworkConfig = {
  '11155111': {
    name: 'ethereumSepolia',
    linkToken: '0x779877A7B0D9E8603169DdbD7836e478b4624789',
    vrfCoordinatorV2Plus: '0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B',
    keyHash:
      '0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae',
    fundAmount: '5000000000000000000', // 5 LINK
  },
  '43113': {
    name: 'avalancheFuji',
    linkToken: '0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846',
    vrfCoordinatorV2Plus: '0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE',
    keyHash:
      '0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887',
    fundAmount: '5000000000000000000', // 5 LINK
  },
  '31337': {
    name: 'hardhat',
    linkToken: '0x326C977E6efc84E512bB9C30f76E30c160eD06FB',
    vrfCoordinatorV2Plus: '0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D',
    keyHash:
      '0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15',
    fundAmount: '10000000000000000000', // 10 LINK
  },
}
