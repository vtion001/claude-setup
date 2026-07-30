# Six Sigma Business MBB — Authoritative Sources

External authorities the body of knowledge is grounded in. `--refresh` re-crawls these (and
searches for newer editions) to rebuild `body-of-knowledge.md`. When citing a recommendation in
the report, reference the relevant entry here.

## Methodology & certification bodies (domain-neutral DMAIC, Lean, FMEA)
- **ASQ — Master Black Belt Body of Knowledge** — https://asq.org/cert/master-black-belt — the
  canonical MBB competency model (methodology, mentoring, statistics, strategy).
- **ASQ — Six Sigma overview & tools** — https://asq.org/quality-resources/six-sigma
- **IASSC — Lean Six Sigma Black Belt BoK** — https://iassc.org/six-sigma-certification/black-belt-certification/
- **ISO 13053-1:2011** (DMAIC methodology) & **ISO 13053-2:2011** (tools) —
  https://www.iso.org/standard/52901.html

## Statistics (capability, DPMO, control charts, DOE, MSA)
- **NIST/SEMATECH e-Handbook of Statistical Methods** — https://www.itl.nist.gov/div898/handbook/
  — process capability (§6.1), control charts (§6.3), DOE (§5), MSA/gage R&R (§2).
- **NIST — Process capability index** — https://www.itl.nist.gov/div898/handbook/pmc/section1/pmc16.htm

## Lean & operations
- **Lean Enterprise Institute — principles & VSM** — https://www.lean.org/lexicon-terms/
- **8 wastes (DOWNTIME)** — https://www.lean.org/lexicon-terms/seven-wastes/
- **McKinsey — Lean operations / operational excellence** — https://www.mckinsey.com/capabilities/operations/our-insights — adaptation of Lean to service/knowledge work.
- **HBR — Operations management canon** — https://hbr.org/topic/operations-management — for the
  cross-functional improvement framing used in the prioritization bias.

## 7 QC tools / FMEA
- **ASQ — Seven Basic Quality Tools** — https://asq.org/quality-resources/seven-basic-quality-tools
- **ASQ — FMEA** — https://asq.org/quality-resources/fmea
- **AIAG-VDA FMEA** (Severity/Occurrence/Detection scales — paywalled, encoded in
  `scoring-rubric.md`) — https://www.aiag.org/

## Customer / Voice-of-Customer / VOM
- **ASQ — VOC / CTQ** — https://asq.org/quality-resources/voice-of-customer
- **Kano model — overview** — https://asq.org/quality-resources/kano-model

## Business / SaaS metrics canon (department CTQs)
- **Bain — Net Promoter System** — https://www.netpromotersystem.com/ — NPS as a CTQ source.
- **OpenView / SaaStr — SaaS metrics canon** — public posts on CAC, LTV, NRR, GRR, Magic Number,
  CAC payback as the standard reference for SaaS-shaped Marketing/Sales/CS CTQs and targets.
- **SaaS Capital — benchmarks** — https://www.saas-capital.com/research — empirical median DSO,
  churn, gross margin by ARR tier; useful for spec-setting.

## Hand-off & sales process
- **Forrester / SiriusDecisions — Waterfall / Demand Waterfall** — pipeline-stage definitions
  (lead, MQL, SAL, SQL, opp) referenced as the canonical SIPOC for the Marketing→Sales handoff.
- **MEDDIC / Command-of-the-Message** — stage-gate exit-criteria standard used in many enterprise
  sales orgs, referenced for `poka-yoke` recommendations.

## Operational excellence in non-manufacturing
- **Lean Healthcare** — https://www.ihi.org/ — adaptation of Lean to service / non-manufacturing
  contexts is largely encoded in healthcare improvement literature; relevant patterns for support
  and operations.

> Note: paywalled standards (ISO, AIAG) and frameworks (MEDDIC, SiriusDecisions Waterfall) are
> cited for authority; the skill encodes their public concepts in `body-of-knowledge.md` and
> `business-mapping.md`. On `--refresh`, prefer the freely-readable NIST handbook, ASQ resources,
> Lean Enterprise Institute, and SaaS-metrics public posts for current figures.
