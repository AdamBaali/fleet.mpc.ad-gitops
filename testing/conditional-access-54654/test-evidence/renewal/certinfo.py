import subprocess,re,sys
pem=subprocess.run(['security','find-certificate','-a','-c','EBC70BCE','-p',sys.argv[1]],capture_output=True,text=True).stdout
blocks=re.findall(r'-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----',pem,re.S)
out=[]
for b in blocks:
    r=subprocess.run(['openssl','x509','-noout','-serial','-startdate','-enddate'],input=b,capture_output=True,text=True).stdout.split('\n')
    out.append(' '.join(x.replace('serial=','serial ').replace('notBefore=','from ').replace('notAfter=','to ') for x in r if x))
print(' | '.join(out) if out else 'no certificate')
