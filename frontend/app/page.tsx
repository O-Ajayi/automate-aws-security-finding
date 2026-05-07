const cards = [
  { title: "Findings", value: "1,248", subtitle: "Open vulnerabilities" },
  { title: "Needs Approval", value: "84", subtitle: "Awaiting reviewer action" },
  { title: "In Progress", value: "41", subtitle: "Active remediations" },
  { title: "SLA Breaches", value: "7", subtitle: "Action required" }
];

export default function DashboardPage() {
  return (
    <main className="min-h-screen bg-slate-950 text-slate-50 p-8">
      <h1 className="text-3xl font-bold mb-6">AI-Assisted Remediation Dashboard</h1>
      <section className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        {cards.map((card) => (
          <article key={card.title} className="rounded-lg border border-slate-800 p-4 bg-slate-900">
            <p className="text-slate-400 text-sm">{card.title}</p>
            <p className="text-2xl font-semibold">{card.value}</p>
            <p className="text-xs text-slate-500">{card.subtitle}</p>
          </article>
        ))}
      </section>
      <section className="rounded-lg border border-slate-800 p-4 bg-slate-900">
        <h2 className="text-xl font-semibold mb-3">Operational Views</h2>
        <ul className="space-y-2 text-slate-300">
          <li>Findings list with filter, search, severity chips, and pagination</li>
          <li>Remediation review queue with approval/rejection actions</li>
          <li>Execution timeline with verification status and rollback outcomes</li>
          <li>Reporting exports (CSV/PDF/Excel) and SLA analytics</li>
        </ul>
      </section>
    </main>
  );
}
