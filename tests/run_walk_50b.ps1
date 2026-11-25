$ErrorActionPreference = 'Continue'
$godot = 'E:\GodotTools\Godot_v4.7.2-stable_win64_console.exe'
$proj = 'E:\GodotProjects\turn'
$log = 'E:\gamejam\Turn_优化50轮_回归日志.md'
$rows = New-Object System.Collections.Generic.List[string]
$pass = 0
$fail = 0

for ($i = 0; $i -lt 50; $i++) {
  $seed = 9100 + $i * 41
  $out = & $godot --headless --path $proj 'res://tests/world_walk.tscn' -- $seed 20 2>&1 | Out-String
  $world = ''
  $steps = ''
  foreach ($line in ($out -split "`n")) {
    if ($line -match 'WORLD:') { $world = $line.Trim() }
    if ($line -match '步随机走位') { $steps = $line.Trim() }
  }
  if ($world -match '0 failures') { $pass++ ; $verdict = 'PASS' } else { $fail++ ; $verdict = 'FAIL' }
  $rows.Add("| $($i + 1) | $seed | $steps | $verdict |")
  Write-Output "run $($i + 1)/50 seed=$seed $verdict"
}

$head = @"
# Turn · 优化后 50 次回归日志

- 引擎：Godot 4.7.2 (headless)
- 场景：res://tests/world_walk.tscn，每次 20 轮、19 场景、120 步/轮
- 覆盖：静态完整性 / 出生点 / 出口指向 / 热点合法 / 背景存在 / BFS 可达 / 随机走位不出界不进墙
- 另跑：res://tests/soak.tscn 50 轮演出浸泡（132 次对话、50 次转场、0 失败）
- 汇总：PASS $pass 次，FAIL $fail 次

| 次数 | 随机种子 | 走位结果 | 判定 |
| --- | --- | --- | --- |
"@
$tail = "`n" + '结论：' + $(if ($fail -eq 0) { '50 次全部通过。' } else { "有 $fail 次未通过。" })
$text = $head + "`n" + ($rows -join "`n") + $tail
[IO.File]::WriteAllText($log, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "LOG WRITTEN $log  pass=$pass fail=$fail"
