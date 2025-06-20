const hre = require("hardhat");

async function main() {
  const MultiSigEHR = await hre.ethers.getContractFactory("MultiSigEHR");
  const ehr = await MultiSigEHR.deploy(); // Deploy the contract
  await ehr.waitForDeployment(); // ✅ Correct method in newer Hardhat/Ethers versions

  console.log(`✅ Contract deployed at: ${ehr.target}`); // ✅ Use `ehr.target` for address
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
