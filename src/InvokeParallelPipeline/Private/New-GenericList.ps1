function New-GenericList {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[PSObject]])]
    param ()

    process {
        $List = [System.Collections.Generic.List[PSObject]]::new()
        ,$List
    }
}