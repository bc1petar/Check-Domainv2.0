[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

function Date {Get-Date -Format "yyyy.MM.dd HH:mm:ss"}

# $domainlist_txt = "$PSScriptRoot\domainlist.txt"
$DNS_Server = "8.8.8.8"

$out_dir = "Results"
New-Item $out_dir -ItemType Directory -ErrorAction SilentlyContinue
$out_html = "$out_dir\$(Get-Date -Format "yyyy_MM_dd_HH_mm_ss").html"
$out_log = "$out_dir\$(Get-Date -Format "yyyy_MM_dd_HH_mm_ss").log"
$out_csv = "$out_dir\$(Get-Date -Format "yyyy_MM_dd_HH_mm_ss").csv"

$Form = New-Object System.Windows.Forms.Form
$Form.Text = "CheckDomain v2.2"
#$Form.TopMost = $true
$Form.FormBorderStyle = "FixedSingle"
$Form.Width = 400
$Form.Height = 600
$Form.MaximizeBox = $False
$Form.MinimizeBox = $False

function Process_domains {
    $html_content = $null
    
    $html_content = "<html>
    <head>
        <style>
            table, th, td {border: 1px solid black; border-collapse: collapse;}
            tr:nth-child(even) {background: #CCC}
            tr:nth-child(odd) {background: #FFF}
        </style>
        <title>
        </title>
    </head>
    <body>
        <p>Domain Info $(Date)</p>
        <table>
        <tr>
            <th>#</th>
            <th>Domain Name</th>
            <th>Mail Provider</th>
            <th>Hosting Provider</th>
            <th>Provider Info</th>
         </tr>"

         Write-Output "Domain;Mail Provider;Provider;Provider Info;Provider Url" | Out-File $out_csv

    $i = 1
    $domainlist = $textbox1.Text -split "`n"

    foreach ($domain in $domainlist) # (Get-Content $domainlist_txt)
        {
        $domain = $domain.Trim()

        Write-Output "$(Date) Processing MX records for domain $domain" | Out-File $out_log -Append
    
        $mx_servers = $mail_provider = $a_servers = [array]$provider = [array]$provider_info = [array]$provider_url = $null
    
        try {
            $mx_servers = (Resolve-DnsName -Name $domain -Type MX -Server $DNS_Server -ErrorAction Stop | sort Preference).NameExchange
            foreach ($mx_server in $mx_servers | select -First 1)
                {
                if ($mx_server -like "*.google.com")
                    {
                    Write-Output "$(Date) Mail provider for domain $domain is Google" | Out-File $out_log -Append
                    $mail_provider = "Google"
                    }
                elseif ($mx_server -like "*.amazonaws.com")
                    {
                    Write-Output "$(Date) Mail provider for domain $domain is Amazon" | Out-File $out_log -Append
                    $mail_provider = "Amazon"
                    }
                elseif ($mx_server -like "*.outlook.com")
                    {
                    Write-Output "$(Date) Mail provider for domain $domain is Microsoft" | Out-File $out_log -Append
                    $mail_provider = "Microsoft"
                    }
                else
                    {
                    Write-Output "$(Date) Can't define cloud mail provider for domain $domain" | Out-File $out_log -Append
                    $mail_provider = "Not Google/Amazon/Microsoft"
                    }
                }
            }
        catch {
            Write-Output "$(Date) $($_.exception.message)" | Out-File $out_log -Append
            }

        Write-Output "$(Date) Processing A records for domain $domain" | Out-File $out_log -Append
    
        try {
            $a_servers = (Resolve-DnsName -Name $domain -Type A -Server $DNS_Server -ErrorAction Stop).IPAddress
            foreach ($a_server in $a_servers | select -First 1)
                {
                Write-Output "$(Date) Searching for information about IP address $a_server" | Out-File $out_log -Append
           
                $out = Invoke-RestMethod -Uri "https://rest.db.ripe.net/search.xml?source=RIPE&source=AFRINIC-GRS&source=APNIC-GRS&source=ARIN-GRS&source=JPIRR-GRS&source=LACNIC-GRS&source=RADB-GRS&source=RIPE-GRS&query-string=$a_server&flags=no-filtering" -Method Get
                #$out.Save("$PSScriptRoot\1.xml")
            
                $provider += (($out.'whois-resources'.objects.object | ? {$_.type -eq "route"}).attributes.attribute | ? {$_.name -eq "mnt-by"}).Value
                $provider += (($out.'whois-resources'.objects.object | ? {$_.type -eq "inetnum"}).attributes.attribute | ? {$_.name -eq "netname"}).Value
                $provider = $provider | ? {$_ –ne "NON-RIPE-NCC-MANAGED-ADDRESS-BLOCK"}
                # $provider | Out-File "$PSScriptRoot\1.txt" -Append
                $provider = $provider | select -First 1
                
                $provider_info += (($out.'whois-resources'.objects.object | ? {$_.type -eq "route"}).attributes.attribute | ? {$_.name -eq "descr"}).Value
                $provider_info += (($out.'whois-resources'.objects.object | ? {$_.type -eq "inetnum"}).attributes.attribute | ? {$_.name -eq "org"}).Value
                $provider_info = $provider_info | select -First 1
                
                $provider_url += (($out.'whois-resources'.objects.object | ? {$_.type -eq "route"}).attributes.attribute | ? {$_.name -eq "mnt-by"}).link.href
                $provider_url += (($out.'whois-resources'.objects.object | ? {$_.type -eq "inetnum"}).attributes.attribute | ? {$_.name -eq "org"}).link.href
                $provider_url = $provider_url | select -First 1
                
                if ($provider -ne $null)
                    {
                    Write-Output "$(Date) IP address $a_server owned by $provider_descr (managed by: $provider, also see URL: $provider_url)" | Out-File $out_log -Append
                    }
                else
                    {
                    Write-Output "$(Date) No matches found for IP address $a_server" | Out-File $out_log -Append
                    }
                }
            }
        catch {
            Write-Output "$(Date) $($_.exception.message)" | Out-File $out_log -Append
            }
        
        $html_content += "<tr>
            <td style=`"text-align: right`">$i</td>
            <td>$domain</td>
            <td>$mail_provider</td>
            <td>$provider</td>
            <td><a href=`"$provider_url`">$provider_info</a></td>"

        $i++

        Write-Output "$domain;$mail_provider;$provider;$provider_info;$provider_url" | Out-File $out_csv -Append
        }
    
    $html_content += "</table>
        </body>
    </html>"
    
    Write-Output $html_content | Out-File $out_html -Append
    
    Start $out_html
    }

$textbox1 = New-Object Windows.Forms.Textbox
$textbox1.Location = New-Object System.Drawing.Point (15, 15)
$textbox1.Size = New-Object System.Drawing.Size (365, 490)
#$textbox1.ReadOnly = $true
$textbox1.Font = "Microsoft Sans Serif, 12"
$textbox1.Text = "Enter domains here. For example:
oriflame.cz
ibis-instruments.com
gmail.com"
$textbox1.Multiline = $true
$Form.Controls.Add($textbox1)

$button1 = New-Object System.Windows.Forms.Button
$button1.Text = "Process"
$button1.Width = 100
$button1.Height = 30
$button1.Location = New-Object system.drawing.point(150, 525)
$button1.Font = "Microsoft Sans Serif, 12"
$Button1.Enabled = $true
$Button1.Add_Click({Process_domains})
$Form.controls.Add($button1)

[void]$Form.ShowDialog()
$Form.Dispose()