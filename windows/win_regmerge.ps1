#!powershell
# This file is part of Ansible
#
# Copyright 2015, Jon Hawkesworth (@jhawkesworth) <figs@unity.demon.co.uk>
#
# Ansible is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Ansible is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Ansible.  If not, see <http://www.gnu.org/licenses/>.

# WANT_JSON
# POWERSHELL_COMMON

Function Convert-RegistryPath {
    Param (
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]$Path
    )

    $output = $Path -replace "HKLM:", "HKEY_LOCAL_MACHINE\"
    $output = $output -replace "HKCU:", "HKEY_CURRENT_USER\" 
#   TODO check if there are other ps providers for registry

    Return $output
}

$params = Parse-Args $args
$result = New-Object PSObject
Set-Attr $result "changed" $false

If ($params.path)
{
    $path = $params.path
} else {
    Fail-Json $result "missing required argument: path"
}

# check it looks like a reg key
# only accepting PS-Drive style key names (starting with HKLM etc, not HKEY_LOCAL_MACHINE etc)

$do_comparison = False

If ($params.compare_to) {
    $compare_to_key = $params.compare_to.ToString()
    If (Test-Path $compare_to_key -pathType container ) {
        $do_comparison = $True
    } Else {
        #Fail-Json $result "compare_to is '$level' but must be an existing registry key on the managed host"
        Set-Attr $result "changed" $true
    }
}

If ( $do_comparison ) {
  $exported_path = [System.IO.Path]::GetTempFileName()
  $expanded_compare_key = Convert-RegistryPath ($compare_to_key) 

  # export from the reg key location to a file
  & regedit.exe /e $exported_path $expanded_compare_key
  # compare the two files
  $comparison_result = Compare-Object $(Get-Content $exported_path) $(Get-Content $path) 
  # remove temp file
  Remove-Item $exported_path

  If ($comparison_result ) {
     # Something is different, actually do reg merge
     & reg.exe IMPORT $path
     Set-Attr $result "changed" $true
  }

} Elseif {
     # not comparing, merge and report changed
     & reg.exe IMPORT $path
     Set-Attr $result "changed" $true
}

Exit-Json $result;
