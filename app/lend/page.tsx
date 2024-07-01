import BondRequest from '../components/bondRequest';

export default function Home() {
  return (
    <main className="flex flex-col w-screen h-screen p-5 dark:bg-slate-900">
      <h1 className="text-3xl dark:text-white mb-2">lend</h1>
      <div className="h-0 border border-sky-500"></div>
      <div className="flex-grow overflow-auto min-h-max">
        <BondRequest />
      </div>
    </main>
  );
}
