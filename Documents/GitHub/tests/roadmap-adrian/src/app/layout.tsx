import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "$ADRIAN - Roadmap del Futuro Digital",
  description: "Roadmap cyber-retro del proyecto $ADRIAN con timeline interactivo y animaciones futuristas",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body className="antialiased">
        {children}
      </body>
    </html>
  );
}
