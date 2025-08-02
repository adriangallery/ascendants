// Configuración de los contratos
const CONTRACT_ADDRESS = '0xeec1a809acb57acaba196c6677f65ecc4c6f4491'; // Staking Contract
const ADRIAN_TOKEN_ADDRESS = '0x7E99075Ce287F1cF8cBCAaa6A1C7894e404fD7Ea'; // ADRIAN Token
const ADRIAN_PUNKS_ADDRESS = '0x79BE8AcdD339C7b92918fcC3fd3875b5Aaad7566'; // AdrianPunks NFT

const CONTRACT_ABI = [
    {
        "inputs": [
            { "internalType": "address", "name": "_nftAddress", "type": "address" },
            { "internalType": "address", "name": "_rewardToken", "type": "address" }
        ],
        "stateMutability": "nonpayable",
        "type": "constructor"
    },
    {
        "inputs": [],
        "name": "baseRewardRate",
        "outputs": [{ "internalType": "uint256", "name": "", "type": "uint256" }],
        "stateMutability": "view",
        "type": "function"
    }
    // ... resto del ABI
];

// Configuración de desarrollo
const DEV_MODE = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';
const DEV_WALLET = {
    address: '0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266', // Primera cuenta de Hardhat
    balance: '1000.0',
    privateKey: '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' // Clave privada de la primera cuenta de Hardhat
};

// Variables globales
let provider;
let signer;
let contract;
let adrianToken;
let adrianPunks;
let userAddress;
let userBalance;
let nftBalance;

// Inicialización
document.addEventListener('DOMContentLoaded', async () => {
    await initWeb3();
    setupEventListeners();
    loadTheme();
});

// Inicialización de Web3
async function initWeb3() {
    if (DEV_MODE) {
        await initDevMode();
    } else {
        await initProductionMode();
    }
}

// Inicialización modo desarrollo
async function initDevMode() {
    console.log('Modo desarrollo activado');
    
    try {
        // Crear provider local (Hardhat Network)
        provider = new ethers.providers.JsonRpcProvider('http://localhost:8545');
        
        // Verificar conexión con la red local
        const network = await provider.getNetwork();
        console.log('Conectado a la red:', network.name);
        
        // Crear signer con la wallet de desarrollo
        signer = new ethers.Wallet(DEV_WALLET.privateKey, provider);
        
        // Obtener datos de la wallet
        userAddress = await signer.getAddress();
        const balance = await provider.getBalance(userAddress);
        userBalance = ethers.utils.formatEther(balance);
        
        console.log('Wallet conectada:', {
            address: userAddress,
            balance: userBalance
        });
        
        // Inicializar contratos
        contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
        adrianToken = new ethers.Contract(ADRIAN_TOKEN_ADDRESS, CONTRACT_ABI, signer);
        adrianPunks = new ethers.Contract(ADRIAN_PUNKS_ADDRESS, CONTRACT_ABI, signer);
        
        // Verificar que los contratos existen
        const contracts = [
            { name: 'Staking', address: CONTRACT_ADDRESS },
            { name: 'ADRIAN Token', address: ADRIAN_TOKEN_ADDRESS },
            { name: 'AdrianPunks', address: ADRIAN_PUNKS_ADDRESS }
        ];
        
        for (const contract of contracts) {
            const code = await provider.getCode(contract.address);
            if (code === '0x') {
                throw new Error(`El contrato ${contract.name} no está desplegado en la red local`);
            }
            console.log(`${contract.name} inicializado:`, contract.address);
        }
        
        // Actualizar UI
        updateWalletUI(true);
        showSuccess('Modo desarrollo activado - Wallet conectada');
        
        // Configurar listeners de eventos
        setupEventListeners();
    } catch (error) {
        console.error('Error en modo desarrollo:', error);
        showError('Error al conectar con la red de desarrollo. Asegúrate de que Hardhat está ejecutándose y los contratos están desplegados.');
    }
}

// Inicialización modo producción
async function initProductionMode() {
    if (typeof window.ethereum !== 'undefined') {
        provider = new ethers.providers.Web3Provider(window.ethereum);
        try {
            await window.ethereum.request({ method: 'eth_requestAccounts' });
            signer = provider.getSigner();
            userAddress = await signer.getAddress();
            contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
            await updateBalance();
            updateWalletUI(true);
            setupEventListeners();
        } catch (error) {
            console.error('Error al conectar con MetaMask:', error);
            showError('Error al conectar con MetaMask');
        }
    } else {
        showError('Please install MetaMask to use this application');
    }
}

// Configurar event listeners
function setupEventListeners() {
    // Wallet connection
    const connectButton = document.getElementById('connectWallet');
    if (connectButton) {
        connectButton.addEventListener('click', connectWallet);
    }
    
    // Theme toggle
    const themeToggle = document.getElementById('themeToggle');
    if (themeToggle) {
        themeToggle.addEventListener('click', toggleTheme);
    }
    
    // MetaMask account change
    if (window.ethereum) {
        window.ethereum.on('accountsChanged', handleAccountsChanged);
        window.ethereum.on('chainChanged', handleChainChanged);
    }
}

// Manejar cambio de cuenta
async function handleAccountsChanged(accounts) {
    if (accounts.length === 0) {
        // Wallet desconectada
        updateWalletUI(false);
    } else {
        // Nueva cuenta seleccionada
        userAddress = accounts[0];
        signer = provider.getSigner();
        contract = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, signer);
        await updateBalance();
        updateWalletUI(true);
    }
}

// Manejar cambio de red
function handleChainChanged(chainId) {
    window.location.reload();
}

// Conectar wallet
async function connectWallet() {
    if (DEV_MODE) {
        // En modo desarrollo, simplemente mostramos la wallet de prueba
        updateWalletUI(true);
        showSuccess('Wallet de desarrollo conectada');
    } else {
        try {
            if (typeof window.ethereum !== 'undefined') {
                await window.ethereum.request({ method: 'eth_requestAccounts' });
                signer = provider.getSigner();
                userAddress = await signer.getAddress();
                await updateBalance();
                updateWalletUI(true);
                showSuccess('Wallet connected successfully! 🚀');
            } else {
                showError('Please install MetaMask to use this application');
            }
        } catch (error) {
            console.error('Error connecting wallet:', error);
            showError('Error connecting wallet');
        }
    }
}

// Actualizar balance
async function updateBalance() {
    try {
        if (DEV_MODE) {
            if (!provider) return;
            const balance = await provider.getBalance(userAddress);
            userBalance = ethers.utils.formatEther(balance);
            
            // Obtener balance de NFTs
            if (adrianPunks) {
                const nftBalance = await adrianPunks.balanceOf(userAddress);
                console.log('NFT Balance:', nftBalance.toString());
            }
            return;
        }
        
        if (!contract) return;
        const balance = await contract.balanceOf(userAddress);
        userBalance = ethers.utils.formatEther(balance);
    } catch (error) {
        console.error('Error updating balance:', error);
        userBalance = '0';
    }
}

// Actualizar UI de wallet
function updateWalletUI(isConnected) {
    const connectButton = document.getElementById('connectWallet');
    const walletInfo = document.getElementById('walletInfo');
    const walletAddress = document.getElementById('walletAddress');
    const walletBalance = document.getElementById('walletBalance');
    
    if (isConnected) {
        connectButton.classList.add('d-none');
        walletInfo.classList.remove('d-none');
        walletAddress.textContent = `${userAddress.slice(0, 6)}...${userAddress.slice(-4)}`;
        walletBalance.textContent = `${userBalance} ADRIAN`;
    } else {
        connectButton.classList.remove('d-none');
        walletInfo.classList.add('d-none');
    }
}

// Toggle tema
function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    
    // Actualizar ícono
    const themeIcon = document.querySelector('#themeToggle i');
    themeIcon.className = newTheme === 'dark' ? 'fas fa-moon' : 'fas fa-sun';
}

// Cargar tema guardado
function loadTheme() {
    const savedTheme = localStorage.getItem('theme') || 'dark';
    document.documentElement.setAttribute('data-theme', savedTheme);
    
    // Actualizar ícono
    const themeIcon = document.querySelector('#themeToggle i');
    themeIcon.className = savedTheme === 'dark' ? 'fas fa-moon' : 'fas fa-sun';
}

// Mostrar mensaje de éxito
function showSuccess(message) {
    // Aquí puedes implementar tu propia lógica para mostrar mensajes de éxito
    const toast = document.createElement('div');
    toast.className = 'toast align-items-center text-white bg-success border-0';
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'assertive');
    toast.setAttribute('aria-atomic', 'true');
    toast.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">
                ${message}
            </div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
        </div>
    `;
    document.body.appendChild(toast);
    const bsToast = new bootstrap.Toast(toast);
    bsToast.show();
    setTimeout(() => toast.remove(), 3000);
}

// Mostrar error
function showError(message) {
    // Aquí puedes implementar tu propia lógica para mostrar errores
    const toast = document.createElement('div');
    toast.className = 'toast align-items-center text-white bg-danger border-0';
    toast.setAttribute('role', 'alert');
    toast.setAttribute('aria-live', 'assertive');
    toast.setAttribute('aria-atomic', 'true');
    toast.innerHTML = `
        <div class="d-flex">
            <div class="toast-body">
                ${message}
            </div>
            <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
        </div>
    `;
    document.body.appendChild(toast);
    const bsToast = new bootstrap.Toast(toast);
    bsToast.show();
    setTimeout(() => toast.remove(), 3000);
}

// Función para obtener datos del contrato
async function getContractData() {
    try {
        if (DEV_MODE) {
            // Datos de prueba para desarrollo
            return {
                baseRewardRate: '0.1',
                totalStaked: '1000',
                userStaked: '100',
                rewards: '10'
            };
        }
        
        if (!contract) return null;
        
        const baseRewardRate = await contract.baseRewardRate();
        // Agregar más llamadas al contrato según sea necesario
        
        return {
            baseRewardRate: ethers.utils.formatEther(baseRewardRate)
        };
    } catch (error) {
        console.error('Error al obtener datos del contrato:', error);
        return null;
    }
}

// Exportar funciones necesarias
window.connectWallet = connectWallet;
window.getContractData = getContractData; 