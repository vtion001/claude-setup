// doctor-health-check — Phase 4 deep-scan Workflow (template)
//
// Adapt ROOT, the DOMAINS[].prompt bodies, and the "recent PRs already fixed" note to the
// project, then run via the Workflow tool (inline `script` or `scriptPath`). It fans out one
// finder per domain in parallel, and adversarially verifies each domain's Critical/High
// findings AS SOON AS that domain's scan completes (pipeline, no barrier). Returns the
// verified findings per domain; the main thread re-verifies the severe survivors firsthand.
//
// Pairs with SKILL.md in this directory. Runs in the background; you'll be notified on completion.

export const meta = {
  name: 'health-check-scan',
  description: 'Multi-domain operational health scan (codebase, API/auth, integrations, agents, cron)',
  phases: [{ title: 'Scan' }, { title: 'Verify' }],
}

const ROOT = '/absolute/path/to/PROJECT_ROOT' // <-- set to the project's absolute cwd before running

const RULES = `
PROJECT_ROOT = ${ROOT}. Operate ONLY within it.
NEVER scan node_modules/, .git/, .next/, dist/, build/, vendor/, test-results/, output/.
You MAY read (never modify) ops config: .claude/agents/, .claude/cron/, alto-os/, scripts/.
This is a HEALTH CHECK of CURRENT operational state — not a fresh security audit.
[ADAPT] Recent merged PRs already fixed: <list them>. Do NOT re-report those as new — only
flag them if they REGRESSED or were done incompletely, with file:line proof.
DATA INTEGRITY (hard rule): report a finding ONLY if you verified it directly by reading the
file. Every finding MUST cite file:line and quote the offending code. No speculation. If you
cannot verify, omit it. Prefer precision over volume. score 0-100 = current domain health.
`

const FINDING_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['domain', 'score', 'summary', 'findings'],
  properties: {
    domain: { type: 'string' },
    score: { type: 'number' },
    summary: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object', additionalProperties: false,
        required: ['severity', 'title', 'location', 'evidence', 'remediation'],
        properties: {
          severity: { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low', 'Info'] },
          title: { type: 'string' },
          location: { type: 'string' },
          evidence: { type: 'string' },
          remediation: { type: 'string' },
        },
      },
    },
  },
}

const VERDICT_SCHEMA = {
  type: 'object', additionalProperties: false,
  required: ['confirmed', 'reason', 'severity'],
  properties: {
    confirmed: { type: 'boolean' },
    reason: { type: 'string' },
    severity: { type: 'string', enum: ['Critical', 'High', 'Medium', 'Low', 'Info'] },
  },
}

const DOMAINS = [
  {
    key: 'codebase',
    prompt: `${RULES}
DOMAIN = codebase. Scan app/ (non-API), lib/, components/, hooks/, middleware for CURRENT-health
issues: latent bugs / logic errors, unhandled promise rejections, missing error handling on
external calls, null/undefined hazards, obvious dead code, React hook misuse, hydration risks,
and TODO/FIXME/HACK that flag a real gap. Read the actual files; cite file:line and quote code.`,
  },
  {
    key: 'api-backend',
    prompt: `${RULES}
DOMAIN = api-backend. Focus on auth-guard CONSISTENCY and data exposure across every route
handler. If middleware only gates mutating methods, sensitive GET routes rely on a handler-level
auth guard — flag ANY sensitive GET that returns DB data / mints privileged tokens with NO guard
(the classic "incomplete sweep" where siblings were fixed but this one was missed; find the
guarded sibling as proof). Also: service-role client leaking to the client, missing input
validation on POST/PUT bodies, handlers that swallow errors and 200 on failure, cron-secret
verification. Read handlers directly; cite file:line.`,
  },
  {
    key: 'integrations',
    prompt: `${RULES}
DOMAIN = integrations. For EACH integration (payments, CRM, telephony, email/OAuth, analytics,
storage, AI), read its lib module + route(s) and report a status (configured & code-healthy /
degraded / broken) with file:line evidence. Flag: hardcoded secrets, missing env guards that
would 500 at runtime, fail-open webhook verification, an intentionally-public webhook whose input
reaches a credentialed fetch (SSRF/credential-leak), wrong/legacy IDs, broken OAuth redirect URIs
(e.g. relative NextResponse.redirect under Next 15.5). Cite file:line.`,
  },
  {
    key: 'agents',
    prompt: `${RULES}
DOMAIN = agents. Read every .claude/agents/*.md. For each: is the frontmatter valid (name,
description, tools)? Do referenced scripts/paths/endpoints actually exist on disk (Glob/Read to
confirm)? Does the tools grant include what the agent's core function needs (e.g. an agent whose
whole job is an MCP but whose tools: omits mcp__<server>__*)? Flag missing files, deprecated
endpoints, stale paths, insufficient tool grants. Cite the agent file + the broken reference.`,
  },
  {
    key: 'cron-scheduling',
    prompt: `${RULES}
DOMAIN = cron-scheduling. Reconcile the layers and report drift: (1) launchd plists /
~/Library/LaunchAgents + any wrapper script, (2) the schedule/operations registry, (3) the real
endpoints/scripts they invoke. READ THE LOGS — a non-zero launchctl exit is a lead; open the log
to find why (e.g. macOS TCC/Full-Disk-Access EPERM reading a protected path, a misrouted
operation, a git-checkout failure). Does every scheduled id map to a real target? Any plist
pointing at a missing script? Is the failure path silent (no alert)? Cite file/log paths.`,
  },
]

phase('Scan')
const results = await pipeline(
  DOMAINS,
  d => agent(d.prompt, { label: `scan:${d.key}`, phase: 'Scan', schema: FINDING_SCHEMA }),
  (res, d) => {
    if (!res || !res.findings) return res
    const hi = res.findings.filter(f => f.severity === 'Critical' || f.severity === 'High')
    if (!hi.length) return res
    return parallel(hi.map(f => () =>
      agent(`${RULES}
Adversarially VERIFY this ${res.domain} finding. Open the cited location yourself. Is it REAL and
current (not already fixed, not a false positive)? Default to confirmed=false if the evidence
doesn't hold up when you read the file.
TITLE: ${f.title}
LOCATION: ${f.location}
EVIDENCE: ${f.evidence}`,
        { label: `verify:${d.key}`, phase: 'Verify', schema: VERDICT_SCHEMA })
        .then(v => ({ ...f, verified: v.confirmed, verifyReason: v.reason, severity: v.severity || f.severity }))
        .catch(() => ({ ...f, verified: null }))
    )).then(verifiedHi => {
      const lo = res.findings.filter(f => f.severity !== 'Critical' && f.severity !== 'High')
      return { ...res, findings: [...verifiedHi, ...lo] }
    })
  }
)

return results.filter(Boolean)
