'use client';

import { useState } from 'react';

export default function Tooltip({ text, children }) {
  const [isVisable, setIsVisable] = useState(false);

  let tooltipContainerClass = 'relative inline-block overflow-visible';
  let tooltipClass = 'absolute block dark:bg-gray-700 dark:text-white m-2 px-2 py-1 w-max max-w-64 border-transparent rounded-md shadow-2xl z-1 top-full';

  return (
    <div className={tooltipContainerClass} onMouseEnter={() => setIsVisable(true)} onMouseLeave={() => setIsVisable(false)}>
      {children}
      {isVisable && <div className={tooltipClass}>{text}</div>}
    </div>
  );
}
