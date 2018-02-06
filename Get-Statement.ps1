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
        if ($Statement.ThenStatement.psobject.Properties["StatementList"] -and $Statement.ThenStatement.StatementList.Statements.Count -ge 1) {
            $SubStatements = $Statement.ThenStatement.StatementList.Statements
            ForEach ($su in $subStatements) {
                $StatementObject = Get-Statement $su $keys $ScriptName
                $StatementObject
            }
        } else {
            $StatementObject = Get-Statement $Statement.ThenStatement $keys $ScriptName
            $StatementObject
        }
    } else {
        $Property = $Statement
        $TempObjectType = ($Keys | Where-Object {$_.ObjectType -eq $Statement.gettype().name})
        if ($TempObjectType) {            
            $ObjectType = $TempObjectType.ObjectType
            Write-Verbose "Object type: $ObjectType"
            if ($ObjectType -eq "UpdateStatement" -and $statement.UpdateSpecification.WhereClause -ne $null -and $statement.UpdateSpecification.SetClauses -ne $null) {
                if ($Statement.UpdateSpecification.FromClause) {
                    if ($Statement.UpdateSpecification.FromClause.TableReferences.psobject.Properties["FirstTableReference"]) {
                        $SchemaObject = Get-UpdatedTableFromReferences $Statement.UpdateSpecification.FromClause.TableReferences.FirstTableReference
                    } else {
                        $SchemaObject = $Statement.UpdateSpecification.FromClause.TableReferences.SchemaObject
                    }
                } else {
                    $SchemaObject = $Statement.UpdateSpecification.Target.SchemaObject
                }
                if ($SchemaObject.SchemaIdentifier -ne $null) {
                    $StatementObject.OnObjectSchema = $SchemaObject.SchemaIdentifier.Value
                } 
                if ($SchemaObject.BaseIdentifier -ne $null) {
                    $StatementObject.OnObjectName = $SchemaObject.BaseIdentifier.Value
                }
        } elseif ($ObjectType -eq "SelectStatement" -and $statement.QueryExpression.FromClause -and $statement.QueryExpression.FromClause.psobject.Properties["TableReferences"] -and $statement.QueryExpression.FromClause.TableReferences -and $statement.QueryExpression.FromClause.TableReferences.psobject.Properties["FirstTableReference"] -and $statement.QueryExpression.FromClause.TableReferences.FirstTableReference -ne $null) {
                $SchemaObject = Get-UpdatedTableFromReferences $statement.Queryexpression.FromClause.TableReferences.FirstTableReference
                $StatementObject.OnObjectSchema = $SchemaObject.SchemaIdentifier.Value
                $StatementObject.OnObjectName = $SchemaObject.BaseIdentifier.Value
            } elseif ($ObjectType -eq "SelectStatement") {
                $StatementObject.StatementType = $Statement.GetType().Name.ToString()
            } elseif ($ObjectType -eq "PredicateSetStatement") {
                $StatementObject.StatementType = $Statement.GetType().Name.ToString()
                $StatementObject.OnObjectSchema = $Property.Options
                $StatementObject.OnObjectName = switch ($Property.IsOn) { $true { "ON" } $false { "OFF" } }                  
            } elseif ($ObjectType -eq "GrantStatement") {
                $StatementObject.StatementType = $Statement.GetType().Name.ToString()
                if ($Property.SecurityTargetObject) {
                    if ($Property.SecurityTargetObject.ObjectName.MultiPartIdentifier.Identifiers.Count -eq 1) {
                        $StatementObject.OnObjectName = $Property.SecurityTargetObject.ObjectName.MultiPartIdentifier.Identifiers[0].Value
                    } else {
                        $StatementObject.OnObjectSchema = $Property.SecurityTargetObject.ObjectName.MultiPartIdentifier.Identifiers[0].Value
                        $StatementObject.OnObjectName = $Property.SecurityTargetObject.ObjectName.MultiPartIdentifier.Identifiers[1].Value                   
                    }
                }
            } elseif ($ObjectType -eq "ExecuteStatement" -and $Statement.ExecuteSpecification.ExecutableEntity -is [Microsoft.SqlServer.TransactSql.ScriptDom.ExecutableStringList]) {
                $StatementObject.StatementType = $Statement.GetType().Name.ToString()                
            } elseif ($ObjectType -in "DeclareVariableStatement", "PrintStatement", "CreateLoginStatement") {
                $StatementObject.StatementType = $Statement.GetType().Name.ToString()                                
            } else {
                try {
                    $StatementObject.StatementType = $Statement.GetType().Name.ToString()
                    $SplitDefinition = (($Keys | Where-Object {$_.ObjectType -eq $Statement.gettype().name}).SchemaSpecification).Split(".")
                    ForEach ($def in $SplitDefinition) {
                        $Property = $Property | Select-Object -ExpandProperty $def
                    }
                    if ($Property.SchemaIdentifier -ne $null) {
                        $StatementObject.OnObjectSchema = $Property.SchemaIdentifier.Value
                    } 
                    if ($Property.BaseIdentifier -ne $null) {
                        $StatementObject.OnObjectName = $Property.BaseIdentifier.Value
                    }
                } catch {
                    Write-Warning "Parsed statement $($Statement.gettype().name) has no descernible statement type. Maybe define one as a parser key?"
                }
            }

            if ($StatementObject) {
                return $StatementObject            
            }                        
        } else {
            Write-Warning "$($Statement.gettype().name) is not a known type"
        }
    }
}
