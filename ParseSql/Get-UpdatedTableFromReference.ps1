function Get-UpdatedTableFromReference($TableReference) {
    Write-Verbose "Looks like a joined DML statement, need to get into the references..."
    if ($TableReference.psobject.Properties["FirstTableReference"] -and $TableReference.FirstTableReference) {
        Get-UpdatedTableFromReference $TableReference.FirstTableReference
    } else {
        Write-Verbose "closing recursion..."
        Return $TableReference.SchemaObject
    }
}
