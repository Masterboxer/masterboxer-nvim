$filtered = @()
foreach ($a in $args) {
  if ($a -like '--target=*') { continue }
  $filtered += $a
}
& zig c++ --target=x86_64-windows-gnu @filtered
exit $LASTEXITCODE
