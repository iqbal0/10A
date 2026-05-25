import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'fs';
import solc from 'solc';

const contractSource = readFileSync('./contracts/RageQuitDAO.sol', 'utf8');

const input = {
  language: 'Solidity',
  sources: {
    'RageQuitDAO.sol': {
      content: contractSource,
    },
  },
  settings: {
    outputSelection: {
      '*': {
        '*': ['abi', 'evm.bytecode.object'],
      },
    },
  },
};

console.log('Compiling contract...');
const output = JSON.parse(solc.compile(JSON.stringify(input)));

if (output.errors) {
  const hasErrors = output.errors.some(err => err.severity === 'error');
  output.errors.forEach(err => console.error(err.formattedMessage));
  if (hasErrors) process.exit(1);
}

const contractName = 'RageQuitDAO';
const contract = output.contracts['RageQuitDAO.sol'][contractName];

if (!existsSync('./build')) {
  mkdirSync('./build');
}

writeFileSync(`./build/${contractName}.abi.json`, JSON.stringify(contract.abi, null, 2));
writeFileSync(`./build/${contractName}.bytecode.json`, JSON.stringify(contract.evm.bytecode.object));

console.log(`Compilation successful. ABI and bytecode saved to ./build/`);
