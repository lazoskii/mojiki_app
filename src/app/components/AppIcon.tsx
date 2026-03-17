interface AppIconProps {
  className?: string;
}

export function AppIcon({ className = "w-10 h-10" }: AppIconProps) {
  return (
    <svg
      viewBox="0 0 100 100"
      fill="none"
      xmlns="http://www.w3.org/2000/svg"
      className={className}
    >
      {/* Card Background */}
      <rect
        x="10"
        y="15"
        width="80"
        height="70"
        rx="8"
        fill="url(#gradient)"
        stroke="currentColor"
        strokeWidth="3"
      />
      
      {/* Japanese Character 日 (Sun/Day) - Simplified */}
      <g fill="white">
        {/* Outer Rectangle */}
        <rect x="25" y="30" width="50" height="40" rx="2" fill="white" />
        
        {/* Inner vertical line */}
        <rect x="48" y="32" width="4" height="36" fill="url(#gradient)" />
        
        {/* Top horizontal section */}
        <rect x="27" y="32" width="46" height="4" fill="url(#gradient)" />
        
        {/* Middle horizontal section */}
        <rect x="27" y="48" width="46" height="4" fill="url(#gradient)" />
        
        {/* Bottom horizontal section */}
        <rect x="27" y="64" width="46" height="4" fill="url(#gradient)" />
        
        {/* Left vertical */}
        <rect x="27" y="32" width="4" height="36" fill="url(#gradient)" />
        
        {/* Right vertical */}
        <rect x="69" y="32" width="4" height="36" fill="url(#gradient)" />
      </g>
      
      {/* Gradient Definition */}
      <defs>
        <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stopColor="#dc2626" />
          <stop offset="100%" stopColor="#000000" />
        </linearGradient>
      </defs>
    </svg>
  );
}
