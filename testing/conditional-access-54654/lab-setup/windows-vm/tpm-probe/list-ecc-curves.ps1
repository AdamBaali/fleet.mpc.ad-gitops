$null=[Reflection.Assembly]::LoadFrom('C:\Program Files (x86)\Duo Desktop\TSS.Net.dll')
$dev=[Tpm2Lib.TbsDevice]::new($false); $dev.Connect(); $tpm=[Tpm2Lib.Tpm2]::new($dev)
$o=$null; $null=$tpm.GetCapability([Tpm2Lib.Cap]::EccCurves,0,64,[ref]$o)
"ECC curves: " + ((($o -as [Tpm2Lib.EccCurveArray]).eccCurves | % { $_.ToString() }) -join ', ')
$o=$null; $null=$tpm.GetCapability([Tpm2Lib.Cap]::Algs,0,128,[ref]$o)
"Algorithms: " + ((($o -as [Tpm2Lib.AlgPropertyArray]).algProperties | % { $_.alg.ToString() }) -join ', ')
$o=$null; $null=$tpm.GetCapability([Tpm2Lib.Cap]::TpmProperties,[Convert]::ToUInt32('100',16),20,[ref]$o)
($o -as [Tpm2Lib.TaggedTpmPropertyArray]).tpmProperty | ? { $_.property -in 'PtFamilyIndicator','PtRevision','PtYear','PtManufacturer','PtVendorString1','PtVendorString2','PtFirmwareVersion1','PtFirmwareVersion2','PtModules' } | % { "{0} = 0x{1:x8}" -f $_.property,$_.value }
