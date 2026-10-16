$null=[Reflection.Assembly]::LoadFrom('C:\Program Files (x86)\Duo Desktop\TSS.Net.dll')
$dev=[Tpm2Lib.TbsDevice]::new($false); $dev.Connect(); $tpm=[Tpm2Lib.Tpm2]::new($dev)
$asm=[Tpm2Lib.Tpm2].Assembly
function N($t,$a){ [Activator]::CreateInstance($asm.GetType("Tpm2Lib.$t"),[object[]]$a) }
function TryPrimary($label,$parms,$attrsText,$unique,$hier){
  try{
    $attrs=[Tpm2Lib.ObjectAttr]$attrsText
    $pub=N 'TpmPublic' @([Tpm2Lib.TpmAlgId]::Sha256,$attrs,[byte[]]::new(0),$parms,$unique)
    $sens=N 'SensitiveCreate' @([byte[]]::new(0),[byte[]]::new(0))
    $op=$null;$cd=$null;$ch=$null;$ct=$null
    $h=$tpm.CreatePrimary([Tpm2Lib.TpmHandle]::new($hier),$sens,$pub,[byte[]]::new(0),[Tpm2Lib.PcrSelection[]]@(),[ref]$op,[ref]$cd,[ref]$ch,[ref]$ct)
    $tpm.FlushContext($h); "OK   $label"
  }catch{ $m=$_.Exception.InnerException.Message; "FAIL $label : " + (($m -split "`n")[0]) }
}
$nullsym=N 'SymDefObject' @([Tpm2Lib.TpmAlgId]::Null,[uint16]0,[Tpm2Lib.TpmAlgId]::Null)
$aes=N 'SymDefObject' @([Tpm2Lib.TpmAlgId]::Aes,[uint16]128,[Tpm2Lib.TpmAlgId]::Cfb)
$empty=N 'EccPoint' @([byte[]]::new(0),[byte[]]::new(0))
foreach($c in 'NistP256','NistP384','NistP192'){
  $curve=[Tpm2Lib.EccCurve]::$c
  # signing ECDSA, owner hierarchy
  $p=N 'EccParms' @($nullsym,(N 'SchemeEcdsa' @([Tpm2Lib.TpmAlgId]::Sha256)),$curve,(N 'NullKdfScheme' @()))
  TryPrimary "ECC $c ECDSA sign key (owner)" $p 'Sign, FixedParent, FixedTPM, UserWithAuth, SensitiveDataOrigin' $empty ([Tpm2Lib.TpmRh]::Owner)
  # storage key (decrypt+restricted) with AES
  $p2=N 'EccParms' @($aes,(N 'NullAsymScheme' @()),$curve,(N 'NullKdfScheme' @()))
  TryPrimary "ECC $c storage key (owner)" $p2 'Restricted, Decrypt, FixedParent, FixedTPM, UserWithAuth, SensitiveDataOrigin' $empty ([Tpm2Lib.TpmRh]::Owner)
}
# RSA 2048 storage key for comparison
$rp=N 'RsaParms' @($aes,(N 'NullAsymScheme' @()),[uint16]2048,[uint32]0)
TryPrimary 'RSA 2048 storage key (owner)' $rp 'Restricted, Decrypt, FixedParent, FixedTPM, UserWithAuth, SensitiveDataOrigin' (N 'Tpm2bPublicKeyRsa' @([byte[]]::new(0))) ([Tpm2Lib.TpmRh]::Owner)
