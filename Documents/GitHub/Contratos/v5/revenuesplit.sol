// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
}

/// @title RevenueSplit
/// @notice Contrato para repartir ingresos (ETH y ERC20) a partes iguales entre artista y dev
/// Cualquiera de los dos puede activar el reparto y automáticamente recibe 50% y envía 50% al otro
contract RevenueSplit {
    
    address public artist;
    address public dev;
    bool public contractRenounced = false;
    
    // Eventos
    event ETHDistributed(address indexed initiator, uint256 artistAmount, uint256 devAmount);
    event TokenDistributed(address indexed token, address indexed initiator, uint256 artistAmount, uint256 devAmount);
    event ETHReceived(address indexed sender, uint256 amount);
    event ArtistChanged(address indexed oldArtist, address indexed newArtist);
    event DevChanged(address indexed oldDev, address indexed newDev);
    event RoleRenounced(address indexed renouncer, string role);
    event ContractRenounced(address indexed renouncer);

    // Modificadores
    modifier onlyAuthorized() {
        require(
            (msg.sender == artist && artist != address(0)) || 
            (msg.sender == dev && dev != address(0)), 
            "Not authorized"
        );
        _;
    }
    
    constructor(address _artist, address _dev) {
        require(_artist != address(0) && _dev != address(0), "Invalid addresses");
        require(_artist != _dev, "Artist and dev must be different");
        artist = _artist;
        dev = _dev;
    }
    
    /// @notice Permite cambiar la dirección del artista (solo el artista actual puede hacerlo)
    function setArtist(address newArtist) external {
        require(!contractRenounced, "Contract has been renounced");
        require(msg.sender == artist, "Only current artist");
        require(newArtist != address(0), "Invalid address");
        require(newArtist != dev, "Cannot be same as dev");
        address oldArtist = artist;
        artist = newArtist;
        emit ArtistChanged(oldArtist, newArtist);
    }
    
    /// @notice Permite cambiar la dirección del dev (solo el dev actual puede hacerlo)
    function setDev(address newDev) external {
        require(!contractRenounced, "Contract has been renounced");
        require(msg.sender == dev, "Only current dev");
        require(newDev != address(0), "Invalid address");
        require(newDev != artist, "Cannot be same as artist");
        address oldDev = dev;
        dev = newDev;
        emit DevChanged(oldDev, newDev);
    }
    
    /// @notice Renuncia al contrato haciendo las direcciones inmutables permanentemente
    /// Cualquiera de los dos (artist o dev) puede activar esto
    /// CUIDADO: Esta acción es IRREVERSIBLE
    function renounceContract() external onlyAuthorized {
        require(!contractRenounced, "Contract already renounced");
        contractRenounced = true;
        emit ContractRenounced(msg.sender);
    }
    
    /// @notice Permite al artista renunciar a su rol (se establece a address(0))
    /// CUIDADO: Esto hace que los fondos solo puedan ser retirados por el dev
    function renounceArtist() external {
        require(msg.sender == artist, "Only current artist");
        artist = address(0);
        emit RoleRenounced(msg.sender, "artist");
    }
    
    /// @notice Permite al dev renunciar a su rol (se establece a address(0))
    /// CUIDADO: Esto hace que los fondos solo puedan ser retirados por el artista
    function renounceDev() external {
        require(msg.sender == dev, "Only current dev");
        dev = address(0);
        emit RoleRenounced(msg.sender, "dev");
    }
    
    /// @notice Función para recibir ETH
    receive() external payable {
        emit ETHReceived(msg.sender, msg.value);
    }
    
    /// @notice Retira y distribuye todo el ETH del contrato 50/50
    /// El que llama recibe su parte inmediatamente, la otra se envía al compañero
    /// Si una parte ha renunciado, todo va al que no renunció
    function withdrawETH() external onlyAuthorized {
        uint256 balance = address(this).balance;
        require(balance > 0, "No ETH available");
        
        // Si una parte renunció, todo va al que no renunció
        if (artist == address(0) || dev == address(0)) {
            (bool success, ) = payable(msg.sender).call{value: balance}("");
            require(success, "Transfer failed");
            
            if (msg.sender == artist) {
                emit ETHDistributed(msg.sender, balance, 0);
            } else {
                emit ETHDistributed(msg.sender, 0, balance);
            }
            return;
        }
        
        // Reparto normal 50/50
        uint256 halfAmount = balance / 2;
        uint256 remainingAmount = balance - halfAmount; // Por si hay remainder por división impar
        
        address recipient = (msg.sender == artist) ? dev : artist;
        
        // Enviar al compañero primero (más seguro)
        (bool successRecipient, ) = payable(recipient).call{value: halfAmount}("");
        require(successRecipient, "Transfer to recipient failed");
        
        // Enviar al que inició
        (bool successInitiator, ) = payable(msg.sender).call{value: remainingAmount}("");
        require(successInitiator, "Transfer to initiator failed");
        
        if (msg.sender == artist) {
            emit ETHDistributed(msg.sender, remainingAmount, halfAmount);
        } else {
            emit ETHDistributed(msg.sender, halfAmount, remainingAmount);
        }
    }
    
    /// @notice Retira y distribuye todos los tokens ERC20 del contrato 50/50
    /// @param tokenAddress Dirección del token ERC20 a distribuir
    /// Si una parte ha renunciado, todo va al que no renunció
    function withdrawToken(address tokenAddress) external onlyAuthorized {
        IERC20 token = IERC20(tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens available");
        
        // Si una parte renunció, todo va al que no renunció
        if (artist == address(0) || dev == address(0)) {
            require(token.transfer(msg.sender, balance), "Transfer failed");
            
            if (msg.sender == artist) {
                emit TokenDistributed(tokenAddress, msg.sender, balance, 0);
            } else {
                emit TokenDistributed(tokenAddress, msg.sender, 0, balance);
            }
            return;
        }
        
        // Reparto normal 50/50
        uint256 halfAmount = balance / 2;
        uint256 remainingAmount = balance - halfAmount; // Por si hay remainder por división impar
        
        address recipient = (msg.sender == artist) ? dev : artist;
        
        // Enviar al compañero
        require(token.transfer(recipient, halfAmount), "Transfer to recipient failed");
        
        // Enviar al que inició
        require(token.transfer(msg.sender, remainingAmount), "Transfer to initiator failed");
        
        if (msg.sender == artist) {
            emit TokenDistributed(tokenAddress, msg.sender, remainingAmount, halfAmount);
        } else {
            emit TokenDistributed(tokenAddress, msg.sender, halfAmount, remainingAmount);
        }
    }
    
    /// @notice Consulta el balance de ETH del contrato
    function getETHBalance() external view returns (uint256) {
        return address(this).balance;
    }
    
    /// @notice Consulta el balance de un token ERC20 específico
    function getTokenBalance(address tokenAddress) external view returns (uint256) {
        return IERC20(tokenAddress).balanceOf(address(this));
    }
    
    /// @notice Devuelve información básica del contrato
    function getInfo() external view returns (address _artist, address _dev, uint256 ethBalance, bool _contractRenounced) {
        return (artist, dev, address(this).balance, contractRenounced);
    }
}