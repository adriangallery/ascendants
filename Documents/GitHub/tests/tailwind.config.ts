import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      fontFamily: {
        'pixel': ['VT323', 'monospace'],
        'orbitron': ['Orbitron', 'sans-serif'],
        'share-tech': ['Share Tech Mono', 'monospace'],
      },
      colors: {
        'neon-green': '#00ff99',
        'neon-cyan': '#00ffff',
        'neon-yellow': '#ffff00',
        'dark-bg': '#0a0a0a',
        'grid-green': '#00ff99',
      },
      animation: {
        'glow': 'glow 2s ease-in-out infinite alternate',
        'glitch': 'glitch 0.3s ease-in-out infinite',
        'scan': 'scan 3s linear infinite',
        'fade-in': 'fadeIn 0.6s ease-out',
        'scale-in': 'scaleIn 0.5s ease-out',
      },
      keyframes: {
        glow: {
          '0%': { boxShadow: '0 0 5px #00ff99, 0 0 10px #00ff99, 0 0 15px #00ff99' },
          '100%': { boxShadow: '0 0 10px #00ff99, 0 0 20px #00ff99, 0 0 30px #00ff99' },
        },
        glitch: {
          '0%, 100%': { transform: 'translate(0)' },
          '20%': { transform: 'translate(-2px, 2px)' },
          '40%': { transform: 'translate(-2px, -2px)' },
          '60%': { transform: 'translate(2px, 2px)' },
          '80%': { transform: 'translate(2px, -2px)' },
        },
        scan: {
          '0%': { transform: 'translateY(-100%)' },
          '100%': { transform: 'translateY(100vh)' },
        },
        fadeIn: {
          '0%': { opacity: '0', transform: 'translateY(20px)' },
          '100%': { opacity: '1', transform: 'translateY(0)' },
        },
        scaleIn: {
          '0%': { opacity: '0', transform: 'scale(0.8)' },
          '100%': { opacity: '1', transform: 'scale(1)' },
        },
      },
    },
  },
  plugins: [],
}
export default config 