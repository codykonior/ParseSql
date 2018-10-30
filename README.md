# ParseSql PowerShell Module by Cody Konior

There is no logo yet.

[![Build status](https://ci.appveyor.com/api/projects/status/t4285njy3p09glxd?svg=true)](https://ci.appveyor.com/project/codykonior/parsesql)

Read the [CHANGELOG][3]

## Description

This parses a T-SQL script and returns it in batches.

```
ScriptName      : ComplicatedALTERExample.sql
ScriptFilePath  : C:\Git\parsesql\Tests\TestScripts\ComplicatedALTERExample.sql
NumberOfBatches : 3
HasParseErrors  : True
Errors          : {}
Batches         : {Parser.DOM.Batch, Parser.DOM.Batch, Parser.DOM.Batch}
```

Each batch is then split into statements.

```
ScriptName                  BatchNumber Statements
----------                  ----------- ----------
ComplicatedALTERExample.sql           1 {Parser.DOM.Statement}
ComplicatedALTERExample.sql           2 {Parser.DOM.Statement}
ComplicatedALTERExample.sql           3 {Parser.DOM.Statement}
```

## Installation

- `Install-Module ParseSql`

## Major functions

- `Split-SqlScript`

## Tips

- It's extremely fragile and only covers a few T-SQL cases. If it breaks it's probably not your fault.

## Notes

This module is based extensively on the work of [Drew Furgiuele][4].

[1]: Images/parsesql.ai.svg
[2]: Images/parsesql.gif
[3]: CHANGELOG.md
[4]: https://port1433.com/
