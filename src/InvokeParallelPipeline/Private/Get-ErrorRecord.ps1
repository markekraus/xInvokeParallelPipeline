function Get-ErrorRecord {
    [CmdletBinding()]
    [OutputType([System.Management.Automation.ErrorRecord])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateSet(
            'UnknownParameterSetName'
        )]
        [String]$Type,

        [Object]$Object
    )
    
    begin {
    }
    
    process {
        switch ($Type) {
            'UnknownParameterSetName' { 
                $Exception = [System.Management.Automation.ParameterBindingException]::New('Unknown ParameterSetName') 
                $ErrorId = 'UnknownParameterSetName'
                $Category = [System.Management.Automation.ErrorCategory]::NotImplemented
            }
        }
        [System.Management.Automation.ErrorRecord]::new($Exception, $ErrorId, $Category, $Object)
    }
}