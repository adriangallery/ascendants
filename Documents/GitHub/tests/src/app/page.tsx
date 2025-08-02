'use client';

import { motion } from 'framer-motion';
import RoadmapItem from '@/components/RoadmapItem';
import { 
  Rocket, 
  Users, 
  Zap, 
  Star, 
  Globe, 
  Shield, 
  Trophy, 
  Gift,
  ExternalLink,
  Coins,
  Gamepad2,
  Palette
} from 'lucide-react';

const roadmapData = [
  {
    date: "Q1 2024",
    title: "🚀 Lanzamiento Genesis",
    description: "Inicio del proyecto $ADRIAN con el lanzamiento de la colección Genesis NFT. 1,000 tokens únicos con metadatos generativos y utilidades exclusivas.",
    icon: <Rocket className="w-8 h-8 text-black" />,
    position: 'left' as const,
    assets: [
      {
        type: 'nft' as const,
        label: 'Mint Genesis',
        url: '#',
        icon: <Coins className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q2 2024",
    title: "👥 Comunidad & Staking",
    description: "Implementación del sistema de staking y recompensas para holders. Desarrollo de la DAO y gobernanza comunitaria.",
    icon: <Users className="w-8 h-8 text-black" />,
    position: 'right' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'Stake $ADRIAN',
        url: '#',
        icon: <Zap className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q3 2024",
    title: "⚡ Plataforma DeFi",
    description: "Lanzamiento de la plataforma DeFi con yield farming, liquidity pools y herramientas de trading avanzadas.",
    icon: <Zap className="w-8 h-8 text-black" />,
    position: 'left' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'DeFi Platform',
        url: '#',
        icon: <ExternalLink className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q4 2024",
    title: "🎮 Metaverso & Gaming",
    description: "Desarrollo del ecosistema gaming con integración de NFTs en juegos, marketplace de assets y experiencias inmersivas.",
    icon: <Gamepad2 className="w-8 h-8 text-black" />,
    position: 'right' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'Gaming Hub',
        url: '#',
        icon: <Gamepad2 className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q1 2025",
    title: "🌐 Expansión Global",
    description: "Expansión a múltiples blockchains, partnerships estratégicos y lanzamiento de productos cross-chain.",
    icon: <Globe className="w-8 h-8 text-black" />,
    position: 'left' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'Partnerships',
        url: '#',
        icon: <ExternalLink className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q2 2025",
    title: "🛡️ Seguridad & Escalabilidad",
    description: "Implementación de auditorías de seguridad, optimización de smart contracts y mejora de la infraestructura.",
    icon: <Shield className="w-8 h-8 text-black" />,
    position: 'right' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'Audit Report',
        url: '#',
        icon: <Shield className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q3 2025",
    title: "🏆 Ecosistema Completo",
    description: "Lanzamiento del ecosistema completo con todas las funcionalidades integradas: DeFi, Gaming, NFT Marketplace y más.",
    icon: <Trophy className="w-8 h-8 text-black" />,
    position: 'left' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'Ecosystem',
        url: '#',
        icon: <Trophy className="w-4 h-4" />
      }
    ]
  },
  {
    date: "Q4 2025",
    title: "🎨 Innovación & Futuro",
    description: "Exploración de nuevas tecnologías: AI, VR, y desarrollo de productos revolucionarios para el futuro del Web3.",
    icon: <Palette className="w-8 h-8 text-black" />,
    position: 'right' as const,
    assets: [
      {
        type: 'link' as const,
        label: 'Innovation Lab',
        url: '#',
        icon: <Star className="w-4 h-4" />
      }
    ]
  }
];

export default function Home() {
  return (
    <div className="min-h-screen bg-dark-bg relative overflow-hidden">
      {/* Scan Line Effect */}
      <div className="scan-line" />
      
      {/* Header */}
      <motion.header 
        className="relative z-10 py-8 px-4 text-center"
        initial={{ opacity: 0, y: -50 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8 }}
      >
        <motion.h1 
          className="text-6xl md:text-8xl font-pixel neon-text mb-4"
          animate={{ 
            textShadow: [
              "0 0 10px #00ff99, 0 0 20px #00ff99, 0 0 30px #00ff99",
              "0 0 20px #00ff99, 0 0 30px #00ff99, 0 0 40px #00ff99",
              "0 0 10px #00ff99, 0 0 20px #00ff99, 0 0 30px #00ff99"
            ]
          }}
          transition={{ duration: 2, repeat: Infinity }}
        >
          $ADRIAN
        </motion.h1>
        <motion.p 
          className="text-xl md:text-2xl font-share-tech text-neon-cyan mb-8"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
        >
          Roadmap del Futuro Digital
        </motion.p>
        
        {/* Stats */}
        <motion.div 
          className="flex justify-center gap-8 mb-12"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.7 }}
        >
          <div className="text-center">
            <div className="text-3xl font-orbitron text-neon-green">1,000</div>
            <div className="text-sm text-neon-cyan">Genesis NFTs</div>
          </div>
          <div className="text-center">
            <div className="text-3xl font-orbitron text-neon-green">8</div>
            <div className="text-sm text-neon-cyan">Fases</div>
          </div>
          <div className="text-center">
            <div className="text-3xl font-orbitron text-neon-green">∞</div>
            <div className="text-sm text-neon-cyan">Posibilidades</div>
          </div>
        </motion.div>
      </motion.header>

      {/* Timeline Container */}
      <div className="timeline-container relative">
        {/* Central Timeline Line */}
        <div className="timeline-line" />
        
        {/* Roadmap Items */}
        <div className="relative z-10">
          {roadmapData.map((item, index) => (
            <RoadmapItem
              key={index}
              date={item.date}
              title={item.title}
              description={item.description}
              icon={item.icon}
              position={item.position}
              index={index}
              assets={item.assets}
            />
          ))}
        </div>
      </div>

      {/* Footer with Claimables */}
      <motion.footer 
        className="relative z-10 py-16 px-4 text-center"
        initial={{ opacity: 0 }}
        whileInView={{ opacity: 1 }}
        viewport={{ once: true }}
        transition={{ duration: 0.8 }}
      >
        <motion.h2 
          className="text-4xl md:text-5xl font-orbitron neon-text mb-8"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.2 }}
        >
          🎁 Claimables Package
        </motion.h2>
        
        <motion.div 
          className="grid grid-cols-2 md:grid-cols-4 gap-6 max-w-4xl mx-auto"
          initial={{ opacity: 0, y: 20 }}
          whileInView={{ opacity: 1, y: 0 }}
          viewport={{ once: true }}
          transition={{ delay: 0.4 }}
        >
          {[
            { icon: <Gift className="w-8 h-8" />, label: "Rewards", desc: "Recompensas exclusivas" },
            { icon: <Coins className="w-8 h-8" />, label: "Tokens", desc: "Tokens de utilidad" },
            { icon: <Gamepad2 className="w-8 h-8" />, label: "Gaming", desc: "Assets de juego" },
            { icon: <Star className="w-8 h-8" />, label: "VIP", desc: "Acceso VIP" }
          ].map((item, index) => (
            <motion.div
              key={index}
              className="bg-black/50 border border-neon-green rounded-lg p-6 hover:bg-black/70 transition-all duration-300"
              whileHover={{ scale: 1.05, boxShadow: "0 0 20px #00ff99" }}
              initial={{ opacity: 0, scale: 0.8 }}
              whileInView={{ opacity: 1, scale: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.6 + index * 0.1 }}
            >
              <div className="text-neon-green mb-3 flex justify-center">
                {item.icon}
              </div>
              <h3 className="font-orbitron text-neon-green text-lg mb-2">{item.label}</h3>
              <p className="text-sm text-neon-cyan">{item.desc}</p>
            </motion.div>
          ))}
        </motion.div>
        
        <motion.div 
          className="mt-12 text-neon-cyan font-share-tech"
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          transition={{ delay: 0.8 }}
        >
          <p>El futuro es digital. El futuro es $ADRIAN.</p>
          <p className="text-sm mt-2">© 2024 $ADRIAN Project. Todos los derechos reservados.</p>
        </motion.div>
      </motion.footer>
    </div>
  );
} 