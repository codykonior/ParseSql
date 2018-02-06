foreach ($file in (Get-ChildItem .\TestScripts\*.sql)) {
    Describe $file {
        It "does not throw an error" {
            { Split-SqlScript $file } | Should -Not -Throw
        }

        It "returns a result set" {
            Split-SqlScript $file | Should -Not -BeNullOrEmpty
        }

        It "returns more than zero batches" {
            Split-SqlScript $file | ForEach-Object NumberOfBatches | Should -BeGreaterThan 0
        }
    }
}