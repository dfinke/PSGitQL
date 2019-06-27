#requires -modules PSStringScanner
function Add-PSOp {
    param($target)

    $target | Add-Member -PassThru -MemberType ScriptProperty -Name PSOp -Value {
        switch ($this.operation) {
            "<>" { "-ne" }
            ">=" { "-ge" }
            "<=" { "-le" }
            "=" { "-eq" }
            ">" { "-gt" }
            "<" { "-lt" }
            "like" { "-like" }
            "match" { "-match" }
            default { $_ }
        }
    }
}

function Add-PSLogicOp {
    param($target)

    $target | Add-Member -PassThru -MemberType ScriptProperty -Name PSLogicOp -Value {
        if ($this.LogicOp) {
            "-" + $this.LogicOp
        }
    }
}

function Invoke-ParseSQL {
    param(
        [Parameter(Mandatory)]
        $SQL
    )

    $ss = New-PSStringScanner $sql

    $SELECT_KW = "^[Ss][Ee][Ll][Ee][Cc][Tt]\s+"
    $FROM_KW = "[Ff][Rr][Oo][Mm]"
    $WHERE_KW = "[Ww][Hh][Ee][Rr][Ee]"
    $LIMIT_KW = "[Ll][Ii][Mm][Ii][Tt]"
    $OPERATIONS = "<>|<=|>=|>|<|=|like|match"
    $LOGICAL = "[Oo][rR]|[Aa][Nn][Dd]"
    $WHITESPACE = "\s+"

    $h = [Ordered]@{ }

    if ($ss.Check($SELECT_KW)) {
        $null = $ss.Scan($SELECT_KW)

        $h.SelectPropertyNames = ($ss.ScanUntil("(?=$FROM_KW)")).trim()

        if ($h.SelectPropertyNames.Contains(',')) {
            $h.SelectPropertyNames = $h.SelectPropertyNames.Split(',').foreach( { $_.trim() })
        }

        $null = $ss.Skip($FROM_KW)

        if ($ss.Check($WHERE_KW)) {
            $h.DataSetName = $ss.ScanUntil("(?=$WHERE_KW)").trim()
            $null = $ss.Skip("$WHERE_KW")

            $ssWhere = New-PSStringScanner $ss.Scan(".*")

            $whereResults = @()

            while (!$ssWhere.EoS()) {
                $currentResult = [Ordered]@{ }
                $currentResult.propertyName = $ssWhere.ScanUntil("(?=$OPERATIONS)").trim()
                $currentResult.operation = $ssWhere.Scan($OPERATIONS)

                if ($ssWhere.Check("$($WHITESPACE)$($LOGICAL)")) {
                    $currentResult.value = $ssWhere.ScanUntil("(?=$($WHITESPACE)$($LOGICAL))")
                    $currentResult.logicOp = $ssWhere.Scan($LOGICAL)
                }
                else {
                    $currentResult.value = $ssWhere.Scan('.*').Trim()
                    #$currentResult.value = $ssWhere.Scan('\w+').Trim()
                }

                $obj = Add-PSOp ([PSCustomObject]$currentResult)
                $obj = Add-PSLogicOp $obj

                $whereResults += [PSCustomObject]$obj
            }
        }
        else {
            $h.DataSetName = $ss.Scan("\w+").trim()
        }
    }

    if ($whereResults) {
        $h.where = [PSCustomObject[]]$whereResults
    }

    if ($ss.Check($LIMIT_KW)) {
        $null = $ss.ScanUntil("(?=$LIMIT_KW)")
        $null = $ss.Skip("$LIMIT_KW")
        $h.limit = $ss.Scan("\d+")
    }

    $h
}

function Invoke-GitQuery {
    [CmdletBinding()]
    param($sql)

    $map = @{
        hash        = "%h"
        date        = "%ad"
        author      = "%an"
        authoremail = "%ae"
        message     = "%s"
        fullmessage = "%B"
    }

    $r = Invoke-ParseSQL $sql

    $fmt = $r.SelectPropertyNames.ForEach( { $map.$_ }) -join '%x09'

    if ($r.where) {
        switch ($r.where.propertyname) {
            'author' { $where = '--{0}{1}{2}' -f $r.where.propertyname, $r.where.operation, $r.where.value }
            'date' {
                function Get-GitDate {
                    param($targetDate)

                    $targetValue = $r.where.value -replace "'", ""
                    Get-Date $targetValue
                }

                if ($r.where.operation -eq "=") {
                    $date = Get-GitDate
                    $dateFmt = "yyyy-MM-dd"
                    $where = '--after="{0}" --before="{1}"' -f $date.ToString($dateFmt + " 00:00"), $date.ToString($dateFmt + " 23:59")
                }
                else {
                    if ($r.where.operation -eq ">") { $when = "after" }
                    if ($r.where.operation -eq "<") { $when = "before" }

                    $date = Get-GitDate
                    $where = '--{0}={1}' -f $when, $date.ToString("yyyy-MM-dd")
                }
                $where += " --date=local"
            }
        }
    }

    if ($r.limit) {
        $limit = "-$($r.limit)"
    }

    $gitcmd = 'git log --pretty=format:"{0}" {1} {2}' -f $fmt, $where, $limit
    Write-Verbose $gitcmd

    $result = $gitcmd | Invoke-Expression
    if ($result) {
        ConvertFrom-Csv -Header $r.SelectPropertyNames -Delimiter "`t" -InputObject $result
    }
}

Set-Alias psgitql Invoke-GitQuery

# Invoke-GitQuery "select hash, author, message from commits limit 5"
# Invoke-GitQuery "select hash, author, authoremail, message from commits limit 5"
# Invoke-GitQuery "select message, author, authoremail from commits limit 15"
# Invoke-GitQuery "select hash,authorEmail from commits where author = 'dfinke'"
# Invoke-GitQuery "select hash,authorEmail from commits_stuff limit 3"
# Invoke-GitQuery "select date,author from commits limit 3"
# Invoke-GitQuery "select date,author from commits where date > '2019-06-25'"
# Invoke-GitQuery "select date,author from commits where date < '2019-06-25'"
# Invoke-GitQuery "select date,author from commits where date = '2019-06-25'"

# psgitql "select hash, author, message from commits limit 5"