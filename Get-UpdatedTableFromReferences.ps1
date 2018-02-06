function Get-UpdatedTableFromReferences($TableReference) {
    Write-Verbose "Looks like a joined DML statement, need to get into the references..."
    if ($TableReference.FirstTableReference) {
        Get-UpdatedTableFromReferences $TableReference.FirstTableReference
    } else {
        Write-Verbose "closing recursion..."
        Return $TableReference.SchemaObject
    }
}
