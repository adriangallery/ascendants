# 🚀 $ADRIAN Roadmap Landing Page

Una landing page moderna y futurista para mostrar el roadmap del proyecto $ADRIAN con estilo cyber-retro y animaciones fluidas.

## ✨ Características

- **🎨 Diseño Cyber-Retro**: Estética futurista con colores neon verde y efectos de rejilla
- **📱 Responsive**: Optimizado para todos los dispositivos
- **⚡ Animaciones Fluidas**: Usando Framer Motion para transiciones suaves
- **🎯 Componentes Modulares**: Estructura reutilizable y fácil de mantener
- **🌐 Fuentes Pixel Art**: Tipografía VT323, Orbitron y Share Tech Mono
- **🎮 Efectos Visuales**: Glow effects, scan lines y animaciones de scroll
- **📊 Timeline Interactivo**: Línea temporal vertical con nodos animados

## 🛠️ Tecnologías Utilizadas

- **Next.js 14** - Framework de React
- **TypeScript** - Tipado estático
- **Tailwind CSS** - Framework de estilos
- **Framer Motion** - Animaciones
- **Lucide React** - Iconos

## 🚀 Instalación

1. **Clona el repositorio**
```bash
git clone <tu-repositorio>
cd roadmap-adrian
```

2. **Instala las dependencias**
```bash
npm install
```

3. **Ejecuta el servidor de desarrollo**
```bash
npm run dev
```

4. **Abre tu navegador**
```
http://localhost:3000
```

## 📁 Estructura del Proyecto

```
src/
├── app/
│   ├── globals.css          # Estilos globales y animaciones
│   ├── layout.tsx           # Layout principal
│   └── page.tsx             # Página principal del roadmap
├── components/
│   └── RoadmapItem.tsx      # Componente reutilizable de roadmap
└── types/                   # Tipos TypeScript (si es necesario)
```

## 🎯 Uso del Componente RoadmapItem

El componente `RoadmapItem` es completamente reutilizable y acepta las siguientes props:

```tsx
<RoadmapItem
  date="Q1 2024"
  title="🚀 Lanzamiento Genesis"
  description="Descripción del hito..."
  icon={<Rocket className="w-8 h-8 text-black" />}
  position="left" // o "right"
  index={0}
  assets={[
    {
      type: 'nft',
      label: 'Mint Genesis',
      url: '#',
      icon: <Coins className="w-4 h-4" />
    }
  ]}
/>
```

### Props Disponibles

- **`date`**: Fecha o período del hito
- **`title`**: Título del hito (puede incluir emojis)
- **`description`**: Descripción detallada
- **`icon`**: Icono representativo (ReactNode)
- **`position`**: Posición en la timeline ('left' | 'right')
- **`index`**: Índice para animaciones secuenciales
- **`assets`**: Array opcional de assets (NFTs, links, botones)

## 🎨 Personalización

### Colores Neon
Los colores principales están definidos en `globals.css`:

```css
:root {
  --neon-green: #00ff99;
  --neon-cyan: #00ffff;
  --neon-yellow: #ffff00;
  --dark-bg: #0a0a0a;
}
```

### Fuentes
Las fuentes pixel art están configuradas en `tailwind.config.ts`:

- `font-pixel`: VT323 (monospace)
- `font-orbitron`: Orbitron (sans-serif)
- `font-share-tech`: Share Tech Mono (monospace)

### Animaciones
Las animaciones personalizadas incluyen:

- `glow`: Efecto de brillo pulsante
- `glitch`: Efecto de glitch
- `scan`: Línea de escaneo
- `fade-in`: Aparición suave
- `scale-in`: Escalado con aparición

## 📱 Responsive Design

El diseño es completamente responsive con breakpoints optimizados:

- **Mobile**: Timeline a la izquierda, elementos apilados
- **Tablet**: Layout adaptativo
- **Desktop**: Timeline central con elementos alternados

## 🎮 Efectos Interactivos

- **Hover Effects**: Escalado y glow en elementos
- **Scroll Animations**: Aparición progresiva al hacer scroll
- **Timeline Nodes**: Nodos brillantes en la línea temporal
- **Scan Line**: Línea de escaneo animada
- **Grid Background**: Rejilla neon animada

## 🚀 Deploy

### Vercel (Recomendado)
```bash
npm run build
vercel --prod
```

### Netlify
```bash
npm run build
# Subir la carpeta .next a Netlify
```

## 📝 Roadmap Data

Los datos del roadmap están definidos en `page.tsx`. Puedes modificar el array `roadmapData` para actualizar:

- Fechas y períodos
- Títulos y descripciones
- Iconos y assets
- Posiciones en la timeline

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 🎯 Roadmap del Proyecto $ADRIAN

El roadmap incluye 8 fases principales:

1. **Q1 2024**: Lanzamiento Genesis NFT
2. **Q2 2024**: Comunidad & Staking
3. **Q3 2024**: Plataforma DeFi
4. **Q4 2024**: Metaverso & Gaming
5. **Q1 2025**: Expansión Global
6. **Q2 2025**: Seguridad & Escalabilidad
7. **Q3 2025**: Ecosistema Completo
8. **Q4 2025**: Innovación & Futuro

---

**El futuro es digital. El futuro es $ADRIAN.** 🚀 