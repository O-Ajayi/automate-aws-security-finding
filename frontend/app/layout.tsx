import type { ReactNode } from "react";
import "./styles.css";

export const metadata = {
  title: "AI-Assisted Vulnerability Remediation Platform"
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
