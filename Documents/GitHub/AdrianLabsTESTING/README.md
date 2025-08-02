# AdrianLab Renderer

Este es el renderer serverless para los NFTs de AdrianLab, implementado en Vercel.

## Características

- Renderizado dinámico de NFTs basado en traits
- Sistema de caché para optimizar el rendimiento
- Soporte para mutaciones y generaciones
- Integración con contratos ERC721 y ERC1155

## Requisitos

- Node.js 14.x o superior
- npm o yarn
- Cuenta en Vercel
- Acceso a un nodo Ethereum (para desarrollo local)

## Instalación

1. Clona el repositorio:
```bash
git clone https://github.com/tu-usuario/adrianlab-renderer.git
cd adrianlab-renderer
```

2. Instala las dependencias:
```bash
npm install
# o
yarn install
```

3. Configura las variables de entorno:
Crea un archivo `.env.local` con las siguientes variables:
```
RPC_URL=tu_url_rpc
CONTRACT_ADDRESS=dirección_del_contrato
```

## Desarrollo Local

Para ejecutar el proyecto en modo desarrollo:

```bash
npm run dev
# o
yarn dev
```

El servidor estará disponible en `http://localhost:3000`.

## Despliegue en Vercel

1. Conecta tu repositorio con Vercel
2. Configura las variables de entorno en el dashboard de Vercel
3. Despliega el proyecto

## Estructura del Proyecto

```
├── contracts/           # Contratos Solidity
├── pages/              # Páginas y endpoints de la API
├── public/             # Assets estáticos
│   └── traits/        # Imágenes de traits
├── lib/               # Funciones auxiliares
└── vercel.json        # Configuración de Vercel
```

## Uso de la API

### Renderizado de Imagen

```
GET /api/render/[tokenId]
```

### Metadata

```
GET /api/metadata/[tokenId]
```

## Contribución

1. Fork el repositorio
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## Licencia

Este proyecto está licenciado bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles. 