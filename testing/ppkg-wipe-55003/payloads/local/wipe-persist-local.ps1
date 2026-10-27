# Lab only: calls doWipePersistProvisionedData on this host through the MDM WMI bridge, with no MDM server.
# Runs as SYSTEM (the guest agent). Proves the lab can reset before Fleet is involved (L-3).
$ns = 'root\cimv2\mdm\dmmap'
$session = New-CimSession
$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$params.Add([Microsoft.Management.Infrastructure.CimMethodParameter]::Create('param', '', 'String', 'In'))
$instance = Get-CimInstance -Namespace $ns -ClassName MDM_RemoteWipe
$session.InvokeMethod($ns, $instance, 'doWipePersistProvisionedDataMethod', $params)
'called'
