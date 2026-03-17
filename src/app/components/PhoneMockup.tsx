import { ReactNode } from 'react';

interface PhoneMockupProps {
  children: ReactNode;
}

export function PhoneMockup({ children }: PhoneMockupProps) {
  return (
    <div className="min-h-screen bg-gradient-to-br from-black via-red-950 to-black flex items-center justify-center p-4 md:p-8">
      {/* Phone Frame */}
      <div className="relative">
        {/* Phone Shadow */}
        <div className="absolute inset-0 bg-black/40 blur-3xl transform translate-y-8 scale-95 rounded-[3.5rem]" />
        
        {/* Phone Container */}
        <div className="relative bg-slate-950 rounded-[3.5rem] p-3 shadow-2xl">
          {/* Phone Bezel */}
          <div className="bg-black rounded-[3rem] p-2 shadow-inner">
            {/* Screen */}
            <div className="relative bg-white rounded-[2.5rem] overflow-hidden w-[380px] h-[780px] shadow-xl">
              {/* Dynamic Island / Notch */}
              <div className="absolute top-0 left-1/2 -translate-x-1/2 z-50">
                <div className="bg-black rounded-b-3xl h-8 w-32 flex items-center justify-center gap-2">
                  {/* Camera */}
                  <div className="w-2 h-2 bg-slate-800 rounded-full" />
                  {/* Speaker */}
                  <div className="w-16 h-1.5 bg-slate-900 rounded-full" />
                </div>
              </div>
              
              {/* App Content */}
              <div className="h-full w-full overflow-y-auto">
                {children}
              </div>
            </div>
          </div>
          
          {/* Side Buttons */}
          <div className="absolute -left-1 top-24 w-1 h-8 bg-slate-800 rounded-l" />
          <div className="absolute -left-1 top-36 w-1 h-14 bg-slate-800 rounded-l" />
          <div className="absolute -left-1 top-52 w-1 h-14 bg-slate-800 rounded-l" />
          <div className="absolute -right-1 top-36 w-1 h-20 bg-slate-800 rounded-r" />
        </div>

        {/* Reflection Effect */}
        <div className="absolute inset-0 bg-gradient-to-br from-white/10 via-transparent to-transparent rounded-[3.5rem] pointer-events-none" />
      </div>
    </div>
  );
}