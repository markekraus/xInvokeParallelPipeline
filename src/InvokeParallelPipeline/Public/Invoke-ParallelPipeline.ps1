function Invoke-ParallelPipeline {
    [CmdletBinding(DefaultParameterSetName='NoInput')]
    [OutputType([System.Collections.Concurrent.BlockingCollection[PSObject]])]
    param (
        [Parameter(ParameterSetName = 'InputQueue')]
        [Parameter(ParameterSetName = 'NoInput')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ValidateRange(
            1, ([Int]::MaxValue - 1)
        )]
        [int]$Throttle  = 1,

        [Parameter(ParameterSetName = 'InputQueue')]
        [Parameter(ParameterSetName = 'NoInput')]
        [Parameter(ParameterSetName = 'InputObject')]
        [ScriptBlock]$ScriptBlock,

        [Parameter(ParameterSetName = 'InputQueue')]
        [Parameter(ParameterSetName = 'NoInput')]
        [Parameter(ParameterSetName = 'InputObject')]
        [System.Collections.IDictionary]$Splat = @{},

        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'InputQueue')]
        [System.Collections.Concurrent.BlockingCollection[PSObject]]
        $InputQueue,

        [Parameter(ValueFromPipeline = $true, ParameterSetName = 'InputObject')]
        [Object]
        $InputObject
    )
    
    begin {
        $CombinedInputQueue = New-BlockingQueue

        #Create the Output Queue and immediately put it in the pipe without enumeration
        $OutputQueue = New-BlockingQueue
        ,$OutputQueue

        $RunnerStack = New-BlockingStack
        $PSRunners = New-GenericList
        $RunnerScriptBlock = Get-RunnerScriptBlock

        $CombinerStack = New-BlockingStack
        $QueuingScriptBlock = Get-QueuingScriptBlock

        $RunspacePool = [RunspaceFactory]::CreateRunspacePool(1,($Throttle+1))
        $null = $RunspacePool.Open()

        $FirstPass = $true
        $RunnerAddCompleteSignal = [System.Threading.AutoResetEvent]::new($false)
        $QueuingAddCompleteSignal = [System.Threading.AutoResetEvent]::new($false)
    }

    process {
        if ($FirstPass) {
            switch ($PSCmdlet.ParameterSetName) {
                'NoInput' { $PassedInputQueue = $null; break }
                Default   { $PassedInputQueue = $CombinedInputQueue; break }
            }
            # Create the Runner threads that run the supplied ScriptBlock
            1..$Throttle | ForEach-Object {
                $ThreadGuid = [Guid]::NewGuid()
                Write-Verbose ('Adding Thread "{0}" GUID: "{1}"' -f $_, $ThreadGuid)

                $PowerShell = [PowerShell]::Create()
                $PowerShell.RunspacePool = $RunspacePool

                $null = $PowerShell.AddScript($RunnerScriptBlock)

                $Parameters = New-GenericList
                $Parameters.Add($PassedInputQueue)
                $Parameters.Add($OutputQueue)
                $Parameters.Add($RunnerStack)
                $Parameters.Add($ThreadGuid)
                $Parameters.Add($RunnerAddCompleteSignal)
                $Parameters.Add($ScriptBlock)
                $Parameters.Add($Splat)
                $null = $PowerShell.AddParameters($Parameters)

                $PowerShellHandler = $PowerShell.BeginInvoke()

                $PSRunners.Add([PSCustomObject]@{
                    PowerShell = $PowerShell
                    Handler = $PowerShellHandler
                    Guid = $ThreadGuid
                })
            }
            $null = $RunnerAddCompleteSignal.Set()
            $FirstPass = $false
        }
        switch ($PSCmdlet.ParameterSetName) {
            'InputQueue'  {
                # For each InputQueue, Create a combiner thread that combiner thread
                # These threads pass the InputQueues to a singe queue consumed
                # by the runner threads
                $Null = $RunspacePool.SetMaxRunspaces(($RunspacePool.GetMaxRunspaces()+1))

                $PowerShell = [PowerShell]::Create()
                $PowerShell.RunspacePool = $RunspacePool
                $ThreadGuid = [Guid]::NewGuid()

                $null = $PowerShell.AddScript($QueuingScriptBlock)
                
                $Parameters = New-GenericList
                $Parameters.Add($InputQueue)
                $Parameters.Add($CombinedInputQueue)
                $Parameters.Add($CombinerStack)
                $Parameters.Add($ThreadGuid)
                $Parameters.Add($QueuingAddCompleteSignal)
                $null = $PowerShell.AddParameters($Parameters)
                
                $PowerShellHandler = $PowerShell.BeginInvoke()
                
                $PSRunners.Add([PSCustomObject]@{
                    PowerShell = $PowerShell
                    Handler = $PowerShellHandler
                    Guid = $ThreadGuid
                })
                break
            }
            'InputObject' { $CombinedInputQueue.Add($InputObject); break }
        }
    }

    end {
        $null = $QueuingAddCompleteSignal.Set()
        $CombinedInputQueue.CompleteAdding()

        while (-not $RunnerStack.IsAddingCompleted) {
            Start-Sleep -Milliseconds 500
        }
        $OutputQueue.CompleteAdding()
        Foreach($Runner in $PSRunners) {
            $null = $Runner.PowerShell.EndInvoke($Runner.Handler)
            $null = $Runner.PowerShell.Dispose()
        }
        $null = $RunspacePool.Dispose()
    }
}