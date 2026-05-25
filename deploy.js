import { readFileSync, writeFileSync, existsSync } from 'fs';
import { ethers } from 'ethers';

// Fallback: Generate a temporary deployer wallet if the platform hasn't injected one
if (!existsSync('.deployer-env.json')) {
  const randomWallet = ethers.Wallet.createRandom();
  writeFileSync('.deployer-env.json', JSON.stringify({ 
    DEPLOYER_PRIVATE_KEY: randomWallet.privateKey 
  }, null, 2));
  console.log('Generated temporary deployer wallet since .deployer-env.json was missing.');
}

const { DEPLOYER_PRIVATE_KEY } = JSON.parse(readFileSync('.deployer-env.json', 'utf8'));
const PRIVATE_KEY  = DEPLOYER_PRIVATE_KEY;
const RPC          = 'https://sepolia.base.org';
const CHAIN_ID     = 84532;
const NETWORK_NAME = 'Base Sepolia';

async function main() {
  console.log(`Connecting to ${NETWORK_NAME}...`);
  const provider = new ethers.JsonRpcProvider(RPC, CHAIN_ID);
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);

  console.log(`Deploying from account: ${wallet.address}`);

  const balance = await provider.getBalance(wallet.address);
  if (balance === 0n) {
    console.error(`\n❌ INSUFFICIENT FUNDS: Account ${wallet.address} has 0 ETH.`);
    console.error(`Please fund this account on Base Sepolia to proceed with deployment.\n`);
    process.exit(1);
  }

  const abi = JSON.parse(readFileSync('./build/RageQuitDAO.abi.json', 'utf8'));
  const bytecode = JSON.parse(readFileSync('./build/RageQuitDAO.bytecode.json', 'utf8'));

  const factory = new ethers.ContractFactory(abi, bytecode, wallet);
  
  console.log('Deploying RageQuitDAO contract...');
  const contract = await factory.deploy();
  await contract.waitForDeployment();
  
  const contractAddress = await contract.getAddress();
  console.log(`Contract deployed successfully at: ${contractAddress}`);

  const deploymentInfo = {
    contractAddress,
    network: NETWORK_NAME,
    chainId: CHAIN_ID,
    deployedAt: new Date().toISOString()
  };

  writeFileSync('deployment-info.json', JSON.stringify(deploymentInfo, null, 2));
  console.log('Deployment info saved to deployment-info.json');
}

main().catch((error) => {
  console.error('Deployment failed:', error);
  process.exit(1);
});
