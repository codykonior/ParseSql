foreach ($file in (Get-ChildItem .\TestScripts\*.sql)) {
    Describe $file {
        It "does not throw an error" {
            { Split-SqlScript -File $file } | Should -Not -Throw
        }

        It "returns a result set" {
            Split-SqlScript -File $file | Should -Not -BeNullOrEmpty
        }

        It "returns more than zero batches" {
            Split-SqlScript -File $file | ForEach-Object NumberOfBatches | Should -BeGreaterThan 0
        }
    }
}