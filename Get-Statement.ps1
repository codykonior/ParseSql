function Get-Statement ($Statement, $Keys, $ScriptName) {
    $StatementObject = [PSCustomObject] @{
        PSTypeName      = "Parser.DOM.Statement"
        ScriptName      = $ScriptName
        BatchNumber     = $TotalBatches
        StatementNumber = $TotalStatements
        StatementType   = $null
        Action          = $null
        IsQualified     = $false
        OnObjectSchema  = $null
        OnObjectName    = $null
    }
                
    Add-Member -InputObject $StatementObject -Type ScriptMethod -Name ToString -Value { $this.psobject.typenames[0] } -Force
                
    $StatementObject.Action = ($Statement.ScriptTokenStream | Where-Object {$_.Line -eq $Statement.StartLine -and $_.Column -eq $Statement.StartColumn}).Text.ToUpper()

    if ($statementObject.Action -eq "If") {
        Write-Verbose "Found an an 'IF' statement, looking at the 'THEN' part of the statement..."
        if ($Statement.ThenStatement.StatementList.Statements.Count -ge 1) {
            $SubStatements = $Statement.ThenStatement.StatementList.Statements
            ForEach ($su in $subStatements) {
                $StatementObject = Get-Statement $su $keys
            }
        } else {
            $StatementObject = Get-Statement $Statement.ThenStatement $keys
        }
        $StatementObject.IsQualified = $true
    } else {
        $Property = $Statement
        $TempObjectType = ($Keys | Where-Object {$_.ObjectType -eq $Statement.gettype().name})
        if ($TempObjectType) {            
            $ObjectType = $TempObjectType.ObjectType
            Write-Verbose "Object type: $ObjectType"
            if ($ObjectType -eq "UpdateStatement" -and $statement.UpdateSpecification.WhereClause -ne $null -and $statement.UpdateSpecification.SetClauses -ne $null) {
                $SchemaObject = Get-UpdatedTableFromReferences $Statement.UpdateSpecification.FromClause.TableReferences.FirstTableReference
                $StatementObject.OnObjectSchema = $SchemaObject.SchemaIdentifier.Value
                $StatementObject.OnObjectName = $SchemaObject.BaseIdentifier.Value
            } elseif ($ObjectType -eq "SelectStatement" -and $statement.Queryexpression.fromclause.tablereferences.FirstTableReference -ne $null) {
                $SchemaObject = Get-UpdatedTableFromReferences $statement.Queryexpression.fromclause.tablereferences.FirstTableReference
                $StatementObject.OnObjectSchema = $SchemaObject.SchemaIdentifier.Value
                $StatementObject.OnObjectName = $SchemaObject.BaseIdentifier.Value
            } elseif ($ObjectType -eq "PredicateSetStatement") {
                $StatementObject.StatementType = $Statement.GetType().Name.ToString()
                $StatementObject.OnObjectSchema = $Property.Options
                $StatementObject.OnObjectName = switch ($Property.IsOn) { $true { "ON" } $false { "OFF" } }                  
            } elseif ($ObjectType -eq "PredicateSetStatement") {
                try {
                    $StatementObject.StatementType = $Statement.GetType().Name.ToString()
                    $SplitDefinition = (($Keys | Where-Object {$_.ObjectType -eq $Statement.gettype().name}).SchemaSpecification).Split(".")
                    ForEach ($def in $SplitDefinition) {
                        $Property = $Property | Select-Object -ExpandProperty $def
                    }
                    $StatementObject.OnObjectSchema = $Property.SchemaIdentifier.Value
                    $StatementObject.OnObjectName = $Property.BaseIdentifier.Value
                } catch {
                    Write-Warning "Parsed statement has no descernible statement type. Maybe define one as a parser key?"
                }
            }
        } else {
            Write-Warning "$($Statement.gettype().name) is not a known type"
        }
    }
    return $StatementObject            

}
