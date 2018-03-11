function Get-RunnerScriptBlock {
    [CmdletBinding()]
    [OutputType([ScriptBlock])]
    param ()
    process {
        {
            Param(
                [System.Collections.Concurrent.BlockingCollection[PSObject]]
                $InputQueue,
                
                [System.Collections.Concurrent.BlockingCollection[PSObject]]
                $OutputQueue,
                
                [System.Collections.Concurrent.BlockingCollection[PSObject]]
                $RunnerStack,
                
                [Guid]
                $ThreadGuid,

                [System.Threading.AutoResetEvent]
                $Signal,
                
                [ScriptBlock]
                $ScriptBlock,

                [System.Collections.IDictionary]
                $Splat = @{}
            )

            $RunnerStack.Add($ThreadGuid)

            if($null -ne $InputQueue) {
                $InputQueue.GetConsumingEnumerable() |
                    & $ScriptBlock @Splat |
                    ForEach-Object {
                        $OutputQueue.Add($_)
                    }
            }
            else {
                & $ScriptBlock @Splat |
                    ForEach-Object {
                        $OutputQueue.Add($_)
                    }
            }

            $null = $RunnerStack.Take()
            $Signal.WaitOne()
            if($RunnerStack.Count -eq 0) {
                $RunnerStack.CompleteAdding()
            }
        }
    }
}