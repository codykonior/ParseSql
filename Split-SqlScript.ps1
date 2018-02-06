<#
.SYNOPSIS
Scans a (list of) T-SQL script files(s) and returns information about the operations being performed by them.
    
.DESCRIPTION
This function utilizes the SQL Server ScriptDom Parser object to parse and return information about each batch and statements within each batch
of T-SQL commands they contain. It will return an object that contains high-level information, as well as a batches object which in turn contains 
statement objects.

.PARAMETER Files
The [System.IO.FileInfo] object containing the files you want to scan. This type of object is usually returned from a Get-ChildItem cmdlet, so you can pipe the
results of it to this function. Required.

.PARAMETER UseQuotedIdentifier
Whether or not the quoted identifier option is turned on for the parser. Defaults to true and is passed to the object instantiation.

.NOTES
Out-of-the-box this function will search for:
    - DML statements (INSERT, UPDATE, DELETE)
    - Certain DDL Statements:
    - ALTER TABLE
    - DROP INDEX
    - CREATE INDEX
    - CREATE PROCEDURE
    - DROP PROCEDURE
    - EXEC
    
You can extend the tests by adding a new [ParserKey] object to the $ParserKeys array. For now, these defined tests live in the code
but I expect them to be an external json file at some point.

Author: Drew Furgiuele (@pittfurg, port1433.com)
Tags: T-SQL, Parser
    
.LINK

.EXAMPLE
$Results = Get-ChildItem -Path C:\Scripts | Split-SqlScript

Execute the parser against a list of files returned from the Get-ChildItem cmdlet and store the returned object in the $Results variable

#>
function Split-SqlScript {
    [cmdletbinding()]
    param(
        [Parameter(
            Mandatory = $true,
            Position = 0,
            ValueFromPipeline = $true,
            ValueFromPipelineByPropertyName = $true)
        ] 
        [Alias("FullName")]
        [string] $File,
        [Parameter(Mandatory = $false)] [string] $UseQuotedIdentifier = $true
    )

    begin {
        $pathToScriptDomLibrary = Join-Path (Get-Module SqlServer -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1 -ExpandProperty ModuleBase) Microsoft.SqlServer.TransactSql.ScriptDom.dll

        $ParserKeys = @()

        Class ParserKey {
            [string] $ObjectType
            [string] $SchemaSpecification
            ParserKey ([string] $ObjectType, [string] $SchemaSpecification) {
                $this.ObjectType = $ObjectType
                $this.SchemaSpecification = $SchemaSpecification
            }
        }

        $ParserKeys += New-Object Parserkey ("SelectStatement", "Queryexpression.Fromclause.Tablereferences.Schemaobject")
        $ParserKeys += New-Object Parserkey ("InsertStatement", "InsertSpecification.Target.SchemaObject")
        $ParserKeys += New-Object Parserkey ("UpdateStatement", "UpdateSpecification.Target.SchemaObject")
        $ParserKeys += New-Object Parserkey ("DeleteStatement", "DeleteSpecification.Target.SchemaObject")
        $ParserKeys += New-Object Parserkey ("AlterTableAddTableElementStatement", "SchemaObjectName")
        $ParserKeys += New-Object Parserkey ("AlterTableDropTableElementStatement", "SchemaObjectName")
        $ParserKeys += New-Object Parserkey ("DropIndexStatement", "DropIndexClauses.Object")
        $ParserKeys += New-Object Parserkey ("CreateIndexStatement", "OnName")
        $ParserKeys += New-Object Parserkey ("CreateProcedureStatement", "ProcedureReference.Name")
        $ParserKeys += New-Object Parserkey ("AlterProcedureStatement", "ProcedureReference.Name")
        $ParserKeys += New-Object Parserkey ("CreateFunctionStatement", "Name")
        $ParserKeys += New-Object Parserkey ("AlterFunctionStatement", "Name")
        $ParserKeys += New-Object Parserkey ("CreateTableStatement", "SchemaObjectName")
        $ParserKeys += New-Object Parserkey ("DropProcedureStatement", "Objects")
        $ParserKeys += New-Object Parserkey ("DropTableStatement", "Objects")
        $ParserKeys += New-Object Parserkey ("PredicateSetStatement", "Options")
        $ParserKeys += New-Object Parserkey ("GrantStatement", "Objects")
        $ParserKeys += New-Object Parserkey ("ExecuteStatement", "ExecuteSpecification.ExecutableEntity.ProcedureReference.ProcedureReference.Name")
        $ParserKeys += New-Object Parserkey ("DeclareVariableStatement", $null)
        $ParserKeys += New-Object Parserkey ("PrintStatement", $null)

        $LibraryLoaded = $false
        $ObjectCreated = $false
        $LibraryVersions = @(14, 13, 12, 11)

        if ($pathToScriptDomLibrary -ne "") {
            try {
                Add-Type -Path $pathToScriptDomLibrary -ErrorAction SilentlyContinue
                Write-Verbose "Loaded library from path $pathToScriptDomLibrary"
            } catch {
                throw "Couldn't load the required ScriptDom library from the path specified!"
            }
        } else {
            ForEach ($v in $LibraryVersions) {
                if (!$LibraryLoaded) {
                    try {
                        Add-Type -AssemblyName "Microsoft.SqlServer.TransactSql.ScriptDom,Version=$v.0.0.0,Culture=neutral,PublicKeyToken=89845dcd8080cc91"  -ErrorAction SilentlyContinue
                        Write-Verbose "Loaded version $v.0.0.0 of the ScriptDom library."
                        $LibraryLoaded = $true                
                    } catch {
                        Write-Verbose "Couldn't load version $v.0.0.0 of the ScriptDom library."
                    }
                }
            }
        }

        ForEach ($v in $LibraryVersions) {
            if (!$ObjectCreated) {
                try {
                    $ParserNameSpace = "Microsoft.SqlServer.TransactSql.ScriptDom.TSql" + $v + "0Parser"
                    $Parser = New-Object $ParserNameSpace($UseQuotedIdentifier)
                    $ObjectCreated = $true
                    Write-Verbose "Created parser object for version $v..."
                } catch {
                    Write-Verbose "Couldn't load version $v.0.0.0 of the ScriptDom library."
                }
            }
        }

        if (!$ObjectCreated) {
            throw "Unable to create ScriptDom library; did you load the right version of the library?"
        }

    }


    process {
        ForEach ($currentFileName in $File) {
            $currentFileName = Resolve-Path $currentFileName
            $scriptName = Split-Path -Leaf $currentFileName
            Write-Verbose "Parsing $currentFileName..."

            $Reader = New-Object System.IO.StreamReader($currentFileName)    
            $Errors = $null
            $Fragment = $Parser.Parse($Reader, [ref] $Errors)

            [bool] $HasErrors = $false
            if ($Errors -ne $null) {
                [bool] $HasErrors = $true
            }

            $ScriptObject = [PSCustomObject] @{
                PSTypeName      = "Parser.DOM.Script"
                ScriptName      = $scriptName
                ScriptFilePath  = $currentFileName
                NumberOfBatches = $Fragment.Batches.Count
                HasParseErrors  = $HasErrors
                Errors          = $Errors
                Batches         = @()
            }

            Add-Member -InputObject $ScriptObject -Type ScriptMethod -Name ToString -Value { $this.psobject.typenames[0] } -Force
                
            $TotalBatches = 0
            ForEach ($b in $Fragment.Batches) {
                $TotalBatches++;

                $BatchObject = [pscustomobject] @{
                    PSTypeName  = "Parser.DOM.Batch"
                    ScriptName  = $scriptName
                    BatchNumber = $TotalBatches
                    Statements  = @()
                }

                Add-Member -InputObject $BatchObject -Type ScriptMethod -Name ToString -Value { $this.psobject.typenames[0] } -Force

                $TotalStatements = 0
                ForEach ($s in $b.Statements) {
                    $TotalStatements++
                    $StatementObject = Get-Statement $s $ParserKeys $scriptName

                    $BatchObject.Statements += $StatementObject
                }
                $ScriptObject.Batches += $BatchObject
            }

            $Reader.Close()

            $ScriptObject
        }
    }

    end {
        $Reader.Dispose()
    }
}