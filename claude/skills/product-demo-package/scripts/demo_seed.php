<?php
// DEMO SEED (local only) — populate deal 16337 with REAL reconciled extractions from the
// two sample statements, and pre-warm its Centrex snapshot cache so the deal page + split
// view render instantly with no live Centrex call. Run: php artisan tinker storage/app/demo_seed.php
use App\Models\DealTracker;
use App\Support\Ai\DealClassifier;
use Illuminate\Support\Facades\Cache;

$classifier = app(DealClassifier::class);

$specs = [
    ['id' => 'demo-april-7358', 'file' => 'April 2026 Statement.pdf', 'path' => storage_path('app/samples/april-7358.pdf')],
    ['id' => 'demo-march-6674', 'file' => 'March 2026 Statement.pdf', 'path' => storage_path('app/samples/march-6674.pdf')],
];

$statements = [];
$docs = [];
$totalCredits = 0.0;
foreach ($specs as $i => $s) {
    echo "Extracting {$s['file']} …\n";
    $out = $classifier->extractLocalPdf($s['path']);
    $tx = $out['transactions'];
    $totalCredits += array_sum(array_map(fn ($t) => $t['credit'] ?? 0, $tx));
    $statements[] = [
        'doc' => $i + 1,
        'document_id' => $s['id'],
        'file' => $s['file'],
        'opening_balance' => $out['opening_balance'],
        'closing_balance' => $out['closing_balance'],
        'transactions' => $tx,
        'needs_review' => (bool) ($out['needs_review'] ?? false),
        'reconciliation_delta' => $out['quality']['reconciliation_delta'] ?? null,
    ];
    $docs[] = [
        'id' => $s['id'], 'file' => $s['file'], 'ext' => 'pdf',
        'url' => 'local://'.$s['id'], 'by' => 'Merchant Upload', 'at' => '2026-04-02', 'size' => '—',
        'doc_type' => 'bank statement',
    ];
    echo "  → ".count($tx)." rows, open ".$out['opening_balance']." close ".$out['closing_balance']." needs_review=".(($out['needs_review'] ?? false) ? 'yes' : 'no')."\n";
}

$deal = DealTracker::findOrFail(16337);
$deal->update([
    'company' => $deal->company ?: 'MCCONE & ASSOCIATES P.S',
    'industry' => 'Logistics & Freight',
    'tib_months' => 81,
    'classification' => 'Good to Go',
    'decline_reason' => null,
    'confidence' => 90,
    'real_revenue' => round($totalCredits / max(1, count($statements)), 2),
    'positions' => [
        ['funder' => 'Fora Financial', 'amount' => 250.00, 'frequency' => 'Daily'],
        ['funder' => 'Rapid Finance', 'amount' => 1200.00, 'frequency' => 'Weekly'],
    ],
    'positions_count' => 2,
    'bank_summary' => [
        'months_analyzed' => count($statements),
        'avg_daily_balance' => 42000,
        'nsf_count' => 0,
        'negative_days' => 0,
        'avg_monthly_deposits' => round($totalCredits / max(1, count($statements)), 2),
    ],
    'rule_hits' => [
        ['code' => 'TIB_OK', 'label' => 'Time in business ≥ 12 months', 'outcome' => 'pass'],
        ['code' => 'REVENUE_OK', 'label' => 'Monthly revenue above minimum', 'outcome' => 'pass'],
        ['code' => 'NSF_CLEAN', 'label' => 'No NSF / negative days', 'outcome' => 'pass'],
    ],
    'analysis_transactions' => $statements,
    'analysis_status' => 'done',
    'analysis_error' => null,
    'analysis_issues' => collect($statements)->filter(fn ($s) => $s['needs_review'])
        ->map(fn ($s) => ['file' => $s['file'], 'status' => 'unreconciled', 'detail' => "extracted figures don't reconcile — off by $".number_format(abs((float) $s['reconciliation_delta']), 2).'; verify against the statement'])
        ->values()->all(),
]);

// Pre-warm the Centrex snapshot cache so the deal page + document proxy never call Centrex.
$cid = (string) $deal->centrex_id;
Cache::put("centrex_snapshot_{$cid}", [
    'ok' => true,
    'customs' => [
        ['label' => 'Industry Type', 'value' => 'Logistics & Freight'],
        ['label' => 'Business Start Date', 'value' => '2019-03-01'],
        ['label' => 'DBA', 'value' => 'McCone & Associates'],
    ],
    'documents' => $docs,
    'notes' => [],
    'history' => [],
    'advance' => null,
], now()->addHours(3));

echo "\nSeeded deal 16337 (centrex_id={$cid}) with ".count($statements)." statements; snapshot cache warmed.\n";
