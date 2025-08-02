const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Desplegando contratos con la cuenta:", deployer.address);

  // Desplegar implementaciones
  const AdrianStorage = await ethers.getContractFactory("AdrianStorage");
  const storage = await AdrianStorage.deploy();
  await storage.deployed();
  console.log("AdrianStorage desplegado en:", storage.address);

  const AdrianLabCore = await ethers.getContractFactory("AdrianLabCore");
  const labCore = await AdrianLabCore.deploy();
  await labCore.deployed();
  console.log("AdrianLabCore desplegado en:", labCore.address);

  const AdrianLabAdmin = await ethers.getContractFactory("AdrianLabAdmin");
  const labAdmin = await AdrianLabAdmin.deploy();
  await labAdmin.deployed();
  console.log("AdrianLabAdmin desplegado en:", labAdmin.address);

  const AdrianLabExtensions = await ethers.getContractFactory("AdrianLabExtensions");
  const labExtensions = await AdrianLabExtensions.deploy();
  await labExtensions.deployed();
  console.log("AdrianLabExtensions desplegado en:", labExtensions.address);

  const AdrianTraitsCore = await ethers.getContractFactory("AdrianTraitsCore");
  const traitsCore = await AdrianTraitsCore.deploy();
  await traitsCore.deployed();
  console.log("AdrianTraitsCore desplegado en:", traitsCore.address);

  const AdrianTraitsExtensions = await ethers.getContractFactory("AdrianTraitsExtensions");
  const traitsExtensions = await AdrianTraitsExtensions.deploy();
  await traitsExtensions.deployed();
  console.log("AdrianTraitsExtensions desplegado en:", traitsExtensions.address);

  const AdrianSerumModule = await ethers.getContractFactory("AdrianSerumModule");
  const serumModule = await AdrianSerumModule.deploy();
  await serumModule.deployed();
  console.log("AdrianSerumModule desplegado en:", serumModule.address);

  const AdrianHistory = await ethers.getContractFactory("AdrianHistory");
  const history = await AdrianHistory.deploy();
  await history.deployed();
  console.log("AdrianHistory desplegado en:", history.address);

  // Desplegar Proxy
  const AdrianMasterProxy = await ethers.getContractFactory("AdrianMasterProxy");
  const proxy = await AdrianMasterProxy.deploy();
  await proxy.deployed();
  console.log("AdrianMasterProxy desplegado en:", proxy.address);

  // Inicializar Proxy
  await proxy.initialize(deployer.address);
  console.log("Proxy inicializado");

  // Registrar implementaciones en el Proxy
  const labCoreSelector = AdrianLabCore.interface.getSighash("initialize");
  const labAdminSelector = AdrianLabAdmin.interface.getSighash("initialize");
  const labExtensionsSelector = AdrianLabExtensions.interface.getSighash("initialize");
  const traitsCoreSelector = AdrianTraitsCore.interface.getSighash("initialize");
  const traitsExtensionsSelector = AdrianTraitsExtensions.interface.getSighash("initialize");
  const serumModuleSelector = AdrianSerumModule.interface.getSighash("initialize");
  const historySelector = AdrianHistory.interface.getSighash("initialize");

  await proxy.updateImplementation(labCoreSelector, labCore.address);
  await proxy.updateImplementation(labAdminSelector, labAdmin.address);
  await proxy.updateImplementation(labExtensionsSelector, labExtensions.address);
  await proxy.updateImplementation(traitsCoreSelector, traitsCore.address);
  await proxy.updateImplementation(traitsExtensionsSelector, traitsExtensions.address);
  await proxy.updateImplementation(serumModuleSelector, serumModule.address);
  await proxy.updateImplementation(historySelector, history.address);

  console.log("Implementaciones registradas en el Proxy");

  // Inicializar contratos a través del Proxy
  const proxyLabCore = AdrianLabCore.attach(proxy.address);
  const proxyLabAdmin = AdrianLabAdmin.attach(proxy.address);
  const proxyLabExtensions = AdrianLabExtensions.attach(proxy.address);
  const proxyTraitsCore = AdrianTraitsCore.attach(proxy.address);
  const proxyTraitsExtensions = AdrianTraitsExtensions.attach(proxy.address);
  const proxySerumModule = AdrianSerumModule.attach(proxy.address);
  const proxyHistory = AdrianHistory.attach(proxy.address);

  await proxyLabCore.initialize("Adrian Lab", "ADRIAN", deployer.address);
  await proxyLabAdmin.initialize(deployer.address);
  await proxyLabExtensions.initialize(deployer.address);
  await proxyTraitsCore.initialize(deployer.address);
  await proxyTraitsExtensions.initialize(deployer.address);
  await proxySerumModule.initialize(deployer.address);
  await proxyHistory.initialize(deployer.address);

  console.log("Contratos inicializados a través del Proxy");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 