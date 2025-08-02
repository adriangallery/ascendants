'use client';

import { motion } from 'framer-motion';
import { ReactNode } from 'react';

interface RoadmapItemProps {
  date: string;
  title: string;
  description: string;
  icon?: ReactNode;
  position: 'left' | 'right';
  index: number;
  assets?: {
    type: 'nft' | 'link' | 'button';
    label: string;
    url?: string;
    icon?: ReactNode;
  }[];
}

export default function RoadmapItem({
  date,
  title,
  description,
  icon,
  position,
  index,
  assets = []
}: RoadmapItemProps) {
  const isEven = index % 2 === 0;
  const autoPosition = isEven ? 'left' : 'right';
  const finalPosition = position || autoPosition;

  return (
    <motion.div
      className={`roadmap-item ${finalPosition}`}
      initial={{ opacity: 0, y: 50 }}
      whileInView={{ opacity: 1, y: 0 }}
      viewport={{ once: true, margin: "-100px" }}
      transition={{ duration: 0.6, delay: index * 0.1 }}
    >
      {/* Timeline Node */}
      <div className="timeline-node" />
      
      {/* Content Container */}
      <motion.div
        className="roadmap-content"
        whileHover={{ scale: 1.02 }}
        transition={{ duration: 0.3 }}
      >
        {/* Icon */}
        {icon && (
          <motion.div
            className="roadmap-icon"
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.2, type: "spring", stiffness: 200 }}
          >
            {icon}
          </motion.div>
        )}

        {/* Date */}
        <motion.div
          className="roadmap-date"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.3 }}
        >
          {date}
        </motion.div>

        {/* Title */}
        <motion.h3
          className="roadmap-title neon-text"
          initial={{ opacity: 0, x: finalPosition === 'left' ? -20 : 20 }}
          animate={{ opacity: 1, x: 0 }}
          transition={{ delay: 0.4 }}
        >
          {title}
        </motion.h3>

        {/* Description */}
        <motion.p
          className="roadmap-description"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.5 }}
        >
          {description}
        </motion.p>

        {/* Optional Assets */}
        {assets.length > 0 && (
          <motion.div
            className="mt-4 flex flex-wrap gap-2"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
          >
            {assets.map((asset, assetIndex) => (
              <motion.div
                key={assetIndex}
                className="inline-flex items-center gap-2 px-3 py-1 bg-black/50 border border-neon-green rounded-md text-sm"
                whileHover={{ scale: 1.05, boxShadow: "0 0 10px #00ff99" }}
                transition={{ duration: 0.2 }}
              >
                {asset.icon && <span className="text-neon-green">{asset.icon}</span>}
                {asset.url ? (
                  <a
                    href={asset.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="text-neon-cyan hover:text-neon-yellow transition-colors"
                  >
                    {asset.label}
                  </a>
                ) : (
                  <span className="text-neon-cyan">{asset.label}</span>
                )}
              </motion.div>
            ))}
          </motion.div>
        )}
      </motion.div>
    </motion.div>
  );
} 