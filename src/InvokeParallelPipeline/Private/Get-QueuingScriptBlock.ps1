function Get-QueuingScriptBlock {
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
                $Signal
            )

            $RunnerStack.Add($ThreadGuid)
            foreach($QueueItem in $InputQueue.GetConsumingEnumerable()) {
                $OutputQueue.Add($QueueItem)
            }

            $null = $RunnerStack.Take()
            $Signal.WaitOne()
            $Signal.Set()
            if($RunnerStack.Count -eq 0) {
                $RunnerStack.CompleteAdding()
                $OutputQueue.CompleteAdding()
            }
        }
    }
}