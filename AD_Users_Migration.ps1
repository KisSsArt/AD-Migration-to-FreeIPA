# Definitions
$OU = "OU=DOMAIN_USERS,DC=atom,DC=xyz"
$FreeIPAFqdn ="redsrv.ipadc.ru"

# Get Active Directory users
$ADUsers = Get-ADUser -SearchBase $OU -filter * -properties employeeNumber,
    title,mail,department,telephoneNumber,mobile

# Get FreeIPA credentials
$FreeIPACredentials = Get-Credential -Message "Enter FreeIPA admin credentials"

# Apply policy to trust all certificates
add-type @"
 using System.Net;
 using System.Security.Cryptography.X509Certificates;
 public class TrustAllCertsPolicy : ICertificatePolicy {
 public bool CheckValidationResult(
 ServicePoint srvPoint, X509Certificate certificate,
 WebRequest request, int certificateProblem) {
 return true;
 }
 }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls,Tls11,Tls12'

# Login to FreeIPA
try {
    $SecureUserName = ConvertTo-SecureString $FreeIPACredentials.UserName -AsPlainText -Force
    Get-FreeIPAAPIAuthenticationCookie -AdminLogin $SecureUserName `
            -AdminPassword $FreeIPACredentials.Password -URL "https://$($FreeIPAFqdn)"
    Write-Host "IPA auth OK" -ForegroundColor Green
}
catch {
    Write-Host $_ -BackgroundColor Red
    exit 1
}

Write-Host "--Transfer users to FreeIPA--" -ForegroundColor Green

# Transfer users to FreeIPA
foreach ($ADUser in $ADUsers) {
    try {
        Write-Host "Adding" "$($ADUser.Name)" "with first:" "$($ADUser.GivenName)" "second:" "$($ADUser.Surname)"
        $Request = Invoke-FreeIPAAPIuser_add -cn "$($ADUser.Name)" -first "$($ADUser.GivenName)" `
            -last "$($ADUser.Surname)" -login "$($ADUser.Name)"
    }
    catch {
        Write-Host $_ -BackgroundColor Red
        continue 
    }
} 
