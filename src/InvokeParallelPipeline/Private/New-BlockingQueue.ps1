function New-BlockingQueue {
    [CmdletBinding()]
    [OutputType([System.Collections.Concurrent.BlockingCollection[PSObject]])]
    param (
        [switch]$Completed
    )

    process {
        $Queue = [System.Collections.Concurrent.BlockingCollection[PSObject]]::new(
            [System.Collections.Concurrent.ConcurrentQueue[PSObject]]::new()
        )
        if ($Completed) {
            $Queue.CompleteAdding()
        }
        ,$Queue
    }
}