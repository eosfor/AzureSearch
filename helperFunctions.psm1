#helper functions

# ---------------------------------------------------------------------------
# Name:   Invoke-Ternary
# Alias:  ?:
# Author: Karl Prosser
# Desc:   Similar to the C# ? : operator e.g. 
#            _name = (value != null) ? String.Empty : value;
# Usage:  1..10 | ?: {$_ -gt 5} {"Greater than 5;$_} {"Not greater than 5";$_}
# ---------------------------------------------------------------------------

function Invoke-Ternary {
[CmdletBinding()]
param([scriptblock]$decider, [scriptblock]$ifTrue, [scriptblock]$ifFalse)
   if (&$decider) { 
      &$ifTrue
   } else { 
      &$ifFalse 
   }
}

function ConvertTo-HashTable {
[CmdletBinding()]
param(
    $psobject
)
    $ht2 = @{}
    $psobject.psobject.properties | Foreach { $ht2[$_.Name] = $_.Value }

    $ht2
}


set-alias -name ?: -value Invoke-Ternary

filter Skip-Null { $_|?{ $_ } }