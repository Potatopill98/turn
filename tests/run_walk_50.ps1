$ErrorActionPreference = 'Continue'
$godot = 'E:\GodotTools\Godot_v4.7.2-stable_win64_console.exe'
$proj = 'E:\GodotProjects\turn'
$log = 'E:\gamejam\Turn_探索模式_50次自检日志.md'
$rows = New-Object System.Collections.Generic.List[string]
$pass = 0
$fail = 0

for ($i = 0; $i -lt 50; $i++) {
  $seed = 7000 + $i * 37
  $out = & $godot --headless --path $proj 'res://tests/world_walk.tscn' -- $seed 20 2>&1 | Out-String
  $world = ''
  foreach ($line in ($out -split "`n")) {
    if ($line -match 'WORLD:') { $world = $line.Trim() }
  }
  $steps = ''
  foreach ($line in ($out -split "`n")) {
    if ($line -match '步随机走位') { $steps = $line.Trim() }
  }
  if ($world -match '0 failures') { $pass++ ; $verdict = 'PASS' } else { $fail++ ; $verdict = 'FAIL' }
  $rows.Add("| $($i + 1) | $seed | $steps | $verdict |")
  Write-Output "run $($i + 1)/50 seed=$seed $verdict"
}

$head = @"
# Turn · 探索模式 50 次自检日志

- 引擎：Godot 4.7.2 (headless)
- 测试场景：res://tests/world_walk.tscn，每次 20 轮、19 个场景、120 步/轮
- 检查项：19 场景静态完整性 / 出生点可站 / 出口指向存在 / 热点 kind 合法 / 背景图存在 / 网格 BFS 可达性 / 随机走位不出界不进墙
- 汇总：PASS $pass 次，FAIL $fail 次

| 次数 | 随机种子 | 走位结果 | 判定 |
| --- | --- | --- | --- |
"@
$tail = "`n" + '结论：' + $(if ($fail -eq 0) { '50 次全部通过，无越界、无不可达、无缺图。' } else { "有 $fail 次未通过，详见上方记录。" })
$text = $head + "`n" + ($rows -join "`n") + $tail
[IO.File]::WriteAllText($log, $text, (New-Object System.Text.UTF8Encoding($false)))
Write-Output "LOG WRITTEN $log  pass=$pass fail=$fail"
