function New-BlockingStack {
    [CmdletBinding()]
    [OutputType([System.Collections.Concurrent.BlockingCollection[PSObject]])]
    param (
        [switch]$Completed
    )

    process {
        $Stack = [System.Collections.Concurrent.BlockingCollection[PSObject]]::new(
            [System.Collections.Concurrent.ConcurrentStack[PSObject]]::new()
        )
        if ($Completed) {
            $Stack.CompleteAdding()
        }
        ,$Stack
    }
}