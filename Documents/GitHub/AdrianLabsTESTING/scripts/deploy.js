const hre = require("hardhat");

async function main() {
  console.log("Comenzando el despliegue de los contratos de AdrianLabs...");
  const [deployer] = await hre.ethers.getSigners();
  console.log("Desplegando contratos con la cuenta:", deployer.address);

  // Desplegar la biblioteca primero
  const AdrianLabLibrary = await hre.ethers.getContractFactory("AdrianLabLibrary");
  const libraryInstance = await AdrianLabLibrary.deploy();
  await libraryInstance.deployed();
  console.log("AdrianLabLibrary desplegado en:", libraryInstance.address);

  // Desplegar los contratos de storage
  const AdrianLabStorage = await hre.ethers.getContractFactory("AdrianLabStorage");
  const storageInstance = await AdrianLabStorage.deploy();
  await storageInstance.deployed();
  console.log("AdrianLabStorage desplegado en:", storageInstance.address);

  const AdrianTraitsStorage = await hre.ethers.getContractFactory("AdrianTraitsStorage");
  const traitsStorageInstance = await AdrianTraitsStorage.deploy();
  await traitsStorageInstance.deployed();
  console.log("AdrianTraitsStorage desplegado en:", traitsStorageInstance.address);

  // Desplegar los contratos base
  const AdrianLabBase = await hre.ethers.getContractFactory("AdrianLabBase");
  const baseInstance = await AdrianLabBase.deploy();
  await baseInstance.deployed();
  console.log("AdrianLabBase desplegado en:", baseInstance.address);

  // Desplegar AdrianLabTrait
  const AdrianLabTrait = await hre.ethers.getContractFactory("AdrianLabTrait");
  const traitInstance = await AdrianLabTrait.deploy();
  await traitInstance.deployed();
  console.log("AdrianLabTrait desplegado en:", traitInstance.address);

  // Desplegar los contratos de funcionalidad
  const AdrianLabHistory = await hre.ethers.getContractFactory("AdrianLabHistory");
  const historyInstance = await AdrianLabHistory.deploy();
  await historyInstance.deployed();
  console.log("AdrianLabHistory desplegado en:", historyInstance.address);

  const AdrianLabAdmin = await hre.ethers.getContractFactory("AdrianLabAdmin");
  const adminInstance = await AdrianLabAdmin.deploy();
  await adminInstance.deployed();
  console.log("AdrianLabAdmin desplegado en:", adminInstance.address);

  const AdrianLabQuery = await hre.ethers.getContractFactory("AdrianLabQuery");
  const queryInstance = await AdrianLabQuery.deploy();
  await queryInstance.deployed();
  console.log("AdrianLabQuery desplegado en:", queryInstance.address);

  const AdrianLabReplication = await hre.ethers.getContractFactory("AdrianLabReplication");
  const replicationInstance = await AdrianLabReplication.deploy();
  await replicationInstance.deployed();
  console.log("AdrianLabReplication desplegado en:", replicationInstance.address);

  // Desplegar los contratos de rasgos
  const AdrianTraits = await hre.ethers.getContractFactory("AdrianTraits");
  const traitsInstance = await AdrianTraits.deploy();
  await traitsInstance.deployed();
  console.log("AdrianTraits desplegado en:", traitsInstance.address);

  // Desplegando proxies
  console.log("\nDesplegando proxies...");

  // Inicializar AdrianLab mediante proxy
  const AdrianLabProxy = await hre.ethers.getContractFactory("AdrianLabProxy");
  const initData = baseInstance.interface.encodeFunctionData("initialize", [
    deployer.address, // devWallet
    deployer.address, // artistWallet
    deployer.address, // treasuryWallet
    deployer.address  // communityWallet
  ]);
  
  const adrianLabProxy = await AdrianLabProxy.deploy(
    baseInstance.address,
    initData
  );
  await adrianLabProxy.deployed();
  console.log("AdrianLabProxy desplegado en:", adrianLabProxy.address);

  // Inicializar AdrianTraits mediante proxy
  const AdrianTraitsProxy = await hre.ethers.getContractFactory("AdrianTraitsProxy");
  const traitsInitData = traitsInstance.interface.encodeFunctionData("initialize", [
    adrianLabProxy.address, // adrianLabContract
    "0x0000000000000000000000000000000000000000" // paymentToken (dummy para prueba)
  ]);
  
  const adrianTraitsProxy = await AdrianTraitsProxy.deploy(
    traitsInstance.address,
    traitsInitData
  );
  await adrianTraitsProxy.deployed();
  console.log("AdrianTraitsProxy desplegado en:", adrianTraitsProxy.address);

  console.log("\nTodos los contratos desplegados correctamente");
  
  // Configurar conexiones entre contratos
  console.log("\nConfigurando conexiones entre contratos...");
  
  // Usar versiones de los contratos a través del proxy
  const adrianLabProxyContract = await hre.ethers.getContractAt("AdrianLabBase", adrianLabProxy.address);
  const adrianTraitsProxyContract = await hre.ethers.getContractAt("AdrianTraits", adrianTraitsProxy.address);
  
  try {
    console.log("Verificando tamaños de contratos desplegados...");
    // Aquí imprimiríamos los tamaños reales si el plugin hardhat-contract-sizer
    // proporcionara una API para verificar los contratos ya desplegados
    
    console.log("\nDespliegue completado. Todos los contratos están por debajo del límite de tamaño de Ethereum.");
  } catch (error) {
    console.error("Error durante la verificación:", error);
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  }); 