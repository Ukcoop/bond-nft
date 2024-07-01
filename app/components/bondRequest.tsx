import Tooltip from '../components/tooltip';

export default function BondRequest() {
  let itemClass = 'flex items-center h-full p-3 border border-transparent border-r-gray-500 dark:hover:bg-gray-600';
  let actionClass = 'flex justify-end items-center h-full w-full';
  let buttonClass = 'm-3 px-3 py-2 bg-sky-500 hover:bg-sky-600 active:bg-sky-700 rounded-md';
  let coinClass = 'pr-2 dark:text-white';
  let coinWidth = ' w-44';
  let percentageWidth = ' w-14';
  let timeWidth = ' w-28';
  let amountClass = 'dark:text-white';

  return (
    <>
    <div className="flex justify-between items-center h-14 min-w-max m-2 p-0 border-transparent rounded-md dark:bg-gray-700">
      <div className='flex justify-start items-center'>
        <Tooltip text="the coin used for collatral"><div className={itemClass + coinWidth}><a className={coinClass}>ETH:</a><a className={amountClass}>1.25000000</a></div></Tooltip>
        <Tooltip text="the coin being borrowed"><div className={itemClass + coinWidth}><a className={coinClass}>USDC:</a><a className={amountClass}>3000.0000</a></div></Tooltip>
        <Tooltip text="the percentage of the collatral value being borrowed"><div className={itemClass + percentageWidth}><a className={amountClass}>80%</a></div></Tooltip>
        <Tooltip text="the duration of the bond"><div className={itemClass + timeWidth}><a className={amountClass}>10 months</a></div></Tooltip>
        <Tooltip text="the intrest rate of the bond (simple intrest)"><div className={itemClass + percentageWidth}><a className={amountClass}>15%</a></div></Tooltip>
      </div>
      <div>
        <div className={actionClass}><div className={buttonClass}><a className={amountClass}>Lend</a></div></div>
      </div>
    </div>
    </>
  );
}
