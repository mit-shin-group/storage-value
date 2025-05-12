$m_values = @("no_exports", "peak_shaving")
$g_values = @(74.0, 36.0)
$s_values = 16..19
# $s_values = @(20.0, 25.0, 50.0, 100.0)

foreach ($m in $m_values) {
    foreach ($g in $g_values) {
        foreach ($s in $s_values) {
            Write-Host "Running: julia julia --threads 8 --project=. code/06_run_ops.jl -d code/06_dates.txt -m $m -g $g -s $s"
            julia --threads 8 --project=. code/06_run_ops.jl -d code/06_dates.txt -m $m -g $g -s $s
        }
    }
}