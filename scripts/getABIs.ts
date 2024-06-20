const fs = require('fs');

import constantABIs from '../constants/constantABIs';

async function writeJSON(path: string, data: Object) {
  await fs.writeFileSync(path, JSON.stringify(data));
  return data;
}

async function readJSON(path: string) {
  let data = await fs.readFileSync(`./${path}`);
  return JSON.parse(data);
}

async function getABI(file: string, contract: string): Array<any> {
  return (await readJSON(`artifacts/contracts/${file}/${contract}.json`)).abi;
}

async function main() {
  let ABIs = constantABIs;
  ABIs['tokenBank'] = await getABI('tokenBank.sol', 'TokenBank');
  ABIs['borrower'] = await getABI('borrowerNFT.sol', 'Borrower');
  ABIs['lender'] = await getABI('lenderNFT.sol', 'Lender');
  await writeJSON('constants/ABIs.json', ABIs);
  console.log('sucessfully saved the new ABIs');
}

main();
